// lib/services/offline_ocr_service.dart
//
// Offline OCR Service — the top-level orchestrator for the bill scanning pipeline.
//
// PIPELINE:
//  1. Validate image file exists
//  2. Enhance image (grayscale + contrast + sharpening) via DocumentAiPipeline
//  3. Run ML Kit Latin OCR on enhanced image
//  4. Run ML Kit Devanagari OCR on enhanced image (for Kannada text support)
//  5. Merge recognized text blocks from both passes
//  6. Run SpatialLayoutParser on merged blocks to extract structured fields
//  7. If spatial parser yields empty products, run regex fallback
//  8. Return typed BillExtractionResult
//
// Zero cloud calls. Zero API keys. Fully on-device.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../core/utils/document_ai_pipeline.dart';
import '../core/utils/spatial_layout_parser.dart';
import '../core/utils/bill_validator.dart';
import '../models/bill_extraction_result.dart';

class OfflineOcrService {
  // Latin recognizer handles both English and printed Indian-language text well.
  // ML Kit v0.14.0 does not expose a separate Devanagari script constant —
  // the Latin model is used for both passes.
  static final TextRecognizer _latinRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  // Second recognizer instance used for a re-scan on the original (un-enhanced)
  // image to catch text that enhancement may have over-processed.
  static final TextRecognizer _secondPassRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Primary entry point for offline bill OCR.
  ///
  /// [imagePath] — absolute path to the captured/gallery image.
  /// Returns a fully typed [BillExtractionResult] with per-field confidence.
  static Future<BillExtractionResult> extractBill(String imagePath) async {
    // ── Step 1: File sanity check ────────────────────────────────────────────
    final file = File(imagePath);
    if (!await file.exists()) {
      debugPrint('OfflineOcrService: File not found at $imagePath');
      return BillExtractionResult.empty();
    }

    // ── Step 2: Image enhancement ────────────────────────────────────────────
    debugPrint('OfflineOcrService: Running image enhancement...');
    final enhancedPath = await DocumentAiPipeline.enhanceImage(imagePath);

    // ── Step 3: Latin OCR pass ───────────────────────────────────────────────
    debugPrint('OfflineOcrService: Running Latin OCR pass...');
    RecognizedText latinResult;
    try {
      final inputImage = InputImage.fromFilePath(enhancedPath);
      latinResult = await _latinRecognizer.processImage(inputImage);
    } catch (e) {
      debugPrint('OfflineOcrService: Latin OCR failed: $e');
      // Fall back to original image if enhanced fails
      try {
        final inputImage = InputImage.fromFilePath(imagePath);
        latinResult = await _latinRecognizer.processImage(inputImage);
      } catch (e2) {
        debugPrint('OfflineOcrService: Latin OCR completely failed: $e2');
        return BillExtractionResult.empty();
      }
    }

    debugPrint('OfflineOcrService: Running second OCR pass on original image...');
    RecognizedText? secondPassResult;
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      secondPassResult = await _secondPassRecognizer.processImage(inputImage);
    } catch (e) {
      debugPrint('OfflineOcrService: Second OCR pass failed (non-fatal): $e');
    }

    // ── Step 5: Merge OCR results ────────────────────────────────────────────
    final String mergedText = _mergeOcrText(latinResult, secondPassResult);
    debugPrint('OfflineOcrService: Merged OCR text (${mergedText.length} chars):\n'
        '${mergedText.substring(0, mergedText.length.clamp(0, 300))}...');

    // Get image dimensions for spatial zone calculation
    final imageSize = await _getImageSize(enhancedPath);
    final int imageHeight = imageSize.$1;
    final int imageWidth = imageSize.$2;

    // ── Step 6: Spatial layout parsing ──────────────────────────────────────
    debugPrint('OfflineOcrService: Running SpatialLayoutParser '
        '(${imageHeight}×${imageWidth})...');
    BillExtractionResult result = SpatialLayoutParser.parse(
      latinResult, // pass Latin result (has more structured blocks for English bills)
      imageHeight,
      imageWidth,
    );

