import 'package:elyx_digital_assignment/features/users/domain/entities/paginated_users.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart';
import 'package:flutter_test/flutter_test.dart';

const UserSummary _u = UserSummary(
  id: 1,
  login: 'mojombo',
  avatarUrl: 'a',
  htmlUrl: 'h',
  type: 'User',
  siteAdmin: false,
);

void main() {
  group('fromBatch derives hasReachedEnd (constraint a)', () {
    test('a cursor and users means there is more to load', () {
      final PaginatedUsers page = PaginatedUsers.fromBatch(
        users: const <UserSummary>[_u],
        nextSince: 1,
      );
      expect(page.hasReachedEnd, isFalse);
      expect(page.nextSince, 1);
    });

    test('a null cursor is the end of the list', () {
      final PaginatedUsers page = PaginatedUsers.fromBatch(
        users: const <UserSummary>[_u],
        nextSince: null,
      );
      expect(page.hasReachedEnd, isTrue);
    });

    test('an empty batch is the end even when a cursor is present', () {
      final PaginatedUsers page = PaginatedUsers.fromBatch(
        users: const <UserSummary>[],
        nextSince: 99,
      );
      expect(page.hasReachedEnd, isTrue);
    });
  });

  test('empty() is terminal and carries nothing', () {
    final PaginatedUsers page = PaginatedUsers.empty();
    expect(page.users, isEmpty);
    expect(page.nextSince, isNull);
    expect(page.hasReachedEnd, isTrue);
  });

  group('copyWith', () {
    final PaginatedUsers base = PaginatedUsers.fromBatch(
      users: const <UserSummary>[_u],
      nextSince: 7,
    );

    test('leaves untouched fields alone', () {
      expect(base.copyWith(), base);
    });

    test('replaces the cursor', () {
      expect(base.copyWith(nextSince: 9).nextSince, 9);
    });

    test('clearNextSince nulls the cursor -- passing null cannot', () {
      expect(base.copyWith(nextSince: null).nextSince, 7,
          reason: 'null means "unchanged"');
      expect(base.copyWith(clearNextSince: true).nextSince, isNull);
    });
  });
}
