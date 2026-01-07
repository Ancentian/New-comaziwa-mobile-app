// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'milk_collection.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MilkCollectionAdapter extends TypeAdapter<MilkCollection> {
  @override
  final int typeId = 1;

  @override
  MilkCollection read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MilkCollection(
      farmerId: fields[0] as int,
      date: fields[1] as String,
      morning: fields[2] as double,
      evening: fields[3] as double,
      rejected: fields[4] as double,
      isSynced: fields[5] as bool,
      center_name: fields[6] as String?,
      fname: fields[7] as String?,
      lname: fields[8] as String?,
      serverId: fields[9] as int?,
      createdById: fields[10] as int?,
      createdByType: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MilkCollection obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.farmerId)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.morning)
      ..writeByte(3)
      ..write(obj.evening)
      ..writeByte(4)
      ..write(obj.rejected)
      ..writeByte(5)
      ..write(obj.isSynced)
      ..writeByte(6)
      ..write(obj.center_name)
      ..writeByte(7)
      ..write(obj.fname)
      ..writeByte(8)
      ..write(obj.lname)
      ..writeByte(9)
      ..write(obj.serverId)
      ..writeByte(10)
      ..write(obj.createdById)
      ..writeByte(11)
      ..write(obj.createdByType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MilkCollectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
