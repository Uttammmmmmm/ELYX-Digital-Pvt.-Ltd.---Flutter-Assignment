// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cached_page_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CachedPageModelAdapter extends TypeAdapter<CachedPageModel> {
  @override
  final typeId = 2;

  @override
  CachedPageModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedPageModel(
      users: (fields[0] as List).cast<UserSummaryModel>(),
      nextSince: (fields[1] as num?)?.toInt(),
      requestedSince: (fields[2] as num?)?.toInt(),
      cachedAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CachedPageModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.users)
      ..writeByte(1)
      ..write(obj.nextSince)
      ..writeByte(2)
      ..write(obj.requestedSince)
      ..writeByte(3)
      ..write(obj.cachedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedPageModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
