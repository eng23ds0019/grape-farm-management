class BillItem {
  final String itemName;
  final String category;
  final double quantity;
  final String unit;
  final double amount;

  BillItem({
    required this.itemName,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemName': itemName,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'amount': amount,
    };
  }

  // To Firebase structured format: {"name": ..., "amount": ...}
  Map<String, dynamic> toFirebaseMap() {
    return {
      'name': itemName,
      'amount': amount,
    };
  }

  factory BillItem.fromMap(Map<String, dynamic> map) {
    // Support both 'itemName' (from local/previous cache) and 'name' (from Firebase)
    final name = map['itemName'] ?? map['name'] ?? '';
    return BillItem(
      itemName: name,
      category: map['category'] ?? 'Other',
      quantity: (map['quantity'] ?? 0.0) is int ? (map['quantity'] as int).toDouble() : (map['quantity'] ?? 0.0),
      unit: map['unit'] ?? 'other',
      amount: (map['amount'] ?? 0.0) is int ? (map['amount'] as int).toDouble() : (map['amount'] ?? 0.0),
    );
  }
}

class BillModel {
  final String billId;
  final String billDate; // YYYY-MM-DD
  final String shopName;
  final String customerName; // Added
  final String invoiceNumber; // Added
  final String billImageUrl;
  final String extractedText;
  final List<BillItem> items;
  final double totalAmount;
  final String status; // "pending" | "confirmed"
  final DateTime createdAt;
  final DateTime updatedAt;

  BillModel({
    required this.billId,
    required this.billDate,
    required this.shopName,
    this.customerName = "Unknown Customer",
    this.invoiceNumber = "",
    required this.billImageUrl,
    this.extractedText = "",
    required this.items,
    required this.totalAmount,
    this.status = "pending",
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'billId': billId,
      'billDate': billDate,
      'shopName': shopName,
      'customerName': customerName,
      'invoiceNumber': invoiceNumber,
      'billImageUrl': billImageUrl,
      'extractedText': extractedText,
      'items': items.map((i) => i.toMap()).toList(),
      'totalAmount': totalAmount,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// STEP 7 — FIREBASE DATABASE STRUCTURE
  /// Returns structured data only. Matches expected keys.
  Map<String, dynamic> toFirebaseMap() {
    return {
      'shop_name': shopName,
      'customer_name': customerName,
      'invoice_number': invoiceNumber,
      'date': billDate,
      'items': items.map((i) => i.toFirebaseMap()).toList(),
      'total_amount': totalAmount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory BillModel.fromMap(Map<String, dynamic> map, String id) {
    var rawItems = map['items'] as List? ?? [];
    List<BillItem> parsedItems = rawItems
        .map((i) => BillItem.fromMap(Map<String, dynamic>.from(i)))
        .toList();

    // Map both snake_case and camelCase to support structured Firebase responses
    final date = map['billDate'] ?? map['date'] ?? '';
    final sName = map['shopName'] ?? map['shop_name'] ?? '';
    final cName = map['customerName'] ?? map['customer_name'] ?? 'Unknown Customer';
    final invNum = map['invoiceNumber'] ?? map['invoice_number'] ?? '';
    final total = map['totalAmount'] ?? map['total_amount'] ?? 0.0;

    return BillModel(
      billId: id,
      billDate: date,
      shopName: sName,
      customerName: cName,
      invoiceNumber: invNum,
      billImageUrl: map['billImageUrl'] ?? '',
      extractedText: map['extractedText'] ?? '',
      items: parsedItems,
      totalAmount: total is int ? total.toDouble() : (total as num).toDouble(),
      status: map['status'] ?? 'pending',
      createdAt: DateTime.parse(map['createdAt'] ?? map['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updatedAt'] ?? map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  BillModel copyWith({
    String? billDate,
    String? shopName,
    String? customerName,
    String? invoiceNumber,
    String? billImageUrl,
    String? extractedText,
    List<BillItem>? items,
    double? totalAmount,
    String? status,
    DateTime? updatedAt,
  }) {
    return BillModel(
      billId: billId,
      billDate: billDate ?? this.billDate,
      shopName: shopName ?? this.shopName,
      customerName: customerName ?? this.customerName,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      billImageUrl: billImageUrl ?? this.billImageUrl,
      extractedText: extractedText ?? this.extractedText,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
