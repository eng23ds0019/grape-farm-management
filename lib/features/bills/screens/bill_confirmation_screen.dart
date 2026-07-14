import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../core/localization/translations.dart';
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
  late String _customerName;
  late String _billDate;
  late String _invoiceNumber;
  late double _totalAmount;
  late List<BillItem> _billItems;
  bool _isSaving = false;

  late TextEditingController _shopNameController;
  late TextEditingController _customerNameController;
  late TextEditingController _billDateController;
  late TextEditingController _invoiceNumberController;
  final List<TextEditingController> _itemNameControllers = [];
  final List<TextEditingController> _itemAmountControllers = [];
  final List<TextEditingController> _itemQuantityControllers = [];

  @override
  void initState() {
    super.initState();
    final data = widget.args['billData'];
    _shopName = data['shopName'] ?? "";
    _customerName = data['customerName'] ?? "";
    _billDate = data['billDate'] ?? DateTime.now().toIso8601String().substring(0, 10);
    _invoiceNumber = data['invoiceNumber'] ?? "";
    
    final rawAmt = data['totalAmount'];
    _totalAmount = rawAmt is int ? rawAmt.toDouble() : (rawAmt is double ? rawAmt : 0.0);
    
    final rawItems = data['items'] as List? ?? [];
    _billItems = rawItems.map((i) => BillItem.fromMap(Map<String, dynamic>.from(i))).toList();

    _shopNameController = TextEditingController(text: _shopName);
    _customerNameController = TextEditingController(text: _customerName);
    _billDateController = TextEditingController(text: _billDate);
    _invoiceNumberController = TextEditingController(text: _invoiceNumber);

    for (var item in _billItems) {
      _itemNameControllers.add(TextEditingController(text: item.itemName));
      _itemAmountControllers.add(TextEditingController(text: item.amount.toStringAsFixed(0)));
      _itemQuantityControllers.add(TextEditingController(text: item.quantity.toStringAsFixed(0)));
    }
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _customerNameController.dispose();
    _billDateController.dispose();
    _invoiceNumberController.dispose();
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
    _totalAmount = _billItems.fold(0.0, (sum, item) => sum + item.amount);
  }

  void _saveBillData(String langCode) async {
    setState(() {
      _isSaving = true;
    });

    final authService = Provider.of<FirebaseAuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final storageService = Provider.of<StorageService>(context, listen: false);

    final String uid = authService.currentUid ?? "mock_farmer_patil";
    final String farmId = widget.args['farmId'];
    final data = widget.args['billData'];
    final String billId = data['billId'];

    // 1. Upload local captured photo to cloud Storage
    String cloudUrl = "";
    final File localFile = File(data['billImageUrl']);
    if (localFile.existsSync()) {
      try {
        cloudUrl = await storageService.uploadFile(
          file: localFile,
          farmerId: uid,
          farmId: farmId,
          category: "bills",
          entryOrBillId: billId,
          fileName: "bill_image.jpg",
        );
      } catch (e) {
        cloudUrl = "https://images.unsplash.com/photo-1537084642907-629340c7e09e?w=500";
      }
    }

    final bill = BillModel(
      billId: billId,
      billDate: _billDate,
      shopName: _shopName,
      customerName: _customerName,
      invoiceNumber: _invoiceNumber,
      billImageUrl: cloudUrl.isNotEmpty ? cloudUrl : data['billImageUrl'],
      extractedText: data['extractedText'],
      items: _billItems,
      totalAmount: _totalAmount,
      status: "confirmed",
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Save Bill Document
    await firestoreService.saveBill(uid, farmId, bill);

    // Also convert bill items to formal farm expenses linked inside a diary entry!
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
    sb.writeln("Purchased Items:");
    for (var item in _billItems) {
      sb.writeln("- ${item.itemName} = Amount: ₹${item.amount.toStringAsFixed(0)}, Quantity: ${item.quantity.toStringAsFixed(0)} ${item.unit}");
    }
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
      photos: [cloudUrl.isNotEmpty ? cloudUrl : data['billImageUrl']],
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
    final billImageUrl = widget.args['billData']['billImageUrl'];

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

              // Premium Extracted Bill Summary Card
              if (widget.args['billData']['extractedText'] != null) ...[
                AppCard(
                  color: AppColors.primaryLight.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: AppColors.primaryGreen, size: 18),
                          SizedBox(width: 8),
                          Text(
                            "AI Extracted Bill Summary",
                            style: TextStyle(
                              color: AppColors.primaryGreen,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.1)),
                        ),
                        child: Text(
                          widget.args['billData']['extractedText'],
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textDark,
                            height: 1.5,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Store metadata card
              // Store metadata card
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Merchant Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.earthyBrown)),
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
                      decoration: InputDecoration(
                        labelText: "Shop Name",
                        prefixIcon: Icon(Icons.store, color: (_shopName.trim().isEmpty || _shopName == "General Agro Store") ? Colors.amber.shade800 : null),
                        filled: (_shopName.trim().isEmpty || _shopName == "General Agro Store"),
                        fillColor: (_shopName.trim().isEmpty || _shopName == "General Agro Store") ? Colors.amber.shade50.withOpacity(0.3) : null,
                        enabledBorder: (_shopName.trim().isEmpty || _shopName == "General Agro Store")
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.amber.shade600, width: 1.5),
                              )
                            : null,
                        helperText: (_shopName.trim().isEmpty || _shopName == "General Agro Store") ? "Low confidence: verify detail" : null,
                        helperStyle: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
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
                      decoration: InputDecoration(
                        labelText: "Customer Name",
                        prefixIcon: Icon(Icons.person, color: (_customerName.trim().isEmpty || _customerName == "Unknown Customer") ? Colors.amber.shade800 : null),
                        filled: (_customerName.trim().isEmpty || _customerName == "Unknown Customer"),
                        fillColor: (_customerName.trim().isEmpty || _customerName == "Unknown Customer") ? Colors.amber.shade50.withOpacity(0.3) : null,
                        enabledBorder: (_customerName.trim().isEmpty || _customerName == "Unknown Customer")
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.amber.shade600, width: 1.5),
                              )
                            : null,
                        helperText: (_customerName.trim().isEmpty || _customerName == "Unknown Customer") ? "Low confidence: verify detail" : null,
                        helperStyle: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
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
                      decoration: InputDecoration(
                        labelText: "Billing Date",
                        prefixIcon: Icon(Icons.calendar_today, color: _billDate.trim().isEmpty ? Colors.amber.shade800 : null),
                        filled: _billDate.trim().isEmpty,
                        fillColor: _billDate.trim().isEmpty ? Colors.amber.shade50.withOpacity(0.3) : null,
                        enabledBorder: _billDate.trim().isEmpty
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.amber.shade600, width: 1.5),
                              )
                            : null,
                        helperText: _billDate.trim().isEmpty ? "Low confidence: verify detail" : null,
                        helperStyle: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
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
                      decoration: InputDecoration(
                        labelText: "Bill / Invoice Number",
                        prefixIcon: Icon(Icons.receipt_long, color: _invoiceNumber.trim().isEmpty ? Colors.amber.shade800 : null),
                        filled: _invoiceNumber.trim().isEmpty,
                        fillColor: _invoiceNumber.trim().isEmpty ? Colors.amber.shade50.withOpacity(0.3) : null,
                        enabledBorder: _invoiceNumber.trim().isEmpty
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.amber.shade600, width: 1.5),
                              )
                            : null,
                        helperText: _invoiceNumber.trim().isEmpty ? "Low confidence: verify detail" : null,
                        helperStyle: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
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
                        final bool isLowConfidenceItem = item.itemName.trim().isEmpty || item.itemName == "Other" || item.itemName == "";
                        final bool isLowConfidenceQty = item.quantity <= 0.0;
                        final bool isLowConfidenceAmt = item.amount <= 0.0;

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Total Spending Amount",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark),
                        ),
                        Text(
                          "₹${_totalAmount.toStringAsFixed(0)}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.accentPurple),
                        ),
                      ],
                    ),
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
