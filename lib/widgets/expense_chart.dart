import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../core/constants/colors.dart';

class ExpenseDonutChart extends StatelessWidget {
  final Map<String, double> categoryTotals;

  const ExpenseDonutChart({super.key, required this.categoryTotals});

  List<Color> get _colors => [
        AppColors.primaryGreen,
        AppColors.accentPurple,
        Colors.orange.shade700,
        Colors.blue.shade700,
        Colors.teal.shade600,
        Colors.red.shade600,
        Colors.indigo.shade600,
        Colors.amber.shade700,
        Colors.grey.shade600
      ];

  @override
  Widget build(BuildContext context) {
    double total = categoryTotals.values.fold(0.0, (sum, val) => sum + val);

    if (total == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            "No expense recorded yet to show chart.",
            style: TextStyle(fontSize: 15, color: AppColors.textLight),
          ),
        ),
      );
    }

    int colorIdx = 0;
    List<PieChartSectionData> sections = [];
    List<Widget> legend = [];

    categoryTotals.forEach((category, value) {
      if (value > 0) {
        final Color col = _colors[colorIdx % _colors.length];
        final double pct = (value / total) * 100;
        
        sections.add(
          PieChartSectionData(
            color: col,
            value: value,
            title: "${pct.toStringAsFixed(0)}%",
            radius: 40,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );

        legend.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: col,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Text(
                  "₹${value.toStringAsFixed(0)}",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        );
        
        colorIdx++;
      }
    });

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 40,
              sections: sections,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Column(children: legend),
      ],
    );
  }
}

class ExpenseBarChart extends StatelessWidget {
  final Map<String, double> monthlyTrends;
  static const double targetBudget = 25000.0; // Dynamic baseline monthly budget for Grape plot

  const ExpenseBarChart({super.key, required this.monthlyTrends});

  @override
  Widget build(BuildContext context) {
    if (monthlyTrends.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            "No historical trends logged.",
            style: TextStyle(fontSize: 15, color: AppColors.textLight),
          ),
        ),
      );
    }

    List<BarChartGroupData> barGroups = [];
    int xIdx = 0;
    List<String> labels = [];

    monthlyTrends.forEach((monthStr, value) {
      labels.add(monthStr);
      final double spent = value;
      
      barGroups.add(
        BarChartGroupData(
          x: xIdx,
          barsSpace: 4,
          barRods: [
            // Rod 1: Target Budget
            BarChartRodData(
              toY: targetBudget,
              color: AppColors.accentPurple.withValues(alpha: 0.5),
              width: 10,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
            // Rod 2: Actual Spent (Green if safe, Red if over budget)
            BarChartRodData(
              toY: spent,
              color: spent <= targetBudget ? AppColors.primaryGreen : Colors.redAccent,
              width: 10,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            )
          ],
        ),
      );
      xIdx++;
    });

    return Column(
      children: [
        // Legend for Budget vs Spent
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem("Target Budget (₹25k)", AppColors.accentPurple.withValues(alpha: 0.5)),
              const SizedBox(width: 16),
              _buildLegendItem("Actual Spent", AppColors.primaryGreen),
              const SizedBox(width: 16),
              _buildLegendItem("Over Budget", Colors.redAccent),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: targetBudget * 1.3 > monthlyTrends.values.fold(0.0, (max, val) => val > max ? val : max) * 1.2
                  ? targetBudget * 1.3
                  : monthlyTrends.values.fold(0.0, (max, val) => val > max ? val : max) * 1.3,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.earthyBrown,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final isBudget = rodIndex == 0;
                    final amt = rod.toY;
                    final spent = group.barRods[1].toY;
                    final savings = targetBudget - spent;
                    
                    if (isBudget) {
                      return BarTooltipItem(
                        "Budget: ₹${amt.toStringAsFixed(0)}",
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      );
                    } else {
                      final savingsText = savings > 0 
                          ? "\nSaved: ₹${savings.toStringAsFixed(0)}" 
                          : "\nOverspent: ₹${(-savings).toStringAsFixed(0)}";
                      return BarTooltipItem(
                        "Spent: ₹${amt.toStringAsFixed(0)}$savingsText",
                        TextStyle(
                          color: savings >= 0 ? AppColors.white : Colors.red.shade100, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 12
                        ),
                      );
                    }
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      int idx = value.toInt();
                      if (idx >= 0 && idx < labels.length) {
                        String label = labels[idx];
                        if (label.length >= 7) {
                          String m = label.substring(5, 7);
                          switch (m) {
                            case '01': label = "Jan"; break;
                            case '02': label = "Feb"; break;
                            case '03': label = "Mar"; break;
                            case '04': label = "Apr"; break;
                            case '05': label = "May"; break;
                            case '06': label = "Jun"; break;
                            case '07': label = "Jul"; break;
                            case '08': label = "Aug"; break;
                            case '09': label = "Sep"; break;
                            case '10': label = "Oct"; break;
                            case '11': label = "Nov"; break;
                            case '12': label = "Dec"; break;
                          }
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: barGroups,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textLight),
        ),
      ],
    );
  }
}
