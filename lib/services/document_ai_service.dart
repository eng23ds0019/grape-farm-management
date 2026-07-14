import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'gemini_service.dart';

class DocumentAiService {
  // In emulator, 10.0.2.2 routes to the host computer's localhost.
  // In production, configure to the deployed FastAPI domain name.
  static String backendUrl = "http://10.0.2.2:8000/api/v1/extract";

  /// Sends receipt image to layout-aware Document AI pipeline.
  /// First tries the local FastAPI backend (Tier 1), then falls back to Gemini Cloud Vision (Tier 2)
  /// with production-grade detailed error reporting.
  static Future<Map<String, dynamic>> extractDocument(String filePath, String rawText) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return {
        "success": false,
        "confidence": 0.0,
        "error": "FileSystemException: Image file not found at local path '$filePath'.",
        "document_type": "unknown",
        "data": null
      };
    }

    // ----------------------------------------------------
    // Tier 1: Local FastAPI Backend
    // ----------------------------------------------------
    try {
      debugPrint("DocumentAiService: Attempting Tier-1 local FastAPI extraction...");
      final request = http.MultipartRequest('POST', Uri.parse(backendUrl));
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 4));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint("DocumentAiService: Successfully received structured JSON from FastAPI.");
        
        final data = decoded['data'] ?? {};
        return {
          "success": true,
          "confidence": decoded['confidence'] ?? 0.95,
          "document_type": decoded['document_type'] ?? "fertilizer_bill",
          "data": {
            "shop_name": {"value": data['shop_name'] ?? "", "confidence": 1.0},
            "gst_number": {"value": data['gst_number'] ?? "", "confidence": 1.0},
            "buyer_name": {"value": data['buyer_name'] ?? "", "confidence": 1.0},
            "invoice_number": {"value": data['invoice_number'] ?? "", "confidence": 1.0},
            "date": {"value": data['date'] ?? "", "confidence": 1.0},
            "products": (data['products'] as List? ?? []).map((p) => {
              "itemName": {"value": p['product_name'] ?? "", "confidence": 1.0},
              "quantity": {"value": double.tryParse(p['quantity']?.toString() ?? '1.0') ?? 1.0, "confidence": 1.0},
              "unit": {"value": p['unit'] ?? "bag", "confidence": 1.0},
              "amount": {"value": double.tryParse(p['amount']?.toString() ?? '0.0') ?? 0.0, "confidence": 1.0},
            }).toList(),
            "subtotal": {"value": double.tryParse(data['subtotal']?.toString() ?? '0.0') ?? 0.0, "confidence": 1.0},
            "gst_amount": {"value": double.tryParse(data['gst_amount']?.toString() ?? '0.0') ?? 0.0, "confidence": 1.0},
            "total_amount": {"value": double.tryParse(data['total_amount']?.toString() ?? '0.0') ?? 0.0, "confidence": 1.0},
          }
        };
      } else {
        debugPrint("DocumentAiService: FastAPI backend returned status code ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("DocumentAiService: FastAPI backend connection failed: $e");
    }

    // ----------------------------------------------------
    // Tier 2: Gemini Cloud Vision API
    // ----------------------------------------------------
    debugPrint("DocumentAiService: Attempting Tier-2 layout-aware Gemini extraction...");
    
    // Check if the API Key is set to the default client key (which has no Generative Language API access)
    if (GeminiService.geminiApiKey == GeminiService.defaultApiKey) {
      return {
        "success": false,
        "confidence": 0.0,
        "error": "API Key Error: Gemini API key is missing or unconfigured.\n\n"
            "Please log in as Administrator (Username: 'admin', Password: 'admin123') and save a valid Gemini API key in the admin settings screen.",
        "document_type": "unknown",
        "data": null
      };
    }

    try {
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      String mimeType = "image/jpeg";
      final lowerPath = filePath.toLowerCase();
      if (lowerPath.endsWith(".png")) {
        mimeType = "image/png";
      } else if (lowerPath.endsWith(".webp")) {
        mimeType = "image/webp";
      }

      final promptText = "You are a production-grade Document AI engine specialized in understanding Indian fertilizer bills.\n"
          "Analyze the visual layout, bounding alignments, table grids, and nearby label associations of this bill image.\n"
          "Do NOT guess or search the page randomly. Use invoice layout understanding:\n"
          "- Shop Name & GST Number: Extract from header/logo section. Identify shop details near the top.\n"
          "- Customer Name: Look near labels like 'Buyer', 'Customer', 'Name', 'Billed To'.\n"
          "- Invoice Number: Look near labels like 'Inv No', 'Bill No', 'Receipt No', 'Sl No'.\n"
          "- Date: Look near labels like 'Date', 'Dated'.\n"
          "- Products Table: Locate the itemized purchases table grid. For each row, extract:\n"
          "  * itemName: clean name of fertilizer or pesticide product (e.g. 'Urea', 'DAP 18:46:0').\n"
          "  * quantity: numeric quantity.\n"
          "  * unit: bag, bottle, kg, Litre, packet, etc.\n"
          "  * amount: final total cost of this item row.\n"
          "- Totals section: Extract:\n"
          "  * subtotal (pre-tax sum of items).\n"
          "  * gstAmount (tax total, if available).\n"
          "  * totalAmount (final payable grand total).\n\n"
          "For every field, estimate your legibility/extraction confidence as a double between 0.0 and 1.0 based on visibility, legibility, print quality, and nearby label alignments.\n\n"
          "Raw OCR Text:\n$rawText\n\n"
          "Return ONLY a JSON object matching this schema:\n"
          "{\n"
          "  \"shopName\": {\"value\": \"string or null\", \"confidence\": double},\n"
          "  \"gstNumber\": {\"value\": \"string or null\", \"confidence\": double},\n"
          "  \"customerName\": {\"value\": \"string or null\", \"confidence\": double},\n"
          "  \"invoiceNumber\": {\"value\": \"string or null\", \"confidence\": double},\n"
          "  \"billDate\": {\"value\": \"YYYY-MM-DD or null\", \"confidence\": double},\n"
          "  \"items\": [\n"
          "    {\n"
          "      \"itemName\": {\"value\": \"string\", \"confidence\": double},\n"
          "      \"quantity\": {\"value\": double, \"confidence\": double},\n"
          "      \"unit\": {\"value\": \"string\", \"confidence\": double},\n"
          "      \"amount\": {\"value\": double, \"confidence\": double}\n"
          "    }\n"
          "  ],\n"
          "  \"subtotal\": {\"value\": double, \"confidence\": double},\n"
          "  \"gstAmount\": {\"value\": double, \"confidence\": double},\n"
          "  \"totalAmount\": {\"value\": double, \"confidence\": double}\n"
          "}\n"
          "Ensure response follows JSON schema exactly. Return ONLY the raw JSON string.";

      final payload = {
        "contents": [
          {
            "parts": [
              {
                "inlineData": {
                  "mimeType": mimeType,
                  "data": base64Image
                }
              },
              {
                "text": promptText
              }
            ]
          }
        ],
        "generationConfig": {
          "responseMimeType": "application/json"
        }
      };

      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GeminiService.geminiApiKey}"
      );

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));

      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> geminiResult = jsonDecode(responseBody);

        final candidates = geminiResult['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'] as Map?;
          if (content != null) {
            final parts = content['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              var text = parts[0]['text'] as String?;
              if (text != null) {
                text = text.trim();
                if (text.startsWith("```")) {
                  text = text.replaceAll(RegExp(r'^```json\s*|```$'), '');
                }
                text = text.trim();
                final decodedJson = jsonDecode(text) as Map<String, dynamic>;

                return {
                  "success": true,
                  "confidence": 0.98,
                  "document_type": "fertilizer_bill",
                  "data": {
                    "shop_name": decodedJson['shopName'] ?? {"value": "", "confidence": 0.0},
                    "gst_number": decodedJson['gstNumber'] ?? {"value": "", "confidence": 0.0},
                    "buyer_name": decodedJson['customerName'] ?? {"value": "", "confidence": 0.0},
                    "invoice_number": decodedJson['invoiceNumber'] ?? {"value": "", "confidence": 0.0},
                    "date": decodedJson['billDate'] ?? {"value": "", "confidence": 0.0},
                    "products": decodedJson['items'] ?? [],
                    "subtotal": decodedJson['subtotal'] ?? {"value": 0.0, "confidence": 0.0},
                    "gst_amount": decodedJson['gstAmount'] ?? {"value": 0.0, "confidence": 0.0},
                    "total_amount": decodedJson['totalAmount'] ?? {"value": 0.0, "confidence": 0.0},
                  }
                };
              }
            }
          }
        }
      } else {
        final errorResponse = await response.transform(utf8.decoder).join();
        String detailedError = "HTTP ${response.statusCode}: ";
        if (response.statusCode == 403) {
          detailedError += "403 Forbidden (Gemini API key is unauthorized or disabled).\n\nPlease verify that the Google Generative Language API is enabled on your Google Developer Console.";
        } else if (response.statusCode == 429) {
          detailedError += "429 Too Many Requests (API rate limit or quota exceeded).";
        } else {
          detailedError += errorResponse;
        }

        return {
          "success": false,
          "confidence": 0.0,
          "error": "Gemini API Connection Failed:\n$detailedError",
          "document_type": "unknown",
          "data": null
        };
      }
    } catch (e) {
      String connectionError = e.toString();
      if (e is SocketException) {
        connectionError = "SocketException: Connection refused (Network offline or Google API hosts unreachable).";
      } else if (e is TimeoutException) {
        connectionError = "TimeoutException: Connection request timed out.";
      }
      return {
        "success": false,
        "confidence": 0.0,
        "error": "Gemini API Connection Failed:\n$connectionError",
        "document_type": "unknown",
        "data": null
      };
    }

    return {
      "success": false,
      "confidence": 0.0,
      "error": "Failed to connect to the cloud Document AI parser. All endpoints are currently unreachable.",
      "document_type": "unknown",
      "data": null
    };
  }
}
