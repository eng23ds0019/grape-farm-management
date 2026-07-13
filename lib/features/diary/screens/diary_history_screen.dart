import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/constants.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../core/localization/translations.dart';
import '../../../services/firestore_service.dart';
import '../../../widgets/diary_card.dart';

class DiaryHistoryScreen extends StatefulWidget {
  final String selectedFarmId;

  const DiaryHistoryScreen({super.key, required this.selectedFarmId});

  @override
  State<DiaryHistoryScreen> createState() => _DiaryHistoryScreenState();
}

class _DiaryHistoryScreenState extends State<DiaryHistoryScreen> {
  String _searchQuery = "";
  String _selectedStage = "All";
  String _selectedWorkType = "All";

  @override
  Widget build(BuildContext context) {
    final langCode = Provider.of<LanguageNotifier>(context).currentLanguage;
    final firestoreService = Provider.of<FirestoreService>(context);

    // Filter diary entries
    final allEntries = firestoreService.cachedDiary
        .where((e) => e.farmId == widget.selectedFarmId)
        .toList();

    // Apply filters
    final filteredEntries = allEntries.where((entry) {
      final matchesSearch = entry.cleanedText.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          entry.originalText.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          entry.cropStage.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          entry.workType.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStage = _selectedStage == "All" || entry.cropStage == _selectedStage;
      final matchesWorkType = _selectedWorkType == "All" || entry.workType == _selectedWorkType;

      return matchesSearch && matchesStage && matchesWorkType;
    }).toList();

    // Sort descending by date
    filteredEntries.sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.translate('view_farm_history', langCode)),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Filter Panel & Search bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            color: AppColors.white,
            child: Column(
              children: [
                // Search Field
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: "Search notes, spraying, crops...",
                    prefixIcon: const Icon(Icons.search, color: AppColors.primaryGreen),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    fillColor: AppColors.warmCream.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 10),

                // Drops Row: Stage Filter & Work Type Filter
                Row(
                  children: [
                    // Stage Filter
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedStage,
                          isExpanded: true,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.filter_list, size: 16, color: AppColors.primaryGreen),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedStage = val);
                          },
                          items: ["All", ...AppConstants.cropStages].map((s) {
                            return DropdownMenuItem(value: s, child: Text(s));
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Work Type Filter
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedWorkType,
                          isExpanded: true,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.filter_list, size: 16, color: AppColors.primaryGreen),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedWorkType = val);
                          },
                          items: ["All", ...AppConstants.workTypes].map((w) {
                            return DropdownMenuItem(value: w, child: Text(w));
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Entries List
          Expanded(
            child: filteredEntries.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.menu_book, size: 64, color: AppColors.textLight.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text(
                            AppTranslations.translate('no_entries', langCode),
                            style: const TextStyle(fontSize: 16, color: AppColors.textLight, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: filteredEntries.length,
                    itemBuilder: (context, index) {
                      final entry = filteredEntries[index];
                      return DiaryCard(
                        entry: entry,
                        languageCode: langCode,
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/diary_detail',
                            arguments: entry,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
        child: const Icon(Icons.add, size: 28),
        onPressed: () {
          Navigator.pushNamed(context, '/add_diary', arguments: widget.selectedFarmId);
        },
      ),
    );
  }
}
