// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final typeId = 3;

  @override
  UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile(
      pubkey: fields[0] as String,
      rawData: (fields[10] as Map).cast<String, dynamic>(),
      createdAt: fields[11] as DateTime,
      eventId: fields[12] as String,
      name: fields[1] as String?,
      displayName: fields[2] as String?,
      about: fields[3] as String?,
      picture: fields[4] as String?,
      banner: fields[5] as String?,
      website: fields[6] as String?,
      nip05: fields[7] as String?,
      lud16: fields[8] as String?,
      lud06: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.pubkey)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.displayName)
      ..writeByte(3)
      ..write(obj.about)
      ..writeByte(4)
      ..write(obj.picture)
      ..writeByte(5)
      ..write(obj.banner)
      ..writeByte(6)
      ..write(obj.website)
      ..writeByte(7)
      ..write(obj.nip05)
      ..writeByte(8)
      ..write(obj.lud16)
      ..writeByte(9)
      ..write(obj.lud06)
      ..writeByte(10)
      ..write(obj.rawData)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.eventId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
