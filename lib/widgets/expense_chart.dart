import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../core/constants/colors.dart';

// Helper to render legends
Widget _buildLegendItem(String label, Color color) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textLight),
      ),
    ],
  );
}

// 1. Expense Category Splits (Donut Chart)
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
          child: Text("No expenses recorded.", style: TextStyle(fontSize: 14, color: AppColors.textLight)),
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
            radius: 35,
            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        );

        legend.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(category, style: const TextStyle(fontSize: 12, color: AppColors.textDark)),
                ),
                Text("₹${value.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark)),
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
          height: 140,
          child: PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 30, sections: sections)),
        ),
        const SizedBox(height: 12),
        Column(children: legend),
      ],
    );
  }
}

// 2. Monthly Expense Trend (Line Chart)
class MonthlyExpenseTrendChart extends StatelessWidget {
  final Map<String, double> monthlyTrends;

  const MonthlyExpenseTrendChart({super.key, required this.monthlyTrends});

  @override
  Widget build(BuildContext context) {
    if (monthlyTrends.isEmpty) {
      return const Center(child: Text("No trend data available.", style: TextStyle(color: AppColors.textLight)));
    }

    List<FlSpot> spots = [];
    List<String> months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    
    for (int i = 1; i <= 12; i++) {
      String key = i.toString().padLeft(2, '0');
      double val = monthlyTrends[key] ?? 0.0;
      spots.add(FlSpot(i.toDouble(), val));
    }

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  int idx = val.toInt() - 1;
                  if (idx >= 0 && idx < 12 && idx % 2 == 0) {
                    return Text(months[idx], style: const TextStyle(fontSize: 9, color: AppColors.textLight));
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primaryGreen,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: AppColors.primaryGreen.withOpacity(0.1)),
            ),
          ],
        ),
      ),
    );
  }
}

// 3. Year vs Total Expenses (Bar Chart)
class YearlyExpensesChart extends StatelessWidget {
  final Map<String, double> yearExpenses;

  const YearlyExpensesChart({super.key, required this.yearExpenses});

  @override
  Widget build(BuildContext context) {
    if (yearExpenses.isEmpty) {
      return const Center(child: Text("No yearly records found.", style: TextStyle(color: AppColors.textLight)));
    }

    List<BarChartGroupData> groups = [];
    int idx = 0;
    List<String> years = yearExpenses.keys.toList()..sort();

    for (var yr in years) {
      groups.add(
        BarChartGroupData(
          x: idx,
          barRods: [
            BarChartRodData(
              toY: yearExpenses[yr] ?? 0.0,
              color: AppColors.accentPurple,
              width: 18,
              borderRadius: BorderRadius.circular(4),
            )
          ],
        ),
      );
      idx++;
    }

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  int i = val.toInt();
                  if (i >= 0 && i < years.length) {
                    return Text(years[i], style: const TextStyle(fontSize: 10, color: AppColors.textDark, fontWeight: FontWeight.bold));
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

// 4. Year vs Yield (Bar Chart)
class YearlyYieldChart extends StatelessWidget {
  final Map<String, double> yearYields;

  const YearlyYieldChart({super.key, required this.yearYields});

  @override
  Widget build(BuildContext context) {
    if (yearYields.isEmpty) {
      return const Center(child: Text("No yield records found.", style: TextStyle(color: AppColors.textLight)));
    }

    List<BarChartGroupData> groups = [];
    int idx = 0;
    List<String> years = yearYields.keys.toList()..sort();

    for (var yr in years) {
      groups.add(
        BarChartGroupData(
          x: idx,
          barRods: [
            BarChartRodData(
              toY: yearYields[yr] ?? 0.0,
              color: AppColors.primaryGreen,
              width: 18,
              borderRadius: BorderRadius.circular(4),
            )
          ],
        ),
      );
      idx++;
    }

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  int i = val.toInt();
                  if (i >= 0 && i < years.length) {
                    return Text(years[i], style: const TextStyle(fontSize: 10, color: AppColors.textDark, fontWeight: FontWeight.bold));
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

// 5. Expense vs Yield (Scatter Plot curves)
class ExpenseVsYieldChart extends StatelessWidget {
  final List<MapEntry<double, double>> points;

  const ExpenseVsYieldChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(child: Text("No yield comparative records.", style: TextStyle(color: AppColors.textLight)));
    }

    // Sort by expense value to render clean trend curves
    final sortedPoints = List<MapEntry<double, double>>.from(points);
    sortedPoints.sort((a, b) => a.key.compareTo(b.key));

    List<FlSpot> spots = sortedPoints.map((p) => FlSpot(p.key, p.value)).toList();

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: const FlTitlesData(
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              barWidth: 0, // Turn off lines to make it a true scatter plot representation
              dotData: const FlDotData(show: true),
              color: Colors.amber.shade800,
            ),
          ],
        ),
      ),
    );
  }
}

