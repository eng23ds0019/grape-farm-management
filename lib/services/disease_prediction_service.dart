import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'gemini_service.dart';
import 'weather_service.dart';
import '../models/diary_entry_model.dart';
import 'package:uuid/uuid.dart';

class DiseasePredictionService {
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _notificationsInitialized = false;

  /// Initializes the local notification plugin with a fallback default channel
  static Future<void> initializeNotifications() async {
    if (_notificationsInitialized) return;
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _localNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint("Disease Alert notification tapped: ${response.payload}");
        },
      );

      // Request permission for Android 13+
      await _localNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();

      _notificationsInitialized = true;
      debugPrint("DiseasePredictionService: Local notifications successfully initialized.");
    } catch (e) {
      debugPrint("DiseasePredictionService: Local notification initialization failed: $e");
    }
  }

  /// Triggers a native system tray notification
  static Future<void> showSystemNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await initializeNotifications();
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'disease_alerts_channel',
        'Disease Alerts',
        channelDescription: 'Alerts and warnings for powdery mildew and downy mildew risks',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
      );

      // Generate a unique integer ID for this notification
      final int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      await _localNotificationsPlugin.show(
        id,
        title,
        body,
        platformDetails,
        payload: payload,
      );
      debugPrint("DiseasePredictionService: Fired local system notification successfully.");
    } catch (e) {
      debugPrint("DiseasePredictionService: Failed to display system tray notification: $e");
    }
  }

  /// Analyzes the current spray entry, weather, and farm history to predict disease risks
  static Future<void> analyzeAndPredictRisk({
    required String farmerId,
    required String farmId,
    required DiaryEntryModel currentEntry,
    required List<DiaryEntryModel> allEntries,
  }) async {
    // Only analyze if the work type is related to spraying, fertilizer, or crop work
    final lowerWork = currentEntry.workType.toLowerCase();
    final lowerText = currentEntry.cleanedText.toLowerCase() + " " + currentEntry.originalText.toLowerCase();
    final isSprayOrDiseaseQuery = lowerWork.contains('spray') ||
        lowerWork.contains('fertilizer') ||
        lowerText.contains('spray') ||
        lowerText.contains('sprayed') ||
        lowerText.contains('ಔಷಧಿ') ||
        lowerText.contains('ಗೊಬ್ಬರ') ||
        lowerText.contains('छिड़काव') ||
        lowerText.contains('रोग') ||
        lowerText.contains('disease');

    if (!isSprayOrDiseaseQuery) {
      debugPrint("DiseasePredictionService: Entry is not a spraying/disease log. Skipping analysis.");
      return;
    }

    debugPrint("DiseasePredictionService: Starting fast deterministic predictive advisory analysis...");

    try {
      // 1. Fetch Plot GPS Coordinates for precise weather
      double? lat;
      double? lon;
      String location = "Sangli";
      try {
         final plotDoc = await FirebaseFirestore.instance.collection('users').doc(farmerId).collection('cropRecords').doc(farmId).get();
         if (plotDoc.exists) {
            final data = plotDoc.data()!;
            lat = data['latitude'] as double?;
            lon = data['longitude'] as double?;
            if (data['village'] != null && data['village'].toString().isNotEmpty) {
               location = data['village'];
            }
         }
      } catch (e) {
         debugPrint("Could not fetch plot coords: $e");
      }

      // 2. Call our lightning-fast deterministic backend
      final prediction = await DrakshaApiClient.predictDisease(
        uid: farmerId,
        location: location,
        lat: lat,
        lon: lon,
      );

      final String riskLevel = prediction['diseaseRisk'] ?? 'Low';
      final String disease = prediction['diseaseName'] ?? 'None';
      final String recommendedSpray = prediction['recommendedSpray'] ?? 'None';
      final String reason = prediction['reason'] ?? '';

      // Only trigger notification on HIGH risk as requested by farmer
      if (riskLevel == 'High') {
        final alertId = const Uuid().v4();
        final alertData = {
          'alertId': alertId,
          'disease': disease,
          'riskLevel': riskLevel,
          'recommendedSpray': recommendedSpray,
          'explanation': reason,
          'createdAt': DateTime.now().toIso8601String(),
          'read': false,
        };

        // 3. Store in Firestore under user collection
        final db = FirebaseFirestore.instance;
        await db
            .collection('users')
            .doc(farmerId)
            .collection('alerts')
            .doc(alertId)
            .set(alertData);

        debugPrint("DiseasePredictionService: Saved alert $alertId to Firestore.");

        // 4. Trigger system tray push notification
        final String title = "⚠️ URGENT Disease Alert: $disease";
        final String body = "Real-time risk is High based on exact GPS weather and your spray history. Tap to see recommended spray: $recommendedSpray";
        await showSystemNotification(
          title: title,
          body: body,
          payload: jsonEncode(alertData),
        );
      } else {
        debugPrint("DiseasePredictionService: Risk is $riskLevel. No notification sent as per rules.");
      }
    } catch (e) {
      debugPrint("DiseasePredictionService: Error running prediction model: $e");
    }
  }
}
