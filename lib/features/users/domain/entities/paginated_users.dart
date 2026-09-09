/// One batch of users plus the cursor that follows it.
library;

import 'package:equatable/equatable.dart';

import 'user_summary.dart';

/// A page of users and the cursor for the next page.
///
/// [nextCursor] is `Object?` and OPAQUE. The two supported sources paginate
/// incompatibly — reqres by page number (`?page=2`), GitHub by a user-id
/// cursor (`?since=47`) — and the only way to keep one Bloc driving both is
/// for nothing above the data layer to know which it is holding. The Bloc
/// stores this value and hands it straight back; it never inspects, compares
/// or increments it.
class PaginatedUsers extends Equatable {
  const PaginatedUsers({
    required this.users,
    required this.nextCursor,
    required this.hasReachedEnd,
  });

  /// Builds a batch and derives [hasReachedEnd] from the two signals both
  /// sources give: an absent next cursor, or an empty batch.
  factory PaginatedUsers.fromBatch({
    required List<UserSummary> users,
    required Object? nextCursor,
  }) =>
      PaginatedUsers(
        users: users,
        nextCursor: nextCursor,
        hasReachedEnd: nextCursor == null || users.isEmpty,
      );

  /// The terminal empty state: nothing loaded, nothing more to load.
  factory PaginatedUsers.empty() => const PaginatedUsers(
        users: <UserSummary>[],
        nextCursor: null,
        hasReachedEnd: true,
      );

  /// The users in this batch, in the order the API returned them.
  final List<UserSummary> users;

  /// Opaque cursor for the next request; null at the end of the list.
  final Object? nextCursor;

  /// True when there is nothing further to fetch.
  ///
  /// Stored rather than derived from `nextCursor == null` alone, because the
  /// two end signals are not the same thing: an empty batch is terminal even
  /// if a stale cursor is still lying around.
  final bool hasReachedEnd;

  /// Copy helper. [nextCursor] is nullable, so "leave alone" and "clear"
  /// cannot both be expressed by passing null.
  PaginatedUsers copyWith({
    List<UserSummary>? users,
    Object? nextCursor,
    bool clearNextCursor = false,
    bool? hasReachedEnd,
  }) =>
      PaginatedUsers(
        users: users ?? this.users,
        nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
        hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      );

  @override
  List<Object?> get props => <Object?>[users, nextCursor, hasReachedEnd];
}