// 6. Income vs Expenses (Grouped Bar Chart)
class IncomeVsExpensesChart extends StatelessWidget {
  final Map<String, MapEntry<double, double>> yearIncomeExpenses;

  const IncomeVsExpensesChart({super.key, required this.yearIncomeExpenses});

  @override
  Widget build(BuildContext context) {
    if (yearIncomeExpenses.isEmpty) {
      return const Center(child: Text("No transaction history.", style: TextStyle(color: AppColors.textLight)));
    }

    List<BarChartGroupData> groups = [];
    int idx = 0;
    List<String> years = yearIncomeExpenses.keys.toList()..sort();

    for (var yr in years) {
      final item = yearIncomeExpenses[yr]!;
      groups.add(
        BarChartGroupData(
          x: idx,
          barRods: [
            BarChartRodData(toY: item.key, color: AppColors.primaryGreen, width: 12, borderRadius: BorderRadius.circular(3)),
            BarChartRodData(toY: item.value, color: AppColors.errorRed, width: 12, borderRadius: BorderRadius.circular(3)),
          ],
        ),
      );
      idx++;
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem("Income", AppColors.primaryGreen),
            const SizedBox(width: 16),
            _buildLegendItem("Expenses", AppColors.errorRed),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, meta) {
                      int i = val.toInt();
                      if (i >= 0 && i < years.length) {
                        return Text(years[i], style: const TextStyle(fontSize: 10, color: AppColors.textDark, fontWeight: FontWeight.bold));
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
        ),
      ],
    );
  }
}

// 7. Monthly Profit Trend (Line Chart)
class MonthlyProfitTrendChart extends StatelessWidget {
  final Map<String, double> monthlyProfits;

  const MonthlyProfitTrendChart({super.key, required this.monthlyProfits});

  @override
  Widget build(BuildContext context) {
    if (monthlyProfits.isEmpty) {
      return const Center(child: Text("No profit stats computed.", style: TextStyle(color: AppColors.textLight)));
    }

    List<FlSpot> spots = [];
    List<String> months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    
    for (int i = 1; i <= 12; i++) {
      String key = i.toString().padLeft(2, '0');
      double val = monthlyProfits[key] ?? 0.0;
      spots.add(FlSpot(i.toDouble(), val));
    }

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  int idx = val.toInt() - 1;
                  if (idx >= 0 && idx < 12 && idx % 2 == 0) {
                    return Text(months[idx], style: const TextStyle(fontSize: 9, color: AppColors.textLight));
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blue.shade700,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.blue.shade100.withOpacity(0.2)),
            ),
          ],
        ),
      ),
    );
  }
}

// 8. Farm-wise Comparison (Multi-plot comparative Grouped Bar chart)
class FarmWiseComparisonChart extends StatelessWidget {
  final Map<String, Map<String, double>> farmComparisons;

  const FarmWiseComparisonChart({super.key, required this.farmComparisons});

  @override
  Widget build(BuildContext context) {
    if (farmComparisons.isEmpty) {
      return const Center(child: Text("No multi-plot data.", style: TextStyle(color: AppColors.textLight)));
    }

    List<BarChartGroupData> groups = [];
    int idx = 0;
    List<String> farmNames = farmComparisons.keys.toList();

    for (var name in farmNames) {
      final metrics = farmComparisons[name]!;
      groups.add(
        BarChartGroupData(
          x: idx,
          barRods: [
            BarChartRodData(toY: metrics["Expenses"] ?? 0.0, color: AppColors.errorRed, width: 8, borderRadius: BorderRadius.circular(2)),
            BarChartRodData(toY: (metrics["Yield"] ?? 0.0) * 1000, color: AppColors.primaryGreen, width: 8, borderRadius: BorderRadius.circular(2)), // scale yield for visibility
            BarChartRodData(toY: metrics["Profit"] ?? 0.0, color: Colors.blue.shade700, width: 8, borderRadius: BorderRadius.circular(2)),
          ],
        ),
      );
      idx++;
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem("Expenses", AppColors.errorRed),
            const SizedBox(width: 10),
            _buildLegendItem("Yield (Tons x1k)", AppColors.primaryGreen),
            const SizedBox(width: 10),
            _buildLegendItem("Profit", Colors.blue.shade700),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, meta) {
                      int i = val.toInt();
                      if (i >= 0 && i < farmNames.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            farmNames[i].length > 8 ? "${farmNames[i].substring(0, 7)}.." : farmNames[i],
                            style: const TextStyle(fontSize: 8, color: AppColors.textDark, fontWeight: FontWeight.bold),
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
        ),
      ],
    );
  }
}

