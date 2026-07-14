import 'package:flutter/material.dart';
import '../models/diary_entry_model.dart';
import '../models/expense_model.dart';
import '../models/farm_model.dart';
import '../models/bill_model.dart';
import '../models/turnover_model.dart';
import 'package:intl/intl.dart';

class AnalyticsSummary {
  // Backward compatibility fields
  final double todayTotal;
  final double monthTotal;
  final double yearTotal;
  final double totalPesticide;
  final double totalFertilizer;
  final double totalLabour;
  final Map<String, double> monthlyTrends;
  final Map<String, double> farmComparison;
  final List<Map<String, dynamic>> topSpendingItems;

  // Simplified BI fields
  final double totalExpenses;
  final double totalIncome;
  final double estimatedProfit;

  // Simple Chart structures
  final Map<String, double> categoryTotals; // Fertilizer, Labour, Pesticides, Irrigation, Transport, Others
  final Map<String, double> yearlyExpenses;
  final Map<String, double> yearlyIncomes;
  final Map<String, double> yearlyProfits;

  final List<String> simpleInsights;
  final String insightText;

  AnalyticsSummary({
    required this.todayTotal,
    required this.monthTotal,
    required this.yearTotal,
    required this.totalPesticide,
    required this.totalFertilizer,
    required this.totalLabour,
    required this.monthlyTrends,
    required this.farmComparison,
    required this.topSpendingItems,
    required this.totalExpenses,
    required this.totalIncome,
    required this.estimatedProfit,
    required this.categoryTotals,
    required this.yearlyExpenses,
    required this.yearlyIncomes,
    required this.yearlyProfits,
    required this.simpleInsights,
    required this.insightText,
  });
}

class AnalyticsService {
  /// Original positional signature kept for 100% backward-compatibility
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

    Map<String, double> catTotals = {
      "Fertilizer": 0.0,
      "Labour": 0.0,
      "Pesticides": 0.0,
      "Irrigation": 0.0,
      "Transport": 0.0,
      "Others": 0.0
    };

    Map<String, double> trend = {};
    Map<String, double> farmComp = {};

    for (var entry in entries) {
      if (entry.isDeleted) continue;
      for (var exp in entry.expenses) {
        double amt = exp.totalAmount;
        String cat = exp.category;

        if (cat == "Pesticide" || cat == "Pesticides") {
          pesticide += amt;
          catTotals["Pesticides"] = (catTotals["Pesticides"] ?? 0.0) + amt;
        } else if (cat == "Fertilizer") {
          fertilizer += amt;
          catTotals["Fertilizer"] = (catTotals["Fertilizer"] ?? 0.0) + amt;
        } else if (cat == "Labour") {
          labour += amt;
          catTotals["Labour"] = (catTotals["Labour"] ?? 0.0) + amt;
        } else if (cat == "Irrigation") {
          catTotals["Irrigation"] = (catTotals["Irrigation"] ?? 0.0) + amt;
        } else if (cat == "Transport") {
          catTotals["Transport"] = (catTotals["Transport"] ?? 0.0) + amt;
        } else {
          catTotals["Others"] = (catTotals["Others"] ?? 0.0) + amt;
        }

        if (exp.date == todayStr) today += amt;
        if (exp.date.startsWith(thisMonthStr)) month += amt;
        if (exp.date.startsWith(thisYearStr)) year += amt;

        if (exp.date.length >= 7) {
          String ym = exp.date.substring(0, 7);
          trend[ym] = (trend[ym] ?? 0.0) + amt;
        }

        String farmName = entry.farmId == "plot_1" ? "Basveshwar Plot 1" : "Plot ${entry.farmId}";
        farmComp[farmName] = (farmComp[farmName] ?? 0.0) + amt;
      }
    }

    if (trend.isEmpty) {
      trend[thisMonthStr] = month;
    }

