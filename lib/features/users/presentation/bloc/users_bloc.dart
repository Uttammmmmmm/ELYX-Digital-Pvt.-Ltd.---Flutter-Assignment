/// Pagination, search, refresh and retry for the users list.
library;

import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/bloc/event_transformers.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/sourced.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/github_user.dart';
import '../../domain/entities/users_page.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/usecases/filter_users.dart';
import '../../domain/usecases/get_users.dart';
import '../../domain/usecases/refresh_users.dart';
import 'users_event.dart';
import 'users_state.dart';

/// Drives the users list screen.
///
/// Owns exactly three things the widgets must not: the pagination cursor, the
/// search query, and which of the four failure presentations applies. It never
/// touches Dio, Hive or JSON -- it only calls use cases.
class UsersBloc extends Bloc<UsersEvent, UsersState> {
  UsersBloc({
    required GetUsers getUsers,
    required RefreshUsers refreshUsers,
    required FilterUsers filterUsers,
    required UserRepository repository,
    Duration searchDebounce = const Duration(milliseconds: 300),
  }) : _getUsers = getUsers,
       _refreshUsers = refreshUsers,
       _filterUsers = filterUsers,
       _repository = repository,
       super(const UsersState()) {
    on<UsersStarted>(_onStarted);

    // droppable(): a fast flick emits several threshold events; without this
    // each fires an identical request. Constraint (d) -- 60 requests/hour.
    on<UsersLoadMoreRequested>(_onLoadMore, transformer: dropWhileBusy());

    // Also droppable: a second pull while one refresh is in flight is a no-op,
    // not a second full reload.
    on<UsersRefreshRequested>(_onRefresh, transformer: dropWhileBusy());

    on<UsersRetryRequested>(_onRetry, transformer: dropWhileBusy());

    // Purely local work, but debounced so a 20-character query filters once
    // rather than twenty times.
    on<UsersSearchChanged>(
      _onSearchChanged,
      transformer: debounceRestartable(searchDebounce),
    );
  }

  final GetUsers _getUsers;
  final RefreshUsers _refreshUsers;
  final FilterUsers _filterUsers;
  final UserRepository _repository;

  Future<void> _onStarted(UsersStarted event, Emitter<UsersState> emit) async {
    if (state.status != UsersStatus.initial) return;
    emit(state.copyWith(status: UsersStatus.loading, clearFailure: true));
    await _loadPage(emit, cursor: null, replace: true);
  }

  Future<void> _onLoadMore(
    UsersLoadMoreRequested event,
    Emitter<UsersState> emit,
  ) async {
    // Two guards the transformer cannot provide: never page past the end, and
    // never page before the first load has produced a cursor.
    if (state.hasReachedEnd || state.status == UsersStatus.initial) return;
    if (state.cursor == null) return;

    emit(state.copyWith(isLoadingMore: true, clearFailure: true));
    await _loadPage(emit, cursor: state.cursor, replace: false);
  }

  Future<void> _onRefresh(
    UsersRefreshRequested event,
    Emitter<UsersState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true, clearFailure: true));

    final Either<Failure, Sourced<UsersPage>> result = await _refreshUsers(
      const NoParams(),
    );

    await result.fold(
      (Failure failure) async => emit(
        state.copyWith(
          status: UsersStatus.failure,
          isRefreshing: false,
          failure: failure,
        ),
      ),
      (Sourced<UsersPage> sourced) async {
        // Replace rather than append: a refresh restarts the cursor sequence,
        // and keeping the old tail would leave a hole in the middle.
        await _emitPage(emit, sourced, replace: true, isRefreshing: false);
      },
    );
  }

  Future<void> _onRetry(
    UsersRetryRequested event,
    Emitter<UsersState> emit,
  ) async {
    final bool isFirstPage = state.users.isEmpty;
    emit(
      state.copyWith(
        status: isFirstPage ? UsersStatus.loading : state.status,
        isLoadingMore: !isFirstPage,
        clearFailure: true,
      ),
    );
    // Resumes from the current cursor -- retry must not restart the list.
    await _loadPage(emit, cursor: state.cursor, replace: isFirstPage);
  }

  void _onSearchChanged(UsersSearchChanged event, Emitter<UsersState> emit) {
    // `users` is deliberately untouched: filtering the source list would
    // destroy the cursor sequence and break scrolling once the query clears.
    emit(
      state.copyWith(
        query: event.query,
        visibleUsers: _filterUsers(
          FilterUsersParams(
            users: state.users,
            query: event.query,
            knownNames: state.knownNames,
          ),
        ),
      ),
    );
  }

  /// Fetches one page and folds the result into state.
  Future<void> _loadPage(
    Emitter<UsersState> emit, {
    required int? cursor,
    required bool replace,
  }) async {
    final Either<Failure, Sourced<UsersPage>> result = await _getUsers(
      GetUsersParams(cursor: cursor),
    );

    await result.fold(
      (Failure failure) async => emit(
        state.copyWith(
          status: UsersStatus.failure,
          isLoadingMore: false,
          isRefreshing: false,
          failure: failure,
        ),
      ),
      (Sourced<UsersPage> sourced) async =>
          _emitPage(emit, sourced, replace: replace),
    );
  }

  /// Merges a page into state and re-applies the active search.
  Future<void> _emitPage(
    Emitter<UsersState> emit,
    Sourced<UsersPage> sourced, {
    required bool replace,
    bool isRefreshing = false,
  }) async {
    final UsersPage page = sourced.value;

    final List<GithubUser> merged = replace
        ? page.users
        : _dedupe(<GithubUser>[...state.users, ...page.users]);

    // Refreshed from the local detail cache each page: a user whose profile
    // was opened earlier becomes searchable by name from then on.
    final Map<String, String> knownNames = await _repository
        .cachedDisplayNames();

    emit(
      state.copyWith(
        status: UsersStatus.success,
        users: merged,
        visibleUsers: _filterUsers(
          FilterUsersParams(
            users: merged,
            query: state.query,
            knownNames: knownNames,
          ),
        ),
        knownNames: knownNames,
        cursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        hasReachedEnd: page.hasReachedEnd,
        isLoadingMore: false,
        isRefreshing: isRefreshing,
        clearFailure: true,
        isFromCache: sourced.isFromCache,
        cachedAt: sourced.cachedAt,
        clearCachedAt: sourced.cachedAt == null,
      ),
    );
  }

  /// Drops duplicate ids.
  ///
  /// A refresh that overlaps an in-flight page, or a cursor replayed from the
  /// cache, can deliver the same user twice -- which would throw on a keyed
  /// list. Cheap insurance for a real failure mode.
  static List<GithubUser> _dedupe(List<GithubUser> users) {
    final Set<int> seen = <int>{};
    return users
        .where((GithubUser u) => seen.add(u.id))
        .toList(growable: false);
  }
}
