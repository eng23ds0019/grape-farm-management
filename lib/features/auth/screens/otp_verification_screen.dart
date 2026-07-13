import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../core/localization/translations.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../widgets/app_button.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  String _error = "";
  int _secondsRemaining = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _secondsRemaining = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        setState(() {
          _timer?.cancel();
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _handleVerifyOtp(String langCode) async {
    final code = _otpController.text.trim();
    if (code.isEmpty || code.length < 6) {
      setState(() {
        _error = langCode == 'kn-IN'
            ? "ದಯವಿಟ್ಟು ೬-ಅಂಕಿಯ ಒಟಿಪಿ ನಮೂದಿಸಿ"
            : (langCode == 'hi-IN' ? "कृपया ६-अंकीय ओटीपी दर्ज करें" : "Please enter the 6-digit verification code");
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = "";
    });

    final authService = Provider.of<FirebaseAuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    bool success = await authService.verifyOtp(code);
    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;
    if (success) {
      // Check if profile exists
      if (firestoreService.cachedFarmer != null && firestoreService.cachedFarmer!.name.isNotEmpty) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else {
        Navigator.pushReplacementNamed(context, '/farmer_profile');
      }
    } else {
      setState(() {
        _error = langCode == 'kn-IN'
            ? "ತಪ್ಪಾದ ಒಟಿಪಿ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ."
            : (langCode == 'hi-IN' ? "गलत ओटीपी। कृपया पुनः प्रयास करें।" : "Invalid OTP code. Please try again.");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Provider.of<LanguageNotifier>(context).currentLanguage;
    final authService = Provider.of<FirebaseAuthService>(context);
    final firebaseError = authService.firebaseError;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.translate('verify_otp', langCode)),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.earthyBrown,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Padlock illustration
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security,
                    size: 60,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                AppTranslations.translate('verify_otp', langCode),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.earthyBrown,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppTranslations.translate('otp_desc', langCode),
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textLight,
                ),
              ),
              if (firebaseError != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              langCode == 'kn-IN'
                                  ? "ಫೈರ್‌ಬೇಸ್ ದೋಷ ಕಂಡುಬಂದಿದೆ!"
                                  : (langCode == 'hi-IN' ? "फायरबेस त्रुटि पाई गई!" : "Firebase Error Detected!"),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        langCode == 'kn-IN'
                            ? "ದೋಷದ ವಿವರ: $firebaseError\n\nಎಸ್‌ಎಂಎಸ್ ಕಳುಹಿಸಲು ಸಾಧ್ಯವಾಗುತ್ತಿಲ್ಲ. ಆದರೆ ಚಿಂತಿಸಬೇಡಿ! ನಾವು ಆಫ್‌ಲೈನ್ ಡೆಮೊ ಮೋಡ್ ಅನ್ನು ಸಕ್ರಿಯಗೊಳಿಸಿದ್ದೇವೆ. ಲಾಗಿನ್ ಮಾಡಲು ದಯವಿಟ್ಟು ಒಟಿಪಿ ಸಂಖ್ಯೆ '123456' ನಮೂದಿಸಿ."
                            : (langCode == 'hi-IN'
                                ? "त्रुटि विवरण: $firebaseError\n\nएसएमएस भेजने में असमर्थ। चिंता न करें! हमने ऑफ़लाइन डेमो मोड सक्रिय कर दिया है। लॉगिन करने के लिए कृपया ओटीपी '123456' दर्ज करें।"
                                : "Details: $firebaseError\n\nUnable to send SMS. Don't worry! We have automatically switched to Offline Demo Mode. Please enter OTP code '123456' to log in instantly."),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.amber.shade900,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 30),

              // OTP Input Field
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: AppColors.primaryGreen,
                ),
                decoration: InputDecoration(
                  hintText: AppTranslations.translate('otp_hint', langCode),
                  hintStyle: const TextStyle(letterSpacing: 2, fontSize: 18),
                  counterText: "",
                ),
              ),
              const SizedBox(height: 12),

              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    _error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.errorRed,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              const SizedBox(height: 20),
              // Resend code option (mock/placeholder)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppTranslations.translate('resend_otp', langCode),
                    style: const TextStyle(color: AppColors.textLight, fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _secondsRemaining > 0 
                        ? "00:${_secondsRemaining.toString().padLeft(2, '0')}" 
                        : (langCode == 'kn-IN' ? "ಮರುಕಳುಹಿಸಿ" : (langCode == 'hi-IN' ? "पुनः भेजें" : "Resend")),
                    style: TextStyle(
                      color: _secondsRemaining > 0 ? AppColors.primaryGreen : AppColors.accentPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              AppButton(
                text: AppTranslations.translate('submit', langCode),
                icon: Icons.check,
                isLoading: _isLoading,
                onPressed: () => _handleVerifyOtp(langCode),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
