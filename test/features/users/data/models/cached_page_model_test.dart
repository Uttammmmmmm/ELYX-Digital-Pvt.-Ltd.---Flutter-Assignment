import 'package:elyx_digital_assignment/features/users/data/models/cached_page_model.dart';
import 'package:elyx_digital_assignment/features/users/data/models/user_summary_model.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/paginated_users.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/entity_fixtures.dart';

void main() {
  final UserSummaryModel user = UserSummaryModel.fromEntity(reqresUser(1));

  group('isStale', () {
    final DateTime now = DateTime.utc(2026, 9, 9, 12);

    CachedPageModel at(Duration age) => CachedPageModel(
          users: <UserSummaryModel>[user],
          nextCursor: 2,
          requestedCursor: 1,
          cachedAt: now.subtract(age),
        );

    test('is fresh inside the TTL', () {
      expect(
        at(const Duration(minutes: 5))
            .isStale(const Duration(minutes: 15), now: now),
        isFalse,
      );
    });

    test('is stale past the TTL', () {
      expect(
        at(const Duration(minutes: 16))
            .isStale(const Duration(minutes: 15), now: now),
        isTrue,
      );
    });

    test('a stale batch is still readable -- staleness is not deletion', () {
      expect(at(const Duration(days: 30)).users, hasLength(1));
    });
  });

  group('toEntity', () {
    test('derives hasReachedEnd exactly as the network path does', () {
      final PaginatedUsers page = CachedPageModel(
        users: <UserSummaryModel>[user],
        nextCursor: 2,
        requestedCursor: 1,
        cachedAt: DateTime.now(),
      ).toEntity();

      expect(page.users, hasLength(1));
      expect(page.nextCursor, 2);
      expect(page.hasReachedEnd, isFalse);
    });

    test('a null cursor round trips as the end of the list', () {
      final CachedPageModel cached = CachedPageModel(
        users: <UserSummaryModel>[user],
        nextCursor: null,
        requestedCursor: 2,
        cachedAt: DateTime.now(),
      );

      expect(cached.toEntity().hasReachedEnd, isTrue);
    });
  });

  group('fromEntity', () {
    test('records the cursor that requested the batch', () {
      final CachedPageModel cached = CachedPageModel.fromEntity(
        PaginatedUsers.fromBatch(
          users: <UserSummary>[reqresUser(1)],
          nextCursor: 2,
        ),
        requestedCursor: 1,
      );

      expect(cached.requestedCursor, 1,
          reason: 'needed to rebuild order in getAllCachedUsers');
      expect(cached.nextCursor, 2);
      expect(cached.users.single.id, 1);
    });

    test('carries a GitHub-shaped cursor unchanged -- it is opaque', () {
      final CachedPageModel cached = CachedPageModel.fromEntity(
        PaginatedUsers.fromBatch(
          users: <UserSummary>[githubUser(1, 'mojombo')],
          nextCursor: 2868,
        ),
        requestedCursor: 47,
      );

      expect(cached.requestedCursor, 47);
      expect(cached.nextCursor, 2868);
    });
  });
}
