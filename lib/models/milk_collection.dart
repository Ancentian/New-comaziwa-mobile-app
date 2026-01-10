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

  @HiveField(9)
  int? serverId; // ID from server after sync

  @HiveField(10)
  int? createdById; // ID of user/employee who created this record

  @HiveField(11)
  String? createdByType; // Type: 'admin', 'user', 'employee', 'grader'

  @HiveField(12)
  String? memberNo; // The member number/display ID like "F001" from farmers.farmerID

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
    this.serverId,
    this.createdById,
    this.createdByType,
    this.memberNo,
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
      "server_id": serverId,
      "created_by_id": createdById,
      "created_by_type": createdByType,
      "member_no": memberNo,
    };
  }

  /// Create MilkCollection from API response
  factory MilkCollection.fromJson(Map<String, dynamic> json) {
    return MilkCollection(
      farmerId: json['farmer_db_id'] ?? json['farmer_id'] ?? 0,
      date: json['collection_date'] ?? '',
      morning: (json['morning'] ?? 0).toDouble(),
      evening: (json['evening'] ?? 0).toDouble(),
      rejected: (json['rejected'] ?? 0).toDouble(),
      isSynced: true, // From server = already synced
      center_name: json['center_name'],
      fname: json['fname'],
      lname: json['lname'],
      serverId: json['id'],
      createdById: json['created_by_id'],
      createdByType: json['created_by_type'],
      memberNo: json['farmerID'], // Parse the member code from API
    );
  }
}
