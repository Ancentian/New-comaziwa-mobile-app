// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'farmer.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FarmerAdapter extends TypeAdapter<Farmer> {
  @override
  final int typeId = 0;

  @override
  Farmer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Farmer(
      farmerId: fields[0] as int,
      fname: fields[1] as String,
      lname: fields[2] as String,
      centerName: fields[3] as String,
      contact: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Farmer obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.farmerId)
      ..writeByte(1)
      ..write(obj.fname)
      ..writeByte(2)
      ..write(obj.lname)
      ..writeByte(3)
      ..write(obj.centerName)
      ..writeByte(4)
      ..write(obj.contact);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FarmerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
