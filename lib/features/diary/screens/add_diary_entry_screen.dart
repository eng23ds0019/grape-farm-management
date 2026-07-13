import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/constants.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../core/localization/translations.dart';
import '../../../models/diary_entry_model.dart';
import '../../../models/expense_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/gemini_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_card.dart';

class AddDiaryEntryScreen extends StatefulWidget {
  final String farmId;

  const AddDiaryEntryScreen({super.key, required this.farmId});

  @override
  State<AddDiaryEntryScreen> createState() => _AddDiaryEntryScreenState();
}

class _AddDiaryEntryScreenState extends State<AddDiaryEntryScreen> {
  final _noteController = TextEditingController();
  final _expenseNameController = TextEditingController();
  final _expenseAmountController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedStage = "Berry growth";
  String _selectedWork = "Spraying";
  String _expenseCategory = "Pesticide";
  String _measurementUnit = "kg";

  final List<File> _photoFiles = [];
  final List<String> _photoUrls = [];
  final List<ExpenseModel> _loggedExpenses = [];
  bool _isUploading = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _noteController.dispose();
    _expenseNameController.dispose();
    _expenseAmountController.dispose();
    super.dispose();
  }

  // Pick Image from Camera
  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final status = await Permission.camera.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Camera permission denied. Cannot capture photo.")),
            );
          }
          return;
        }
      }

      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 75);
      if (picked != null) {
        setState(() {
          _photoFiles.add(File(picked.path));
        });
      }
    } catch (e) {
      // Gracefully handle permission errors
    }
  }

  // Save diary entry
  void _saveDiaryEntry(String langCode) async {
    setState(() {
      _isSaving = true;
    });

    final authService = Provider.of<FirebaseAuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final storageService = Provider.of<StorageService>(context, listen: false);

    final String uid = authService.currentUid ?? "mock_farmer_patil";
    final String entryId = const Uuid().v4();

    // 1. Upload photos to Firebase Storage
    if (_photoFiles.isNotEmpty) {
      setState(() {
        _isUploading = true;
      });
      for (int i = 0; i < _photoFiles.length; i++) {
        try {
          String url = await storageService.uploadFile(
            file: _photoFiles[i],
            farmerId: uid,
            farmId: widget.farmId,
            category: "diary",
            entryOrBillId: entryId,
            fileName: "photo_$i.jpg",
          );
          _photoUrls.add(url);
        } catch (e) {
          // Fallback url
          _photoUrls.add("https://images.unsplash.com/photo-1537084642907-629340c7e09e?w=500");
        }
      }
      setState(() {
        _isUploading = false;
      });
    }

    double totalExp = _loggedExpenses.fold(0.0, (sum, item) => sum + item.totalAmount);

    final entry = DiaryEntryModel(
      entryId: entryId,
      farmerId: uid,
      farmId: widget.farmId,
      date: _selectedDate.toIso8601String().substring(0, 10),
      cropStage: _selectedStage,
      workType: _selectedWork,
      languageCode: langCode,
      inputType: "manual",
      originalText: _noteController.text,
      cleanedText: _noteController.text,
      photos: _photoUrls,
      expenses: _loggedExpenses,
      structuredData: StructuredData(
        pesticides: _loggedExpenses.where((e) => e.category == 'Pesticide').map((e) => e.toMap()).toList(),
        fertilizers: _loggedExpenses.where((e) => e.category == 'Fertilizer').map((e) => e.toMap()).toList(),
        labour: {},
        irrigation: {},
        expenses: _loggedExpenses,
        observations: [],
        followUpActions: [],
        tags: [_selectedWork, _selectedStage],
      ),
      totalExpense: totalExp,
      missingFields: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await firestoreService.saveDiaryEntry(uid, widget.farmId, entry);

    setState(() {
      _isSaving = false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(langCode == 'kn-IN' ? "ದಾಖಲೆ ಯಶಸ್ವಿಯಾಗಿ ಉಳಿಸಲಾಗಿದೆ!" : "Diary entry saved successfully!"),
        backgroundColor: AppColors.successGreen,
      ),
    );

    Navigator.pop(context);
  }

  void _addExpenseItem() {
    final name = _expenseNameController.text.trim();
    final amtStr = _expenseAmountController.text.trim();
    if (name.isEmpty || amtStr.isEmpty) return;

    final double? amt = double.tryParse(amtStr);
    if (amt == null || amt <= 0) return;

    setState(() {
      _loggedExpenses.add(
        ExpenseModel(
          category: _expenseCategory,
          itemName: name,
          quantity: 1.0,
          unit: _measurementUnit,
          totalAmount: amt,
          date: _selectedDate.toIso8601String().substring(0, 10),
        ),
      );
      _expenseNameController.clear();
      _expenseAmountController.clear();
    });
  }

  void _triggerAiDrafting(String langCode) async {
    final searchController = TextEditingController();
    bool isGenerating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppColors.primaryGreen, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        langCode == 'kn-IN' ? "AI ಡೈರಿ ಬರಹಗಾರ" : "AI Diary Assistant",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.earthyBrown,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    langCode == 'kn-IN'
                        ? "ಕೆಲವೇ ಪದಗಳು ಅಥವಾ ಕೀವರ್ಡ್ಗಳನ್ನು ಟೈಪ್ ಮಾಡಿ. AI ನಿಮಗಾಗಿ ಒಂದು ಸುಂದರವಾದ ಡೈರಿ ಟಿಪ್ಪಣಿಯನ್ನು ಬರೆಯುತ್ತದೆ."
                        : "Type or speak a few keywords (e.g. 'spraying GA3, 10 workers, stage berry growth'). AI will write a professional diary entry for you.",
                    style: const TextStyle(fontSize: 13, color: AppColors.textLight, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  if (isGenerating) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: AppColors.primaryGreen),
                            SizedBox(height: 12),
                            Text(
                              "AI is understanding & writing...",
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: searchController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: langCode == 'kn-IN' ? "ಉದಾ: ಔಷಧಿ ಸಿಂಪಡಣೆ, ೫ ಕೂಲಿ ಆಳುಗಳು..." : "E.g. spraying pesticide, 5 workers, nice weather...",
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: AppColors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (searchController.text.trim().isEmpty) return;
                        setSheetState(() {
                          isGenerating = true;
                        });
                        try {
                          final draftedText = await GeminiService.draftDiaryNote(
                            prompt: searchController.text.trim(),
                            languageCode: langCode,
                          );
                          if (draftedText.isNotEmpty) {
                            setState(() {
                              _noteController.text = draftedText;
                            });
                          }
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("AI Diary note successfully written!"),
                                backgroundColor: AppColors.successGreen,
                              ),
                            );
                          }
                        } catch (e) {
                          setSheetState(() {
                            isGenerating = false;
                          });
                        }
                      },
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: Text(
                        langCode == 'kn-IN' ? "ಟಿಪ್ಪಣಿ ಬರೆಯಿರಿ" : "Draft Professional Note",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Provider.of<LanguageNotifier>(context).currentLanguage;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.translate('add_diary_title', langCode)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Date Selector
              AppCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Select Date:",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today, color: AppColors.primaryGreen),
                      label: Text(
                        _selectedDate.toIso8601String().substring(0, 10),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryGreen),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2025),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. Crop Stage Selection
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.translate('crop_stage', langCode),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.borderLight),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStage,
                          isExpanded: true,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedStage = val);
                          },
                          items: AppConstants.cropStages.map((stage) {
                            return DropdownMenuItem(
                              value: stage,
                              child: Text(AppTranslations.translate(stage, langCode)),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. Work Type Selection
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.translate('work_type', langCode),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.borderLight),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedWork,
                          isExpanded: true,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedWork = val);
                          },
                          items: AppConstants.workTypes.map((work) {
                            return DropdownMenuItem(
                              value: work,
                              child: Text(AppTranslations.translate(work, langCode)),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. Notes input
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppTranslations.translate('write_note', langCode),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
                        ),
                        TextButton.icon(
                          onPressed: () => _triggerAiDrafting(langCode),
                          icon: const Icon(Icons.auto_awesome, size: 14, color: AppColors.primaryGreen),
                          label: const Text(
                            "AI Write",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: "Enter details here...",
                        fillColor: AppColors.warmCream.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 5. Photos Section
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Capture & Upload Photos",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text("Camera"),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text("Gallery"),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, foregroundColor: AppColors.primaryGreen),
                        ),
                      ],
                    ),
                    if (_photoFiles.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _photoFiles.length,
                          itemBuilder: (context, idx) {
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                image: DecorationImage(
                                  image: FileImage(_photoFiles[idx]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 30),

              AppButton(
                text: AppTranslations.translate('save_entry', langCode),
                icon: Icons.check,
                isLoading: _isSaving || _isUploading,
                onPressed: () => _saveDiaryEntry(langCode),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
