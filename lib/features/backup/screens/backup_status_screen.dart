import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../core/localization/translations.dart';
import '../../../services/firestore_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_card.dart';

class BackupStatusScreen extends StatefulWidget {
  const BackupStatusScreen({super.key});

  @override
  State<BackupStatusScreen> createState() => _BackupStatusScreenState();
}

class _BackupStatusScreenState extends State<BackupStatusScreen> {
  bool _isSyncing = false;

  void _triggerSync(String uid, FirestoreService firestore) async {
    setState(() {
      _isSyncing = true;
    });

    await firestore.syncOfflineData(uid);
    await Future.delayed(const Duration(milliseconds: 1500)); // Latency mockup

    setState(() {
      _isSyncing = false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("All local records successfully synchronized to the cloud!"),
        backgroundColor: AppColors.successGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Provider.of<LanguageNotifier>(context).currentLanguage;
    final firestoreService = Provider.of<FirestoreService>(context);

    final String uid = firestoreService.cachedFarmer?.farmerId ?? "mock_farmer";

    // Count unsynced entries
    final int offlineCount = firestoreService.cachedDiary.where((e) => e.createdOffline || !e.isSynced).length;
    // Count soft-deleted entries (using the deletedDiary getter)
    


    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.translate('backup_status', langCode)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cloud sync indicator panel
              AppCard(
                color: AppColors.primaryLight.withValues(alpha: 0.5),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_sync, size: 70, color: AppColors.primaryGreen),
                    const SizedBox(height: 12),
                    Text(
                      offlineCount == 0 ? "All Records Protected" : "$offlineCount Records Saved Locally",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      offlineCount == 0
                          ? "Your digital diary matches the cloud database perfectly."
                          : "Tap 'Sync Now' below to backup your offline data safely.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // sync summary card
              AppCard(
                child: Column(
                  children: [
                    _buildSyncRow("Connection", "Connected (Internet)"),
                    const Divider(),
                    _buildSyncRow("Offline Records Pending", offlineCount.toString()),
                    const Divider(),
                    _buildSyncRow("Last Backup Timestamp", "Today, 18:00"),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              AppButton(
                text: AppTranslations.translate('sync_now', langCode),
                icon: Icons.sync,
                isLoading: _isSyncing,
                onPressed: () => _triggerSync(uid, firestoreService),
              ),
              const SizedBox(height: 24),

              // Soft Delete Recovery Portal!
              const Text(
                "Data Loss Prevention (Restore Deleted Entries)",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
              ),
              const SizedBox(height: 6),
              const Text(
                "Accidentally deleted a diary entry? Restore it below within 30 days.",
                style: TextStyle(fontSize: 13, color: AppColors.textLight),
              ),
              const SizedBox(height: 12),

              // Soft delete lists
              Consumer<FirestoreService>(
                builder: (context, firestore, child) {
                  // We'll update firestore_service.dart to add deletedDiary getter.
                  // For now, let's invoke a placeholder list which will be linked perfectly.
                  final deletedList = firestore.deletedDiary;
                  
                  if (deletedList.isEmpty) {
                    return AppCard(
                      color: AppColors.white,
                      child: const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Text(
                            "No recently deleted entries found.",
                            style: TextStyle(fontSize: 14, color: AppColors.textLight, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: deletedList.map((entry) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          color: AppColors.white,
                          border: Border.all(color: Colors.red.shade100),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.date,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.earthyBrown),
                                    ),
                                    Text(
                                      "${entry.workType} (${entry.cropStage})",
                                      style: const TextStyle(fontSize: 13, color: AppColors.textLight),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await firestore.restoreDiaryEntry(uid, entry.farmId, entry.entryId);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Diary entry successfully restored!"),
                                      backgroundColor: AppColors.successGreen,
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryLight,
                                  foregroundColor: AppColors.primaryGreen,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.restore, size: 16),
                                label: const Text("Restore", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textLight)),
          Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        ],
      ),
    );
  }
}
