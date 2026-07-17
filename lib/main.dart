import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'core/localization/language_notifier.dart';
import 'services/firebase_auth_service.dart';
import 'services/firestore_service.dart';
import 'services/speech_service.dart';
import 'services/storage_service.dart';
import 'services/openai_service.dart';
import 'services/gemini_service.dart';
import 'services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the OpenAI and Gemini API Keys from shared preferences
  try {
    final prefs = await SharedPreferences.getInstance();
    OpenAiService.openAiApiKey = prefs.getString('openai_api_key') ?? "";
    GeminiService.geminiApiKey = prefs.getString('gemini_api_key') ?? GeminiService.defaultApiKey;
  } catch (e) {
    debugPrint("Failed to load API Keys from SharedPreferences: $e");
  }

  // Try initializing Firebase, but catch configuration errors to enable mock mode out-of-the-box
  bool firebaseAvailable = false;
  try {
    await Firebase.initializeApp();
    firebaseAvailable = true;
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
      );
    } catch (e_appcheck) {
      debugPrint("Firebase App Check activation failed: $e_appcheck");
    }
  } catch (e) {
    debugPrint("Firebase init failed or credentials missing. Running in robust offline-first mode.");
  }

  // Initialize date formatting for all supported locales (prevents LocaleDataException).
  // We need BOTH the short code ('en','kn','hi') used by DateFormat AND the
  // regional codes ('en_IN','kn_IN','hi_IN') used elsewhere.
  for (final locale in ['en', 'en_IN', 'kn', 'kn_IN', 'hi', 'hi_IN']) {
    await initializeDateFormatting(locale, null);
  }

  // Pre-load the LanguageNotifier to read user preferred language
  final languageNotifier = LanguageNotifier();
  await languageNotifier.loadLanguage();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LanguageNotifier>.value(value: languageNotifier),
        ChangeNotifierProvider<FirebaseAuthService>(
          create: (_) {
            final service = FirebaseAuthService();
            if (!firebaseAvailable) {
              service.setMockMode(true);
            }
            return service;
          },
        ),
        ChangeNotifierProxyProvider<FirebaseAuthService, FirestoreService>(
          create: (_) {
            final service = FirestoreService();
            // If Firebase initialization failed, force mock mode to ensure zero crashing
            if (!firebaseAvailable) {
              service.setMockMode(true);
            } else {
              service.setMockMode(false);
            }
            return service;
          },
          update: (_, authService, firestoreService) {
            if (firestoreService != null) {
              if (authService.useMock && !firestoreService.useMock) {
                firestoreService.setMockMode(true);
              } else if (!authService.useMock && firestoreService.useMock) {
                firestoreService.setMockMode(false);
              }
              firestoreService.switchUser(authService.currentUid);
              
              if (authService.currentUid != null && !authService.useMock) {
                FcmService.initialize(authService.currentUid!);
              }
            }
            return firestoreService!;
          },
        ),
        Provider<StorageService>(
          create: (_) => StorageService(),
        ),
        ChangeNotifierProvider<SpeechService>(
          create: (_) => SpeechService(),
        ),
      ],
      child: const DrakshaDiaryApp(),
    ),
  );
}
