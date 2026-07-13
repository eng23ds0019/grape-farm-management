import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../widgets/app_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String _error = "";
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Strong password rule checker
  bool _isPasswordStrong(String password) {
    if (password.length < 8) return false;
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasLower = password.contains(RegExp(r'[a-z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    final hasSpecial = password.contains(RegExp(r'[^a-zA-Z0-9]'));
    return hasUpper && hasLower && hasDigit && hasSpecial;
  }

  void _handleRegister(String langCode, Map<String, String> trans) async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (phone.isEmpty || phone.length < 10) {
      setState(() {
        _error = langCode == 'kn-IN'
            ? "ದಯವಿಟ್ಟು ಮಾನ್ಯವಾದ ಮೊಬೈಲ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ"
            : (langCode == 'hi-IN' ? "कृपया एक मान्य मोबाइल नंबर दर्ज करें" : "Please enter a valid 10-digit mobile number");
      });
      return;
    }

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
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    // Disable mock mode for real registrations if Firebase is available
    if (Firebase.apps.isNotEmpty) {
      await authService.setMockMode(false);
    }

    // 1. Check if phone is already registered to prevent duplicates
    final exists = await firestoreService.checkPhoneExists(phone);
    if (exists) {
      setState(() {
        _isLoading = false;
        _error = trans['dup_phone'] ?? "This phone number is already registered.";
      });
      return;
    }

    // 2. Perform Firebase Auth Registration (Phone converted to email internally)
    final fullNumber = phone.startsWith('+') ? phone : "+91$phone";
    bool success = await authService.registerWithPhoneAndPassword(
      phoneNumber: fullNumber,
      password: password,
      onError: (err) {
        setState(() {
          _error = err;
        });
      },
    );

    setState(() {
      _isLoading = false;
    });

    if (success && mounted) {
      // Upon successful authentication, navigate to FarmerProfileScreen to capture name & village
      Navigator.pushReplacementNamed(context, '/farmer_profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Provider.of<LanguageNotifier>(context).currentLanguage;

    final Map<String, Map<String, String>> localTranslations = {
      'en-IN': {
        'title': 'Create Account',
        'desc': 'Register your phone number and secure password',
        'phone_hint': 'Phone Number',
        'password': 'Password',
        'confirm_password': 'Confirm Password',
        'register': 'Register',
        'have_account': 'Already have an account? Login',
        'pass_rule': 'Password must be at least 8 characters, with 1 uppercase, 1 lowercase, 1 number, and 1 special character.',
        'mismatch': 'Passwords do not match.',
        'dup_phone': 'This phone number is already registered.',
        'empty_fields': 'Please fill all fields.',
      },
      'kn-IN': {
        'title': 'ಖಾತೆಯನ್ನು ರಚಿಸಿ',
        'desc': 'ನಿಮ್ಮ ಮೊಬೈಲ್ ಸಂಖ್ಯೆ ಮತ್ತು ಪಾಸ್‌ವರ್ಡ್ ನೋಂದಾಯಿಸಿ',
        'phone_hint': 'ಮೊಬೈಲ್ ಸಂಖ್ಯೆ',
        'password': 'ಪಾಸ್‌ವರ್ಡ್',
        'confirm_password': 'ಪಾಸ್‌ವರ್ಡ್ ಖಚಿತಪಡಿಸಿ',
        'register': 'ನೋಂದಾಯಿಸಿ',
        'have_account': 'ಈಗಾಗಲೇ ಖಾತೆ ಇದೆಯೇ? ಲಾಗಿನ್ ಮಾಡಿ',
        'pass_rule': 'ಪಾಸ್‌ವರ್ಡ್ ಕನಿಷ್ಠ ೮ ಅಕ್ಷರಗಳು, ಒಂದು ದೊಡ್ಡ ಅಕ್ಷರ, ಒಂದು ಸಣ್ಣ ಅಕ್ಷರ, ಒಂದು ಸಂಖ್ಯೆ ಮತ್ತು ವಿಶೇಷ ಅಕ್ಷರವನ್ನು ಹೊಂದಿರಬೇಕು.',
        'mismatch': 'ಪಾಸ್‌ವರ್ಡ್‌ಗಳು ಹೊಂದಿಕೆಯಾಗುತ್ತಿಲ್ಲ.',
        'dup_phone': 'ಈ ಮೊಬೈಲ್ ಸಂಖ್ಯೆ ಈಗಾಗಲೇ ನೋಂದಾಯಿಸಲ್ಪಟ್ಟಿದೆ.',
        'empty_fields': 'ದಯವಿಟ್ಟು ಎಲ್ಲಾ ಕ್ಷೇತ್ರಗಳನ್ನು ಭರ್ತಿ ಮಾಡಿ.',
      },
      'hi-IN': {
        'title': 'खाता बनाएं',
        'desc': 'अपना मोबाइल नंबर और पासवर्ड दर्ज करें',
        'phone_hint': 'मोबाइल नंबर',
        'password': 'पासवर्ड',
        'confirm_password': 'पासवर्ड की पुष्टि करें',
        'register': 'पंजीकरण करें',
        'have_account': 'पहले से खाता है? लॉगिन करें',
        'pass_rule': 'पासवर्ड कम से कम 8 वर्णों का होना चाहिए, जिसमें एक बड़ा अक्षर, एक छोटा अक्षर, एक संख्या और एक विशेष वर्ण होना चाहिए।',
        'mismatch': 'पासवर्ड मेल नहीं खाते हैं।',
        'dup_phone': 'यह मोबाइल नंबर पहले से पंजीकृत है।',
        'empty_fields': 'कृपया सभी क्षेत्र भरें।',
      }
    };

    final trans = localTranslations[langCode] ?? localTranslations['en-IN']!;

    return Scaffold(
      appBar: AppBar(
        title: Text(trans['title']!),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.earthyBrown,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.person_add,
                    size: 55,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                trans['title']!,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.earthyBrown,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                trans['desc']!,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 24),

              // Country Code & Phone Input Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: const Text(
                      "+91",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      decoration: InputDecoration(
                        hintText: trans['phone_hint']!,
                        counterText: "",
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Password field
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
              const SizedBox(height: 18),

              // Confirm Password field
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: trans['confirm_password']!,
                  prefixIcon: const Icon(Icons.lock_clock, color: AppColors.primaryGreen),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.primaryGreen,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
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
              const SizedBox(height: 18),

              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    _error,
                    style: const TextStyle(color: AppColors.errorRed, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),

              AppButton(
                text: trans['register']!,
                icon: Icons.person_add,
                isLoading: _isLoading,
                onPressed: () => _handleRegister(langCode, trans),
              ),
              const SizedBox(height: 18),

              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: Text(
                    trans['have_account']!,
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
