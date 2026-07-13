import '../../models/diary_entry_model.dart';

class DataQualityValidator {
  /// Analyzes a [DiaryEntryModel] and calculates a quality score between 0.0 and 1.0,
  /// along with a list of missing fields.
  static Map<String, dynamic> evaluateQuality(DiaryEntryModel entry) {
    double score = 0.0;
    List<String> missingFields = [];

    // Date Check (Weight: 0.15)
    if (entry.date.isNotEmpty) {
      score += 0.15;
    } else {
      missingFields.add("Date");
    }

    // Crop Stage Check (Weight: 0.20)
    if (entry.cropStage.isNotEmpty && entry.cropStage != "Other") {
      score += 0.20;
    } else {
      missingFields.add("Crop Stage");
    }

    // Work Type Check (Weight: 0.20)
    if (entry.workType.isNotEmpty && entry.workType != "Other") {
      score += 0.20;
    } else {
      missingFields.add("Work Type");
    }

    // Text Description Check (Weight: 0.20)
    if (entry.cleanedText.isNotEmpty || entry.originalText.isNotEmpty) {
      score += 0.20;
    } else {
      missingFields.add("Diary Note");
    }

    // Media Check: Photos or Audio (Weight: 0.15)
    if (entry.photos.isNotEmpty || entry.voiceUrl.isNotEmpty) {
      score += 0.15;
    } else {
      missingFields.add("Photos/Voice Note");
    }

    // Expense Details Check (Weight: 0.10)
    if (entry.expenses.isNotEmpty) {
      score += 0.10;
    } else {
      missingFields.add("Expenses logged");
    }

    return {
      'score': double.parse(score.toStringAsFixed(2)),
      'missingFields': missingFields,
      'aiReady': score >= 0.70, // 70% quality threshold for AI training readiness
      'needsReview': score < 0.70,
    };
  }
}
