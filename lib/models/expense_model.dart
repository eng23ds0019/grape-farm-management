class ExpenseModel {
  final String category;
  final String itemName;
  final double quantity;
  final String unit;
  final double totalAmount;
  final String note;
  final String date; // YYYY-MM-DD
  final String linkedDiaryEntryId;

  ExpenseModel({
    required this.category,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.totalAmount,
    this.note = "",
    required this.date,
    this.linkedDiaryEntryId = "",
  });

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'itemName': itemName,
      'quantity': quantity,
      'unit': unit,
      'totalAmount': totalAmount,
      'note': note,
      'date': date,
      'linkedDiaryEntryId': linkedDiaryEntryId,
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      category: map['category'] ?? 'Other',
      itemName: map['itemName'] ?? '',
      quantity: (map['quantity'] ?? 0.0) is int ? (map['quantity'] as int).toDouble() : (map['quantity'] ?? 0.0),
      unit: map['unit'] ?? 'other',
      totalAmount: (map['totalAmount'] ?? 0.0) is int ? (map['totalAmount'] as int).toDouble() : (map['totalAmount'] ?? 0.0),
      note: map['note'] ?? '',
      date: map['date'] ?? '',
      linkedDiaryEntryId: map['linkedDiaryEntryId'] ?? '',
    );
  }
}
