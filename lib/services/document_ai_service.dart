import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/utils/document_ai_pipeline.dart';

class DocumentAiService {
  // In emulator, 10.0.2.2 routes to the host computer's localhost.
  // In production, configure to the deployed FastAPI domain name.
  static String backendUrl = "http://10.0.2.2:8000/api/v1/extract";

  /// Sends receipt image to FastAPI backend. Falls back to local on-device pipeline if server is unreachable.
  static Future<Map<String, dynamic>> extractDocument(String filePath, String rawText) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileSystemException("File not found", filePath);
      }

      debugPrint("DocumentAiService: Sending extraction request to $backendUrl");
      final request = http.MultipartRequest('POST', Uri.parse(backendUrl));
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      // Define a 5-second connection timeout to ensure rapid offline fallback
      final streamedResponse = await request.send().timeout(const Duration(seconds: 5));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint("DocumentAiService: Successfully received structured JSON from backend.");
        return decoded;
      } else {
        debugPrint("DocumentAiService: Server returned status code ${response.statusCode}. Falling back to local pipeline.");
      }
    } catch (e) {
      debugPrint("DocumentAiService: FastAPI backend connection failed ($e). Executing local on-device pipeline fallback.");
    }

    // --- Local Fail-safe Fallback ---
    final quality = DocumentAiPipeline.analyzeImageQuality(filePath, rawText);
    if (!quality.isAcceptable) {
      return {
        "success": false,
        "confidence": 0.0,
        "error": quality.message,
        "document_type": "unknown",
        "data": null
      };
    }

    return DocumentAiPipeline.extractStructuredData(rawText);
  }
}