// 9. Crop Stage Timeline (Stage-wise cost allocations)
class CropStageTimelineChart extends StatelessWidget {
  final Map<String, double> stageExpenses;

  const CropStageTimelineChart({super.key, required this.stageExpenses});

  @override
  Widget build(BuildContext context) {
    if (stageExpenses.isEmpty) {
      return const Center(child: Text("No stage cost history.", style: TextStyle(color: AppColors.textLight)));
    }

    final stages = ["Land Preparation", "Bud Stage", "Flowering", "Fruit Set", "Berry Growth", "Harvest"];
    List<Widget> barItems = [];
    double total = stageExpenses.values.fold(0.0, (sum, val) => sum + val);

    if (total == 0) {
      return const Center(child: Text("No stage costs logged yet.", style: TextStyle(color: AppColors.textLight)));
    }

    final colorsList = [
      Colors.brown.shade400,
      Colors.green.shade300,
      AppColors.primaryGreen,
      Colors.green.shade800,
      AppColors.accentPurple,
      Colors.amber.shade800
    ];

    for (int i = 0; i < stages.length; i++) {
      double cost = stageExpenses[stages[i]] ?? 0.0;
      double pct = (cost / total) * 100;
      if (cost > 0) {
        barItems.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: colorsList[i % colorsList.length], shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(stages[i], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                ),
                Text("₹${cost.toStringAsFixed(0)} (${pct.toStringAsFixed(0)}%)", style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
              ],
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Horizontal progress stack representation
        Container(
          height: 14,
          width: double.infinity,
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(7)),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: List.generate(stages.length, (i) {
              double cost = stageExpenses[stages[i]] ?? 0.0;
              if (cost == 0) return const SizedBox();
              return Expanded(
                flex: cost.toInt(),
                child: Container(color: colorsList[i % colorsList.length]),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),
        Column(children: barItems),
      ],
    );
  }
}

// 10. Bill Scanner Analytics (Pie chart of top suppliers)
class BillScannerAnalyticsChart extends StatelessWidget {
  final Map<String, double> supplierSpend;

  const BillScannerAnalyticsChart({super.key, required this.supplierSpend});

  @override
  Widget build(BuildContext context) {
    if (supplierSpend.isEmpty) {
      return const Center(child: Text("No scanned bill data.", style: TextStyle(color: AppColors.textLight)));
    }

    double total = supplierSpend.values.fold(0.0, (sum, val) => sum + val);
    if (total == 0) {
      return const Center(child: Text("No supplier stats found.", style: TextStyle(color: AppColors.textLight)));
    }

    List<PieChartSectionData> sections = [];
    int idx = 0;
    final colorOptions = [Colors.teal, Colors.orange, Colors.pink, Colors.blue, Colors.indigo];

    supplierSpend.forEach((supplier, value) {
      if (value > 0 && idx < 5) {
        sections.add(
          PieChartSectionData(
            color: colorOptions[idx % colorOptions.length],
            value: value,
            title: "${((value / total) * 100).toStringAsFixed(0)}%",
            radius: 35,
            titleStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        );
        idx++;
      }
    });

    List<Widget> listItems = [];
    int listIdx = 0;
    supplierSpend.forEach((supplier, value) {
      if (value > 0 && listIdx < 5) {
        listItems.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                Icon(Icons.store, size: 14, color: colorOptions[listIdx % colorOptions.length]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(supplier, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textDark)),
                ),
                Text("₹${value.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              ],
            ),
          ),
        );
        listIdx++;
      }
    });

    return Column(
      children: [
        SizedBox(
          height: 130,
          child: PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 25, sections: sections)),
        ),
        const SizedBox(height: 12),
        Column(children: listItems),
      ],
    );
  }
}