    return AnalyticsSummary(
      todayTotal: today,
      monthTotal: month,
      yearTotal: year,
      totalPesticide: pesticide,
      totalFertilizer: fertilizer,
      totalLabour: labour,
      monthlyTrends: trend,
      farmComparison: farmComp,
      topSpendingItems: const [],
      totalExpenses: month,
      totalIncome: 0.0,
      estimatedProfit: -month,
      categoryTotals: catTotals,
      yearlyExpenses: const {},
      yearlyIncomes: const {},
      yearlyProfits: const {},
      simpleInsights: const [],
      insightText: "",
    );
  }

  /// Simplified Farmer Analytics Aggregator
  static AnalyticsSummary generateBiSummary({
    required List<DiaryEntryModel> diaryEntries,
    required List<TurnoverModel> turnovers,
    required List<BillModel> bills,
    required List<FarmModel> farms,
    required String languageCode,
    String? filterFarmId,
    DateTimeRange? filterDateRange,
    String? filterYear,
    String? filterMonth,
    String? filterCategory,
    String? filterCropStage,
  }) {
    // 1. Filter diary entries
    List<DiaryEntryModel> filteredDiary = diaryEntries.where((entry) {
      if (entry.isDeleted) return false;
      if (filterFarmId != null && filterFarmId != "All Plots" && filterFarmId.isNotEmpty) {
        if (entry.farmId != filterFarmId) return false;
      }
      if (filterDateRange != null) {
        try {
          final d = DateTime.parse(entry.date);
          if (d.isBefore(filterDateRange.start) || d.isAfter(filterDateRange.end)) return false;
        } catch (_) {}
      }
      if (filterYear != null && filterYear != "All Years" && filterYear.isNotEmpty) {
        if (!entry.date.startsWith(filterYear)) return false;
      }
      if (filterMonth != null && filterMonth != "All Months" && filterMonth.isNotEmpty) {
        final mStr = filterMonth.padLeft(2, '0');
        if (!entry.date.contains("-$mStr-")) return false;
      }
      if (filterCropStage != null && filterCropStage != "All Stages" && filterCropStage.isNotEmpty) {
        if (entry.cropStage != filterCropStage) return false;
      }
      return true;
    }).toList();

    // 2. Filter turnovers (incomes)
    List<TurnoverModel> filteredTurnovers = turnovers.where((t) {
      if (filterDateRange != null) {
        try {
          final d = DateTime.parse(t.date);
          if (d.isBefore(filterDateRange.start) || d.isAfter(filterDateRange.end)) return false;
        } catch (_) {}
      }
      if (filterYear != null && filterYear != "All Years" && filterYear.isNotEmpty) {
        if (!t.date.startsWith(filterYear)) return false;
      }
      if (filterMonth != null && filterMonth != "All Months" && filterMonth.isNotEmpty) {
        final mStr = filterMonth.padLeft(2, '0');
        if (!t.date.contains("-$mStr-")) return false;
      }
      return true;
    }).toList();

    // 3. Aggregate Expenses into simplified categories
    double totalExpenses = 0.0;
    Map<String, double> catTotals = {
      "Fertilizer": 0.0,
      "Labour": 0.0,
      "Pesticides": 0.0,
      "Irrigation": 0.0,
      "Transport": 0.0,
      "Others": 0.0
    };

    Map<String, double> yearlyExpenses = {};
    Map<String, double> yearlyIncomes = {};
    Map<String, double> yearlyProfits = {};

    for (var entry in filteredDiary) {
      for (var exp in entry.expenses) {
        // Filter by category
        if (filterCategory != null && filterCategory != "All Categories" && filterCategory.isNotEmpty) {
          if (exp.category != filterCategory) continue;
        }

        double amt = exp.totalAmount;
        totalExpenses += amt;

        // Group categories as requested
        String cleanCat = exp.category.trim();
        if (cleanCat == "Fertilizer") {
          catTotals["Fertilizer"] = (catTotals["Fertilizer"] ?? 0.0) + amt;
        } else if (cleanCat == "Labour") {
          catTotals["Labour"] = (catTotals["Labour"] ?? 0.0) + amt;
        } else if (cleanCat == "Pesticide" || cleanCat == "Pesticides") {
          catTotals["Pesticides"] = (catTotals["Pesticides"] ?? 0.0) + amt;
        } else if (cleanCat == "Irrigation") {
          catTotals["Irrigation"] = (catTotals["Irrigation"] ?? 0.0) + amt;
        } else if (cleanCat == "Transport") {
          catTotals["Transport"] = (catTotals["Transport"] ?? 0.0) + amt;
        } else {
          catTotals["Others"] = (catTotals["Others"] ?? 0.0) + amt;
        }

        // Yearly aggregation
        if (exp.date.length >= 4) {
          String yr = exp.date.substring(0, 4);
          yearlyExpenses[yr] = (yearlyExpenses[yr] ?? 0.0) + amt;
        }
      }
    }

    // 4. Aggregate Turnovers (Incomes)
    double totalIncome = 0.0;
    double globalTotalAcres = farms.fold(0.0, (sum, f) => sum + f.acres);
    if (globalTotalAcres == 0.0) globalTotalAcres = 1.0;
    double filteredAcres = farms
        .where((f) => filterFarmId == null || filterFarmId == "All Plots" || f.farmId == filterFarmId)
        .fold(0.0, (sum, f) => sum + f.acres);
    double farmAcresRatio = filteredAcres / globalTotalAcres;

    for (var t in filteredTurnovers) {
      double tYield = t.totalYield;
      // Pro-rate turnovers based on plot filters
      if (filterFarmId != null && filterFarmId != "All Plots" && filterFarmId.isNotEmpty) {
        tYield = tYield * farmAcresRatio;
      }

      double rate = t.grapeType.toLowerCase().contains("dry") ? 180000.0 : 60000.0;
      double tIncome = tYield * rate;
      totalIncome += tIncome;

      if (t.date.length >= 4) {
        String yr = t.date.substring(0, 4);
        yearlyIncomes[yr] = (yearlyIncomes[yr] ?? 0.0) + tIncome;
      }
    }

    // Build yearly profit maps
    final allYears = {...yearlyExpenses.keys, ...yearlyIncomes.keys};
    for (var yr in allYears) {
      double yExp = yearlyExpenses[yr] ?? 0.0;
      double yInc = yearlyIncomes[yr] ?? 0.0;
      yearlyProfits[yr] = yInc - yExp;
    }

    double estimatedProfit = totalIncome - totalExpenses;

    // 5. Generate exactly 3 simple AI insights
    List<String> insights = [];

    // Insight 1: Highest spend category
    String highestCategory = "Others";
    double highestCatAmt = 0.0;
    catTotals.forEach((key, val) {
      if (val > highestCatAmt) {
        highestCatAmt = val;
        highestCategory = key;
      }
    });

    if (highestCatAmt > 0) {
      if (languageCode == 'kn-IN') {
        insights.add("ಈ ಹಂಗಾಮಿನಲ್ಲಿ ನೀವು ಗೊಬ್ಬರ ಮತ್ತು ಔಷಧಿಗಳ ಪೈಕಿ ಅತ್ಯಧಿಕವಾಗಿ '$highestCategory' ಮೇಲೆ ಖರ್ಚು ಮಾಡಿದ್ದೀರಿ.");
      } else if (languageCode == 'hi-IN') {
        insights.add("इस सीजन में आपने सबसे अधिक खर्च '$highestCategory' पर किया है।");
      } else {
        insights.add("You spent the most money on $highestCategory this season.");
      }
    } else {
      if (languageCode == 'kn-IN') {
        insights.add("ಖರ್ಚುಗಳ ವಿವರವನ್ನು ತಿಳಿಯಲು ದಿನಚರಿಯನ್ನು ದಾಖಲಿಸಿ.");
      } else {
        insights.add("Log farm expenses to start generating insights.");
      }
    }

    // Insight 2: YoY Profit comparisons or simple spending warnings
    if (yearlyProfits.length >= 2) {
      final sortedYears = yearlyProfits.keys.toList()..sort();
      final lastYr = sortedYears[sortedYears.length - 2];
      final currYr = sortedYears.last;
      double prevProf = yearlyProfits[lastYr] ?? 0.0;
      double currProf = yearlyProfits[currYr] ?? 0.0;
      if (prevProf > 0) {
        double diffPct = ((currProf - prevProf) / prevProf) * 100;
        if (diffPct > 0) {
          if (languageCode == 'kn-IN') {
            insights.add("ಕಳೆದ ವರ್ಷಕ್ಕೆ ಹೋಲಿಸಿದರೆ ನಿಮ್ಮ ಲಾಭ ಶೇಕಡಾ ${diffPct.toStringAsFixed(0)}% ಹೆಚ್ಚಾಗಿದೆ.");
          } else if (languageCode == 'hi-IN') {
            insights.add("पिछले वर्ष की तुलना में आपका मुनाफा ${diffPct.toStringAsFixed(0)}% बढ़ा है।");
          } else {
            insights.add("Compared to last year, your profit increased by ${diffPct.toStringAsFixed(0)}%.");
          }
        }
      }
    }

    if (insights.length < 2) {
      // Fallback spending warning
      double labourCost = catTotals["Labour"] ?? 0.0;
      if (labourCost > totalExpenses * 0.3) {
        if (languageCode == 'kn-IN') {
          insights.add("ನಿಮ್ಮ ಒಟ್ಟು ವೆಚ್ಚದಲ್ಲಿ ಕೂಲಿ ವೆಚ್ಚವು ಹೆಚ್ಚಾಗಿದೆ (30% ಕ್ಕಿಂತ ಅಧಿಕ).");
        } else if (languageCode == 'hi-IN') {
          insights.add("मजदूरी लागत आपके कुल खर्च के 30% से अधिक है।");
        } else {
          insights.add("Labour costs are higher than 30% of total expenses.");
        }
      } else {
        if (languageCode == 'kn-IN') {
          insights.add("ವೆಚ್ಚ ನಿಯಂತ್ರಿಸಲು ಹನಿ ನೀರಾವರಿ ಪದ್ಧತಿಯನ್ನು ಬಳಸಿ.");
        } else {
          insights.add("Ensure timely spray records to prevent pesticide waste.");
        }
      }
    }

    // Insight 3: Dynamic advice
    if (estimatedProfit > 0) {
      if (languageCode == 'kn-IN') {
        insights.add("ಅಭಿನಂದನೆಗಳು! ನಿಮ್ಮ ಕೃಷಿ ಲಾಭದಲ್ಲಿದೆ. ಈ ಹಂತದ ಆದಾಯವು ಆಶಾದಾಯಕವಾಗಿದೆ.");
      } else if (languageCode == 'hi-IN') {
        insights.add("बधाई हो! आपकी खेती मुनाफे की राह पर चल रही है।");
      } else {
        insights.add("Your farm earnings are higher than your average expenses.");
      }
    } else {
      if (languageCode == 'kn-IN') {
        insights.add("ಔಷಧಿ ಮತ್ತು ಗೊಬ್ಬರದ ಬಿಲ್‌ಗಳನ್ನು ಸ್ಕ್ಯಾನ್ ಮಾಡಿ ಖರ್ಚುಗಳನ್ನು ನಿಯಂತ್ರಿಸಿ.");
      } else if (languageCode == 'hi-IN') {
        insights.add("कीटनाशकों और उर्वरकों के खर्चों की समीक्षा करें।");
      } else {
        insights.add("Expenses increased this month. Review pesticide shop bills.");
      }
    }

    return AnalyticsSummary(
      todayTotal: 0.0,
      monthTotal: totalExpenses,
      yearTotal: totalExpenses,
      totalPesticide: catTotals["Pesticides"] ?? 0.0,
      totalFertilizer: catTotals["Fertilizer"] ?? 0.0,
      totalLabour: catTotals["Labour"] ?? 0.0,
      monthlyTrends: const {},
      farmComparison: const {},
      topSpendingItems: const [],
      totalExpenses: totalExpenses,
      totalIncome: totalIncome,
      estimatedProfit: estimatedProfit,
      categoryTotals: catTotals,
      yearlyExpenses: yearlyExpenses,
      yearlyIncomes: yearlyIncomes,
      yearlyProfits: yearlyProfits,
      simpleInsights: insights.take(3).toList(),
      insightText: "",
    );
  }
}
