part of 'user_summary_model.dart';

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
      detailId: fields[1] as String,
      avatarUrl: fields[2] as String,
      handle: fields[3] as String?,
      firstName: fields[4] as String?,
      lastName: fields[5] as String?,
      email: fields[6] as String?,
      profileUrl: fields[7] as String?,
      accountType: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, UserSummaryModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.detailId)
      ..writeByte(2)
      ..write(obj.avatarUrl)
      ..writeByte(3)
      ..write(obj.handle)
      ..writeByte(4)
      ..write(obj.firstName)
      ..writeByte(5)
      ..write(obj.lastName)
      ..writeByte(6)
      ..write(obj.email)
      ..writeByte(7)
      ..write(obj.profileUrl)
      ..writeByte(8)
      ..write(obj.accountType);
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
