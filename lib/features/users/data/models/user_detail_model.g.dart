part of 'user_detail_model.dart';

class UserDetailModelAdapter extends TypeAdapter<UserDetailModel> {
  @override
  final typeId = 1;

  @override
  UserDetailModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserDetailModel(
      user: fields[0] as UserSummaryModel,
      bio: fields[1] as String?,
      company: fields[2] as String?,
      location: fields[3] as String?,
      blog: fields[4] as String?,
      publicRepos: (fields[5] as num?)?.toInt(),
      followers: (fields[6] as num?)?.toInt(),
      following: (fields[7] as num?)?.toInt(),
      createdAt: fields[8] as DateTime?,
      cachedAt: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, UserDetailModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.user)
      ..writeByte(1)
      ..write(obj.bio)
      ..writeByte(2)
      ..write(obj.company)
      ..writeByte(3)
      ..write(obj.location)
      ..writeByte(4)
      ..write(obj.blog)
      ..writeByte(5)
      ..write(obj.publicRepos)
      ..writeByte(6)
      ..write(obj.followers)
      ..writeByte(7)
      ..write(obj.following)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.cachedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserDetailModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
