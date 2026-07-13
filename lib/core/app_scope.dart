import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/services/firebase_service.dart';

class AppScope extends InheritedNotifier<AppController> {
  AppScope({
    super.key,
    required FirebaseService firebase,
    required bool firebaseReady,
    required super.child,
  }) : super(
         notifier: AppController(
           firebase: firebase,
           firebaseReady: firebaseReady,
         ),
       );

  static AppController of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this context.');
    return scope!.notifier!;
  }
}

class AppController extends ChangeNotifier {
  AppController({required this.firebase, required this.firebaseReady});

  final FirebaseService firebase;
  final bool firebaseReady;

  String _languageCode = 'en';
  String get languageCode => _languageCode;

  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _languageCode = prefs.getString('preferredLanguage') ?? '';
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferredLanguage', code);
    _languageCode = code;
    notifyListeners();
  }

  bool get hasLanguage => _languageCode.isNotEmpty;
}
