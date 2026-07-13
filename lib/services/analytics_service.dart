import '../models/diary_entry_model.dart';
import '../models/expense_model.dart';
import '../core/constants/constants.dart';
import 'package:intl/intl.dart';

class AnalyticsSummary {
  final double todayTotal;
  final double monthTotal;
  final double yearTotal;
  final String highestCategory;
  final double highestCategoryAmount;
  final double totalPesticide;
  final double totalFertilizer;
  final double totalLabour;
  final Map<String, double> categoryTotals;
  final Map<String, double> monthlyTrends; // YYYY-MM -> Amount
  final Map<String, double> farmComparison; // FarmName -> Amount
  final List<Map<String, dynamic>> topSpendingItems;
  final String insightText;

  AnalyticsSummary({
    required this.todayTotal,
    required this.monthTotal,
    required this.yearTotal,
    required this.highestCategory,
    required this.highestCategoryAmount,
    required this.totalPesticide,
    required this.totalFertilizer,
    required this.totalLabour,
    required this.categoryTotals,
    required this.monthlyTrends,
    required this.farmComparison,
    required this.topSpendingItems,
    required this.insightText,
  });
}

class AnalyticsService {
  /// Compiles all calculations dynamically based on active diary entries.
  static AnalyticsSummary generateSummary(List<DiaryEntryModel> entries, String currentFarmId, String languageCode) {
    double today = 0.0;
    double month = 0.0;
    double year = 0.0;
    double pesticide = 0.0;
    double fertilizer = 0.0;
    double labour = 0.0;

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final thisMonthStr = DateFormat('yyyy-MM').format(now);
    final thisYearStr = DateFormat('yyyy').format(now);

    Map<String, double> catTotals = {};
    for (var cat in AppConstants.expenseCategories) {
      catTotals[cat] = 0.0;
    }

    Map<String, double> trend = {};
    Map<String, double> farmComp = {};
    List<ExpenseModel> allExpenses = [];

    // Parse entries
    for (var entry in entries) {
      // Collect expenses
      for (var exp in entry.expenses) {
        allExpenses.add(exp);

        double amt = exp.totalAmount;
        String cat = exp.category;

        // Categories
        catTotals[cat] = (catTotals[cat] ?? 0.0) + amt;

        if (cat == "Pesticide") pesticide += amt;
        if (cat == "Fertilizer") fertilizer += amt;
        if (cat == "Labour") labour += amt;

        // Date breakdowns
        if (exp.date == todayStr) {
          today += amt;
        }
        if (exp.date.startsWith(thisMonthStr)) {
          month += amt;
        }
        if (exp.date.startsWith(thisYearStr)) {
          year += amt;
        }

        // Monthly Trend
        if (exp.date.length >= 7) {
          String ym = exp.date.substring(0, 7); // YYYY-MM
          trend[ym] = (trend[ym] ?? 0.0) + amt;
        }

        // Farm Comparison
        String farmName = entry.farmId == "plot_1" ? "Basveshwar Plot 1" : "Plot ${entry.farmId}";
        farmComp[farmName] = (farmComp[farmName] ?? 0.0) + amt;
      }
    }

    // Determine highest category
    String highestCat = "None";
    double highestCatAmt = 0.0;
    catTotals.forEach((key, value) {
      if (value > highestCatAmt) {
        highestCatAmt = value;
        highestCat = key;
      }
    });

    // Top individual spending items
    allExpenses.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    List<Map<String, dynamic>> topItems = allExpenses
        .take(5)
        .map((e) => {
              'itemName': e.itemName.isNotEmpty ? e.itemName : e.category,
              'category': e.category,
              'amount': e.totalAmount,
            })
        .toList();

    // Compile dynamic Insights in selected language
    String insight = "";
    if (languageCode == 'kn-IN') {
      if (month > 0) {
        insight = "ಈ ತಿಂಗಳ ಒಟ್ಟು ಖರ್ಚು ₹${month.toStringAsFixed(0)}. ಇದರಲ್ಲಿ ಅತ್ಯಧಿಕ ವೆಚ್ಚ $highestCat ಆಗಿದೆ (₹${highestCatAmt.toStringAsFixed(0)}). "
            "ಗೊಬ್ಬರಕ್ಕೆ ₹${fertilizer.toStringAsFixed(0)} ಮತ್ತು ಔಷಧಿಗಳಿಗೆ ₹${pesticide.toStringAsFixed(0)} ಖರ್ಚಾಗಿದೆ. "
            "ಕೂಲಿ ವೆಚ್ಚವು ₹${labour.toStringAsFixed(0)} ಆಗಿದೆ.";
      } else {
        insight = "ಈ ತಿಂಗಳು ಇನ್ನೂ ಯಾವುದೇ ಖರ್ಚು ದಾಖಲಾಗಿಲ್ಲ. ಆರಂಭಿಸಲು 'ಖರ್ಚು ಸೇರಿಸಿ' ಬಟನ್ ಬಳಸಿ.";
      }
    } else if (languageCode == 'hi-IN') {
      if (month > 0) {
        insight = "इस महीने का कुल खर्च ₹${month.toStringAsFixed(0)} है। इसमें सबसे अधिक खर्च $highestCat श्रेणी में हुआ है (₹${highestCatAmt.toStringAsFixed(0)})। "
            "उर्वरक (Fertilizer) पर ₹${fertilizer.toStringAsFixed(0)} और कीटनाशक (Pesticide) पर ₹${pesticide.toStringAsFixed(0)} खर्च हुए। "
            "मजदूरी पर खर्च ₹${labour.toStringAsFixed(0)} रहा।";
      } else {
        insight = "इस महीने में अभी तक कोई खर्च दर्ज नहीं किया गया है। शुरू करने के लिए 'खर्च जोड़ें' पर टैप करें।";
      }
    } else {
      if (month > 0) {
        insight = "This month your highest expense is $highestCat (₹${highestCatAmt.toStringAsFixed(0)}). "
            "Pesticide expense is ₹${pesticide.toStringAsFixed(0)} and fertilizer is ₹${fertilizer.toStringAsFixed(0)}. "
            "Your total farm spending this month is ₹${month.toStringAsFixed(0)}.";
      } else {
        insight = "No farm expenses logged this month yet. Use the 'Add Expense' module to begin tracking.";
      }
    }

    // Default historical trend points for layout testing if empty
    if (trend.isEmpty) {
      trend[thisMonthStr] = month;
    }

    return AnalyticsSummary(
      todayTotal: today,
      monthTotal: month,
      yearTotal: year,
      highestCategory: highestCat,
      highestCategoryAmount: highestCatAmt,
      totalPesticide: pesticide,
      totalFertilizer: fertilizer,
      totalLabour: labour,
      categoryTotals: catTotals,
      monthlyTrends: trend,
      farmComparison: farmComp,
      topSpendingItems: topItems,
      insightText: insight,
    );
  }
}
