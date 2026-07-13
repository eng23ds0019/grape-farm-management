import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/app_theme.dart';
import '../core/l10n.dart';
import '../data/models/farm.dart';
import '../data/models/farmer_profile.dart';
import '../data/services/ai_advisor_service.dart';
import '../data/services/analytics_service.dart';
import '../data/services/auth_service.dart';
import '../data/services/farm_repository.dart';
import '../data/services/local_sync_service.dart';
import '../data/services/media_service.dart';
import '../data/services/ocr_service.dart';
import '../data/services/speech_service.dart';
import '../shared/widgets/premium_background.dart';
import 'auth/language_selection_screen.dart';
import 'auth/phone_login_screen.dart';
import 'dashboard/main_shell.dart';
import 'profile/farm_profile_screen.dart';
import 'profile/profile_screen.dart';

class AppFlow extends StatefulWidget {
  const AppFlow({super.key});

  @override
  State<AppFlow> createState() => _AppFlowState();
}

class _AppFlowState extends State<AppFlow> {
  late final AuthService auth;
  late final AnalyticsService analytics;
  late final LocalSyncService localSync;
  late final FarmRepository repository;
  late final MediaService media;
  late final OcrService ocr;
  late final SpeechService speech;
  late final AiAdvisorService aiAdvisor;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final scope = AppScope.of(context);
    auth = AuthService(scope.firebase);
    analytics = AnalyticsService(scope.firebase);
    localSync = LocalSyncService();
    repository = FarmRepository(
      firebase: scope.firebase,
      localSync: localSync,
      analytics: analytics,
    );
    media = MediaService(scope.firebase, analytics);
    ocr = OcrService();
    speech = SpeechService();
    aiAdvisor = AiAdvisorService();
    _load();
  }

  Future<void> _load() async {
    await AppScope.of(context).loadLanguage();
    if (mounted) setState(() => _loaded = true);
    localSync.onlineChanges().listen((online) {
      if (online) repository.flushOfflineQueue();
    });
  }

  @override
  void dispose() {
    ocr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    if (!_loaded) return const SplashScreen();
    if (!scope.hasLanguage) {
      return LanguageSelectionScreen(
        onSelected: (code) async => scope.setLanguage(code),
      );
    }
    if (!scope.firebaseReady) return const FirebaseSetupScreen();

    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data ?? auth.currentUser;
        if (user == null) return PhoneLoginScreen(auth: auth);
        return _ProfileGate(
          user: user,
          repository: repository,
          auth: auth,
          analytics: analytics,
          media: media,
          ocr: ocr,
          speech: speech,
          aiAdvisor: aiAdvisor,
        );
      },
    );
  }
}













































































      ),
    );
  }
}

class _ProfileGate extends StatelessWidget {
  const _ProfileGate({
    required this.user,
    required this.repository,
    required this.auth,
    required this.analytics,
    required this.media,
    required this.ocr,
    required this.speech,
    required this.aiAdvisor,
  });

  final User user;
  final FarmRepository repository;
  final AuthService auth;
  final AnalyticsService analytics;
  final MediaService media;
  final OcrService ocr;
  final SpeechService speech;
  final AiAdvisorService aiAdvisor;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FarmerProfile?>(
      stream: repository.profileStream(user.uid),
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data;
        if (profile == null) {
          return ProfileScreen(user: user, repository: repository);
        }
        return StreamBuilder<List<Farm>>(
          stream: repository.farmsStream(user.uid),
          builder: (context, farmSnapshot) {
            final farms = farmSnapshot.data ?? const <Farm>[];
            if (farms.isEmpty) {
              return FarmProfileScreen(
                farmerId: user.uid,
                repository: repository,
              );
            }
            return MainShell(
              profile: profile,
              farm: farms.first,
              repository: repository,
              auth: auth,
              analytics: analytics,
              media: media,
              ocr: ocr,
              speech: speech,
              aiAdvisor: aiAdvisor,
            );
          },
        );
      },
    );
  }
}
