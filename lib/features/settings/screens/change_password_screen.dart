import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../widgets/app_button.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _isLoading = false;
  String _error = "";
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _isPasswordStrong(String password) {
    if (password.length < 8) return false;
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasLower = password.contains(RegExp(r'[a-z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    final hasSpecial = password.contains(RegExp(r'[^a-zA-Z0-9]'));
    return hasUpper && hasLower && hasDigit && hasSpecial;
  }

  void _handleChangePassword(String langCode, Map<String, String> trans) async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.isEmpty || confirm.isEmpty) {
      setState(() {
        _error = trans['empty_fields'] ?? "Please fill all fields.";
      });
      return;
    }

    if (!_isPasswordStrong(password)) {
      setState(() {
        _error = trans['pass_rule'] ?? "Password must contain at least 8 characters, an uppercase letter, a lowercase letter, a number, and a special character.";
      });
      return;
    }

    if (password != confirm) {
      setState(() {
        _error = trans['mismatch'] ?? "Passwords do not match.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = "";
    });

    final authService = Provider.of<FirebaseAuthService>(context, listen: false);

    bool success = await authService.changePassword(
      newPassword: password,
      onError: (err) {
        setState(() {
          // If session expired or requires recent login
          if (err.contains("requires-recent-login")) {
            _error = trans['recent_login'] ?? "Security limit reached. Please log out and log back in to change password.";
          } else {
            _error = err;
          }
        });
      },
    );

    setState(() {
      _isLoading = false;
    });

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(trans['success_msg'] ?? "Password changed successfully!"),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Provider.of<LanguageNotifier>(context).currentLanguage;

    final Map<String, Map<String, String>> localTranslations = {
      'en-IN': {
        'title': 'Change Password',
        'desc': 'Update your account security password',
        'password': 'New Password',
        'confirm_password': 'Confirm New Password',
        'update': 'Update Password',
        'pass_rule': 'Password must be at least 8 characters, with 1 uppercase, 1 lowercase, 1 number, and 1 special character.',
        'mismatch': 'Passwords do not match.',
        'empty_fields': 'Please fill all fields.',
        'success_msg': 'Password updated successfully!',
        'recent_login': 'Security verification required. Please logout and login again to change password.',
      },
      'kn-IN': {
        'title': 'ಪಾಸ್‌ವರ್ಡ್ ಬದಲಾಯಿಸಿ',
        'desc': 'ನಿಮ್ಮ ಖಾತೆಯ ಸುರಕ್ಷತಾ ಪಾಸ್‌ವರ್ಡ್ ಅಪ್‌ಡೇಟ್ ಮಾಡಿ',
        'password': 'ಹೊಸ ಪಾಸ್‌ವರ್ಡ್',
        'confirm_password': 'ಹೊಸ ಪಾಸ್‌ವರ್ಡ್ ಖಚಿತಪಡಿಸಿ',
        'update': 'ಪಾಸ್‌ವರ್ಡ್ ಅಪ್‌ಡೇಟ್ ಮಾಡಿ',
        'pass_rule': 'ಪಾಸ್‌ವರ್ಡ್ ಕನಿಷ್ಠ ೮ ಅಕ್ಷರಗಳು, ಒಂದು ದೊಡ್ಡ ಅಕ್ಷರ, ಒಂದು ಸಣ್ಣ ಅಕ್ಷರ, ಒಂದು ಸಂಖ್ಯೆ ಮತ್ತು ವಿಶೇಷ ಅಕ್ಷರವನ್ನು ಹೊಂದಿರಬೇಕು.',
        'mismatch': 'ಪಾಸ್‌ವರ್ಡ್‌ಗಳು ಹೊಂದಿಕೆಯಾಗುತ್ತಿಲ್ಲ.',
        'empty_fields': 'ದಯವಿಟ್ಟು ಎಲ್ಲಾ ಕ್ಷೇತ್ರಗಳನ್ನು ಭರ್ತಿ ಮಾಡಿ.',
        'success_msg': 'ಪಾಸ್‌ವರ್ಡ್ ಯಶಸ್ವಿಯಾಗಿ ಬದಲಾಯಿಸಲಾಗಿದೆ!',
        'recent_login': 'ಭದ್ರತಾ ಮಿತಿ ತಲುಪಿದೆ. ಪಾಸ್‌ವರ್ಡ್ ಬದಲಾಯಿಸಲು ದಯವಿಟ್ಟು ಲಾಗ್‌ಔಟ್ ಆಗಿ ಮತ್ತೊಮ್ಮೆ ಲಾಗಿನ್ ಮಾಡಿ.',
      },
      'hi-IN': {
        'title': 'पासवर्ड बदलें',
        'desc': 'अपना खाता सुरक्षा पासवर्ड अपडेट करें',
        'password': 'नया पासवर्ड',
        'confirm_password': 'नए पासवर्ड की पुष्टि करें',
        'update': 'पासवर्ड अपडेट करें',
        'pass_rule': 'पासवर्ड कम से कम 8 वर्णों का होना चाहिए, जिसमें एक बड़ा अक्षर, एक छोटा अक्षर, एक संख्या और एक विशेष वर्ण होना चाहिए।',
        'mismatch': 'पासवर्ड मेल नहीं खाते हैं।',
        'empty_fields': 'कृपया सभी क्षेत्र भरें।',
        'success_msg': 'पासवर्ड सफलतापूर्वक बदल दिया गया है!',
        'recent_login': 'सुरक्षा सीमा। पासवर्ड बदलने के लिए कृपया लॉगआउट करें और फिर से लॉगिन करें।',
      }
    };

    final trans = localTranslations[langCode] ?? localTranslations['en-IN']!;

    return Scaffold(
      appBar: AppBar(
        title: Text(trans['title']!),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                trans['desc']!,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 24),

              // New Password field
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: trans['password']!,
                  prefixIcon: const Icon(Icons.lock, color: AppColors.primaryGreen),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.primaryGreen,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Confirm New Password field
              TextField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: trans['confirm_password']!,
                  prefixIcon: const Icon(Icons.lock_clock, color: AppColors.primaryGreen),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.primaryGreen,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirm = !_obscureConfirm;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Text(
                trans['pass_rule']!,
                style: const TextStyle(fontSize: 12, color: AppColors.textLight, height: 1.3),
              ),
              const SizedBox(height: 24),

              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _error,
                    style: const TextStyle(color: AppColors.errorRed, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),

              AppButton(
                text: trans['update']!,
                icon: Icons.security,
                isLoading: _isLoading,
                onPressed: () => _handleChangePassword(langCode, trans),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
