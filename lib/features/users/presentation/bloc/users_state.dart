library;

import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/user_summary.dart';

enum UsersStatus { initial, loading, loadingMore, success, failure, refreshing }

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

  final UsersStatus status;

  final List<UserSummary> allUsers;

  final List<UserSummary> visibleUsers;

  final String searchQuery;

  final Object? nextCursor;

  final bool hasReachedEnd;

  final Failure? failure;

  final DateTime? rateLimitResetAt;

  bool get isEmpty =>
      allUsers.isEmpty &&
      status != UsersStatus.loading &&
      status != UsersStatus.initial;

  bool get isSearchEmpty =>
      searchQuery.trim().isNotEmpty && visibleUsers.isEmpty;

  bool get canLoadMore =>
      !hasReachedEnd &&
      nextCursor != null &&
      !isRateLimited &&
      status != UsersStatus.failure &&
      status != UsersStatus.loadingMore &&
      status != UsersStatus.loading &&
      status != UsersStatus.refreshing;

  bool get isRateLimited {
    final DateTime? resetAt = rateLimitResetAt;
    return resetAt != null && resetAt.isAfter(DateTime.now());
  }

  bool get isFiltering => searchQuery.trim().isNotEmpty;

  bool get hasBlockingFailure =>
      status == UsersStatus.failure && allUsers.isEmpty;

  bool get hasInlineFailure =>
      status == UsersStatus.failure && allUsers.isNotEmpty;

  RateLimitFailure? get rateLimitFailure {
    final Failure? f = failure;
    return f is RateLimitFailure ? f : null;
  }

  bool get shouldOfferMoreForSearch =>
      isFiltering && !hasReachedEnd && visibleUsers.length < 5;

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
