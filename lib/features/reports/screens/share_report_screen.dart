import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/colors.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../models/diary_entry_model.dart';
import '../../../services/firestore_service.dart';
import '../../../services/analytics_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_card.dart';

class ShareReportScreen extends StatefulWidget {
  final Map<String, dynamic> args;

  const ShareReportScreen({super.key, required this.args});

  @override
  State<ShareReportScreen> createState() => _ShareReportScreenState();
}

class _ShareReportScreenState extends State<ShareReportScreen> {
  bool _hidePhone = false;
  bool _hideLocation = false;
  bool _hideExpenses = false;
  bool _shareAnonymously = false;
  bool _isSharing = false;

  String _csvFilePath = "";
  bool _exportSuccess = false;

  Future<void> _generateAndSaveCSV(List<DiaryEntryModel> entries, String type) async {
    try {
      final buffer = StringBuffer();
      // CSV Headers
      buffer.writeln("Date,Crop Stage,Work Type,Input Type,Cleaned Note,Total Expense (₹),Expenses Detailed");
      
      for (var entry in entries) {
        final note = (entry.cleanedText.isNotEmpty ? entry.cleanedText : entry.originalText).replaceAll('"', '""');
        final expStr = entry.expenses.map((e) => "${e.category}:${e.itemName}:₹${e.totalAmount}").join("; ").replaceAll('"', '""');
        buffer.writeln('"${entry.date}","${entry.cropStage}","${entry.workType}","${entry.inputType}","${note}",${entry.totalExpense},"${expStr}"');
      }

      final directory = await getApplicationDocumentsDirectory();
      final fileName = "Draksha_Farm_Report_${type}_${DateTime.now().millisecondsSinceEpoch}.csv";
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(buffer.toString());

      setState(() {
        _csvFilePath = file.path;
        _exportSuccess = true;
      });
    } catch (e) {
      setState(() {
        _exportSuccess = false;
      });
    }
  }

