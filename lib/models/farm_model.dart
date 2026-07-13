class FarmModel {
  final String farmId;
  final String farmName;
  final String crop; // Default is "Grapes"
  final double acres;
  final String location;
  final String soilType;
  final DateTime createdAt;
  final DateTime updatedAt;

  FarmModel({
    required this.farmId,
    required this.farmName,
    this.crop = "Grapes",
    required this.acres,
    required this.location,
    this.soilType = "",
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'farmId': farmId,
      'farmName': farmName,
      'crop': crop,
      'acres': acres,
      'location': location,
      'soilType': soilType,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FarmModel.fromMap(Map<String, dynamic> map, String id) {
    return FarmModel(
      farmId: id,
      farmName: map['farmName'] ?? '',
      crop: map['crop'] ?? 'Grapes',
      acres: (map['acres'] ?? 0.0) is int ? (map['acres'] as int).toDouble() : (map['acres'] ?? 0.0),
      location: map['location'] ?? '',
      soilType: map['soilType'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  FarmModel copyWith({
    String? farmName,
    double? acres,
    String? location,
    String? soilType,
    DateTime? updatedAt,
  }) {
    return FarmModel(
      farmId: farmId,
      farmName: farmName ?? this.farmName,
      crop: crop,
      acres: acres ?? this.acres,
      location: location ?? this.location,
      soilType: soilType ?? this.soilType,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
