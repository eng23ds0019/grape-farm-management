import 'expense_model.dart';

class StructuredData {
  final List<Map<String, dynamic>> pesticides;
  final List<Map<String, dynamic>> fertilizers;
  final Map<String, dynamic> labour;
  final Map<String, dynamic> irrigation;
  final List<ExpenseModel> expenses;
  final List<String> observations;
  final List<String> followUpActions;
  final List<String> tags;

  StructuredData({
    required this.pesticides,
    required this.fertilizers,
    required this.labour,
    required this.irrigation,
    required this.expenses,
    required this.observations,
    required this.followUpActions,
    required this.tags,
  });

  Map<String, dynamic> toMap() {
    return {
      'pesticides': pesticides,
      'fertilizers': fertilizers,
      'labour': labour,
      'irrigation': irrigation,
      'expenses': expenses.map((e) => e.toMap()).toList(),
      'observations': observations,
      'followUpActions': followUpActions,
      'tags': tags,
    };
  }

  factory StructuredData.fromMap(Map<String, dynamic> map) {
    var rawExpenses = map['expenses'] as List? ?? [];
    List<ExpenseModel> parsedExpenses = rawExpenses
        .map((e) => ExpenseModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    return StructuredData(
      pesticides: List<Map<String, dynamic>>.from(map['pesticides'] ?? []),
      fertilizers: List<Map<String, dynamic>>.from(map['fertilizers'] ?? []),
      labour: Map<String, dynamic>.from(map['labour'] ?? {}),
      irrigation: Map<String, dynamic>.from(map['irrigation'] ?? {}),
      expenses: parsedExpenses,
      observations: List<String>.from(map['observations'] ?? []),
      followUpActions: List<String>.from(map['followUpActions'] ?? []),
      tags: List<String>.from(map['tags'] ?? []),
    );
  }

  factory StructuredData.empty() {
    return StructuredData(
      pesticides: [],
      fertilizers: [],
      labour: {},
      irrigation: {},
      expenses: [],
      observations: [],
      followUpActions: [],
      tags: [],
    );
  }
}

class EditHistoryItem {
  final String editedAt;
  final List<String> changedFields;
  final Map<String, dynamic> previousValues;
  final String editedBy;

  EditHistoryItem({
    required this.editedAt,
    required this.changedFields,
    required this.previousValues,
    required this.editedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'editedAt': editedAt,
      'changedFields': changedFields,
      'previousValues': previousValues,
      'editedBy': editedBy,
    };
  }

  factory EditHistoryItem.fromMap(Map<String, dynamic> map) {
    return EditHistoryItem(
      editedAt: map['editedAt'] ?? '',
      changedFields: List<String>.from(map['changedFields'] ?? []),
      previousValues: Map<String, dynamic>.from(map['previousValues'] ?? {}),
      editedBy: map['editedBy'] ?? '',
    );
  }
}

class DiaryEntryModel {
  final String entryId;
  final String farmerId;
  final String farmId;
  final String date; // YYYY-MM-DD
  final String crop; // "Grapes"
  final String cropStage;
  final String workType;
  final String languageCode;
  final String inputType; // "voice" | "text" | "manual" | "photo" | "bill"
  final String originalText;
  final String cleanedText;
  final String voiceUrl;
  final List<String> photos;
  final List<ExpenseModel> expenses;
  final StructuredData structuredData;
  final double totalExpense;
  final bool aiReady;
  final bool farmerConfirmed;
  final bool needsReview;
  final double dataQualityScore;
  final List<String> missingFields;
  final String reminderDate; // YYYY-MM-DD
  final bool isSynced;
  final bool createdOffline;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final String? deletedAt;
  final List<EditHistoryItem> editHistory;

  DiaryEntryModel({
    required this.entryId,
    required this.farmerId,
    required this.farmId,
    required this.date,
    this.crop = "Grapes",
    required this.cropStage,
    required this.workType,
    required this.languageCode,
    required this.inputType,
    this.originalText = "",
    this.cleanedText = "",
    this.voiceUrl = "",
    required this.photos,
    required this.expenses,
    required this.structuredData,
    required this.totalExpense,
    this.aiReady = false,
    this.farmerConfirmed = false,
    this.needsReview = true,
    this.dataQualityScore = 0.0,
    required this.missingFields,
    this.reminderDate = "",
    this.isSynced = false,
    this.createdOffline = false,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.editHistory = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'entryId': entryId,
      'farmerId': farmerId,
      'farmId': farmId,
      'date': date,
      'crop': crop,
      'cropStage': cropStage,
      'workType': workType,
      'languageCode': languageCode,
      'inputType': inputType,
      'originalText': originalText,
      'cleanedText': cleanedText,
      'voiceUrl': voiceUrl,
      'photos': photos,
      'expenses': expenses.map((e) => e.toMap()).toList(),
      'structuredData': structuredData.toMap(),
      'totalExpense': totalExpense,
      'aiReady': aiReady,
      'farmerConfirmed': farmerConfirmed,
      'needsReview': needsReview,
      'dataQualityScore': dataQualityScore,
      'missingFields': missingFields,
      'reminderDate': reminderDate,
      'isSynced': isSynced,
      'createdOffline': createdOffline,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt,
      'editHistory': editHistory.map((h) => h.toMap()).toList(),
    };
  }

