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
}
