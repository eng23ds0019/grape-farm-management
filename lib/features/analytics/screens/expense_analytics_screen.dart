import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/colors.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../core/localization/translations.dart';
import '../../../services/firestore_service.dart';
import '../../../services/analytics_service.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/expense_chart.dart';

class ExpenseAnalyticsScreen extends StatefulWidget {
  final String selectedFarmId;

  const ExpenseAnalyticsScreen({super.key, required this.selectedFarmId});

  @override
  State<ExpenseAnalyticsScreen> createState() => _ExpenseAnalyticsScreenState();
}

class _ExpenseAnalyticsScreenState extends State<ExpenseAnalyticsScreen> {
  // Filter states
  String _selectedFarmId = "All Plots";
  String _selectedYear = "All Years";
  String _selectedMonth = "All Months";
  String _selectedCategory = "All Categories";
  String _selectedCropStage = "All Stages";
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    // Default to the user's selected dashboard plot if specified
    if (widget.selectedFarmId.isNotEmpty && widget.selectedFarmId != "plot_all") {
      _selectedFarmId = widget.selectedFarmId;
    }
  }

  void _exportReport(AnalyticsSummary summary, String format) {
    String content = "🍀 DRAKSHA FARM BUSINESS INTELLIGENCE REPORT 🍀\n";
    content += "Export Format: $format\n";
    content += "Generated At: ${DateTime.now().toString().substring(0, 19)}\n";
    content += "=========================================\n\n";

    content += "📊 KEY PERFORMANCE METRICS\n";
    content += "-----------------------------------------\n";
    content += "• Total Expenses: ₹${summary.totalExpenses.toStringAsFixed(2)}\n";
    content += "• Total Income: ₹${summary.totalIncome.toStringAsFixed(2)}\n";
    content += "• Estimated Net Profit: ₹${summary.estimatedProfit.toStringAsFixed(2)}\n";
    content += "• Total Harvested Yield: ${summary.totalYield.toStringAsFixed(2)} Tons\n";
    content += "• Farm Area: ${summary.totalAcres.toStringAsFixed(1)} Acres\n";
    content += "• Plots Monitored: ${summary.plotCount}\n";
    content += "• Diary Logs: ${summary.diaryEntriesCount}\n";
    content += "• Scanned Bills: ${summary.billsScannedCount}\n";
    content += "• Media Photos: ${summary.photosUploadedCount}\n";
    content += "• Sprays Performed: ${summary.sprayRecordsCount}\n\n";

    content += "🎨 EXPENSE BREAKDOWN BY CATEGORY\n";
    content += "-----------------------------------------\n";
    summary.categoryTotals.forEach((cat, amt) {
      if (amt > 0) {
        content += "• $cat: ₹${amt.toStringAsFixed(2)}\n";
      }
    });
    content += "\n";

    content += "💡 AI FARM ADVISORY INSIGHTS\n";
    content += "-----------------------------------------\n";
    for (var insight in summary.aiInsights) {
      content += "- $insight\n";
    }
    content += "\n";
    content += "=========================================\n";
    content += "Thank you for using Draksha Farm Management.";

    Share.share(content, subject: 'Draksha Farm BI Report - $format');
  }

  void _clearFilters() {
    setState(() {
      _selectedFarmId = "All Plots";
      _selectedYear = "All Years";
      _selectedMonth = "All Months";
      _selectedCategory = "All Categories";
      _selectedCropStage = "All Stages";
      _selectedDateRange = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Provider.of<LanguageNotifier>(context).currentLanguage;
    final firestoreService = Provider.of<FirestoreService>(context);

    // Fetch database items
    final diaryEntries = firestoreService.cachedDiary;
    final turnovers = firestoreService.cachedTurnovers;
    final bills = firestoreService.cachedBills;
    final farms = firestoreService.cachedFarms;

    // Generate dynamic values for dropdown choices
    final farmIdsList = ["All Plots", ...farms.map((f) => f.farmId)];
    final farmNamesMap = {
      "All Plots": langCode == 'kn-IN' ? "ಎಲ್ಲಾ ಪ್ಲಾಟ್‌ಗಳು" : (langCode == 'hi-IN' ? "सभी प्लॉट" : "All Plots")
    };
    for (var f in farms) {
      farmNamesMap[f.farmId] = f.farmName;
    }

    final cropStages = [
      "All Stages",
      "Land Preparation",
      "Bud Stage",
      "Flowering",
      "Fruit Set",
      "Berry Growth",
      "Harvest"
    ];

    final expenseCategories = [
      "All Categories",
      "Fertilizer",
      "Pesticides",
      "Labour",
      "Irrigation",
      "Machinery",
      "Transport",
      "Electricity",
      "Other"
    ];

    final years = ["All Years", "2024", "2025", "2026"];
    final months = [
      "All Months",
      "01", "02", "03", "04", "05", "06",
      "07", "08", "09", "10", "11", "12"
    ];
    final monthNamesMap = {
      "All Months": langCode == 'kn-IN' ? "ಎಲ್ಲಾ ತಿಂಗಳುಗಳು" : "All Months",
      "01": "Jan", "02": "Feb", "03": "Mar", "04": "Apr", "05": "May", "06": "Jun",
      "07": "Jul", "08": "Aug", "09": "Sep", "10": "Oct", "11": "Nov", "12": "Dec"
    };

        // Calculate dynamic dashboard summary values
    final summary = AnalyticsService.generateBiSummary(
      diaryEntries: diaryEntries,
      turnovers: turnovers,
      bills: bills,
      farms: farms,
      languageCode: langCode,
      filterFarmId: _selectedFarmId,
      filterDateRange: _selectedDateRange,
      filterYear: _selectedYear,
      filterMonth: _selectedMonth,
      filterCategory: _selectedCategory,
      filterCropStage: _selectedCropStage,
    );

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.analytics, color: AppColors.white),
            const SizedBox(width: 8),
            Text(
              langCode == 'kn-IN' ? "ಕೃಷಿ ವ್ಯವಹಾರ ವಿಶ್ಲೇಷಣೆ" : "Farm Business Intelligence",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.white),
            tooltip: "Reset Filters",
            onPressed: _clearFilters,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. FILTER CONTROLLER CARD
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tune, color: AppColors.primaryGreen, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              langCode == 'kn-IN' ? "ಫಿಲ್ಟರ್‌ಗಳು" : "Analytics Filters",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryGreen),
                            ),
                          ],
                        ),
                        if (_selectedDateRange != null)
                          TextButton(
                            onPressed: () => setState(() => _selectedDateRange = null),
                            child: const Text("Clear Dates", style: TextStyle(fontSize: 11, color: AppColors.errorRed)),
                          )
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Filter Fields Grid
                    LayoutBuilder(builder: (context, constraints) {
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Farm dropdown
                          SizedBox(
                            width: (constraints.maxWidth - 8) / 2,
                            child: _buildDropdown(
                              label: "Plot",
                              value: _selectedFarmId,
                              items: farmIdsList.map((id) => DropdownMenuItem(
                                    value: id,
                                    child: Text(farmNamesMap[id] ?? id, style: const TextStyle(fontSize: 12)),
                                  )).toList(),
                              onChanged: (val) => setState(() => _selectedFarmId = val ?? "All Plots"),
                            ),
                          ),
                          // Crop stage dropdown
                          SizedBox(
                            width: (constraints.maxWidth - 8) / 2,
                            child: _buildDropdown(
                              label: "Stage",
                              value: _selectedCropStage,
                              items: cropStages.map((stg) => DropdownMenuItem(
                                    value: stg,
                                    child: Text(stg, style: const TextStyle(fontSize: 12)),
                                  )).toList(),
                              onChanged: (val) => setState(() => _selectedCropStage = val ?? "All Stages"),
                            ),
                          ),
                          // Year dropdown
                          SizedBox(
                            width: (constraints.maxWidth - 8) / 2,
                            child: _buildDropdown(
                              label: "Year",
                              value: _selectedYear,
                              items: years.map((y) => DropdownMenuItem(
                                    value: y,
                                    child: Text(y, style: const TextStyle(fontSize: 12)),
                                  )).toList(),
                              onChanged: (val) => setState(() => _selectedYear = val ?? "All Years"),
                            ),
                          ),
                          // Month dropdown
                          SizedBox(
                            width: (constraints.maxWidth - 8) / 2,
                            child: _buildDropdown(
                              label: "Month",
                              value: _selectedMonth,
                              items: months.map((m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(monthNamesMap[m] ?? m, style: const TextStyle(fontSize: 12)),
                                  )).toList(),
                              onChanged: (val) => setState(() => _selectedMonth = val ?? "All Months"),
                            ),
                          ),
                          // Category dropdown
                          SizedBox(
                            width: constraints.maxWidth,
                            child: _buildDropdown(
                              label: "Expense Category",
                              value: _selectedCategory,
                              items: expenseCategories.map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c, style: const TextStyle(fontSize: 12)),
                                  )).toList(),
                              onChanged: (val) => setState(() => _selectedCategory = val ?? "All Categories"),
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 10),
                    // Date range picker button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text(
                          _selectedDateRange == null
                              ? "Custom Date Range"
                              : "${_selectedDateRange!.start.toString().substring(0, 10)} to ${_selectedDateRange!.end.toString().substring(0, 10)}",
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () async {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2027),
                          );
                          if (range != null) {
                            setState(() {
                              _selectedDateRange = range;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. KPI METRICS GRID CARD
              Text(
                langCode == 'kn-IN' ? "ಪ್ರಮುಖ ಸೂಚಕಗಳು" : "Key Performance Indicators",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.earthyBrown),
              ),
              const SizedBox(height: 8),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.6,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  _buildKpiCard("Total Expenses", summary.totalExpenses, isCurrency: true, color: const Color(0xFFFFEBEE), textColor: AppColors.errorRed, icon: Icons.money_off),
                  _buildKpiCard("Total Income", summary.totalIncome, isCurrency: true, color: const Color(0xFFE8F5E9), textColor: AppColors.primaryGreen, icon: Icons.attach_money),
                  _buildKpiCard("Estimated Profit", summary.estimatedProfit, isCurrency: true, color: const Color(0xFFE0F2F1), textColor: Colors.teal.shade700, icon: Icons.trending_up),
                  _buildKpiCard("Total Yield", summary.totalYield, suffix: " Tons", color: const Color(0xFFFFF3E0), textColor: Colors.orange.shade700, icon: Icons.grass),
                  _buildKpiCard("Total Area", summary.totalAcres, suffix: " Acres", color: const Color(0xFFEFEBE9), textColor: AppColors.earthyBrown, icon: Icons.landscape),
                  _buildKpiCard("Farm Plots", summary.plotCount.toDouble(), color: const Color(0xFFE1F5FE), textColor: Colors.blue.shade700, icon: Icons.grid_view),
                  _buildKpiCard("Diary Logs", summary.diaryEntriesCount.toDouble(), color: const Color(0xFFF3E5F5), textColor: AppColors.accentPurple, icon: Icons.book),
                  _buildKpiCard("Bills Scanned", summary.billsScannedCount.toDouble(), color: const Color(0xFFFFFDE7), textColor: Colors.amber.shade900, icon: Icons.document_scanner),
                  _buildKpiCard("Media Photos", summary.photosUploadedCount.toDouble(), color: const Color(0xFFECEFF1), textColor: Colors.blueGrey, icon: Icons.photo_library),
                  _buildKpiCard("Spray Records", summary.sprayRecordsCount.toDouble(), color: const Color(0xFFF1F8E9), textColor: Colors.lightGreen.shade900, icon: Icons.bug_report),
                ],
              ),
              const SizedBox(height: 16),

              // 3. AI INSIGHTS ADVISORY
              AppCard(
                color: AppColors.softYellow,
                border: Border.all(color: AppColors.softYellowDark, width: 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.psychology, color: AppColors.accentPurple, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          langCode == 'kn-IN' ? "ದ್ರಾಕ್ಷಾ AI ವ್ಯವಹಾರ ಒಳನೋಟಗಳು" : "Draksha AI Business Insights",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.accentPurple),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (summary.aiInsights.isEmpty)
                      const Text("No insights available. Log more diaries & turnovers to generate AI recommendations.", style: TextStyle(fontSize: 12, color: AppColors.textLight))
                    else
                      ...summary.aiInsights.map((insight) => Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("• ", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentPurple)),
                                Expanded(child: Text(insight, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark))),
                              ],
                            ),
                          )),
                    const SizedBox(height: 6),
                    Divider(color: AppColors.softYellowDark.withOpacity(0.3)),
                    const SizedBox(height: 4),
                    Text(
                      summary.insightText,
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textDark.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. INTERACTIVE BI CHARTS
              Text(
                langCode == 'kn-IN' ? "ವ್ಯವಹಾರ ಪ್ಲಾಟ್‌ಗಳು ಮತ್ತು ಚಾರ್ಟ್‌ಗಳು" : "Business Dashboard Charts",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.earthyBrown),
              ),
              const SizedBox(height: 8),

              // Chart 1: Expense Category Splits
              _buildChartCard("Expense Category Splits", ExpenseDonutChart(categoryTotals: summary.categoryTotals)),
              const SizedBox(height: 12),

              // Chart 2: Monthly Expense Trend
              _buildChartCard("Monthly Expense Trend", MonthlyExpenseTrendChart(monthlyTrends: summary.monthlyExpenses)),
              const SizedBox(height: 12),

              // Chart 3: Income vs Expenses
              _buildChartCard("Income vs Expenses Comparison", IncomeVsExpensesChart(yearIncomeExpenses: summary.yearIncomeExpenses)),
              const SizedBox(height: 12),

              // Chart 4: Monthly Profit Trend
              _buildChartCard("Monthly Profit / Loss Trend", MonthlyProfitTrendChart(monthlyProfits: summary.monthlyProfits)),
              const SizedBox(height: 12),

              // Chart 5: Crop Stage Cost allocations
              _buildChartCard("Grape Lifecycle Stage cost allocation", CropStageTimelineChart(stageExpenses: summary.stageExpenses)),
              const SizedBox(height: 12),

              // Chart 6: Bill Scanner Supplier splits
              _buildChartCard("Bill Scanner - Supplier Spend Splits", BillScannerAnalyticsChart(supplierSpend: summary.supplierSpend)),
              const SizedBox(height: 12),

              // Chart 7: Year vs Total Expenses
              _buildChartCard("Year vs Total Farm Expenses", YearlyExpensesChart(yearExpenses: summary.yearExpenses)),
              const SizedBox(height: 12),

              // Chart 8: Year vs Harvested Yield
              _buildChartCard("Year vs Total Harvested Yield (Tons)", YearlyYieldChart(yearYields: summary.yearYields)),
              const SizedBox(height: 12),

              // Chart 9: Expense vs Yield Scatter Plot
              _buildChartCard("Cost vs Yield Scatter Map", ExpenseVsYieldChart(points: summary.expenseVsYield)),
              const SizedBox(height: 12),

              // Chart 10: Farm Plot comparative analysis
              _buildChartCard("Farm Plots comparative summary", FarmWiseComparisonChart(farmComparisons: summary.farmComparisons)),
              const SizedBox(height: 16),

              // 5. REPORT EXPORT ACTIONS
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Export Analytics Reports",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.earthyBrown),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.description, size: 16),
                            label: const Text("CSV", style: TextStyle(fontSize: 12)),
                            onPressed: () => _exportReport(summary, "CSV"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.table_view, size: 16),
                            label: const Text("Excel", style: TextStyle(fontSize: 12)),
                            onPressed: () => _exportReport(summary, "Excel"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.picture_as_pdf, size: 16),
                            label: const Text("PDF Summary", style: TextStyle(fontSize: 12)),
                            onPressed: () => _exportReport(summary, "PDF"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textLight)),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
    String title,
    double value, {
    bool isCurrency = false,
    String suffix = "",
    required Color color,
    required Color textColor,
    required IconData icon,
  }) {
    String formattedValue = value.toStringAsFixed(0);
    if (isCurrency) {
      formattedValue = "₹${value.toStringAsFixed(0)}";
    }

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withOpacity(0.1), width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          Positioned(
            top: 2,
            right: 2,
            child: Icon(icon, size: 22, color: textColor.withOpacity(0.08)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textLight),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "$formattedValue$suffix",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, Widget chartWidget) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 14),
          chartWidget,
        ],
      ),
    );
  }
}
