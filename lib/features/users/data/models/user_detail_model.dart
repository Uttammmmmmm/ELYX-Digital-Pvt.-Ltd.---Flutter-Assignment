/// Hive representation of [UserDetail].
library;

import 'package:hive_ce/hive.dart';

import '../../../../core/storage/hive_type_ids.dart';
import '../../domain/entities/user_detail.dart';
import '../../domain/entities/user_summary.dart';
import 'user_summary_model.dart';

part 'user_detail_model.g.dart';

/// [UserDetail] plus Hive persistence and a cache stamp.
@HiveType(typeId: HiveTypeIds.userDetail)
class UserDetailModel extends UserDetail {
  const UserDetailModel({
    required UserSummaryModel super.user,
    super.bio,
    super.company,
    super.location,
    super.blog,
    super.publicRepos,
    super.followers,
    super.following,
    super.createdAt,
    this.cachedAt,
  });

  /// Narrows an entity for caching.
  factory UserDetailModel.fromEntity(UserDetail detail, {DateTime? cachedAt}) =>
      UserDetailModel(
        user: UserSummaryModel.fromEntity(detail.user),
        bio: detail.bio,
        company: detail.company,
        location: detail.location,
        blog: detail.blog,
        publicRepos: detail.publicRepos,
        followers: detail.followers,
        following: detail.following,
        createdAt: detail.createdAt,
        cachedAt: cachedAt,
      );

  /// When this profile was written to the cache; null before it is stored.
  ///
  /// A data-layer-only field with no domain counterpart -- freshness is a
  /// caching concern, not a fact about the user. It lives here rather than in
  /// a parallel timestamp box so a profile and its age cannot get out of sync.
  @HiveField(9)
  final DateTime? cachedAt;

  @HiveField(0)
  @override
  UserSummary get user => super.user;

  @HiveField(1)
  @override
  String? get bio => super.bio;

  @HiveField(2)
  @override
  String? get company => super.company;

  @HiveField(3)
  @override
  String? get location => super.location;

  @HiveField(4)
  @override
  String? get blog => super.blog;

  @HiveField(5)
  @override
  int? get publicRepos => super.publicRepos;

  @HiveField(6)
  @override
  int? get followers => super.followers;

  @HiveField(7)
  @override
  int? get following => super.following;

  @HiveField(8)
  @override
  DateTime? get createdAt => super.createdAt;

  /// True once this profile is older than [ttl].
  ///
  /// Unstamped records read as stale, so a pre-`cachedAt` entry is refetched
  /// rather than trusted forever.
  bool isStale(Duration ttl, {DateTime? now}) {
    final DateTime? at = cachedAt;
    if (at == null) return true;
    return (now ?? DateTime.now()).difference(at) > ttl;
  }

  /// Returns a copy stamped with the current time, for writing to the cache.
  UserDetailModel withCacheStamp({DateTime? now}) =>
      UserDetailModel.fromEntity(this, cachedAt: now ?? DateTime.now());
}
