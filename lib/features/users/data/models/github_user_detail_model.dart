/// Wire/cache representation of [GithubUserDetail].
library;

import '../../domain/entities/github_user_detail.dart';
import 'github_user_model.dart';
import 'json_parsing.dart';

/// [GithubUserDetail] plus JSON serialization.
///
/// `GET /users/{login}` returns a superset of the list object, so the shared
/// fields are parsed by [GithubUserModel] rather than duplicated here.
class GithubUserDetailModel extends GithubUserDetail {
  const GithubUserDetailModel({
    required super.user,
    required super.publicRepos,
    required super.publicGists,
    required super.followers,
    required super.following,
    super.name,
    super.email,
    super.bio,
    super.location,
    super.company,
    super.blog,
    super.createdAt,
  });

  /// Parses a `GET /users/{login}` document.
  factory GithubUserDetailModel.fromJson(Map<String, dynamic> json) =>
      GithubUserDetailModel(
        user: GithubUserModel.fromJson(json),
        publicRepos: asInt(json, 'public_repos'),
        publicGists: asInt(json, 'public_gists'),
        followers: asInt(json, 'followers'),
        following: asInt(json, 'following'),
        // Nullable by design -- see constraint (c). No fallbacks here.
        name: asOptionalString(json, 'name'),
        email: asOptionalString(json, 'email'),
        bio: asOptionalString(json, 'bio'),
        location: asOptionalString(json, 'location'),
        company: asOptionalString(json, 'company'),
        blog: asOptionalString(json, 'blog'),
        createdAt: asOptionalDate(json, 'created_at'),
      );

  /// Emits GitHub's field names, flattened exactly as the API returns them,
  /// so a cached document is re-parseable by [GithubUserDetailModel.fromJson].
  Map<String, dynamic> toJson() => <String, dynamic>{
        ...GithubUserModel.fromEntity(user).toJson(),
        'public_repos': publicRepos,
        'public_gists': publicGists,
        'followers': followers,
        'following': following,
        'name': name,
        'email': email,
        'bio': bio,
        'location': location,
        'company': company,
        'blog': blog,
        'created_at': createdAt?.toIso8601String(),
      };
}
