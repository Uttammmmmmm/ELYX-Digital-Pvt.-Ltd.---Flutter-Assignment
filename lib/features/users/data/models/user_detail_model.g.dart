// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_detail_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

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
      id: (fields[0] as num).toInt(),
      login: fields[1] as String,
      avatarUrl: fields[2] as String,
      htmlUrl: fields[3] as String,
      publicRepos: (fields[4] as num).toInt(),
      followers: (fields[5] as num).toInt(),
      following: (fields[6] as num).toInt(),
      createdAt: fields[7] as DateTime,
      name: fields[8] as String?,
      email: fields[9] as String?,
      bio: fields[10] as String?,
      company: fields[11] as String?,
      location: fields[12] as String?,
      blog: fields[13] as String?,
      cachedAt: fields[14] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, UserDetailModel obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.login)
      ..writeByte(2)
      ..write(obj.avatarUrl)
      ..writeByte(3)
      ..write(obj.htmlUrl)
      ..writeByte(4)
      ..write(obj.publicRepos)
      ..writeByte(5)
      ..write(obj.followers)
      ..writeByte(6)
      ..write(obj.following)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.name)
      ..writeByte(9)
      ..write(obj.email)
      ..writeByte(10)
      ..write(obj.bio)
      ..writeByte(11)
      ..write(obj.company)
      ..writeByte(12)
      ..write(obj.location)
      ..writeByte(13)
      ..write(obj.blog)
      ..writeByte(14)
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
