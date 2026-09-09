/// Wire/cache representation of [UsersPage].
library;

import '../../../../core/network/link_header_parser.dart';
import '../../domain/entities/github_user.dart';
import '../../domain/entities/users_page.dart';
import 'github_user_model.dart';

/// [UsersPage] plus serialization, and the cursor derivation.
///
/// Constraint (a) is resolved entirely inside this class. The next cursor
/// comes from the `Link` header's `rel="next"`; when that is absent (GitHub
/// omits it on the final page) we fall back to the last item's id, and an
/// empty array means the end. Above this file, the cursor is opaque.
class UsersPageModel extends UsersPage {
  const UsersPageModel({required super.users, required super.nextCursor});

  /// Builds a page from a `GET /users` response body and its `Link` header.
  ///
  /// [linkHeader] is authoritative: honouring it lets the UI stop paginating
  /// without spending a request to discover an empty array -- which matters
  /// against a 60/hour budget. The last-id fallback exists only for proxies
  /// and mocks that strip the header.
  factory UsersPageModel.fromResponse(
    List<dynamic> body, {
    String? linkHeader,
  }) {
    final List<GithubUserModel> users = body
        .whereType<Map<String, dynamic>>()
        .map(GithubUserModel.fromJson)
        .toList(growable: false);

    // An empty page is unconditionally the end, regardless of any header.
    if (users.isEmpty) {
      return const UsersPageModel(
        users: <GithubUser>[],
        nextCursor: null,
      );
    }

    final int? fromHeader = LinkHeaderParser.nextSince(linkHeader);

    return UsersPageModel(
      users: users,
      // No header at all -> fall back to the last id. A header that exists but
      // carries no `next` rel is a genuine end-of-list, so it stays null.
      nextCursor:
          fromHeader ?? (linkHeader == null ? users.last.id : null),
    );
  }

  /// Restores a page from the cache envelope written by [toJson].
  factory UsersPageModel.fromJson(Map<String, dynamic> json) {
    final Object? rawUsers = json['users'];
    final List<GithubUserModel> users = rawUsers is List
        ? rawUsers
            .whereType<Map<String, dynamic>>()
            .map(GithubUserModel.fromJson)
            .toList(growable: false)
        : const <GithubUserModel>[];

    final Object? cursor = json['nextCursor'];
    return UsersPageModel(
      users: users,
      nextCursor: cursor is int ? cursor : null,
    );
  }

  /// Cache envelope. Unlike the other models this is NOT GitHub's shape --
  /// the cursor lives in a response header, not the body, so there is no
  /// upstream shape to mirror.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'users': users
            .map((GithubUser u) => GithubUserModel.fromEntity(u).toJson())
            .toList(growable: false),
        'nextCursor': nextCursor,
      };
}
