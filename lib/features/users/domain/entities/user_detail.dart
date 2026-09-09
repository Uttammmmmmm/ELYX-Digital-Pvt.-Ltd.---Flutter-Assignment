/// The user as a DETAIL endpoint returns it.
library;

import 'package:equatable/equatable.dart';

import 'user_summary.dart';

/// A full profile, in a shape neither API dictates.
///
/// Composes [UserSummary] because the detail response of both sources is a
/// superset of their list response. Everything GitHub-only ([bio], [company],
/// [publicRepos] …) is nullable, because reqres simply does not return it —
/// and the UI hides a null optional field rather than rendering a blank.
///
/// THERE IS DELIBERATELY NO `phone` FIELD, AND THAT IS NOT AN OVERSIGHT.
/// NEITHER API HAS ONE. reqres returns id, email, first_name, last_name and
/// avatar; GitHub has no phone concept at any scope. The assignment asks for
/// a phone number, so the detail screen renders an explicit unavailable state
/// — never a fabricated value, not even a deterministic one, because a
/// plausible-looking number is indistinguishable from real data to anyone
/// reading the screen. Modelling `String? phone` would assert a phone is
/// *possible*; omitting the field makes the fabrication unrepresentable.
class UserDetail extends Equatable {
  const UserDetail({
    required this.user,
    this.bio,
    this.company,
    this.location,
    this.blog,
    this.publicRepos,
    this.followers,
    this.following,
    this.createdAt,
  });

  /// The fields shared with the list representation.
  final UserSummary user;

  /// Profile bio. GitHub only.
  final String? bio;

  /// Self-reported company. GitHub only.
  final String? company;

  /// Self-reported location. GitHub only.
  final String? location;

  /// Personal site URL. GitHub only.
  final String? blog;

  /// Public repository count. GitHub only.
  final int? publicRepos;

  /// Follower count. GitHub only.
  final int? followers;

  /// Following count. GitHub only.
  final int? following;

  /// Account creation time. GitHub only.
  final DateTime? createdAt;

  /// Passthroughs, so callers need not reach through [user].
  int get id => user.id;
  String get avatarUrl => user.avatarUrl;
  String? get handle => user.handle;
  String? get email => user.email;
  String? get profileUrl => user.profileUrl;

  /// The name to show. Never empty.
  String get displayName => user.displayName;

  /// Whether an email exists to render or copy.
  bool get hasEmail => email != null && email!.trim().isNotEmpty;

  /// Whether this source provided the public counters at all.
  ///
  /// False for reqres, whose profile has no stats — the row is hidden rather
  /// than rendered as three zeros, which would be fabricated data.
  bool get hasStats =>
      publicRepos != null || followers != null || following != null;

  @override
  List<Object?> get props => <Object?>[
        user,
        bio,
        company,
        location,
        blog,
        publicRepos,
        followers,
        following,
        createdAt,
      ];
}
