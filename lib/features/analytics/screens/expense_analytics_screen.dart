import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  String _selectedFilter = "This Month"; // "Today", "This Week", "This Month", "This Year"

  @override
  Widget build(BuildContext context) {
    final langCode = Provider.of<LanguageNotifier>(context).currentLanguage;
    final firestoreService = Provider.of<FirestoreService>(context);

    final entries = firestoreService.cachedDiary
        .where((e) => e.farmId == widget.selectedFarmId)
        .toList();

    // Global summary context (always representing total today, total month, and long term trends)
    final globalSummary = AnalyticsService.generateSummary(entries, widget.selectedFarmId, langCode);

    // Calculate start dates for filtering
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    // Filter list based on choice tab selection
    final filteredEntries = entries.where((entry) {
      try {
        final entryDate = DateTime.parse(entry.date);
        if (_selectedFilter == "Today") {
          return entryDate.isAfter(startOfToday.subtract(const Duration(seconds: 1)));
        } else if (_selectedFilter == "This Week") {
          final startOfWeek = startOfToday.subtract(const Duration(days: 7));
          return entryDate.isAfter(startOfWeek.subtract(const Duration(seconds: 1)));
        } else if (_selectedFilter == "This Month") {
          final startOfMonth = DateTime(now.year, now.month, 1);
          return entryDate.isAfter(startOfMonth.subtract(const Duration(seconds: 1)));
        } else if (_selectedFilter == "This Year") {
          final startOfYear = DateTime(now.year, 1, 1);
          return entryDate.isAfter(startOfYear.subtract(const Duration(seconds: 1)));
        }
      } catch (e) {
        // Fallback for custom or empty date formats
      }
      return true;
    }).toList();

    // Summary specifically reflecting the selected tab period
    final filteredSummary = AnalyticsService.generateSummary(filteredEntries, widget.selectedFarmId, langCode);
    final double filteredTotal = filteredEntries.fold(0.0, (sum, e) => sum + e.totalExpense);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.translate('expense_analytics', langCode)),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filter Tabs Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ["Today", "This Week", "This Month", "This Year"].map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        filter,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppColors.white : AppColors.primaryGreen,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primaryGreen,
                      backgroundColor: AppColors.primaryLight,
                      checkmarkColor: AppColors.white,
                      onSelected: (val) {
                        if (val) setState(() => _selectedFilter = filter);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            // calculated Insight text panel
            AppCard(
              color: AppColors.softYellow,
              border: Border.all(color: AppColors.softYellowDark, width: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb, color: Colors.orange, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        AppTranslations.translate('insights', langCode),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.earthyBrown,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    filteredSummary.insightText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Cost Summary Cards Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildSummaryCard(
                  title: "Today Spend",
                  amount: globalSummary.todayTotal,
                  color: const Color(0xFFE8F5E9),
                  textColor: AppColors.primaryGreen,
                  icon: Icons.today,
                ),
                _buildSummaryCard(
                  title: "This Month",
                  amount: globalSummary.monthTotal,
                  color: const Color(0xFFF3E5F5),
                  textColor: AppColors.accentPurple,
                  icon: Icons.calendar_month,
                ),
                _buildSummaryCard(
                  title: "Highest Category",
                  amount: filteredSummary.highestCategoryAmount,
                  subText: filteredSummary.highestCategory,
                  color: const Color(0xFFFFFDE7),
                  textColor: Colors.amber.shade900,
                  icon: Icons.star,
                ),
                _buildSummaryCard(
                  title: "$_selectedFilter Spend",
                  amount: filteredTotal,
                  subText: "${filteredEntries.length} entries logged",
                  color: const Color(0xFFE0F2F1),
                  textColor: Colors.teal.shade800,
                  icon: Icons.wallet,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Donut split chart
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Category Spending Splits",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
                  ),
                  const SizedBox(height: 16),
                  ExpenseDonutChart(categoryTotals: filteredSummary.categoryTotals),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Bar trend chart
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Monthly Cost Projections",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
                  ),
                  const SizedBox(height: 20),
                  ExpenseBarChart(monthlyTrends: globalSummary.monthlyTrends),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Top items list
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Top Spends in Selected Period",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
                  ),
                  const SizedBox(height: 12),
                  if (filteredSummary.topSpendingItems.isEmpty)
                    const Text("No spends recorded yet.", style: TextStyle(color: AppColors.textLight, fontSize: 14))
                  else
                    ...filteredSummary.topSpendingItems.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['itemName'],
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark),
                                  ),
                                  Text(
                                    item['category'],
                                    style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                                  ),
                                  ],
                              ),
                              Text(
                                "₹${item['amount'].toStringAsFixed(0)}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.accentPurple),
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
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    String? subText,
    required Color color,
    required Color textColor,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Icon(
              icon,
              size: 24,
              color: textColor.withOpacity(0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLight),
              ),
              const SizedBox(height: 4),
              Text(
                "₹${amount.toStringAsFixed(0)}",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
              ),
              if (subText != null) ...[
                const SizedBox(height: 2),
                Text(
                  subText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.8)),
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }
}
