class MilkCollection {
  int? id;
  String farmerId;
  double liters;
  String date;
  int synced;

  MilkCollection({
    this.id,
    required this.farmerId,
    required this.liters,
    required this.date,
    this.synced = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'farmer_id': farmerId,
      'liters': liters,
      'date': date,
      'synced': synced,
    };
  }

  factory MilkCollection.fromMap(Map<String, dynamic> map) {
    return MilkCollection(
      id: map['id'],
      farmerId: map['farmer_id'],
      liters: map['liters'],
      date: map['date'],
      synced: map['synced'],
    );
  }
}
