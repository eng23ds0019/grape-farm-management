// lib/core/utils/spatial_layout_parser.dart
//
// Overhauled Spatial Layout Parser — Production-Grade Document AI Parser
//
// Designed specifically for structured Indian fertilizer & pesticide invoices.
//
// ALGORITHM:
// 1. Line Clustered Reconstruction:
//    - Groups individual TextLines from ML Kit into horizontal `SpatialLine` groups
//      if they overlap vertically (tolerance of 50% line height).
//    - Sorts all TextLines within a `SpatialLine` from left to right (by X coordinate).
//    - This reconstructs the printed page exactly as read left-to-right, eliminating
//      failures where ML Kit scans columns out of order.
// 2. Field Classification:
//    - Shop Name & GSTIN: Extracted from topmost lines (Header).
//    - Customer Name: Extracted by matching labels (`Customer`, `Buyer`, `Name`, `Recipient`)
//      and fetching the remainder of the line, or the line immediately below it.
//      Avoids `/Recipient` bug by correctly stripping the match prefix.
//    - Invoice No & Date: Matches nearby label associations.
// 3. Table Column Parser:
//    - Scan lines. If they contain agricultural terms (urea, dap, potash, pesticide, crop names)
//      AND have numbers, they are parsed as product rows.
//    - Splitting columns horizontally: leftmost is Product Name, rightmost is Row Amount,
//      middle fields represent Quantity, Unit, and Unit Price.
// 4. Totals Parser:
//    - Extracts pre-tax taxable amount (Subtotal), GST taxes, and final Grand Total
//      by searching for corresponding labels.

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../models/bill_extraction_result.dart';
import 'bill_validator.dart';

class SpatialLine {
  double top;
  double bottom;
  final List<TextLine> lines;

  SpatialLine({
    required this.top,
    required this.bottom,
    required this.lines,
  });

  double get centerY => (top + bottom) / 2.0;
  double get height => bottom - top;

  void addTextLine(TextLine tl) {
    final rect = tl.boundingBox;
    if (rect == null) return;
    lines.add(tl);
    top = min(top, rect.top.toDouble());
    bottom = max(bottom, rect.bottom.toDouble());
    // Sort horizontally: left-to-right
    lines.sort((a, b) => (a.boundingBox?.left ?? 0).compareTo(b.boundingBox?.left ?? 0));
  }

  String get text => lines.map((l) => l.text).join(' ');
}

class SpatialLayoutParser {
  // Confidence levels
  static const double _highConf = 0.95;
  static const double _medConf = 0.78;
  static const double _lowConf = 0.45;

  /// Parse ML Kit's [RecognizedText] into structured [BillExtractionResult].
  static BillExtractionResult parse(
    RecognizedText recognizedText,
    int imageHeight,
    int imageWidth,
  ) {
    debugPrint("SpatialLayoutParser: Beginning layout-aware invoice parse...");

    // Step 1: Reconstruct the document lines horizontally
    final spatialLines = _reconstructHorizontalLines(recognizedText);
    debugPrint("SpatialLayoutParser: Reconstructed ${spatialLines.length} horizontal lines.");

    // Step 2: Extract Merchant Shop details
    final shopResult = _extractShopName(spatialLines);
    final gstResult = _extractGstNumber(spatialLines);

    // Step 3: Extract Buyer/Customer details
    final customerResult = _extractCustomerName(spatialLines, shopResult.value);

    // Step 4: Extract Invoice metadata
    final invoiceResult = _extractInvoiceNumber(spatialLines);
    final dateResult = _extractDate(spatialLines);

    // Step 5: Extract Products table columns
    final products = _extractProducts(spatialLines);

    // Step 6: Extract Totals (Taxable Subtotal, GST, Grand Total)
    final totals = _extractTotals(spatialLines, products);

    // Calculate average confidence across primary fields
    final confidenceScores = [
      shopResult.confidence,
      customerResult.confidence,
      invoiceResult.confidence,
      dateResult.confidence,
      totals.$3.confidence, // Grand Total
    ];
    final double overallConf =
        confidenceScores.reduce((a, b) => a + b) / confidenceScores.length;

    return BillExtractionResult(
      shopName: shopResult,
      gstNumber: gstResult,
      customerName: customerResult,
      invoiceNumber: invoiceResult,
      invoiceDate: dateResult,
      products: products,
      grandTotal: totals.$3, // Grand Total
      overallConfidence: overallConf,
      extractionSource: 'offline_mlkit_spatial_v2',
    );
  }

