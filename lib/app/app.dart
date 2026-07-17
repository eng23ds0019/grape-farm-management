import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/splash/screens/splash_screen.dart';
import '../features/language/screens/language_selection_screen.dart';
import '../features/auth/screens/phone_login_screen.dart';
import '../features/auth/screens/otp_verification_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/admin_login_screen.dart';
import '../features/farmer_profile/screens/farmer_profile_screen.dart';
import '../features/settings/screens/change_password_screen.dart';
import '../features/farm_profile/screens/farm_profile_screen.dart';
import '../features/diary/screens/home_dashboard.dart';
import '../features/diary/screens/add_diary_entry_screen.dart';
import '../features/diary/screens/diary_detail_screen.dart';
import '../features/diary/screens/turnover_screen.dart';
import '../features/voice/screens/voice_recording_screen.dart';
import '../features/expenses/screens/manual_expense_screen.dart';
import '../features/bills/screens/bill_scanner_screen.dart';
import '../features/bills/screens/bill_confirmation_screen.dart';
import '../features/backup/screens/backup_status_screen.dart';
import '../features/privacy/screens/privacy_consent_screen.dart';
import '../features/reports/screens/share_report_screen.dart';
import '../features/photos/screens/photo_gallery_screen.dart';
import '../features/draksha_ai/screens/voice_engine_screen.dart';
import '../models/diary_entry_model.dart';

class DrakshaDiaryApp extends StatelessWidget {
  const DrakshaDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Soudi Farming',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      onGenerateRoute: (RouteSettings settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          case '/language':
            return MaterialPageRoute(builder: (_) => const LanguageSelectionScreen());
          case '/login':
            return MaterialPageRoute(builder: (_) => const PhoneLoginScreen());
          case '/register':
            return MaterialPageRoute(builder: (_) => const RegisterScreen());
          case '/change_password':
            return MaterialPageRoute(builder: (_) => const ChangePasswordScreen());
          case '/otp':
            return MaterialPageRoute(builder: (_) => const OtpVerificationScreen());
          case '/farmer_profile':
            return MaterialPageRoute(builder: (_) => const FarmerProfileScreen());
          case '/farm_profile':
            return MaterialPageRoute(builder: (_) => const FarmProfileScreen());
          case '/home':
            return MaterialPageRoute(builder: (_) => const HomeDashboard());
          
          case '/add_diary':
            final args = settings.arguments;
            String farmId = "";
            if (args is String) {
              farmId = args;
            } else if (args is Map<String, dynamic>) {
              farmId = args['farmId'] ?? "";
            }
            return MaterialPageRoute(
              builder: (_) => AddDiaryEntryScreen(farmId: farmId),
            );

          case '/turnover':
            final farmId = settings.arguments as String? ?? "plot_1";
            return MaterialPageRoute(
              builder: (_) => TurnoverScreen(farmId: farmId),
            );

          case '/diary_detail':
            final entry = settings.arguments as DiaryEntryModel;
            return MaterialPageRoute(
              builder: (_) => DiaryDetailScreen(entry: entry),
            );

          case '/voice_record':
            final farmId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => VoiceRecordingScreen(farmId: farmId),
            );

          case '/manual_expense':
            final farmId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => ManualExpenseScreen(farmId: farmId),
            );

          case '/bill_scanner':
            final farmId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => BillScannerScreen(farmId: farmId),
            );

          case '/bill_confirm':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => BillConfirmationScreen(args: args),
              settings: settings,
            );

          case '/backup_status':
            return MaterialPageRoute(builder: (_) => const BackupStatusScreen());

          case '/privacy_consent':
            return MaterialPageRoute(builder: (_) => const PrivacyConsentScreen());

          case '/share_report':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => ShareReportScreen(args: args),
            );

          case '/photo_gallery':
            final farmId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => PhotoGalleryScreen(farmId: farmId),
            );

          case '/chatbot':
            final farmId = settings.arguments as String? ?? "plot_1";
            return MaterialPageRoute(
              builder: (_) => VoiceEngineScreen(selectedFarmId: farmId),
            );

          case '/admin':
            return MaterialPageRoute(builder: (_) => const AdminLoginScreen());

          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text("Route not defined")),
              ),
            );
        }
      },
    );
  }
}
