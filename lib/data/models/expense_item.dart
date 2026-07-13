import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseItem {
  const ExpenseItem({
    required this.category,
    required this.itemName,
    required this.quantity,
    required this.amount,
    required this.date,
  });

  final String category;
  final String itemName;
  final String quantity;
  final double amount;
  final DateTime date;

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'itemName': itemName,
      'quantity': quantity,
      'amount': amount,
      'date': Timestamp.fromDate(date),
    };
  }

  factory ExpenseItem.fromMap(Map<String, dynamic> data) {
    return ExpenseItem(
      category: data['category'] as String? ?? '',
      itemName: data['itemName'] as String? ?? '',
      quantity: data['quantity'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
