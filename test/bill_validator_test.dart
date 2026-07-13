import 'package:flutter_test/flutter_test.dart';
import 'package:draksha_farm_diary/core/utils/bill_validator.dart';

void main() {
  group('BillValidator Tests', () {
    test('cleanOcrText removes phone, GST, invoice numbers, and noise', () {
      const rawOcr = """
      SHREE FERTILIZERS
      GSTIN: 29AAAAA0000A1Z5
      Invoice No: INV-2026-9874
      Mobile: +91 9876543210
      Urea Fertilizer - 1200
      DAP Fertilizer - 1500
      Total: 2700
      -------------------------
      Thank you for shopping!
      """;

      final cleaned = BillValidator.cleanOcrText(rawOcr);
      
      expect(cleaned.contains("29AAAAA0000A1Z5"), isFalse);
      expect(cleaned.contains("INV-2026-9874"), isFalse);
      expect(cleaned.contains("9876543210"), isFalse);
      expect(cleaned.contains("Thank you"), isTrue);
      expect(cleaned.contains("Urea Fertilizer"), isTrue);
    });

    test('fuzzyMatchFertilizer matches official keywords', () {
      expect(BillValidator.fuzzyMatchFertilizer("urea 46%"), "urea");
      expect(BillValidator.fuzzyMatchFertilizer("d.a.p."), "dap");
      expect(BillValidator.fuzzyMatchFertilizer("potash active"), "potash");
      expect(BillValidator.fuzzyMatchFertilizer("npk 19-19-19"), "npk");
      expect(BillValidator.fuzzyMatchFertilizer("zinc sulphate 21%"), "zinc sulphate");
      expect(BillValidator.fuzzyMatchFertilizer("calcium nitrate crystals"), "calcium nitrate");
      expect(BillValidator.fuzzyMatchFertilizer("random ocr noise word"), isNull);
    });

    test('isValidAmount validates correct currency and numeric formats', () {
      expect(BillValidator.isValidAmount("1500"), isTrue);
      expect(BillValidator.isValidAmount("₹1,200.50"), isTrue);
      expect(BillValidator.isValidAmount("Rs. 500"), isTrue);
      expect(BillValidator.isValidAmount("9876543210"), isFalse); // Too large, looks like phone
      expect(BillValidator.isValidAmount("2"), isFalse); // Too small
    });

    test('detectTotalAmount detects totals near keywords', () {
      const receiptText = """
      Urea: 1200
      DAP: 1500
      Grand Total: ₹2700.00
      """;
      expect(BillValidator.detectTotalAmount(receiptText), 2700.00);
    });
  });
}
