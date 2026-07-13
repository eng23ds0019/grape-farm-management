import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:draksha_farm_diary/app/app.dart';
import 'package:draksha_farm_diary/core/localization/language_notifier.dart';
import 'package:draksha_farm_diary/services/firebase_auth_service.dart';
import 'package:draksha_farm_diary/services/firestore_service.dart';
import 'package:draksha_farm_diary/services/speech_service.dart';
import 'package:draksha_farm_diary/services/storage_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Draksha Diary App boots up and displays splash screen', (WidgetTester tester) async {
    final languageNotifier = LanguageNotifier();
    
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LanguageNotifier>.value(value: languageNotifier),
          ChangeNotifierProvider<FirebaseAuthService>(
            create: (_) => FirebaseAuthService(),
          ),
          ChangeNotifierProvider<FirestoreService>(
            create: (_) => FirestoreService()..setMockMode(true),
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

    // Verify splash screen or MaterialApp is rendered.
    expect(find.byType(MaterialApp), findsOneWidget);
    
    // Trigger dynamic animation timing for the splash screen
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
  });
}
