import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/utils/document_ai_pipeline.dart';
import 'gemini_service.dart';

class DocumentAiService {
  // In emulator, 10.0.2.2 routes to the host computer's localhost.
  // In production, configure to the deployed FastAPI domain name.
  static String backendUrl = "http://10.0.2.2:8000/api/v1/extract";

  /// Sends receipt image to FastAPI backend. Falls back to Gemini 1.5 Flash Cloud Vision API,
  /// then to local on-device pipeline if offline.
  static Future<Map<String, dynamic>> extractDocument(String filePath, String rawText) async {
    // 1. Try FastAPI backend (Tier 1)
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileSystemException("File not found", filePath);
      }

      debugPrint("DocumentAiService: Sending extraction request to $backendUrl");
      final request = http.MultipartRequest('POST', Uri.parse(backendUrl));
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      // Define a 4-second connection timeout to ensure rapid offline/cloud fallback
      final streamedResponse = await request.send().timeout(const Duration(seconds: 4));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint("DocumentAiService: Successfully received structured JSON from backend.");
        return decoded;
      } else {
        debugPrint("DocumentAiService: Server returned status code ${response.statusCode}. Trying Gemini.");
      }
    } catch (e) {
      debugPrint("DocumentAiService: FastAPI backend connection failed ($e). Executing Gemini cloud vision fallback.");
    }

    // 2. Try Gemini 1.5 Flash Cloud Vision API (Tier 2)
    try {
      debugPrint("DocumentAiService: Executing cloud vision extraction via Gemini API.");
      final geminiResult = await GeminiService.analyzeReceipt(filePath);
      if (geminiResult != null && geminiResult.isNotEmpty) {
        debugPrint("DocumentAiService: Successfully parsed document details via Gemini.");
        
        final List<Map<String, String>> mappedProducts = [];
        final rawItems = geminiResult['items'] as List? ?? [];
        for (var item in rawItems) {
          if (item is Map) {
            final double qty = double.tryParse(item['quantity']?.toString() ?? '1') ?? 1.0;
            final double amt = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
            final double price = qty > 0 ? (amt / qty) : amt;

            mappedProducts.add({
              "product_name": item['itemName'] ?? "",
              "quantity": qty.toStringAsFixed(0),
              "unit_price": price.toStringAsFixed(2),
              "amount": amt.toStringAsFixed(2),
            });
          }
        }

        return {
          "success": true,
          "confidence": 0.98,
          "document_type": "fertilizer_bill",
          "data": {
            "shop_name": geminiResult['shopName'] ?? "General Agro Store",
            "buyer_name": geminiResult['customerName'] ?? "Unknown Customer",
            "invoice_number": geminiResult['invoiceNumber'] ?? "",
            "date": geminiResult['billDate'] ?? DateTime.now().toIso8601String().substring(0, 10),
            "products": mappedProducts,
            "total_amount": (geminiResult['totalAmount'] ?? 0.0).toStringAsFixed(2),
          }
        };
      }
    } catch (e) {
      debugPrint("DocumentAiService: Gemini cloud extraction failed ($e). Falling back to Tier-3 local parser.");
    }

    // 3. Local Fail-safe Fallback (Tier 3 - offline)
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
