import 'package:hive/hive.dart';

part 'milk_collection.g.dart';

@HiveType(typeId: 1)
class MilkCollection extends HiveObject {
  @HiveField(0)
  int farmerId;

  @HiveField(1)
  String date;

  @HiveField(2)
  double morning;

  @HiveField(3)
  double evening;

  @HiveField(4)
  double rejected;

  @HiveField(5)
  bool isSynced;

  @HiveField(6)
  String? center_name;

  @HiveField(7)
  String? fname;

  @HiveField(8)
  String? lname;

  MilkCollection({
    required this.farmerId,
    required this.date,
    required this.morning,
    required this.evening,
    required this.rejected,
    required this.isSynced,
    this.center_name,
    this.fname,
    this.lname,
  });

  Map<String, dynamic> toJson() {
    return {
      "farmerID": farmerId,
      "collection_date": date,
      "morning": morning,
      "evening": evening,
      "rejected": rejected,
      "center_name": center_name,
      "fname": fname,
      "lname": lname,
    };
  }
}
