import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../core/localization/language_notifier.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../core/constants/colors.dart';
import '../../../widgets/app_button.dart';
import '../../../services/gemini_service.dart';
import '../../../services/openai_service.dart';
import '../../../core/utils/bill_validator.dart';
import '../../../core/utils/document_ai_pipeline.dart';
import '../../../services/document_ai_service.dart';

class BillScannerScreen extends StatefulWidget {
  final String farmId;

  const BillScannerScreen({super.key, required this.farmId});

  @override
  State<BillScannerScreen> createState() => _BillScannerScreenState();
}

class _BillScannerScreenState extends State<BillScannerScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _imagePath;
  String _scanStatusText = "Preparing receipt...";
  
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    // 2-second loop for scanning sweeping animation
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    // Dynamic tween updated dynamically in LayoutBuilder
    _scanAnimation = Tween<double>(begin: 0.0, end: 300.0).animate(CurvedAnimation(
      parent: _scanController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  // Trigger gallery image pick
  void _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      _startOcrAndScanAnimation(picked.path);
    }
  }

  // Trigger camera snap
  void _captureFromCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 75);
    if (picked != null) {
      _startOcrAndScanAnimation(picked.path);
    }
  }

  // Start the sweeping laser and transparent layer scan animation and perform OCR in parallel
  void _startOcrAndScanAnimation(String imagePath) async {
    setState(() {
      _imagePath = imagePath;
      _isLoading = true;
      _scanStatusText = "Opening scanner lens...";
    });

    _scanController.repeat(reverse: true);

    final navigator = Navigator.of(context);
    
    // OCR Extraction
    try {
      setState(() {
        _scanStatusText = "Local OCR: Processing image...";
      });

      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      final String rawText = recognizedText.text;
      await textRecognizer.close();

      // A. Run Image Quality Analyzer
      final langCode = Provider.of<LanguageNotifier>(context, listen: false).currentLanguage;
      final quality = DocumentAiPipeline.analyzeImageQuality(imagePath, rawText);
      if (!quality.isAcceptable) {
        setState(() {
          _isLoading = false;
        });
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(langCode == 'kn-IN' ? "ಕಡಿಮೆ ಚಿತ್ರ ಗುಣಮಟ್ಟ" : (langCode == 'hi-IN' ? "कम छवि गुणवत्ता" : "Low Image Quality")),
            content: Text(quality.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              ),
            ],
          ),
        );
        return;
      }

      // B. Simulated Image Enhancement
      final enhancedPath = DocumentAiPipeline.enhanceImage(imagePath);

      setState(() {
        _scanStatusText = "Document AI: Classifying & Extracting...";
      });

      // Call the production-grade Agriculture Document AI pipeline
      final parsedResult = await DocumentAiService.extractDocument(enhancedPath, rawText);
      final bool success = parsedResult['success'] ?? false;

      if (!success) {
        setState(() {
          _isLoading = false;
        });
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(langCode == 'kn-IN' ? "ದೋಷ" : (langCode == 'hi-IN' ? "त्रुटि" : "AI Processing Failed")),
            content: Text(parsedResult['error'] ?? "Failed to extract structured data from document."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              ),
            ],
          ),
        );
        return;
      }

      String shopName = "";
      String customerName = "";
      String billDate = DateTime.now().toIso8601String().substring(0, 10);
      double totalAmount = 0.0;
      List<Map<String, dynamic>> items = [];

      final data = parsedResult['data'] as Map<String, dynamic>;

      shopName = data['shop_name'] ?? "";
      customerName = data['buyer_name'] ?? "";
      billDate = data['date'] ?? DateTime.now().toIso8601String().substring(0, 10);
      final String invoiceNumber = data['invoice_number'] ?? "";
      
      final totalStr = data['total_amount'] ?? "0";
      totalAmount = double.tryParse(totalStr) ?? 0.0;
      
      final rawItems = data['products'] as List? ?? [];
      for (var item in rawItems) {
        if (item is Map) {
          final name = item['product_name'] ?? '';
          if (name.isEmpty) continue;

          final amtVal = item['amount'];
          final double itemAmt = double.tryParse(amtVal.toString()) ?? 0.0;

          final fuzzyMatchedName = BillValidator.fuzzyMatchFertilizer(name);
          final String finalName = fuzzyMatchedName ?? name;

          final String finalCategory = fuzzyMatchedName != null ? 'Fertilizer' : 'Pesticide';
          final qVal = item['quantity'] ?? '1';
          final double finalQuantity = double.tryParse(qVal.toString()) ?? 1.0;
          final String finalUnit = finalCategory == 'Fertilizer' ? 'bag' : 'bottle';
          
          final rateVal = item['unit_price'];
          final double finalNetAmt = double.tryParse(rateVal.toString()) ?? itemAmt;

          items.add({
            'itemName': finalName,
            'category': finalCategory,
            'quantity': finalQuantity,
            'unit': finalUnit,
            'amount': itemAmt,
            'hsnCode': '',
            'netAmount': finalNetAmt,
          });
        }
      }

      // Detect total amount from raw OCR text using regex helper if still 0.0
      final double? detectedTotal = BillValidator.detectTotalAmount(rawText);
      if (totalAmount == 0.0 && detectedTotal != null) {
        totalAmount = detectedTotal;
      }
      
      // Sanity check totalAmount with items sum to prevent OCR rupee-to-2 misreads (e.g. ₹10,500 read as 210,500)
      final double calculatedItemsSum = items.fold(0.0, (sum, item) => sum + (item['amount'] as double));
      if (calculatedItemsSum > 0.0) {
        if (totalAmount == 0.0 || 
            totalAmount == (calculatedItemsSum + 200000.0) || 
            totalAmount == (calculatedItemsSum + 20000.0) ||
            totalAmount == (calculatedItemsSum + 2000.0) ||
            (totalAmount - calculatedItemsSum).abs() > (calculatedItemsSum * 0.5)) {
          totalAmount = calculatedItemsSum;
        }
      } else {
        if (totalAmount == 0.0) {
          totalAmount = calculatedItemsSum;
        }
      }

      // Formulate the strict clean formatting of extracted text (including HSN and Net pricing)
      StringBuffer sb = StringBuffer();
      if (shopName.isNotEmpty) sb.writeln("Shop Name: $shopName");
      if (customerName.isNotEmpty) sb.writeln("Customer Name: $customerName");
      sb.writeln("Date: $billDate");
      sb.writeln("Purchased Items:");
      for (var item in items) {
        final hsn = item['hsnCode'] ?? '';
        final net = item['netAmount'] ?? item['amount'];
        final hsnStr = hsn.isNotEmpty ? " (HSN: $hsn)" : "";
        final netStr = net != item['amount'] ? " [Net: ₹${(net as double).toStringAsFixed(0)}]" : "";
        
        sb.writeln("- ${item['itemName']}$hsnStr = Qty: ${(item['quantity'] as double).toStringAsFixed(0)} ${item['unit']}$netStr, Total: ₹${(item['amount'] as double).toStringAsFixed(0)}");
      }
      sb.write("Total Bill: ₹${totalAmount.toStringAsFixed(0)}");
      final String cleanSummaryText = sb.toString();

      setState(() {
        _scanStatusText = "Refining item logs...";
      });

      // Ensure the scanner animation runs for at least 2.5 seconds for premium UX
      await Future.delayed(const Duration(milliseconds: 2500));

      _scanController.stop();
      setState(() {
        _isLoading = false;
      });

      // Navigate to confirmation screen
      navigator.pushReplacementNamed(
        '/bill_confirm',
        arguments: {
          'farmId': widget.farmId,
          'billData': {
            'billId': const Uuid().v4(),
            'shopName': shopName,
            'customerName': customerName,
            'billDate': billDate,
            'invoiceNumber': invoiceNumber,
            'billImageUrl': imagePath,
            'totalAmount': totalAmount,
            'extractedText': cleanSummaryText,
            'items': items,
          },
        },
      );
    } catch (e) {
      debugPrint("OCR Parsing error: $e");
      _scanController.stop();
      setState(() {
        _isLoading = false;
      });
      // Show snackbar error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Receipt scan failed: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text(
          "Scan Shop Bill",
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
              const Text(
                "Purchase Invoice OCR",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
              ),
              const SizedBox(height: 6),
              const Text(
                "Snap a clean photo of your fertilizer or pesticide purchase receipt. The system will extract the shop name, items, and total spending automatically.",
                style: TextStyle(fontSize: 13, color: AppColors.textLight, height: 1.4),
              ),
              const SizedBox(height: 24),

              // Scanning Box / Viewfinder Alignment box
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final containerHeight = constraints.maxHeight;
                      
                      // Dynamically adjust animation endpoints based on available container layout
                      if (_isLoading && _imagePath != null) {
                        _scanAnimation = Tween<double>(begin: 0.0, end: containerHeight - 6.0).animate(CurvedAnimation(
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
                          border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryGreen.withValues(alpha: 0.05),
                              blurRadius: 16,
                              spreadRadius: 2,
                            )
                          ]
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_imagePath != null) ...[
                              // Selected image display
                              Positioned.fill(
                                child: Image.file(
                                  File(_imagePath!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              
                              if (_isLoading) ...[
                                // Sweep shadow overlay (Green Layer covering selected bill receipt)
                                AnimatedBuilder(
                                  animation: _scanAnimation,
                                  builder: (context, child) {
                                    return Positioned(
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
                                              AppColors.primaryGreen.withValues(alpha: 0.15),
                                              AppColors.freshGreen.withValues(alpha: 0.35),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // Sweep neon laser line
                                AnimatedBuilder(
                                  animation: _scanAnimation,
                                  builder: (context, child) {
                                    return Positioned(
                                      top: _scanAnimation.value,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        height: 4,
                                        decoration: BoxDecoration(
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.freshGreen.withValues(alpha: 0.9),
                                              blurRadius: 12,
                                              spreadRadius: 3,
                                            )
                                          ],
                                          color: AppColors.freshGreen,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ] else ...[
                              // Viewfinder Placeholder when no image selected
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
                                          )
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
                                      "Align Receipt Within Frame",
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.primaryGreen),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      "Camera supports automatic text extraction.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 13, color: AppColors.textLight),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            
                            // Bottom active status alert
                            if (_isLoading)
                              Positioned(
                                bottom: 20,
                                left: 20,
                                right: 20,
                                child: Card(
                                  elevation: 8,
                                  shadowColor: Colors.black12,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  color: Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            _scanStatusText,
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primaryGreen),
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

              // Capture controls
              if (!_isLoading) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          side: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          foregroundColor: AppColors.primaryGreen,
                          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library),
                        label: const Text("Upload Gallery"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        text: "Capture Receipt",
                        icon: Icons.camera_alt,
                        onPressed: _captureFromCamera,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 56), // spacer when loading
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
