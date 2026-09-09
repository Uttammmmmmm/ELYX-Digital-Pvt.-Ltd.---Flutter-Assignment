/// State held by [UsersBloc].
library;

import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/user_summary.dart';

/// Lifecycle of the users list.
enum UsersStatus {
  /// Nothing requested yet.
  initial,

  /// First page in flight; the screen has nothing to show.
  loading,

  /// A subsequent page is in flight; the list is on screen.
  loadingMore,

  /// At least one page has loaded.
  success,

  /// The most recent request failed. Loaded users may still be present.
  failure,

  /// A pull-to-refresh is in flight; the OLD list is still on screen.
  refreshing,
}

/// A single, flat state object for the users list.
///
/// WHY ONE CLASS RATHER THAN A SEALED UNION -- the mid-scroll error case
/// decides it. With `UsersLoadingMore` / `UsersFailure` as separate variants,
/// the failure that interrupts page 5 either discards the 40 users already on
/// screen or forces every variant to carry them anyway, at which point the
/// union is a flat class with extra ceremony. A status field keeps "40 users
/// loaded AND the last page failed" directly representable, which is exactly
/// what an inline footer error needs, and lets the UI branch on data
/// (`allUsers.isEmpty`) rather than on which constructor happened to run.
class UsersState extends Equatable {
  const UsersState({
    this.status = UsersStatus.initial,
    this.allUsers = const <UserSummary>[],
    this.visibleUsers = const <UserSummary>[],
    this.searchQuery = '',
    this.nextCursor,
    this.hasReachedEnd = false,
    this.failure,
    this.rateLimitResetAt,
  });

  /// Overall lifecycle.
  final UsersStatus status;

  /// Everything paged in so far, unfiltered, in API order. The pagination
  /// sequence lives here and is never narrowed by a search.
  final List<UserSummary> allUsers;

  /// What the list renders: [allUsers] through the search filter.
  final List<UserSummary> visibleUsers;

  /// Current search text.
  final String searchQuery;

  /// Opaque cursor for the next page; null before the first load and at the
  /// end of the list. Constraint (a) -- never interpreted here.
  /// Opaque cursor for the next batch; null before the first load and at the
  /// end of the list.
  ///
  /// `Object?`, and never interpreted here. Its meaning belongs to the active
  /// source -- a page number for reqres, a user id for GitHub -- and the Bloc
  /// only stores it and hands it back. That is what lets one Bloc drive two
  /// incompatible pagination schemes.
  final Object? nextCursor;

  /// True once GitHub has said there is no next page.
  final bool hasReachedEnd;

  /// The most recent failure. Non-null only alongside [UsersStatus.failure].
  final Failure? failure;

  /// When the GitHub quota returns, so the UI can run a countdown.
  ///
  /// Held separately from [failure] because it must OUTLIVE the failure
  /// status: after a retry moves the status back to `loading`, the quota is
  /// still spent and the UI may still want to say so. Constraint (d).
  final DateTime? rateLimitResetAt;

  // -- Derived -------------------------------------------------------------

  /// Nothing to show and nothing being fetched.
  bool get isEmpty =>
      allUsers.isEmpty &&
      status != UsersStatus.loading &&
      status != UsersStatus.initial;

  /// A search is active and matched nothing.
  ///
  /// Deliberately DIFFERENT from [isEmpty]: "no loaded user matches 'zzz'"
  /// and "GitHub returned no users" need different copy and different
  /// actions. Conflating them tells the user their search term does not exist
  /// on GitHub, which is not something client-side filtering can know.
  bool get isSearchEmpty =>
      searchQuery.trim().isNotEmpty && visibleUsers.isEmpty;

  /// Whether a next-page request is worth issuing.
  ///
  /// Note it does NOT consider the search query: filtering is a view over
  /// loaded data, and pagination continues underneath it. See the bloc.
  ///
  /// It DOES exclude [UsersStatus.failure]. A page that just failed must be
  /// retried explicitly, by tapping the inline Retry -- never automatically.
  /// Without this the scroll listener keeps firing at the bottom of the list,
  /// each attempt fails, and the app hammers the same cursor in a loop. That
  /// is not merely wasteful: against a 60/hour budget it spends the entire
  /// remaining quota in seconds, and against a 429 it is exactly the
  /// behaviour rate limiting exists to stop.
  bool get canLoadMore =>
      !hasReachedEnd &&
      nextCursor != null &&
      !isRateLimited &&
      status != UsersStatus.failure &&
      status != UsersStatus.loadingMore &&
      status != UsersStatus.loading &&
      status != UsersStatus.refreshing;

  /// True while GitHub's quota is known to be spent.
  ///
  /// Once [rateLimitResetAt] is in the future, every request is guaranteed to
  /// come back 403/429. Issuing one anyway cannot succeed, so the app stops
  /// asking until the window reopens -- and, because GitHub counts rejected
  /// requests too, asking anyway would push the reset time further out.
  bool get isRateLimited {
    final DateTime? resetAt = rateLimitResetAt;
    return resetAt != null && resetAt.isAfter(DateTime.now());
  }

  /// True when a search query is narrowing the list.
  bool get isFiltering => searchQuery.trim().isNotEmpty;

  /// The failure should take over the screen: nothing behind it.
  bool get hasBlockingFailure =>
      status == UsersStatus.failure && allUsers.isEmpty;

  /// The failure should render inline under an existing list.
  bool get hasInlineFailure =>
      status == UsersStatus.failure && allUsers.isNotEmpty;

  /// The rate-limit failure, when that is what went wrong.
  RateLimitFailure? get rateLimitFailure {
    final Failure? f = failure;
    return f is RateLimitFailure ? f : null;
  }

  /// A search is active over a short loaded set, so the UI should invite
  /// loading more rather than implying the user does not exist.
  bool get shouldOfferMoreForSearch =>
      isFiltering && !hasReachedEnd && visibleUsers.length < 5;

  /// Copy helper.
  ///
  /// [failure] and [nextCursor] are nullable, so "leave alone" and "clear"
  /// cannot both be expressed by passing null -- each gets an explicit flag.
  UsersState copyWith({
    UsersStatus? status,
    List<UserSummary>? allUsers,
    List<UserSummary>? visibleUsers,
    String? searchQuery,
    Object? nextCursor,
    bool clearNextCursor = false,
    bool? hasReachedEnd,
    Failure? failure,
    bool clearFailure = false,
    DateTime? rateLimitResetAt,
    bool clearRateLimitResetAt = false,
  }) {
    return UsersState(
      status: status ?? this.status,
      allUsers: allUsers ?? this.allUsers,
      visibleUsers: visibleUsers ?? this.visibleUsers,
      searchQuery: searchQuery ?? this.searchQuery,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      failure: clearFailure ? null : (failure ?? this.failure),
      rateLimitResetAt: clearRateLimitResetAt
          ? null
          : (rateLimitResetAt ?? this.rateLimitResetAt),
    );
  }

  @override
  List<Object?> get props => <Object?>[
        status,
        allUsers,
        visibleUsers,
        searchQuery,
        nextCursor,
        hasReachedEnd,
        failure,
        rateLimitResetAt,
      ];
}
