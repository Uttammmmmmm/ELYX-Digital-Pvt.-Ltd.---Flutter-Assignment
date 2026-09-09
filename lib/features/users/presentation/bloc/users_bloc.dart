/// Pagination, search, refresh and retry for the users list.
library;

import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/event_transformers.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/paginated_users.dart';
import '../../domain/entities/user_summary.dart';
import '../../domain/usecases/filter_users.dart';
import '../../domain/usecases/get_users.dart';
import 'users_event.dart';
import 'users_state.dart';

/// Drives the users list screen.
///
/// Owns exactly three things the widgets must not: the pagination cursor, the
/// search query, and which failure presentation applies. It never touches
/// Dio, Hive or JSON -- it only calls use cases.
class UsersBloc extends Bloc<UsersEvent, UsersState> {
  UsersBloc({
    required GetUsers getUsers,
    required FilterUsers filterUsers,
    Duration searchDebounce = const Duration(milliseconds: 300),
  })  : _getUsers = getUsers,
        _filterUsers = filterUsers,
        super(const UsersState()) {
    on<UsersStarted>(_onStarted);

    // droppable(): a fast flick emits several threshold events; without this
    // each fires an identical request. Constraint (d) -- 60 requests/hour.
    on<UsersLoadMoreRequested>(_onLoadMore, transformer: dropWhileBusy());

    // Also droppable: a second pull while one refresh is in flight is a
    // no-op, not a second full reload.
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
  final FilterUsers _filterUsers;

  Future<void> _onStarted(UsersStarted event, Emitter<UsersState> emit) async {
    if (state.status != UsersStatus.initial) return;
    emit(state.copyWith(status: UsersStatus.loading, clearFailure: true));
    await _loadPage(emit, since: null, replace: true);
  }

  Future<void> _onLoadMore(
    UsersLoadMoreRequested event,
    Emitter<UsersState> emit,
  ) async {
    // Two guards the transformer cannot provide: never page past the end, and
    // never page before the first load has produced a cursor.
    if (state.hasReachedEnd || state.status == UsersStatus.initial) return;
    if (state.nextSince == null) return;

    emit(state.copyWith(isLoadingMore: true, clearFailure: true));
    await _loadPage(emit, since: state.nextSince, replace: false);
  }

  Future<void> _onRefresh(
    UsersRefreshRequested event,
    Emitter<UsersState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true, clearFailure: true));
    // Cursor reset to null on purpose: `since` is a cursor, not a page index,
    // so there is no way to re-request "the current page". A refresh can only
    // restart the walk from the beginning, and keeping the old tail would
    // leave a hole in the middle of the sequence.
    await _loadPage(emit, since: null, replace: true, forceRefresh: true);
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
    await _loadPage(emit, since: state.nextSince, replace: isFirstPage);
  }

  void _onSearchChanged(UsersSearchChanged event, Emitter<UsersState> emit) {
    // `users` is deliberately untouched: filtering the source list would
    // destroy the cursor sequence and break scrolling once the query clears.
    emit(
      state.copyWith(
        query: event.query,
        visibleUsers: _filterUsers(
          FilterUsersParams(users: state.users, query: event.query),
        ),
      ),
    );
  }

  /// Fetches one batch and folds the result into state.
  Future<void> _loadPage(
    Emitter<UsersState> emit, {
    required int? since,
    required bool replace,
    bool forceRefresh = false,
  }) async {
    final Either<Failure, PaginatedUsers> result = await _getUsers(
      GetUsersParams(since: since, forceRefresh: forceRefresh),
    );

    emit(
      result.fold(
        (Failure failure) => state.copyWith(
          status: UsersStatus.failure,
          isLoadingMore: false,
          isRefreshing: false,
          failure: failure,
        ),
        (PaginatedUsers page) => _merged(page, replace: replace),
      ),
    );
  }

  /// Merges a batch into state and re-applies the active search.
  UsersState _merged(PaginatedUsers page, {required bool replace}) {
    final List<UserSummary> users = replace
        ? page.users
        : _dedupe(<UserSummary>[...state.users, ...page.users]);

    return state.copyWith(
      status: UsersStatus.success,
      users: users,
      visibleUsers: _filterUsers(
        FilterUsersParams(users: users, query: state.query),
      ),
      nextSince: page.nextSince,
      clearNextSince: page.nextSince == null,
      hasReachedEnd: page.hasReachedEnd,
      isLoadingMore: false,
      isRefreshing: false,
      clearFailure: true,
    );
  }

  /// Drops duplicate ids.
  ///
  /// A refresh overlapping an in-flight batch, or a cursor replayed from the
  /// cache, can deliver the same user twice -- which throws on a keyed list.
  static List<UserSummary> _dedupe(List<UserSummary> users) {
    final Set<int> seen = <int>{};
    return users
        .where((UserSummary u) => seen.add(u.id))
        .toList(growable: false);
  }
}
