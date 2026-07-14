import 'package:flutter/material.dart';
import '../models/diary_entry_model.dart';
import '../models/expense_model.dart';
import '../models/farm_model.dart';
import '../models/bill_model.dart';
import '../models/turnover_model.dart';
import '../core/constants/constants.dart';
import 'package:intl/intl.dart';

class AnalyticsSummary {
  // Old fields for backward compatibility
  final double todayTotal;
  final double monthTotal;
  final double yearTotal;
  final double totalPesticide;
  final double totalFertilizer;
  final double totalLabour;
  final Map<String, double> monthlyTrends;
  final Map<String, double> farmComparison;
  final List<Map<String, dynamic>> topSpendingItems;

  // New BI fields
  final double totalExpenses;
  final double totalIncome;
  final double estimatedProfit;
  final double totalYield;
  final double totalAcres;
  final int plotCount;
  final int diaryEntriesCount;
  final int billsScannedCount;
  final int photosUploadedCount;
  final int sprayRecordsCount;

  final Map<String, double> yearExpenses;
  final Map<String, double> monthlyExpenses;
  final Map<String, double> categoryTotals;
  final Map<String, double> yearYields;
  final List<MapEntry<double, double>> expenseVsYield;
  final Map<String, MapEntry<double, double>> yearIncomeExpenses;
  final Map<String, double> monthlyProfits;
  final Map<String, Map<String, double>> farmComparisons;
  final Map<String, double> stageExpenses;
  final Map<String, double> supplierSpend;
  final Map<String, double> materialPurchases;

  final List<String> aiInsights;
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
    required this.totalYield,
    required this.totalAcres,
    required this.plotCount,
    required this.diaryEntriesCount,
    required this.billsScannedCount,
    required this.photosUploadedCount,
    required this.sprayRecordsCount,
    required this.yearExpenses,
    required this.monthlyExpenses,
    required this.categoryTotals,
    required this.yearYields,
    required this.expenseVsYield,
    required this.yearIncomeExpenses,
    required this.monthlyProfits,
    required this.farmComparisons,
    required this.stageExpenses,
    required this.supplierSpend,
    required this.materialPurchases,
    required this.aiInsights,
    required this.insightText,
  });
}

