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

    debugPrint("DiseasePredictionService: Starting AI predictive advisory analysis...");

    // 1. Gather Weather Forecast (via real API integration)
    final weather = await WeatherService.getCurrentWeather("Nashik"); // Default to Nashik if not provided

    // 2. Gather Spray History (past Spraying diary entries)
    final List<DiaryEntryModel> sprayLogs = allEntries
        .where((e) => e.workType.toLowerCase().contains('spray') || e.workType.toLowerCase().contains('fertilizer'))
        .toList();
    final String sprayHistory = sprayLogs
        .take(10)
        .map((e) => "- Date: ${e.date} | Crop Stage: ${e.cropStage} | Details: ${e.cleanedText} ${e.expenses.isNotEmpty ? '(Sprayed: ' + e.expenses.map((exp) => exp.itemName).join(', ') + ')' : ''}")
        .join("\n");

    // 3. Gather Disease History (any past disease mentions)
    final diseaseKeywords = ['mildew', 'downy', 'powdery', 'beetle', 'thrips', 'udada', 'nusi', 'ರೋಗ', 'ಬೂದಿ', 'ಕೀಟ', 'बीमारी'];
    final String diseaseHistory = allEntries
        .where((e) => diseaseKeywords.any((kw) => e.cleanedText.toLowerCase().contains(kw) || e.originalText.toLowerCase().contains(kw)))
        .take(5)
        .map((e) => "- Date: ${e.date} | Notes: ${e.cleanedText}")
        .join("\n");

    // 4. Construct AI prompt
    final String prompt = "You are an expert grape pathology advisor.\n"
        "Analyze the current viticulture state to predict if there is a disease risk (Powdery Mildew, Downy Mildew, Flea Beetle, Thrips) in the next 5 days.\n\n"
        "--- TODAY'S SPRAY LOG ---\n"
        "Date: ${currentEntry.date}\n"
        "Crop Stage: ${currentEntry.cropStage}\n"
        "Logged Details: ${currentEntry.cleanedText} ${currentEntry.originalText}\n\n"
        "--- CURRENT WEATHER CONDITIONS ---\n"
        "${weather.toString()}\n\n"
        "--- RECENT SPRAY HISTORY ---\n"
        "${sprayHistory.isNotEmpty ? sprayHistory : 'No recent sprays logged.'}\n\n"
        "--- RECENT DISEASE HISTORY ---\n"
        "${diseaseHistory.isNotEmpty ? diseaseHistory : 'No disease history logged.'}\n\n"
        "--- OUTBREAK CONDITIONS ---\n"
        "- Powdery Mildew: Thrives in warm weather (25-32°C), high humidity (70-90% RH), and cloudy/shaded conditions.\n"
        "- Downy Mildew: Requires free water (recent light rains/heavy dew) and high relative humidity (above 85%).\n\n"
        "If weather conditions match outbreak conditions, and today's spray does NOT provide sufficient protection (or if today's spray IS the spray itself, assess if the risk is now low or remains high for untreated rows), warn the farmer.\n\n"
        "Your output must be ONLY a clean JSON map with these keys. Do not include markdown blocks, ```json, or asterisks. Return exactly:\n"
        "{\n"
        "  \"riskLevel\": \"High\" or \"Medium\" or \"Low\",\n"
        "  \"disease\": \"Disease Name\" (e.g., \"Powdery Mildew\" or \"Downy Mildew\" or \"None\"),\n"
        "  \"recommendedSpray\": \"Fungicide/Chemical name & dosage\" (e.g. \"Sulfur 80 WP (2g/L)\"),\n"
        "  \"days\": 5,\n"
        "  \"explanation\": \"Short explanation of why the risk is flagged.\"\n"
        "}";

    try {
      // Call Gemini API
      final responseText = await GeminiService.getDirectResponse(prompt);
      debugPrint("DiseasePredictionService: Raw Gemini response: '$responseText'");

      // Extract JSON map
      final Map<String, dynamic> prediction = Map<String, dynamic>.from(jsonDecode(_cleanJsonResponse(responseText)));
      final String riskLevel = prediction['riskLevel'] ?? 'Low';
      final String disease = prediction['disease'] ?? 'None';
      final String recommendedSpray = prediction['recommendedSpray'] ?? 'None';
      final String explanation = prediction['explanation'] ?? '';

      if (riskLevel == 'High' || riskLevel == 'Medium') {
        final alertId = const Uuid().v4();
        final alertData = {
          'alertId': alertId,
          'disease': disease,
          'riskLevel': riskLevel,
          'recommendedSpray': recommendedSpray,
          'explanation': explanation,
          'createdAt': DateTime.now().toIso8601String(),
          'read': false,
        };

        // 5. Store in Firestore under user collection: users/{farmerId}/alerts/{alertId}
        final db = FirebaseFirestore.instance;
        await db
            .collection('users')
            .doc(farmerId)
            .collection('alerts')
            .doc(alertId)
            .set(alertData);

        debugPrint("DiseasePredictionService: Saved alert $alertId to Firestore.");

        // 6. Trigger Simulated FCM system tray push notification
        final String title = riskLevel == 'High' ? "⚠️ Disease Alert" : "🔔 Disease Advisory";
        final String body = "$riskLevel $disease Risk\nRecommended Spray: $recommendedSpray";
        await showSystemNotification(
          title: title,
          body: body,
          payload: jsonEncode(alertData),
        );
      }
    } catch (e) {
      debugPrint("DiseasePredictionService: Error running prediction model: $e");
    }
  }

  static String _cleanJsonResponse(String text) {
    var cleaned = text.trim();
    if (cleaned.startsWith("```")) {
      cleaned = cleaned.replaceAll(RegExp(r'^```(json)?|```$'), '').trim();
    }
    return cleaned;
  }
}
