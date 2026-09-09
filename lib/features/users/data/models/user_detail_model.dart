/// Wire/cache representation of [UserDetail].
library;

import '../../domain/entities/user_detail.dart';
import 'json_parsing.dart';

/// [UserDetail] plus JSON serialization.
class UserDetailModel extends UserDetail {
  const UserDetailModel({
    required super.id,
    required super.login,
    required super.avatarUrl,
    required super.htmlUrl,
    required super.publicRepos,
    required super.followers,
    required super.following,
    required super.createdAt,
    super.name,
    super.email,
    super.bio,
    super.company,
    super.location,
    super.blog,
  });

  /// Parses a `GET /users/{login}` document.
  factory UserDetailModel.fromJson(Map<String, dynamic> json) =>
      UserDetailModel(
        id: asInt(json, 'id'),
        login: asString(json, 'login'),
        avatarUrl: asString(json, 'avatar_url'),
        htmlUrl: asString(json, 'html_url'),
        publicRepos: asInt(json, 'public_repos'),
        followers: asInt(json, 'followers'),
        following: asInt(json, 'following'),
        // The entity declares createdAt non-nullable, so a malformed or
        // missing timestamp needs a value. Epoch is used as an obviously-wrong
        // sentinel rather than DateTime.now(), which would look like a real
        // brand-new account. GitHub always sends this for real profiles; the
        // fallback exists so one bad field cannot fail the whole parse.
        createdAt: asOptionalDate(json, 'created_at') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        // Nullable by design -- constraint (c). No invented fallbacks here.
        name: asOptionalString(json, 'name'),
        email: asOptionalString(json, 'email'),
        bio: asOptionalString(json, 'bio'),
        company: asOptionalString(json, 'company'),
        location: asOptionalString(json, 'location'),
        blog: asOptionalString(json, 'blog'),
      );

  /// Emits GitHub's field names, so a cached document is re-parseable by
  /// [UserDetailModel.fromJson].
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'login': login,
        'avatar_url': avatarUrl,
        'html_url': htmlUrl,
        'public_repos': publicRepos,
        'followers': followers,
        'following': following,
        'created_at': createdAt.toIso8601String(),
        'name': name,
        'email': email,
        'bio': bio,
        'company': company,
        'location': location,
        'blog': blog,
      };
}
