library;

import 'package:equatable/equatable.dart';

import 'user_summary.dart';

class PaginatedUsers extends Equatable {
  const PaginatedUsers({
    required this.users,
    required this.nextCursor,
    required this.hasReachedEnd,
  });

  factory PaginatedUsers.fromBatch({
    required List<UserSummary> users,
    required Object? nextCursor,
  }) => PaginatedUsers(
    users: users,
    nextCursor: nextCursor,
    hasReachedEnd: nextCursor == null || users.isEmpty,
  );

  factory PaginatedUsers.empty() => const PaginatedUsers(
    users: <UserSummary>[],
    nextCursor: null,
    hasReachedEnd: true,
  );

  final List<UserSummary> users;

  final Object? nextCursor;

  final bool hasReachedEnd;

  PaginatedUsers copyWith({
    List<UserSummary>? users,
    Object? nextCursor,
    bool clearNextCursor = false,
    bool? hasReachedEnd,
  }) => PaginatedUsers(
    users: users ?? this.users,
    nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
    hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
  );

  @override
  List<Object?> get props => <Object?>[users, nextCursor, hasReachedEnd];
}
