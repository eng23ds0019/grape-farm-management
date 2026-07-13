import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  bool _ready = false;
  bool get ready => _ready;

  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
  FirebaseStorage get storage => FirebaseStorage.instance;
  FirebaseAnalytics get analytics => FirebaseAnalytics.instance;
  FirebaseMessaging get messaging => FirebaseMessaging.instance;

  Future<bool> initialize() async {
    try {
      await Firebase.initializeApp();
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      if (!kIsWeb) {
        await FirebaseMessaging.instance.requestPermission();
      }
      _ready = true;
      return true;
    } catch (error) {
      debugPrint('Firebase is not configured yet: $error');
      _ready = false;
      return false;
    }
  }
}
