import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class VectorDbService {
  static const String _pineconeApiKey = "pcsk_Zj6cN_5MMwuQcUqYcR63Cc6YL7Dpq8mCfLVQq3nnnp1Gv5ycFmhSj94xTtFpRw2sLZ7Fi";
  static const String _pineconeEnvironment = "YOUR_PINECONE_ENV"; 
  static const String _pineconeIndexUrl = "https://your-index-url.svc.environment.pinecone.io";

  /// Queries the vector database (Pinecone) with a user's natural language query.
  /// Note: In a true production app, you first convert the query to an embedding
  /// via Gemini/OpenAI, then send that vector to Pinecone. 
  /// For this service, we mock the embedding step and return curated context.
  static Future<String> searchKnowledgeBase(String query) async {
    if (_pineconeApiKey == "YOUR_PINECONE_API_KEY") {
      debugPrint("VectorDbService: No Pinecone API Key set. Using embedded fallback vector DB.");
      return _localVectorSearchFallback(query);
    }

    try {
      // 1. Generate Embedding (Mocked here since we're directly calling the Pinecone REST API)
      final List<double> queryVector = List.generate(768, (index) => 0.01); // Mock embedding for 768-dim model

      // 2. Query Pinecone
      final url = Uri.parse("$_pineconeIndexUrl/query");
      final response = await http.post(
        url,
        headers: {
          "Api-Key": _pineconeApiKey,
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "vector": queryVector,
          "topK": 3,
          "includeMetadata": true,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final matches = data['matches'] as List;
        if (matches.isEmpty) return "";

        // Combine retrieved text from metadata
        return matches.map((m) => m['metadata']['text'] ?? '').join("\n\n");
      } else {
        debugPrint("VectorDbService: Pinecone query failed with ${response.statusCode}: ${response.body}");
        return _localVectorSearchFallback(query);
      }
    } catch (e) {
      debugPrint("VectorDbService: Network error during Pinecone query: $e");
      return _localVectorSearchFallback(query);
    }
  }

  /// An offline, embedded rule-based vector-like search for agricultural knowledge.
  static String _localVectorSearchFallback(String query) {
    final lowerQuery = query.toLowerCase();
    List<String> retrievedContexts = [];

    // Soil preparation
    if (lowerQuery.contains('soil') || lowerQuery.contains('prepare') || lowerQuery.contains('mound')) {
      retrievedContexts.add(
          "[KNOWLEDGE: Soil Preparation] Grapes require well-drained soil (pH 6.5-7.5). Deep ploughing and trenches of 2.5x2.5 ft are recommended before planting.");
    }
    // Pruning
    if (lowerQuery.contains('prun') || lowerQuery.contains('cut') || lowerQuery.contains('october')) {
      retrievedContexts.add(
          "[KNOWLEDGE: Pruning] Forward pruning (October pruning) is for fruit yielding. Foundation pruning (April pruning) is for vegetative growth. Apply Bordeaux paste to cut ends.");
    }
    // Diseases
    if (lowerQuery.contains('mildew') || lowerQuery.contains('downy') || lowerQuery.contains('white') || lowerQuery.contains('fuzz')) {
      retrievedContexts.add(
          "[KNOWLEDGE: Downy Mildew] Symptoms: Yellow oily spots on upper leaf, white fuzzy growth on lower leaf. Triggered by high humidity (>85%) and rain. Treatment: Copper Oxychloride (2g/L) or Metalaxyl+Mancozeb.");
    }
    if (lowerQuery.contains('powdery') || lowerQuery.contains('ash') || lowerQuery.contains('powder')) {
      retrievedContexts.add(
          "[KNOWLEDGE: Powdery Mildew] Symptoms: Ashy white powdery patches on leaves and berries. Thrives in cloudy weather, moderate temps. Treatment: Sulfur 80 WP (2g/L) or Hexaconazole.");
    }
    if (lowerQuery.contains('thrip') || lowerQuery.contains('flea') || lowerQuery.contains('insect') || lowerQuery.contains('bug')) {
      retrievedContexts.add(
          "[KNOWLEDGE: Insect Pests] Flea beetles eat growing buds. Thrips cause berry scarring. Treatment: Imidacloprid (0.3ml/L) or Spinosad.");
    }
    // Nutrition / GA3
    if (lowerQuery.contains('ga3') || lowerQuery.contains('gibberellic') || lowerQuery.contains('berry') || lowerQuery.contains('size')) {
      retrievedContexts.add(
          "[KNOWLEDGE: GA3 & Berry Size] GA3 is applied for berry elongation and thinning. Typical doses range from 10ppm to 40ppm depending on variety. Do not apply during heavy rains.");
    }
    if (lowerQuery.contains('fertilizer') || lowerQuery.contains('yield') || lowerQuery.contains('npk')) {
      retrievedContexts.add(
          "[KNOWLEDGE: Fertilizer & Yield] Balance NPK. Stop excess Nitrogen during flowering to prevent flower drop. Potassium (SOP 0-0-50) is critical during berry development for sugar accumulation.");
    }

    if (retrievedContexts.isEmpty) {
      return "[KNOWLEDGE: General Grape Farming] Grapevines require careful canopy management, timely irrigation, and strict adherence to spray schedules to ensure high yields.";
    }

    return retrievedContexts.join("\n\n");
  }
}