  factory DiaryEntryModel.fromMap(Map<String, dynamic> map, String id) {
    var rawExpenses = map['expenses'] as List? ?? [];
    List<ExpenseModel> parsedExpenses = rawExpenses
        .map((e) => ExpenseModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    var rawHistory = map['editHistory'] as List? ?? [];
    List<EditHistoryItem> parsedHistory = rawHistory
        .map((h) => EditHistoryItem.fromMap(Map<String, dynamic>.from(h)))
        .toList();

    return DiaryEntryModel(
      entryId: id,
      farmerId: map['farmerId'] ?? '',
      farmId: map['farmId'] ?? '',
      date: map['date'] ?? '',
      crop: map['crop'] ?? 'Grapes',
      cropStage: map['cropStage'] ?? '',
      workType: map['workType'] ?? '',
      languageCode: map['languageCode'] ?? 'en-IN',
      inputType: map['inputType'] ?? 'manual',
      originalText: map['originalText'] ?? '',
      cleanedText: map['cleanedText'] ?? '',
      voiceUrl: map['voiceUrl'] ?? '',
      photos: List<String>.from(map['photos'] ?? []),
      expenses: parsedExpenses,
      structuredData: map['structuredData'] != null
          ? StructuredData.fromMap(Map<String, dynamic>.from(map['structuredData']))
          : StructuredData.empty(),
      totalExpense: (map['totalExpense'] ?? 0.0) is int
          ? (map['totalExpense'] as int).toDouble()
          : (map['totalExpense'] ?? 0.0),
      aiReady: map['aiReady'] ?? false,
      farmerConfirmed: map['farmerConfirmed'] ?? false,
      needsReview: map['needsReview'] ?? true,
      dataQualityScore: (map['dataQualityScore'] ?? 0.0) is int
          ? (map['dataQualityScore'] as int).toDouble()
          : (map['dataQualityScore'] ?? 0.0),
      missingFields: List<String>.from(map['missingFields'] ?? []),
      reminderDate: map['reminderDate'] ?? '',
      isSynced: map['isSynced'] ?? false,
      createdOffline: map['createdOffline'] ?? false,
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
      isDeleted: map['isDeleted'] ?? false,
      deletedAt: map['deletedAt'],
      editHistory: parsedHistory,
    );
  }

  DiaryEntryModel copyWith({
    String? cropStage,
    String? workType,
    String? cleanedText,
    List<String>? photos,
    List<ExpenseModel>? expenses,
    StructuredData? structuredData,
    double? totalExpense,
    bool? aiReady,
    bool? farmerConfirmed,
    bool? needsReview,
    double? dataQualityScore,
    List<String>? missingFields,
    String? reminderDate,
    bool? isSynced,
    DateTime? updatedAt,
    bool? isDeleted,
    String? deletedAt,
    List<EditHistoryItem>? editHistory,
  }) {
    return DiaryEntryModel(
      entryId: entryId,
      farmerId: farmerId,
      farmId: farmId,
      date: date,
      crop: crop,
      cropStage: cropStage ?? this.cropStage,
      workType: workType ?? this.workType,
      languageCode: languageCode,
      inputType: inputType,
      originalText: originalText,
      cleanedText: cleanedText ?? this.cleanedText,
      voiceUrl: voiceUrl,
      photos: photos ?? this.photos,
      expenses: expenses ?? this.expenses,
      structuredData: structuredData ?? this.structuredData,
      totalExpense: totalExpense ?? this.totalExpense,
      aiReady: aiReady ?? this.aiReady,
      farmerConfirmed: farmerConfirmed ?? this.farmerConfirmed,
      needsReview: needsReview ?? this.needsReview,
      dataQualityScore: dataQualityScore ?? this.dataQualityScore,
      missingFields: missingFields ?? this.missingFields,
      reminderDate: reminderDate ?? this.reminderDate,
      isSynced: isSynced ?? this.isSynced,
      createdOffline: createdOffline,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      editHistory: editHistory ?? this.editHistory,
    );
  }
}
