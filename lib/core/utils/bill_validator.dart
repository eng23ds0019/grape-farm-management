import 'dart:math';

class BillValidator {
  // Known fertilizer keywords
  static const List<String> knownFertilizers = [
    'urea',
    'dap',
    'potash',
    'npk',
    'zinc sulphate',
    'micronutrient',
    'magnesium sulphate',
    'calcium nitrate',
  ];

  /// STEP 2 — CLEAN OCR TEXT
  /// Before parsing, removes phone numbers, GST numbers, invoice numbers,
  /// long numeric strings, serial IDs, unrelated text, and OCR noise.
  static String cleanOcrText(String rawText) {
    final List<String> lines = rawText.split('\n');
    final List<String> cleanedLines = [];

    // 1. Phone number pattern (matches typical Indian phone numbers: +91 xxxxx xxxxx, 10 digits, etc.)
    final phoneRegex = RegExp(r'(?:\+?91[\-\s]?)?[6-9]\d{9}|(?:\+?91[\-\s]?)?\d{5}[\-\s]?\d{5}|\b\d{10}\b');

    // 2. GST number pattern (15 alphanumeric characters: e.g. 29AAAAA0000A1Z5)
    final gstRegex = RegExp(r'\b\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}[Z]{1}[A-Z\d]{1}\b', caseSensitive: false);

    // 3. Invoice identifiers (e.g. Invoice: #1234, Inv: 982743, Bill No, Receipt No, GSTIN, License No)
    final invoiceLabelRegex = RegExp(
      r'(invoice\s*(?:no|number)?|inv\s*(?:no|number)?|bill\s*(?:no)?|receipt\s*(?:no)?|gstin|lic\s*(?:no)?|dl\s*no|tfa\s*no|batch\s*(?:no)?|sl\s*no|serial\s*no|phone|tel|mobile|contact|gst|cst|tin|email|address|bank|a\/c|ifsc|challan|terms|conditions|vehicle)',
      caseSensitive: false
    );

    // 4. Long numeric strings (typically serial IDs, barcodes, account numbers, e.g. 11+ digits)
    final longNumericRegex = RegExp(r'\b\d{11,}\b');

    // 5. General OCR noise (isolated special characters, line separators, e.g. "----", "=====", ".....")
    final noiseRegex = RegExp(r'^[\s\-\.\#\*\:\,\+\=\/\&\@\(\)\[\]\?\\_\|]+$');

    for (var line in lines) {
      String trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Skip lines that match general OCR noise or lines that only consist of repetitive chars
      if (noiseRegex.hasMatch(trimmed)) continue;

      // Skip lines starting with or containing specific invoice metadata labels
      if (invoiceLabelRegex.hasMatch(trimmed)) continue;

      // Remove phone numbers if present
      trimmed = trimmed.replaceAll(phoneRegex, '').trim();

      // Remove GST numbers if present
      trimmed = trimmed.replaceAll(gstRegex, '').trim();

      // Remove long numeric strings
      trimmed = trimmed.replaceAll(longNumericRegex, '').trim();

      // Check if after cleaning it still contains meaningful alphanumeric characters
      if (trimmed.isNotEmpty && trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').isNotEmpty) {
        cleanedLines.add(trimmed);
      }
    }

    return cleanedLines.join('\n');
  }

  /// Levenshtein Distance implementation for fuzzy matching.
  static double getLevenshteinDistanceScore(String s1, String s2) {
    s1 = s1.toLowerCase().trim();
    s2 = s2.toLowerCase().trim();

    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final List<int> prev = List<int>.generate(s2.length + 1, (i) => i);
    final List<int> curr = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      curr[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        curr[j + 1] = min(
          curr[j] + 1, // Insertion
          min(
            prev[j + 1] + 1, // Deletion
            prev[j] + cost // Substitution
          )
        );
      }
      for (int k = 0; k < prev.length; k++) {
        prev[k] = curr[k];
      }
    }

