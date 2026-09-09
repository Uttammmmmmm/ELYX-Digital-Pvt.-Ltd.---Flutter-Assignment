// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_summary_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserSummaryModelAdapter extends TypeAdapter<UserSummaryModel> {
  @override
  final typeId = 0;

  @override
  UserSummaryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserSummaryModel(
      id: (fields[0] as num).toInt(),
      login: fields[1] as String,
      avatarUrl: fields[2] as String,
      htmlUrl: fields[3] as String,
      type: fields[4] as String,
      siteAdmin: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, UserSummaryModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.login)
      ..writeByte(2)
      ..write(obj.avatarUrl)
      ..writeByte(3)
      ..write(obj.htmlUrl)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.siteAdmin);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSummaryModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
