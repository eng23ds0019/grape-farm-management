import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_service.dart';

class AnalyticsService {
  AnalyticsService(this.firebase);

  final FirebaseService firebase;

  Future<void> logAppOpened(String farmerId) =>
      logEvent('app_opened', farmerId: farmerId);

  Future<void> logEvent(
    String name, {
    required String farmerId,
    Map<String, Object> parameters = const {},
  }) async {
    if (!firebase.ready) return;
    await firebase.analytics.logEvent(
      name: name,
      parameters: {'farmer_id': farmerId, ...parameters},
    );

    final dayId = DateTime.now().toIso8601String().substring(0, 10);
    final statsRef = firebase.firestore.collection('adminStats').doc(dayId);
    await statsRef.set({
      'date': dayId,
      'updatedAt': FieldValue.serverTimestamp(),
      'events.$name': FieldValue.increment(1),
      'activeUsers.$farmerId': true,
    }, SetOptions(merge: true));
  }

  Future<void> incrementGlobal(String key) async {
    if (!firebase.ready) return;
    await firebase.firestore.collection('adminMetrics').doc('totals').set({
      key: FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
