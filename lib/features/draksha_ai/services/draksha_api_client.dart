import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DrakshaApiClient {
  static const String _baseUrl =
      "https://grape-farm-management.onrender.com";

  /// Main orchestration endpoint — voice and text queries
  static Future<Map<String, dynamic>> sendQuery({
    required String uid,
    required String query,
    String farmId = "",
    String language = "en",
    String? imageBase64,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$_baseUrl/api/v1/chat/orchestrate"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "uid": uid,
              "query": query,
              "farm_id": farmId,
              "language": language,
              if (imageBase64 != null) "image_base64": imageBase64,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint("✅ Draksha AI response received");
        return data;
      } else {
        debugPrint("⚠️ Draksha API error: ${response.statusCode}");
        return _gracefulFallback();
      }
    } catch (e) {
      debugPrint("❌ Draksha API network error: $e");
      return _gracefulFallback();
    }
  }

  /// Backward-compatible wrapper used by existing voice screen
  static Future<Map<String, dynamic>> sendVoiceQuery({
    required String uid,
    required String query,
    String weatherContext = "",
  }) =>
      sendQuery(uid: uid, query: query);

  static Map<String, dynamic> _gracefulFallback() {
    return {
      "response":
          "I am your Vineyard Manager. I am starting up — please try again in a moment.",
      "diseaseRisk": "Low",
      "diseaseName": "None",
      "recommendedSpray": "None",
      "cropStage": "Unknown",
    };
  }

  /// Disease prediction endpoint — pure deterministic logic
  static Future<Map<String, dynamic>> predictDisease({
    required String uid,
    String location = "Nashik",
    double? lat,
    double? lon,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$_baseUrl/api/v1/predict-disease"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "uid": uid,
              "location": location,
              if (lat != null) "lat": lat,
              if (lon != null) "lon": lon,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {"diseaseRisk": "Low"};
    } catch (e) {
      debugPrint("❌ Draksha API disease prediction error: $e");
      return {"diseaseRisk": "Low"};
    }
  }
}
