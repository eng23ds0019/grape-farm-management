import 'package:cloud_firestore/cloud_firestore.dart';

class BillItem {
  const BillItem({
    required this.productName,
    required this.quantity,
    required this.amount,
  });

  final String productName;
  final String quantity;
  final double amount;

  Map<String, dynamic> toMap() => {
    'productName': productName,
    'quantity': quantity,
    'amount': amount,
  };

  factory BillItem.fromMap(Map<String, dynamic> data) {
    return BillItem(
      productName: data['productName'] as String? ?? '',
      quantity: data['quantity'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class BillRecord {
  const BillRecord({
    required this.billId,
    required this.billImageUrl,
    required this.extractedText,
    required this.shopName,
    required this.items,
    required this.totalAmount,
    this.createdAt,
  });

  final String billId;
  final String billImageUrl;
  final String extractedText;
  final String shopName;
  final List<BillItem> items;
  final double totalAmount;
  final DateTime? createdAt;

  Map<String, dynamic> toMap({bool forCreate = false}) {
    return {
      'billImageUrl': billImageUrl,
      'extractedText': extractedText,
      'shopName': shopName,
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      if (forCreate) 'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
