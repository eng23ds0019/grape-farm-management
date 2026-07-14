// lib/core/utils/spatial_layout_parser.dart
//
// Spatial Layout Parser — the core intelligence engine of the offline OCR pipeline.
//
// DESIGN PRINCIPLE:
// Rather than reading `recognizedText.text` as a flat string, this parser uses
// ML Kit's TextBlock bounding boxes to understand WHERE each piece of text appears
// on the document. Fertilizer bills follow a consistent spatial structure:
//
//   ┌──────────────────────────────┐
//   │ HEADER ZONE  (top 25%)       │ → Shop Name, GST Number
//   │ META ZONE    (25%–42%)       │ → Customer Name, Invoice No, Date
//   │ TABLE ZONE   (42%–82%)       │ → Product rows (name, qty, unit, amount)
//   │ FOOTER ZONE  (bottom 18%)    │ → Grand Total
//   └──────────────────────────────┘
//
// Column detection for the products table uses X-coordinate clustering to find
// consistent column anchors (name | qty | unit | amount) without relying solely
// on regex.

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../models/bill_extraction_result.dart';
import 'bill_validator.dart';

class SpatialLayoutParser {
  // ─── Zone boundaries as fractions of image height ──────────────────────────
  static const double _headerEnd = 0.28;
  static const double _metaEnd = 0.44;
  static const double _tableEnd = 0.84;
  // footer = _tableEnd → 1.0

  // ─── Confidence constants ───────────────────────────────────────────────────
  static const double _highConf = 0.92;
  static const double _medConf = 0.75;
  static const double _lowConf = 0.55;

