import 'package:hive/hive.dart';

part 'record.g.dart';

@HiveType(typeId: 1)
class Record extends HiveObject {
  @HiveField(0)
  int? id; // ID from server

  @HiveField(1)
  String name;

  @HiveField(2)
  String value;

  @HiveField(3)
  bool isSynced;

  Record({
    this.id,
    required this.name,
    required this.value,
    this.isSynced = false,
  });
}
