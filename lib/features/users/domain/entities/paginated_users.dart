/// One batch of users plus the cursor that follows it.
library;

import 'package:equatable/equatable.dart';

import 'user_summary.dart';

/// A page of users and the cursor for the next page.
///
/// CONSTRAINT (a): `GET /users` is CURSOR-paginated via `since`, not
/// offset-paginated -- a `page` parameter is accepted and silently ignored.
/// [nextSince] is the `since` value for the following request, taken from the
/// `Link` header's `rel="next"` entry.
///
/// Everything above the data layer treats [nextSince] as OPAQUE: the Bloc
/// stores it and hands it straight back. Nothing here knows or cares that it
/// happens to be the last user's id, which is what lets a different backend
/// with string tokens drop in without touching this file.
class PaginatedUsers extends Equatable {
  const PaginatedUsers({
    required this.users,
    required this.nextSince,
    required this.hasReachedEnd,
  });

  /// Builds a batch and derives [hasReachedEnd] from the two signals GitHub
  /// gives us: an absent `rel="next"` cursor, or an empty array.
  ///
  /// Preferring the header means the UI can stop paginating WITHOUT spending
  /// a request to discover an empty page -- which matters at 60/hour.
  factory PaginatedUsers.fromBatch({
    required List<UserSummary> users,
    required int? nextSince,
  }) =>
      PaginatedUsers(
        users: users,
        nextSince: nextSince,
        hasReachedEnd: nextSince == null || users.isEmpty,
      );

  /// The terminal empty state: nothing loaded, nothing more to load.
  ///
  /// Used as a Bloc's initial value and as the result of a request that came
  /// back empty, so callers never handle a null page.
  factory PaginatedUsers.empty() => const PaginatedUsers(
        users: <UserSummary>[],
        nextSince: null,
        hasReachedEnd: true,
      );

  /// The users in this batch, in the order GitHub returned them.
  final List<UserSummary> users;

  /// Opaque cursor for the next request; null at the end of the list.
  final int? nextSince;

  /// True when there is nothing further to fetch.
  ///
  /// Stored rather than derived from `nextSince == null` alone, because the
  /// two end-of-list signals are not the same thing: an empty batch is
  /// terminal even if a stale cursor is still lying around.
  final bool hasReachedEnd;

  /// Copy helper.
  ///
  /// [nextSince] is nullable, so "leave it alone" and "clear it" cannot both
  /// be expressed by passing null -- [clearNextSince] disambiguates. Reaching
  /// the end of the list is exactly the case that needs the clear.
  PaginatedUsers copyWith({
    List<UserSummary>? users,
    int? nextSince,
    bool clearNextSince = false,
    bool? hasReachedEnd,
  }) =>
      PaginatedUsers(
        users: users ?? this.users,
        nextSince: clearNextSince ? null : (nextSince ?? this.nextSince),
        hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      );

  @override
  List<Object?> get props => <Object?>[users, nextSince, hasReachedEnd];
}