  // ─── Line Reconstruction Algorithm ─────────────────────────────────────────
  static List<SpatialLine> _reconstructHorizontalLines(RecognizedText recognizedText) {
    final List<SpatialLine> spatialLines = [];

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final rect = line.boundingBox;
        if (rect == null || line.text.trim().isEmpty) continue;

        final double lineTop = rect.top.toDouble();
        final double lineBottom = rect.bottom.toDouble();
        final double lineCenterY = (lineTop + lineBottom) / 2.0;
        final double lineHeight = lineBottom - lineTop;

        bool merged = false;
        for (final sl in spatialLines) {
          // Check vertical overlap ratio
          final double overlapTop = max(sl.top, lineTop);
          final double overlapBottom = min(sl.bottom, lineBottom);
          final double overlap = overlapBottom - overlapTop;
          final double minHeight = min(sl.height, lineHeight);

          // If lines overlap by more than 45% of the smaller line height,
          // or their centers are within each other's boundaries, merge them.
          if (overlap > minHeight * 0.45 || 
              (lineCenterY >= sl.top && lineCenterY <= sl.bottom) ||
              (sl.centerY >= lineTop && sl.centerY <= lineBottom)) {
            sl.addTextLine(line);
            merged = true;
            break;
          }
        }

        if (!merged) {
          spatialLines.add(SpatialLine(
            top: lineTop,
            bottom: lineBottom,
            lines: [line],
          ));
        }
      }
    }

    // Sort lines top-to-bottom
    spatialLines.sort((a, b) => a.top.compareTo(b.top));
    return spatialLines;
  }

  // ─── Field Extraction: Merchant details ────────────────────────────────────
  static ExtractedField<String> _extractShopName(List<SpatialLine> lines) {
    if (lines.isEmpty) {
      return const ExtractedField(value: '', confidence: 0.0);
    }

    const shopKeywords = [
      'agro', 'agency', 'kendra', 'store', 'shop', 'center', 'centre',
      'enterprise', 'traders', 'supplier', 'seeds', 'fertilizer',
      'krishi', 'seva', 'mart', 'market', 'trading', 'sales', 'fertilizers'
    ];

    // Shop name is printed at the top. Check the first 8 lines.
    final topLines = lines.take(min(8, lines.length)).toList();

    // Pass 1: Line containing business keywords
    for (final sl in topLines) {
      final text = sl.text.trim();
      final lower = text.toLowerCase();
      if (shopKeywords.any((keyword) => lower.contains(keyword)) && 
          text.length > 4 && 
          !_isNumericLine(text) &&
          !lower.contains("gst") &&
          !lower.contains("phone")) {
        return ExtractedField(value: _cleanText(text), confidence: _highConf);
      }
    }

    // Pass 2: Fallback to the first non-numeric line that doesn't look like meta info
    for (final sl in topLines) {
      final text = sl.text.trim();
      final lower = text.toLowerCase();
      if (text.length > 5 && 
          !_isNumericLine(text) && 
          !_looksLikeAddressOrContact(text) &&
          !lower.contains("invoice") &&
          !lower.contains("bill") &&
          !lower.contains("gst")) {
        return ExtractedField(value: _cleanText(text), confidence: _medConf);
      }
    }

    return const ExtractedField(value: 'General Agro Store', confidence: 0.20);
  }

  static ExtractedField<String> _extractGstNumber(List<SpatialLine> lines) {
    final gstRegex = RegExp(
      r'\b\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}Z[A-Z\d]{1}\b',
      caseSensitive: false,
    );

    for (final sl in lines) {
      final match = gstRegex.firstMatch(sl.text);
      if (match != null) {
        return ExtractedField(
          value: match.group(0)!.toUpperCase(),
          confidence: _highConf,
        );
      }
    }
    return const ExtractedField(value: '', confidence: 0.3);
  }

  // ─── Field Extraction: Buyer details ───────────────────────────────────────
  static ExtractedField<String> _extractCustomerName(List<SpatialLine> lines, String shopName) {
    const buyerLabels = [
      'customer name', 'buyer name', 'recipient name',
      'customer', 'buyer', 'billed to', 'bill to', 'sold to',
      'party name', 'party', 'name', 'ಹೆಸರು', 'नाम', 'ग्राहक'
    ];

    for (int i = 0; i < lines.length; i++) {
      final sl = lines[i];
      final text = sl.text;
      final lower = text.toLowerCase();

      for (final label in buyerLabels) {
        final idx = lower.indexOf(label);
        if (idx != -1) {
          // Extract remainder of the line after the matched label
          String val = text.substring(idx + label.length).trim();
          val = val.replaceFirst(RegExp(r'^[\s/:\-–=]+'), '').trim();

          // Reject if it contains shop name, or looks like label metadata
          if (val.isNotEmpty && 
              val != shopName && 
              val.toLowerCase() != "/recipient" &&
              !_isNumericLine(val) &&
              val.length > 2) {
            return ExtractedField(value: _cleanText(val), confidence: _highConf);
          }

          // Check the line immediately below if same line is empty or just label garbage
          if (i + 1 < lines.length) {
            final nextText = lines[i + 1].text.trim();
            if (nextText.isNotEmpty && 
                nextText != shopName && 
                !_isNumericLine(nextText) && 
                !_looksLikeAddressOrContact(nextText) &&
                !nextText.toLowerCase().contains("invoice") &&
                nextText.length > 2) {
              return ExtractedField(value: _cleanText(nextText), confidence: _medConf);
            }
          }
        }
      }
    }

    return const ExtractedField(value: 'Unknown Customer', confidence: 0.20);
  }

  // ─── Field Extraction: Invoice metadata ────────────────────────────────────
  static ExtractedField<String> _extractInvoiceNumber(List<SpatialLine> lines) {
    final invoiceLabels = [
      'invoice no', 'inv no', 'bill no', 'receipt no', 'invoice number',
      'bill number', 'invoice#', 'bill#', 'inv#', 'sl no', 'sl.no',
      'invoice', 'inv', 'bill'
    ];

    for (final sl in lines) {
      final text = sl.text;
      final lower = text.toLowerCase();

      for (final label in invoiceLabels) {
        final idx = lower.indexOf(label);
        if (idx != -1) {
          String val = text.substring(idx + label.length).trim();
          val = val.replaceFirst(RegExp(r'^[\s/:\-–=]+'), '').trim();

          // Split by whitespace and take the first token (invoice id)
          if (val.isNotEmpty) {
            final tokens = val.split(RegExp(r'\s+'));
            final invToken = tokens.first.trim();
            // Validate it doesn't look like a date or a phone number
            if (!_looksLikeDate(invToken) && invToken.length <= 16 && invToken.length > 1) {
              return ExtractedField(value: invToken, confidence: _highConf);
            }
          }
        }
      }
    }

    return const ExtractedField(value: '', confidence: 0.3);
  }

  static ExtractedField<String> _extractDate(List<SpatialLine> lines) {
    final datePatterns = [
      // YYYY-MM-DD or YYYY/MM/DD
      RegExp(r'\b(20\d{2})[-/](0?[1-9]|1[0-2])[-/](0?[1-9]|[12]\d|3[01])\b'),
      // DD-MM-YYYY or DD/MM/YYYY or DD.MM.YYYY
      RegExp(r'\b(0?[1-9]|[12]\d|3[01])[-/\.](0?[1-9]|1[0-2])[-/\.](20\d{2})\b'),
    ];

    for (final sl in lines) {
      final text = sl.text;
      for (final pattern in datePatterns) {
        final match = pattern.firstMatch(text);
        if (match != null) {
          final rawDate = match.group(0)!;
          return ExtractedField(value: _normalizeDate(rawDate), confidence: _highConf);
        }
      }
    }

    // Default to today
    return ExtractedField(
      value: DateTime.now().toIso8601String().substring(0, 10),
      confidence: 0.50,
    );
  }

  // ─── Field Extraction: Table Products ──────────────────────────────────────
  static List<ExtractedProduct> _extractProducts(List<SpatialLine> lines) {
    final List<ExtractedProduct> products = [];

    final agriKeywords = RegExp(
      r'(urea|npk|dap|potash|fertilizer|pesticide|insecticide|fungicide|'
      r'herbicide|phosphate|sulphate|zinc|calcium|magnesium|micronutrient|'
      r'coragen|chlor|seed|mono|compost|organic|bio|humic|boron|mancozeb|'
      r'thiram|captan|metalaxyl|cymoxanil|propiconazole|carbendazim|'
      r'imidacloprid|acetamiprid|fipronil|chlorpyrifos|glyphosate|'
      r'paraquat|2,4-d|ಗೊಬ್ಬರ|ಕ್ರಿಮಿನಾಶಕ|ಯೂರಿಯಾ|उर्वरक|खाद)',
      caseSensitive: false,
    );

    final totalKeywords = RegExp(
      r'(total|subtotal|taxable|cgst|sgst|igst|gst|tax|discount|round|payable)',
      caseSensitive: false,
    );

    for (final sl in lines) {
      final text = sl.text;
      final lower = text.toLowerCase();

      // Skip lines carrying totals keywords
      if (totalKeywords.hasMatch(lower)) continue;

      final hasAgri = agriKeywords.hasMatch(lower);
      if (!hasAgri) continue;

      // Extract all numeric elements from the line
      final numRegex = RegExp(
        r'\b\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\b\d{1,7}(?:\.\d{1,2})?\b',
      );
      final numMatches = numRegex.allMatches(text).toList();
      if (numMatches.isEmpty) continue;

      final List<double> values = numMatches
          .map((m) => double.tryParse(m.group(0)!.replaceAll(',', '')) ?? 0.0)
          .where((v) => v > 0)
          .toList();

      if (values.isEmpty) continue;

      // Layout Column Mapping:
      // - Rightmost number is typically row Amount.
      // - Second rightmost is Unit Price / Rate.
      // - Leftmost is Quantity.
      double amount = values.last;
      double quantity = 1.0;
      String unit = 'bag';

      // Look for explicit quantity + unit format: "10 bags", "5 kg", "2 ltr"
      final unitMatch = RegExp(
        r'(\d+(?:\.\d+)?)\s*(bags?|kg|litre?s?|lt?|bottles?|packets?|boxes?|pkt|nos?|units?)\b',
        caseSensitive: false,
      ).firstMatch(text);

      if (unitMatch != null) {
        quantity = double.tryParse(unitMatch.group(1)!) ?? 1.0;
        unit = unitMatch.group(2)!.toLowerCase().replaceAll(RegExp(r's$'), '');
      } else if (values.length >= 2) {
        quantity = values.first < amount ? values.first : 1.0;
      }

      // Reconstruct product name: everything to the left of the first number,
      // discarding leading serial numbers (e.g. "1.", "2 -").
      String prodName = text;
      final serialMatch = RegExp(r'^\s*\d+\s*[.\-)\s]+').firstMatch(prodName);
      if (serialMatch != null) {
        prodName = prodName.substring(serialMatch.end).trim();
      }

      final firstNumMatch = numRegex.firstMatch(prodName);
      if (firstNumMatch != null) {
        prodName = prodName.substring(0, firstNumMatch.start).trim();
      }
      prodName = prodName.replaceAll(RegExp(r'[\s\-–:,\.]+$'), '').trim();

      if (prodName.length > 2 && amount > 1.0) {
        final matchedName = BillValidator.fuzzyMatchFertilizer(prodName) ?? prodName;
        final nameConfidence = BillValidator.fuzzyMatchFertilizer(prodName) != null ? _highConf : _medConf;

        products.add(ExtractedProduct(
          name: ExtractedField(value: _cleanProductName(matchedName), confidence: nameConfidence),
          quantity: ExtractedField(value: quantity, confidence: unitMatch != null ? _highConf : _medConf),
          unit: ExtractedField(value: unit, confidence: unitMatch != null ? _highConf : _lowConf),
          amount: ExtractedField(value: amount, confidence: _highConf),
          category: _classifyProduct(matchedName),
        ));
      }
    }

    return products;
  }

  // ─── Field Extraction: Totals ──────────────────────────────────────────────
  // Returns: (Taxable Subtotal, GST, Grand Total)
  static (ExtractedField<double>, ExtractedField<double>, ExtractedField<double>) _extractTotals(
    List<SpatialLine> lines,
    List<ExtractedProduct> products,
  ) {
    double? taxable;
    double? gst;
    double? grandTotal;

    final numRegex = RegExp(
      r'(?:₹|Rs\.?|INR)?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\d{1,7}(?:\.\d{1,2})?)\b',
    );

    for (final sl in lines) {
      final text = sl.text;
      final lower = text.toLowerCase();

      final amounts = numRegex
          .allMatches(text)
          .map((m) => double.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0.0)
          .where((v) => v > 0)
          .toList();

      if (amounts.isEmpty) continue;

      // Taxable Subtotal
      if (lower.contains("subtotal") || 
          lower.contains("taxable value") || 
          lower.contains("taxable amount") ||
          lower.contains("amount before tax")) {
        taxable = amounts.last;
      }

      // GST Tax amount
      if (lower.contains("cgst") || 
          lower.contains("sgst") || 
          lower.contains("igst") || 
          lower.contains("gst tax") ||
          lower.contains("tax amount")) {
        // Accumulate GST tax lines
        gst = (gst ?? 0.0) + amounts.last;
      }

      // Grand Total
      if (lower.contains("grand total") || 
          lower.contains("net amount") || 
          lower.contains("amount payable") ||
          lower.contains("g.total") ||
          lower.contains("total due") ||
          (lower.contains("total") && !lower.contains("subtotal") && !lower.contains("taxable") && !lower.contains("gst"))) {
        grandTotal = amounts.last;
      }
    }

    // Fallbacks if not found
    final double itemSum = products.fold<double>(0.0, (sum, p) => sum + p.amount.value);
    taxable ??= itemSum;
    gst ??= 0.0;
    grandTotal ??= taxable + gst;

    // Cross-validate totals
    if (grandTotal == 0.0 && itemSum > 0.0) {
      grandTotal = itemSum;
    }

    return (
      ExtractedField(value: taxable, confidence: taxable > 0 ? _highConf : _lowConf),
      ExtractedField(value: gst, confidence: gst >= 0 ? _highConf : _lowConf),
      ExtractedField(value: grandTotal, confidence: grandTotal > 0 ? _highConf : _lowConf),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  static String _cleanText(String val) {
    return val
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  static String _cleanProductName(String val) {
    return val
        .replaceAll(RegExp(r'[^\w\s\-().%/:,]'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  static bool _isNumericLine(String text) {
    final nonNum = text.replaceAll(RegExp(r'[\d\s,.\-+₹%]'), '');
    return nonNum.length < 2;
  }

  static bool _looksLikeAddressOrContact(String text) {
    final lower = text.toLowerCase();
    return lower.contains("road") ||
        lower.contains("street") ||
        lower.contains("nagar") ||
        lower.contains("dist") ||
        lower.contains("taluk") ||
        lower.contains("pin") ||
        lower.contains("ph:") ||
        lower.contains("mob:") ||
        lower.contains("phone");
  }

  static bool _looksLikeDate(String text) {
    return RegExp(r'\d{2}[-/]\d{2}[-/]\d{2,4}').hasMatch(text);
  }

  static String _normalizeDate(String raw) {
    // Try YYYY-MM-DD / YYYY/MM/DD
    final iso = RegExp(r'(20\d{2})[-/](0?\d|1[0-2])[-/](0?\d|[12]\d|3[01])');
    final dm = iso.firstMatch(raw);
    if (dm != null) {
      return '${dm.group(1)}-${dm.group(2)!.padLeft(2, '0')}-${dm.group(3)!.padLeft(2, '0')}';
    }
    // DD-MM-YYYY or DD.MM.YYYY
    final parts = raw.split(RegExp(r'[-/.]'));
    if (parts.length == 3 && parts[2].length == 4) {
      return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
    }
    return raw;
  }

  static String _classifyProduct(String name) {
    final lower = name.toLowerCase();
    if (RegExp(r'(urea|npk|dap|potash|phosphate|sulphate|zinc|calcium|magnesium|'
            r'micronutrient|compost|organic|humic|boron|fertilizer|ಗೊಬ್ಬರ|ಯೂರಿಯಾ|उर्वरक|खाद)')
        .hasMatch(lower)) return 'Fertilizer';
    if (RegExp(r'(pesticide|insecticide|fungicide|herbicide|coragen|chlor|'
            r'mancozeb|thiram|captan|metalaxyl|cymoxanil|propiconazole|'
            r'carbendazim|imidacloprid|acetamiprid|fipronil|chlorpyrifos|'
            r'glyphosate|paraquat|ಕ್ರಿಮಿನಾಶಕ)')
        .hasMatch(lower)) return 'Pesticide';
    return 'Other';
  }
}
