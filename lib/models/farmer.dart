import 'package:hive/hive.dart';

part 'farmer.g.dart';

@HiveType(typeId: 0)
class Farmer extends HiveObject {
  @HiveField(0)
  int farmerId;

  @HiveField(1)
  String fname;

  @HiveField(2)
  String lname;

  @HiveField(3)
  String centerName;

  @HiveField(4)
  String contact;

  Farmer({
    required this.farmerId,
    required this.fname,
    required this.lname,
    required this.centerName,
    required this.contact,
  });

  factory Farmer.fromJson(Map<String, dynamic> json) {
    return Farmer(
      farmerId: json['farmerID'] is int ? json['farmerID'] : int.parse('${json['farmerID']}'),
      fname: json['fname']?.toString() ?? '',
      lname: json['lname']?.toString() ?? '',
      centerName: json['center_name']?.toString() ?? json['centerName']?.toString() ?? '',
      contact: json['contact1']?.toString() ?? json['contact']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'farmerID': farmerId,
        'fname': fname,
        'lname': lname,
        'center_name': centerName,
        'contact1': contact,
      };
}
