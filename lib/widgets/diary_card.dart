import 'package:flutter/material.dart';
import '../models/diary_entry_model.dart';
import '../core/constants/colors.dart';
import '../core/utils/date_formatter.dart';
import 'app_card.dart';

class DiaryCard extends StatelessWidget {
  final DiaryEntryModel entry;
  final String languageCode;
  final VoidCallback onTap;

  const DiaryCard({
    super.key,
    required this.entry,
    required this.languageCode,
    required this.onTap,
  });

  IconData _getWorkTypeIcon(String workType) {
    switch (workType) {
      case "Spraying":
        return Icons.opacity;
      case "Fertilizer":
        return Icons.grass;
      case "Irrigation":
        return Icons.water_drop;
      case "Labour work":
        return Icons.people;
      case "Harvesting":
        return Icons.agriculture;
      case "Drying grapes":
        return Icons.wb_sunny;
      case "Packing":
        return Icons.inventory_2;
      case "Selling":
        return Icons.shopping_basket;
      default:
        return Icons.assignment;
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendlyDate = DateFormatter.formatFarmerFriendly(entry.date, languageCode);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Date & Total Expense Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  friendlyDate,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.earthyBrown,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: entry.totalExpense > 0 
                        ? AppColors.accentPurple.withValues(alpha: 0.1) 
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    entry.totalExpense > 0 
                        ? "₹${entry.totalExpense.toStringAsFixed(0)}" 
                        : "No Expense",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: entry.totalExpense > 0 
                          ? AppColors.accentPurple 
                          : AppColors.textLight,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Middle Row: Crop Stage & Work Type Tags
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Work Type Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getWorkTypeIcon(entry.workType),
                        size: 16,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        entry.workType,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),

                // Crop Stage Tag
                if (entry.cropStage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200, width: 0.8),
                    ),
                    child: Text(
                      entry.cropStage,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Bottom Row: Note Summary
            if (entry.cleanedText.isNotEmpty || entry.originalText.isNotEmpty) ...[
              Text(
                entry.cleanedText.isNotEmpty ? entry.cleanedText : entry.originalText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Indicators row (Voice badge, Image badge, Sync status)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (entry.voiceUrl.isNotEmpty || entry.inputType == "voice") ...[
                      const Icon(Icons.mic, size: 18, color: AppColors.primaryGreen),
                      const SizedBox(width: 4),
                      Text(
                        "Voice Note",
                        style: TextStyle(fontSize: 12, color: AppColors.primaryGreen.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 14),
                    ],
                    if (entry.photos.isNotEmpty) ...[
                      const Icon(Icons.photo, size: 18, color: AppColors.accentPurple),
                      const SizedBox(width: 4),
                      Text(
                        "${entry.photos.length} Photo(s)",
                        style: TextStyle(fontSize: 12, color: AppColors.accentPurple.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
                Icon(
                  entry.isSynced ? Icons.cloud_done : Icons.cloud_off,
                  size: 18,
                  color: entry.isSynced ? AppColors.successGreen : Colors.orange,
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
