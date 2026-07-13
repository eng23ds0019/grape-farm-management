import '../models/diary_entry.dart';

class AiAdvisorService {
  String answerFromFarmerData({
    required String question,
    required List<DiaryEntry> entries,
    required String languageCode,
  }) {
    final lower = question.toLowerCase();
    final recent = entries.take(20).toList();
    final totalExpense = recent.fold<double>(
      0,
      (sum, entry) => sum + entry.totalExpense,
    );
    final sprayCount = recent
        .where((entry) => entry.workType.toLowerCase().contains('spray'))
        .length;
    final diseaseNotes = recent
        .where(
          (entry) =>
              entry.workType.toLowerCase().contains('disease') ||
              entry.cleanedText.toLowerCase().contains('disease'),
        )
        .length;

    if (recent.isEmpty) {
      return _localized(
        languageCode,
        en: 'I need your saved diary, photos, bills, and expenses first. Add today work, then I will advise only from your farm data.',
        hi: 'पहले आपकी सेव की गई डायरी, फोटो, बिल और खर्च चाहिए। आज का काम जोड़ें, फिर मैं केवल आपके खेत के डेटा से सलाह दूंगा।',
        kn: 'ಮೊದಲು ನಿಮ್ಮ ಉಳಿಸಿದ ಡೈರಿ, ಫೋಟೋ, ಬಿಲ್ ಮತ್ತು ಖರ್ಚು ಬೇಕು. ಇಂದಿನ ಕೆಲಸ ಸೇರಿಸಿ, ನಂತರ ನಾನು ನಿಮ್ಮ ತೋಟದ ಡೇಟಾದಿಂದ ಮಾತ್ರ ಸಲಹೆ ನೀಡುತ್ತೇನೆ.',
      );
    }

    if (lower.contains('spray') || lower.contains('pesticide') || lower.contains('ಸಿಂಪಡಣೆ') || lower.contains('छिड़काव')) {
      return _localized(
        languageCode,
        en: 'You have done $sprayCount sprays in recent records. Add spray date, product and amount to track all applications.',
        hi: 'हाल के रिकॉर्ड में $sprayCount स्प्रे हैं। सभी अनुप्रयोगों को ट्रैक करने के लिए स्प्रे तिथि, उत्पाद और राशि जोड़ें।',
        kn: 'ಇತ್ತೀಚಿನ ದಾಖಲೆಗಳಲ್ಲಿ $sprayCount ಸ್ಪ್ರೇ ಮಾಡಿದ್ದೀರಿ. ಎಲ್ಲ ಸ್ಪ್ರೇ ದಿನಾಂಕ, ಉತ್ಪನ್ನ ಮತ್ತು ಮೊತ್ತ ಸೇರಿಸಿ.',
      );
    }

    if (lower.contains('expense') || lower.contains('cost') || lower.contains('ಖರ್ಚು') || lower.contains('खर्च')) {
      return _localized(
        languageCode,
        en: 'Total expense in recent records: Rs ${totalExpense.toStringAsFixed(0)}. Keep adding bills and expenses daily.',
        hi: 'हाल के रिकॉर्ड में कुल खर्च: Rs ${totalExpense.toStringAsFixed(0)}। रोज बिल और खर्च जोड़ते रहें।',
        kn: 'ಇತ್ತೀಚಿನ ದಾಖಲೆಗಳಲ್ಲಿ ಒಟ್ಟು ಖರ್ಚು: Rs ${totalExpense.toStringAsFixed(0)}. ಪ್ರತಿದಿನ ಬಿಲ್ ಮತ್ತು ಖರ್ಚು ಸೇರಿಸಿ.',
      );
    }

    if (lower.contains('disease') || lower.contains('ರೋಗ') || lower.contains('बीमारी')) {
      return _localized(
        languageCode,
        en: 'You have $diseaseNotes recent disease notes. Add clear leaf/grape photos and symptoms; app will keep them AI-ready.',
        hi: 'आपकी डायरी में $diseaseNotes हाल की रोग टिप्पणियां हैं। साफ पत्ती/अंगूर फोटो और लक्षण जोड़ें।',
        kn: 'ನಿಮ್ಮ ಡೈರಿಯಲ್ಲಿ $diseaseNotes ಇತ್ತೀಚಿನ ರೋಗ ಗಮನಿಕೆಗಳಿವೆ. ಸ್ಪಷ್ಟ ಎಲೆ/ದ್ರಾಕ್ಷಿ ಫೋಟೋ ಮತ್ತು ಲಕ್ಷಣ ಸೇರಿಸಿ.',
      );
    }

    return _localized(
      languageCode,
      en: 'Based only on your saved grape farm records, continue updating diary, expenses, photos and bills daily. More records will make advice stronger.',
      hi: 'केवल आपके सेव किए गए अंगूर खेत रिकॉर्ड के आधार पर, रोज डायरी, खर्च, फोटो और बिल अपडेट करते रहें। ज्यादा रिकॉर्ड से सलाह बेहतर होगी।',
      kn: 'ನಿಮ್ಮ ಉಳಿಸಿದ ದ್ರಾಕ್ಷಿ ತೋಟದ ದಾಖಲೆಗಳ ಆಧಾರದಲ್ಲಿ ಮಾತ್ರ, ಪ್ರತಿದಿನ ಡೈರಿ, ಖರ್ಚು, ಫೋಟೋ ಮತ್ತು ಬಿಲ್ ನವೀಕರಿಸಿ. ಹೆಚ್ಚು ದಾಖಲೆಗಳಿಂದ ಸಲಹೆ ಉತ್ತಮವಾಗುತ್ತದೆ.',
    );
  }

  String _localized(
    String languageCode, {
    required String en,
    required String hi,
    required String kn,
  }) {
    return switch (languageCode) {
      'hi' => hi,
      'kn' => kn,
      _ => en,
    };
  }
}
