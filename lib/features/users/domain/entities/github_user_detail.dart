/// The user as it appears in a detail response.
library;

import 'package:equatable/equatable.dart';

import 'github_user.dart';

/// A GitHub user profile from `GET /users/{login}`.
///
/// Composes rather than extends [GithubUser]: the list fields are genuinely
/// the same data, and composition keeps "which endpoint did this come from"
/// legible at every call site.
///
/// Constraint (c): [name], [email], [bio] and [location] are nullable because
/// GitHub really does return null for them -- `email` especially, since users
/// hide it by default. They are NOT given fallbacks here; inventing data is a
/// presentation decision and belongs in the presentation layer.
///
/// There is deliberately no `phone` field. GitHub has no such concept, and a
/// `String? phone` that is always null would be a lie the type says is
/// possible. The detail screen renders that row as a hardcoded, non-data
/// placeholder.
class GithubUserDetail extends Equatable {
  const GithubUserDetail({
    required this.user,
    required this.publicRepos,
    required this.publicGists,
    required this.followers,
    required this.following,
    this.name,
    this.email,
    this.bio,
    this.location,
    this.company,
    this.blog,
    this.createdAt,
  });

  /// The fields shared with the list representation.
  final GithubUser user;

  /// Public repository count.
  final int publicRepos;

  /// Public gist count.
  final int publicGists;

  /// Follower count.
  final int followers;

  /// Following count.
  final int following;

  /// Display name. Null when the user never set one.
  final String? name;

  /// Public email. Null for most users -- the common case, not the edge case.
  final String? email;

  /// Profile bio.
  final String? bio;

  /// Self-reported location, free text.
  final String? location;

  /// Self-reported company.
  final String? company;

  /// Personal site URL. May be an empty string rather than null.
  final String? blog;

  /// Account creation time.
  final DateTime? createdAt;

  /// Convenience passthroughs so callers need not reach through [user].
  int get id => user.id;
  String get login => user.login;
  String get avatarUrl => user.avatarUrl;
  String get htmlUrl => user.htmlUrl;

  @override
  List<Object?> get props => <Object?>[
        user,
        publicRepos,
        publicGists,
        followers,
        following,
        name,
        email,
        bio,
        location,
        company,
        blog,
        createdAt,
      ];
}
