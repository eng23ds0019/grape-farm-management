class ReportModel {
  final String reportId;
  final int month;
  final int year;
  final double totalExpense;
  final Map<String, double> categoryBreakdown;
  final DateTime generatedAt;

  ReportModel({
    required this.reportId,
    required this.month,
    required this.year,
    required this.totalExpense,
    required this.categoryBreakdown,
    required this.generatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'reportId': reportId,
      'month': month,
      'year': year,
      'totalExpense': totalExpense,
      'categoryBreakdown': categoryBreakdown,
      'generatedAt': generatedAt.toIso8601String(),
    };
  }

  factory ReportModel.fromMap(Map<String, dynamic> map, String id) {
    Map<String, double> parsedBreakdown = {};
    if (map['categoryBreakdown'] != null) {
      Map<String, dynamic>.from(map['categoryBreakdown']).forEach((key, value) {
        parsedBreakdown[key] = value is int ? value.toDouble() : (value ?? 0.0);
      });
    }

    return ReportModel(
      reportId: id,
      month: map['month'] ?? 0,
      year: map['year'] ?? 0,
      totalExpense: (map['totalExpense'] ?? 0.0) is int
          ? (map['totalExpense'] as int).toDouble()
          : (map['totalExpense'] ?? 0.0),
      categoryBreakdown: parsedBreakdown,
      generatedAt: DateTime.parse(map['generatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
