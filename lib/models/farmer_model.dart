class FarmerModel {
  final String farmerId;
  final String name;
  final String phone;
  final String village;
  final String preferredLanguage;
  final bool aiTrainingConsent;
  final bool dataSharingConsent;
  final bool anonymousSharingAllowed;
  final DateTime createdAt;
  final DateTime updatedAt;

  FarmerModel({
    required this.farmerId,
    required this.name,
    required this.phone,
    required this.village,
    required this.preferredLanguage,
    required this.aiTrainingConsent,
    required this.dataSharingConsent,
    required this.anonymousSharingAllowed,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'farmerId': farmerId,
      'name': name,
      'phone': phone,
      'village': village,
      'preferredLanguage': preferredLanguage,
      'aiTrainingConsent': aiTrainingConsent,
      'dataSharingConsent': dataSharingConsent,
      'anonymousSharingAllowed': anonymousSharingAllowed,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FarmerModel.fromMap(Map<String, dynamic> map, String id) {
    return FarmerModel(
      farmerId: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      village: map['village'] ?? '',
      preferredLanguage: map['preferredLanguage'] ?? 'en-IN',
      aiTrainingConsent: map['aiTrainingConsent'] ?? false,
      dataSharingConsent: map['dataSharingConsent'] ?? false,
      anonymousSharingAllowed: map['anonymousSharingAllowed'] ?? false,
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  FarmerModel copyWith({
    String? name,
    String? phone,
    String? village,
    String? preferredLanguage,
    bool? aiTrainingConsent,
    bool? dataSharingConsent,
    bool? anonymousSharingAllowed,
    DateTime? updatedAt,
  }) {
    return FarmerModel(
      farmerId: farmerId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      village: village ?? this.village,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      aiTrainingConsent: aiTrainingConsent ?? this.aiTrainingConsent,
      dataSharingConsent: dataSharingConsent ?? this.dataSharingConsent,
      anonymousSharingAllowed: anonymousSharingAllowed ?? this.anonymousSharingAllowed,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
