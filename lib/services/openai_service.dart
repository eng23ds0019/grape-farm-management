import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'gemini_service.dart';

class OpenAiService {
  // Configurable OpenAI API Key
  static String openAiApiKey = "";

  /// Transcribe audio file using OpenAI Whisper API. Falls back to Gemini if API key is not set or request fails.
  static Future<String> transcribeAudio(String filePath, {String? languageCode}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint("OpenAiService: Audio file does not exist at $filePath");
      return "";
    }

    if (openAiApiKey.isEmpty) {
      debugPrint("OpenAiService: API key is empty. Falling back to Gemini.");
      return GeminiService.transcribeAudio(filePath, languageCode: languageCode);
    }

    try {
      final url = Uri.parse("https://api.openai.com/v1/audio/transcriptions");
      final boundary = '----Boundary${DateTime.now().millisecondsSinceEpoch}';
      
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 25);
      
      final request = await client.postUrl(url);
      request.headers.set('Authorization', 'Bearer $openAiApiKey');
      request.headers.set('content-type', 'multipart/form-data; boundary=$boundary');

      final body = BytesBuilder();

      // Add Model parameter
      body.add(utf8.encode('--$boundary\r\n'));
      body.add(utf8.encode('Content-Disposition: form-data; name="model"\r\n\r\n'));
      body.add(utf8.encode('whisper-1\r\n'));

      // Add language parameter if available
      if (languageCode != null) {
        final lang = languageCode.split('-')[0];
        body.add(utf8.encode('--$boundary\r\n'));
        body.add(utf8.encode('Content-Disposition: form-data; name="language"\r\n\r\n'));
        body.add(utf8.encode('$lang\r\n'));
      }

      // Add Prompt parameter to nudge Whisper for mixed Kannada-English
      body.add(utf8.encode('--$boundary\r\n'));
      body.add(utf8.encode('Content-Disposition: form-data; name="prompt"\r\n\r\n'));
      body.add(utf8.encode('Transcribe the agricultural note. Support Kannada (ಕನ್ನಡ), English, or mixed Kannada-English speech.\r\n'));

      // Add File
      final fileName = filePath.split(Platform.pathSeparator).last;
      body.add(utf8.encode('--$boundary\r\n'));
      body.add(utf8.encode('Content-Disposition: form-data; name="file"; filename="$fileName"\r\n'));
      
      String contentType = 'audio/mpeg';
      if (fileName.endsWith('.m4a')) {
        contentType = 'audio/mp4';
      } else if (fileName.endsWith('.wav')) {
        contentType = 'audio/wav';
      } else if (fileName.endsWith('.aac')) {
        contentType = 'audio/aac';
      }
      
      body.add(utf8.encode('Content-Type: $contentType\r\n\r\n'));
      body.add(await file.readAsBytes());
      body.add(utf8.encode('\r\n'));
      body.add(utf8.encode('--$boundary--\r\n'));

