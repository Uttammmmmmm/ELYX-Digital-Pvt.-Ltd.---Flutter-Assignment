/// Wire/cache representation of [UserSummary].
library;

import '../../domain/entities/user_summary.dart';
import 'json_parsing.dart';

/// [UserSummary] plus JSON serialization.
///
/// Extends the entity so a model is usable anywhere an entity is expected,
/// and keeps `fromJson`/`toJson` out of the domain -- GitHub's field names are
/// a data-layer concern.
///
/// The SAME shape serves the network response and the Hive cache, which is
/// why no TypeAdapters are needed: one encoding, exercised by every request,
/// so the cache path cannot silently drift from the API path.
class UserSummaryModel extends UserSummary {
  const UserSummaryModel({
    required super.id,
    required super.login,
    required super.avatarUrl,
    required super.htmlUrl,
    required super.type,
    required super.siteAdmin,
  });

  /// Parses one element of a `GET /users` array.
  factory UserSummaryModel.fromJson(Map<String, dynamic> json) =>
      UserSummaryModel(
        id: asInt(json, 'id'),
        login: asString(json, 'login'),
        avatarUrl: asString(json, 'avatar_url'),
        htmlUrl: asString(json, 'html_url'),
        type: asString(json, 'type', fallback: 'User'),
        siteAdmin: asBool(json, 'site_admin'),
      );

  /// Narrows an entity back to a model, for caching.
  factory UserSummaryModel.fromEntity(UserSummary user) => UserSummaryModel(
        id: user.id,
        login: user.login,
        avatarUrl: user.avatarUrl,
        htmlUrl: user.htmlUrl,
        type: user.type,
        siteAdmin: user.siteAdmin,
      );

  /// Emits GitHub's own field names so a cached entry round-trips through
  /// [UserSummaryModel.fromJson] unchanged.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'login': login,
        'avatar_url': avatarUrl,
        'html_url': htmlUrl,
        'type': type,
        'site_admin': siteAdmin,
      };
}
