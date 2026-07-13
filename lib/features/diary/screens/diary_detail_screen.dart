import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../core/localization/translations.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../services/firestore_service.dart';
import '../../../services/translation_service.dart';
import '../../../models/diary_entry_model.dart';
import '../../../widgets/app_card.dart';

class DiaryDetailScreen extends StatefulWidget {
  final DiaryEntryModel entry;

  const DiaryDetailScreen({super.key, required this.entry});

  @override
  State<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends State<DiaryDetailScreen> {
  bool _isPlaying = false;
  double _audioProgress = 0.0;
  Timer? _audioTimer;
  int _playDurationSeconds = 0;
  final int _totalDurationSeconds = 24; // Mock voice note duration

  bool _isTranslating = false;
  String? _translatedText;
  bool _showTranslation = false;

  @override
  void dispose() {
    _audioTimer?.cancel();
    super.dispose();
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _audioTimer?.cancel();
      setState(() {
        _isPlaying = false;
      });
    } else {
      setState(() {
        _isPlaying = true;
      });
      _audioTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_audioProgress >= 1.0) {
            _audioProgress = 0.0;
            _playDurationSeconds = 0;
            _isPlaying = false;
            _audioTimer?.cancel();
          } else {
            _audioProgress += 0.02; // Increment progress
            _playDurationSeconds = (_audioProgress * _totalDurationSeconds).toInt();
          }
        });
      });
    }
  }


  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}";
  }

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
    final langCode = Provider.of<LanguageNotifier>(context).currentLanguage;
    final firestoreService = Provider.of<FirestoreService>(context);
    final entry = widget.entry;

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: Text(AppTranslations.translate('diary_entry', langCode)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note, size: 28),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/add_diary',
                arguments: {
                  'farmId': entry.farmId,
                  'editEntry': entry,
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 26),
            onPressed: () => _confirmDelete(context, firestoreService, entry.farmId, entry),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderCard(entry),
            const SizedBox(height: 16),
            if (entry.inputType == "voice" || entry.voiceUrl.isNotEmpty) ...[
              _buildAudioPlayerCard(),
              const SizedBox(height: 16),
            ],
            if (entry.photos.isNotEmpty) ...[
              _buildPhotosSection(entry),
              const SizedBox(height: 16),
            ],
            _buildNotesCard(entry, langCode),
            const SizedBox(height: 16),
            _buildExpensesSection(entry, langCode),
            const SizedBox(height: 16),
            _buildQualityCard(entry, langCode),
            if (entry.editHistory.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildEditHistoryCard(entry),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(DiaryEntryModel entry) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormatter.formatFarmerFriendly(entry.date, entry.languageCode),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.earthyBrown,
                ),
              ),
              Icon(
                entry.isSynced ? Icons.cloud_done : Icons.cloud_off,
                color: entry.isSynced ? AppColors.successGreen : Colors.orange,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(_getWorkTypeIcon(entry.workType), color: AppColors.primaryGreen, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      entry.workType,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (entry.cropStage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Text(
                    entry.cropStage,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Input Platform:",
                style: TextStyle(fontSize: 13, color: AppColors.textLight),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.inputType.toUpperCase(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAudioPlayerCard() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      color: AppColors.primaryLight.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.audiotrack, color: AppColors.accentPurple),
              SizedBox(width: 8),
              Text(
                "Original Voice Recording",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: _togglePlayback,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: AppColors.accentPurple,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: AppColors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    Slider(
                      value: _audioProgress,
                      activeColor: AppColors.accentPurple,
                      thumbColor: AppColors.accentPurple,
                      onChanged: (val) {
                        setState(() {
                          _audioProgress = val;
                          _playDurationSeconds = (_audioProgress * _totalDurationSeconds).toInt();
                        });
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_playDurationSeconds),
                            style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                          ),
                          Text(
                            _formatDuration(_totalDurationSeconds),
                            style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosSection(DiaryEntryModel entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Photos Captured",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.earthyBrown,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: entry.photos.length,
            itemBuilder: (context, index) {
              final photo = entry.photos[index];
              return Container(
                margin: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      photo.startsWith('http')
                          ? Image.network(
                              photo,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 120,
                                height: 120,
                                color: AppColors.primaryLight,
                                child: const Icon(Icons.image, color: AppColors.primaryGreen, size: 40),
                              ),
                            )
                          : Image.file(
                              File(photo),
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 120,
                                height: 120,
                                color: AppColors.primaryLight,
                                child: const Icon(Icons.image, color: AppColors.primaryGreen, size: 40),
                              ),
                            ),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.fullscreen, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotesCard(DiaryEntryModel entry, String langCode) {
    // Parse language codes
    String fromLang = entry.languageCode;
    if (fromLang.startsWith('kn')) fromLang = 'kn';
    if (fromLang.startsWith('hi')) fromLang = 'hi';
    if (fromLang.startsWith('en')) fromLang = 'en';

    // Translate to English if original is Kannada/Hindi, otherwise translate to Kannada
    String toLang = (fromLang == 'kn' || fromLang == 'hi') ? 'en' : (langCode.startsWith('kn') ? 'kn' : 'hi');

    return AppCard(
      padding: const EdgeInsets.all(16),
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Farm Journal Diary", 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
              ),
              if (entry.cleanedText.isNotEmpty || entry.originalText.isNotEmpty)
                IconButton(
                  icon: Icon(
                    _showTranslation ? Icons.g_translate : Icons.translate, 
                    color: AppColors.primaryGreen,
                    size: 22,
                  ),
                  tooltip: "Translate Note",
                  onPressed: () async {
                    if (_showTranslation) {
                      setState(() {
                        _showTranslation = false;
                      });
                      return;
                    }

                    if (_translatedText != null) {
                      setState(() {
                        _showTranslation = true;
                      });
                      return;
                    }

                    setState(() {
                      _isTranslating = true;
                    });

                    final sourceText = entry.cleanedText.isNotEmpty ? entry.cleanedText : entry.originalText;
                    final translated = await TranslationService.translate(
                      text: sourceText,
                      fromLanguage: fromLang,
                      toLanguage: toLang,
                    );

                    setState(() {
                      _translatedText = translated;
                      _isTranslating = false;
                      _showTranslation = true;
                    });
                  },
                ),
            ],
          ),
          const Divider(height: 20),
          
          if (_isTranslating)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                  ),
                ),
              ),
            )
          else if (_showTranslation && _translatedText != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2), width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.g_translate, color: AppColors.primaryGreen, size: 16),
                      SizedBox(width: 8),
                      Text(
                        "Translated Journal note:",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _translatedText!,
                    style: const TextStyle(
                      fontSize: 15, 
                      fontWeight: FontWeight.bold, 
                      color: AppColors.textDark, 
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (entry.cleanedText.isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 16),
                SizedBox(width: 6),
                Text(
                  "AI CLEANED & STRUCTURED NOTE", 
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              entry.cleanedText, 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark, height: 1.4),
            ),
            const SizedBox(height: 16),
          ],
          if (entry.originalText.isNotEmpty) ...[
            Text(
              entry.originalText,
              style: const TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: AppColors.textLight,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Itemized Expenses
  Widget _buildExpensesSection(DiaryEntryModel entry, String langCode) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Associated Expenses",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.earthyBrown,
                ),
              ),
              Text(
                "Total: ₹${entry.totalExpense.toStringAsFixed(0)}",
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentPurple,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          if (entry.expenses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: AppColors.textLight, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "No monetary cost recorded with this entry.",
                    style: TextStyle(color: AppColors.textLight, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entry.expenses.length,
              separatorBuilder: (context, index) => const Divider(height: 12, thickness: 0.5),
              itemBuilder: (context, index) {
                final exp = entry.expenses[index];
                return Row(
                  children: [
                    // Visual Category Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getCategoryIcon(exp.category),
                        color: AppColors.primaryGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Category & Item Name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exp.category,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          if (exp.itemName.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              "${exp.itemName} (${exp.quantity.toStringAsFixed(1)} ${exp.unit})",
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Amount
                    Text(
                      "₹${exp.totalAmount.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case "Pesticide":
        return Icons.opacity;
      case "Fertilizer":
        return Icons.grass;
      case "Labour":
        return Icons.people;
      case "Fuel":
        return Icons.local_gas_station;
      case "Transport":
        return Icons.local_shipping;
      case "Packing":
        return Icons.inventory;
      case "Equipment":
        return Icons.build;
      default:
        return Icons.attach_money;
    }
  }

  // Data Quality & AI Readiness Card
  Widget _buildQualityCard(DiaryEntryModel entry, String langCode) {
    final int scorePct = (entry.dataQualityScore * 100).toInt();
    final Color scoreColor = entry.aiReady ? AppColors.primaryGreen : Colors.amber.shade700;

    return AppCard(
      padding: const EdgeInsets.all(16),
      color: AppColors.white,
      border: Border.all(
        color: entry.aiReady ? AppColors.primaryGreen.withValues(alpha: 0.3) : Colors.amber.withValues(alpha: 0.3),
        width: 1.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Data Quality Score",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.earthyBrown,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$scorePct% AI-Ready",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Linear progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: entry.dataQualityScore,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),

          // Status Explanation
          if (entry.aiReady)
            Row(
              children: const [
                Icon(Icons.check_circle, color: AppColors.successGreen, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Excellent! This record is fully complete, structured, and ready to feed our future AI-Advisory recommendations.",
                    style: TextStyle(fontSize: 13, color: AppColors.successGreen, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning, color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Partially Complete Diary",
                        style: TextStyle(fontSize: 13, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Adding specific details helps future crop algorithms suggest accurate sprays or costs.",
                        style: TextStyle(fontSize: 12, color: AppColors.textLight),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (entry.missingFields.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Suggested Additions:",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
                    ),
                    const SizedBox(height: 4),
                    ...entry.missingFields.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 2.0),
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline, size: 12, color: Colors.amber.shade800),
                          const SizedBox(width: 6),
                          Text(
                            _formatMissingField(f),
                            style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _formatMissingField(String f) {
    switch (f) {
      case 'cropStage':
        return 'Crop growth stage';
      case 'workType':
        return 'Specific work category (e.g. Spraying)';
      case 'cleanedText':
        return 'Detailed text logs or observations';
      case 'expenses':
        return 'Monetary expense cost details';
      case 'photos':
        return 'Add crop leaf sample photo or bill photo';
      default:
        return f;
    }
  }

  // Edit History Card
  Widget _buildEditHistoryCard(DiaryEntryModel entry) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.history, color: AppColors.textLight, size: 18),
              SizedBox(width: 8),
              Text(
                "Entry Edit History",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.earthyBrown,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          ...entry.editHistory.map((item) {
            final formattedDate = item.editedAt.split('T')[0];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.edit, size: 12, color: AppColors.textLight),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                        children: [
                          const TextSpan(text: "Edited on "),
                          TextSpan(
                            text: formattedDate,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                          ),
                          const TextSpan(text: " by "),
                          TextSpan(
                            text: item.editedBy.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                          ),
                          const TextSpan(text: ". Fields changed: "),
                          TextSpan(
                            text: item.changedFields.join(', '),
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // Soft Delete Dialog Trigger
  Future<void> _confirmDelete(
    BuildContext context,
    FirestoreService firestoreService,
    String farmId,
    DiaryEntryModel entry,
  ) async {
    final languageCode = Provider.of<LanguageNotifier>(context, listen: false).currentLanguage;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(AppTranslations.translate('confirm_delete', languageCode)),
          content: const Text(
            "Are you sure you want to delete this diary entry? It will be safely put in the local backup trash where you can restore it anytime.",
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(ctx, false),
              icon: const Icon(Icons.close, size: 16, color: AppColors.textLight),
              label: const Text("CANCEL", style: TextStyle(color: AppColors.textLight)),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.delete_forever, size: 16, color: Colors.redAccent),
              label: const Text("DELETE", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      // Execute Soft Delete
      await firestoreService.softDeleteDiaryEntry(entry.farmerId, farmId, entry.entryId);

      // Show SnackBar with Undo option
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Entry moved to Backup Trash."),
            action: SnackBarAction(
              label: "UNDO",
              textColor: Colors.amberAccent,
              onPressed: () async {
                await firestoreService.restoreDiaryEntry(entry.farmerId, farmId, entry.entryId);
                // Return them to detail view or refresh
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        Navigator.pop(context); // Go back to history
      }
    }
  }
}
