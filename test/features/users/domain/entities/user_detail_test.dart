import 'package:elyx_digital_assignment/features/users/domain/entities/user_detail.dart';
import 'package:flutter_test/flutter_test.dart';

UserDetail _detail({String? name, String? email}) => UserDetail(
      id: 1,
      login: 'mojombo',
      avatarUrl: 'a',
      htmlUrl: 'h',
      publicRepos: 66,
      followers: 23000,
      following: 11,
      createdAt: DateTime.utc(2007, 10, 20),
      name: name,
      email: email,
    );

void main() {
  group('displayName', () {
    test('uses the real name when set', () {
      expect(_detail(name: 'Tom Preston-Werner').displayName,
          'Tom Preston-Werner');
    });

    test('falls back to the login when the name is null (constraint c)', () {
      expect(_detail().displayName, 'mojombo');
    });

    test('is never empty -- login is always present', () {
      expect(_detail().displayName, isNotEmpty);
    });
  });

  group('hasEmail', () {
    test('is false when GitHub hid the email -- the common case', () {
      expect(_detail().hasEmail, isFalse);
    });

    test('is true when an email is public', () {
      expect(_detail(email: 'tom@example.com').hasEmail, isTrue);
    });
  });

  test('the entity exposes no phone concept at all (constraint c)', () {
    // Compile-time guarantee: `UserDetail` has no `phone` member, so the UI
    // cannot accidentally render fabricated data. This test documents the
    // decision -- if someone adds the field, the props list below changes and
    // this test is the breadcrumb explaining why it should not.
    final UserDetail detail = _detail();
    expect(detail.props.length, 14,
        reason: 'adding a phone field here would be modelling data GitHub '
            'does not have');
  });
}
