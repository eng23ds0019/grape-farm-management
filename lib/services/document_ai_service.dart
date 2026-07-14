import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'gemini_service.dart';

class DocumentAiService {
  static String backendUrl = "http://10.0.2.2:8000/api/v1/extract";

  /// Sends receipt image to layout-aware Document AI pipeline.
  /// Recognizes invoice sections, labels, tables, totals, and buyer/merchant associations.
  static Future<Map<String, dynamic>> extractDocument(String filePath, String rawText) async {
    try {
      debugPrint("DocumentAiService: Executing layout-aware structured invoice extraction via Gemini API.");
      final geminiResult = await GeminiService.analyzeFertilizerInvoice(filePath, rawText);
      if (geminiResult != null && geminiResult.isNotEmpty) {
        debugPrint("DocumentAiService: Successfully parsed document layout details.");
        
        // Return the full structured result mapping values and confidence scores
        return {
          "success": true,
          "confidence": 0.98,
          "document_type": "fertilizer_bill",
          "data": {
            "shop_name": geminiResult['shopName'] ?? {"value": "", "confidence": 0.0},
            "gst_number": geminiResult['gstNumber'] ?? {"value": "", "confidence": 0.0},
            "buyer_name": geminiResult['customerName'] ?? {"value": "", "confidence": 0.0},
            "invoice_number": geminiResult['invoiceNumber'] ?? {"value": "", "confidence": 0.0},
            "date": geminiResult['billDate'] ?? {"value": "", "confidence": 0.0},
            "products": geminiResult['items'] ?? [],
            "subtotal": geminiResult['subtotal'] ?? {"value": 0.0, "confidence": 0.0},
            "gst_amount": geminiResult['gstAmount'] ?? {"value": 0.0, "confidence": 0.0},
            "total_amount": geminiResult['totalAmount'] ?? {"value": 0.0, "confidence": 0.0},
          }
        };
      }
    } catch (e) {
      debugPrint("DocumentAiService: Gemini layout extraction failed ($e).");
    }

    // Default structure on extraction failure (e.g. offline)
    return {
      "success": false,
      "confidence": 0.0,
      "error": "Failed to connect to the cloud Document AI parser. Please check your internet connection.",
      "document_type": "unknown",
      "data": null
    };
  }
}
