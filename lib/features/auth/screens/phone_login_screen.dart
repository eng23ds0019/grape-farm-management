import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../core/localization/translations.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../widgets/app_button.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _error = "";
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin(String langCode) async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (phone.isEmpty || phone.length < 10) {
      setState(() {
        _error = langCode == 'kn-IN'
            ? "ದಯವಿಟ್ಟು ಮಾನ್ಯವಾದ ಮೊಬೈಲ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ"
            : (langCode == 'hi-IN' ? "कृपया एक मान्य मोबाइल नंबर दर्ज करें" : "Please enter a valid 10-digit mobile number");
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _error = langCode == 'kn-IN'
            ? "ದಯವಿಟ್ಟು ಪಾಸ್‌ವರ್ಡ್ ನಮೂದಿಸಿ"
            : (langCode == 'hi-IN' ? "कृपया पासवर्ड दर्ज करें" : "Please enter password");
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = "";
    });

    final authService = Provider.of<FirebaseAuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final fullNumber = phone.startsWith('+') ? phone : "+91$phone";

    // Disable mock mode if Firebase is available and they are logging in with a custom account
    if (Firebase.apps.isNotEmpty && (phone != "9876543210" || password != "MockPassword123!")) {
      await authService.setMockMode(false);
    }

    bool success = await authService.signInWithPhoneAndPassword(
      phoneNumber: fullNumber,
      password: password,
      onError: (err) {
        setState(() {
          _error = err;
        });
      },
    );

    if (success && mounted) {
      final uid = authService.currentUid;
      if (uid != null) {
        // Fetch farmer profile and trigger background sync
        final farmer = await firestoreService.fetchFarmerProfile(uid);
        if (farmer != null) {
          await firestoreService.fetchAndSyncAllData(uid);
        }
      }

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;
      if (firestoreService.cachedFarmer != null && firestoreService.cachedFarmer!.name.isNotEmpty) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else {
        Navigator.pushReplacementNamed(context, '/farmer_profile');
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showForgotPasswordDialog(String langCode) {
    final TextEditingController resetPhoneController = TextEditingController();
    final TextEditingController resetOtpController = TextEditingController();
    final TextEditingController resetPasswordController = TextEditingController();
    final TextEditingController resetConfirmController = TextEditingController();

    bool otpSent = false;
    bool isDialogLoading = false;
    String dialogError = "";
    bool obscureNewPass = true;
    bool obscureNewConfirm = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                langCode == 'kn-IN'
                    ? (otpSent ? "ಒಟಿಪಿ ಮತ್ತು ಹೊಸ ಪಾಸ್‌ವರ್ಡ್" : "ಪಾಸ್‌ವರ್ಡ್ ಮರುಹೊಂದಿಸಿ")
                    : (langCode == 'hi-IN'
                        ? (otpSent ? "ओटीपी और नया पासवर्ड" : "पासवर्ड रीसेट करें")
                        : (otpSent ? "Verify OTP & Reset" : "Reset Password")),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!otpSent) ...[
                      Text(
                        langCode == 'kn-IN'
                            ? "ಒಟಿಪಿ ಪಡೆಯಲು ನಿಮ್ಮ ನೋಂದಾಯಿತ ಮೊಬೈಲ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ."
                            : (langCode == 'hi-IN'
                                ? "ओटीपी प्राप्त करने के लिए अपना पंजीकृत मोबाइल नंबर दर्ज करें।"
                                : "Enter your registered mobile number to receive an SMS OTP code."),
                        style: const TextStyle(fontSize: 14, color: AppColors.textLight),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: resetPhoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        decoration: InputDecoration(
                          hintText: langCode == 'kn-IN' ? "ಮೊಬೈಲ್ ಸಂಖ್ಯೆ" : (langCode == 'hi-IN' ? "मोबाइल नंबर" : "Phone Number"),
                          counterText: "",
                        ),
                      ),
                    ] else ...[
                      Text(
                        langCode == 'kn-IN'
                            ? "ನಿಮ್ಮ ಮೊಬೈಲ್‌ಗೆ ಕಳುಹಿಸಲಾದ ಒಟಿಪಿ ಮತ್ತು ಹೊಸ ಸುರಕ್ಷಿತ ಪಾಸ್‌ವರ್ಡ್ ನಮೂದಿಸಿ."
                            : (langCode == 'hi-IN'
                                ? "अपने मोबाइल पर भेजा गया ओटीपी और नया सुरक्षित पासवर्ड दर्ज करें।"
                                : "Enter the SMS OTP and your new secure password."),
                        style: const TextStyle(fontSize: 14, color: AppColors.textLight),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: resetOtpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 4),
                        decoration: const InputDecoration(
                          hintText: "6-Digit OTP",
                          counterText: "",
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: resetPasswordController,
                        obscureText: obscureNewPass,
                        decoration: InputDecoration(
                          labelText: langCode == 'kn-IN' ? "ಹೊಸ ಪಾಸ್‌ವರ್ಡ್" : (langCode == 'hi-IN' ? "नया पासवर्ड" : "New Password"),
                          prefixIcon: const Icon(Icons.lock, color: AppColors.primaryGreen),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNewPass ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.primaryGreen,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                obscureNewPass = !obscureNewPass;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: resetConfirmController,
                        obscureText: obscureNewConfirm,
                        decoration: InputDecoration(
                          labelText: langCode == 'kn-IN' ? "ಪಾಸ್‌ವರ್ಡ್ ಖಚಿತಪಡಿಸಿ" : (langCode == 'hi-IN' ? "पासवर्ड की पुष्टि करें" : "Confirm Password"),
                          prefixIcon: const Icon(Icons.lock_clock, color: AppColors.primaryGreen),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNewConfirm ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.primaryGreen,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                obscureNewConfirm = !obscureNewConfirm;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                    if (dialogError.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        dialogError,
                        style: const TextStyle(color: AppColors.errorRed, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                    if (isDialogLoading) ...[
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDialogLoading
                      ? null
                      : () {
                          Navigator.pop(context);
                          resetPhoneController.dispose();
                          resetOtpController.dispose();
                          resetPasswordController.dispose();
                          resetConfirmController.dispose();
                        },
                  child: Text(
                    langCode == 'kn-IN' ? "ರದ್ದುಮಾಡು" : (langCode == 'hi-IN' ? "ರद्द करें" : "Cancel"),
                    style: const TextStyle(color: AppColors.textLight),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
                  onPressed: isDialogLoading
                      ? null
                      : () async {
                          final authService = Provider.of<FirebaseAuthService>(context, listen: false);
                          setDialogState(() {
                            isDialogLoading = true;
                            dialogError = "";
                          });

                          if (!otpSent) {
                            final phone = resetPhoneController.text.trim();
                            if (phone.length < 10) {
                              setDialogState(() {
                                isDialogLoading = false;
                                dialogError = "Please enter a valid 10-digit number.";
                              });
                              return;
                            }
                            await authService.verifyPhoneForReset(
                              phoneNumber: phone,
                              onCodeSent: (verificationId) {
                                setDialogState(() {
                                  otpSent = true;
                                  isDialogLoading = false;
                                });
                              },
                              onError: (err) {
                                setDialogState(() {
                                  isDialogLoading = false;
                                  dialogError = err;
                                });
                              },
                            );
                          } else {
                            final code = resetOtpController.text.trim();
                            final pass = resetPasswordController.text;
                            final confirm = resetConfirmController.text;

                            if (code.length < 6) {
                              setDialogState(() {
                                isDialogLoading = false;
                                dialogError = "Please enter a valid 6-digit OTP code.";
                              });
                              return;
                            }

                            if (pass.length < 8) {
                              setDialogState(() {
                                isDialogLoading = false;
                                dialogError = "Password must be at least 8 characters.";
                              });
                              return;
                            }

                            if (pass != confirm) {
                              setDialogState(() {
                                isDialogLoading = false;
                                dialogError = "Passwords do not match.";
                              });
                              return;
                            }

                            await authService.verifyOtpAndResetPassword(
                              smsCode: code,
                              newPassword: pass,
                              onSuccess: (msg) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(msg), backgroundColor: AppColors.primaryGreen),
                                );
                                resetPhoneController.dispose();
                                resetOtpController.dispose();
                                resetPasswordController.dispose();
                                resetConfirmController.dispose();
                              },
                              onError: (err) {
                                setDialogState(() {
                                  isDialogLoading = false;
                                  dialogError = err;
                                });
                              },
                            );
                          }
                        },
                  child: Text(
                    !otpSent
                        ? (langCode == 'kn-IN' ? "ಒಟಿಪಿ ಕಳುಹಿಸಿ" : (langCode == 'hi-IN' ? "ओटीपी भेजें" : "Send OTP"))
                        : (langCode == 'kn-IN' ? "ಪಾಸ್‌ವರ್ಡ್ ಬದಲಾಯಿಸಿ" : (langCode == 'hi-IN' ? "पासवर्ड बदलें" : "Reset Password")),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Provider.of<LanguageNotifier>(context).currentLanguage;

    final title = langCode == 'kn-IN' ? "ಲಾಗಿನ್ ಮಾಡಿ" : (langCode == 'hi-IN' ? "लॉगिन करें" : "Farmer Login");
    final desc = langCode == 'kn-IN' ? "ನಿಮ್ಮ ಮೊಬೈಲ್ ಸಂಖ್ಯೆ ಮತ್ತು ಪಾಸ್‌ವರ್ಡ್ ಬಳಸಿ ಲಾಗಿನ್ ಮಾಡಿ" : (langCode == 'hi-IN' ? "अपने मोबाइल नंबर और पासवर्ड का उपयोग करके लॉगिन करें" : "Log in using your phone number and password");

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
                    Icons.agriculture,
                    size: 55,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.earthyBrown,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                desc,
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
                        hintText: AppTranslations.translate('phone_hint', langCode),
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
                  labelText: langCode == 'kn-IN' ? "ಪಾಸ್‌ವರ್ಡ್" : (langCode == 'hi-IN' ? "पासवर्ड" : "Password"),
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
              const SizedBox(height: 8),

              // Forgot Password link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showForgotPasswordDialog(langCode),
                  child: Text(
                    langCode == 'kn-IN' ? "ಪಾಸ್‌ವರ್ಡ್ ಮರೆತಿರಾ?" : (langCode == 'hi-IN' ? "पासवर्ड भूल गए?" : "Forgot Password?"),
                    style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    _error,
                    style: const TextStyle(color: AppColors.errorRed, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),

              AppButton(
                text: langCode == 'kn-IN' ? "ಲಾಗಿನ್" : (langCode == 'hi-IN' ? "लॉगिन" : "Login"),
                icon: Icons.login,
                isLoading: _isLoading,
                onPressed: () => _handleLogin(langCode),
              ),
              const SizedBox(height: 18),

              // Navigate to Registration
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  child: Text(
                    langCode == 'kn-IN'
                        ? "ಹೊಸ ಖಾತೆ ರಚಿಸಿ"
                        : (langCode == 'hi-IN' ? "नया खाता बनाएं" : "Create New Account"),
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Dynamic button to switch to Mock/Offline Demo Mode explicitly
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.swap_horizontal_circle_outlined, color: AppColors.primaryGreen),
                  label: Text(
                    langCode == 'kn-IN' 
                        ? "ಡೆಮೊ ಮೋಡ್ ಬಳಸಿ (ಆಫ್‌ಲೈನ್)" 
                        : (langCode == 'hi-IN' ? "डेमो मोड का उपयोग करें (ऑफलाइन)" : "Use Offline Demo Mode"),
                    style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: () {
                    final authService = Provider.of<FirebaseAuthService>(context, listen: false);
                    authService.setMockMode(true);
                    _phoneController.text = "9876543210";
                    _passwordController.text = "MockPassword123!";
                    _handleLogin(langCode);
                  },
                ),
              ),
              const SizedBox(height: 10),
              
              // Admin Access Button Link
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.admin_panel_settings, color: AppColors.accentPurple),
                  label: const Text(
                    "Admin Portal Login",
                    style: TextStyle(color: AppColors.accentPurple, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/admin');
                  },
                ),
              ),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }
}
