import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../models/turnover_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/openai_service.dart';
import '../../../services/gemini_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_card.dart';

class TurnoverScreen extends StatefulWidget {
  final String farmId;

  const TurnoverScreen({super.key, required this.farmId});

  @override
  State<TurnoverScreen> createState() => _TurnoverScreenState();
}

class _TurnoverScreenState extends State<TurnoverScreen> {
  final _yieldController = TextEditingController();
  String _grapeType = "Fresh Grapes";
  
  // List of allocations
  final List<AllocationInput> _allocations = [];
  
  bool _isSaving = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    // Start with one blank allocation row
    _addAllocationRow();
  }

  @override
  void dispose() {
    _yieldController.dispose();
    for (var alloc in _allocations) {
      alloc.dispose();
    }
    _audioRecorder.dispose();
    super.dispose();
  }

  void _addAllocationRow() {
    setState(() {
      _allocations.add(AllocationInput());
    });
  }

  void _removeAllocationRow(int index) {
    if (_allocations.length > 1) {
      setState(() {
        _allocations[index].dispose();
        _allocations.removeAt(index);
      });
    }
  }

  // AI-powered Voice Typing Bottom Sheet
  Future<void> _startVoiceInput(TextEditingController controller, String label, String langCode) async {
    // Request permission
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }

    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Microphone permission required for voice typing")),
        );
      }
      return;
    }

    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/voice_type_${const Uuid().v4()}.m4a';

    try {
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      setState(() {
        _isListening = true;
      });
    } catch (e) {
      debugPrint("Failed to start voice typing record: $e");
      return;
    }

    if (!mounted) return;

    // Show listening visual overlay bottom sheet
    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24.0),
              height: 280,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    langCode == 'kn-IN' ? "ಕೇಳಿಸಿಕೊಳ್ಳಲಾಗುತ್ತಿದೆ..." : "Listening...",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${langCode == 'kn-IN' ? 'ಇದಕ್ಕಾಗಿ ಮಾತನಾಡಿ' : 'Speak naturally for'} \"$label\"",
                    style: const TextStyle(fontSize: 14, color: AppColors.textLight),
                  ),
                  const SizedBox(height: 24),
                  
                  // Pulse micro-animation replacement (glowing circle)
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGreen.withOpacity(0.2),
                          blurRadius: 16,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mic,
                      size: 36,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      minimumSize: const Size(160, 48),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx); // Close sheet
                    },
                    child: Text(
                      langCode == 'kn-IN' ? "ನಿಲ್ಲಿಸಿ" : "Stop & Process",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // Stop recording and process
    final finalPath = await _audioRecorder.stop();
    setState(() {
      _isListening = false;
    });

    if (finalPath != null && File(finalPath).existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                ),
                const SizedBox(width: 12),
                Text(langCode == 'kn-IN' ? "ಧ್ವನಿಯನ್ನು ಪರಿವರ್ತಿಸಲಾಗುತ್ತಿದೆ..." : "Transcribing your speech..."),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Transcribe
      final text = await OpenAiService.transcribeAudio(finalPath, languageCode: langCode);
      final cleanText = text.trim().replaceAll(RegExp(r'[.\u200b]'), '');

      if (cleanText.isNotEmpty) {
        setState(() {
          // If we are typing yield or quantity, extract numbers only
          if (label.toLowerCase().contains("yield") || label.toLowerCase().contains("quantity")) {
            final numbers = RegExp(r'\d+(\.\d+)?').firstMatch(cleanText);
            if (numbers != null) {
              controller.text = numbers.group(0)!;
            } else {
              controller.text = cleanText;
            }
          } else {
            controller.text = cleanText;
          }
        });
      }

      // Clean up temp file
      try {
        await File(finalPath).delete();
      } catch (e) {
        debugPrint("Error deleting temp audio: $e");
      }
    }
  }

  // Save Turnover Details
  void _saveTurnoverData(String langCode) async {
    final yieldStr = _yieldController.text.trim();
    if (yieldStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(langCode == 'kn-IN' ? "ದಯವಿಟ್ಟು ಒಟ್ಟು ಇಳುವರಿಯನ್ನು ನಮೂದಿಸಿ" : "Please enter total yield"),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final double? totalYield = double.tryParse(yieldStr);
    if (totalYield == null || totalYield <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(langCode == 'kn-IN' ? "ದಯವಿಟ್ಟು ಮಾನ್ಯವಾದ ಇಳುವರಿಯನ್ನು ನಮೂದಿಸಿ" : "Please enter a valid yield in tons"),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    // Build Allocations list
    List<TurnoverAllocationModel> allocModels = [];
    double allocatedSum = 0.0;

    for (int i = 0; i < _allocations.length; i++) {
      final allocInput = _allocations[i];
      final dest = allocInput.destinationController.text.trim();
      final qtyStr = allocInput.qtyController.text.trim();
      final billAcc = allocInput.billingAccController.text.trim();
      final plate = allocInput.plateController.text.trim();

      if (dest.isEmpty || qtyStr.isEmpty) {
        continue; // Skip blank allocations
      }

      final double? qty = double.tryParse(qtyStr);
      if (qty == null || qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(langCode == 'kn-IN' 
                ? "ಸಾಲಿನಲ್ಲಿ ತಪ್ಪಾದ ಪ್ರಮಾಣ: ${i+1}" 
                : "Invalid quantity in allocation row ${i+1}"),
            backgroundColor: AppColors.errorRed,
          ),
        );
        return;
      }

      allocatedSum += qty;
      allocModels.add(TurnoverAllocationModel(
        destinationName: dest,
        quantitySent: qty,
        billingAccountNumber: billAcc,
        vehicleNumberPlate: plate,
      ));
    }

    if (allocatedSum > totalYield) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(langCode == 'kn-IN' 
              ? "ಹಂಚಿಕೆ ಮಾಡಿದ ಪ್ರಮಾಣವು ಒಟ್ಟು ಇಳುವರಿಗಿಂತ ಹೆಚ್ಚಿರಬಾರದು" 
              : "Allocated sum cannot exceed total yield"),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final authService = Provider.of<FirebaseAuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    final uid = authService.currentUid ?? "mock_farmer_patil";
    final turnoverId = const Uuid().v4();

    final turnover = TurnoverModel(
      turnoverId: turnoverId,
      farmerId: uid,
      grapeType: _grapeType,
      totalYield: totalYield,
      allocations: allocModels,
      date: DateTime.now().toIso8601String().substring(0, 10),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await firestoreService.saveTurnover(uid, turnover);

    setState(() {
      _isSaving = false;
      _yieldController.clear();
      _allocations.clear();
      _addAllocationRow(); // Reset to one blank row
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(langCode == 'kn-IN' 
              ? "ಟರ್ನೋವರ್ ವಿವರಗಳನ್ನು ಯಶಸ್ವಿಯಾಗಿ ಉಳಿಸಲಾಗಿದೆ!" 
              : "Turnover records saved successfully!"),
          backgroundColor: AppColors.successGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Provider.of<LanguageNotifier>(context).currentLanguage;
    final firestoreService = Provider.of<FirestoreService>(context);

    // Filter past turnovers for this farmer/uid
    final authService = Provider.of<FirebaseAuthService>(context, listen: false);
    final currentUid = authService.currentUid ?? "mock_farmer_patil";
    final pastTurnovers = firestoreService.cachedTurnovers
        .where((t) => t.farmerId == currentUid)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: Text(langCode == 'kn-IN' ? "ಟರ್ನೋವರ್ ಟ್ರ್ಯಾಕರ್" : "Turnover Tracker"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Crop Yield Section Card
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      langCode == 'kn-IN' ? "ಬೆಳೆ ಇಳುವರಿ ವಿವರಗಳು" : "Crop Yield Summary",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
                    ),
                    const SizedBox(height: 14),

                    // Grape Type Dropdown
                    const Text("Grape Type", style: TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.borderLight),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _grapeType,
                          isExpanded: true,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _grapeType = val;
                              });
                            }
                          },
                          items: ["Fresh Grapes", "Dry Grapes"].map((w) => DropdownMenuItem(
                            value: w,
                            child: Text(w),
                          )).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Total Yield in Tons with Mic
                    const Text("Total Yield Grown (in Tons)", style: TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _yieldController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              hintText: "E.g. 25",
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.mic, color: AppColors.accentPurple),
                          onPressed: () => _startVoiceInput(_yieldController, "Total Yield", langCode),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Allocations / Destinations Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    langCode == 'kn-IN' ? "ಸಂಗ್ರಹಣೆ / ಸಾಗಣೆ ಹಂಚಿಕೆಗಳು" : "Storage & Transport Allocations",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
                  ),
                  TextButton.icon(
                    onPressed: _addAllocationRow,
                    icon: const Icon(Icons.add, color: AppColors.primaryGreen, size: 18),
                    label: Text(
                      langCode == 'kn-IN' ? "ಸೇರಿಸಿ" : "Add Location",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Allocation Input Cards List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _allocations.length,
                itemBuilder: (context, index) {
                  final alloc = _allocations[index];
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${langCode == 'kn-IN' ? 'ಹಂಚಿಕೆ' : 'Allocation'} #${index + 1}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen, fontSize: 14),
                            ),
                            if (_allocations.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.errorRed, size: 20),
                                onPressed: () => _removeAllocationRow(index),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Destination Name Field
                        const Text("Storage/Destination Location", style: TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: alloc.destinationController,
                                decoration: const InputDecoration(
                                  hintText: "E.g. Bangalore Cold Storage",
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.mic, color: AppColors.accentPurple, size: 20),
                              onPressed: () => _startVoiceInput(alloc.destinationController, "Location Location", langCode),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Quantity Sent (in tons) Field
                        const Text("Quantity Sent (in Tons)", style: TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: alloc.qtyController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  hintText: "E.g. 10",
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.mic, color: AppColors.accentPurple, size: 20),
                              onPressed: () => _startVoiceInput(alloc.qtyController, "Quantity in Tons", langCode),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Billing Account Number Field
                        const Text("Storage Billing Account Number", style: TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: alloc.billingAccController,
                                decoration: const InputDecoration(
                                  hintText: "E.g. ACC9876543",
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.mic, color: AppColors.accentPurple, size: 20),
                              onPressed: () => _startVoiceInput(alloc.billingAccController, "Billing Account Number", langCode),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Vehicle plate number Field
                        const Text("Transport Vehicle Number Plate", style: TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: alloc.plateController,
                                decoration: const InputDecoration(
                                  hintText: "E.g. KA-28-M-1234",
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.mic, color: AppColors.accentPurple, size: 20),
                              onPressed: () => _startVoiceInput(alloc.plateController, "Vehicle Plate Number", langCode),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Save button
              AppButton(
                text: langCode == 'kn-IN' ? "ಟರ್ನೋವರ್ ಉಳಿಸಿ" : "Save Turnover Record",
                icon: Icons.check,
                isLoading: _isSaving,
                onPressed: () => _saveTurnoverData(langCode),
              ),
              const SizedBox(height: 24),

              // Past Turnovers List Section Header
              Text(
                langCode == 'kn-IN' ? "ಹಿಂದಿನ ಟರ್ನೋವರ್ ಇತಿಹಾಸ" : "Past Turnover History",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
              ),
              const SizedBox(height: 10),

              if (pastTurnovers.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Center(
                      child: Text(
                        langCode == 'kn-IN' ? "ಯಾವುದೇ ಟರ್ನೋವರ್ ದಾಖಲೆಗಳಿಲ್ಲ." : "No turnover records registered yet.",
                        style: const TextStyle(color: AppColors.textLight),
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pastTurnovers.length,
                  itemBuilder: (context, idx) {
                    final item = pastTurnovers[idx];
                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.grapeType,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                              ),
                              Text(
                                item.date,
                                style: const TextStyle(fontSize: 13, color: AppColors.textLight, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${langCode == 'kn-IN' ? 'ಒಟ್ಟು ಇಳುವರಿ' : 'Total Grown'}: ${item.totalYield.toStringAsFixed(1)} Tons",
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark),
                          ),
                          const SizedBox(height: 10),
                          
                          if (item.allocations.isNotEmpty) ...[
                            const Divider(),
                            const SizedBox(height: 4),
                            const Text(
                              "Allocations & Transport:",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLight),
                            ),
                            const SizedBox(height: 6),
                            ...item.allocations.map((a) => Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.local_shipping, size: 16, color: AppColors.accentPurple),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "${a.quantitySent.toStringAsFixed(1)} Tons -> ${a.destinationName}",
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                                        ),
                                        Text(
                                          "Billing: ${a.billingAccountNumber.isEmpty ? 'N/A' : a.billingAccountNumber} • Plate: ${a.vehicleNumberPlate.isEmpty ? 'N/A' : a.vehicleNumberPlate}",
                                          style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            )),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// Controller container helper class for allocation input items
class AllocationInput {
  final destinationController = TextEditingController();
  final qtyController = TextEditingController();
  final billingAccController = TextEditingController();
  final plateController = TextEditingController();

  void dispose() {
    destinationController.dispose();
    qtyController.dispose();
    billingAccController.dispose();
    plateController.dispose();
  }
}
