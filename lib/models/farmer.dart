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

  @HiveField(5)
  double monthlyTotal;

  @HiveField(6)
  double yearlyTotal;

  @HiveField(7)
  int? centerId;

  Farmer({
    required this.farmerId,
    required this.fname,
    required this.lname,
    required this.centerName,
    required this.contact,
    this.monthlyTotal = 0.0,
    this.yearlyTotal = 0.0,
    this.centerId,
  });

  factory Farmer.fromJson(Map<String, dynamic> json) {
    try {
      return Farmer(
        farmerId: json['farmerID'] is int
            ? json['farmerID']
            : int.parse('${json['farmerID']}'),
        fname: json['fname']?.toString() ?? '',
        lname: json['lname']?.toString() ?? '',
        centerName:
            json['center_name']?.toString() ??
            json['centerName']?.toString() ??
            '',
        contact:
            json['contact1']?.toString() ?? json['contact']?.toString() ?? '',
        monthlyTotal: _safeDouble(json['monthly_total']),
        yearlyTotal: _safeDouble(json['yearly_total']),
        centerId: json['center_id'] is int
            ? json['center_id']
            : (json['center_id'] != null
                  ? int.tryParse('${json['center_id']}')
                  : null),
      );
    } catch (e) {
      print('Error parsing farmer: $e');
      rethrow;
    }
  }

  static double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() => {
    'farmerID': farmerId,
    'fname': fname,
    'lname': lname,
    'center_name': centerName,
    'contact1': contact,
    'monthly_total': monthlyTotal,
    'yearly_total': yearlyTotal,
    'center_id': centerId,
  };
}