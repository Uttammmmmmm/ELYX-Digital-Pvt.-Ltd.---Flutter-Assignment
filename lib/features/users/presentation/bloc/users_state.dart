/// State held by [UsersBloc].
library;

import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/user_summary.dart';

/// Lifecycle of the users list.
enum UsersStatus {
  /// Nothing requested yet.
  initial,

  /// First batch in flight; the screen is empty.
  loading,

  /// At least one batch has loaded.
  success,

  /// The most recent request failed. [UsersState.users] may still hold data.
  failure,
}

/// A single, flat state object for the users list.
///
/// WHY NOT SEALED SUBCLASSES: pagination state is a list *plus* an overlay
/// status. With `UsersLoading` / `UsersError` as separate classes every
/// transition either loses the already-loaded users or copies them into each
/// subclass anyway. A flat object keeps "40 users loaded, and the 5th batch
/// just failed" representable -- exactly the case that needs an inline footer
/// error rather than a blank error screen.
class UsersState extends Equatable {
  const UsersState({
    this.status = UsersStatus.initial,
    this.users = const <UserSummary>[],
    this.visibleUsers = const <UserSummary>[],
    this.query = '',
    this.nextSince,
    this.hasReachedEnd = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.failure,
  });

  /// Overall lifecycle.
  final UsersStatus status;

  /// Every user paged in so far, in API order. Never filtered -- filtering
  /// this would destroy the cursor sequence and break scrolling.
  final List<UserSummary> users;

  /// What the list renders: [users] passed through the search filter.
  final List<UserSummary> visibleUsers;

  /// Current search text.
  final String query;

  /// Opaque cursor for the next batch; null before the first load or at the
  /// end of the list. Constraint (a) -- the Bloc never interprets this.
  final int? nextSince;

  /// True once GitHub has told us there is no next batch.
  final bool hasReachedEnd;

  /// A subsequent batch is in flight (footer spinner, not full-screen).
  final bool isLoadingMore;

  /// A pull-to-refresh is in flight.
  final bool isRefreshing;

  /// The most recent failure, or null. Kept alongside [users] so the UI can
  /// choose between a full-screen error and an inline one.
  final Failure? failure;

  /// True when a search query is narrowing the list.
  bool get isFiltering => query.trim().isNotEmpty;

  /// True when the failure should take over the whole screen: something went
  /// wrong and there is nothing to show behind it.
  bool get hasBlockingFailure =>
      status == UsersStatus.failure && users.isEmpty;

  /// True when the failure should render inline under an existing list.
  bool get hasInlineFailure =>
      status == UsersStatus.failure && users.isNotEmpty;

  /// The rate-limit failure, when that is what went wrong. Constraint (d).
  RateLimitFailure? get rateLimitFailure {
    final Failure? f = failure;
    return f is RateLimitFailure ? f : null;
  }

  /// True when a search is active but few users are loaded, so the UI should
  /// invite loading more rather than implying "no such user exists".
  bool get shouldOfferMoreForSearch =>
      isFiltering && !hasReachedEnd && visibleUsers.length < 5;

  /// Copy helper. [failure] and [nextSince] need explicit clearing, so they
  /// get dedicated flags rather than relying on null meaning "unchanged".
  UsersState copyWith({
    UsersStatus? status,
    List<UserSummary>? users,
    List<UserSummary>? visibleUsers,
    String? query,
    int? nextSince,
    bool clearNextSince = false,
    bool? hasReachedEnd,
    bool? isLoadingMore,
    bool? isRefreshing,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return UsersState(
      status: status ?? this.status,
      users: users ?? this.users,
      visibleUsers: visibleUsers ?? this.visibleUsers,
      query: query ?? this.query,
      nextSince: clearNextSince ? null : (nextSince ?? this.nextSince),
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => <Object?>[
        status,
        users,
        visibleUsers,
        query,
        nextSince,
        hasReachedEnd,
        isLoadingMore,
        isRefreshing,
        failure,
      ];
}
