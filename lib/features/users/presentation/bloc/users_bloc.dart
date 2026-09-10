library;

import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/event_transformers.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/paginated_users.dart';
import '../../domain/entities/user_summary.dart';
import '../../domain/usecases/filter_users.dart';
import '../../domain/usecases/get_cached_users.dart';
import '../../domain/usecases/get_users.dart';
import 'users_event.dart';
import 'users_state.dart';

class UsersBloc extends Bloc<UsersEvent, UsersState> {
  UsersBloc({
    required GetUsers getUsers,
    required FilterUsers filterUsers,
    required GetCachedUsers getCachedUsers,
    Duration searchDebounce = const Duration(milliseconds: 300),
  }) : _getUsers = getUsers,
       _filterUsers = filterUsers,
       _getCachedUsers = getCachedUsers,
       super(const UsersState()) {
    on<UsersFetched>(_onFetched);

    on<UsersNextPageRequested>(_onNextPage, transformer: dropWhileBusy());

    on<UsersRefreshed>(_onRefreshed, transformer: dropWhileBusy());

    on<UsersFailedPageRetried>(_onRetried, transformer: dropWhileBusy());

    on<UsersSearchQueryChanged>(
      _onSearchQueryChanged,
      transformer: debounceRestartable(searchDebounce),
    );

    on<UsersSearchCleared>(_onSearchCleared);
  }

  final GetUsers _getUsers;
  final FilterUsers _filterUsers;
  final GetCachedUsers _getCachedUsers;

  /// Bumped every time the list is replaced wholesale (first load, refresh,
  /// first-page retry).
  ///
  /// `droppable()` serialises requests *within* one event type, but a refresh
  /// and an append are different events with different transformers, so a
  /// refresh can land while a page request is still in flight. Without this
  /// counter the older page appends onto the refreshed list and drags the
  /// cursor back to its own successor, so pagination resumes from the
  /// pre-refresh sequence and re-serves rows the user has already seen.
  int _generation = 0;

  Future<void> _onFetched(UsersFetched event, Emitter<UsersState> emit) async {
    if (state.status != UsersStatus.initial) return;

    emit(state.copyWith(status: UsersStatus.loading, clearFailure: true));

    final List<UserSummary> cached = await _getCachedUsers(const NoParams());
    if (isClosed) return;
    if (cached.isNotEmpty) {
      emit(_filtered(state.copyWith(allUsers: cached), state.searchQuery));
    }

    await _load(emit, cursor: null, replace: true);
  }

  Future<void> _onNextPage(
    UsersNextPageRequested event,
    Emitter<UsersState> emit,
  ) async {
    if (!state.canLoadMore) return;

    emit(state.copyWith(status: UsersStatus.loadingMore, clearFailure: true));
    await _load(emit, cursor: state.nextCursor, replace: false);
  }

  Future<void> _onRefreshed(
    UsersRefreshed event,
    Emitter<UsersState> emit,
  ) async {
    emit(state.copyWith(status: UsersStatus.refreshing, clearFailure: true));

    await _load(emit, cursor: null, replace: true, forceRefresh: true);
  }

  Future<void> _onRetried(
    UsersFailedPageRetried event,
    Emitter<UsersState> emit,
  ) async {
    if (state.isRateLimited) return;

    final bool isFirstPage = state.allUsers.isEmpty;

    emit(
      state.copyWith(
        status: isFirstPage ? UsersStatus.loading : UsersStatus.loadingMore,
        clearFailure: true,
      ),
    );
    await _load(emit, cursor: state.nextCursor, replace: isFirstPage);
  }

  void _onSearchQueryChanged(
    UsersSearchQueryChanged event,
    Emitter<UsersState> emit,
  ) => emit(_filtered(state, event.query));

  void _onSearchCleared(UsersSearchCleared event, Emitter<UsersState> emit) =>
      emit(_filtered(state, ''));

  UsersState _filtered(UsersState from, String query) => from.copyWith(
    searchQuery: query,
    visibleUsers: _filterUsers(
      FilterUsersParams(users: from.allUsers, query: query),
    ),
  );

  Future<void> _load(
    Emitter<UsersState> emit, {
    required Object? cursor,
    required bool replace,
    bool forceRefresh = false,
  }) async {
    // A replacing load defines a new list identity; an appending load belongs
    // to the one that is current when it starts.
    final int generation = replace ? ++_generation : _generation;

    final Either<Failure, PaginatedUsers> result = await _getUsers(
      GetUsersParams(cursor: cursor, forceRefresh: forceRefresh),
    );

    if (isClosed) return;

    // A refresh overtook this request while it was in flight. Its page
    // describes a list that no longer exists, so drop it rather than splice
    // two snapshots together.
    if (generation != _generation) return;

    emit(
      result.fold(
        (Failure failure) => _withFailure(failure),
        (PaginatedUsers page) => _withPage(page, replace: replace),
      ),
    );
  }

  UsersState _withFailure(Failure failure) => state.copyWith(
    status: UsersStatus.failure,
    failure: failure,

    rateLimitResetAt: failure is RateLimitFailure ? failure.resetAt : null,
  );

  UsersState _withPage(PaginatedUsers page, {required bool replace}) {
    final List<UserSummary> merged = replace
        ? page.users
        : _dedupe(<UserSummary>[...state.allUsers, ...page.users]);

    return _filtered(
      state.copyWith(
        status: UsersStatus.success,
        allUsers: merged,
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        hasReachedEnd: page.hasReachedEnd,
        clearFailure: true,

        clearRateLimitResetAt: true,
      ),
      state.searchQuery,
    );
  }

  static List<UserSummary> _dedupe(List<UserSummary> users) {
    final Set<int> seen = <int>{};
    return users
        .where((UserSummary u) => seen.add(u.id))
        .toList(growable: false);
  }
}
