library;

import 'package:equatable/equatable.dart';

import 'user_summary.dart';

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

  final UserSummary user;

  final String? bio;

  final String? company;

  final String? location;

  final String? blog;

  final int? publicRepos;

  final int? followers;

  final int? following;

  final DateTime? createdAt;

  int get id => user.id;
  String get avatarUrl => user.avatarUrl;
  String? get handle => user.handle;
  String? get email => user.email;
  String? get profileUrl => user.profileUrl;

  String get displayName => user.displayName;

  bool get hasEmail => email != null && email!.trim().isNotEmpty;

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
