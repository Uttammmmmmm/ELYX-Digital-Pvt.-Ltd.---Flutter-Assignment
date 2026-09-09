/// Wire + Hive representation of [UserSummary].
library;

import 'package:hive_ce/hive.dart';

import '../../../../core/storage/hive_type_ids.dart';
import '../../domain/entities/user_summary.dart';
import 'json_parsing.dart';

part 'user_summary_model.g.dart';

/// [UserSummary] plus JSON and Hive serialization.
///
/// Extends the entity and declares NO storage of its own -- the `@HiveField`
/// getters below delegate straight to the inherited fields via `super`, so
/// there is exactly one copy of every value. Annotating them here rather than
/// on the entity is what keeps `domain/` free of any Hive import.
@HiveType(typeId: HiveTypeIds.userSummary)
class UserSummaryModel extends UserSummary {
  const UserSummaryModel({
    required super.id,
    required super.login,
    required super.avatarUrl,
    required super.htmlUrl,
    required super.type,
    required super.siteAdmin,
  });

  /// Parses one element of a `GET /users` array.
  ///
  /// Every field is coerced rather than cast. A single malformed record must
  /// not throw away the whole batch: GitHub occasionally returns a numeric id
  /// as a string, and a null where a string is documented. `whereType` at the
  /// call site drops entries that are not objects at all; this handles the
  /// ones that are objects but wrong inside.
  factory UserSummaryModel.fromJson(Map<String, dynamic> json) =>
      UserSummaryModel(
        id: asInt(json, 'id'),
        login: asString(json, 'login'),
        avatarUrl: asString(json, 'avatar_url'),
        htmlUrl: asString(json, 'html_url'),
        type: asString(json, 'type', fallback: 'User'),
        siteAdmin: asBool(json, 'site_admin'),
      );

  /// Narrows an entity back to a model.
  factory UserSummaryModel.fromEntity(UserSummary user) => UserSummaryModel(
        id: user.id,
        login: user.login,
        avatarUrl: user.avatarUrl,
        htmlUrl: user.htmlUrl,
        type: user.type,
        siteAdmin: user.siteAdmin,
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
  String get type => super.type;

  @HiveField(5)
  @override
  bool get siteAdmin => super.siteAdmin;

  /// Emits GitHub's own field names, so a payload survives a round trip.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'login': login,
        'avatar_url': avatarUrl,
        'html_url': htmlUrl,
        'type': type,
        'site_admin': siteAdmin,
      };
}