  /// Parse a full bill from ML Kit's [RecognizedText] and the image [imageHeight].
  /// Runs a spatial zone pass, then a label-proximity pass, then validates.
  static BillExtractionResult parse(
    RecognizedText recognizedText,
    int imageHeight,
    int imageWidth,
  ) {
    final double h = imageHeight.toDouble();
    final double w = imageWidth.toDouble();

    // ── 1. Partition blocks into zones ───────────────────────────────────────
    final List<TextBlock> headerBlocks = [];
    final List<TextBlock> metaBlocks = [];
    final List<TextBlock> tableBlocks = [];
    final List<TextBlock> footerBlocks = [];

    for (final block in recognizedText.blocks) {
      final rect = block.boundingBox;
      if (rect == null) continue;
      final double centerY = (rect.top + rect.bottom) / 2.0;
      final double relY = centerY / h;

      if (relY < _headerEnd) {
        headerBlocks.add(block);
      } else if (relY < _metaEnd) {
        metaBlocks.add(block);
      } else if (relY < _tableEnd) {
        tableBlocks.add(block);
      } else {
        footerBlocks.add(block);
      }
    }

    debugPrint(
        'SpatialLayoutParser: header=${headerBlocks.length}, meta=${metaBlocks.length}, '
        'table=${tableBlocks.length}, footer=${footerBlocks.length}');

    // ── 2. Extract fields from each zone ─────────────────────────────────────
    final shopResult = _extractShopName(headerBlocks);
    final gstResult = _extractGstNumber(recognizedText.blocks); // GST can appear anywhere
    final customerResult = _extractCustomerName(metaBlocks, shopResult.value);
    final invoiceResult = _extractInvoiceNumber(metaBlocks);
    final dateResult = _extractDate(metaBlocks, headerBlocks);
    final products = _extractProducts(tableBlocks, w);
    final totalResult = _extractGrandTotal(footerBlocks, tableBlocks, products);

    // ── 3. Compute overall confidence ─────────────────────────────────────────
    final fields = [
      shopResult.confidence,
      customerResult.confidence,
      dateResult.confidence,
      totalResult.confidence,
    ];
    final double overallConf =
        fields.reduce((a, b) => a + b) / fields.length;

    return BillExtractionResult(
      shopName: shopResult,
      gstNumber: gstResult,
      customerName: customerResult,
      invoiceNumber: invoiceResult,
      invoiceDate: dateResult,
      products: products,
      grandTotal: totalResult,
      overallConfidence: overallConf,
      extractionSource: 'offline_mlkit_spatial',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHOP NAME EXTRACTOR
  // Strategy: In the header zone, the shop name is usually the LARGEST or
  // FIRST text block (printed prominently at the top). Prefer blocks with
  // known commerce keywords.
  // ═══════════════════════════════════════════════════════════════════════════
  static ExtractedField<String> _extractShopName(List<TextBlock> header) {
    if (header.isEmpty) {
      return const ExtractedField(value: '', confidence: 0.0);
    }

    const shopKeywords = [
      'agro', 'agency', 'kendra', 'store', 'shop', 'center', 'centre',
      'enterprise', 'traders', 'supplier', 'seeds', 'fertilizer',
      'krishi', 'seva', 'mart', 'market', 'trading', 'sales',
    ];

    // Sort header blocks by Y position (top first)
    final sorted = List<TextBlock>.from(header)
      ..sort((a, b) {
        final ay = a.boundingBox?.top ?? 0;
        final by = b.boundingBox?.top ?? 0;
        return ay.compareTo(by);
      });

    // First pass: blocks with commerce keywords
    for (final block in sorted) {
      final text = block.text.trim();
      final lower = text.toLowerCase();
      if (shopKeywords.any((k) => lower.contains(k)) && text.length > 3) {
        return ExtractedField(value: _cleanName(text), confidence: _highConf);
      }
    }

    // Second pass: topmost non-numeric block of reasonable length
    for (final block in sorted) {
      final text = block.text.trim();
      if (text.length > 4 && !_isAllNumeric(text) && !_looksLikeAddress(text)) {
        return ExtractedField(value: _cleanName(text), confidence: _medConf);
      }
    }

    return const ExtractedField(value: '', confidence: 0.0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GST NUMBER EXTRACTOR — searches all blocks for Indian GST format
  // Format: 2 digits + 5 letters + 4 digits + 1 letter + 1 alnum + Z + alnum
  // Example: 29AAAAA0000A1Z5
  // ═══════════════════════════════════════════════════════════════════════════
  static ExtractedField<String> _extractGstNumber(List<TextBlock> allBlocks) {
    final gstRegex = RegExp(
      r'\b\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}Z[A-Z\d]{1}\b',
      caseSensitive: false,
    );

    for (final block in allBlocks) {
      final match = gstRegex.firstMatch(block.text);
      if (match != null) {
        return ExtractedField(
          value: match.group(0)!.toUpperCase(),
          confidence: _highConf,
        );
      }
    }
    return const ExtractedField(value: '', confidence: 0.3);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CUSTOMER NAME EXTRACTOR
  // Strategy: Look for label-value pairs in the meta zone.
  // Labels: "Customer", "Buyer", "Billed To", "Name", "ಹೆಸರು"
  // The value is text on the same line after the colon, or on the next line.
  // ═══════════════════════════════════════════════════════════════════════════
  static ExtractedField<String> _extractCustomerName(
    List<TextBlock> meta,
    String shopName,
  ) {
    const buyerLabels = [
      'customer', 'buyer', 'billed to', 'bill to', 'sold to',
      'party', 'name', 'ಹೆಸರು', 'नाम', 'ग्राहक',
    ];

    for (final block in meta) {
      for (final line in block.lines) {
        final lower = line.text.toLowerCase();
        if (buyerLabels.any((lbl) => lower.contains(lbl))) {
          // Value after colon on same line
          final afterColon = _valueAfterDelimiter(line.text);
          if (afterColon.isNotEmpty && afterColon != shopName) {
            return ExtractedField(
              value: _cleanName(afterColon),
              confidence: _highConf,
            );
          }
          // Check next line in the same block
          final lineIdx = block.lines.indexOf(line);
          if (lineIdx + 1 < block.lines.length) {
            final nextLine = block.lines[lineIdx + 1].text.trim();
            if (nextLine.isNotEmpty &&
                !_isNumericLine(nextLine) &&
                nextLine != shopName) {
              return ExtractedField(
                value: _cleanName(nextLine),
                confidence: _medConf,
              );
            }
          }
        }
      }
    }

    // Fallback: second prominent text block in meta zone that is not shop name
    final candidates = meta
        .map((b) => b.text.trim())
        .where((t) =>
            t.length > 4 &&
            t != shopName &&
            !_isNumericLine(t) &&
            !_looksLikeAddress(t) &&
            !_containsInvoiceKeyword(t))
        .toList();

    if (candidates.isNotEmpty) {
      return ExtractedField(
        value: _cleanName(candidates.first),
        confidence: _lowConf,
      );
    }

    return const ExtractedField(value: '', confidence: 0.0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INVOICE NUMBER EXTRACTOR
  // Labels: "Invoice No", "Bill No", "Receipt No", "Inv #", "Sl No"
  // ═══════════════════════════════════════════════════════════════════════════
  static ExtractedField<String> _extractInvoiceNumber(List<TextBlock> meta) {
    final invoiceRegex = RegExp(
      r'(?:inv(?:oice)?|bill|receipt|sl|sr|serial|order|ref|no)\s*[.:#]?\s*(\w[\w\-/]{1,14})',
      caseSensitive: false,
    );

    for (final block in meta) {
      final match = invoiceRegex.firstMatch(block.text);
      if (match != null) {
        final val = match.group(1)!.trim();
        // Reject obvious dates and phone numbers
        if (!_looksLikeDate(val) && val.length <= 14) {
          return ExtractedField(value: val, confidence: _highConf);
        }
      }
    }
    return const ExtractedField(value: '', confidence: 0.3);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATE EXTRACTOR
  // Supports: DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD, DD.MM.YYYY
  // Outputs: YYYY-MM-DD
  // ═══════════════════════════════════════════════════════════════════════════
  static ExtractedField<String> _extractDate(
    List<TextBlock> meta,
    List<TextBlock> header,
  ) {
    final datePatterns = [
      // YYYY-MM-DD or YYYY/MM/DD
      RegExp(r'\b(20\d{2})[-/](0?[1-9]|1[0-2])[-/](0?[1-9]|[12]\d|3[01])\b'),
      // DD-MM-YYYY or DD/MM/YYYY or DD.MM.YYYY
      RegExp(r'\b(0?[1-9]|[12]\d|3[01])[-/\.](0?[1-9]|1[0-2])[-/\.](20\d{2})\b'),
    ];

    String? rawDate;
    for (final block in [...meta, ...header]) {
      for (final pattern in datePatterns) {
        final match = pattern.firstMatch(block.text);
        if (match != null) {
          rawDate = match.group(0);
          break;
        }
      }
      if (rawDate != null) break;
    }

    if (rawDate == null) {
      return ExtractedField(
        value: DateTime.now().toIso8601String().substring(0, 10),
        confidence: _lowConf,
      );
    }

    return ExtractedField(
      value: _normalizeDate(rawDate),
      confidence: _highConf,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRODUCTS TABLE EXTRACTOR
  // Strategy: Table rows in Indian fertilizer bills typically have:
  //   - A serial number at the left (1., 2., etc.)
  //   - Product name text
  //   - Quantity + unit
  //   - Amount at the far right
  //
  // We use X-coordinate clustering to find the rightmost column (amount)
  // and left region (product name). Rows with agricultural keywords are
  // also captured even without a serial number.
  // ═══════════════════════════════════════════════════════════════════════════
  static List<ExtractedProduct> _extractProducts(
    List<TextBlock> tableBlocks,
    double imageWidth,
  ) {
    final List<ExtractedProduct> products = [];

    // Gather all lines from table zone, sorted top-to-bottom
    final allLines = <_LineData>[];
    for (final block in tableBlocks) {
      for (final line in block.lines) {
        final rect = line.boundingBox;
        if (rect == null) continue;
        allLines.add(_LineData(
          text: line.text.trim(),
          top: rect.top.toDouble(),
          left: rect.left.toDouble(),
          right: rect.right.toDouble(),
          width: rect.width.toDouble(),
        ));
      }
    }
    allLines.sort((a, b) => a.top.compareTo(b.top));

    final serialRegex = RegExp(r'^\s*\d+\s*[.\-)\s]');
    final agriKeyword = RegExp(
      r'(urea|npk|dap|potash|fertilizer|pesticide|insecticide|fungicide|'
      r'herbicide|phosphate|sulphate|zinc|calcium|magnesium|micronutrient|'
      r'coragen|chlor|seed|mono|compost|organic|bio|humic|boron|mancozeb|'
      r'thiram|captan|metalaxyl|cymoxanil|propiconazole|carbendazim|'
      r'imidacloprid|acetamiprid|fipronil|chlorpyrifos|glyphosate|'
      r'paraquat|2,4-d|ಗೊಬ್ಬರ|ಕ್ರಿಮಿನಾಶಕ|ಯೂರಿಯಾ|उर्वरक|खाद)',
      caseSensitive: false,
    );

    for (final lineData in allLines) {
      final text = lineData.text;
      if (text.length < 3) continue;

      final isSerialRow = serialRegex.hasMatch(text);
      final hasAgri = agriKeyword.hasMatch(text);

      if (!isSerialRow && !hasAgri) continue;

      // Clean out serial number prefix
      final cleaned = text.replaceFirst(serialRegex, '').trim();

      // Extract all numeric tokens from this line
      final numRegex = RegExp(
        r'\b\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\b\d{1,7}(?:\.\d{1,2})?\b',
      );
      final nums = numRegex
          .allMatches(cleaned)
          .map((m) => double.tryParse(m.group(0)!.replaceAll(',', '')) ?? 0.0)
          .where((v) => v > 0)
          .toList();

      if (nums.isEmpty) continue;

      // Amount = last/largest number; quantity = first small number
      double amount = nums.last;
      double quantity = 1.0;
      String unit = 'bag';

      // Try to find explicit quantity+unit pattern
      final unitMatch = RegExp(
        r'(\d+(?:\.\d+)?)\s*(bags?|kg|litre?s?|lt?|bottles?|packets?|boxes?|pkt|nos?|units?)\b',
        caseSensitive: false,
      ).firstMatch(cleaned);

      if (unitMatch != null) {
        quantity = double.tryParse(unitMatch.group(1)!) ?? 1.0;
        unit = unitMatch.group(2)!.toLowerCase().replaceAll(RegExp(r's$'), '');
      } else if (nums.length >= 2) {
        // Fallback: first numeric value is usually quantity
        quantity = nums.first < amount ? nums.first : 1.0;
      }

      // Product name = text before first number
      String productName = cleaned;
      final firstNumIdx = numRegex.firstMatch(cleaned)?.start ?? cleaned.length;
      if (firstNumIdx > 0) {
        productName = cleaned.substring(0, firstNumIdx).trim();
      }
      // Strip trailing punctuation/dashes
      productName = productName
          .replaceAll(RegExp(r'[\s\-–:,\.]+$'), '')
          .trim();

      if (productName.isEmpty || amount < 1.0) continue;

      // Reject lines that are clearly totals/tax rows
      if (_isTotalLine(productName)) continue;

      // Fuzzy-match fertilizer name to known catalogue
      final fuzzyName = BillValidator.fuzzyMatchFertilizer(productName);
      final finalName = fuzzyName ?? productName;
      final nameConf = fuzzyName != null ? _highConf : _medConf;

      products.add(ExtractedProduct(
        name: ExtractedField(value: _cleanProductName(finalName), confidence: nameConf),
        quantity: ExtractedField(value: quantity, confidence: unitMatch != null ? _highConf : _medConf),
        unit: ExtractedField(value: unit, confidence: unitMatch != null ? _highConf : _lowConf),
        amount: ExtractedField(value: amount, confidence: amount > 10 ? _highConf : _medConf),
        category: _classifyProduct(finalName),
      ));
    }

    return products;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GRAND TOTAL EXTRACTOR
  // Searches footer zone first, then table zone for total keywords.
  // Picks the LARGEST valid amount near a "Total" keyword.
  // ═══════════════════════════════════════════════════════════════════════════
  static ExtractedField<double> _extractGrandTotal(
    List<TextBlock> footerBlocks,
    List<TextBlock> tableBlocks,
    List<ExtractedProduct> products,
  ) {
    final totalRegex = RegExp(
      r'(grand\s*total|net\s*(?:total|amount)|total\s*amount|amount\s*payable|'
      r'payable|total\s*due|bill\s*total|g\.?\s*total|ಒಟ್ಟು|कुल)',
      caseSensitive: false,
    );

    final numRegex = RegExp(
      r'(?:₹|Rs\.?|INR)?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\d{1,7}(?:\.\d{1,2})?)\b',
    );

    double? detected;
    double detectedConf = 0.0;

    for (final block in [...footerBlocks, ...tableBlocks]) {
      if (!totalRegex.hasMatch(block.text)) continue;
      final amounts = numRegex
          .allMatches(block.text)
          .map((m) => double.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0.0)
          .where((v) => v >= 10.0)
          .toList();

      if (amounts.isNotEmpty) {
        // Grand total is typically the largest amount near the total keyword
        final candidate = amounts.reduce(max);
        if (detected == null || candidate > detected!) {
          detected = candidate;
          detectedConf = _highConf;
        }
      }
    }

    // Fallback: sum of product amounts
    if (detected == null || detected! < 1.0) {
      final itemSum = products.fold<double>(
        0.0,
        (sum, p) => sum + p.amount.value,
      );
      detected = itemSum;
      detectedConf = itemSum > 0 ? _medConf : 0.0;
    }

    return ExtractedField(value: detected!, confidence: detectedConf);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  static String _valueAfterDelimiter(String text) {
    final idx = text.indexOf(RegExp(r'[:：]'));
    if (idx < 0) return '';
    return text.substring(idx + 1).trim();
  }

  static String _cleanName(String text) => text
      .split('\n')
      .first
      .trim()
      .replaceAll(RegExp(r'\s{2,}'), ' ');

  static String _cleanProductName(String name) => name
      .replaceAll(RegExp(r'[^\w\s\-().%/:,]'), '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();

  static String _normalizeDate(String raw) {
    // Try YYYY-MM-DD / YYYY/MM/DD
    final iso = RegExp(r'(20\d{2})[-/](0?\d|1[0-2])[-/](0?\d|[12]\d|3[01])');
    final dm = iso.firstMatch(raw);
    if (dm != null) {
      return '${dm.group(1)}-${dm.group(2)!.padLeft(2, '0')}-${dm.group(3)!.padLeft(2, '0')}';
    }
    // DD-MM-YYYY
    final parts = raw.split(RegExp(r'[-/.]'));
    if (parts.length == 3 && parts[2].length == 4) {
      return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
    }
    return raw;
  }

  static bool _isAllNumeric(String t) =>
      RegExp(r'^\d[\d\s,.\-+]+$').hasMatch(t.trim());

  static bool _isNumericLine(String t) {
    final nonNum = t.replaceAll(RegExp(r'[\d\s,.\-+₹%]'), '');
    return nonNum.length < 2;
  }

  static bool _looksLikeDate(String t) =>
      RegExp(r'\d{2}[-/]\d{2}[-/]\d{2,4}').hasMatch(t);

  static bool _looksLikeAddress(String t) {
    final lower = t.toLowerCase();
    return lower.contains('road') ||
        lower.contains('street') ||
        lower.contains('nagar') ||
        lower.contains('dist') ||
        lower.contains('taluk') ||
        lower.contains('pin') ||
        lower.contains('ph:') ||
        lower.contains('mob:');
  }

  static bool _containsInvoiceKeyword(String t) {
    final lower = t.toLowerCase();
    return lower.contains('invoice') ||
        lower.contains('bill') ||
        lower.contains('gst') ||
        lower.contains('total') ||
        lower.contains('date');
  }

  static bool _isTotalLine(String name) {
    final lower = name.toLowerCase();
    return lower.contains('total') ||
        lower.contains('subtotal') ||
        lower.contains('tax') ||
        lower.contains('gst') ||
        lower.contains('cgst') ||
        lower.contains('sgst') ||
        lower.contains('discount') ||
        lower.contains('round') ||
        lower.contains('payable');
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
    if (lower.contains('seed')) return 'Other';
    return 'Other';
  }
}

/// Internal helper to carry line spatial metadata.
class _LineData {
  final String text;
  final double top;
  final double left;
  final double right;
  final double width;

  const _LineData({
    required this.text,
    required this.top,
    required this.left,
    required this.right,
    required this.width,
  });
}
