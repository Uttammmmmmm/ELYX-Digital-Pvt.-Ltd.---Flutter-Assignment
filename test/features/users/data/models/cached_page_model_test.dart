import 'package:elyx_digital_assignment/features/users/data/models/cached_page_model.dart';
import 'package:elyx_digital_assignment/features/users/data/models/user_summary_model.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/paginated_users.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart';
import 'package:flutter_test/flutter_test.dart';

const UserSummaryModel _u = UserSummaryModel(
  id: 47,
  login: 'mojombo',
  avatarUrl: 'a',
  htmlUrl: 'h',
  type: 'User',
  siteAdmin: false,
);

void main() {
  group('isStale', () {
    final DateTime now = DateTime.utc(2026, 9, 9, 12);

    CachedPageModel at(Duration age) => CachedPageModel(
          users: const <UserSummaryModel>[_u],
          nextSince: 47,
          requestedSince: null,
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

    test('age never goes negative on a clock skew', () {
      expect(at(const Duration(minutes: -5)).ageFrom(now), Duration.zero);
    });
  });

  group('toEntity', () {
    test('derives hasReachedEnd exactly as the network path does', () {
      final CachedPageModel cached = CachedPageModel(
        users: const <UserSummaryModel>[_u],
        nextSince: 47,
        requestedSince: null,
        cachedAt: DateTime.now(),
      );

      final PaginatedUsers page = cached.toEntity();

      expect(page.users, hasLength(1));
      expect(page.nextSince, 47);
      expect(page.hasReachedEnd, isFalse);
    });

    test('a null cursor round trips as the end of the list', () {
      final CachedPageModel cached = CachedPageModel(
        users: const <UserSummaryModel>[_u],
        nextSince: null,
        requestedSince: 47,
        cachedAt: DateTime.now(),
      );

      expect(cached.toEntity().hasReachedEnd, isTrue);
    });
  });

  group('fromEntity', () {
    test('records the cursor that requested the batch', () {
      final CachedPageModel cached = CachedPageModel.fromEntity(
        PaginatedUsers.fromBatch(
          users: const <UserSummary>[_u],
          nextSince: 99,
        ),
        requestedSince: 47,
      );

      expect(cached.requestedSince, 47,
          reason: 'needed to rebuild cursor order in getAllCachedUsers');
      expect(cached.nextSince, 99);
      expect(cached.users.single.id, 47);
    });
  });
}
