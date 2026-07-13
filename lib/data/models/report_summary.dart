class ReportSummary {
  final String reportId;
  final String farmerId;
  final String farmId;
  final String period; // e.g. '2024-05'
  final double totalExpense;
  final int diaryCount;
  final int billCount;
  final DateTime generatedAt;

  const ReportSummary({
    required this.reportId,
    required this.farmerId,
    required this.farmId,
    required this.period,
    required this.totalExpense,
    required this.diaryCount,
    required this.billCount,
    required this.generatedAt,
  });

  Map<String, dynamic> toMap() => {
        'reportId': reportId,
        'farmerId': farmerId,
        'farmId': farmId,
        'period': period,
        'totalExpense': totalExpense,
        'diaryCount': diaryCount,
        'billCount': billCount,
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory ReportSummary.fromMap(Map<String, dynamic> map) => ReportSummary(
        reportId: map['reportId'] as String? ?? '',
        farmerId: map['farmerId'] as String? ?? '',
        farmId: map['farmId'] as String? ?? '',
        period: map['period'] as String? ?? '',
        totalExpense: (map['totalExpense'] as num?)?.toDouble() ?? 0.0,
        diaryCount: map['diaryCount'] as int? ?? 0,
        billCount: map['billCount'] as int? ?? 0,
        generatedAt: map['generatedAt'] != null
            ? DateTime.parse(map['generatedAt'] as String)
            : DateTime.now(),
      );
}
