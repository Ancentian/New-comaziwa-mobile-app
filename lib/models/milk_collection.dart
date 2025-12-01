import 'package:hive/hive.dart';

part 'milk_collection.g.dart';

@HiveType(typeId: 2)
class MilkCollection extends HiveObject {
  @HiveField(0)
  int? id; // optional: assigned by server

  @HiveField(1)
  int farmerId;

  @HiveField(2)
  String date; // 'yyyy-MM-dd'

  @HiveField(3)
  double morning;

  @HiveField(4)
  double evening;

  @HiveField(5)
  double rejected;

  @HiveField(6)
  bool isSynced;

  MilkCollection({
    this.id,
    required this.farmerId,
    required this.date,
    required this.morning,
    required this.evening,
    required this.rejected,
    this.isSynced = false,
  });
}
