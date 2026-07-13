import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/l10n.dart';
import '../../data/services/auth_service.dart';
import '../../shared/widgets/premium_background.dart';

class PhoneLoginScreen extends StatefulWidget {
                decoration: InputDecoration(

  final AuthService auth;

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  String? _verificationId;
  bool _loading = false;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() => _loading = true);
    await widget.auth.verifyPhone(
      phoneNumber: _phone.text.trim(),
      onCodeSent: (id) {
        setState(() {
          _verificationId = id;
          _loading = false;
        });
      },
      onError: (message) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  Future<void> _verify() async {
    final id = _verificationId;
    if (id == null) return;
    setState(() => _loading = true);
    try {
      await widget.auth.signInWithO























































                  prefixIcon: const Icon(Icons.phone),
                  hintText: AppStrings.of(context, 'phoneHint'),
                ),
              ),
              const SizedBox(height: 14),
              if (_verificationId != null)
                TextField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.verified_user),
                    hintText: AppStrings.of(context, 'otpHint'),
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loading
                    ? null
                    : _verificationId == null
                    ? _sendOtp
                    : _verify,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sms),
                label: Text(
                  _verificationId == null
                      ? AppStrings.of(context, 'sendOtp')
                      : AppStrings.of(context, 'verifyOtp'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loading ? null : _anonymousLogin,
                icon: const Icon(Icons.person_pin),
                label: Text(AppStrings.of(context, 'continueWithoutOtp')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
