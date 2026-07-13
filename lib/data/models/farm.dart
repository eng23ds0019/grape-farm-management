import 'package:cloud_firestore/cloud_firestore.dart';

class Farm {
  const Farm({
    required this.farmId,
    required this.farmName,
    required this.crop,
    required this.acres,
    required this.location,
    this.createdAt,
  });

  final String farmId;
  final String farmName;
  final String crop;
  final double acres;
  final String location;
  final DateTime? createdAt;

  Map<String, dynamic> toMap({bool forCreate = false}) {
    return {
      'farmName': farmName,
      'crop': crop,
      'acres': acres,
      'location': location,
      if (forCreate) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory Farm.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Farm(
      farmId: doc.id,
      farmName: data['farmName'] as String? ?? '',
      crop: data['crop'] as String? ?? 'Grapes',
      acres: (data['acres'] as num?)?.toDouble() ?? 0,
      location: data['location'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
