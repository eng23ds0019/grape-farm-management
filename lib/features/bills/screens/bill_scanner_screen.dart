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
      double shopNameConfidence = 1.0;
      String gstNumber = "";
      double gstNumberConfidence = 1.0;
      String customerName = "";
      double customerNameConfidence = 1.0;
      String billDate = DateTime.now().toIso8601String().substring(0, 10);
      double billDateConfidence = 1.0;
      String invoiceNumber = "";
      double invoiceNumberConfidence = 1.0;

      double subtotal = 0.0;
      double subtotalConfidence = 1.0;
      double gstAmount = 0.0;
      double gstAmountConfidence = 1.0;
      double totalAmount = 0.0;
      double totalAmountConfidence = 1.0;

      List<Map<String, dynamic>> items = [];

      final data = parsedResult['data'] as Map<String, dynamic>;

      final shopData = data['shop_name'] as Map<String, dynamic>?;
      final gstData = data['gst_number'] as Map<String, dynamic>?;
      final buyerData = data['buyer_name'] as Map<String, dynamic>?;
      final invoiceData = data['invoice_number'] as Map<String, dynamic>?;
      final dateData = data['date'] as Map<String, dynamic>?;

      shopName = shopData?['value'] ?? "";
      shopNameConfidence = double.tryParse(shopData?['confidence']?.toString() ?? '1.0') ?? 1.0;

      gstNumber = gstData?['value'] ?? "";
      gstNumberConfidence = double.tryParse(gstData?['confidence']?.toString() ?? '1.0') ?? 1.0;

      customerName = buyerData?['value'] ?? "";
      customerNameConfidence = double.tryParse(buyerData?['confidence']?.toString() ?? '1.0') ?? 1.0;

      invoiceNumber = invoiceData?['value'] ?? "";
      invoiceNumberConfidence = double.tryParse(invoiceData?['confidence']?.toString() ?? '1.0') ?? 1.0;

      billDate = dateData?['value'] ?? DateTime.now().toIso8601String().substring(0, 10);
      billDateConfidence = double.tryParse(dateData?['confidence']?.toString() ?? '1.0') ?? 1.0;

      final subtotalData = data['subtotal'] as Map<String, dynamic>?;
      final gstAmtData = data['gst_amount'] as Map<String, dynamic>?;
      final totalData = data['total_amount'] as Map<String, dynamic>?;

      subtotal = double.tryParse(subtotalData?['value']?.toString() ?? '0.0') ?? 0.0;
      subtotalConfidence = double.tryParse(subtotalData?['confidence']?.toString() ?? '1.0') ?? 1.0;

      gstAmount = double.tryParse(gstAmtData?['value']?.toString() ?? '0.0') ?? 0.0;
      gstAmountConfidence = double.tryParse(gstAmtData?['confidence']?.toString() ?? '1.0') ?? 1.0;

      totalAmount = double.tryParse(totalData?['value']?.toString() ?? '0.0') ?? 0.0;
      totalAmountConfidence = double.tryParse(totalData?['confidence']?.toString() ?? '1.0') ?? 1.0;

      final rawItems = data['products'] as List? ?? [];
      for (var item in rawItems) {
        if (item is Map) {
          final nameMap = item['itemName'] as Map? ?? item['product_name'] as Map?;
          final qtyMap = item['quantity'] as Map?;
          final unitMap = item['unit'] as Map?;
          final amtMap = item['amount'] as Map?;

          final String name = nameMap?['value'] ?? "";
          if (name.isEmpty) continue;

          final double nameConf = double.tryParse(nameMap?['confidence']?.toString() ?? '1.0') ?? 1.0;
          final double quantity = double.tryParse(qtyMap?['value']?.toString() ?? '1.0') ?? 1.0;
          final double qtyConf = double.tryParse(qtyMap?['confidence']?.toString() ?? '1.0') ?? 1.0;
          final String unit = unitMap?['value'] ?? "bag";
          final double unitConf = double.tryParse(unitMap?['confidence']?.toString() ?? '1.0') ?? 1.0;
          final double amount = double.tryParse(amtMap?['value']?.toString() ?? '0.0') ?? 0.0;
          final double amtConf = double.tryParse(amtMap?['confidence']?.toString() ?? '1.0') ?? 1.0;

          final fuzzyMatchedName = BillValidator.fuzzyMatchFertilizer(name);
          final String finalName = fuzzyMatchedName ?? name;
          final String finalCategory = fuzzyMatchedName != null ? 'Fertilizer' : 'Pesticide';

          items.add({
            'itemName': finalName,
            'itemNameConfidence': nameConf,
            'category': finalCategory,
            'quantity': quantity,
            'quantityConfidence': qtyConf,
            'unit': unit,
            'unitConfidence': unitConf,
            'amount': amount,
            'amountConfidence': amtConf,
            'hsnCode': '',
            'netAmount': quantity > 0 ? (amount / quantity) : amount,
          });
        }
      }

      // Check sum validation
      final double calculatedItemsSum = items.fold(0.0, (sum, item) => sum + (item['amount'] as double));
      if (totalAmount == 0.0) {
        totalAmount = calculatedItemsSum;
      }

      // Formulate the strict clean formatting of extracted text (including HSN and Net pricing)
      StringBuffer sb = StringBuffer();
      if (shopName.isNotEmpty) sb.writeln("Shop Name: $shopName");
      if (gstNumber.isNotEmpty) sb.writeln("GSTIN: $gstNumber");
      if (customerName.isNotEmpty) sb.writeln("Customer Name: $customerName");
      sb.writeln("Date: $billDate");
      sb.writeln("Purchased Items:");
      for (var item in items) {
        sb.writeln("- ${item['itemName']} = Qty: ${(item['quantity'] as double).toStringAsFixed(0)} ${item['unit']}, Total: ₹${(item['amount'] as double).toStringAsFixed(0)}");
      }
      sb.writeln("Subtotal: ₹${subtotal.toStringAsFixed(0)}");
      sb.writeln("GST: ₹${gstAmount.toStringAsFixed(0)}");
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
            'shopNameConfidence': shopNameConfidence,
            'gstNumber': gstNumber,
            'gstNumberConfidence': gstNumberConfidence,
            'customerName': customerName,
            'customerNameConfidence': customerNameConfidence,
            'billDate': billDate,
            'billDateConfidence': billDateConfidence,
            'invoiceNumber': invoiceNumber,
            'invoiceNumberConfidence': invoiceNumberConfidence,
            'billImageUrl': imagePath,
            'subtotal': subtotal,
            'subtotalConfidence': subtotalConfidence,
            'gstAmount': gstAmount,
            'gstAmountConfidence': gstAmountConfidence,
            'totalAmount': totalAmount,
            'totalAmountConfidence': totalAmountConfidence,
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
