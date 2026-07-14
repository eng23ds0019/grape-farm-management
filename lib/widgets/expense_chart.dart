import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../core/constants/colors.dart';

// 1. Simple Donut Chart for Expense Breakdown
class SimpleExpenseDonutChart extends StatelessWidget {
  final Map<String, double> categoryTotals;

  const SimpleExpenseDonutChart({super.key, required this.categoryTotals});

  List<Color> get _colors => [
        const Color(0xFF2E7D32), // Fertilizer (Forest green)
        const Color(0xFF6A1B9A), // Labour (Purple)
        const Color(0xFFC62828), // Pesticides (Crimson)
        const Color(0xFF0277BD), // Irrigation (Blue)
        const Color(0xFFEF6C00), // Transport (Orange)
        const Color(0xFF4E342E), // Others (Earthy brown)
      ];

  @override
  Widget build(BuildContext context) {
    double total = categoryTotals.values.fold(0.0, (sum, val) => sum + val);

    if (total == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            "No expenses recorded yet.",
            style: TextStyle(fontSize: 14, color: AppColors.textLight, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    int colorIdx = 0;
    List<PieChartSectionData> sections = [];
    List<Widget> legend = [];

    // Ordered categories to match layout exactly
    final order = ["Fertilizer", "Labour", "Pesticides", "Irrigation", "Transport", "Others"];

    for (var cat in order) {
      double value = categoryTotals[cat] ?? 0.0;
      if (value > 0) {
        final Color col = _colors[colorIdx % _colors.length];
        final double pct = (value / total) * 100;

        sections.add(
          PieChartSectionData(
            color: col,
            value: value,
            title: "${pct.toStringAsFixed(0)}%",
            radius: 40,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        );

        legend.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cat,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                  ),
                ),
                Text(
                  "₹${value.toStringAsFixed(0)}",
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
              ],
            ),
          ),
        );
        colorIdx++;
      }
    }

    if (sections.isEmpty) {
      return const Center(child: Text("No data matching categories.", style: TextStyle(color: AppColors.textLight)));
    }

    return Column(
      children: [
        SizedBox(
          height: 160,
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

// 2. Simple Yearly Bar Chart (Comparison of years)
class SimpleYearlyBarChart extends StatelessWidget {
  final Map<String, double> dataPoints;
  final Color barColor;

  const SimpleYearlyBarChart({super.key, required this.dataPoints, required this.barColor});

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            "No year history found.",
            style: TextStyle(fontSize: 14, color: AppColors.textLight, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    List<BarChartGroupData> groups = [];
    int idx = 0;
    List<String> years = dataPoints.keys.toList()..sort();

    for (var yr in years) {
      groups.add(
        BarChartGroupData(
          x: idx,
          barRods: [
            BarChartRodData(
              toY: dataPoints[yr] ?? 0.0,
              color: barColor,
              width: 24,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            )
          ],
        ),
      );
      idx++;
    }

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  int i = val.toInt();
                  if (i >= 0 && i < years.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        years[i],
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: groups,
        ),
      ),
    );
  }
}
