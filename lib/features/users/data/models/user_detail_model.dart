/// Wire + Hive representation of [UserDetail].
library;

import 'package:hive_ce/hive.dart';

import '../../../../core/storage/hive_type_ids.dart';
import '../../domain/entities/user_detail.dart';
import 'json_parsing.dart';

part 'user_detail_model.g.dart';

/// [UserDetail] plus JSON and Hive serialization.
///
/// As with [UserSummaryModel], the `@HiveField` getters delegate to inherited
/// fields via `super` -- no duplicated storage, and no Hive import in the
/// domain layer.
@HiveType(typeId: HiveTypeIds.userDetail)
class UserDetailModel extends UserDetail {
  const UserDetailModel({
    required super.id,
    required super.login,
    required super.avatarUrl,
    required super.htmlUrl,
    required super.publicRepos,
    required super.followers,
    required super.following,
    required super.createdAt,
    super.name,
    super.email,
    super.bio,
    super.company,
    super.location,
    super.blog,
    this.cachedAt,
  });

  /// Parses a `GET /users/{login}` document.
  factory UserDetailModel.fromJson(Map<String, dynamic> json) =>
      UserDetailModel(
        id: asInt(json, 'id'),
        login: asString(json, 'login'),
        avatarUrl: asString(json, 'avatar_url'),
        htmlUrl: asString(json, 'html_url'),
        publicRepos: asInt(json, 'public_repos'),
        followers: asInt(json, 'followers'),
        following: asInt(json, 'following'),
        // created_at is ISO 8601. Parsed with tryParse, never parse: a bad
        // timestamp must not throw away an otherwise-valid profile. The
        // entity declares this non-nullable, so a miss falls back to the
        // epoch -- an obviously-wrong sentinel, deliberately not
        // DateTime.now(), which would read as a real brand-new account.
        createdAt: asOptionalDate(json, 'created_at') ?? _epoch,
        // Nullable by design -- constraint (c), no invented fallbacks.
        // asOptionalString trims and maps '' to null, which is what makes
        // GitHub's empty-string email (and blog, and company) read as the
        // absence it actually is rather than as a value.
        name: asOptionalString(json, 'name'),
        email: asOptionalString(json, 'email'),
        bio: asOptionalString(json, 'bio'),
        company: asOptionalString(json, 'company'),
        location: asOptionalString(json, 'location'),
        blog: asOptionalString(json, 'blog'),
      );

  static final DateTime _epoch =
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  /// When this profile was written to the cache; null before it is stored.
  ///
  /// A data-layer-only field with no domain counterpart -- freshness is a
  /// caching concern, not a fact about the user. It lives here rather than in
  /// a parallel timestamp box so a profile and its age cannot get out of sync.
  @HiveField(14)
  final DateTime? cachedAt;

  /// True once this profile is older than [ttl]. Unstamped records are
  /// treated as stale, so a pre-cachedAt cache entry is refetched rather
  /// than trusted forever.
  bool isStale(Duration ttl, {DateTime? now}) {
    final DateTime? at = cachedAt;
    if (at == null) return true;
    return (now ?? DateTime.now()).difference(at) > ttl;
  }

  /// Returns a copy stamped with the current time, for writing to the cache.
  UserDetailModel withCacheStamp({DateTime? now}) => UserDetailModel(
        id: id,
        login: login,
        avatarUrl: avatarUrl,
        htmlUrl: htmlUrl,
        publicRepos: publicRepos,
        followers: followers,
        following: following,
        createdAt: createdAt,
        name: name,
        email: email,
        bio: bio,
        company: company,
        location: location,
        blog: blog,
        cachedAt: now ?? DateTime.now(),
      );

  @HiveField(0)
  @override
  int get id => super.id;

  @HiveField(1)
  @override
  String get login => super.login;

  @HiveField(2)
  @override
  String get avatarUrl => super.avatarUrl;

  @HiveField(3)
  @override
  String get htmlUrl => super.htmlUrl;

  @HiveField(4)
  @override
  int get publicRepos => super.publicRepos;

  @HiveField(5)
  @override
  int get followers => super.followers;

  @HiveField(6)
  @override
  int get following => super.following;

  @HiveField(7)
  @override
  DateTime get createdAt => super.createdAt;

  @HiveField(8)
  @override
  String? get name => super.name;

  @HiveField(9)
  @override
  String? get email => super.email;

  @HiveField(10)
  @override
  String? get bio => super.bio;

  @HiveField(11)
  @override
  String? get company => super.company;

  @HiveField(12)
  @override
  String? get location => super.location;

  @HiveField(13)
  @override
  String? get blog => super.blog;

  /// Emits GitHub's field names, so a payload survives a round trip.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'login': login,
        'avatar_url': avatarUrl,
        'html_url': htmlUrl,
        'public_repos': publicRepos,
        'followers': followers,
        'following': following,
        'created_at': createdAt.toIso8601String(),
        'name': name,
        'email': email,
        'bio': bio,
        'company': company,
        'location': location,
        'blog': blog,
      };
}