    int maxLen = max(s1.length, s2.length);
    return 1.0 - (curr[s2.length] / maxLen);
  }

  /// STEP 4 — FERTILIZER VALIDATION SYSTEM
  /// Uses fuzzy matching. Returns standard fertilizer name if matched, else null.
  /// Prevents random OCR words from becoming fertilizer names.
  static String? fuzzyMatchFertilizer(String name) {
    final lowerName = name.toLowerCase().trim().replaceAll('.', '');

    // 1. Check for direct substring matches first (high confidence)
    for (var kf in knownFertilizers) {
      if (lowerName == kf) return kf;
      // If it contains the exact keyword as a separate word, e.g. "urea 46%" -> "urea"
      final words = lowerName.split(RegExp(r'\s+'));
      if (words.contains(kf)) return kf;
      
      // Or multi-word keyword contains or is contained in lowerName
      if (kf.contains(' ')) {
        if (lowerName.contains(kf)) return kf;
      }
    }

    // 2. Perform Levenshtein Distance fuzzy matching
    String? bestMatch;
    double bestScore = 0.0;

    for (var kf in knownFertilizers) {
      double score = getLevenshteinDistanceScore(lowerName, kf);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = kf;
      }

      // Also compare word-by-word to capture strings like "Fertilizer Urea Bag"
      final words = lowerName.split(RegExp(r'[\s\-]+'));
      for (var word in words) {
        if (word.length > 2) {
          double wordScore = getLevenshteinDistanceScore(word, kf);
          if (wordScore > bestScore) {
            bestScore = wordScore;
            bestMatch = kf;
          }
        }
      }
    }

    // 0.65 threshold to prevent random OCR words from matching
    if (bestScore >= 0.65) {
      return bestMatch;
    }

    return null;
  }

  /// STEP 5 — AMOUNT VALIDATION
  /// Checks if a number looks like a valid purchase amount:
  /// - Reject phone numbers, GST numbers, invoice IDs.
  /// - Optionally contain ₹ symbol.
  /// - Check money/decimal formats.
  static bool isValidAmount(String amountStr) {
    // Clean string by removing whitespace, ₹, and currency text
    final clean = amountStr.replaceAll(RegExp(r'[\s₹₹Rs\.inr]'), '').trim();
    if (clean.isEmpty) return false;

    // Check if it matches a valid number format (e.g. 1500, 1500.00, 1,500.00)
    final moneyFormat = RegExp(r'^\d{1,7}(?:\.\d{1,2})?$');
    if (!moneyFormat.hasMatch(clean.replaceAll(',', ''))) return false;

    final val = double.tryParse(clean.replaceAll(',', '')) ?? 0.0;
    
    // A single item/total spending amount is rarely less than 10 or greater than 1,000,000 in this context
    if (val < 10 || val > 1000000) return false;

    return true;
  }

  /// STEP 6 — TOTAL DETECTION
  /// Detects totals only near keywords: Total, Grand Total, Net Amount, Amount Payable.
  /// Extract only the valid nearby amount.
  static double? detectTotalAmount(String rawText) {
    final lines = rawText.split('\n');
    final totalKeywords = RegExp(
      r'(total|grand\s*total|net\s*amount|amount\s*payable|gtotal|g\.total|payable\s*amount|total\s*due)',
      caseSensitive: false
    );

    double? detectedTotal;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (totalKeywords.hasMatch(line)) {
        // Look for numbers on the same line first
        final numbersInLine = _extractAmountsFromText(line);
        if (numbersInLine.isNotEmpty) {
          // Typically the last or largest number on the total line is the total
          detectedTotal = numbersInLine.last;
          break;
        }

        // Check the next 2 lines if no number is on the same line
        for (int offset = 1; offset <= 2 && (i + offset) < lines.length; offset++) {
          final nextLine = lines[i + offset].trim();
          final numbersInNextLine = _extractAmountsFromText(nextLine);
          if (numbersInNextLine.isNotEmpty) {
            detectedTotal = numbersInNextLine.first;
            break;
          }
        }
        if (detectedTotal != null) break;
      }
    }

    return detectedTotal;
  }

  static List<double> _extractAmountsFromText(String text) {
    final numRegex = RegExp(r'(?:₹|Rs\.?|INR)?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\d{1,7}(?:\.\d{1,2})?)\b');
    final matches = numRegex.allMatches(text);
    final List<double> results = [];
    for (var m in matches) {
      final valStr = m.group(1);
      if (valStr != null) {
        final clean = valStr.replaceAll(',', '');
        final val = double.tryParse(clean);
        if (val != null && val >= 10.0) {
          results.add(val);
        }
      }
    }
    return results;
  }

  /// 100% Offline Local Fallback Receipt Parser that works without any API keys.
  static Map<String, dynamic> parseReceiptLocally(String rawText) {
    String shopName = "";
    String customerName = "";
    String billDate = DateTime.now().toIso8601String().substring(0, 10);
    double totalAmount = 0.0;
    List<Map<String, dynamic>> items = [];

    final lines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    // 1. Detect Date
    final dateRegex = RegExp(r'\b(\d{4}[-/]\d{2}[-/]\d{2}|\d{2}[-/]\d{2}[-/]\d{4})\b');
    for (var line in lines) {
      final match = dateRegex.firstMatch(line);
      if (match != null) {
        String dt = match.group(1)!;
        if (dt.contains('/')) dt = dt.replaceAll('/', '-');
        if (dt.split('-')[0].length == 2) {
          final parts = dt.split('-');
          billDate = "${parts[2]}-${parts[1]}-${parts[0]}";
        } else {
          billDate = dt;
        }
        break;
      }
    }

    // 2. Detect Total Amount
    final total = detectTotalAmount(rawText);
    if (total != null) {
      totalAmount = total;
    }

    // 3. Detect Shop Name and Customer Name
    for (int i = 0; i < min(5, lines.length); i++) {
      final line = lines[i];
      final lower = line.toLowerCase();
      if (lower.contains("agro") ||
          lower.contains("agency") ||
          lower.contains("kendra") ||
          lower.contains("store") ||
          lower.contains("shop") ||
          lower.contains("center") ||
          lower.contains("rama") ||
          lower.contains("enterprise")) {
        shopName = line;
        break;
      }
    }
    if (shopName.isEmpty && lines.isNotEmpty) {
      for (var line in lines) {
        if (!line.contains(RegExp(r'\d')) && line.length > 5) {
          shopName = line;
          break;
        }
      }
    }

    for (var line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains("customer") ||
          lower.contains("buyer") ||
          lower.contains("billed to") ||
          lower.contains("bill to") ||
          lower.contains("name")) {
        customerName = line.replaceAll(RegExp(r'(customer|buyer|billed to|bill to|name|[\:\-])', caseSensitive: false), '').trim();
        break;
      }
    }
    if (customerName.isEmpty) {
      for (int i = 1; i < min(4, lines.length); i++) {
        final line = lines[i];
        if (line != shopName && !line.contains(RegExp(r'(date|total|inv|bill|phone)', caseSensitive: false)) && line.length > 5) {
          customerName = line;
          break;
        }
      }
    }

    // 4. Parse Items from table rows
    final serialRegex = RegExp(r'^\s*(\d+)\s*[\.\-]?\s+');
    final npkRegex = RegExp(r'\b\d+[\-:\u2013\u2212]\d+[\-:\u2013\u2212]\d+\b');
    final pctRegex = RegExp(r'\(\s*\d+\s*%\s*[A-Za-z]*\s*\)');

    for (var line in lines) {
      final trimmed = line.trim();
      final startsWithSerial = serialRegex.hasMatch(trimmed);
      final hasAgriKeyword = trimmed.toLowerCase().contains(RegExp(r'(urea|npk|dap|potash|fertilizer|agro|pesticide|gobbara|saf|mono|phosphate|sulphate|chlorpyriphos|coragen|chlorantraniliprole)'));

      if (startsWithSerial || hasAgriKeyword) {
        final originalLineWithoutSerial = trimmed.replaceFirst(serialRegex, '');

        String cleanLine = originalLineWithoutSerial;
        cleanLine = cleanLine.replaceAll(npkRegex, '');
        cleanLine = cleanLine.replaceAll(pctRegex, '');

        final numRegex = RegExp(r'\b\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\b\d{1,7}(?:\.\d{1,2})?\b');
        final matches = numRegex.allMatches(cleanLine).toList();

        if (matches.length >= 2) {
          final amountStr = matches.last.group(0)!.replaceAll(',', '');
          final rateStr = matches[matches.length - 2].group(0)!.replaceAll(',', '');
          final qtyStr = matches.first.group(0)!;

          final double itemAmount = double.tryParse(amountStr) ?? 0.0;
          final double itemRate = double.tryParse(rateStr) ?? 0.0;

          final qtyReg = RegExp('\\b' + qtyStr + '\\b');
          final qtyMatch = qtyReg.firstMatch(originalLineWithoutSerial);

          String itemName = "";
          if (qtyMatch != null) {
            itemName = originalLineWithoutSerial.substring(0, qtyMatch.start).trim();
          } else {
            itemName = cleanLine.substring(0, cleanLine.indexOf(qtyStr)).trim();
          }

          itemName = itemName.replaceAll(RegExp(r'[\s\-\u2013\u2212\:]+$'), '').trim();

          if (itemName.isEmpty && hasAgriKeyword) {
            final nameMatch = RegExp(r'^[A-Za-z\s\d\-\(\)%]+', caseSensitive: false).firstMatch(originalLineWithoutSerial);
            if (nameMatch != null) {
              itemName = nameMatch.group(0)!.trim();
              itemName = itemName.replaceAll(RegExp('\\b' + qtyStr + r'\b.*$'), '').trim();
            }
          }

          double quantity = 1.0;
          String unit = "qty";

          final unitMatch = RegExp(r'(\d+)\s*(bags|bag|kg|litre|bottle|box|qty|packet|day|trip|worker)\b', caseSensitive: false).firstMatch(originalLineWithoutSerial);
          if (unitMatch != null) {
            quantity = double.tryParse(unitMatch.group(1)!) ?? 1.0;
            unit = unitMatch.group(2)!.toLowerCase();
          } else {
            if (itemRate > 0) {
              quantity = itemAmount / itemRate;
            }
          }

          if (itemName.isNotEmpty && itemAmount > 0) {
            items.add({
              'itemName': itemName,
              'category': fuzzyMatchFertilizer(itemName) != null ? 'Fertilizer' : 'Other',
              'quantity': quantity,
              'unit': unit,
              'amount': itemAmount,
              'hsnCode': '',
              'netAmount': itemRate,
            });
          }
        }
      }
    }

    return {
      'shopName': shopName,
      'customerName': customerName,
      'billDate': billDate,
      'totalAmount': totalAmount == 0.0 ? items.fold(0.0, (sum, i) => sum + (i['amount'] as double)) : totalAmount,
      'items': items,
    };
  }
}