  String _buildWhatsAppSummary(
    String farmerName,
    String phone,
    String village,
    String type,
    double totalPesticide,
    double totalFertilizer,
    double totalLabour,
    double totalExpense,
    String langCode,
    List<DiaryEntryModel> entries,
  ) {
    final displayFarmer = _shareAnonymously ? "[ANONYMOUS]" : farmerName;
    final displayPhone = _hidePhone ? "[HIDDEN]" : phone;
    final displayVillage = _hideLocation ? "[HIDDEN]" : village;
    final displayPesticide = _hideExpenses ? "[HIDDEN]" : "₹${totalPesticide.toStringAsFixed(0)}";
    final displayFertilizer = _hideExpenses ? "[HIDDEN]" : "₹${totalFertilizer.toStringAsFixed(0)}";
    final displayLabour = _hideExpenses ? "[HIDDEN]" : "₹${totalLabour.toStringAsFixed(0)}";
    final displayTotal = _hideExpenses ? "[HIDDEN]" : "₹${totalExpense.toStringAsFixed(0)}";

    // Day by Day logs compilation
    final StringBuffer logsBuffer = StringBuffer();
    if (entries.isNotEmpty) {
      logsBuffer.writeln("\n📅 *Day-by-Day Detailed Logs:*");
      for (var entry in entries) {
        logsBuffer.writeln("• ${entry.date}: ${entry.workType} (${entry.cropStage})");
        if (entry.cleanedText.isNotEmpty) {
          logsBuffer.writeln("  _Note: ${entry.cleanedText}_");
        }
        if (entry.expenses.isNotEmpty && !_hideExpenses) {
          for (var e in entry.expenses) {
            logsBuffer.writeln("  - ${e.itemName}: ₹${e.totalAmount.toStringAsFixed(0)}");
          }
        }
      }
    }

    if (langCode == 'kn-IN') {
      return "🍀 *ದ್ರಾಕ್ಷಾ ಕೃಷಿ ವರದಿ (Draksha Farm Report)* 🍀\n"
          "----------------------------------\n"
          "👤 ರೈತರು: $displayFarmer\n"
          "📞 ಮೊಬೈಲ್: $displayPhone\n"
          "📍 ಸ್ಥಳ: $displayVillage\n"
          "📅 ವರದಿ ಪ್ರಕಾರ: $type\n"
          "🚜 ತೋಟ: Basveshwar Plot 1\n\n"
          "📊 *ಖರ್ಚು ವೆಚ್ಚಗಳ ವಿವರ:*\n"
          "• ಔಷಧಿ ಸಿಂಪಡಣೆ ವೆಚ್ಚ: $displayPesticide\n"
          "• ಗೊಬ್ಬರದ ವೆಚ್ಚ: $displayFertilizer\n"
          "• ಕೂಲಿ ವೆಚ್ಚ: $displayLabour\n"
          "----------------------------------\n"
          "💰 *ಒಟ್ಟು ವೆಚ್ಚ: $displayTotal*\n"
          "${logsBuffer.toString()}"
          "----------------------------------\n"
          "_ಸೌದಿ ಫಾರ್ಮಿಂಗ್ ಡೈರಿ ಅಪ್ಲಿಕೇಶನ್ ಮೂಲಕ ಹಂಚಿಕೊಳ್ಳಲಾಗಿದೆ_";
    } else if (langCode == 'hi-IN') {
      return "🍀 *द्राक्षा कृषि रिपोर्ट (Draksha Farm Report)* 🍀\n"
          "----------------------------------\n"
          "👤 किसान: $displayFarmer\n"
          "📞 मोबाइल: $displayPhone\n"
          "📍 स्थान: $displayVillage\n"
          "📅 रिपोर्ट का प्रकार: $type\n"
          "🚜 प्लाट का नाम: Basveshwar Plot 1\n\n"
          "📊 *खर्च का विवरण:*\n"
          "• कीटनाशक खर्च: $displayPesticide\n"
          "• खाद खर्च: $displayFertilizer\n"
          "• मजदूरी खर्च: $displayLabour\n"
          "----------------------------------\n"
          "💰 *कुल खर्च: $displayTotal*\n"
          "${logsBuffer.toString()}"
          "----------------------------------\n"
          "_सौदी फार्मिंग डायरी ऐप द्वारा साझा किया गया_";
    } else {
      return "🍀 *Draksha Farm Report* 🍀\n"
          "----------------------------------\n"
          "👤 Farmer: $displayFarmer\n"
          "📞 Contact: $displayPhone\n"
          "📍 Location: $displayVillage\n"
          "📅 Report Scope: $type\n"
          "🚜 Plot Name: Basveshwar Plot 1\n\n"
          "📊 *Expense Breakdown:*\n"
          "• Pesticides: $displayPesticide\n"
          "• Fertilizers: $displayFertilizer\n"
          "• Labour: $displayLabour\n"
          "----------------------------------\n"
          "💰 *Total Expense: $displayTotal*\n"
          "${logsBuffer.toString()}"
          "----------------------------------\n"
          "_Shared via Soudi Farming Diary App_";
    }
  }

