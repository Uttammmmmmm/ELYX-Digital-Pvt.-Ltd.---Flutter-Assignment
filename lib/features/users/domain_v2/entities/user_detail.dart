/// The user as the DETAIL endpoint returns it.
library;

import 'package:equatable/equatable.dart';

/// A full profile from `GET /users/{login}`.
///
/// CONSTRAINT (c): [name], [email], [bio], [company], [location] and [blog]
/// are nullable because GitHub genuinely returns null for them. `email` in
/// particular is null for most accounts -- that is the common case, not an
/// edge case. They are NOT given defaults here: substituting a fallback is a
/// presentation decision, and an entity that invents data is an entity that
/// lies to every consumer downstream.
///
/// THERE IS DELIBERATELY NO `phone` FIELD. The GitHub API exposes no phone
/// number anywhere -- this is not a value that happens to be null, it is a
/// concept the source system does not have. Modelling it as `String? phone`
/// would assert that a phone number is *possible*, and every consumer would
/// then have to handle a case that can never occur. The UI instead renders an
/// explicit unavailable state ("Not provided by GitHub API"), styled so it
/// cannot be mistaken for real data, sourced from a presentation constant
/// rather than from this entity. Fabricating a plausible-looking number --
/// deterministic or otherwise -- would be inventing data the API never gave us.
class UserDetail extends Equatable {
  const UserDetail({
    required this.id,
    required this.login,
    required this.avatarUrl,
    required this.htmlUrl,
    required this.publicRepos,
    required this.followers,
    required this.following,
    required this.createdAt,
    this.name,
    this.email,
    this.bio,
    this.company,
    this.location,
    this.blog,
  });

  /// Numeric account id.
  final int id;

  /// Unique handle. Always present, which is what makes [displayName] safe.
  final String login;

  /// Avatar image URL.
  final String avatarUrl;

  /// Public profile URL on github.com.
  final String htmlUrl;

  /// Public repository count.
  final int publicRepos;

  /// Follower count.
  final int followers;

  /// Following count.
  final int following;

  /// Account creation timestamp.
  final DateTime createdAt;

  /// Display name. Null when the user never set one.
  final String? name;

  /// Public email. Null for most users -- hidden by default.
  final String? email;

  /// Profile bio.
  final String? bio;

  /// Self-reported company.
  final String? company;

  /// Self-reported location, free text.
  final String? location;

  /// Personal site URL.
  final String? blog;

  /// The name to show in a header, falling back to the handle.
  ///
  /// Cannot return empty: [login] is always present. This lives on the entity
  /// rather than in the UI because "a user is identified by their name, or
  /// their handle if they have no name" is a rule about the domain, not about
  /// any one screen -- a second client would make the same choice.
  String get displayName => name ?? login;

  /// Whether a public email exists to render or link.
  ///
  /// Saves every call site from repeating a null check and, more usefully,
  /// gives the absence a name.
  bool get hasEmail => email != null;

  @override
  List<Object?> get props => <Object?>[
        id,
        login,
        avatarUrl,
        htmlUrl,
        publicRepos,
        followers,
        following,
        createdAt,
        name,
        email,
        bio,
        company,
        location,
        blog,
      ];
}
