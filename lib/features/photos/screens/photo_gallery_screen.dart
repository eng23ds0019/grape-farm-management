import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/constants.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../services/firestore_service.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/storage_service.dart';
import '../../../widgets/app_card.dart';
import '../../../models/diary_entry_model.dart';

class PhotoGalleryScreen extends StatefulWidget {
  final String farmId;

  const PhotoGalleryScreen({super.key, required this.farmId});

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> {
  String _selectedStage = "All";

  @override
  Widget build(BuildContext context) {
    Provider.of<LanguageNotifier>(context);
    final firestoreService = Provider.of<FirestoreService>(context);

    // Fetch all photos from diary entries
    final entries = firestoreService.cachedDiary
        .where((e) => e.farmId == widget.farmId)
        .toList();

    // Collect and map photos
    final List<Map<String, dynamic>> photosList = [];
    for (var entry in entries) {
      if (_selectedStage == "All" || entry.cropStage == _selectedStage) {
        for (var photoUrl in entry.photos) {
          photosList.add({
            'url': photoUrl,
            'date': entry.date,
            'stage': entry.cropStage,
            'work': entry.workType,
            'note': entry.cleanedText.isNotEmpty ? entry.cleanedText : entry.originalText,
          });
        }
      }
    }

    // Sort descending by date
    photosList.sort((a, b) => b['date'].compareTo(a['date']));

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: const Text("Crop & Bill Photos"),
      ),
      body: Column(
        children: [
          // Filter Stage Panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            color: AppColors.white,
            child: Row(
              children: [
                const Icon(Icons.filter_alt, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                const Text(
                  "Filter by Crop Stage:",
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedStage,
                      isExpanded: true,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryGreen),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedStage = val;
                          });
                        }
                      },
                      items: ["All", ...AppConstants.cropStages].map((s) {
                        return DropdownMenuItem(value: s, child: Text(s));
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main photo grid
          Expanded(
            child: photosList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_outlined, size: 64, color: AppColors.textLight.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Text(
                          "No photos recorded for this stage.",
                          style: TextStyle(fontSize: 16, color: AppColors.textLight, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Photos can be snapped in the Add Diary form.",
                          style: TextStyle(fontSize: 13, color: AppColors.textLight),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16.0),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: photosList.length,
                    itemBuilder: (context, index) {
                      final item = photosList[index];
                      return AppCard(
                        padding: EdgeInsets.zero,
                        color: AppColors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                child: item['url'].startsWith('http')
                                    ? Image.network(
                                        item['url'],
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, err, stack) {
                                          return Container(
                                            color: AppColors.primaryLight,
                                            child: const Icon(Icons.image, size: 48, color: AppColors.primaryGreen),
                                          );
                                        },
                                      )
                                    : Image.file(
                                        File(item['url']),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, err, stack) {
                                          return Container(
                                            color: AppColors.primaryLight,
                                            child: const Icon(Icons.image, size: 48, color: AppColors.primaryGreen),
                                          );
                                        },
                                      ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['date'],
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item['work'],
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                                        ),
                                      ),
                                      if (item['stage'].isNotEmpty)
                                        Text(
                                          item['stage'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add_a_photo),
        label: const Text("Capture Crop Leaf"),
        onPressed: () => _captureCropPhoto(context, firestoreService),
      ),
    );
  }

  void _captureCropPhoto(BuildContext context, FirestoreService firestoreService) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final langCode = Provider.of<LanguageNotifier>(context, listen: false).currentLanguage;

    final picker = ImagePicker();
    // Choose Camera or Gallery
    final pickedSource = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primaryGreen),
              title: const Text("Take Photo with Camera", style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.accentPurple),
              title: const Text("Select from Gallery", style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (pickedSource == null) return;

    if (pickedSource == ImageSource.camera) {
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text("Camera permission denied. Cannot capture photo.")),
        );
        return;
      }
    }

    final XFile? pickedFile = await picker.pickImage(source: pickedSource, imageQuality: 75);
    if (pickedFile == null) return;

    if (!context.mounted) return;

    // Show dialog to choose Stage and write optional description
    String chosenStage = _selectedStage == "All" ? "Berry growth" : _selectedStage;
    final noteController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text("Save Crop Photo", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.earthyBrown)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Preview picked image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(pickedFile.path),
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Stage Selector
                    const Text("Crop Stage:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLight)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: chosenStage,
                          isExpanded: true,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                          icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryGreen),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                chosenStage = val;
                              });
                            }
                          },
                          items: AppConstants.cropStages.where((s) => s != "Other" && s != "All").map((s) {
                            return DropdownMenuItem(value: s, child: Text(s));
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Note Description
                    const Text("Note / Observation (Optional):", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLight)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        hintText: "E.g. Leaf looks healthy...",
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(ctx, false),
                  icon: const Icon(Icons.close, size: 16, color: AppColors.textLight),
                  label: const Text("CANCEL", style: TextStyle(color: AppColors.textLight)),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.check, size: 16, color: AppColors.primaryGreen),
                  label: const Text("SAVE PHOTO", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm != true) return;

    if (!context.mounted) return;

    // Trigger save operations with SnackBar loading
    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text("Saving crop stage photo...")),
    );

    try {
      final authService = Provider.of<FirebaseAuthService>(context, listen: false);
      final storageService = Provider.of<StorageService>(context, listen: false);

      final String uid = authService.currentUid ?? "mock_farmer_patil";
      final String entryId = const Uuid().v4();

      // Upload local captured photo to cloud Storage
      String cloudUrl = "";
      try {
        cloudUrl = await storageService.uploadFile(
          file: File(pickedFile.path),
          farmerId: uid,
          farmId: widget.farmId,
          category: "diary",
          entryOrBillId: entryId,
          fileName: "photo_0.jpg",
        );
      } catch (e) {
        // Offline / Simulation fallback
        cloudUrl = pickedFile.path;
      }

      final entry = DiaryEntryModel(
        entryId: entryId,
        farmerId: uid,
        farmId: widget.farmId,
        date: DateTime.now().toIso8601String().substring(0, 10),
        cropStage: chosenStage,
        workType: "Other",
        languageCode: langCode,
        inputType: "photo",
        originalText: noteController.text.trim(),
        cleanedText: noteController.text.trim(),
        photos: [cloudUrl],
        expenses: [],
        structuredData: StructuredData.empty(),
        totalExpense: 0.0,
        missingFields: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await firestoreService.saveDiaryEntry(uid, widget.farmId, entry);

      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text("Crop leaf photo saved successfully!"),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (e) {
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("Error saving photo: $e"), backgroundColor: AppColors.errorRed),
      );
    }
  }
}
