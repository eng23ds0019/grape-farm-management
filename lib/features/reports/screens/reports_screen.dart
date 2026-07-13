import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../core/localization/translations.dart';
import '../../../services/firestore_service.dart';
import '../../../services/analytics_service.dart';
import '../../../models/diary_entry_model.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_card.dart';

class ReportsScreen extends StatefulWidget {
  final String selectedFarmId;

  const ReportsScreen({super.key, required this.selectedFarmId});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _reportType = "Monthly"; // "Daily", "Monthly", "Yearly", "Custom Range"
  DateTimeRange? _selectedDateRange;

  @override
  Widget build(BuildContext context) {
    final langCode = Provider.of<LanguageNotifier>(context).currentLanguage;
    final firestoreService = Provider.of<FirestoreService>(context);

    final entries = firestoreService.cachedDiary
        .where((e) => e.farmId == widget.selectedFarmId)
        .toList();

    // Filter entries based on selected window
    List<DiaryEntryModel> filteredEntries = [];
    if (_reportType == "Daily") {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      filteredEntries = entries.where((e) => e.date == todayStr).toList();
    } else if (_reportType == "Monthly") {
      final thisMonthStr = DateTime.now().toIso8601String().substring(0, 7);
      filteredEntries = entries.where((e) => e.date.startsWith(thisMonthStr)).toList();
    } else if (_reportType == "Yearly") {
      final thisYearStr = DateTime.now().toIso8601String().substring(0, 4);
      filteredEntries = entries.where((e) => e.date.startsWith(thisYearStr)).toList();
    } else if (_reportType == "Custom Range" && _selectedDateRange != null) {
      filteredEntries = entries.where((e) {
        final entryDate = DateTime.tryParse(e.date);
        if (entryDate == null) return false;
        return entryDate.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
               entryDate.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    } else {
      filteredEntries = entries;
    }

    final summary = AnalyticsService.generateSummary(filteredEntries, widget.selectedFarmId, langCode);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.translate('reports', langCode)),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Farm Report Generator",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
            ),
            const SizedBox(height: 6),
            const Text(
              "Select a report scope to export your secure farm history logs.",
              style: TextStyle(fontSize: 14, color: AppColors.textLight),
            ),
            const SizedBox(height: 20),

            // Select Report Window Card
            AppCard(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ["Daily", "Monthly", "Yearly", "Custom Range"].map((type) {
                    final isSelected = _reportType == type;
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          type,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppColors.white : AppColors.primaryGreen,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.primaryGreen,
                        backgroundColor: AppColors.primaryLight,
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _reportType = type;
                              if (type == "Custom Range" && _selectedDateRange == null) {
                                _selectedDateRange = DateTimeRange(
                                  start: DateTime.now().subtract(const Duration(days: 7)),
                                  end: DateTime.now(),
                                );
                              }
                            });
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            
            // Custom Range Picker Panel
            if (_reportType == "Custom Range") ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2030),
                    initialDateRange: _selectedDateRange,
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: AppColors.primaryGreen,
                            onPrimary: AppColors.white,
                            surface: AppColors.white,
                            onSurface: AppColors.textDark,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDateRange = picked;
                    });
                  }
                },
                child: AppCard(
                  color: AppColors.primaryLight,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.date_range, color: AppColors.primaryGreen),
                      Text(
                        _selectedDateRange == null 
                            ? "Tap to select date range" 
                            : "${_selectedDateRange!.start.toIso8601String().substring(0,10)} to ${_selectedDateRange!.end.toIso8601String().substring(0,10)}",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 14),
                      ),
                      const Icon(Icons.arrow_drop_down, color: AppColors.primaryGreen),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Report Preview Sheet
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "$_reportType Report Summary",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "PREVIEW ONLY",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 14),
                  
                  // Meta Data
                  _buildPreviewRow("Farm Plot", "Basveshwar Plot 1"),
                  _buildPreviewRow("Crop Target", "Grapes"),
                  _buildPreviewRow("Acres Size", "3.5 Acres"),
                  _buildPreviewRow("Total Diary Entries", filteredEntries.length.toString()),
                  const Divider(height: 20),

                  // Aggregation sums
                  _buildPreviewRow("Spraying Costs", "₹${summary.totalPesticide.toStringAsFixed(0)}"),
                  _buildPreviewRow("Fertilizer Costs", "₹${summary.totalFertilizer.toStringAsFixed(0)}"),
                  _buildPreviewRow("Labour Costs", "₹${summary.totalLabour.toStringAsFixed(0)}"),
                  const Divider(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total Cost Summary",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark),
                      ),
                      Text(
                        "₹${(_reportType == 'Daily' ? summary.todayTotal : (_reportType == 'Monthly' ? summary.monthTotal : (_reportType == 'Yearly' ? summary.yearTotal : summary.yearTotal))).toStringAsFixed(0)}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.accentPurple),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            AppButton(
              text: "Export & Share Report",
              icon: Icons.share,
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/share_report',
                  arguments: {
                    'farmId': widget.selectedFarmId,
                    'type': _reportType,
                    'startDate': _selectedDateRange?.start.toIso8601String().substring(0, 10),
                    'endDate': _selectedDateRange?.end.toIso8601String().substring(0, 10),
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textLight)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        ],
      ),
    );
  }
}
