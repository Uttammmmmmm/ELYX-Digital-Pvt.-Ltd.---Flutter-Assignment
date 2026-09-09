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
/// Purely a data-layer type -- it has no domain counterpart, because
/// "when was this written" is a caching concern the domain has no opinion on.
/// [toEntity] converts to [PaginatedUsers] at the repository boundary.
///
/// Storing [requestedSince] as well as [nextSince] is what makes
/// `getAllCachedUsers()` possible: it records WHICH request produced this
/// batch, so cached batches can be walked back into their original cursor
/// order rather than whatever order Hive happens to return keys in.
@HiveType(typeId: HiveTypeIds.cachedPage)
class CachedPageModel {
  const CachedPageModel({
    required this.users,
    required this.nextSince,
    required this.requestedSince,
    required this.cachedAt,
  });

  /// The users in this batch, in the order GitHub returned them.
  @HiveField(0)
  final List<UserSummaryModel> users;

  /// Cursor for the NEXT batch; null at the end of the list.
  @HiveField(1)
  final int? nextSince;

  /// The `since` value this batch was requested with; null for the first
  /// batch. This is the cache key in field form.
  @HiveField(2)
  final int? requestedSince;

  /// When this batch was written to disk.
  @HiveField(3)
  final DateTime cachedAt;

  /// True once this batch is older than [ttl].
  ///
  /// Staleness and usability are separate questions: a stale batch is still
  /// perfectly renderable, and the repository deliberately serves one rather
  /// than showing an error when the network is unavailable. Nothing here
  /// deletes anything.
  bool isStale(Duration ttl, {DateTime? now}) =>
      (now ?? DateTime.now()).difference(cachedAt) > ttl;

  /// Age of this batch, for "updated 5 minutes ago" copy.
  Duration ageFrom(DateTime now) {
    final Duration d = now.difference(cachedAt);
    return d.isNegative ? Duration.zero : d;
  }

  /// Converts to the domain type.
  ///
  /// `hasReachedEnd` is derived the same way the network path derives it, so
  /// a cached batch and a live one are indistinguishable to the domain.
  PaginatedUsers toEntity() => PaginatedUsers.fromBatch(
        users: users,
        nextSince: nextSince,
      );

  /// Builds a cache record from a freshly-fetched batch.
  factory CachedPageModel.fromEntity(
    PaginatedUsers page, {
    required int? requestedSince,
    DateTime? now,
  }) =>
      CachedPageModel(
        users: page.users
            .map((UserSummary u) => UserSummaryModel.fromEntity(u))
            .toList(growable: false),
        nextSince: page.nextSince,
        requestedSince: requestedSince,
        cachedAt: now ?? DateTime.now(),
      );
}
