import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PendingWrite {
  const PendingWrite({
    required this.collectionPath,
    required this.documentId,
    required this.data,
  });

  final String collectionPath;
  final String documentId;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {
    'collectionPath': collectionPath,
    'documentId': documentId,
    'data': data,
  };

  factory PendingWrite.fromJson(Map<String, dynamic> json) {
    return PendingWrite(
      collectionPath: json['collectionPath'] as String,
      documentId: json['documentId'] as String,
      data: Map<String, dynamic>.from(json['data'] as Map),
    );
  }
}

class LocalSyncService {
  static const _key = 'offlinePendingWrites';

  Future<bool> get isOnline async {
    final status = await Connectivity().checkConnectivity();
    return !status.contains(ConnectivityResult.none);
  }

  Stream<bool> onlineChanges() {
    return Connectivity().onConnectivityChanged.map(
      (statuses) => !statuses.contains(ConnectivityResult.none),
    );
  }

  Future<void> queue(PendingWrite write) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    existing.add(jsonEncode(write.toJson()));
    await prefs.setStringList(_key, existing);
  }

  Future<List<PendingWrite>> pendingWrites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((item) => PendingWrite.fromJson(jsonDecode(item)))
        .toList(growable: false);
  }

  Future<void> clearSynced() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
