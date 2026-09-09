/// Wire/cache representation of [GithubUser].
library;

import '../../domain/entities/github_user.dart';
import 'json_parsing.dart';

/// [GithubUser] plus JSON serialization.
///
/// Extends the entity so a model is usable anywhere an entity is expected, and
/// keeps `fromJson`/`toJson` out of the domain -- serialization is a data-layer
/// concern and the domain must not know GitHub's field names.
///
/// The SAME shape is used for the network response and the Hive cache. That is
/// the whole reason we do not need TypeAdapters: one encoding, exercised by
/// every request, so the cache path cannot silently drift from the API path.
class GithubUserModel extends GithubUser {
  const GithubUserModel({
    required super.id,
    required super.login,
    required super.avatarUrl,
    required super.htmlUrl,
    required super.type,
    required super.isSiteAdmin,
  });

  /// Parses one element of a `GET /users` array, or a nested user object.
  factory GithubUserModel.fromJson(Map<String, dynamic> json) =>
      GithubUserModel(
        id: asInt(json, 'id'),
        login: asString(json, 'login'),
        avatarUrl: asString(json, 'avatar_url'),
        htmlUrl: asString(json, 'html_url'),
        type: asString(json, 'type', fallback: 'User'),
        isSiteAdmin: asBool(json, 'site_admin'),
      );

  /// Narrows an entity back to a model (used when caching detail documents).
  factory GithubUserModel.fromEntity(GithubUser user) => GithubUserModel(
        id: user.id,
        login: user.login,
        avatarUrl: user.avatarUrl,
        htmlUrl: user.htmlUrl,
        type: user.type,
        isSiteAdmin: user.isSiteAdmin,
      );

  /// Emits GitHub's own field names so the cache round-trips through
  /// [GithubUserModel.fromJson] unchanged.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'login': login,
        'avatar_url': avatarUrl,
        'html_url': htmlUrl,
        'type': type,
        'site_admin': isSiteAdmin,
      };
}
