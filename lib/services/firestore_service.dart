import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/farmer_model.dart';
import '../models/farm_model.dart';
import '../models/diary_entry_model.dart';
import '../models/bill_model.dart';
import '../models/turnover_model.dart';
import 'ai_notification_pipeline.dart';

import '../core/utils/data_validator.dart';

class FirestoreService extends ChangeNotifier {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  bool _useMock = false; // Use live Firebase by default when correct credentials exist

  // Local Cache Lists for Mock Offline Mode
  FarmerModel? _cachedFarmer;
  final List<FarmModel> _cachedFarms = [];
  final List<DiaryEntryModel> _cachedDiary = [];
  final List<BillModel> _cachedBills = [];
  final List<TurnoverModel> _cachedTurnovers = [];

  bool get useMock => _useMock;
  FarmerModel? get cachedFarmer => _cachedFarmer;
  List<FarmModel> get cachedFarms => _cachedFarms;
  List<DiaryEntryModel> get cachedDiary => _cachedDiary.where((e) => !e.isDeleted).toList();
  List<DiaryEntryModel> get deletedDiary => _cachedDiary.where((e) => e.isDeleted).toList();
  List<BillModel> get cachedBills => _cachedBills;
  List<TurnoverModel> get cachedTurnovers => _cachedTurnovers;
  
  final List<Map<String, dynamic>> _cachedChats = [];
  List<Map<String, dynamic>> get cachedChats => _cachedChats;

  StreamSubscription<dynamic>? _connectivitySubscription;

