import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../models/bill_record.dart';

class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<ExtractedBill> extractBill(XFile file) async {
    final input = InputImage.fromFile(File(file.path));
    final result = await _recognizer.processImage(input);
    final text = result.text;
    return _parseImportantBillFields(text);
  }

  ExtractedBill _parseImportantBillFields(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final shopName = lines.isEmpty ? 'Unknown shop' : lines.first;
    final amountRegex = RegExp(r'(\d+[,.]?\d*)\s*$');
    final quantityRegex = RegExp(
      r'(\d+\s?(kg|ltr|litre|ml|gm|pcs|bags?)?)',
      caseSensitive: false,
    );
    final items = <BillItem>[];

    for (final line in lines.skip(1)) {
      final amountMatch = amountRegex.firstMatch(line);
      if (amountMatch == null) continue;
      final amount =
          double.tryParse(amountMatch.group(1)!.replaceAll(',', '')) ?? 0;
      if (amount <= 0) continue;
      final productPart = line.substring(0, amountMatch.start).trim();
      if (productPart.length < 3) continue;
      final quantity = quantityRegex.firstMatch(productPart)?.group(1) ?? '';
      items.add(
        BillItem(
          productName: productPart.replaceAll(quantity, '').trim(),
          quantity: quantity,
          amount: amount,
        ),
      );
    }

    final totalLine = lines.lastWhere(
      (line) => line.toLowerCase().contains('total'),
      orElse: () => '',
    );
    final totalMatch = amountRegex.firstMatch(totalLine);
    final total = totalMatch == null
        ? items.fold<double>(0, (sum, item) => sum + item.amount)
        : double.tryParse(totalMatch.group(1)!.replaceAll(',', '')) ?? 0;

    return ExtractedBill(
      extractedText: text,
      shopName: shopName,
      items: items,
      totalAmount: total,
    );
  }

  void dispose() => _recognizer.close();
}

class ExtractedBill {
  const ExtractedBill({
    required this.extractedText,
    required this.shopName,
    required this.items,
    required this.totalAmount,
  });

  final String extractedText;
  final String shopName;
  final List<BillItem> items;
  final double totalAmount;
}
