import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/bill_record.dart';
import '../models/diary_entry.dart';
import '../models/farm.dart';
import '../models/farmer_profile.dart';
import '../models/report_summary.dart';
import 'analytics_service.dart';
import 'firebase_service.dart';
import 'local_sync_service.dart';

class FarmRepository {
  FarmRepository({
    required this.firebase,
    required this.localSync,
    required this.analytics,
  });

  final FirebaseService firebase;
  final LocalSyncService localSync;
  final AnalyticsService analytics;

  DocumentReference<Map<String, dynamic>> userRef(String farmerId) {
    return firebase.firestore.collection('users').doc(farmerId);
  }

  CollectionReference<Map<String, dynamic>> farmsRef(String farmerId) {
    return userRef(farmerId).collection('cropRecords');
  }

  CollectionReference<Map<String, dynamic>> diaryRef(
    String farmerId,
    String farmId,
  ) {
    return userRef(farmerId).collection('diaryEntries');
  }

  Stream<FarmerProfile?> profileStream(String farmerId) {
    return userRef(farmerId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return FarmerProfile.fromDoc(doc);
    });
  }

  Future<void> saveProfile(FarmerProfile profile) async {
    await userRef(
      profile.farmerId,
    ).set(profile.toMap(), SetOptions(merge: true));
  }

  Stream<List<Farm>> farmsStream(String farmerId) {
    return farmsRef(farmerId).snapshots().map((snap) {
      return snap.docs.map((doc) => Farm.fromDoc(doc)).toList();
    });
  }

  Future<void> saveFarm(String farmerId, Farm farm) async {
    await farmsRef(farmerId).doc(farm.farmId).set(farm.toMap(), SetOptions(merge: true));
  }

  Future<void> saveDiaryEntry(
    String farmerId,
    String farmId,
    DiaryEntry entry,
  ) async {
    final ref = diaryRef(farmerId, farmId).doc(
      entry.entryId.isEmpty ? null : entry.entryId,
    );
    final data = entry.toMap();
    if (firebase.ready && await localSync.isOnline) {
      await ref.set(data, SetOptions(merge: true));
      await analytics.logEvent('diary_entry_created', farmerId: farmerId);
      if (entry.totalExpense > 0) {
        await analytics.logEvent('expense_added', farmerId: farmerId);
      }
      await analytics.incrementGlobal('totalDiaryEntries');
    } else {
      await localSync.queue(
        PendingWrite(
          collectionPath: diaryRef(farmerId, farmId).path,
          documentId: ref.id,
          data: data,
        ),
      );
    }
  }

  Future<void> saveBill(String farmerId, String farmId, BillRecord bill) async {
    await userRef(farmerId)
        .collection('fertilizerBills')
        .doc(bill.billId.isEmpty ? null : bill.billId)
        .set(bill.toMap(forCreate: true), SetOptions(merge: true));
    await analytics.logEvent('bill_scanned', farmerId: farmerId);
    await analytics.incrementGlobal('totalBillsScanned');
  }

  Future<void> saveReport(
    String farmerId,
    String farmId,
    ReportSummary report,
  ) async {
    await farmsRef(farmerId)
        .doc(farmId)
        .collection('reports')
        .doc(report.reportId)
        .set(report.toMap(), SetOptions(merge: true));
    await analytics.logEvent('report_generated', farmerId: farmerId);
  }

  Future<void> flushOfflineQueue() async {
    if (!firebase.ready || !await localSync.isOnline) return;
    final writes = await localSync.pendingWrites();
    for (final write in writes) {
      await firebase.firestore
          .collection(write.collectionPath)
          .doc(write.documentId)
          .set(write.data, SetOptions(merge: true));
    }
    if (writes.isNotEmpty) await localSync.clearSynced();
  }
}
