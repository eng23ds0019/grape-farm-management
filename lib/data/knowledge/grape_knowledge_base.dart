class GrapeKnowledgeBase {
  /// Permanent agricultural knowledge base.
  /// To save tokens, the router will only extract relevant sections based on the farmer's query.
  static const Map<String, String> _knowledgeSections = {
    'downy_mildew': '''
### Downy Mildew (ಡೌನಿ ಮಿಲ್ಡ್ಯೂ / डाउनी मिल्ड्यू)
- **Symptoms**: Yellow oil-like spots on top of leaves, white cottony growth on the underside.
- **Weather Risk**: High humidity (>80%), rainfall, and temperatures between 15-25°C.
- **Prevention/IPM**: Keep canopy open for aeration. Avoid excessive irrigation.
- **Chemical Control**: Copper Oxychloride (COC), Bordeaux mixture (1%), or Metalaxyl + Mancozeb (Ridomil Gold).
- **Organic Control**: Trichoderma viride or Pseudomonas fluorescens spray.
- **Crucial Rule**: NEVER mix copper-based fungicides with soluble sulfur (causes leaf burning).
''',
    'powdery_mildew': '''
### Powdery Mildew (ಪುಡಿ ರೋಗ / पाउडरी मिल्ड्यू)
- **Symptoms**: White ash-like powder on leaves, stems, and berries. Berries may crack.
- **Weather Risk**: Cloudy weather, moderate temperatures (20-30°C), and low/fluctuating humidity.
- **Prevention/IPM**: Remove infected shoots. Ensure good sunlight penetration.
- **Chemical Control**: Soluble Sulfur (80% WDG), Dinocap, or Penconazole (Topas).
- **Organic Control**: Milk spray (1 part milk : 9 parts water) or Ampelomyces quisqualis.
''',
    'flea_beetle': '''
### Flea Beetle (ಉಡದ ನುಸಿ / फ्ली बीटल)
- **Symptoms**: Holes in leaves, scabbing or scarring on berries.
- **Risk**: Very common immediately after pruning when buds begin to burst.
- **Chemical Control**: Imidacloprid, Spinosad, or Lambda-cyhalothrin.
''',
    'pruning': '''
### Pruning (ಕತ್ತರಿಸುವಿಕೆ / छंटाई)
- **Foundation Pruning (April/Back Pruning)**: Done for vegetative growth and sub-cane development.
- **Forward Pruning (October Pruning)**: Done for fruit bearing. Usually performed after monsoon ends.
- **Post-Pruning Care**: Spray 1% Bordeaux mixture immediately after pruning to prevent cut-end infections. Apply heavy irrigation.
''',
    'nutrition_fertilizer': '''
### Nutrition & Fertilizer (ಗೊಬ್ಬರ / खाद)
- **Vegetative Stage**: High Nitrogen (Urea) needed for shoot growth.
- **Flowering Stage**: Avoid excess Nitrogen. Apply Phosphorus (DAP) and Boron for flower setting.
- **Berry Development**: Potassium (Potash) and Calcium are crucial for berry size and skin thickness.
- **Ripening Stage**: NEVER apply heavy Nitrogen, it delays sweetening and Brix development.
''',
    'irrigation': '''
### Irrigation (ನೀರಾವರಿ / सिंचाई)
- **Post-Pruning**: High water requirement.
- **Flowering**: Moderate to low water. Excess water causes flower drop.
- **Berry Growth**: High water requirement for cell expansion.
- **Ripening**: Drastically reduce water to accumulate sugars (Brix).
''',
    'ga3': '''
### GA3 Hormone (ಜಿಎ3 / जीए3)
- **Purpose**: Used for bunch elongation and berry sizing.
- **Usage**: Typically applied at 3-4 mm berry size and 7-8 mm berry size.
- **Precautions**: Over-application can cause berry drop, bunch compactness, or delay ripening.
'''
  };

  /// Dynamic Router: Analyzes the query and extracts ONLY the relevant knowledge chunks.
  /// This heavily optimizes token usage for LLM API costs.
  static String getRelevantContext(String query) {
    final lower = query.toLowerCase();
    final List<String> relevantChunks = [];

    // Keywords mapping to topics
    final Map<String, List<String>> keywordMap = {
      'downy_mildew': ['downy', 'mildew', 'oil', 'spot', 'cotton', 'ಡೌನಿ', 'डाउनी', 'yellow'],
      'powdery_mildew': ['powdery', 'ash', 'powder', 'white', 'ಪುಡಿ', 'ರೋಗ', 'पाउडरी', 'चूर्णी'],
      'flea_beetle': ['flea', 'beetle', 'thrips', 'hole', 'scar', 'ಉಡದ', 'ನುಸಿ', 'फ्ली', 'कीट'],
      'pruning': ['pruning', 'prune', 'cut', 'october', 'april', 'ಕತ್ತರಿಸು', 'छंटाई'],
      'nutrition_fertilizer': ['fertilizer', 'urea', 'dap', 'npk', 'potash', 'nitrogen', 'ಗೊಬ್ಬರ', 'खाद'],
      'irrigation': ['water', 'irrigation', 'ನೀರು', 'ನೀರಾವರಿ', 'सिंचाई', 'पानी'],
      'ga3': ['ga3', 'hormone', 'elongation', 'size', 'ಜಿಎ3', 'ಹಾರ್ಮೋನ್', 'जीए3', 'हार्मोन'],
    };

    // Scan for matches
    for (final entry in keywordMap.entries) {
      final topic = entry.key;
      final keywords = entry.value;
      if (keywords.any((kw) => lower.contains(kw))) {
        if (_knowledgeSections.containsKey(topic)) {
          relevantChunks.add(_knowledgeSections[topic]!);
        }
      }
    }

    // If no specific topic found, provide a very brief general fallback context
    if (relevantChunks.isEmpty) {
      return "General Grape Farming Principles: Maintain open canopy, monitor weather for disease risks, and balance irrigation based on crop stage.";
    }

    return relevantChunks.join("\n");
  }
}