class AnalyticsService {
  /// Backward compatible dashboard data retrieval
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
      for (var exp in entry.expenses) {
        allExpenses.add(exp);

        double amt = exp.totalAmount;
        String cat = exp.category;

        catTotals[cat] = (catTotals[cat] ?? 0.0) + amt;

        if (cat == "Pesticides" || cat == "Pesticide") pesticide += amt;
        if (cat == "Fertilizer") fertilizer += amt;
        if (cat == "Labour") labour += amt;

        if (exp.date == todayStr) {
          today += amt;
        }
        if (exp.date.startsWith(thisMonthStr)) {
          month += amt;
        }
        if (exp.date.startsWith(thisYearStr)) {
          year += amt;
        }

        if (exp.date.length >= 7) {
          String ym = exp.date.substring(0, 7);
          trend[ym] = (trend[ym] ?? 0.0) + amt;
        }

        String farmName = entry.farmId == "plot_1" ? "Basveshwar Plot 1" : "Plot ${entry.farmId}";
        farmComp[farmName] = (farmComp[farmName] ?? 0.0) + amt;
      }
    }

    String highestCat = "None";
    double highestCatAmt = 0.0;
    catTotals.forEach((key, value) {
      if (value > highestCatAmt) {
        highestCatAmt = value;
        highestCat = key;
      }
    });

    allExpenses.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    List<Map<String, dynamic>> topItems = allExpenses
        .take(5)
        .map((e) => {
              'itemName': e.itemName.isNotEmpty ? e.itemName : e.category,
              'category': e.category,
              'amount': e.totalAmount,
            })
        .toList();

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
      topSpendingItems: topItems,
      totalExpenses: month,
      totalIncome: 0.0,
      estimatedProfit: -month,
      totalYield: 0.0,
      totalAcres: 0.0,
      plotCount: 0,
      diaryEntriesCount: entries.length,
      billsScannedCount: 0,
      photosUploadedCount: 0,
      sprayRecordsCount: 0,
      yearExpenses: {},
      monthlyExpenses: {},
      categoryTotals: catTotals,
      yearYields: {},
      expenseVsYield: [],
      yearIncomeExpenses: {},
      monthlyProfits: {},
      farmComparisons: {},
      stageExpenses: {},
      supplierSpend: {},
      materialPurchases: {},
      aiInsights: [insight],
      insightText: insight,
    );
  }

  /// Advanced BI Dashboard summaries with full filtration algorithms
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
    List<FarmModel> filteredFarms = List.from(farms);
    if (filterFarmId != null && filterFarmId != "All Plots" && filterFarmId.isNotEmpty) {
      filteredFarms = farms.where((f) => f.farmId == filterFarmId).toList();
    }
    double totalAcres = filteredFarms.fold(0.0, (sum, f) => sum + f.acres);
    double globalTotalAcres = farms.fold(0.0, (sum, f) => sum + f.acres);
    if (globalTotalAcres == 0.0) globalTotalAcres = 1.0;
    double farmAcresRatio = totalAcres / globalTotalAcres;

    List<DiaryEntryModel> filteredDiary = diaryEntries.where((entry) {
      if (entry.isDeleted) return false;
      if (filterFarmId != null && filterFarmId != "All Plots" && filterFarmId.isNotEmpty) {
        if (entry.farmId != filterFarmId) return false;
      }
      if (filterDateRange != null) {
        try {
          final d = DateTime.parse(entry.date);
          if (d.isBefore(filterDateRange.start) || d.isAfter(filterDateRange.end)) {
            return false;
          }
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

    List<BillModel> filteredBills = bills.where((b) {
      if (filterDateRange != null) {
        try {
          final d = DateTime.parse(b.billDate);
          if (d.isBefore(filterDateRange.start) || d.isAfter(filterDateRange.end)) return false;
        } catch (_) {}
      }
      if (filterYear != null && filterYear != "All Years" && filterYear.isNotEmpty) {
        if (!b.billDate.startsWith(filterYear)) return false;
      }
      if (filterMonth != null && filterMonth != "All Months" && filterMonth.isNotEmpty) {
        final mStr = filterMonth.padLeft(2, '0');
        if (!b.billDate.contains("-$mStr-")) return false;
      }
      return true;
    }).toList();

    double totalExpenses = 0.0;
    int photoCount = 0;
    int sprayCount = 0;
    Map<String, double> catTotals = {};
    for (var cat in AppConstants.expenseCategories) {
      catTotals[cat] = 0.0;
    }

    Map<String, double> yearExpMap = {};
    Map<String, double> monthlyExpMap = {};
    Map<String, double> stageExpMap = {};

    for (var entry in filteredDiary) {
      photoCount += entry.photos.length;
      bool isSpray = entry.workType.toLowerCase().contains("spray") ||
                     entry.structuredData.pesticides.isNotEmpty ||
                     entry.structuredData.fertilizers.isNotEmpty;
      if (isSpray) sprayCount++;

      for (var exp in entry.expenses) {
        if (filterCategory != null && filterCategory != "All Categories" && filterCategory.isNotEmpty) {
          if (exp.category != filterCategory) continue;
        }
        double amt = exp.totalAmount;
        totalExpenses += amt;
        catTotals[exp.category] = (catTotals[exp.category] ?? 0.0) + amt;

        if (exp.date.length >= 4) {
          String y = exp.date.substring(0, 4);
          yearExpMap[y] = (yearExpMap[y] ?? 0.0) + amt;
        }
        if (exp.date.length >= 7) {
          String ym = exp.date.substring(5, 7);
          monthlyExpMap[ym] = (monthlyExpMap[ym] ?? 0.0) + amt;
        }
        String stage = entry.cropStage.isNotEmpty ? entry.cropStage : "Other";
        stageExpMap[stage] = (stageExpMap[stage] ?? 0.0) + amt;
      }
    }

    double totalYield = 0.0;
    double totalIncome = 0.0;
    Map<String, double> yearYields = {};
    Map<String, MapEntry<double, double>> yearIncExp = {};

    for (var t in filteredTurnovers) {
      double tYield = t.totalYield;
      if (filterFarmId != null && filterFarmId != "All Plots" && filterFarmId.isNotEmpty) {
        tYield = tYield * farmAcresRatio;
      }
      totalYield += tYield;
      double rate = t.grapeType.toLowerCase().contains("dry") ? 180000.0 : 60000.0;
      double tIncome = tYield * rate;
      totalIncome += tIncome;

      if (t.date.length >= 4) {
        String y = t.date.substring(0, 4);
        yearYields[y] = (yearYields[y] ?? 0.0) + tYield;
        double currentInc = yearIncExp[y]?.key ?? 0.0;
        double currentExp = yearIncExp[y]?.value ?? 0.0;
        yearIncExp[y] = MapEntry(currentInc + tIncome, currentExp);
      }
    }

    yearExpMap.forEach((year, expVal) {
      double currentInc = yearIncExp[year]?.key ?? 0.0;
      yearIncExp[year] = MapEntry(currentInc, expVal);
    });

    double estimatedProfit = totalIncome - totalExpenses;

    Map<String, double> monthlyProfits = {};
    for (int i = 1; i <= 12; i++) {
      String mm = i.toString().padLeft(2, '0');
      double expAmt = monthlyExpMap[mm] ?? 0.0;
      double incAmt = 0.0;
      for (var t in filteredTurnovers) {
        if (t.date.length >= 7) {
          String tMM = t.date.substring(5, 7);
          if (tMM == mm) {
            double rate = t.grapeType.toLowerCase().contains("dry") ? 180000.0 : 60000.0;
            double tIncome = t.totalYield * rate;
            if (filterFarmId != null && filterFarmId != "All Plots" && filterFarmId.isNotEmpty) {
              tIncome = tIncome * farmAcresRatio;
            }
            incAmt += tIncome;
          }
        }
      }
      if (incAmt > 0 || expAmt > 0) {
        monthlyProfits[mm] = incAmt - expAmt;
      }
    }

    List<MapEntry<double, double>> expenseVsYieldPoints = [];
    for (int i = 1; i <= 12; i++) {
      String mm = i.toString().padLeft(2, '0');
      double expAmt = monthlyExpMap[mm] ?? 0.0;
      double yldAmt = 0.0;
      for (var t in filteredTurnovers) {
        if (t.date.length >= 7 && t.date.substring(5, 7) == mm) {
          double ty = t.totalYield;
          if (filterFarmId != null && filterFarmId != "All Plots" && filterFarmId.isNotEmpty) {
            ty = ty * farmAcresRatio;
          }
          yldAmt += ty;
        }
      }
      if (expAmt > 0 || yldAmt > 0) {
        expenseVsYieldPoints.add(MapEntry(expAmt, yldAmt));
      }
    }

    Map<String, Map<String, double>> farmComps = {};
    for (var f in farms) {
      double fExp = 0.0;
      final fEntries = diaryEntries.where((e) => !e.isDeleted && e.farmId == f.farmId);
      for (var entry in fEntries) {
        for (var exp in entry.expenses) {
          fExp += exp.totalAmount;
        }
      }
      double fRatio = f.acres / globalTotalAcres;
      double fYield = 0.0;
      double fIncome = 0.0;
      for (var t in turnovers) {
        double ty = t.totalYield * fRatio;
        fYield += ty;
        double rate = t.grapeType.toLowerCase().contains("dry") ? 180000.0 : 60000.0;
        fIncome += ty * rate;
      }
      farmComps[f.farmName] = {
        "Expenses": fExp,
        "Yield": fYield,
        "Profit": fIncome - fExp,
      };
    }

    Map<String, double> supplierSpendMap = {};
    Map<String, double> materialPurchasedMap = {};
    for (var b in filteredBills) {
      supplierSpendMap[b.shopName] = (supplierSpendMap[b.shopName] ?? 0.0) + b.totalAmount;
      for (var item in b.items) {
        String cleanName = item.itemName.trim();
        if (cleanName.isNotEmpty) {
          materialPurchasedMap[cleanName] = (materialPurchasedMap[cleanName] ?? 0.0) + item.amount;
        }
      }
    }

    List<String> insights = [];
    String insightText = "";

    String maxCat = "None";
    double maxCatAmt = 0.0;
    catTotals.forEach((key, val) {
      if (val > maxCatAmt) {
        maxCatAmt = val;
        maxCat = key;
      }
    });

    if (maxCatAmt > 0) {
      if (languageCode == 'kn-IN') {
        insights.add("ನಿಮ್ಮ ಅತ್ಯಧಿಕ ವೆಚ್ಚ $maxCat ಆಗಿದೆ (₹${maxCatAmt.toStringAsFixed(0)}).");
      } else if (languageCode == 'hi-IN') {
        insights.add("आपका सबसे अधिक खर्च $maxCat पर हुआ है (₹${maxCatAmt.toStringAsFixed(0)}).");
      } else {
        insights.add("Your highest spending category is $maxCat (₹${maxCatAmt.toStringAsFixed(0)}).");
      }
    }

    double fert = catTotals["Fertilizer"] ?? 0.0;
    double pest = catTotals["Pesticides"] ?? 0.0;
    if (pest > fert && pest > 0) {
      if (languageCode == 'kn-IN') {
        insights.add("ಗೊಬ್ಬರಕ್ಕಿಂತ ಔಷಧಿಗೆ ಹೆಚ್ಚಿನ ವೆಚ್ಚವಾಗಿದೆ. ಕೀಟ ರೋಗಗಳ ಪರಿಶೀಲನೆ ಮಾಡಿ.");
      } else if (languageCode == 'hi-IN') {
        insights.add("उर्वरक की तुलना में कीटनाशकों पर अधिक खर्च हुआ। कीट नियंत्रण की समीक्षा करें।");
      } else {
        insights.add("Pesticide expense is higher than fertilizer. Monitor pest logs.");
      }
    }

    if (estimatedProfit > 0) {
      if (languageCode == 'kn-IN') {
        insights.add("ಈ ಹಂತದಲ್ಲಿ ಅಂದಾಜು ಲಾಭ ₹${estimatedProfit.toStringAsFixed(0)} ಆಗಿದೆ.");
        insightText = "ಅಭಿನಂದನೆಗಳು! ನಿಮ್ಮ ಕೃಷಿ ಲಾಭದಾಯಕ ಹಾದಿಯಲ್ಲಿದೆ. ಒಟ್ಟು ಆದಾಯ ₹${totalIncome.toStringAsFixed(0)} ಮತ್ತು ಒಟ್ಟು ವೆಚ್ಚ ₹${totalExpenses.toStringAsFixed(0)} ಆಗಿದೆ.";
      } else if (languageCode == 'hi-IN') {
        insights.add("इस सीजन में अनुमानित लाभ ₹${estimatedProfit.toStringAsFixed(0)} है।");
        insightText = "बधाई हो! आपकी खेती मुनाफे की राह पर है। कुल आय ₹${totalIncome.toStringAsFixed(0)} और कुल खर्च ₹${totalExpenses.toStringAsFixed(0)} है।";
      } else {
        insights.add("Estimated profit this season is ₹${estimatedProfit.toStringAsFixed(0)}.");
        insightText = "Congratulations! Your farm business is profitable. Total revenue is ₹${totalIncome.toStringAsFixed(0)} against expenses of ₹${totalExpenses.toStringAsFixed(0)}.";
      }
    } else {
      if (languageCode == 'kn-IN') {
        insights.add("ಖರ್ಚು ಆದಾಯಕ್ಕಿಂತ ಹೆಚ್ಚಾಗಿದೆ. ವೆಚ್ಚ ನಿಯಂತ್ರಣದ ಕಡೆ ಗಮನಹರಿಸಿ.");
        insightText = "ವೆಚ್ಚಗಳು ನಿಮ್ಮ ಆದಾಯವನ್ನು ಮೀರಿದೆ. ದಯವಿಟ್ಟು ಕೀಟನಾಶಕ ಮತ್ತು ಕೂಲಿ ವೆಚ್ಚಗಳನ್ನು ಪರಿಶೀಲಿಸಿ.";
      } else if (languageCode == 'hi-IN') {
        insights.add("खर्च आय से अधिक हो गया है। लागत कम करने पर ध्यान दें।");
        insightText = "खर्च आपकी कुल आय से अधिक है। कृपया कीटनाशक और मजदूरी लागतों की समीक्षा करें।";
      } else {
        insights.add("Expenses exceed current income. Focus on cost optimization.");
        insightText = "Your farm expenses exceed current income. Consider reviewing chemical spray and labour logs.";
      }
    }

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final thisMonthStr = DateFormat('yyyy-MM').format(now);
    final thisYearStr = DateFormat('yyyy').format(now);
    
    double oldToday = 0.0;
    double oldMonth = 0.0;
    double oldYear = 0.0;
    double oldPest = 0.0;
    double oldFert = 0.0;
    double oldLab = 0.0;
    Map<String, double> oldTrend = {};
    Map<String, double> oldFarmComp = {};

    for (var entry in filteredDiary) {
      for (var exp in entry.expenses) {
        if (exp.date == todayStr) oldToday += exp.totalAmount;
        if (exp.date.startsWith(thisMonthStr)) oldMonth += exp.totalAmount;
        if (exp.date.startsWith(thisYearStr)) oldYear += exp.totalAmount;
        if (exp.category == "Pesticides") oldPest += exp.totalAmount;
        if (exp.category == "Fertilizer") oldFert += exp.totalAmount;
        if (exp.category == "Labour") oldLab += exp.totalAmount;
        if (exp.date.length >= 7) {
          String ym = exp.date.substring(0, 7);
          oldTrend[ym] = (oldTrend[ym] ?? 0.0) + exp.totalAmount;
        }
        String fn = entry.farmId == "plot_1" ? "Basveshwar Plot 1" : "Plot ${entry.farmId}";
        oldFarmComp[fn] = (oldFarmComp[fn] ?? 0.0) + exp.totalAmount;
      }
    }

    return AnalyticsSummary(
      todayTotal: oldToday,
      monthTotal: oldMonth,
      yearTotal: oldYear,
      totalPesticide: oldPest,
      totalFertilizer: oldFert,
      totalLabour: oldLab,
      monthlyTrends: oldTrend,
      farmComparison: oldFarmComp,
      topSpendingItems: [],
      totalExpenses: totalExpenses,
      totalIncome: totalIncome,
      estimatedProfit: estimatedProfit,
      totalYield: totalYield,
      totalAcres: totalAcres,
      plotCount: filteredFarms.length,
      diaryEntriesCount: filteredDiary.length,
      billsScannedCount: filteredBills.length,
      photosUploadedCount: photoCount,
      sprayRecordsCount: sprayCount,
      yearExpenses: yearExpMap,
      monthlyExpenses: monthlyExpMap,
      categoryTotals: catTotals,
      yearYields: yearYields,
      expenseVsYield: expenseVsYieldPoints,
      yearIncomeExpenses: yearIncExp,
      monthlyProfits: monthlyProfits,
      farmComparisons: farmComps,
      stageExpenses: stageExpMap,
      supplierSpend: supplierSpendMap,
      materialPurchases: materialPurchasedMap,
      aiInsights: insights,
      insightText: insightText,
    );
  }
}
