import 'package:cloud_firestore/cloud_firestore.dart';

class FarmerProfile {
  const FarmerProfile({
    required this.farmerId,
    required this.name,
    required this.phone,
    required this.village,
    required this.preferredLanguage,
    required this.aiTrainingConsent,
    this.createdAt,
    this.updatedAt,
  });

  final String farmerId;
  final String name;
  final String phone;
  final String village;
  final String preferredLanguage;
  final bool aiTrainingConsent;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap({bool forCreate = false}) {
    return {
      'farmerId': farmerId,
      'name': name,
      'phone': phone,
      'village': village,
      'preferredLanguage': preferredLanguage,
      'aiTrainingConsent': aiTrainingConsent,
      'updatedAt': FieldValue.serverTimestamp(),
      if (forCreate) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory FarmerProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FarmerProfile(
      farmerId: data['farmerId'] as String? ?? doc.id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      village: data['village'] as String? ?? '',
      preferredLanguage: data['preferredLanguage'] as String? ?? 'en',
      aiTrainingConsent: data['aiTrainingConsent'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
