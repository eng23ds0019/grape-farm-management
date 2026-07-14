import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../core/localization/translations.dart';
import '../../../models/bill_extraction_result.dart';
import '../../../models/bill_model.dart';
import '../../../models/diary_entry_model.dart';
import '../../../models/expense_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_card.dart';

class BillConfirmationScreen extends StatefulWidget {
  final Map<String, dynamic> args;

  const BillConfirmationScreen({super.key, required this.args});

  @override
  State<BillConfirmationScreen> createState() => _BillConfirmationScreenState();
}

class _BillConfirmationScreenState extends State<BillConfirmationScreen> {
  late String _shopName;
  late String _gstNumber;
  late String _customerName;
  late String _billDate;
  late String _invoiceNumber;
  late double _subtotal;
  late double _gstAmount;
  late double _totalAmount;
  late List<BillItem> _billItems;
  bool _isSaving = false;

  late double _shopNameConfidence;
  late double _gstNumberConfidence;
  late double _customerNameConfidence;
  late double _billDateConfidence;
  late double _invoiceNumberConfidence;
  late double _subtotalConfidence;
  late double _gstAmountConfidence;
  late double _totalAmountConfidence;

  late TextEditingController _shopNameController;
  late TextEditingController _gstNumberController;
  late TextEditingController _customerNameController;
  late TextEditingController _billDateController;
  late TextEditingController _invoiceNumberController;
  late TextEditingController _subtotalController;
  late TextEditingController _gstAmountController;

  final List<TextEditingController> _itemNameControllers = [];
  final List<TextEditingController> _itemAmountControllers = [];
  final List<TextEditingController> _itemQuantityControllers = [];

