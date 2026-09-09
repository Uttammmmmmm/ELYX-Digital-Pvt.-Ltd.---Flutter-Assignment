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
/// Owns the three things widgets must not: the pagination cursor, the search
/// query, and which failure presentation applies. It imports no Flutter
/// widget library and never sees a BuildContext -- it calls use cases and
/// emits state, which is what makes it testable with `bloc_test` and no
/// network at all.
class UsersBloc extends Bloc<UsersEvent, UsersState> {
  UsersBloc({
    required GetUsers getUsers,
    required FilterUsers filterUsers,
    Duration searchDebounce = const Duration(milliseconds: 300),
  })  : _getUsers = getUsers,
        _filterUsers = filterUsers,
        super(const UsersState()) {
    on<UsersFetched>(_onFetched);

    // droppable(): a fast flick crosses the threshold several times and emits
    // several events. Without this each fires an identical request for the
    // SAME cursor -- duplicate users, and three of a 60/hour budget spent to
    // fetch one page. Dropping is right rather than queueing, because the
    // extra events carry no new information.
    on<UsersNextPageRequested>(_onNextPage, transformer: dropWhileBusy());

    // droppable(): a second pull while a refresh is in flight is a no-op, not
    // a second full reload of the list.
    on<UsersRefreshed>(_onRefreshed, transformer: dropWhileBusy());

    on<UsersFailedPageRetried>(_onRetried, transformer: dropWhileBusy());

    // restartable() + 300ms debounce: 300ms is long enough that a typed word
    // filters once instead of per keystroke, short enough to feel immediate.
    // Restarting matters as much as the delay -- if an older query is still
    // being applied when a newer one arrives, its result is discarded rather
    // than racing the newer one and briefly rendering stale matches.
    on<UsersSearchQueryChanged>(
      _onSearchQueryChanged,
      transformer: debounceRestartable(searchDebounce),
    );

    // NOT debounced: clearing is deliberate and must feel instant.
    on<UsersSearchCleared>(_onSearchCleared);
  }

  final GetUsers _getUsers;
  final FilterUsers _filterUsers;

  // -- Handlers ------------------------------------------------------------

  Future<void> _onFetched(
    UsersFetched event,
    Emitter<UsersState> emit,
  ) async {
    if (state.status != UsersStatus.initial) return;

    emit(state.copyWith(status: UsersStatus.loading, clearFailure: true));
    await _load(emit, since: null, replace: true);
  }

  Future<void> _onNextPage(
    UsersNextPageRequested event,
    Emitter<UsersState> emit,
  ) async {
    // Guards the transformer cannot provide. `canLoadMore` covers all of
    // them: end of list reached, no cursor yet (the first page has not
    // landed), or a load already in progress.
    if (!state.canLoadMore) return;

    emit(state.copyWith(status: UsersStatus.loadingMore, clearFailure: true));
    await _load(emit, since: state.nextSince, replace: false);
  }

  Future<void> _onRefreshed(
    UsersRefreshed event,
    Emitter<UsersState> emit,
  ) async {
    // The OLD list stays in `allUsers` throughout. The screen is never
    // blanked mid-refresh: `refreshing` is a status over existing data, and
    // the list is only replaced once a new first page actually arrives.
    emit(state.copyWith(status: UsersStatus.refreshing, clearFailure: true));

    // Cursor resets to null because `since` is a cursor, not a page index --
    // there is no way to re-request "the current page", only to restart the
    // walk from the beginning.
    await _load(emit, since: null, replace: true, forceRefresh: true);
  }

