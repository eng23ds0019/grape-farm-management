import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/constants.dart';

class LanguageNotifier extends ChangeNotifier {
  String _currentLanguage = 'en-IN'; // Default to English (India)

  // Valid language codes from AppConstants
  static final Set<String> _validCodes =
      AppConstants.languages.map((l) => l['code']!).toSet();

  String get currentLanguage => _currentLanguage;

  LanguageNotifier() {
    loadLanguage();
  }

  // Load language from Shared Preferences
  Future<void> loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString('preferredLanguage');
      if (savedLang != null && _validCodes.contains(savedLang)) {
        _currentLanguage = savedLang;
        notifyListeners();
      } else if (savedLang != null) {
        // Saved value doesn't match any known code — reset to default
        await prefs.setString('preferredLanguage', _currentLanguage);
      }
    } catch (e) {
      // Handle preference read error gracefully
    }
  }

  // Save and set language
  Future<void> setLanguage(String langCode) async {
    if (_currentLanguage != langCode) {
      _currentLanguage = langCode;
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('preferredLanguage', langCode);
      } catch (e) {
        // Handle preference write error gracefully
      }
    }
  }
}