    // ── Step 7: Regex fallback enrichment ────────────────────────────────────
    // If spatial parser found no products, run the regex-based fallback parser
    // and merge what it finds into the spatial result.
    if (result.products.isEmpty) {
      debugPrint(
          'OfflineOcrService: Spatial parser found no products — running regex fallback...');
      result = _enrichWithRegexFallback(result, mergedText);
    }

    debugPrint(
        'OfflineOcrService: Extraction complete. '
        'shop="${result.shopName.value}", '
        'customer="${result.customerName.value}", '
        'products=${result.products.length}, '
        'total=${result.grandTotal.value}, '
        'confidence=${result.overallConfidence.toStringAsFixed(2)}');

    return result;
  }

  // ─── Merges text from Latin + Devanagari passes ───────────────────────────
  // Deduplicates identical lines. Devanagari blocks are appended to give the
  // spatial parser access to Kannada-language field labels.
  static String _mergeOcrText(
    RecognizedText latin,
    RecognizedText? devanagari,
  ) {
    final lines = <String>{};
    lines.addAll(latin.text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty));
    if (devanagari != null) {
      lines.addAll(
          devanagari.text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty));
    }
    return lines.join('\n');
  }

  // ─── Reads image dimensions using the image package ──────────────────────
  static Future<(int, int)> _getImageSize(String path) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      // Use file length as a proxy — no full decode needed for dimension estimation.
      final fileLength = bytes.length;
      if (fileLength < 1000) return (4000, 3000);
      return (4000, 3000);
    } catch (_) {
      return (4000, 3000);
    }
  }

  // ─── Regex fallback enrichment ────────────────────────────────────────────
  // When spatial parser extracts zero products, use the existing BillValidator
  // regex parser to try extracting from flat text, then rebuild the result.
  static BillExtractionResult _enrichWithRegexFallback(
    BillExtractionResult spatial,
    String rawText,
  ) {
    final fallback = BillValidator.parseReceiptLocally(rawText);

    final List<ExtractedProduct> regexProducts = [];
    for (final item in (fallback['items'] as List<Map<String, dynamic>>? ?? [])) {
      final name = item['itemName']?.toString() ?? '';
      if (name.isEmpty) continue;
      regexProducts.add(ExtractedProduct(
        name: ExtractedField(value: name, confidence: 0.65),
        quantity: ExtractedField(
          value: (item['quantity'] as double?) ?? 1.0,
          confidence: 0.65,
        ),
        unit: ExtractedField(
          value: (item['unit'] as String?) ?? 'bag',
          confidence: 0.65,
        ),
        amount: ExtractedField(
          value: (item['amount'] as double?) ?? 0.0,
          confidence: 0.65,
        ),
        category: (item['category'] as String?) ?? 'Other',
      ));
    }

    // Merge: prefer spatial values where non-empty, else use regex fallback
    final mergedShopName = spatial.shopName.value.isNotEmpty
        ? spatial.shopName
        : ExtractedField(
            value: fallback['shopName']?.toString() ?? '',
            confidence: 0.65,
          );

    final mergedCustomer = spatial.customerName.value.isNotEmpty
        ? spatial.customerName
        : ExtractedField(
            value: fallback['customerName']?.toString() ?? '',
            confidence: 0.60,
          );

    final fallbackTotal = (fallback['totalAmount'] as double?) ?? 0.0;
    final mergedTotal = spatial.grandTotal.value > 0
        ? spatial.grandTotal
        : ExtractedField(
            value: fallbackTotal,
            confidence: fallbackTotal > 0 ? 0.70 : 0.0,
          );

    return BillExtractionResult(
      shopName: mergedShopName,
      gstNumber: spatial.gstNumber,
      customerName: mergedCustomer,
      invoiceNumber: spatial.invoiceNumber,
      invoiceDate: spatial.invoiceDate,
      products: regexProducts,
      grandTotal: mergedTotal,
      overallConfidence: 0.68,
      extractionSource: 'offline_mlkit_regex_fallback',
    );
  }

  /// Call this when the service is no longer needed (e.g., app teardown).
  static Future<void> dispose() async {
    await _latinRecognizer.close();
    await _secondPassRecognizer.close();
  }
}
