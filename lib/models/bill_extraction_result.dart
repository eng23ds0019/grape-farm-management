// lib/models/bill_extraction_result.dart
// Typed, confidence-scored output model for the offline Document AI pipeline.
// Every field carries both its extracted value and a 0.0–1.0 confidence score.
// Fields below the LOW_CONFIDENCE_THRESHOLD (0.70) are flagged for manual correction.

const double kLowConfidenceThreshold = 0.70;

/// A single extracted field with value + confidence.
class ExtractedField<T> {
  final T value;
  final double confidence;

  const ExtractedField({required this.value, required this.confidence});

  /// True when the model is uncertain — UI should highlight this field.
  bool get needsReview => confidence < kLowConfidenceThreshold;

  @override
  String toString() => 'ExtractedField(value: $value, confidence: $confidence)';
}

/// A single product row extracted from the items table.
class ExtractedProduct {
  final ExtractedField<String> name;
  final ExtractedField<double> quantity;
  final ExtractedField<String> unit;
  final ExtractedField<double> amount;
  String category;

  ExtractedProduct({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.amount,
    this.category = 'Other',
  });

  bool get needsReview =>
      name.needsReview ||
      quantity.needsReview ||
      amount.needsReview;

  /// Serialize to a plain Map for Firestore storage.
  Map<String, dynamic> toMap() => {
        'itemName': name.value,
        'category': category,
        'quantity': quantity.value,
        'unit': unit.value,
        'amount': amount.value,
        'netAmount': quantity.value > 0 ? (amount.value / quantity.value) : amount.value,
        'hsnCode': '',
      };
}

/// Full extraction result returned by the offline OCR pipeline.
class BillExtractionResult {
  final ExtractedField<String> shopName;
  final ExtractedField<String> gstNumber;
  final ExtractedField<String> customerName;
  final ExtractedField<String> invoiceNumber;
  final ExtractedField<String> invoiceDate;
  final List<ExtractedProduct> products;
  final ExtractedField<double> grandTotal;

  /// How many fields have high confidence (>= threshold).
  final double overallConfidence;

  /// Source of extraction for debug/logging.
  final String extractionSource;

  const BillExtractionResult({
    required this.shopName,
    required this.gstNumber,
    required this.customerName,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.products,
    required this.grandTotal,
    required this.overallConfidence,
    this.extractionSource = 'offline_mlkit',
  });

  /// Returns true if any key fields need manual review.
  bool get hasUncertainFields =>
      shopName.needsReview ||
      customerName.needsReview ||
      invoiceDate.needsReview ||
      grandTotal.needsReview ||
      products.any((p) => p.needsReview);

  /// Builds a clean human-readable summary for the extracted text field.
  String buildSummaryText() {
    final sb = StringBuffer();
    if (shopName.value.isNotEmpty) sb.writeln('Shop: ${shopName.value}');
    if (gstNumber.value.isNotEmpty) sb.writeln('GSTIN: ${gstNumber.value}');
    if (customerName.value.isNotEmpty) sb.writeln('Customer: ${customerName.value}');
    if (invoiceNumber.value.isNotEmpty) sb.writeln('Invoice: ${invoiceNumber.value}');
    sb.writeln('Date: ${invoiceDate.value}');
    sb.writeln('Items:');
    for (final p in products) {
      sb.writeln(
          '  - ${p.name.value}: ${p.quantity.value.toStringAsFixed(0)} ${p.unit.value} = ₹${p.amount.value.toStringAsFixed(0)}');
    }
    sb.write('Grand Total: ₹${grandTotal.value.toStringAsFixed(0)}');
    return sb.toString();
  }

  /// Creates an empty/fallback result for when extraction completely fails.
  factory BillExtractionResult.empty() => BillExtractionResult(
        shopName: const ExtractedField(value: '', confidence: 0.0),
        gstNumber: const ExtractedField(value: '', confidence: 0.0),
        customerName: const ExtractedField(value: '', confidence: 0.0),
        invoiceNumber: const ExtractedField(value: '', confidence: 0.0),
        invoiceDate: ExtractedField(
          value: DateTime.now().toIso8601String().substring(0, 10),
          confidence: 0.5,
        ),
        products: [],
        grandTotal: const ExtractedField(value: 0.0, confidence: 0.0),
        overallConfidence: 0.0,
      );
}