  Future<void> _onRetried(
    UsersFailedPageRetried event,
    Emitter<UsersState> emit,
  ) async {
    // Even an explicit retry is refused while the quota is spent: it cannot
    // succeed, and a rejected request still counts against the limit. The UI
    // disables its retry button for the same reason, so this is the guard for
    // anything that dispatches the event another way.
    if (state.isRateLimited) return;

    // Retry resumes from the CURRENT cursor, which the failure deliberately
    // left intact. A cold failure (nothing loaded) retries the first page.
    final bool isFirstPage = state.allUsers.isEmpty;

    emit(
      state.copyWith(
        status: isFirstPage ? UsersStatus.loading : UsersStatus.loadingMore,
        clearFailure: true,
      ),
    );
    await _load(emit, since: state.nextSince, replace: isFirstPage);
  }

  void _onSearchQueryChanged(
    UsersSearchQueryChanged event,
    Emitter<UsersState> emit,
  ) =>
      emit(_filtered(state, event.query));

  void _onSearchCleared(
    UsersSearchCleared event,
    Emitter<UsersState> emit,
  ) =>
      emit(_filtered(state, ''));

  // -- Internals -----------------------------------------------------------

  /// Applies [query] to the loaded users.
  ///
  /// Purely local: no network call, and `nextSince` / `hasReachedEnd` are
  /// untouched, so pagination is unaffected by searching. Filtering
  /// `allUsers` itself would destroy the cursor sequence and break scrolling
  /// the moment the query was cleared.
  UsersState _filtered(UsersState from, String query) => from.copyWith(
        searchQuery: query,
        visibleUsers: _filterUsers(
          FilterUsersParams(users: from.allUsers, query: query),
        ),
      );

  /// Fetches one page and folds the result into state.
  Future<void> _load(
    Emitter<UsersState> emit, {
    required int? since,
    required bool replace,
    bool forceRefresh = false,
  }) async {
    final Either<Failure, PaginatedUsers> result = await _getUsers(
      GetUsersParams(since: since, forceRefresh: forceRefresh),
    );

    // MUST be checked after every await before emitting. A Bloc closed while
    // this request was in flight -- the user tapped back before the page
    // landed -- would otherwise receive an emit on a closed StreamController
    // and throw `Cannot add new events after calling close`. That crash
    // surfaces as an unrelated red screen some frames after the navigation,
    // which is exactly the back-navigation failure the brief describes.
    if (isClosed) return;

    emit(
      result.fold(
        (Failure failure) => _withFailure(failure),
        (PaginatedUsers page) => _withPage(page, replace: replace),
      ),
    );
  }

  /// Records a failure WITHOUT discarding progress.
  ///
  /// `allUsers` and `nextSince` are deliberately left untouched, so a retry
  /// resumes from the same cursor instead of restarting the list.
  UsersState _withFailure(Failure failure) => state.copyWith(
        status: UsersStatus.failure,
        failure: failure,
        // Constraint (d): kept in state so the UI can run a countdown, and
        // kept separately from `failure` so it survives the next retry.
        rateLimitResetAt:
            failure is RateLimitFailure ? failure.resetAt : null,
      );

  /// Merges a page into state and re-applies the active search.
  UsersState _withPage(PaginatedUsers page, {required bool replace}) {
    final List<UserSummary> merged = replace
        ? page.users
        : _dedupe(<UserSummary>[...state.allUsers, ...page.users]);

    return _filtered(
      state.copyWith(
        status: UsersStatus.success,
        allUsers: merged,
        nextSince: page.nextSince,
        clearNextSince: page.nextSince == null,
        hasReachedEnd: page.hasReachedEnd,
        clearFailure: true,
        // A successful response means the quota is no longer spent.
        clearRateLimitResetAt: true,
      ),
      state.searchQuery,
    );
  }

  /// Drops duplicate ids while preserving order.
  ///
  /// A refresh overlapping an in-flight page, or a cursor replayed from the
  /// cache, can deliver the same user twice -- which throws on a keyed list
  /// and inflates the search corpus.
  static List<UserSummary> _dedupe(List<UserSummary> users) {
    final Set<int> seen = <int>{};
    return users
        .where((UserSummary u) => seen.add(u.id))
        .toList(growable: false);
  }
}
