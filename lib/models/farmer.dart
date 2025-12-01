import 'package:hive/hive.dart';

part 'farmer.g.dart';

@HiveType(typeId: 1)
class Farmer {
  @HiveField(0)
  final int farmerId;

  @HiveField(1)
  final String fname;

  @HiveField(2)
  final String lname;

  @HiveField(3)
  final String centerName;

  @HiveField(4)
  final String contact;

  Farmer({
    required this.farmerId,
    required this.fname,
    required this.lname,
    required this.centerName,
    required this.contact,
  });

  factory Farmer.fromJson(Map<String, dynamic> json) {
    return Farmer(
      farmerId: json['farmerID'],
      fname: json['fname'],
      lname: json['lname'],
      centerName: json['center_name'],
      contact: json['contact1'],
    );
  }
}
