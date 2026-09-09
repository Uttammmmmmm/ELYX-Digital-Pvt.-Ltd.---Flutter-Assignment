library;

import 'package:hive_ce/hive.dart';

import '../../../../core/storage/hive_type_ids.dart';
import '../../domain/entities/user_summary.dart';

part 'user_summary_model.g.dart';

@HiveType(typeId: HiveTypeIds.userSummary)
class UserSummaryModel extends UserSummary {
  const UserSummaryModel({
    required super.id,
    required super.detailId,
    required super.avatarUrl,
    super.handle,
    super.firstName,
    super.lastName,
    super.email,
    super.profileUrl,
    super.accountType,
  });

  factory UserSummaryModel.fromEntity(UserSummary user) => UserSummaryModel(
    id: user.id,
    detailId: user.detailId,
    avatarUrl: user.avatarUrl,
    handle: user.handle,
    firstName: user.firstName,
    lastName: user.lastName,
    email: user.email,
    profileUrl: user.profileUrl,
    accountType: user.accountType,
  );

  @HiveField(0)
  @override
  int get id => super.id;

  @HiveField(1)
  @override
  String get detailId => super.detailId;

  @HiveField(2)
  @override
  String get avatarUrl => super.avatarUrl;

  @HiveField(3)
  @override
  String? get handle => super.handle;

  @HiveField(4)
  @override
  String? get firstName => super.firstName;

  @HiveField(5)
  @override
  String? get lastName => super.lastName;

  @HiveField(6)
  @override
  String? get email => super.email;

  @HiveField(7)
  @override
  String? get profileUrl => super.profileUrl;

  @HiveField(8)
  @override
  String? get accountType => super.accountType;
}
