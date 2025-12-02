// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'milk_collection.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MilkCollectionAdapter extends TypeAdapter<MilkCollection> {
  @override
  final int typeId = 2;

  @override
  MilkCollection read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MilkCollection(
      id: fields[0] as int?,
      farmerId: fields[1] as int,
      date: fields[2] as String,
      morning: fields[3] as double,
      evening: fields[4] as double,
      rejected: fields[5] as double,
      isSynced: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, MilkCollection obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.farmerId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.morning)
      ..writeByte(4)
      ..write(obj.evening)
      ..writeByte(5)
      ..write(obj.rejected)
      ..writeByte(6)
      ..write(obj.isSynced);
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
