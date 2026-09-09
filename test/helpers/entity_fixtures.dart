/// Builders for domain entities, so tests state only what they care about.
library;

import 'package:elyx_digital_assignment/features/users/domain/entities/user_detail.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart';

/// A reqres-shaped user: real names, an email, no handle.
UserSummary reqresUser(int id, {String? first, String? last, String? email}) =>
    UserSummary(
      id: id,
      detailId: '$id',
      avatarUrl: 'https://reqres.in/img/faces/$id-image.jpg',
      firstName: first ?? 'First$id',
      lastName: last ?? 'Last$id',
      email: email ?? 'user$id@reqres.in',
    );

/// A GitHub-shaped user: a handle, no name, no email.
UserSummary githubUser(int id, String handle) => UserSummary(
  id: id,
  detailId: handle,
  avatarUrl: 'https://avatars.githubusercontent.com/u/$id?v=4',
  handle: handle,
  profileUrl: 'https://github.com/$handle',
  accountType: 'User',
);

/// A profile with no source-specific extras -- the reqres shape.
UserDetail reqresDetail(int id, {String? first, String? last, String? email}) =>
    UserDetail(
      user: reqresUser(id, first: first, last: last, email: email),
    );

/// A profile with GitHub's extras populated.
UserDetail githubDetail(
  int id,
  String handle, {
  String? bio,
  String? company,
  String? location,
  String? blog,
  DateTime? createdAt,
}) => UserDetail(
  user: githubUser(id, handle),
  bio: bio,
  company: company,
  location: location,
  blog: blog,
  publicRepos: 66,
  followers: 23000,
  following: 11,
  createdAt: createdAt ?? DateTime.utc(2007, 10, 20),
);
