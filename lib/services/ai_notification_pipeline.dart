import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'gemini_service.dart';
import 'fcm_service.dart';
import 'firestore_service.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiNotificationPipeline {
  static bool _isRunning = false;

  /// Runs the full AI pathology, expense, and profit predictive analysis
  static Future<void> runAnalysis({
    required String farmerId,
    required String farmId,
    required FirestoreService firestore,
  }) async {
    if (_isRunning) {
      debugPrint("AiNotificationPipeline: Analysis is already running. Skipping.");
      return;
    }
    _isRunning = true;
    debugPrint("AiNotificationPipeline: Starting background analysis for $farmerId...");

    try {
      // 1. Gather all local farm history context
      final diary = firestore.cachedDiary;
      final bills = firestore.cachedBills;
      final turnovers = firestore.cachedTurnovers;

      // Extract details
      final recentDiary = diary.take(15).map((e) {
        return "- Date: ${e.date} | Crop Stage: ${e.cropStage} | Work: ${e.workType} | Notes: ${e.cleanedText} ${e.originalText} | Expense: ₹${e.totalExpense.toStringAsFixed(0)}";
      }).join("\n");

      final recentBills = bills.take(10).map((b) {
        return "- Date: ${b.billDate} | Shop: ${b.shopName} | Total: ₹${b.totalAmount.toStringAsFixed(0)} | Items: [${b.items.map((i) => "${i.itemName} (Qty: ${i.quantity} ${i.unit}, Amt: ₹${i.amount.toStringAsFixed(0)})").join(", ")}]";
      }).join("\n");

      final recentTurnovers = turnovers.take(10).map((t) {
        return "- Date: ${t.date} | Grape Type: ${t.grapeType} | Total Yield: ${t.totalYield} tons | Allocations: [${t.allocations.map((a) => "${a.destinationName} (Qty: ${a.quantitySent} tons)").join(", ")}]";
      }).join("\n");

      // 2. Add simulated/real weather parameters (high-humidity outbreak environment)
      const String weatherForecast = "Temp: 28-32°C, Humidity: 82%, Rain Probability: 85% with light showers forecast, cloudy overcast for 5 days.";

      // 3. Construct AI analysis prompt
      final String prompt = "You are the head grape viticulture expert and farm auditor AI for Draksha AI.\n"
          "Analyze the farmer's history and predict outbreak risks, alerts, reminders, and financial recommendations.\n\n"
          "--- WEATHER FORECAST ---\n"
          "$weatherForecast\n\n"
          "--- RECENT DIARY ENTRIES ---\n"
          "${recentDiary.isNotEmpty ? recentDiary : 'No diary logs found.'}\n\n"
          "--- RECENT PURCHASE BILLS ---\n"
          "${recentBills.isNotEmpty ? recentBills : 'No bills found.'}\n\n"
          "--- RECENT SALES TURNOVERS ---\n"
          "${recentTurnovers.isNotEmpty ? recentTurnovers : 'No turnovers found.'}\n\n"
          "--- OUTBREAK & SYSTEM RULES ---\n"
          "1. Disease Outbreaks: fungal spores (Powdery Mildew, Downy Mildew, Anthracnose) thrive in warm (25-32°C), wet, highly humid (above 80% RH) conditions. Check if the farmer's spray history leaves them vulnerable.\n"
          "2. Insect Pests: Thrips, Mealy Bug, Fruit Fly, Red Mite thrive depending on crop stages (flowering, berry growth).\n"
          "3. Reminders: If any standard chemical (e.g. Sulphur, Bordeaux mixture, Copper) was sprayed >10 days ago, recommend an inspection.\n"
          "4. Rain: If rain probability is high (>75%), warn them NOT to spray.\n"
          "5. Finances: Flag alerts if pesticide spending is climbing compared to recent trends, or if turnovers show high yield/profit gains.\n\n"
          "Generate any necessary warnings or recommendations. You must output ONLY a valid JSON array of objects. Do not include markdown blocks, ```json, or asterisks. Return exactly:\n"
          "[\n"
          "  {\n"
          "    \"type\": \"disease\" | \"weather\" | \"spray_reminder\" | \"expense\" | \"profit\" | \"harvest\" | \"recommendation\",\n"
          "    \"riskLevel\": \"High\" | \"Medium\" | \"Low\",\n"
          "    \"title\": \"⚠ Disease Alert\" (or another matching title, e.g. \"💰 Expense Alert\", \"📈 Profit Insight\"),\n"
          "    \"message\": \"Detailed warning text (e.g., High Powdery Mildew Risk. Recommended Spray: Sulphur 80 WP. Expected within 5 days.)\",\n"
          "    \"disease\": \"Powdery Mildew\" (or another category or \"None\"),\n"
          "    \"recommendation\": \"Sulphur 80 WP\" (or other advice)\n"
          "  }\n"
          "]";

      // 4. Run prediction request
      final responseText = await GeminiService.getDirectResponse(prompt);
      debugPrint("AiNotificationPipeline: Raw Gemini response: '$responseText'");

      final String cleaned = _cleanJsonResponse(responseText);
      if (cleaned.isEmpty) {
        debugPrint("AiNotificationPipeline: Cleaned response is empty. Aborting.");
        return;
      }

      final List<dynamic> alerts = jsonDecode(cleaned) as List<dynamic>;

      // 5. Query user notification settings toggles from Firestore
      // 5. Query user notification settings toggles from SharedPreferences to prevent Firebase Permission Denied errors
      final prefs = await SharedPreferences.getInstance();
      final bool diseaseEnabled = prefs.getBool('ns_diseaseAlerts') ?? true;
      final bool weatherEnabled = prefs.getBool('ns_weatherAlerts') ?? true;
      final bool sprayEnabled = prefs.getBool('ns_sprayReminders') ?? true;
      final bool expenseEnabled = prefs.getBool('ns_expenseAlerts') ?? true;
      final bool profitEnabled = prefs.getBool('ns_profitAlerts') ?? true;
      final bool harvestEnabled = prefs.getBool('ns_harvestAlerts') ?? true;
      final bool recsEnabled = prefs.getBool('ns_aiRecommendations') ?? true;

      // 6. Process and deliver enabled alerts
      for (final alertMap in alerts) {
        final alert = Map<String, dynamic>.from(alertMap);
        final String type = alert['type'] ?? '';
        final String title = alert['title'] ?? '🔔 Draksha Notification';
        final String message = alert['message'] ?? '';
        final String riskLevel = alert['riskLevel'] ?? 'Low';

        bool isEnabled = true;
        switch (type) {
          case 'disease':
            isEnabled = diseaseEnabled;
            break;
          case 'weather':
            isEnabled = weatherEnabled;
            break;
          case 'spray_reminder':
            isEnabled = sprayEnabled;
            break;
          case 'expense':
            isEnabled = expenseEnabled;
            break;
          case 'profit':
            isEnabled = profitEnabled;
            break;
          case 'harvest':
            isEnabled = harvestEnabled;
            break;
          case 'recommendation':
            isEnabled = recsEnabled;
            break;
        }

        if (!isEnabled) {
          debugPrint("AiNotificationPipeline: Alert type '$type' is disabled in settings. Skipping.");
          continue;
        }

        // Generate unique alert
        final alertId = const Uuid().v4();
        final alertData = {
          'alertId': alertId,
          'type': type,
          'title': title,
          'message': message,
          'riskLevel': riskLevel,
          'disease': alert['disease'] ?? 'None',
          'recommendation': alert['recommendation'] ?? 'None',
          'createdAt': DateTime.now().toIso8601String(),
          'read': false,
        };

        // Save to Firestore subcollection users/{farmerId}/alerts/{alertId}
        try {
          final db = FirebaseFirestore.instance;
          await db
              .collection('users')
              .doc(farmerId)
              .collection('alerts')
              .doc(alertId)
              .set(alertData);
        } catch (e_db) {
          debugPrint("AiNotificationPipeline: Error writing alert log to database (continuing locally): $e_db");
        }

        // Display push notification on device
        await FcmService.showLocalNotification(
          title: title,
          body: message,
          payload: jsonEncode(alertData),
        );

        debugPrint("AiNotificationPipeline: Triggered alert: '$title' -> $message");
      }
    } catch (e) {
      debugPrint("AiNotificationPipeline: Error during analysis run: $e");
    } finally {
      _isRunning = false;
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
