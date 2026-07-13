class TurnoverAllocationModel {
  final String destinationName;
  final double quantitySent;
  final String billingAccountNumber;
  final String vehicleNumberPlate;

  TurnoverAllocationModel({
    required this.destinationName,
    required this.quantitySent,
    required this.billingAccountNumber,
    required this.vehicleNumberPlate,
  });

  Map<String, dynamic> toMap() {
    return {
      'destinationName': destinationName,
      'quantitySent': quantitySent,
      'billingAccountNumber': billingAccountNumber,
      'vehicleNumberPlate': vehicleNumberPlate,
    };
  }

  factory TurnoverAllocationModel.fromMap(Map<String, dynamic> map) {
    return TurnoverAllocationModel(
      destinationName: map['destinationName'] ?? '',
      quantitySent: (map['quantitySent'] ?? 0.0) is int ? (map['quantitySent'] as int).toDouble() : (map['quantitySent'] ?? 0.0),
      billingAccountNumber: map['billingAccountNumber'] ?? '',
      vehicleNumberPlate: map['vehicleNumberPlate'] ?? '',
    );
  }
}

class TurnoverModel {
  final String turnoverId;
  final String farmerId;
  final String grapeType; // e.g. "Dry Grapes" or "Fresh Grapes"
  final double totalYield; // total tons grown
  final List<TurnoverAllocationModel> allocations;
  final String date; // YYYY-MM-DD
  final DateTime createdAt;
  final DateTime updatedAt;

  TurnoverModel({
    required this.turnoverId,
    required this.farmerId,
    required this.grapeType,
    required this.totalYield,
    required this.allocations,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'turnoverId': turnoverId,
      'farmerId': farmerId,
      'grapeType': grapeType,
      'totalYield': totalYield,
      'allocations': allocations.map((a) => a.toMap()).toList(),
      'date': date,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TurnoverModel.fromMap(Map<String, dynamic> map, String docId) {
    var rawAlloc = map['allocations'] as List? ?? [];
    List<TurnoverAllocationModel> allocList = rawAlloc
        .map((a) => TurnoverAllocationModel.fromMap(Map<String, dynamic>.from(a)))
        .toList();

    return TurnoverModel(
      turnoverId: docId,
      farmerId: map['farmerId'] ?? '',
      grapeType: map['grapeType'] ?? 'Fresh Grapes',
      totalYield: (map['totalYield'] ?? 0.0) is int ? (map['totalYield'] as int).toDouble() : (map['totalYield'] ?? 0.0),
      allocations: allocList,
      date: map['date'] ?? '',
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : DateTime.now(),
    );
  }
}