  @override
  void initState() {
    super.initState();

    // ── Accept either the new typed BillExtractionResult (from OfflineOcrService)
    // ── or the legacy billData map (backward compatibility).
    final BillExtractionResult? typed =
        widget.args['extractionResult'] as BillExtractionResult?;

    if (typed != null) {
      // ── New typed path ─────────────────────────────────────────────────────
      _shopName = typed.shopName.value;
      _shopNameConfidence = typed.shopName.confidence;

      _gstNumber = typed.gstNumber.value;
      _gstNumberConfidence = typed.gstNumber.confidence;

      _customerName = typed.customerName.value;
      _customerNameConfidence = typed.customerName.confidence;

      _invoiceNumber = typed.invoiceNumber.value;
      _invoiceNumberConfidence = typed.invoiceNumber.confidence;

      _billDate = typed.invoiceDate.value;
      _billDateConfidence = typed.invoiceDate.confidence;

      _totalAmount = typed.grandTotal.value;
      _totalAmountConfidence = typed.grandTotal.confidence;

      // Derive subtotal from item sum; GST = 0 (will be entered manually if needed)
      _billItems = typed.products.map((p) => BillItem(
            itemName: p.name.value,
            category: p.category,
            quantity: p.quantity.value,
            unit: p.unit.value,
            amount: p.amount.value,
          )).toList();

      _subtotal = _billItems.fold(0.0, (s, i) => s + i.amount);
      _subtotalConfidence = typed.grandTotal.confidence;
      _gstAmount = (_totalAmount - _subtotal).clamp(0.0, double.infinity);
      _gstAmountConfidence = 0.6;
    } else {
      // ── Legacy map path (backward compat) ──────────────────────────────────
      final data = widget.args['billData'] as Map<String, dynamic>? ?? {};
      _shopName = data['shopName'] ?? '';
      _gstNumber = data['gstNumber'] ?? '';
      _customerName = data['customerName'] ?? '';
      _billDate = data['billDate'] ?? DateTime.now().toIso8601String().substring(0, 10);
      _invoiceNumber = data['invoiceNumber'] ?? '';

      _shopNameConfidence = double.tryParse(data['shopNameConfidence']?.toString() ?? '1.0') ?? 1.0;
      _gstNumberConfidence = double.tryParse(data['gstNumberConfidence']?.toString() ?? '1.0') ?? 1.0;
      _customerNameConfidence = double.tryParse(data['customerNameConfidence']?.toString() ?? '1.0') ?? 1.0;
      _invoiceNumberConfidence = double.tryParse(data['invoiceNumberConfidence']?.toString() ?? '1.0') ?? 1.0;
      _billDateConfidence = double.tryParse(data['billDateConfidence']?.toString() ?? '1.0') ?? 1.0;

      final rawSubtotal = data['subtotal'];
      _subtotal = rawSubtotal is int ? rawSubtotal.toDouble() : (rawSubtotal is double ? rawSubtotal : 0.0);
      _subtotalConfidence = double.tryParse(data['subtotalConfidence']?.toString() ?? '1.0') ?? 1.0;

      final rawGstAmt = data['gstAmount'];
      _gstAmount = rawGstAmt is int ? rawGstAmt.toDouble() : (rawGstAmt is double ? rawGstAmt : 0.0);
      _gstAmountConfidence = double.tryParse(data['gstAmountConfidence']?.toString() ?? '1.0') ?? 1.0;

      final rawAmt = data['totalAmount'];
      _totalAmount = rawAmt is int ? rawAmt.toDouble() : (rawAmt is double ? rawAmt : 0.0);
      _totalAmountConfidence = double.tryParse(data['totalAmountConfidence']?.toString() ?? '1.0') ?? 1.0;

      final rawItems = data['items'] as List? ?? [];
      _billItems = rawItems.map((i) => BillItem.fromMap(Map<String, dynamic>.from(i))).toList();
    }

    _shopNameController = TextEditingController(text: _shopName);
    _gstNumberController = TextEditingController(text: _gstNumber);
    _customerNameController = TextEditingController(text: _customerName);
    _billDateController = TextEditingController(text: _billDate);
    _invoiceNumberController = TextEditingController(text: _invoiceNumber);
    _subtotalController = TextEditingController(text: _subtotal.toStringAsFixed(0));
    _gstAmountController = TextEditingController(text: _gstAmount.toStringAsFixed(0));

    for (var item in _billItems) {
      _itemNameControllers.add(TextEditingController(text: item.itemName));
      _itemAmountControllers.add(TextEditingController(text: item.amount.toStringAsFixed(0)));
      _itemQuantityControllers.add(TextEditingController(text: item.quantity.toStringAsFixed(0)));
    }
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _gstNumberController.dispose();
    _customerNameController.dispose();
    _billDateController.dispose();
    _invoiceNumberController.dispose();
    _subtotalController.dispose();
    _gstAmountController.dispose();
    for (var c in _itemNameControllers) {
      c.dispose();
    }
    for (var c in _itemAmountControllers) {
      c.dispose();
    }
    for (var c in _itemQuantityControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _billItems.add(BillItem(
        itemName: "",
        category: "Other",
        quantity: 1.0,
        unit: "qty",
        amount: 0.0,
      ));
      _itemNameControllers.add(TextEditingController(text: ""));
      _itemAmountControllers.add(TextEditingController(text: "0"));
      _itemQuantityControllers.add(TextEditingController(text: "1"));
      _recalculateTotal();
    });
  }

  void _removeItem(int index) {
    setState(() {
      _billItems.removeAt(index);
      _itemNameControllers[index].dispose();
      _itemNameControllers.removeAt(index);
      _itemAmountControllers[index].dispose();
      _itemAmountControllers.removeAt(index);
      _itemQuantityControllers[index].dispose();
      _itemQuantityControllers.removeAt(index);
      _recalculateTotal();
    });
  }

  void _recalculateTotal() {
    _subtotal = _billItems.fold(0.0, (sum, item) => sum + item.amount);
    _totalAmount = _subtotal + _gstAmount;
    _subtotalController.text = _subtotal.toStringAsFixed(0);
  }

  void _saveBillData(String langCode) async {
    // Dates validation check
    final datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!datePattern.hasMatch(_billDate) || DateTime.tryParse(_billDate) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(langCode == 'kn-IN' ? "ದಯವಿಟ್ಟು ಮಾನ್ಯ ದಿನಾಂಕವನ್ನು ನಮೂದಿಸಿ (YYYY-MM-DD)" : "Please enter a valid billing date (YYYY-MM-DD)"),
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
    final storageService = Provider.of<StorageService>(context, listen: false);

    final String uid = authService.currentUid ?? 'mock_farmer_patil';
    final String farmId = widget.args['farmId'] as String? ?? '';

    // Resolve billId — from new typed args or legacy map
    final String billId = (widget.args['billId'] as String?) ??
        (widget.args['billData'] as Map<String, dynamic>?)?['billId'] as String? ??
        DateTime.now().millisecondsSinceEpoch.toString();

    // Resolve image path — from new typed args or legacy map
    final String imagePath = (widget.args['billImagePath'] as String?) ??
        (widget.args['billData'] as Map<String, dynamic>?)?['billImageUrl'] as String? ??
        '';

    String cloudUrl = '';
    if (imagePath.isNotEmpty) {
      final File localFile = File(imagePath);
      if (localFile.existsSync()) {
        try {
          cloudUrl = await storageService.uploadFile(
            file: localFile,
            farmerId: uid,
            farmId: farmId,
            category: 'bills',
            entryOrBillId: billId,
            fileName: 'bill_image.jpg',
          );
        } catch (e) {
          debugPrint('BillConfirmationScreen: Image upload failed: $e');
        }
      }
    }

    final String extractedText = (widget.args['extractionResult'] as BillExtractionResult?)
            ?.buildSummaryText() ??
        (widget.args['billData'] as Map?)?['extractedText']?.toString() ?? '';

    final bill = BillModel(
      billId: billId,
      billDate: _billDate,
      shopName: _shopName,
      customerName: _customerName,
      invoiceNumber: _invoiceNumber,
      billImageUrl: cloudUrl.isNotEmpty ? cloudUrl : imagePath,
      extractedText: extractedText,
      items: _billItems,
      totalAmount: _totalAmount,
      status: 'confirmed',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Save Bill Document
    await firestoreService.saveBill(uid, farmId, bill);

    // Also convert bill items to formal farm expenses linked inside a diary entry
    final List<ExpenseModel> formalExpenses = _billItems.map((item) {
      return ExpenseModel(
        category: item.category,
        itemName: item.itemName,
        quantity: item.quantity,
        unit: item.unit,
        totalAmount: item.amount,
        date: _billDate,
        linkedDiaryEntryId: billId,
      );
    }).toList();

    StringBuffer sb = StringBuffer();
    sb.writeln("Shop Name: $_shopName");
    if (_gstNumber.isNotEmpty) sb.writeln("GSTIN: $_gstNumber");
    sb.writeln("Purchased Items:");
    for (var item in _billItems) {
      sb.writeln("- ${item.itemName} = Amount: ₹${item.amount.toStringAsFixed(0)}, Quantity: ${item.quantity.toStringAsFixed(0)} ${item.unit}");
    }
    sb.writeln("Subtotal: ₹${_subtotal.toStringAsFixed(0)}");
    sb.writeln("GST: ₹${_gstAmount.toStringAsFixed(0)}");
    sb.write("Total Bill: ₹${_totalAmount.toStringAsFixed(0)}");
    final String cleanSummaryText = sb.toString();

    final entry = DiaryEntryModel(
      entryId: billId,
      farmerId: uid,
      farmId: farmId,
      date: _billDate,
      cropStage: "Other",
      workType: "Other",
      languageCode: langCode,
      inputType: "bill",
      cleanedText: cleanSummaryText,
      photos: [cloudUrl.isNotEmpty ? cloudUrl : imagePath],
      expenses: formalExpenses,
      structuredData: StructuredData(
        pesticides: formalExpenses.where((e) => e.category == 'Pesticide').map((e) => e.toMap()).toList(),
        fertilizers: formalExpenses.where((e) => e.category == 'Fertilizer').map((e) => e.toMap()).toList(),
        labour: {},
        irrigation: {},
        expenses: formalExpenses,
        observations: [],
        followUpActions: [],
        tags: ["Bill", _shopName],
      ),
      totalExpense: _totalAmount,
      missingFields: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await firestoreService.saveDiaryEntry(uid, farmId, entry);

    setState(() {
      _isSaving = false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(langCode == 'kn-IN' ? "ಬಿಲ್ ಯಶಸ್ವಿಯಾಗಿ ಉಳಿಸಲಾಗಿದೆ!" : "Bill details successfully confirmed and saved!"),
        backgroundColor: AppColors.successGreen,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Provider.of<LanguageNotifier>(context).currentLanguage;
    // Resolve image path for the preview — new args or legacy map
    final billImageUrl = (widget.args['billImagePath'] as String?) ??
        (widget.args['billData'] as Map?)?['billImageUrl']?.toString() ??
        '';
    // For item confidence display — use typed model or legacy list
    final BillExtractionResult? typedResult =
        widget.args['extractionResult'] as BillExtractionResult?;
    final rawItemsArg = (widget.args['billData'] as Map?)?['items'] as List? ?? [];

    InputDecoration buildConfDecoration({
      required String label,
      required IconData icon,
      required bool isHighlight,
    }) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: isHighlight ? Colors.amber.shade800 : null),
        filled: isHighlight,
        fillColor: isHighlight ? Colors.amber.shade50.withOpacity(0.4) : null,
        enabledBorder: isHighlight
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.amber.shade600, width: 1.5),
              )
            : null,
        focusedBorder: isHighlight
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.amber.shade800, width: 2.0),
              )
            : null,
        helperText: isHighlight ? "Confidence low (<90%): please verify" : null,
        helperStyle: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
      );
    }

    final datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    final bool isDateValid = datePattern.hasMatch(_billDate) && DateTime.tryParse(_billDate) != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.translate('confirm_bill', langCode)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Receipt Image Preview
              if (billImageUrl != null && File(billImageUrl).existsSync()) ...[
                AppCard(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Image.file(
                          File(billImageUrl),
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                        Container(
                          width: double.infinity,
                          color: AppColors.textDark.withValues(alpha: 0.6),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          child: const Row(
                            children: [
                              Icon(Icons.photo, color: AppColors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                "Scanned Bill Receipt Photo",
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Store metadata card
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Merchant & Buyer Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.earthyBrown)),
                    const SizedBox(height: 12),
                    
                    // Shop Name
                    TextField(
                      controller: _shopNameController,
                      onChanged: (val) {
                        setState(() {
                          _shopName = val;
                        });
                      },
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: buildConfDecoration(
                        label: "Shop Name",
                        icon: Icons.store,
                        isHighlight: _shopNameConfidence < 0.90 || _shopName.isEmpty,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // GST Number
                    TextField(
                      controller: _gstNumberController,
                      onChanged: (val) {
                        setState(() {
                          _gstNumber = val;
                        });
                      },
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: buildConfDecoration(
                        label: "Merchant GSTIN",
                        icon: Icons.assignment,
                        isHighlight: _gstNumberConfidence < 0.90 || _gstNumber.isEmpty,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Customer Name
                    TextField(
                      controller: _customerNameController,
                      onChanged: (val) {
                        setState(() {
                          _customerName = val;
                        });
                      },
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: buildConfDecoration(
                        label: "Customer Name",
                        icon: Icons.person,
                        isHighlight: _customerNameConfidence < 0.90 || _customerName.isEmpty,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Date
                    TextField(
                      controller: _billDateController,
                      onChanged: (val) {
                        setState(() {
                          _billDate = val;
                        });
                      },
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: buildConfDecoration(
                        label: "Billing Date (YYYY-MM-DD)",
                        icon: Icons.calendar_today,
                        isHighlight: _billDateConfidence < 0.90 || _billDate.isEmpty || !isDateValid,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Bill / Invoice Number
                    TextField(
                      controller: _invoiceNumberController,
                      onChanged: (val) {
                        setState(() {
                          _invoiceNumber = val;
                        });
                      },
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: buildConfDecoration(
                        label: "Bill / Invoice Number",
                        icon: Icons.receipt_long,
                        isHighlight: _invoiceNumberConfidence < 0.90 || _invoiceNumber.isEmpty,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Extracted bill items editor card
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Extracted Purchases", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.earthyBrown)),
                        TextButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text("Add Item", style: TextStyle(fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreen),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_billItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        child: Center(
                          child: Text(
                            "No items added. Click Add Item to start.",
                            style: TextStyle(color: AppColors.textLight, fontStyle: FontStyle.italic),
                          ),
                        ),
                      )
                    else
                      ..._billItems.asMap().entries.map((entry) {
                        int idx = entry.key;
                        BillItem item = entry.value;

                        double nameConf = 1.0;
                        double qtyConf = 1.0;
                        double amtConf = 1.0;

                        // Prefer typed model confidence, fall back to legacy map
                        if (typedResult != null && idx < typedResult.products.length) {
                          nameConf = typedResult.products[idx].name.confidence;
                          qtyConf = typedResult.products[idx].quantity.confidence;
                          amtConf = typedResult.products[idx].amount.confidence;
                        } else if (idx < rawItemsArg.length) {
                          nameConf = double.tryParse(rawItemsArg[idx]['itemNameConfidence']?.toString() ?? '1.0') ?? 1.0;
                          qtyConf = double.tryParse(rawItemsArg[idx]['quantityConfidence']?.toString() ?? '1.0') ?? 1.0;
                          amtConf = double.tryParse(rawItemsArg[idx]['amountConfidence']?.toString() ?? '1.0') ?? 1.0;
                        }

                        final bool isLowConfidenceItem = nameConf < 0.90 || item.itemName.trim().isEmpty || item.itemName == "Other" || item.itemName == "";
                        final bool isLowConfidenceQty = qtyConf < 0.90 || item.quantity <= 0.0;
                        final bool isLowConfidenceAmt = amtConf < 0.90 || item.amount <= 0.0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: _itemNameControllers[idx],
                                      onChanged: (val) {
                                        setState(() {
                                          _billItems[idx] = BillItem(
                                            itemName: val,
                                            category: item.category,
                                            quantity: item.quantity,
                                            unit: item.unit,
                                            amount: item.amount,
                                          );
                                        });
                                      },
                                      decoration: InputDecoration(
                                        hintText: "Item Name",
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        filled: isLowConfidenceItem,
                                        fillColor: isLowConfidenceItem ? Colors.amber.shade50.withOpacity(0.3) : null,
                                        enabledBorder: isLowConfidenceItem
                                            ? OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide(color: Colors.amber.shade600, width: 1.2),
                                              )
                                            : null,
                                        focusedBorder: isLowConfidenceItem
                                            ? OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide(color: Colors.amber.shade800, width: 1.5),
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4.0),
                                      child: Row(
                                        children: [
                                          Text(
                                            "Category: ${item.category} | Qty: ",
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textLight,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 45,
                                            height: 20,
                                            child: TextField(
                                              controller: _itemQuantityControllers[idx],
                                              keyboardType: TextInputType.number,
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                                              decoration: InputDecoration(
                                                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 2),
                                                isDense: true,
                                                border: const UnderlineInputBorder(),
                                                focusedBorder: isLowConfidenceQty
                                                    ? UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber.shade800, width: 1.5))
                                                    : null,
                                              ),
                                              onChanged: (val) {
                                                double? valD = double.tryParse(val);
                                                if (valD != null) {
                                                  setState(() {
                                                    _billItems[idx] = BillItem(
                                                      itemName: item.itemName,
                                                      category: item.category,
                                                      quantity: valD,
                                                      unit: item.unit,
                                                      amount: item.amount,
                                                    );
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                          Text(
                                            " ${item.unit}",
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: _itemAmountControllers[idx],
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) {
                                    double? valD = double.tryParse(val);
                                    if (valD != null) {
                                      setState(() {
                                        _billItems[idx] = BillItem(
                                          itemName: item.itemName,
                                          category: item.category,
                                          quantity: item.quantity,
                                          unit: item.unit,
                                          amount: valD,
                                        );
                                        _recalculateTotal();
                                      });
                                    }
                                  },
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    prefixText: "₹",
                                    filled: isLowConfidenceAmt,
                                    fillColor: isLowConfidenceAmt ? Colors.amber.shade50.withOpacity(0.3) : null,
                                    enabledBorder: isLowConfidenceAmt
                                        ? OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.amber.shade600, width: 1.2),
                                          )
                                        : null,
                                    focusedBorder: isLowConfidenceAmt
                                        ? OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.amber.shade800, width: 1.5),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.delete, color: AppColors.errorRed, size: 20),
                                onPressed: () => _removeItem(idx),
                              ),
                            ],
                          ),
                        );
                      }),
                    const Divider(height: 24),
                    
                    // Subtotal
                    TextField(
                      controller: _subtotalController,
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        double? valD = double.tryParse(val);
                        if (valD != null) {
                          setState(() {
                            _subtotal = valD;
                            _totalAmount = _subtotal + _gstAmount;
                          });
                        }
                      },
                      decoration: buildConfDecoration(
                        label: "Subtotal",
                        icon: Icons.monetization_on,
                        isHighlight: _subtotalConfidence < 0.90 || _subtotal <= 0.0,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // GST Amount
                    TextField(
                      controller: _gstAmountController,
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        double? valD = double.tryParse(val);
                        if (valD != null) {
                          setState(() {
                            _gstAmount = valD;
                            _totalAmount = _subtotal + _gstAmount;
                          });
                        }
                      },
                      decoration: buildConfDecoration(
                        label: "GST Taxes",
                        icon: Icons.percent,
                        isHighlight: _gstAmountConfidence < 0.90,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Grand Total Check
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Grand Total",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark),
                        ),
                        Text(
                          "₹${_totalAmount.toStringAsFixed(0)}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: (_totalAmountConfidence < 0.90 || (_totalAmount - (_subtotal + _gstAmount)).abs() > 1.0)
                                ? Colors.amber.shade900
                                : AppColors.accentPurple,
                          ),
                        ),
                      ],
                    ),
                    if ((_totalAmount - (_subtotal + _gstAmount)).abs() > 1.0) ...[
                      const SizedBox(height: 8),
                      const Text(
                        "⚠️ Validation Error: Grand Total does not equal Subtotal + GST.",
                        style: TextStyle(color: AppColors.errorRed, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 30),

              AppButton(
                text: "Save & Link Expenses",
                icon: Icons.check,
                isLoading: _isSaving,
                onPressed: () => _saveBillData(langCode),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
