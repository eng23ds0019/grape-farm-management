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

  StreamSubscription<dynamic>? _connectivitySubscription;

  FirestoreService() {
    _loadLocalData();
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((dynamic event) {
      List<ConnectivityResult> results = [];
      if (event is List) {
        results = List<ConnectivityResult>.from(event);
      } else if (event is ConnectivityResult) {
        results = [event];
      }
      
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
    
    if (userId == null) {
      notifyListeners();
      return;
    }
    
    await _loadLocalData();
    
    // Auto-fetch data from Firestore if local cache is empty for this user session
    if (!_useMock && _cachedFarmer == null) {
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
      _db.collection('users').doc(farmer.farmerId).set(map).catchError((e) {
        debugPrint("Firestore saveFarmerProfile failed: $e");
      });
    }
  }

  // --- Farm/Plot Operations ---

  Future<void> addFarm(String farmerId, FarmModel farm) async {
    _cachedFarms.add(farm);
    notifyListeners();

    final List<String> list = _cachedFarms.map((f) => jsonEncode(f.toMap())).toList();
    await _saveLocalCache('local_farms', list);

    if (!_useMock) {
      _db
          .collection('users')
          .doc(farmerId)
          .collection('farms')
          .doc(farm.farmId)
          .set(farm.toMap())
          .catchError((e) {
        debugPrint("Firestore addFarm failed: $e");
      });
    }
  }

  // --- Diary Operations ---

  Future<void> saveDiaryEntry(String farmerId, String farmId, DiaryEntryModel entry) async {
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
      _db
          .collection('users')
          .doc(farmerId)
          .collection('farms')
          .doc(farmId)
          .collection('diaryEntries')
          .doc(updatedEntry.entryId)
          .set(updatedEntry.toMap())
          .catchError((e) {
        debugPrint("Firestore saveDiaryEntry failed: $e");
      });
    }
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
        _db
            .collection('users')
            .doc(farmerId)
            .collection('farms')
            .doc(farmId)
            .collection('diaryEntries')
            .doc(entryId)
            .update({
          'isDeleted': true,
          'deletedAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        }).catchError((e) {
          debugPrint("Firestore softDeleteDiaryEntry failed: $e");
        });
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
        _db
            .collection('users')
            .doc(farmerId)
            .collection('farms')
            .doc(farmId)
            .collection('diaryEntries')
            .doc(entryId)
            .update({
          'isDeleted': false,
          'deletedAt': null,
          'updatedAt': DateTime.now().toIso8601String(),
        }).catchError((e) {
          debugPrint("Firestore restoreDiaryEntry failed: $e");
        });
      }
    }
  }

  // --- Bill Operations ---

  Future<void> saveBill(String farmerId, String farmId, BillModel bill) async {
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
      _db
          .collection('users')
          .doc(farmerId)
          .collection('bills')
          .doc(bill.billId)
          .set(bill.toFirebaseMap())
          .catchError((e) {
        debugPrint("Firestore saveBill failed: $e");
      });
    }
  }

  // --- Turnover Operations ---

  Future<void> saveTurnover(String farmerId, TurnoverModel turnover) async {
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
      _db
          .collection('users')
          .doc(farmerId)
          .collection('turnovers')
          .doc(turnover.turnoverId)
          .set(turnover.toMap())
          .catchError((e) {
        debugPrint("Firestore saveTurnover failed: $e");
      });
    }
  }

  // --- Sync Offline Local Data ---

  Future<void> syncOfflineData(String farmerId) async {
    if (_useMock) return;

    try {
      // Push local cached entries, bills and turnovers to Firebase
      for (var farm in _cachedFarms) {
        await _db.collection('users').doc(farmerId).collection('farms').doc(farm.farmId).set(farm.toMap());

        // Sync Diary
        final farmDiary = _cachedDiary.where((e) => e.farmId == farm.farmId);
        for (var entry in farmDiary) {
          await _db
              .collection('users')
              .doc(farmerId)
              .collection('farms')
              .doc(farm.farmId)
              .collection('diaryEntries')
              .doc(entry.entryId)
              .set(entry.copyWith(isSynced: true).toMap());
        }

        // Sync Bills
        for (var bill in _cachedBills) {
          await _db
              .collection('users')
              .doc(farmerId)
              .collection('bills')
              .doc(bill.billId)
              .set(bill.toFirebaseMap());
        }

        // Sync Turnovers
        for (var turnover in _cachedTurnovers) {
          await _db
              .collection('users')
              .doc(farmerId)
              .collection('turnovers')
              .doc(turnover.turnoverId)
              .set(turnover.toMap());
        }
      }

      // Refresh sync states
      for (int i = 0; i < _cachedDiary.length; i++) {
        _cachedDiary[i] = _cachedDiary[i].copyWith(isSynced: true);
      }
      notifyListeners();
      final List<String> list = _cachedDiary.map((e) => jsonEncode(e.toMap())).toList();
      await _saveLocalCache('local_diary', list);
    } catch (e) {
      debugPrint("Firestore syncOfflineData failed: $e");
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

  // Fetch all user-scoped collections from Firestore and save locally
  Future<void> fetchAndSyncAllData(String farmerId) async {
    if (_useMock) return;
    try {
      // 1. Farmer Profile
      await fetchFarmerProfile(farmerId);

      // 2. Farms
      final farmsSnap = await _db.collection('users').doc(farmerId).collection('farms').get();
      _cachedFarms.clear();
      for (var doc in farmsSnap.docs) {
        _cachedFarms.add(FarmModel.fromMap(doc.data(), doc.id));
      }
      final List<String> farmsList = _cachedFarms.map((f) => jsonEncode(f.toMap())).toList();
      await _saveLocalCache('local_farms', farmsList);

      // 3. Diary Entries
      _cachedDiary.clear();
      for (var farm in _cachedFarms) {
        final diarySnap = await _db
            .collection('users')
            .doc(farmerId)
            .collection('farms')
            .doc(farm.farmId)
            .collection('diaryEntries')
            .get();
        for (var doc in diarySnap.docs) {
          _cachedDiary.add(DiaryEntryModel.fromMap(doc.data(), doc.id));
        }
      }
      final List<String> diaryList = _cachedDiary.map((e) => jsonEncode(e.toMap())).toList();
      await _saveLocalCache('local_diary', diaryList);

      // 4. Bills
      final billsSnap = await _db.collection('users').doc(farmerId).collection('bills').get();
      _cachedBills.clear();
      for (var doc in billsSnap.docs) {
        _cachedBills.add(BillModel.fromMap(doc.data(), doc.id));
      }
      final List<String> billsList = _cachedBills.map((b) => jsonEncode(b.toMap())).toList();
      await _saveLocalCache('local_bills', billsList);

      // 5. Turnovers
      final turnoversSnap = await _db.collection('users').doc(farmerId).collection('turnovers').get();
      _cachedTurnovers.clear();
      for (var doc in turnoversSnap.docs) {
        _cachedTurnovers.add(TurnoverModel.fromMap(doc.data(), doc.id));
      }
      final List<String> turnoversList = _cachedTurnovers.map((t) => jsonEncode(t.toMap())).toList();
      await _saveLocalCache('local_turnovers', turnoversList);

      notifyListeners();
    } catch (e) {
      debugPrint("Firestore fetchAndSyncAllData failed: $e");
    }
  }
}
