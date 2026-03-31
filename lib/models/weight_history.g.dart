// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weight_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WeightHistoryAdapter extends TypeAdapter<WeightHistory> {
  @override
  final int typeId = 0;

  @override
  WeightHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WeightHistory(
      weight: fields[0] as double,
      timestamp: fields[1] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, WeightHistory obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.weight)
      ..writeByte(1)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeightHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
