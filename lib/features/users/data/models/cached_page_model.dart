/// One cached batch of users, with the cursors that produced it.
library;

import 'package:hive_ce/hive.dart';

import '../../../../core/storage/hive_type_ids.dart';
import '../../domain/entities/paginated_users.dart';
import '../../domain/entities/user_summary.dart';
import 'user_summary_model.dart';

part 'cached_page_model.g.dart';

/// A persisted batch: the users, both cursors, and when it was written.
///
/// Purely a data-layer type -- "when was this written" is a caching concern
/// the domain has no opinion on. Storing [requestedCursor] as well as
/// [nextCursor] is what makes `getAllCachedUsers()` possible: it records WHICH
/// request produced this batch, so cached batches can be walked back into
/// their original order rather than Hive's insertion order.
@HiveType(typeId: HiveTypeIds.cachedPage)
class CachedPageModel {
  const CachedPageModel({
    required this.users,
    required this.nextCursor,
    required this.requestedCursor,
    required this.cachedAt,
  });

  /// Builds a cache record from a freshly-fetched batch.
  factory CachedPageModel.fromEntity(
    PaginatedUsers page, {
    required Object? requestedCursor,
    DateTime? now,
  }) =>
      CachedPageModel(
        users: page.users
            .map((UserSummary u) => UserSummaryModel.fromEntity(u))
            .toList(growable: false),
        nextCursor: page.nextCursor,
        requestedCursor: requestedCursor,
        cachedAt: now ?? DateTime.now(),
      );

  /// The users in this batch, in the order the API returned them.
  @HiveField(0)
  final List<UserSummaryModel> users;

  /// Cursor for the NEXT batch; null at the end of the list.
  @HiveField(1)
  final Object? nextCursor;

  /// The cursor this batch was requested with; null for the first batch.
  @HiveField(2)
  final Object? requestedCursor;

  /// When this batch was written to disk.
  @HiveField(3)
  final DateTime cachedAt;

  /// True once this batch is older than [ttl].
  ///
  /// Staleness and usability are separate questions: a stale batch is still
  /// renderable, and the repository deliberately serves one rather than
  /// showing an error when the network is unavailable.
  bool isStale(Duration ttl, {DateTime? now}) =>
      (now ?? DateTime.now()).difference(cachedAt) > ttl;

  /// Converts to the domain type, deriving `hasReachedEnd` exactly as the
  /// network path does, so a cached batch is indistinguishable from a live one.
  PaginatedUsers toEntity() =>
      PaginatedUsers.fromBatch(users: users, nextCursor: nextCursor);
}
