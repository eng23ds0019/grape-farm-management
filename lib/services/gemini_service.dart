import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class GeminiService {
  static const String defaultApiKey = "AIzaSyAjI0D6aafBBMxvGjguhLE3jTOTmHmyQxw";
  static String geminiApiKey = defaultApiKey;

  /// Transcribes local audio file using Gemini 1.5 Flash API.
  static Future<String> transcribeAudio(String filePath, {String? languageCode}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint("GeminiService: Audio file does not exist at $filePath");
      return "";
    }

    try {
      final bytes = await file.readAsBytes();
      final base64Audio = base64Encode(bytes);

      // Determine mime type based on file extension
      String mimeType = "audio/mp4"; // Default standard container
      if (filePath.endsWith(".mp3")) {
        mimeType = "audio/mp3";
      } else if (filePath.endsWith(".wav")) {
        mimeType = "audio/wav";
      } else if (filePath.endsWith(".aac")) {
        mimeType = "audio/aac";
      } else if (filePath.endsWith(".m4a")) {
        mimeType = "audio/mp4";
      }

      String languagePrompt = "The language of the audio note can be Kannada (ಕನ್ನಡ), Hindi (हिंदी), or English.";
      if (languageCode != null) {
        final code = languageCode.toLowerCase();
        if (code.startsWith("kn")) {
          languagePrompt = "The language of the audio note is Kannada (ಕನ್ನಡ). Please transcribe the audio accurately to Kannada script (ಕನ್ನಡ ಲಿಪಿ).";
        } else if (code.startsWith("hi")) {
          languagePrompt = "The language of the audio note is Hindi (हिंदी). Please transcribe the audio accurately to Devanagari script (देवनागरी लिपि).";
        } else if (code.startsWith("en")) {
          languagePrompt = "The language of the audio note is English. Please transcribe the audio accurately to English text.";
        }
      }

      final payload = {
        "contents": [
          {
            "parts": [
              {
                "inlineData": {
                  "mimeType": mimeType,
                  "data": base64Audio
                }
              },
              {
                "text": "Transcribe this audio recording. $languagePrompt Return ONLY the exact transcribed text. Do not include any introduction, formatting, markdown, explanations, or notes. If the audio is silent or contains only static/noise, return an empty string."
              }
            ]
          }
        ]
      };

      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$geminiApiKey"
      );

      final client = HttpClient();
      // Increase timeout for audio upload processing
      client.connectionTimeout = const Duration(seconds: 15);
      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));

      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> json = jsonDecode(responseBody);

        final candidates = json['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'] as Map?;
          if (content != null) {
            final parts = content['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              final text = parts[0]['text'] as String?;
              if (text != null) {
                return text.trim();
              }
            }
          }
        }
      } else {
        final errorResponse = await response.transform(utf8.decoder).join();
        debugPrint("GeminiService: Transcription failed with status ${response.statusCode}: $errorResponse");
      }
    } catch (e) {
      debugPrint("GeminiService: Exception during transcription: $e");
    }

    return "";
  }

  /// Generates content for a general text prompt against Gemini 1.5 Flash.
  static Future<String> getDirectResponse(String prompt) async {
    try {
      final payload = {
        "contents": [
          {
            "parts": [
              {
                "text": prompt
              }
            ]
          }
        ]
      };

      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$geminiApiKey"
      );

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 20);
      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));

      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> json = jsonDecode(responseBody);

        final candidates = json['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'] as Map?;
          if (content != null) {
            final parts = content['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              final text = parts[0]['text'] as String?;
              if (text != null) {
                return text.trim();
              }
            }
          }
        }
      } else {
         final err = await response.transform(utf8.decoder).join();
         debugPrint("Gemini Direct API Error: ${response.statusCode} - $err");
      }
    } catch (e) {
      debugPrint("GeminiService: Exception in getDirectResponse: $e");
    }
    return "";
  }

  /// Extracts receipt details from a local image file using Gemini 1.5 Flash.
  static Future<Map<String, dynamic>?> analyzeReceipt(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint("GeminiService: Image file does not exist at $filePath");
      return null;
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
                "text": "Analyze this agricultural purchase receipt image. Extract key details and return them in a strict JSON format with these exact keys:\n"
                    "- 'shopName': name of the merchant/shop (default to 'General Agro Store' if not found)\n"
                    "- 'customerName': name of the buyer/customer (often labeled as 'Billed To' or 'Bill To', default to 'Unknown Customer' if not found)\n"
                    "- 'billDate': date of purchase in YYYY-MM-DD format (default to today's date if not found)\n"
                    "- 'totalAmount': total bill amount as a number (default to 0.0 if not found)\n"
                    "- 'items': a list of items bought. Extract ONLY needful agricultural items like fertilizers, pesticides, seeds, products, or labour work. Exclude non-item lines such as SGST, CGST, tax, discount, carry bags, subtotal, or rounding off. Each valid item should have keys:\n"
                    "  * 'itemName': clean name of the fertilizer, pesticide, product, or labour work (strictly remove prices, quantities, serial numbers, and unit text from the name)\n"
                    "  * 'category': category of the item. Must be exactly one of: 'Pesticide', 'Fertilizer', 'Labour', 'Irrigation', 'Transport', 'Packing', 'Machinery / tractor', 'Market expense', 'Other'\n"
                    "  * 'quantity': quantity bought as a number (default to 1.0)\n"
                    "  * 'unit': measurement unit (e.g. 'kg', 'litre', 'packet', 'bottle', 'bag', 'worker', 'day', 'trip', 'other')\n"
                    "  * 'amount': cost of this specific item as a number (default to 0.0)\n\n"
                    "Return ONLY the raw JSON string. Do not include markdown code block formatting like ```json ... ```. If you cannot parse the image, return a JSON object with empty values."
              }
            ]
          }
        ]
      };

      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$geminiApiKey"
      );

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 25);
      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));

      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> json = jsonDecode(responseBody);

        final candidates = json['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'] as Map?;
          if (content != null) {
            final parts = content['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              var text = parts[0]['text'] as String?;
              if (text != null) {
                text = text.trim();
                // Strip markdown code block wrappers if Gemini ignored the prompt
                if (text.startsWith("```")) {
                  text = text.replaceAll(RegExp(r'^```json\s*|```$'), '');
                }
                text = text.trim();
                return jsonDecode(text) as Map<String, dynamic>;
              }
            }
          }
        }
      } else {
        final errorResponse = await response.transform(utf8.decoder).join();
        debugPrint("GeminiService: Receipt analysis failed with status ${response.statusCode}: $errorResponse");
      }
    } catch (e) {
      debugPrint("GeminiService: Exception during receipt analysis: $e");
    }

    return null;
  }

  /// Extracts receipt details by combining the local OCR text and the visual receipt image.
  static Future<Map<String, dynamic>?> analyzeReceiptHybrid(String filePath, String rawOcrText) async {
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint("GeminiService: Image file does not exist at $filePath");
      return null;
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
                "text": "Analyze this agricultural purchase receipt image along with the raw OCR text extracted from it.\n"
                    "Compare the visual image and raw OCR text to correct spelling mistakes, read human handwriting, align columns/tables, and extract the correct details.\n"
                    "Extract key details and return them in a strict JSON format with these exact keys:\n"
                    "- 'shopName': name of the merchant/shop (strictly extract the correct shop name from the receipt header/logo. Return null if not found. Do not make up a dummy shop name)\n"
                    "- 'customerName': name of the buyer/customer (often labeled as 'Billed To' or 'Bill To', return null if not found. Do not make up a dummy customer name)\n"
                    "- 'billDate': date of purchase in YYYY-MM-DD format (return null if not found)\n"
                    "- 'totalAmount': total bill amount as a number (return null if not found)\n"
                    "- 'items': a list of items bought. Extract ONLY agricultural items like fertilizers, pesticides, seeds, products, or labour work. Exclude non-item lines such as SGST, CGST, tax, discount, carry bags, subtotal, or rounding off. Each valid item should have keys:\n"
                    "  * 'itemName': clean name of the fertilizer, pesticide, product, or labour work (strictly remove prices, quantities, serial numbers, and unit text from the name)\n"
                    "  * 'category': category of the item. Must be exactly one of: 'Pesticide', 'Fertilizer', 'Labour', 'Irrigation', 'Transport', 'Packing', 'Machinery / tractor', 'Market expense', 'Other'\n"
                    "  * 'quantity': quantity bought as a number (default to 1.0)\n"
                    "  * 'unit': measurement unit (e.g. 'kg', 'litre', 'packet', 'bottle', 'bag', 'worker', 'day', 'trip', 'other')\n"
                    "  * 'hsnCode': HSN code of the item if printed (return null or empty if not found)\n"
                    "  * 'netAmount': unit price or net rate before tax for this item (return null if not found)\n"
                    "  * 'amount': cost of this specific item as a number (return null if not found)\n\n"
                    "Raw OCR Text from MLKit:\n$rawOcrText\n\n"
                    "Return ONLY the raw JSON string. Do not include markdown code block formatting like ```json ... ```. If you cannot parse the image, return a JSON object with empty/null values. Do NOT use mock, dummy, or placeholder data under any circumstances."
              }
            ]
          }
        ],
        "generationConfig": {
          "responseMimeType": "application/json"
        }
      };

      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$geminiApiKey"
      );

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 25);
      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));

      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> json = jsonDecode(responseBody);

        final candidates = json['candidates'] as List?;
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
                return jsonDecode(text) as Map<String, dynamic>;
              }
            }
          }
        }
      } else {
        final errorResponse = await response.transform(utf8.decoder).join();
        debugPrint("GeminiService: Hybrid receipt analysis failed with status ${response.statusCode}: $errorResponse");
      }
    } catch (e) {
      debugPrint("GeminiService: Exception during hybrid receipt analysis: $e");
    }

    return null;
  }

  /// Extracts structured invoice information using layout-aware Document AI.
  static Future<Map<String, dynamic>?> analyzeFertilizerInvoice(String filePath, String rawOcrText) async {
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint("GeminiService: Image file does not exist at $filePath");
      return null;
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
          "Raw OCR Text from MLKit:\n$rawOcrText\n\n"
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
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$geminiApiKey"
      );

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 25);
      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));

      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> json = jsonDecode(responseBody);

        final candidates = json['candidates'] as List?;
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
                return jsonDecode(text) as Map<String, dynamic>;
              }
            }
          }
        }
      } else {
        final errorResponse = await response.transform(utf8.decoder).join();
        debugPrint("GeminiService: Fertilizer invoice analysis failed with status ${response.statusCode}: $errorResponse");
      }
    } catch (e) {
      debugPrint("GeminiService: Exception during fertilizer invoice analysis: $e");
    }

    return null;
  }

  /// Generates a natural, fluent, and personalized chat response for the farmer.
  static Future<String> getChatResponse({
    required String farmerName,
    required String query,
    required String languageCode,
    required String plotStage,
    required String personalizedContextJson,
    required String knowledgeBaseContext,
    required List<Map<String, dynamic>> chatHistory,
  }) async {
    try {
      final languageName = languageCode == 'kn-IN' ? 'Kannada (ಕನ್ನಡ)' : (languageCode == 'hi-IN' ? 'Hindi (हिंदी)' : 'English');

      final systemPrompt = "You are Draksha AI, a friendly, highly intelligent grape farming voice advisor.\n"
          "Address the farmer as '$farmerName'. Maintain a warm, conversational connection. Do not sound robotic.\n"
          "Current Plot Stage: '$plotStage'.\n\n"
          "--- LAYER 1: PERSONALIZED FARMER MEMORY (FIRESTORE) ---\n"
          "JSON Summary of farmer's recent activity:\n$personalizedContextJson\n\n"
          "--- LAYER 2: RELEVANT GRAPE FARMING KNOWLEDGE (RAG) ---\n"
          "$knowledgeBaseContext\n\n"
          "--- INSTRUCTIONS ---\n"
          "1. Reason step-by-step internally, but only output the final polite, natural response.\n"
          "2. Answer in $languageName. If they spoke mixed, you can reply mixed.\n"
          "3. Return ONLY the direct spoken response message. No formatting, no asterisks (**), no markdown. Clean verbal text for TTS.";

      // Build Chat History
      final List<Map<String, dynamic>> contents = [];
      for (var msg in chatHistory) {
        contents.add({
          "role": msg['role'] == 'user' ? 'user' : 'model',
          "parts": [{"text": msg['text']}]
        });
      }
      // Add current query
      contents.add({
        "role": "user",
        "parts": [{"text": query}]
      });

      final payload = {
        "systemInstruction": {
          "parts": [
            { "text": systemPrompt }
          ]
        },
        "contents": contents
      };

      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$geminiApiKey"
      );

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 20);
      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));

      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> json = jsonDecode(responseBody);

        final candidates = json['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'] as Map?;
          if (content != null) {
            final parts = content['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              final text = parts[0]['text'] as String?;
              if (text != null) {
                return text.trim();
              }
            }
          }
        }
      } else {
         final err = await response.transform(utf8.decoder).join();
         debugPrint("Gemini Chat API Error: \${response.statusCode} - \$err");
      }
    } catch (e) {
      debugPrint("GeminiService: Exception generating chat response: $e");
    }

    // Call 100% offline local multi-agent smart advisor fallback instead of generic error message!
    return getLocalAdvisorResponse(
      farmerName: farmerName,
      query: query,
      languageCode: languageCode,
      plotStage: plotStage,
      personalizedContextJson: personalizedContextJson,
      knowledgeBaseContext: knowledgeBaseContext,
    );
  }

  /// 100% Offline Local Multi-Agent Smart Advisor Fallback System
  static String getLocalAdvisorResponse({
    required String farmerName,
    required String query,
    required String languageCode,
    required String plotStage,
    required String personalizedContextJson,
    required String knowledgeBaseContext,
  }) {
    final lower = query.toLowerCase();
    final isKn = languageCode == 'kn-IN';
    final isHi = languageCode == 'hi-IN';

    final isExpenseQuery = lower.contains("spent") || lower.contains("spend") || lower.contains("expense") || lower.contains("cost") || lower.contains("ಖರ್ಚು") || lower.contains("ಖರ್ಚುಗಳು") || lower.contains("ಖರ್ಚಿ") || lower.contains("खर्च") || lower.contains("खर्चे");
    final isYieldQuery = lower.contains("yield") || lower.contains("turnover") || lower.contains("harvest") || lower.contains("sales") || lower.contains("ಇಳುವರಿ") || lower.contains("ಫಸಲು") || lower.contains("ಮಾರ್ಕೆಟ್") || lower.contains("उपज") || lower.contains("पैदावार");
    final isLogQuery = lower.contains("log") || lower.contains("diary") || lower.contains("entry") || lower.contains("history") || lower.contains("ಡೈರಿ") || lower.contains("ದಾಖಲೆ") || lower.contains("ಇತಿಹಾಸ") || lower.contains("डायरी") || lower.contains("इतिहास");

    if (isExpenseQuery) {
      if (isKn) {
        return "ನಮಸ್ತೆ $farmerName! ನಿಮ್ಮ ಇತ್ತೀಚಿನ ಖರ್ಚುಗಳ ವಿವರಗಳನ್ನು ನೀವು ಮುಖ್ಯ ಪರದೆಯ 'ವೆಚ್ಚಗಳು' (Expenses) ವಿಭಾಗದಲ್ಲಿ ಪರಿಶೀಲಿಸಬಹುದು.";
      } else if (isHi) {
        return "नमस्ते $farmerName! आपके हाल के खर्चों का विवरण मुख्य स्क्रीन के 'खर्च' (Expenses) अनुभाग में देखा जा सकता है।";
      } else {
        return "[ Draksha AI Multi-Agent Advisor ]\nHello $farmerName! I am offline right now. You can review your expenses in the 'Expenses' section on the dashboard.";
      }
    }

    if (isYieldQuery) {
      if (isKn) {
        return "ನಮಸ್ತೆ $farmerName! ನಿಮ್ಮ ಟರ್ನೋವರ್ ವಿವರಗಳನ್ನು 'ಟರ್ನೋವರ್' ವಿಭಾಗದಲ್ಲಿ ಪರಿಶೀಲಿಸಿ.";
      } else if (isHi) {
        return "नमस्ते $farmerName! अपने टर्नओवर का विवरण 'टर्नओवर' अनुभाग में जांचें।";
      } else {
        return "[ Draksha AI Multi-Agent Advisor ]\nHello $farmerName! I am offline right now. Check the 'Turnover' tab to view specific vehicle dispatch numbers and sales.";
      }
    }

    if (isLogQuery) {
      if (isKn) {
        return "ನಮಸ್ತೆ $farmerName! ನಿಮ್ಮ ಕೊನೆಯ ಡೈರಿ ನಮೂದುಗಳನ್ನು 'ಡೈರಿ' ವಿಭಾಗದಲ್ಲಿ ನೋಡಿ.";
      } else if (isHi) {
        return "नमस्ते $farmerName! अपनी हाल की डायरी प्रविष्टियाँ 'डायरी' अनुभाग में देखें।";
      } else {
        return "[ Draksha AI Multi-Agent Advisor ]\nHello $farmerName! I am offline. Please check the Dairy section for logs.";
      }
    }

    // 1. Downy Mildew
    if (lower.contains("downy") || lower.contains("ಡೌನಿ") || lower.contains("डाउन")) {
      if (isKn) {
        return "ನಮಸ್ತೆ $farmerName! ಡೌನಿ ಮಿಲ್ಡ್ಯೂ (Downy Mildew) ರೋಗ ನಿಯಂತ್ರಣಕ್ಕಾಗಿ:\n"
            "- ಹೂಬಿಡುವ ಹಂತದಲ್ಲಿ (Flowering stage) ಮೆಟಾಲಾಕ್ಸಿಲ್ (Metalaxyl) ಅಥವಾ ಸೈಮೋಕ್ಸಾನಿಲ್ (Cymoxanil) ಆಧಾರಿತ ಶಿಲೀಂಧ್ರನಾಶಕಗಳನ್ನು ಬಳಸಿ.\n"
            "- ಬೋರ್ಡೋ ಮಿಶ್ರಣ (Bordeaux mixture) ಅಥವಾ ತಾಮ್ರದ ಶಿಲೀಂಧ್ರನಾಶಕಗಳನ್ನು ಹೂಬಿಡುವಾಗ ಸಿಂಪಡಿಸಬೇಡಿ, ಇದು ಹೂವು ಉದುರಲು ಕಾರಣವಾಗಬಹುದು.\n"
            "- ತೋಟದಲ್ಲಿ ಗಾಳಿ ಮತ್ತು ಬೆಳಕು ಚೆನ್ನಾಗಿ ಬೀಳುವಂತೆ ಕ್ಯಾನೋಪಿ ನಿರ್ವಹಣೆ ಮಾಡಿ.";
      } else if (isHi) {
        return "नमस्ते $farmerName! डाउन मून (Downy Mildew) रोग नियंत्रण के लिए:\n"
            "- फूल आने की अवस्था (Flowering stage) में मेटलैक्सिल (Metalaxyl) या साइमोक्सानिल (Cymoxanil) आधारित कवकनाशी का उपयोग करें।\n"
            "- फूल आने के समय बोर्डो मिश्रण (Bordeaux mixture) या तांबे के कवकनाशी का छिड़काव न करें, इससे फूल गिर सकते हैं।\n"
            "- बगीचे में हवा और रोशनी का अच्छा संचार रखने के लिए कैनोपी प्रबंधन करें।";
      } else {
        return "[ Draksha AI Multi-Agent Advisor ]\n"
            "Hello $farmerName! Here is the expert advice for Downy Mildew during the '$plotStage' stage:\n"
            "- **Disease Specialist**: Apply systemic fungicides like Metalaxyl-MZ or Cymoxanil (e.g. Curzate) to protect active growing tissue.\n"
            "- **Agronomist**: Avoid applying copper-based fungicides (like Bordeaux mixture) directly during flowering as it can cause flower drop and phytotoxicity.\n"
            "- **Management**: Keep the canopy open to facilitate proper air circulation and reduce micro-humidity around the bunches.";
      }
    }

    // 2. Powdery Mildew
    if (lower.contains("powdery") || lower.contains("ಬೂದಿ") || lower.contains("पाउडर")) {
      if (isKn) {
        return "ನಮಸ್ತೆ $farmerName! ಬೂದಿ ರೋಗ (Powdery Mildew) ನಿಯಂತ್ರಣಕ್ಕಾಗಿ:\n"
            "- ಸಲ್ಫರ್ (Sulfur 80% WDG) ಅಥವಾ ಡಿನೋಕ್ಯಾಪ್ (Dinocap) ಸಿಂಪಡಿಸಿ.\n"
            "- ಆರಂಭಿಕ ಹಂತದಲ್ಲಿ ಹೆಕ್ಸಾಕೋನಜೋಲ್ (Hexaconazole) ಅಥವಾ ಟ್ರಯಾಡಿಮೆಫೋನ್ ಬಳಸಿ.\n"
            "- ತೇವಾಂಶ ಮತ್ತು ಮೋಡ ಕವಿದ ವಾತಾವರಣದಲ್ಲಿ ರೋಗ ಹರಡುವಿಕೆ ಹೆಚ್ಚಿರುವುದರಿಂದ ತೀವ್ರ ನಿಗಾ ಇರಿಸಿ.";
      } else if (isHi) {
        return "नमस्ते $farmerName! पाउडर फफूंदी (Powdery Mildew) नियंत्रण के लिए:\n"
            "- सल्फर (Sulfur 80% WDG) या डिनोकैप (Dinocap) का छिड़काव करें।\n"
            "- शुरुआती चरण में हेक्साकोनाज़ोल (Hexaconazole) या ट्रायडिमफ़ोन का उपयोग करें।\n"
            "- नमी और बादल छाए रहने वाले मौसम में रोग फैलने का खतरा अधिक रहता है, इसलिए विशेष ध्यान दें।";
      } else {
        return "[ Draksha AI Multi-Agent Advisor ]\n"
            "Hello $farmerName! For Powdery Mildew control:\n"
            "- **Disease Specialist**: Spray wettable Sulfur (80% WDG) at 2g/L or Dinocap.\n"
            "- **Agronomist**: For systemic control, use Triazoles like Hexaconazole or Penconazole (Topas).\n"
            "- **Management**: Keep a close watch during cool, dry days with high relative humidity, which favor powdery mildew development.";
      }
    }

    // 3. Bordeaux / Chemical mixing warning
    if (lower.contains("bordeaux") || lower.contains("ಬೋರ್ಡೋ") || lower.contains("बोर्डो") || lower.contains("mix") || lower.contains("ಮಿಶ್ರಣ")) {
      if (isKn) {
        return "ಬೋರ್ಡೋ ಮಿಶ್ರಣ (Bordeaux mixture) ಬಳಕೆ ಎಚ್ಚರಿಕೆ:\n"
            "- ಬೋರ್ಡೋ ಮಿಶ್ರಣದೊಂದಿಗೆ ಸಲ್ಫರ್ (Sulfur) ಅನ್ನು ಎಂದಿಗೂ ಮಿಶ್ರಣ ಮಾಡಬೇಡಿ! ಇದು ಗಿಡದ ಎಲೆಗಳು ಮತ್ತು ಹೂವುಗಳನ್ನು ಸುಡುತ್ತದೆ (Phytotoxicity).\n"
            "- ಬೋರ್ಡೋ ಮಿಶ್ರಣವನ್ನು ಹೂಬಿಡುವ ಹಂತದಲ್ಲಿ ಸಿಂಪಡಿಸಬೇಡಿ.\n"
            "- ಇದನ್ನು ತಯಾರಿಸಿದ ತಕ್ಷಣವೇ ಬಳಸಬೇಕು, ಶೇಖರಿಸಿಡಬಾರದು.";
      } else if (isHi) {
        return "बोर्डो मिश्रण (Bordeaux mixture) उपयोग की चेतावनी:\n"
            "- बोर्डो मिश्रण के साथ सल्फर (Sulfur) को कभी न मिलाएं! यह पत्तियों और फूलों को गंभीर रूप से जला सकता है।\n"
            "- फूल आने की अवस्था में बोर्डो मिश्रण का छिड़काव करने से बचें।\n"
            "- इसे बनाने के तुरंत बाद उपयोग किया जाना चाहिए, इसे स्टोर न करें।";
      } else {
        return "[ Draksha AI Multi-Agent Advisor ]\n"
            "• **Critical Warning**: Never mix Bordeaux mixture with Sulfur or organophosphate pesticides! This combination causes severe phytotoxicity (foliage scorching).\n"
            "- Avoid spraying Bordeaux mixture during the flowering/bloom stage.\n"
            "- Use freshly prepared Bordeaux mixture within 24 hours for optimum results.";
      }
    }

    // 4. Urea application warning
    if (lower.contains("urea") || lower.contains("ಯೂರಿಯಾ") || lower.contains("यूरिया")) {
      if (isKn) {
        return "ಯೂರಿಯಾ (Urea) ಗೊಬ್ಬರ ಬಳಕೆ ಸಲಹೆ:\n"
            "- ಹಣ್ಣು ಪಕ್ವವಾಗುವ ಹಂತದಲ್ಲಿ (Fruit ripening/Sugar development) ಹೆಚ್ಚಿನ ಯೂರಿಯಾ ನೀಡಬೇಡಿ. ಇದು ಹಣ್ಣು ಪಕ್ವವಾಗುವುದನ್ನು ತಡ ಮಾಡುತ್ತದೆ ಮತ್ತು ಹಣ್ಣಿನ ಗುಣಮಟ್ಟವನ್ನು ಕಡಿಮೆ ಮಾಡುತ್ತದೆ.\n"
            "- ಸಾರಜನಕದ ಅಗತ್ಯವಿದ್ದರೆ ಹೂಬಿಡುವ ಮುನ್ನ ಅಥವಾ ಆರಂಭಿಕ ಹಂತದಲ್ಲಿ ಮಾತ್ರ ಕೊಡಿ.";
      } else if (isHi) {
        return "यूरिया (Urea) उर्वरक उपयोग की सलाह:\n"
            "- फल पकने (Fruit ripening/Sugar development) के चरण में अधिक यूरिया न दें। यह फल पकने में देरी करता है और गुणवत्ता को खराब करता है।\n"
            "- नाइट्रोजन की आवश्यकता होने पर केवल फूल आने से पहले या शुरुआती चरण में ही दें।";
      } else {
        return "[ Draksha AI Multi-Agent Advisor ]\n"
            "- **Warning**: Do not apply heavy nitrogen/Urea during the sugar development or fruit ripening stages. Excessive nitrogen delays wood maturity, slows down sugar accumulation, and makes grapes susceptible to post-harvest decay.\n"
            "- Nitrogen should be applied post-harvest or during early vegetative stages for canopy establishment.";
      }
    }

    // 5. GA3 / Gibberellic Acid
    if (lower.contains("ga3") || lower.contains("gibberellic") || lower.contains("ಜಿಎ3")) {
      if (isKn) {
        return "ಜಿಎ3 (Gibberellic Acid) ಬಳಕೆ ವಿವರ:\n"
            "- ಹೂಬಿಡುವ ಹಂತದಲ್ಲಿ ಕಡ್ಡಿ ಉದ್ದವಾಗಲು ಮತ್ತು ಹೂವು ವಿರಳವಾಗಿಸಲು 10-15 ppm ಬಳಸಿ.\n"
            "- ಹಣ್ಣು ಬೆಳೆಯುವ ಹಂತದಲ್ಲಿ (Berry growth) ಗಾತ್ರ ಹೆಚ್ಚಿಸಲು 20-30 ppm ಬಳಸಿ.\n"
            "- ಹೆಚ್ಚಿನ ಪ್ರಮಾಣದ ಬಳಕೆ ಕಡ್ಡಿಯನ್ನು ಗಟ್ಟಿಯಾಗಿಸಿ ಬೆರ್ರಿ ಉದುರಲು ಕಾರಣವಾಗಬಹುದು.";
      } else if (isHi) {
        return "जीए3 (Gibberellic Acid) उपयोग का विवरण:\n"
            "- फूल आने के समय डंठल लंबा करने और फूलों को विरल करने के लिए 10-15 ppm का उपयोग करें।\n"
            "- फल विकास (Berry growth) के समय आकार बढ़ाने के लिए 20-30 ppm का उपयोग करें।\n"
            "- आवश्यकता से अधिक उपयोग डंठल को कड़ा कर देता है जिससे फल झड़ सकते हैं।";
      } else {
        return "[ Draksha AI Multi-Agent Advisor ]\n"
            "GA3 (Gibberellic Acid) application guidelines:\n"
            "- Pre-bloom (elongation): Apply 10-15 ppm to stretch cluster rachis.\n"
            "- Bloom (thinning): Apply 10-15 ppm at 40-50% bloom to thin out berries.\n"
            "- Berry growth (sizing): Apply 25-40 ppm at 4-6mm size to boost cell division.\n"
            "- Adjust water pH to slightly acidic (5.5 - 6.5) for optimal GA3 efficacy.";
      }
    }

    // Default responses
    if (isKn) {
      return "ನಮಸ್ತೆ $farmerName! ದ್ರಾಕ್ಷಿ ತೋಟದ ಕ್ಯಾನೋಪಿ ನಿರ್ವಹಣೆ, ರೋಗ ನಿಯಂತ್ರಣ (ಡೌನಿ/ಬೂದಿ ರೋಗ) ಮತ್ತು ಗೊಬ್ಬರ ನಿರ್ವಹಣೆ ಬಗ್ಗೆ ನಿಮ್ಮ ಪ್ರಶ್ನೆಯನ್ನು ಕೇಳಿ. ನಿಖರ ಸಲಹೆ ನೀಡಲು ನಾನು ಸದಾ ಸಿದ್ಧ.";
    } else if (isHi) {
      return "नमस्ते $farmerName! अंगूर के बाग के कैनोपी प्रबंधन, रोग नियंत्रण (डाउन/पाउडर फफूंदी) और उर्वरक प्रबंधन के बारे में अपना प्रश्न पूछें। सही सलाह देने के लिए मैं हमेशा तैयार हूँ।";
    }
    return "[ Draksha AI Multi-Agent Advisor ]\n"
        "Hello $farmerName! I am your Multi-Agent Farm Advisor. Here are some quick guidelines for your grapes:\n"
        "- **Disease Control**: Use Metalaxyl or Cymoxanil for Downy Mildew; use Sulfur or Hexaconazole for Powdery Mildew.\n"
        "- **Pruning & Canopy**: Avoid chemical mixing incompatibilities (e.g. Bordeaux + Sulfur).\n"
        "- **Plot Status**: Your plot is currently in the '$plotStage' stage. Customize your inputs accordingly.\n"
        "Ask me about specific chemicals, diseases, or fertilizer dosing for more detailed guidance.";
  }

  /// Drafts a professional, descriptive diary note from a short voice note or keywords.
  static Future<String> draftDiaryNote({
    required String prompt,
    required String languageCode,
  }) async {
    try {
      final languageName = languageCode == 'kn-IN' ? 'Kannada (ಕನ್ನಡ)' : (languageCode == 'hi-IN' ? 'Hindi (हिंदी)' : 'English');
      
      final payload = {
        "contents": [
          {
            "parts": [
              {
                "text": "You are a professional agronomist and assistant. Draft a beautiful, clean, structured farm diary entry note in $languageName based on these raw notes/keywords: '$prompt'.\n"
                    "Make it descriptive but concise, suitable for a professional grape farm diary. Return ONLY the drafted note. Do not include any headers, greeting, markdown formatting, explanations, or quotes."
              }
            ]
          }
        ]
      };

      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$geminiApiKey"
      );

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));

      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> json = jsonDecode(responseBody);

        final candidates = json['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'] as Map?;
          if (content != null) {
            final parts = content['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              final text = parts[0]['text'] as String?;
              if (text != null) {
                return text.trim();
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("GeminiService: Exception drafting diary note: $e");
    }
    return prompt; // Fallback to raw prompt if it fails
  }
}
