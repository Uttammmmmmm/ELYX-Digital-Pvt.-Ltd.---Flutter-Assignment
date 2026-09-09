library;

import 'package:hive_ce/hive.dart';

import '../../../../core/storage/hive_type_ids.dart';
import '../../domain/entities/paginated_users.dart';
import '../../domain/entities/user_summary.dart';
import 'user_summary_model.dart';

part 'cached_page_model.g.dart';

@HiveType(typeId: HiveTypeIds.cachedPage)
class CachedPageModel {
  const CachedPageModel({
    required this.users,
    required this.nextCursor,
    required this.requestedCursor,
    required this.cachedAt,
  });

  factory CachedPageModel.fromEntity(
    PaginatedUsers page, {
    required Object? requestedCursor,
    DateTime? now,
  }) => CachedPageModel(
    users: page.users
        .map((UserSummary u) => UserSummaryModel.fromEntity(u))
        .toList(growable: false),
    nextCursor: page.nextCursor,
    requestedCursor: requestedCursor,
    cachedAt: now ?? DateTime.now(),
  );

  @HiveField(0)
  final List<UserSummaryModel> users;

  @HiveField(1)
  final Object? nextCursor;

  @HiveField(2)
  final Object? requestedCursor;

  @HiveField(3)
  final DateTime cachedAt;

  bool isStale(Duration ttl, {DateTime? now}) =>
      (now ?? DateTime.now()).difference(cachedAt) > ttl;

  PaginatedUsers toEntity() =>
      PaginatedUsers.fromBatch(users: users, nextCursor: nextCursor);
}
