import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class DrakshaApiClient {
  // Pointing to the live Render backend
  static const String _baseUrl = "https://grape-farm-management.onrender.com/api/v1/chat/orchestrate";

  static Future<Map<String, dynamic>> sendVoiceQuery({
    required String uid,
    required String query,
    required String weatherContext,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "uid": uid,
          "query": query,
          "weather_context": weatherContext,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint("Draksha API Error: ${response.statusCode} - ${response.body}");
        return {
          "response": "I could not reach the reasoning engine.",
          "diseaseRisk": "Low",
          "diseaseName": "None",
          "recommendedSpray": "None"
        };
      }
    } catch (e) {
      debugPrint("Draksha API Network Error: $e");
      return {
        "response": "Network error reaching the reasoning engine.",
        "diseaseRisk": "Low",
        "diseaseName": "None",
        "recommendedSpray": "None"
      };
    }
  }
}
