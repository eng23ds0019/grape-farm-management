import 'package:intl/intl.dart';

class DateFormatter {
  /// Converts a YYYY-MM-DD string into a friendly localized string like "Today", "Yesterday", or "May 20, 2026".
  static String formatFarmerFriendly(String dateStr, String languageCode) {
    try {
      if (dateStr.isEmpty) return "";
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final compareDate = DateTime(date.year, date.month, date.day);

      if (compareDate == today) {
        if (languageCode == 'kn-IN') return "ಇಂದು (Today)";
        if (languageCode == 'hi-IN') return "आज (Today)";
        return "Today";
      } else if (compareDate == yesterday) {
        if (languageCode == 'kn-IN') return "ನಿನ್ನೆ (Yesterday)";
        if (languageCode == 'hi-IN') return "कल (Yesterday)";
        return "Yesterday";
      }

      // Standard Format
      String locale = 'en';
      if (languageCode == 'kn-IN') locale = 'kn';
      if (languageCode == 'hi-IN') locale = 'hi';

      try {
        return DateFormat.yMMMMd(locale).format(date);
      } catch (_) {
        // Fallback to English if locale data isn't loaded for this locale
        return DateFormat.yMMMMd('en').format(date);
      }
    } catch (e) {
      return dateStr;
    }
  }

  /// Parses date into short format
  static String formatShortDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
}