      request.add(body.takeBytes());
      
      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> json = jsonDecode(responseBody);
        return (json['text'] as String? ?? "").trim();
      } else {
        final err = await response.transform(utf8.decoder).join();
        debugPrint("OpenAiService: Whisper failed status ${response.statusCode}: $err. Falling back to Gemini.");
        return GeminiService.transcribeAudio(filePath, languageCode: languageCode);
      }
    } catch (e) {
      debugPrint("OpenAiService: Whisper exception $e. Falling back to Gemini.");
      return GeminiService.transcribeAudio(filePath, languageCode: languageCode);
    }
  }

  /// Parses receipt raw text using OpenAI structured chat completions.
  /// Returns structured JSON data matching step 3 requirements.
  static Future<Map<String, dynamic>?> parseReceiptOcr(String cleanedText) async {
    if (openAiApiKey.isEmpty) {
      debugPrint("OpenAiService: API key is empty. Calling Gemini fallback.");
      return _parseReceiptWithGeminiFallback(cleanedText);
    }

    try {
      final url = Uri.parse("https://api.openai.com/v1/chat/completions");
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 20);

      final payload = {
        "model": "gpt-4o-mini",
        "messages": [
          {
            "role": "system",
            "content": "You are a precise agricultural bill parser. Analyze the cleaned OCR text and extract only the relevant fields in JSON. IGNORE phone numbers, GST numbers, invoice IDs, unrelated numbers, and serial numbers.\n\n"
                       "Return a JSON object with these EXACT keys and value types:\n"
                       "- 'shop_name': String (Name of the merchant/shop. Default to 'General Agro Store' if not found)\n"
                       "- 'customer_name': String (Name of the buyer/customer. Default to 'Unknown Customer' if not found)\n"
                       "- 'date': String (Billing date in DD/MM/YYYY format or YYYY-MM-DD. Use today's date if not found)\n"
                       "- 'items': Array of Objects. Each object represents a single fertilizer, pesticide, product, or labour work item and has keys:\n"
                       "  * 'name': String (fertilizer, pesticide, labour name, e.g. 'Urea', 'Coragen', 'Labour Wages')\n"
                       "  * 'amount': Number (cost of this specific item)\n"
                       "  * 'category': String (must be exactly one of: 'Fertilizer', 'Pesticide', 'Labour', 'Other')\n"
                       "  * 'quantity': Number (quantity bought, default to 1.0)\n"
                       "  * 'unit': String (e.g., 'bag', 'kg', 'litre', 'packet', 'worker', 'qty')\n"
                       "- 'total_amount': Number (sum of the items. Use valid total amount payable)\n\n"
                       "Do not output markdown code block ticks. Output raw JSON only."
          },
          {
            "role": "user",
            "content": cleanedText
          }
        ],
        "response_format": { "type": "json_object" }
      };

      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.json;
      request.headers.set('Authorization', 'Bearer $openAiApiKey');
      request.write(jsonEncode(payload));

      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> jsonResponse = jsonDecode(responseBody);
        final content = jsonResponse['choices'][0]['message']['content'] as String;
        return jsonDecode(content.trim()) as Map<String, dynamic>;
      } else {
        final err = await response.transform(utf8.decoder).join();
        debugPrint("OpenAiService: OCR AI parsing failed with status ${response.statusCode}: $err. Calling Gemini fallback.");
        return _parseReceiptWithGeminiFallback(cleanedText);
      }
    } catch (e) {
      debugPrint("OpenAiService: OCR AI parsing exception: $e. Calling Gemini fallback.");
      return _parseReceiptWithGeminiFallback(cleanedText);
    }
  }

  /// Structured voice note parser using OpenAI.
  /// Translates speech context to structured JSON: activity, plot, expense.
  static Future<Map<String, dynamic>?> parseVoiceTranscript(String text) async {
    Map<String, dynamic>? parsed;
    if (openAiApiKey.isEmpty) {
      debugPrint("OpenAiService: API key is empty. Calling Gemini fallback.");
      parsed = await _parseVoiceWithGeminiFallback(text);
    } else {
      try {
        final url = Uri.parse("https://api.openai.com/v1/chat/completions");
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 15);

        final payload = {
          "model": "gpt-4o-mini",
          "messages": [
            {
              "role": "system",
              "content": "You are an assistant for a grape farmer. Analyze the transcription of the farmer's voice note (written in English, Kannada, or mixed language) and extract information into structured JSON.\n\n"
                         "Return a JSON object with these EXACT keys:\n"
                         "- 'activity': String (Normalized agricultural action. E.g., 'Fungicide Spray', 'Urea Application', 'Weeding', 'Pruning', etc.)\n"
                         "- 'plot': String (The plot number, name, or 'Plot 1' by default if not specified)\n"
                         "- 'expense': String (The numeric cost value extracted, or '0' if no expense mentioned)\n\n"
                         "Do not output markdown code blocks. Output raw JSON only."
            },
            {
              "role": "user",
              "content": text
            }
          ],
          "response_format": { "type": "json_object" }
        };

        final request = await client.postUrl(url);
        request.headers.contentType = ContentType.json;
        request.headers.set('Authorization', 'Bearer $openAiApiKey');
        request.write(jsonEncode(payload));

        final response = await request.close();
        if (response.statusCode == 200) {
          final responseBody = await response.transform(utf8.decoder).join();
          final Map<String, dynamic> jsonResponse = jsonDecode(responseBody);
          final content = jsonResponse['choices'][0]['message']['content'] as String;
          parsed = jsonDecode(content.trim()) as Map<String, dynamic>;
        } else {
          final err = await response.transform(utf8.decoder).join();
          debugPrint("OpenAiService: Voice AI parsing failed with status ${response.statusCode}: $err. Calling Gemini fallback.");
          parsed = await _parseVoiceWithGeminiFallback(text);
        }
      } catch (e) {
        debugPrint("OpenAiService: Voice AI parsing exception: $e. Calling Gemini fallback.");
        parsed = await _parseVoiceWithGeminiFallback(text);
      }
    }

    if (parsed == null || parsed.isEmpty) {
      debugPrint("OpenAiService: Online voice parsing failed. Falling back to local parser.");
      parsed = parseVoiceLocally(text);
    }
    return parsed;
  }

  // --- GEMINI FALLBACK IMPLEMENTATIONS ---

  static Future<Map<String, dynamic>?> _parseReceiptWithGeminiFallback(String cleanedText) async {
    try {
      final payload = {
        "contents": [
          {
            "parts": [
              {
                "text": "You are a precise agricultural bill parser. Analyze the cleaned OCR text and extract only the relevant fields in JSON. IGNORE phone numbers, GST numbers, invoice IDs, unrelated numbers, and serial numbers.\n\n"
                       "Return a JSON object with these EXACT keys and value types:\n"
                       "- 'shop_name': String (Name of the merchant/shop. Default to 'General Agro Store' if not found)\n"
                       "- 'customer_name': String (Name of the buyer/customer. Default to 'Unknown Customer' if not found)\n"
                       "- 'date': String (Billing date in DD/MM/YYYY format or YYYY-MM-DD. Use today's date if not found)\n"
                       "- 'items': Array of Objects. Each object represents a single fertilizer, pesticide, product, or labour work item and has keys:\n"
                       "  * 'name': String (fertilizer, pesticide, labour name, e.g. 'Urea', 'Coragen', 'Labour Wages')\n"
                       "  * 'amount': Number (cost of this specific item)\n"
                       "  * 'category': String (must be exactly one of: 'Fertilizer', 'Pesticide', 'Labour', 'Other')\n"
                       "  * 'quantity': Number (quantity bought, default to 1.0)\n"
                       "  * 'unit': String (e.g., 'bag', 'kg', 'litre', 'packet', 'worker', 'qty')\n"
                       "- 'total_amount': Number (sum of the items. Use valid total amount payable)\n\n"
                       "Return ONLY the raw JSON string. Do not include markdown code block formatting."
              },
              {
                "text": cleanedText
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
              var text = parts[0]['text'] as String?;
              if (text != null) {
                text = text.trim();
                if (text.startsWith("```")) {
                  text = text.replaceAll(RegExp(r'^```json\s*|```$'), '');
                }
                return jsonDecode(text.trim()) as Map<String, dynamic>;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("OpenAiService Gemini Fallback Exception: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _parseVoiceWithGeminiFallback(String text) async {
    try {
      final payload = {
        "contents": [
          {
            "parts": [
              {
                "text": "You are an assistant for a grape farmer. Analyze the transcription of the farmer's voice note (written in English, Kannada, or mixed language) and extract information into structured JSON.\n\n"
                       "Return a JSON object with these EXACT keys:\n"
                       "- 'activity': String (Normalized agricultural action. E.g., 'Fungicide Spray', 'Urea Application', 'Weeding', 'Pruning', etc.)\n"
                       "- 'plot': String (The plot number, name, or 'Plot 1' by default if not specified)\n"
                       "- 'expense': String (The numeric cost value extracted, or '0' if no expense mentioned)\n\n"
                       "Return ONLY the raw JSON string. Do not include markdown code block formatting."
              },
              {
                "text": text
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
        final Map<String, dynamic> json = jsonDecode(responseBody);

        final candidates = json['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'] as Map?;
          if (content != null) {
            final parts = content['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              var textRes = parts[0]['text'] as String?;
              if (textRes != null) {
                textRes = textRes.trim();
                if (textRes.startsWith("```")) {
                  textRes = textRes.replaceAll(RegExp(r'^```json\s*|```$'), '');
                }
                return jsonDecode(textRes.trim()) as Map<String, dynamic>;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("OpenAiService Gemini Voice Fallback Exception: $e");
    }
    return null;
  }

  /// 100% Offline Local Fallback Voice Parser that works without any API keys.
  static Map<String, dynamic> parseVoiceLocally(String text) {
    final lower = text.toLowerCase();
    String activity = "Other";
    String plot = "Plot 1";
    String expense = "0";

    // 1. Detect activity
    if (lower.contains("spray") || lower.contains("spraying") || lower.contains("ಸಿಂಪಡಣೆ") || lower.contains("ದವಾ") || lower.contains("दवा")) {
      activity = "Fungicide Spray";
    } else if (lower.contains("urea") || lower.contains("fertilizer") || lower.contains("npk") || lower.contains("gobbara") || lower.contains("ಗೊಬ್ಬರ") || lower.contains("खाद")) {
      activity = "Urea Application";
    } else if (lower.contains("weed") || lower.contains("weeding") || lower.contains("ಕಳೆ")) {
      activity = "Weeding";
    } else if (lower.contains("prun") || lower.contains("pruning") || lower.contains("ಕತ್ತರಿಸು") || lower.contains("छंटाई")) {
      activity = "Pruning";
    } else if (lower.contains("water") || lower.contains("irrigation") || lower.contains("ನೀರು") || lower.contains("पानी")) {
      activity = "Irrigation";
    } else if (lower.contains("labour") || lower.contains("cooli") || lower.contains("ಕೂಲಿ") || lower.contains("मजदूरी")) {
      activity = "Labour work";
    }

    // 2. Detect plot
    final plotMatch = RegExp(r'(plot|ಪ್ಲಾಟ್|प्लॉट)\s*(\d+)', caseSensitive: false).firstMatch(text);
    if (plotMatch != null) {
      plot = "Plot ${plotMatch.group(2)}";
    }

    // 3. Detect expense/amount (e.g. ₹500, 500 rupees, 500 ರೂ, 500 रुपये)
    final expenseMatch = RegExp(r'(?:₹|rs\.?|inr|ರೂ|ರೇಖೆ|रुपये)?\s*(\d{2,7})\b', caseSensitive: false).firstMatch(text);
    if (expenseMatch != null) {
      expense = expenseMatch.group(1)!;
    }

    return {
      'activity': activity,
      'plot': plot,
      'expense': expense,
    };
  }
}
