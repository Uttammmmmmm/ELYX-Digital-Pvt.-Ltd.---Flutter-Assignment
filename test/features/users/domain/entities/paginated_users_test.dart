import 'package:elyx_digital_assignment/features/users/domain/entities/paginated_users.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart';
import 'package:flutter_test/flutter_test.dart';

const UserSummary _u = UserSummary(
  id: 1,
  detailId: 'mojombo',
      handle: 'mojombo',
  avatarUrl: 'a',
  profileUrl: 'h',
  accountType: 'User',
);

void main() {
  group('fromBatch derives hasReachedEnd (constraint a)', () {
    test('a cursor and users means there is more to load', () {
      final PaginatedUsers page = PaginatedUsers.fromBatch(
        users: const <UserSummary>[_u],
        nextCursor: 1,
      );
      expect(page.hasReachedEnd, isFalse);
      expect(page.nextCursor, 1);
    });

    test('a null cursor is the end of the list', () {
      final PaginatedUsers page = PaginatedUsers.fromBatch(
        users: const <UserSummary>[_u],
        nextCursor: null,
      );
      expect(page.hasReachedEnd, isTrue);
    });

    test('an empty batch is the end even when a cursor is present', () {
      final PaginatedUsers page = PaginatedUsers.fromBatch(
        users: const <UserSummary>[],
        nextCursor: 99,
      );
      expect(page.hasReachedEnd, isTrue);
    });
  });

  test('empty() is terminal and carries nothing', () {
    final PaginatedUsers page = PaginatedUsers.empty();
    expect(page.users, isEmpty);
    expect(page.nextCursor, isNull);
    expect(page.hasReachedEnd, isTrue);
  });

  group('copyWith', () {
    final PaginatedUsers base = PaginatedUsers.fromBatch(
      users: const <UserSummary>[_u],
      nextCursor: 7,
    );

    test('leaves untouched fields alone', () {
      expect(base.copyWith(), base);
    });

    test('replaces the cursor', () {
      expect(base.copyWith(nextCursor: 9).nextCursor, 9);
    });

    test('clearNextCursor nulls the cursor -- passing null cannot', () {
      expect(base.copyWith(nextCursor: null).nextCursor, 7,
          reason: 'null means "unchanged"');
      expect(base.copyWith(clearNextCursor: true).nextCursor, isNull);
    });
  });
}
