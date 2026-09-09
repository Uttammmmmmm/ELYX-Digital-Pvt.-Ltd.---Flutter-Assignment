/// Wire/cache representation of [PaginatedUsers].
library;

import '../../../../core/network/link_header_parser.dart';
import '../../domain/entities/paginated_users.dart';
import '../../domain/entities/user_summary.dart';
import 'user_summary_model.dart';

/// [PaginatedUsers] plus serialization and cursor derivation.
///
/// Constraint (a) is resolved entirely inside this class. Above it, the
/// cursor is opaque.
class PaginatedUsersModel extends PaginatedUsers {
  const PaginatedUsersModel({
    required super.users,
    required super.nextSince,
    required super.hasReachedEnd,
  });

  /// Builds a page from a `GET /users` body and its `Link` header.
  ///
  /// The header is authoritative: honouring it lets the UI stop paginating
  /// without spending a request to discover an empty array, which matters
  /// against a 60/hour budget. The last-id fallback covers proxies and mocks
  /// that strip the header.
  factory PaginatedUsersModel.fromResponse(
    List<dynamic> body, {
    String? linkHeader,
  }) {
    final List<UserSummaryModel> users = body
        .whereType<Map<String, dynamic>>()
        .map(UserSummaryModel.fromJson)
        .toList(growable: false);

    // An empty batch is unconditionally the end, whatever the header says.
    if (users.isEmpty) {
      return const PaginatedUsersModel(
        users: <UserSummary>[],
        nextSince: null,
        hasReachedEnd: true,
      );
    }

    final int? fromHeader = LinkHeaderParser.nextSince(linkHeader);
    // No header at all -> fall back to the last id. A header that exists but
    // carries no `next` rel is a genuine end-of-list, so it stays null.
    final int? nextSince =
        fromHeader ?? (linkHeader == null ? users.last.id : null);

    return PaginatedUsersModel(
      users: users,
      nextSince: nextSince,
      hasReachedEnd: nextSince == null,
    );
  }

  /// Restores a page from the cache envelope written by [toJson].
  factory PaginatedUsersModel.fromJson(Map<String, dynamic> json) {
    final Object? rawUsers = json['users'];
    final List<UserSummaryModel> users = rawUsers is List
        ? rawUsers
            .whereType<Map<String, dynamic>>()
            .map(UserSummaryModel.fromJson)
            .toList(growable: false)
        : const <UserSummaryModel>[];

    final Object? cursor = json['nextSince'];
    final int? nextSince = cursor is int ? cursor : null;

    return PaginatedUsersModel(
      users: users,
      nextSince: nextSince,
      hasReachedEnd: nextSince == null || users.isEmpty,
    );
  }

  /// Cache envelope. Unlike the other models this is NOT GitHub's shape --
  /// the cursor lives in a response header, not the body, so there is no
  /// upstream shape to mirror.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'users': users
            .map((UserSummary u) => UserSummaryModel.fromEntity(u).toJson())
            .toList(growable: false),
        'nextSince': nextSince,
      };
}
