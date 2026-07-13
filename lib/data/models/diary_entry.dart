import 'package:cloud_firestore/cloud_firestore.dart';

import 'expense_item.dart';

class DiaryEntry {
  const DiaryEntry({
    required this.entryId,
    required this.date,
    required this.cropStage,
    required this.workType,
    required this.originalText,
    required this.cleanedText,
    required this.languageCode,
    required this.photos,
    required this.expenses,
    required this.structuredData,
    required this.totalExpense,
    required this.aiReady,
    required this.farmerConfirmed,
    this.voiceUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String entryId;
  final DateTime date;
  final String cropStage;
  final String workType;
  final String originalText;
  final String cleanedText;
  final String languageCode;
  final String? voiceUrl;
  final List<String> photos;
  final List<ExpenseItem> expenses;
  final Map<String, dynamic> structuredData;
  final double totalExpense;
  final bool aiReady;
  final bool farmerConfirmed;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap({bool forCreate = false}) {
    return {
      'date': Timestamp.fromDate(date),
      'cropStage': cropStage,
      'workType': workType,
      'originalText': originalText,
      'cleanedText': cleanedText,
      'languageCode': languageCode,
      'voiceUrl': voiceUrl,
      'photos': photos,
      'expenses': expenses.map((expense) => expense.toMap()).toList(),
      'structuredData': structuredData,
      'totalExpense': totalExpense,
      'aiReady': aiReady,
      'farmerConfirmed': farmerConfirmed,
      'updatedAt': FieldValue.serverTimestamp(),
      if (forCreate) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory DiaryEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final expensesData = data['expenses'] as List<dynamic>? ?? [];
    return DiaryEntry(
      entryId: doc.id,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      cropStage: data['cropStage'] as String? ?? '',
      workType: data['workType'] as String? ?? '',
      originalText: data['originalText'] as String? ?? '',
      cleanedText: data['cleanedText'] as String? ?? '',
      languageCode: data['languageCode'] as String? ?? 'en',
      voiceUrl: data['voiceUrl'] as String?,
      photos: List<String>.from(data['photos'] as List<dynamic>? ?? const []),
      expenses: expensesData
          .whereType<Map<String, dynamic>>()
          .map(ExpenseItem.fromMap)
          .toList(),
      structuredData: Map<String, dynamic>.from(
        data['structuredData'] as Map<String, dynamic>? ?? const {},
      ),
      totalExpense: (data['totalExpense'] as num?)?.toDouble() ?? 0,
      aiReady: data['aiReady'] as bool? ?? false,
      farmerConfirmed: data['farmerConfirmed'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
