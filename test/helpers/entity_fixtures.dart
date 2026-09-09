library;

import 'package:elyx_digital_assignment/features/users/domain/entities/user_detail.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart';

UserSummary reqresUser(int id, {String? first, String? last, String? email}) =>
    UserSummary(
      id: id,
      detailId: '$id',
      avatarUrl: 'https://reqres.in/img/faces/$id-image.jpg',
      firstName: first ?? 'First$id',
      lastName: last ?? 'Last$id',
      email: email ?? 'user$id@reqres.in',
    );

UserSummary githubUser(int id, String handle) => UserSummary(
  id: id,
  detailId: handle,
  avatarUrl: 'https://avatars.githubusercontent.com/u/$id?v=4',
  handle: handle,
  profileUrl: 'https://github.com/$handle',
  accountType: 'User',
);

UserDetail reqresDetail(int id, {String? first, String? last, String? email}) =>
    UserDetail(
      user: reqresUser(id, first: first, last: last, email: email),
    );

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