  void _triggerShare(
    String langCode,
    List<DiaryEntryModel> entries,
    String farmerName,
    String phone,
    String village,
    String type,
    AnalyticsSummary summary,
  ) async {
    setState(() {
      _isSharing = true;
    });

    // 1. Generate and write physical CSV file
    await _generateAndSaveCSV(entries, type);

    // 2. Generate WhatsApp summary with day-by-day logs
    final totalExp = type == 'Daily' ? summary.todayTotal : (type == 'Monthly' ? summary.monthTotal : summary.yearTotal);
    final summaryText = _buildWhatsAppSummary(
      farmerName,
      phone,
      village,
      type,
      summary.totalPesticide,
      summary.totalFertilizer,
      summary.totalLabour,
      totalExp,
      langCode,
      entries,
    );

    // Copy to clipboard as a backup
    await Clipboard.setData(ClipboardData(text: summaryText));

    setState(() {
      _isSharing = false;
    });

    if (!mounted) return;

    // Trigger direct native share sheet using share_plus
    if (_exportSuccess && _csvFilePath.isNotEmpty) {
      try {
        final xFile = XFile(_csvFilePath);
        await Share.shareXFiles(
          [xFile],
          text: summaryText,
          subject: type == 'Custom Range' ? "Custom Grape Farm Report" : "$type Grape Farm Report",
        );
      } catch (e) {
        await Share.share(summaryText);
      }
    } else {
      await Share.share(summaryText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Provider.of<LanguageNotifier>(context).currentLanguage;
    final firestoreService = Provider.of<FirestoreService>(context);

    final farmerName = firestoreService.cachedFarmer?.name ?? "Farmer";
    final phone = firestoreService.cachedFarmer?.phone ?? "";
    final village = firestoreService.cachedFarmer?.village ?? "";

    final String farmId = widget.args['farmId'] ?? "plot_1";
    final String type = widget.args['type'] ?? "Monthly";
    final String? startDate = widget.args['startDate'];
    final String? endDate = widget.args['endDate'];

    final entries = firestoreService.cachedDiary
        .where((e) => e.farmId == farmId)
        .toList();

    // Filter entries based on range
    List<DiaryEntryModel> filteredEntries = [];
    if (type == "Daily") {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      filteredEntries = entries.where((e) => e.date == todayStr).toList();
    } else if (type == "Monthly") {
      final thisMonthStr = DateTime.now().toIso8601String().substring(0, 7);
      filteredEntries = entries.where((e) => e.date.startsWith(thisMonthStr)).toList();
    } else if (type == "Yearly") {
      final thisYearStr = DateTime.now().toIso8601String().substring(0, 4);
      filteredEntries = entries.where((e) => e.date.startsWith(thisYearStr)).toList();
    } else if (type == "Custom Range" && startDate != null && endDate != null) {
      final s = DateTime.parse(startDate);
      final e = DateTime.parse(endDate);
      filteredEntries = entries.where((entry) {
        final d = DateTime.tryParse(entry.date);
        if (d == null) return false;
        return d.isAfter(s.subtract(const Duration(days: 1))) &&
               d.isBefore(e.add(const Duration(days: 1)));
      }).toList();
    } else {
      filteredEntries = entries;
    }

    final summary = AnalyticsService.generateSummary(filteredEntries, farmId, langCode);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Share Report"),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Granular Privacy Filters",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
              ),
              const SizedBox(height: 6),
              const Text(
                "Filter sensitive fields to control what gets shared with agronomists, advisors, or researchers.",
                style: TextStyle(fontSize: 14, color: AppColors.textLight),
              ),
              const SizedBox(height: 20),

              // Toggles Card
              AppCard(
                child: Column(
                  children: [
                    // Anonymize Entirely
                    SwitchListTile(
                      value: _shareAnonymously,
                      activeThumbColor: AppColors.primaryGreen,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        "Share Entirely Anonymously",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark),
                      ),
                      subtitle: const Text("Completely strips your name, phone number, and location from the record"),
                      onChanged: (val) {
                        setState(() {
                          _shareAnonymously = val;
                          if (val) {
                            _hidePhone = true;
                            _hideLocation = true;
                          }
                        });
                      },
                    ),
                    const Divider(),

                    // Hide Phone Number
                    SwitchListTile(
                      value: _hidePhone,
                      activeThumbColor: AppColors.primaryGreen,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        "Hide Phone Number",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark),
                      ),
                      onChanged: _shareAnonymously
                          ? null
                          : (val) => setState(() => _hidePhone = val),
                    ),
                    const Divider(),

                    // Hide Location
                    SwitchListTile(
                      value: _hideLocation,
                      activeThumbColor: AppColors.primaryGreen,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        "Hide Village / Plot Location",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark),
                      ),
                      onChanged: _shareAnonymously
                          ? null
                          : (val) => setState(() => _hideLocation = val),
                    ),
                    const Divider(),

                    // Hide Expenses
                    SwitchListTile(
                      value: _hideExpenses,
                      activeThumbColor: AppColors.primaryGreen,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        "Hide Expense Cost Totals",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark),
                      ),
                      onChanged: (val) => setState(() => _hideExpenses = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Resulting Preview Card
              AppCard(
                color: AppColors.primaryLight.withOpacity(0.4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Data Sharing Package Summary",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryGreen),
                    ),
                    const SizedBox(height: 8),
                    _buildMetaText("Farmer Owner", _shareAnonymously ? "[ANONYMOUS]" : farmerName),
                    _buildMetaText("Phone Contact", _hidePhone ? "[HIDDEN]" : phone),
                    _buildMetaText("Village Location", _hideLocation ? "[HIDDEN]" : village),
                    _buildMetaText("Financial Values", _hideExpenses ? "[HIDDEN]" : "Visible"),
                  ],
                ),
              ),

              const Spacer(),

              AppButton(
                text: "Export & Share Report",
                icon: Icons.send,
                isLoading: _isSharing,
                onPressed: () => _triggerShare(
                  langCode,
                  filteredEntries,
                  farmerName,
                  phone,
                  village,
                  type,
                  summary,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaText(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: AppColors.textDark),
          children: [
            TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(
              text: val,
              style: TextStyle(
                color: val.startsWith('[') ? AppColors.accentPurple : AppColors.textDark,
                fontWeight: val.startsWith('[') ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
