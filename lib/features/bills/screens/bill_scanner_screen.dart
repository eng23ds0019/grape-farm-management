// lib/features/bills/screens/bill_scanner_screen.dart
//
// Bill Scanner Screen — camera/gallery entry point for the offline OCR pipeline.
//
// Pipeline wired up here:
//  PickImage → OfflineOcrService.extractBill → BillConfirmationScreen
//
// Cloud API calls (DocumentAiService, GeminiService, OpenAiService) are
// intentionally NOT used here. Everything runs on-device.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/colors.dart';
import '../../../widgets/app_button.dart';
import '../../../services/offline_ocr_service.dart';
import '../../../core/utils/document_ai_pipeline.dart';
import '../../../models/bill_extraction_result.dart';

class BillScannerScreen extends StatefulWidget {
  final String farmId;

  const BillScannerScreen({super.key, required this.farmId});

  @override
  State<BillScannerScreen> createState() => _BillScannerScreenState();
}

class _BillScannerScreenState extends State<BillScannerScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _imagePath;
  String _scanStatusText = 'Preparing scanner...';

  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  // Status steps shown during processing
  static const List<String> _statusSteps = [
    'Opening scanner lens...',
    'Enhancing image quality...',
    'Running English OCR pass...',
    'Running Kannada OCR pass...',
    'Analysing document layout...',
    'Extracting fields...',
    'Validating data...',
    'Preparing confirmation...',
  ];

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _scanAnimation = Tween<double>(begin: 0.0, end: 300.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  // ─── Image pickers ─────────────────────────────────────────────────────────

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked != null) _startOfflinePipeline(picked.path);
  }

  Future<void> _captureFromCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked != null) _startOfflinePipeline(picked.path);
  }

  // ─── Main pipeline ─────────────────────────────────────────────────────────

  Future<void> _startOfflinePipeline(String imagePath) async {
    setState(() {
      _imagePath = imagePath;
      _isLoading = true;
      _scanStatusText = _statusSteps[0];
    });

    _scanController.repeat(reverse: true);

    final navigator = Navigator.of(context);

    try {
      // ── Quick quality pre-check using word count from a fast Latin pass ────
      _setStatus(1); // Enhancing image quality
      
      // Run the full offline extraction pipeline
      _setStatus(2); // Running English OCR
      
      // Small delay lets UI refresh before heavy computation starts
      await Future.delayed(const Duration(milliseconds: 80));

      _setStatus(3); // Running Kannada OCR
      final BillExtractionResult result =
          await OfflineOcrService.extractBill(imagePath);

      _setStatus(4); // Analysing document layout
      await Future.delayed(const Duration(milliseconds: 80));

      _setStatus(5); // Extracting fields

      // Quality check: if we got almost nothing, prompt user to retake
      if (result.products.isEmpty &&
          result.shopName.value.isEmpty &&
          result.grandTotal.value == 0.0) {
        _stopLoading();
        _showRetakeDialog(
          'Could not read the bill.\n\n'
          'Tips:\n'
          '• Place the bill on a flat, well-lit surface\n'
          '• Avoid shadows and glare\n'
          '• Hold the phone directly above the bill\n'
          '• Ensure the entire bill is in frame',
        );
        return;
      }

      _setStatus(6); // Validating
      await Future.delayed(const Duration(milliseconds: 80));

      _setStatus(7); // Preparing confirmation

      // Minimum animation time for premium UX feel
      await Future.delayed(const Duration(milliseconds: 1500));

      _scanController.stop();
      setState(() => _isLoading = false);

      // Navigate to confirmation screen
      navigator.pushReplacementNamed(
        '/bill_confirm',
        arguments: {
          'farmId': widget.farmId,
          'extractionResult': result,
          'billId': const Uuid().v4(),
          'billImagePath': imagePath,
        },
      );
    } catch (e) {
      debugPrint('BillScannerScreen: Pipeline error: $e');
      _stopLoading();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _setStatus(int stepIndex) {
    if (!mounted) return;
    setState(() {
      _scanStatusText = _statusSteps[stepIndex.clamp(0, _statusSteps.length - 1)];
    });
  }

  void _stopLoading() {
    _scanController.stop();
    if (mounted) setState(() => _isLoading = false);
  }

  void _showRetakeDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.document_scanner, color: AppColors.primaryGreen, size: 22),
            const SizedBox(width: 8),
            const Text('Scan Quality Low', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Retake', style: TextStyle(color: AppColors.primaryGreen)),
          ),
        ],
      ),
    );
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text(
          'Scan Shop Bill',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const Text(
                'Purchase Invoice OCR',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.offline_bolt,
                            size: 13, color: AppColors.primaryGreen),
                        const SizedBox(width: 4),
                        Text(
                          '100% Offline · No API Key',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.translate, size: 13, color: Colors.blue.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'English + Kannada',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Snap a clean photo of your fertilizer or pesticide purchase receipt. '
                'The AI extracts shop name, items, quantities and totals automatically — '
                'completely offline.',
                style: TextStyle(fontSize: 13, color: AppColors.textLight, height: 1.4),
              ),
              const SizedBox(height: 20),

              // Scan viewfinder
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final containerHeight = constraints.maxHeight;
                      if (_isLoading && _imagePath != null) {
                        _scanAnimation = Tween<double>(
                          begin: 0.0,
                          end: containerHeight - 6.0,
                        ).animate(CurvedAnimation(
                          parent: _scanController,
                          curve: Curves.easeInOut,
                        ));
                      }

                      return Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.primaryGreen.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryGreen.withValues(alpha: 0.05),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Image display
                            if (_imagePath != null) ...[
                              Positioned.fill(
                                child: Image.file(
                                  File(_imagePath!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              if (_isLoading) ...[
                                // Scan sweep overlay
                                AnimatedBuilder(
                                  animation: _scanAnimation,
                                  builder: (context, _) => Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    height: _scanAnimation.value,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            AppColors.primaryGreen.withValues(alpha: 0.12),
                                            AppColors.freshGreen.withValues(alpha: 0.30),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Neon laser line
                                AnimatedBuilder(
                                  animation: _scanAnimation,
                                  builder: (context, _) => Positioned(
                                    top: _scanAnimation.value,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: AppColors.freshGreen,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.freshGreen.withValues(alpha: 0.9),
                                            blurRadius: 12,
                                            spreadRadius: 3,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ] else ...[
                              // Placeholder
                              Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: AppColors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primaryGreen.withValues(alpha: 0.1),
                                            blurRadius: 16,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.document_scanner_outlined,
                                        size: 72,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    const Text(
                                      'Align Receipt Within Frame',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Supports English & Kannada text.\nWorks completely offline.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textLight,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Tips card
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.amber.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text('📸 Tips for best results:',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                  color: Colors.black87)),
                                          SizedBox(height: 4),
                                          Text(
                                            '• Place bill on flat surface\n'
                                            '• Good lighting, no shadows\n'
                                            '• Hold phone directly above\n'
                                            '• Entire bill in frame',
                                            style: TextStyle(fontSize: 11.5, color: Colors.black54, height: 1.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Processing status card
                            if (_isLoading)
                              Positioned(
                                bottom: 20,
                                left: 20,
                                right: 20,
                                child: Card(
                                  elevation: 8,
                                  shadowColor: Colors.black12,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  color: Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20.0,
                                      vertical: 12.0,
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              AppColors.primaryGreen,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            _scanStatusText,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: AppColors.primaryGreen,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action buttons
              if (!_isLoading) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          side: const BorderSide(
                              color: AppColors.primaryGreen, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                          foregroundColor: AppColors.primaryGreen,
                          textStyle: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Upload Gallery'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        text: 'Capture Receipt',
                        icon: Icons.camera_alt,
                        onPressed: _captureFromCamera,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 56),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
