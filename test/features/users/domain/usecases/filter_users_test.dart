import 'package:elyx_digital_assignment/features/users/domain/entities/github_user.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/filter_users.dart';
import 'package:flutter_test/flutter_test.dart';

GithubUser _user(int id, String login) => GithubUser(
      id: id,
      login: login,
      avatarUrl: 'https://avatars.githubusercontent.com/u/$id?v=4',
      htmlUrl: 'https://github.com/$login',
      type: 'User',
      isSiteAdmin: false,
    );

void main() {
  const FilterUsers filterUsers = FilterUsers();

  final List<GithubUser> users = <GithubUser>[
    _user(1, 'mojombo'),
    _user(2, 'defunkt'),
    _user(3, 'octocat'),
  ];

  test('an empty or whitespace query returns the original list unchanged', () {
    expect(
      filterUsers(FilterUsersParams(users: users, query: '')),
      same(users),
    );
    expect(
      filterUsers(FilterUsersParams(users: users, query: '   ')),
      same(users),
    );
  });

  test('matches login case-insensitively as a substring', () {
    final List<GithubUser> result =
        filterUsers(FilterUsersParams(users: users, query: 'OCTO'));

    expect(result.map((GithubUser u) => u.login), <String>['octocat']);
  });

  test('matches a known name even though the list endpoint has none '
      '(constraint b + e)', () {
    final List<GithubUser> result = filterUsers(
      FilterUsersParams(
        users: users,
        query: 'preston',
        knownNames: const <String, String>{'mojombo': 'Tom Preston-Werner'},
      ),
    );

    expect(result.map((GithubUser u) => u.login), <String>['mojombo']);
  });

  test('users with no cached name are still searchable by login', () {
    final List<GithubUser> result = filterUsers(
      FilterUsersParams(
        users: users,
        query: 'defunkt',
        knownNames: const <String, String>{'mojombo': 'Tom Preston-Werner'},
      ),
    );

    expect(result.map((GithubUser u) => u.login), <String>['defunkt']);
  });

  test('preserves original ordering so the list does not jump while typing', () {
    final List<GithubUser> result =
        filterUsers(FilterUsersParams(users: users, query: 'o'));

    expect(
      result.map((GithubUser u) => u.login),
      <String>['mojombo', 'octocat'],
    );
  });

  test('returns empty on no match', () {
    expect(
      filterUsers(FilterUsersParams(users: users, query: 'zzzz')),
      isEmpty,
    );
  });
}
