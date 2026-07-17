import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'firestore_service.dart';
import 'weather_service.dart';
import 'disease_prediction_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class DrakshaOrchestrator {
  /// The core reasoning engine. Orchestrates the flow of data from all sources,
  /// sends to the secure backend, handles disease alerts, and returns the TTS text.
  static Future<String> processMessage({
    required String message,
    required FirestoreService firestoreService,
  }) async {
    try {
      final farmer = firestoreService.cachedFarmer;
      if (farmer == null) {
        return "I cannot access your records. Please ensure you are logged in.";
      }

      // 1. Prepare Farm Context
      final diaries = firestoreService.cachedDiary.take(20).toList();
      final expenses = diaries.expand((d) => d.expenses).take(15).toList();
      String currentCropStage = diaries.isNotEmpty ? diaries.first.cropStage : "Unknown";

      final farmContext = {
        "cropStage": currentCropStage,
        "recentDiaries": diaries.map((d) => "${d.date}: ${d.workType} - ${d.cleanedText}").toList(),
        "recentExpenses": expenses.map((e) => "${e.date}: ${e.itemName} - ₹${e.totalAmount}").toList(),
        "chatHistory": firestoreService.cachedChats.map((e) => "${e['role'] == 'user' ? 'Farmer' : 'Draksha AI'}: ${e['text']}").toList(),
      };

      // 2. Retrieve Weather
      final weather = await WeatherService.getCurrentWeather("Nashik"); // Mocked default

      // 3. Send Context to Secure Backend for RAG & Gemini processing
      // NOTE: Connecting to live production backend hosted on Render.com
      final backendUrl = Uri.parse("https://grape-farm-management.onrender.com/api/v1/chat/orchestrate");
      
      final response = await http.post(
        backendUrl,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "query": message,
          "farm_context": jsonEncode(farmContext),
          "weather_context": weather.toString(),
        }),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
         final data = jsonDecode(response.body);
         
         // 4. Check if disease was predicted
         final String responseText = data['response'] ?? "Received empty response from backend.";
         final String risk = data['diseaseRisk'] ?? "Low";
         final String disease = data['diseaseName'] ?? "None";
         final String spray = data['recommendedSpray'] ?? "None";
         
         if ((risk == "High" || risk == "Medium") && disease != "None") {
            await _dispatchDiseaseAlert(
               farmerId: farmer.farmerId, 
               risk: risk,
               disease: disease, 
               spray: spray,
            );
         }
         return responseText;
      } else {
         debugPrint("Backend Error: ${response.statusCode} - ${response.body}");
         return "I could not reach the reasoning engine. Please check your backend connection.";
      }

    } catch (e) {
      debugPrint("DrakshaOrchestrator Network Error: $e");
      return "I could not reach the reasoning engine. Please check your connection to the backend.";
    }
  }

  static Future<void> _dispatchDiseaseAlert({
    required String farmerId,
    required String risk,
    required String disease,
    required String spray,
  }) async {
    final alertId = const Uuid().v4();
    final alertData = {
      'alertId': alertId,
      'disease': disease,
      'riskLevel': risk,
      'recommendedSpray': spray,
      'explanation': "Draksha AI detected high risk factors during conversation orchestration.",
      'createdAt': DateTime.now().toIso8601String(),
      'read': false,
    };

    // Save to Firestore for permanent record
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(farmerId)
          .collection('alerts')
          .doc(alertId)
          .set(alertData);
    } catch (e) {
      debugPrint("Orchestrator: Failed to save alert to Firestore: $e");
    }

    // Trigger Notification
    final String title = risk == 'High' ? "⚠️ Disease Alert: $disease" : "🔔 Disease Advisory: $disease";
    final String body = "Risk Level: $risk\nRecommended Spray: $spray";
    await DiseasePredictionService.showSystemNotification(
      title: title,
      body: body,
      payload: jsonEncode(alertData),
    );
  }
}
