import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/filter_users.dart';
import 'package:flutter_test/flutter_test.dart';

UserSummary _u(int id, String login) => UserSummary(
  id: id,
  detailId: login,
  handle: login,
  avatarUrl: 'https://avatars.githubusercontent.com/u/$id?v=4',
  profileUrl: 'https://github.com/$login',
  accountType: 'User',
);

void main() {
  const FilterUsers filter = FilterUsers();

  final List<UserSummary> users = <UserSummary>[
    _u(1, 'mojombo'),
    _u(2, 'defunkt'),
    _u(3, 'OctoCat'),
    _u(4, 'pre-commit'),
  ];

  List<String> logins(List<UserSummary> result) =>
      result.map((UserSummary u) => u.displayName).toList();

  List<UserSummary> run(String query, {List<UserSummary>? input}) =>
      filter(FilterUsersParams(users: input ?? users, query: query));

  group('empty and whitespace queries', () {
    test('an empty query returns the SAME list instance', () {
      expect(run(''), same(users));
    });

    test('a whitespace-only query returns the same instance', () {
      expect(run('   '), same(users));
    });

    test('a tab/newline-only query counts as empty', () {
      expect(run('\t\n  '), same(users));
    });

    test('leading and trailing whitespace is trimmed before matching', () {
      expect(logins(run('  mojo  ')), <String>['mojombo']);
    });

    test('internal whitespace runs collapse to a single space', () {
      expect(run('mo   jo'), run('mo jo'));
    });

    test(
      'a multi-word query matches nothing -- logins cannot contain spaces',
      () {
        expect(run('mojo mbo'), isEmpty);
      },
    );
  });

  group('casing', () {
    test('an uppercase query matches a lowercase login', () {
      expect(logins(run('MOJO')), <String>['mojombo']);
    });

    test('a lowercase query matches a mixed-case login', () {
      expect(logins(run('octo')), <String>['OctoCat']);
    });

    test('dotted/dotless I follows Unicode default mapping, not a locale', () {
      final List<UserSummary> input = <UserSummary>[_u(9, 'IstanbulDev')];
      expect(logins(run('istanbul', input: input)), <String>['IstanbulDev']);
    });
  });

  group('matching semantics', () {
    test('matches a substring, not only a prefix', () {
      expect(logins(run('jomb')), <String>['mojombo']);
    });

    test('matches a full login exactly', () {
      expect(logins(run('defunkt')), <String>['defunkt']);
    });

    test('no match returns an empty list, never null', () {
      expect(run('zzzzz'), isEmpty);
    });

    test('preserves the original ordering', () {
      expect(logins(run('o')), <String>['mojombo', 'OctoCat', 'pre-commit']);
    });

    test('does not mutate the input list', () {
      final List<UserSummary> input = <UserSummary>[...users];
      run('mojo', input: input);
      expect(input, hasLength(4));
    });

    test('an empty input list yields an empty result', () {
      expect(run('mojo', input: const <UserSummary>[]), isEmpty);
    });

    test('a hyphen in a login is matched literally', () {
      expect(logins(run('pre-commit')), <String>['pre-commit']);
    });
  });

  group('regex metacharacters are literals', () {
    test('. is not a wildcard', () {
      expect(run('m.jombo'), isEmpty);
    });

    test('* is literal', () {
      expect(run('moj*'), isEmpty);
    });

    test('+ is literal', () {
      expect(run('moj+'), isEmpty);
    });

    test('? is literal', () {
      expect(run('moj?'), isEmpty);
    });

    test('an unbalanced [ returns empty instead of throwing', () {
      expect(() => run('user['), returnsNormally);
      expect(run('user['), isEmpty);
    });

    test('] is literal', () {
      expect(run('a]b'), isEmpty);
    });

    test('an unbalanced ( returns empty instead of throwing', () {
      expect(() => run('('), returnsNormally);
      expect(run('('), isEmpty);
    });

    test(') is literal', () {
      expect(run(')'), isEmpty);
    });

    test('^ is not an anchor', () {
      expect(run('^mojombo'), isEmpty);
    });

    test(r'$ is not an anchor', () {
      expect(run(r'mojombo$'), isEmpty);
    });

    test('a lone trailing backslash returns empty instead of throwing', () {
      expect(() => run('\\'), returnsNormally);
      expect(run('\\'), isEmpty);
    });

    test('| is not alternation -- it must match NEITHER side', () {
      expect(run('mojombo|defunkt'), isEmpty);
    });

    test('a login containing metacharacters is still matched literally', () {
      final List<UserSummary> input = <UserSummary>[_u(9, r'we.ird')];
      expect(logins(run('we.ird', input: input)), <String>[r'we.ird']);
    });
  });

  group('unicode', () {
    test('diacritics are NOT folded (documented behaviour)', () {
      final List<UserSummary> input = <UserSummary>[_u(9, 'josé')];
      expect(run('jose', input: input), isEmpty);
      expect(logins(run('josé', input: input)), <String>['josé']);
    });

    test('a non-ASCII query returns empty without throwing', () {
      expect(() => run('日本語'), returnsNormally);
      expect(run('日本語'), isEmpty);
    });
  });
}
