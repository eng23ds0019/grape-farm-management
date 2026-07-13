import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/constants.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../core/localization/translations.dart';
import '../../../models/diary_entry_model.dart';
import '../../../models/expense_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_card.dart';

class ManualExpenseScreen extends StatefulWidget {
  final String farmId;

  const ManualExpenseScreen({super.key, required this.farmId});

  @override
  State<ManualExpenseScreen> createState() => _ManualExpenseScreenState();
}

class _ManualExpenseScreenState extends State<ManualExpenseScreen> {
  final _itemNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _quantityController = TextEditingController(text: "1");
  final _noteController = TextEditingController();

  String _category = "Pesticide";
  String _unit = "kg";
  DateTime _expenseDate = DateTime.now();
  bool _isSaving = false;
  String _error = "";

  @override
  void dispose() {
    _itemNameController.dispose();
    _amountController.dispose();
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _saveExpense(String langCode) async {
    final name = _itemNameController.text.trim();
    final amtStr = _amountController.text.trim();
    final qtyStr = _quantityController.text.trim();

    if (name.isEmpty || amtStr.isEmpty) {
      setState(() {
        _error = "Please fill in item name and amount details.";
      });
      return;
    }

    final double? amt = double.tryParse(amtStr);
    final double? qty = double.tryParse(qtyStr);

    if (amt == null || amt <= 0 || qty == null || qty <= 0) {
      setState(() {
        _error = "Please enter valid positive values for cost and quantity.";
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = "";
    });

    final authService = Provider.of<FirebaseAuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    final String uid = authService.currentUid ?? "mock_farmer_patil";
    final String entryId = const Uuid().v4();

    // Create an itemized expense model
    final expense = ExpenseModel(
      category: _category,
      itemName: name,
      quantity: qty,
      unit: _unit,
      totalAmount: amt,
      note: _noteController.text.trim(),
      date: _expenseDate.toIso8601String().substring(0, 10),
      linkedDiaryEntryId: entryId,
    );

    // Save as a diary entry specifically for tracking expenses
    final entry = DiaryEntryModel(
      entryId: entryId,
      farmerId: uid,
      farmId: widget.farmId,
      date: _expenseDate.toIso8601String().substring(0, 10),
      cropStage: "Other",
      workType: _category == "Labour" ? "Labour work" : "Other",
      languageCode: langCode,
      inputType: "manual",
      cleanedText: "Logged expense item: $name ($_category) of ₹${amt.toStringAsFixed(0)}",
      photos: [],
      expenses: [expense],
      structuredData: StructuredData(
        pesticides: _category == "Pesticide" ? [expense.toMap()] : [],
        fertilizers: _category == "Fertilizer" ? [expense.toMap()] : [],
        labour: _category == "Labour" ? {'workers': qty.toInt(), 'amount': amt} : {},
        irrigation: {},
        expenses: [expense],
        observations: [],
        followUpActions: [],
        tags: [_category, "Expense"],
      ),
      totalExpense: amt,
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
        content: Text(langCode == 'kn-IN' ? "ವೆಚ್ಚವನ್ನು ಯಶಸ್ವಿಯಾಗಿ ಉಳಿಸಲಾಗಿದೆ!" : "Expense logged successfully!"),
        backgroundColor: AppColors.successGreen,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Provider.of<LanguageNotifier>(context).currentLanguage;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.translate('add_expense', langCode)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Calendar picker card
              AppCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Expense Date:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark)),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today, color: AppColors.primaryGreen),
                      label: Text(
                        _expenseDate.toIso8601String().substring(0, 10),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryGreen),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _expenseDate,
                          firstDate: DateTime(2025),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => _expenseDate = picked);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Category Selector
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Expense Category", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.earthyBrown)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(border: Border.all(color: AppColors.borderLight), borderRadius: BorderRadius.circular(10)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _category,
                          isExpanded: true,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          onChanged: (val) {
                            if (val != null) setState(() => _category = val);
                          },
                          items: AppConstants.expenseCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Item details entry
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Itemized Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.earthyBrown)),
                    const SizedBox(height: 14),

                    // Item Name
                    TextField(
                      controller: _itemNameController,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(labelText: "Item or Spray Name (e.g. Mancozeb, Nitrogen)"),
                    ),
                    const SizedBox(height: 14),

                    // Amount Cost
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(labelText: "Total Cost Amount (₹)"),
                    ),
                    const SizedBox(height: 14),

                    // Quantity and Unit row
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(labelText: "Quantity"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            initialValue: _unit,
                            decoration: const InputDecoration(labelText: "Measurement Unit"),
                            onChanged: (val) {
                              if (val != null) setState(() => _unit = val);
                            },
                            items: AppConstants.measurementUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Optional note card
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Remarks Note", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.earthyBrown)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteController,
                      maxLines: 2,
                      decoration: InputDecoration(hintText: "Enter extra remarks...", fillColor: AppColors.warmCream.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    _error,
                    style: const TextStyle(color: AppColors.errorRed, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),

              AppButton(
                text: "Save Cost Item",
                icon: Icons.check,
                isLoading: _isSaving,
                onPressed: () => _saveExpense(langCode),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
