import 'dart:convert';
import 'dart:io';

class TranslationService {
  /// Translates text using the client-free, open-source Google Translate GTX API.
  /// sl = source language (e.g. 'en', 'kn', 'hi')
  /// tl = target language (e.g. 'en', 'kn', 'hi')
  static Future<String> translate({
    required String text,
    required String fromLanguage,
    required String toLanguage,
  }) async {
    if (text.trim().isEmpty) return text;
    if (fromLanguage == toLanguage) return text;

    try {
      final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$fromLanguage&tl=$toLanguage&dt=t&q=${Uri.encodeComponent(text)}',
      );

      final client = HttpClient();
      final request = await client.getUrl(url);
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final List<dynamic> parsed = jsonDecode(responseBody);
        
        if (parsed.isNotEmpty && parsed[0] != null) {
          final List<dynamic> translationItems = parsed[0];
          String result = "";
          for (var item in translationItems) {
            if (item is List && item.isNotEmpty && item[0] != null) {
              result += item[0].toString();
            }
          }
          return result;
        }
      }
    } catch (e) {
      print("Translation error: $e");
    }
    return text; // Fallback to original text if API fails
  }
}
