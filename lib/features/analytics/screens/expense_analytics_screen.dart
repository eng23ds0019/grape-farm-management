import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../core/localization/translations.dart';
import '../../../services/firestore_service.dart';
import '../../../services/analytics_service.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/expense_chart.dart';

class PulsingCelebrationWidget extends StatefulWidget {
  const PulsingCelebrationWidget({super.key});

  @override
  State<PulsingCelebrationWidget> createState() => _PulsingCelebrationWidgetState();
}

class _PulsingCelebrationWidgetState extends State<PulsingCelebrationWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.celebration, color: Colors.green, size: 28),
      ),
    );
  }
}

class ExpenseAnalyticsScreen extends StatefulWidget {
  final String selectedFarmId;

  const ExpenseAnalyticsScreen({super.key, required this.selectedFarmId});

  @override
  State<ExpenseAnalyticsScreen> createState() => _ExpenseAnalyticsScreenState();
}

class _ExpenseAnalyticsScreenState extends State<ExpenseAnalyticsScreen> {
  // Toggle choice for Year Comparison Chart ("Expenses", "Income", "Profit")
  String _yearlyComparisonMode = "Expenses";

  // Filter states
  String _selectedFarmId = "All Plots";
  String _selectedCropStage = "All Stages";

  @override
  void initState() {
    super.initState();
    if (widget.selectedFarmId.isNotEmpty && widget.selectedFarmId != "plot_all") {
      _selectedFarmId = widget.selectedFarmId;
    }
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

    // Filter lists
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

    // Compute simple analytics summary
    final summary = AnalyticsService.generateBiSummary(
      diaryEntries: diaryEntries,
      turnovers: turnovers,
      bills: bills,
      farms: farms,
      languageCode: langCode,
      filterFarmId: _selectedFarmId,
      filterCropStage: _selectedCropStage,
    );

    // Determine values for yearly chart toggle
    Map<String, double> activeYearlyData = summary.yearlyExpenses;
    Color activeYearlyColor = AppColors.errorRed;
    if (_yearlyComparisonMode == "Income") {
      activeYearlyData = summary.yearlyIncomes;
      activeYearlyColor = AppColors.primaryGreen;
    } else if (_yearlyComparisonMode == "Profit") {
      activeYearlyData = summary.yearlyProfits;
      activeYearlyColor = Colors.teal.shade700;
    }

    final isProfit = summary.estimatedProfit >= 0;

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: Text(
          langCode == 'kn-IN' ? "ಖರ್ಚು ಮತ್ತು ಆದಾಯ" : "Expenses & Income",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. SIMPLE FILTERS ROW
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Farm dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedFarmId,
                          items: farmIdsList.map((id) => DropdownMenuItem(
                                value: id,
                                child: Text(farmNamesMap[id] ?? id, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              )).toList(),
                          onChanged: (val) => setState(() => _selectedFarmId = val ?? "All Plots"),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Stage dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCropStage,
                          items: cropStages.map((stg) => DropdownMenuItem(
                                value: stg,
                                child: Text(stg, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              )).toList(),
                          onChanged: (val) => setState(() => _selectedCropStage = val ?? "All Stages"),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. THREE LARGE KPI SUMMARY CARDS
              // Card A: Total Expense
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: AppColors.shadowColor, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                      child: const Icon(Icons.money_off, color: AppColors.errorRed, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          langCode == 'kn-IN' ? "ಒಟ್ಟು ಖರ್ಚು" : "Total Expense",
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textLight),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "₹${summary.totalExpenses.toStringAsFixed(0)}",
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Card B: Total Income
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: AppColors.shadowColor, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                      child: const Icon(Icons.attach_money, color: AppColors.primaryGreen, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          langCode == 'kn-IN' ? "ಒಟ್ಟು ಆದಾಯ" : "Total Income",
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textLight),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "₹${summary.totalIncome.toStringAsFixed(0)}",
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Card C: Net Profit/Loss
              Container(
                decoration: BoxDecoration(
                  color: isProfit ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isProfit ? Colors.green.shade300 : Colors.red.shade300,
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(color: AppColors.shadowColor, blurRadius: 12, offset: Offset(0, 5)),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (isProfit)
                          const PulsingCelebrationWidget()
                        else
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.warning_amber, color: AppColors.errorRed, size: 28),
                          ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                langCode == 'kn-IN' ? "ನಿವ್ವಳ ಲಾಭ" : "Net Profit",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isProfit ? Colors.green.shade900 : Colors.red.shade900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "₹${summary.estimatedProfit.toStringAsFixed(0)}",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: isProfit ? Colors.green.shade900 : Colors.red.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: isProfit ? Colors.green.shade300 : Colors.red.shade300),
                    const SizedBox(height: 6),
                    Text(
                      isProfit
                          ? (langCode == 'kn-IN'
                              ? "ಅಭಿನಂದನೆಗಳು! ನಿಮ್ಮ ಕೃಷಿ ಲಾಭದಾಯಕವಾಗಿದೆ."
                              : "Congratulations! Your farm is making a profit.")
                          : (langCode == 'kn-IN'
                              ? "ನಿಮ್ಮ ಆದಾಯಕ್ಕಿಂತ ಖರ್ಚು ಹೆಚ್ಚಾಗಿದೆ. ವೆಚ್ಚಗಳನ್ನು ಪರಿಶೀಲಿಸಿ."
                              : "Your expenses are higher than your income. Review your spending."),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isProfit ? Colors.green.shade900 : Colors.red.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. EXPENSE BREAKDOWN (ONE DONUT CHART)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      langCode == 'kn-IN' ? "ಅತಿ ಹೆಚ್ಚು ಖರ್ಚು ಎಲ್ಲಾಗಿದೆ?" : "Where did I spend the most money?",
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 16),
                    SimpleExpenseDonutChart(categoryTotals: summary.categoryTotals),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. YEAR COMPARISON (ONE BAR CHART WITH TOGGLE)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      langCode == 'kn-IN' ? "ಕಳೆದ ವರ್ಷದ ಹೋಲಿಕೆ" : "Is this year better than last year?",
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 14),
                    // Toggle choice row
                    Center(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ["Expenses", "Income", "Profit"].map((mode) {
                            final isSelected = _yearlyComparisonMode == mode;
                            return Container(
                              margin: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(
                                  mode,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : AppColors.primaryGreen,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: AppColors.primaryGreen,
                                backgroundColor: Colors.green.shade50,
                                checkmarkColor: Colors.white,
                                onSelected: (val) {
                                  if (val) {
                                    setState(() {
                                      _yearlyComparisonMode = mode;
                                    });
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SimpleYearlyBarChart(dataPoints: activeYearlyData, barColor: activeYearlyColor),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 5. FARM INSIGHTS (3 SIMPLE AI INSIGHTS)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, color: Colors.orange, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          langCode == 'kn-IN' ? "ಪ್ರಮುಖ ಸಲಹೆಗಳು" : "Farm Insights",
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (summary.simpleInsights.isEmpty)
                      const Text(
                        "No insights computed yet.",
                        style: TextStyle(fontSize: 13, color: AppColors.textLight),
                      )
                    else
                      ...summary.simpleInsights.map((insight) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("• ", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                                Expanded(
                                  child: Text(
                                    insight,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          )),
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
}
