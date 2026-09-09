import 'package:elyx_digital_assignment/features/users/domain/entities/user_detail.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/entity_fixtures.dart';

void main() {
  group('displayName -- never blank, whichever source supplied the user', () {
    test('prefers a real name', () {
      expect(
        reqresDetail(1, first: 'George', last: 'Bluth').displayName,
        'George Bluth',
      );
    });

    test('falls back to the handle when there is no name', () {
      expect(githubDetail(1, 'mojombo').displayName, 'mojombo');
    });

    test('falls back to the id when there is neither', () {
      const UserSummary bare = UserSummary(
        id: 7,
        detailId: '7',
        avatarUrl: 'a',
      );
      expect(const UserDetail(user: bare).displayName, 'User 7');
    });

    test('tolerates a blank half of the name', () {
      final UserDetail d = UserDetail(
        user: UserSummary(
          id: 1,
          detailId: '1',
          avatarUrl: 'a',
          firstName: 'George',
          lastName: '   ',
        ),
      );
      expect(d.displayName, 'George');
    });
  });

  group('hasEmail', () {
    test('is true when the source provides one (reqres always does)', () {
      expect(reqresDetail(1).hasEmail, isTrue);
    });

    test('is false when absent -- the common case on GitHub', () {
      expect(githubDetail(1, 'mojombo').hasEmail, isFalse);
    });
  });

  group('hasStats', () {
    test('is true when the source provides counters', () {
      expect(githubDetail(1, 'mojombo').hasStats, isTrue);
    });

    test('is false on a source without them, so the UI hides the row rather '
        'than showing three zeros', () {
      expect(reqresDetail(1).hasStats, isFalse);
    });
  });

  test('the entity exposes no phone concept at all', () {
    // A compile-time guarantee: `UserDetail` has no `phone` member, so the UI
    // cannot render fabricated data. NEITHER supported API has a phone field,
    // so this is a documented gap, not an unimplemented feature.
    final UserDetail detail = reqresDetail(1);
    expect(
      detail.props.length,
      9,
      reason: 'adding a phone field would be modelling data no source has',
    );
  });
}