  FirestoreService() {
    try {
      _db.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      debugPrint("FirestoreService: Successfully configured unlimited offline persistence.");
    } catch (e) {
      debugPrint("FirestoreService: Settings already initialized or configuration failed: $e");
    }
    _loadLocalData();
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection && !_useMock && _cachedFarmer != null) {
        syncOfflineData(_cachedFarmer!.farmerId);
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void setMockMode(bool val) {
    _useMock = val;
    notifyListeners();
    if (!val && _cachedFarmer != null) {
      syncOfflineData(_cachedFarmer!.farmerId);
    }
  }

  String? _currentUserId;

  // Switch the active user session and reload their cached data
  Future<void> switchUser(String? userId) async {
    if (_currentUserId == userId) return;
    _currentUserId = userId;
    
    // Clear the active caches in memory for the previous user session
    _cachedFarmer = null;
    _cachedFarms.clear();
    _cachedDiary.clear();
    _cachedBills.clear();
    _cachedTurnovers.clear();
    _cachedChats.clear();
    
    if (userId == null) {
      notifyListeners();
      return;
    }
    
    await _loadLocalData();
    
    // Always auto-fetch fresh data from Firestore upon login or user switch
    if (!_useMock) {
      fetchAndSyncAllData(userId).catchError((e) {
        debugPrint("Background sync failed in switchUser: $e");
      });
    }
  }

  // Load cache from SharedPreferences using user-specific keys
  Future<void> _loadLocalData() async {
    final suffix = _currentUserId != null ? "_$_currentUserId" : "";
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Farmer Profile
      final farmerJson = prefs.getString('local_farmer$suffix');
      if (farmerJson != null) {
        _cachedFarmer = FarmerModel.fromMap(jsonDecode(farmerJson), _currentUserId ?? 'mock_farmer_patil');
      } else {
        _cachedFarmer = null;
      }

      // 2. Farms
      final farmsJson = prefs.getStringList('local_farms$suffix');
      _cachedFarms.clear();
      if (farmsJson != null) {
        for (var f in farmsJson) {
          final map = jsonDecode(f);
          _cachedFarms.add(FarmModel.fromMap(map, map['farmId']));
        }
      } else {
        // Default Farm Plot
        _cachedFarms.add(FarmModel(
          farmId: 'plot_1',
          farmName: 'Basveshwar Plot 1',
          acres: 3.5,
          location: 'Soudi North',
          soilType: 'Black Cotton',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      // 3. Diary Entries
      final diaryJson = prefs.getStringList('local_diary$suffix');
      _cachedDiary.clear();
      if (diaryJson != null) {
        for (var d in diaryJson) {
          final map = jsonDecode(d);
          _cachedDiary.add(DiaryEntryModel.fromMap(map, map['entryId']));
        }
      }

      // 4. Bills
      final billsJson = prefs.getStringList('local_bills$suffix');
      _cachedBills.clear();
      if (billsJson != null) {
        for (var b in billsJson) {
          final map = jsonDecode(b);
          _cachedBills.add(BillModel.fromMap(map, map['billId']));
        }
      }

      // 5. Turnovers
      final turnoversJson = prefs.getStringList('local_turnovers$suffix');
      _cachedTurnovers.clear();
      if (turnoversJson != null) {
        for (var t in turnoversJson) {
          final map = jsonDecode(t);
          _cachedTurnovers.add(TurnoverModel.fromMap(map, map['turnoverId']));
        }
      }

      // 6. Chat History (Recent 15)
      final chatsJson = prefs.getStringList('local_chats$suffix');
      _cachedChats.clear();
      if (chatsJson != null) {
        for (var c in chatsJson) {
          _cachedChats.add(jsonDecode(c) as Map<String, dynamic>);
        }
      }

      notifyListeners();

      // Trigger instant background sync on load if live and connected
      if (!_useMock && _cachedFarmer != null) {
        final dynamic conn = await Connectivity().checkConnectivity();
        List<ConnectivityResult> results = [];
        if (conn is List) {
          results = List<ConnectivityResult>.from(conn);
        } else if (conn is ConnectivityResult) {
          results = [conn];
        }
        final hasConnection = results.any((r) => r != ConnectivityResult.none);
        if (hasConnection) {
          syncOfflineData(_cachedFarmer!.farmerId);
        }
      }
    } catch (e) {
      // Gracefully catch load errors
    }
  }

  // Save Cache to SharedPreferences with user-specific keys
  Future<void> _saveLocalCache(String key, dynamic data) async {
    final suffix = _currentUserId != null ? "_$_currentUserId" : "";
    final fullKey = "$key$suffix";
    try {
      final prefs = await SharedPreferences.getInstance();
      if (data is String) {
        await prefs.setString(fullKey, data);
      } else if (data is List<String>) {
        await prefs.setStringList(fullKey, data);
      }
    } catch (e) {
      // Gracefully catch cache save errors
    }
  }

  // --- Farmer Profile Operations ---

  Future<void> saveFarmerProfile(FarmerModel farmer) async {
    _cachedFarmer = farmer;
    notifyListeners();

    final map = farmer.toMap();
    await _saveLocalCache('local_farmer', jsonEncode(map));

    if (!_useMock) {
      try {
        await _db.collection('users').doc(farmer.farmerId).set(map);
      } catch (e) {
        debugPrint("Firestore saveFarmerProfile failed, queuing offline: $e");
        await _queuePendingWrite(type: 'profile', id: farmer.farmerId, data: map);
      }
    }
  }

  // --- Farm/Plot Operations ---

  Future<void> addFarm(String farmerId, FarmModel farm) async {
    _cachedFarms.add(farm);
    notifyListeners();

    final List<String> list = _cachedFarms.map((f) => jsonEncode(f.toMap())).toList();
    await _saveLocalCache('local_farms', list);

    if (!_useMock) {
      final activeUid = (_currentUserId != null && _currentUserId != "mock_farmer" && _currentUserId != "mock_farmer_patil")
          ? _currentUserId!
          : farmerId;
          
      final map = farm.toMap();
      try {
        await _db
            .collection('users')
            .doc(activeUid)
            .collection('cropRecords')
            .doc(farm.farmId)
            .set(map);
      } catch (e) {
        debugPrint("Firestore addFarm failed, queuing offline: $e");
        await _queuePendingWrite(type: 'farm', id: farm.farmId, data: map);
      }
    }
  }

  // --- Diary Operations ---

  Future<void> saveDiaryEntry(String farmerId, String farmId, DiaryEntryModel entry) async {
    final activeUid = (_currentUserId != null && _currentUserId != "mock_farmer" && _currentUserId != "mock_farmer_patil")
        ? _currentUserId!
        : farmerId;

    // 1. Quality Evaluation & Score Check
    final eval = DataQualityValidator.evaluateQuality(entry);
    final updatedEntry = entry.copyWith(
      dataQualityScore: eval['score'],
      missingFields: List<String>.from(eval['missingFields']),
      aiReady: eval['aiReady'],
      needsReview: eval['needsReview'],
      updatedAt: DateTime.now(),
    );

    // Update Cache
    int idx = _cachedDiary.indexWhere((e) => e.entryId == updatedEntry.entryId);
    if (idx != -1) {
      _cachedDiary[idx] = updatedEntry;
    } else {
      _cachedDiary.add(updatedEntry);
    }
    notifyListeners();

    final List<String> list = _cachedDiary.map((e) => jsonEncode(e.toMap())).toList();
    await _saveLocalCache('local_diary', list);

    if (!_useMock) {
      try {
        await _db
            .collection('users')
            .doc(activeUid)
            .collection('diaryEntries')
            .doc(updatedEntry.entryId)
            .set(updatedEntry.toMap());

        // Save nested expenses to direct subcollection 'expenses'
        if (updatedEntry.expenses.isNotEmpty) {
          for (int i = 0; i < updatedEntry.expenses.length; i++) {
            final exp = updatedEntry.expenses[i];
            await _db
                .collection('users')
                .doc(activeUid)
                .collection('expenses')
                .doc("${updatedEntry.entryId}_exp_$i")
                .set(exp.toMap());
          }
        }

        // Save reminderDate to direct subcollection 'reminders'
        if (updatedEntry.reminderDate.isNotEmpty) {
          await _db
              .collection('users')
              .doc(activeUid)
              .collection('reminders')
              .doc(updatedEntry.entryId)
              .set({
            'reminderDate': updatedEntry.reminderDate,
            'cropStage': updatedEntry.cropStage,
            'workType': updatedEntry.workType,
            'originalText': updatedEntry.originalText,
            'createdAt': DateTime.now().toIso8601String(),
          });
        }

        // Save photo URLs to direct subcollection 'uploadedImages'
        if (updatedEntry.photos.isNotEmpty) {
          for (int i = 0; i < updatedEntry.photos.length; i++) {
            final photoUrl = updatedEntry.photos[i];
            await _db
                .collection('users')
                .doc(activeUid)
                .collection('uploadedImages')
                .doc("${updatedEntry.entryId}_img_$i")
                .set({
              'imageUrl': photoUrl,
              'diaryEntryId': updatedEntry.entryId,
              'createdAt': DateTime.now().toIso8601String(),
            });
          }
        }
      } catch (e) {
        debugPrint("Firestore saveDiaryEntry failed, queuing offline: $e");
        await _queuePendingWrite(type: 'diary', id: updatedEntry.entryId, data: updatedEntry.toMap());
      }
    }

    // Trigger Production-Grade AI Outbreak, Expense, & Profit Risk Analysis Pipeline
    unawaited(AiNotificationPipeline.runAnalysis(
      farmerId: activeUid,
      farmId: farmId,
      firestore: this,
    ));
  }

  // Soft Delete Diary Entry
  Future<void> softDeleteDiaryEntry(String farmerId, String farmId, String entryId) async {
    int idx = _cachedDiary.indexWhere((e) => e.entryId == entryId);
    if (idx != -1) {
      final old = _cachedDiary[idx];
      _cachedDiary[idx] = old.copyWith(
        isDeleted: true,
        deletedAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now(),
      );
      notifyListeners();

      final List<String> list = _cachedDiary.map((e) => jsonEncode(e.toMap())).toList();
      await _saveLocalCache('local_diary', list);

      if (!_useMock) {
        try {
          await _db
              .collection('users')
              .doc(farmerId)
              .collection('diaryEntries')
              .doc(entryId)
              .update({
            'isDeleted': true,
            'deletedAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint("Firestore softDeleteDiaryEntry failed, queuing offline: $e");
          await _queuePendingDelete(type: 'diary', id: entryId);
        }
      }
    }
  }

  // Restore Soft Deleted Diary Entry
  Future<void> restoreDiaryEntry(String farmerId, String farmId, String entryId) async {
    int idx = _cachedDiary.indexWhere((e) => e.entryId == entryId);
    if (idx != -1) {
      final old = _cachedDiary[idx];
      _cachedDiary[idx] = old.copyWith(
        isDeleted: false,
        deletedAt: null,
        updatedAt: DateTime.now(),
      );
      notifyListeners();

      final List<String> list = _cachedDiary.map((e) => jsonEncode(e.toMap())).toList();
      await _saveLocalCache('local_diary', list);

      if (!_useMock) {
        try {
          await _db
              .collection('users')
              .doc(farmerId)
              .collection('diaryEntries')
              .doc(entryId)
              .update({
            'isDeleted': false,
            'deletedAt': null,
            'updatedAt': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint("Firestore restoreDiaryEntry failed: $e");
          rethrow;
        }
      }
    }
  }

  // --- Bill Operations ---

  Future<void> saveBill(String farmerId, String farmId, BillModel bill) async {
    final activeUid = (_currentUserId != null && _currentUserId != "mock_farmer" && _currentUserId != "mock_farmer_patil")
        ? _currentUserId!
        : farmerId;

    int idx = _cachedBills.indexWhere((b) => b.billId == bill.billId);
    if (idx != -1) {
      _cachedBills[idx] = bill;
    } else {
      _cachedBills.add(bill);
    }
    notifyListeners();

    final List<String> list = _cachedBills.map((b) => jsonEncode(b.toMap())).toList();
    await _saveLocalCache('local_bills', list);

    if (!_useMock) {
      try {
        await _db
            .collection('users')
            .doc(activeUid)
            .collection('fertilizerBills')
            .doc(bill.billId)
            .set(bill.toFirebaseMap());
      } catch (e) {
        debugPrint("Firestore saveBill failed, queuing offline: $e");
        await _queuePendingWrite(type: 'bill', id: bill.billId, data: bill.toFirebaseMap());
      }
    }

    // Trigger Production-Grade AI Outbreak, Expense, & Profit Risk Analysis Pipeline
    unawaited(AiNotificationPipeline.runAnalysis(
      farmerId: activeUid,
      farmId: farmId,
      firestore: this,
    ));
  }

  // --- Turnover Operations ---

  Future<void> saveTurnover(String farmerId, TurnoverModel turnover) async {
    final activeUid = (_currentUserId != null && _currentUserId != "mock_farmer" && _currentUserId != "mock_farmer_patil")
        ? _currentUserId!
        : farmerId;

    int idx = _cachedTurnovers.indexWhere((t) => t.turnoverId == turnover.turnoverId);
    if (idx != -1) {
      _cachedTurnovers[idx] = turnover;
    } else {
      _cachedTurnovers.add(turnover);
    }
    notifyListeners();

    final List<String> list = _cachedTurnovers.map((t) => jsonEncode(t.toMap())).toList();
    await _saveLocalCache('local_turnovers', list);

    if (!_useMock) {
      try {
        await _db
            .collection('users')
            .doc(activeUid)
            .collection('turnovers')
            .doc(turnover.turnoverId)
            .set(turnover.toMap());
      } catch (e) {
        debugPrint("Firestore saveTurnover failed, queuing offline: $e");
        await _queuePendingWrite(type: 'turnover', id: turnover.turnoverId, data: turnover.toMap());
      }
    }

    // Trigger Production-Grade AI Outbreak, Expense, & Profit Risk Analysis Pipeline
    unawaited(AiNotificationPipeline.runAnalysis(
      farmerId: activeUid,
      farmId: "plot_1",
      firestore: this,
    ));
  }

  // --- Local Outbox Retry Queue Helper Methods ---

  Future<List<Map<String, dynamic>>> _loadOutboxQueue() async {
    final suffix = _currentUserId != null ? "_$_currentUserId" : "";
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('pending_writes$suffix');
      if (list != null) {
        return list.map((item) => jsonDecode(item) as Map<String, dynamic>).toList();
      }
    } catch (e) {
      debugPrint("Error loading pending outbox queue: $e");
    }
    return [];
  }

  Future<void> _saveOutboxQueue(List<Map<String, dynamic>> queue) async {
    final suffix = _currentUserId != null ? "_$_currentUserId" : "";
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = queue.map((item) => jsonEncode(item)).toList();
      await prefs.setStringList('pending_writes$suffix', list);
    } catch (e) {
      debugPrint("Error saving pending outbox queue: $e");
    }
  }

  Future<void> _queuePendingWrite({
    required String type,
    required String id,
    required Map<String, dynamic> data,
  }) async {
    final queue = await _loadOutboxQueue();
    queue.removeWhere((item) => item['type'] == type && item['id'] == id);
    queue.add({
      'type': type,
      'id': id,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await _saveOutboxQueue(queue);
    debugPrint("Offline-First: Queued pending write of type '$type' with ID '$id'.");
  }

  Future<void> _queuePendingDelete({
    required String type,
    required String id,
  }) async {
    final queue = await _loadOutboxQueue();
    queue.removeWhere((item) => item['type'] == type && item['id'] == id);
    queue.add({
      'type': type,
      'id': id,
      'delete': true,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await _saveOutboxQueue(queue);
    debugPrint("Offline-First: Queued pending delete of type '$type' with ID '$id'.");
  }

  // --- Sync Offline Local Data ---

  Future<void> syncOfflineData(String farmerId) async {
    await flushOfflineQueue();
  }

  Future<void> flushOfflineQueue() async {
    if (_useMock) return;
    if (_currentUserId == null || _currentUserId == "mock_farmer" || _currentUserId == "mock_farmer_patil") {
      return;
    }

    try {
      final List<ConnectivityResult> results = await Connectivity().checkConnectivity();
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (!hasConnection) {
        debugPrint("Offline-First: Sync skipped. No active network connection.");
        return;
      }
    } catch (e_conn) {
      debugPrint("Offline-First: Connectivity check failed, assuming online: $e_conn");
    }

    final queue = await _loadOutboxQueue();
    if (queue.isEmpty) {
      debugPrint("Offline-First: Outbox queue is empty. Sync complete.");
      return;
    }

    debugPrint("Offline-First: Syncing ${queue.length} pending writes/deletes to Firestore...");
    final List<Map<String, dynamic>> failed = [];

    for (final item in queue) {
      final String type = item['type'] ?? '';
      final String id = item['id'] ?? '';
      final bool isDelete = item['delete'] ?? false;
      final Map<String, dynamic>? data = item['data'] != null ? Map<String, dynamic>.from(item['data']) : null;

      try {
        if (isDelete) {
          if (type == 'diary') {
            await _db
                .collection('users')
                .doc(_currentUserId)
                .collection('diaryEntries')
                .doc(id)
                .update({
              'isDeleted': true,
              'deletedAt': DateTime.now().toIso8601String(),
            });
          }
        } else if (data != null) {
          if (type == 'profile') {
            await _db.collection('users').doc(_currentUserId).set(data);
          } else if (type == 'farm') {
            await _db
                .collection('users')
                .doc(_currentUserId)
                .collection('cropRecords')
                .doc(id)
                .set(data);
          } else if (type == 'diary') {
            await _db
                .collection('users')
                .doc(_currentUserId)
                .collection('diaryEntries')
                .doc(id)
                .set(data);

            // Sync nested expenses if present
            if (data['expenses'] != null) {
              final list = data['expenses'] as List;
              for (int i = 0; i < list.length; i++) {
                await _db
                    .collection('users')
                    .doc(_currentUserId)
                    .collection('expenses')
                    .doc("${id}_exp_$i")
                    .set(list[i]);
              }
            }
          } else if (type == 'bill') {
            await _db
                .collection('users')
                .doc(_currentUserId)
                .collection('fertilizerBills')
                .doc(id)
                .set(data);
          } else if (type == 'turnover') {
            await _db
                .collection('users')
                .doc(_currentUserId)
                .collection('turnovers')
                .doc(id)
                .set(data);
          }
        }
        debugPrint("Offline-First: Successfully synced '$type' with ID '$id'.");
      } catch (e) {
        debugPrint("Offline-First: Sync failed for '$type' ID '$id': $e");
        failed.add(item);
      }
    }

    await _saveOutboxQueue(failed);
    
    // If we resolved some items, run the analysis
    if (queue.length > failed.length) {
      // Mark local memory items as synced
      bool modified = false;
      for (final item in queue) {
        if (failed.any((f) => f['type'] == item['type'] && f['id'] == item['id'])) continue;
        
        if (item['type'] == 'diary') {
          int idx = _cachedDiary.indexWhere((e) => e.entryId == item['id']);
          if (idx != -1) {
            _cachedDiary[idx] = _cachedDiary[idx].copyWith(isSynced: true);
            modified = true;
          }
        }
      }
      if (modified) {
        notifyListeners();
        final List<String> list = _cachedDiary.map((e) => jsonEncode(e.toMap())).toList();
        await _saveLocalCache('local_diary', list);
      }

      unawaited(AiNotificationPipeline.runAnalysis(
        farmerId: _currentUserId!,
        farmId: "plot_1",
        firestore: this,
      ));
    }
  }

  // Check if phone number is already in use by another user in Firestore
  Future<bool> checkPhoneExists(String phoneNumber) async {
    if (_useMock) {
      final clean = phoneNumber.replaceAll(RegExp(r'[\s\-()]+'), '');
      final formatted = clean.startsWith('+') ? clean : "+91$clean";
      return formatted == "+919876543210" || (_cachedFarmer != null && _cachedFarmer!.phone == formatted);
    }
    try {
      final clean = phoneNumber.replaceAll(RegExp(r'[\s\-()]+'), '');
      final formatted = clean.startsWith('+') ? clean : "+91$clean";
      final query = await _db.collection('users').where('phone', isEqualTo: formatted).limit(1).get();
      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint("Firestore checkPhoneExists failed: $e");
      return false;
    }
  }

  // Fetch farmer profile from Firestore remote database
  Future<FarmerModel?> fetchFarmerProfile(String farmerId) async {
    if (_useMock) return _cachedFarmer;
    try {
      final doc = await _db.collection('users').doc(farmerId).get();
      if (doc.exists && doc.data() != null) {
        final farmer = FarmerModel.fromMap(doc.data()!, farmerId);
        _cachedFarmer = farmer;
        await _saveLocalCache('local_farmer', jsonEncode(farmer.toMap()));
        notifyListeners();
        return farmer;
      }
    } catch (e) {
      debugPrint("Firestore fetchFarmerProfile failed: $e");
    }
    return null;
  }

  Future<void> fetchAndSyncAllData(String farmerId) async {
    if (_useMock) return;
    try {
      debugPrint("Firestore: Starting full data fetch and sync for user $farmerId");
      
      // Load outbox writes to detect pending updates
      final outbox = await _loadOutboxQueue();
      bool isPending(String type, String id) {
        return outbox.any((item) => item['type'] == type && item['id'] == id);
      }

      // 1. Farmer Profile
      await fetchFarmerProfile(farmerId);

      // 2. Crop Records (Farms)
      final farmsSnap = await _db.collection('users').doc(farmerId).collection('cropRecords').get();
      final remoteFarmIds = farmsSnap.docs.map((d) => d.id).toSet();
      
      // Remove synced local farms that don't exist on remote server
      _cachedFarms.removeWhere((f) => !remoteFarmIds.contains(f.farmId) && !isPending('farm', f.farmId));
      
      // Merge remote records
      for (var doc in farmsSnap.docs) {
        final farm = FarmModel.fromMap(doc.data(), doc.id);
        if (!isPending('farm', farm.farmId)) {
          int idx = _cachedFarms.indexWhere((f) => f.farmId == farm.farmId);
          if (idx != -1) {
            _cachedFarms[idx] = farm;
          } else {
            _cachedFarms.add(farm);
          }
        }
      }
      final List<String> farmsList = _cachedFarms.map((f) => jsonEncode(f.toMap())).toList();
      await _saveLocalCache('local_farms', farmsList);

      // 3. Diary Entries (Direct under user)
      final diarySnap = await _db
          .collection('users')
          .doc(farmerId)
          .collection('diaryEntries')
          .get();
      final remoteDiaryIds = diarySnap.docs.map((d) => d.id).toSet();
      
      // Remove synced local diary entries that don't exist on remote server (i.e. deleted)
      _cachedDiary.removeWhere((e) => e.isSynced && !remoteDiaryIds.contains(e.entryId) && !isPending('diary', e.entryId));

      // Merge remote records
      for (var doc in diarySnap.docs) {
        final entry = DiaryEntryModel.fromMap(doc.data(), doc.id);
        if (!isPending('diary', entry.entryId)) {
          int idx = _cachedDiary.indexWhere((e) => e.entryId == entry.entryId);
          if (idx != -1) {
            _cachedDiary[idx] = entry.copyWith(isSynced: true);
          } else {
            _cachedDiary.add(entry.copyWith(isSynced: true));
          }
        }
      }
      final List<String> diaryList = _cachedDiary.map((e) => jsonEncode(e.toMap())).toList();
      await _saveLocalCache('local_diary', diaryList);

      // 4. Bills (Fertilizer Bills)
      final billsSnap = await _db.collection('users').doc(farmerId).collection('fertilizerBills').get();
      final remoteBillIds = billsSnap.docs.map((d) => d.id).toSet();

      // Remove synced local bills that don't exist on remote server
      _cachedBills.removeWhere((b) => !remoteBillIds.contains(b.billId) && !isPending('bill', b.billId));

      for (var doc in billsSnap.docs) {
        final bill = BillModel.fromMap(doc.data(), doc.id);
        if (!isPending('bill', bill.billId)) {
          int idx = _cachedBills.indexWhere((b) => b.billId == bill.billId);
          if (idx != -1) {
            _cachedBills[idx] = bill;
          } else {
            _cachedBills.add(bill);
          }
        }
      }
      final List<String> billsList = _cachedBills.map((b) => jsonEncode(b.toMap())).toList();
      await _saveLocalCache('local_bills', billsList);

      // 5. Turnovers
      final turnoversSnap = await _db.collection('users').doc(farmerId).collection('turnovers').get();
      final remoteTurnoverIds = turnoversSnap.docs.map((d) => d.id).toSet();

      // Remove synced local turnovers that don't exist on remote server
      _cachedTurnovers.removeWhere((t) => !remoteTurnoverIds.contains(t.turnoverId) && !isPending('turnover', t.turnoverId));

      for (var doc in turnoversSnap.docs) {
        final turnover = TurnoverModel.fromMap(doc.data(), doc.id);
        if (!isPending('turnover', turnover.turnoverId)) {
          int idx = _cachedTurnovers.indexWhere((t) => t.turnoverId == turnover.turnoverId);
          if (idx != -1) {
            _cachedTurnovers[idx] = turnover;
          } else {
            _cachedTurnovers.add(turnover);
          }
        }
      }
      final List<String> turnoversList = _cachedTurnovers.map((t) => jsonEncode(t.toMap())).toList();
      await _saveLocalCache('local_turnovers', turnoversList);

      notifyListeners();
      debugPrint("Offline-First: Successfully sync-merged remote data locally.");
      
      // Flush any pending offline queue items
      unawaited(flushOfflineQueue());
    } catch (e) {
      debugPrint("Firestore fetchAndSyncAllData failed (preserving local cache): $e");
    }
  }

  // --- AI Chat History Methods ---
  Future<void> saveChatMessage(String role, String text) async {
    final activeUid = (_currentUserId != null && _currentUserId != "mock_farmer" && _currentUserId != "mock_farmer_patil") 
        ? _currentUserId! : "mock_farmer";

    final chatDoc = {
      'role': role,
      'text': text,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _cachedChats.add(chatDoc);
    // Keep only last 15 messages locally to save tokens & space
    if (_cachedChats.length > 15) {
      _cachedChats.removeAt(0);
    }
    
    notifyListeners();

    // Save to SharedPreferences for fast local retrieval
    final suffix = "_$activeUid";
    final prefs = await SharedPreferences.getInstance();
    final list = _cachedChats.map((c) => jsonEncode(c)).toList();
    await prefs.setStringList('local_chats$suffix', list);

    // Persist permanently in Firestore (async, background, safe to fail)
    if (!_useMock) {
      try {
        await _db.collection('users').doc(activeUid).collection('chats').add(chatDoc);
      } catch (e) {
        debugPrint("Background saveChatMessage failed: $e");
      }
    }
  }
}
