import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'document_ai_service.dart';

class FirebaseAuthService extends ChangeNotifier {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  bool _useMock = false; // Use live Firebase Auth by default when configuration is ready
  String? firebaseError; // Stores real Firebase connection/auth error details
  
  String? _verificationId;
  String? _resetVerificationId;
  String? _mockPhoneNumber;
  bool _isLoggedIn = false;
  String? _customUid;

  bool get useMock => _useMock;
  bool get isLoggedIn => _isLoggedIn || (!_useMock && _auth.currentUser != null);
  String? get currentUid => _useMock ? (_customUid ?? "mock_farmer_patil") : _auth.currentUser?.uid;
  String? get currentPhoneNumber => _useMock 
      ? _mockPhoneNumber 
      : (_auth.currentUser?.email != null ? _auth.currentUser!.email!.split('@')[0] : null);

  FirebaseAuthService() {
    _checkSavedLogin();
    _auth.authStateChanges().listen((User? user) {
      debugPrint("FirebaseAuthService: authStateChanges fired. User: ${user?.uid}");
      notifyListeners();
    });
  }

  // Set mock mode status and persist it
  Future<void> setMockMode(bool val) async {
    _useMock = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('useMock', val);
    } catch (e) {
      debugPrint("Failed to save useMock preference: $e");
    }
    if (val && _isLoggedIn) {
      signInAnonymouslyIfNeeded();
    }
    notifyListeners();
  }

  // Background anonymous sign-in to support live writes to Cloud Firestore during demo mode
  Future<void> signInAnonymouslyIfNeeded() async {
    if (!_useMock) return;
    try {
      if (_auth.currentUser == null) {
        final credential = await _auth.signInAnonymously();
        if (credential.user?.uid != null) {
          _customUid = credential.user!.uid;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('customUid', _customUid!);
        }
      } else {
        _customUid = _auth.currentUser?.uid;
      }
    } catch (e) {
      debugPrint("Firebase background anonymous auth failed: $e");
    }
  }

  Future<void> _checkSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    _useMock = prefs.getBool('useMock') ?? false; // Restore mock mode state!
    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    _customUid = prefs.getString('customUid') ?? "mock_farmer_patil";
    _mockPhoneNumber = prefs.getString('mockPhone') ?? "+919876543210";
    if (_isLoggedIn && _useMock) {
      await signInAnonymouslyIfNeeded();
    }
    notifyListeners();
  }

  // Convert phone number to generated email address
  String _phoneToEmail(String phoneNumber) {
    // Standardize number (remove spaces/dashes, ensure starts with +91)
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[\s\-()]+'), '');
    final formatted = cleanPhone.startsWith('+') ? cleanPhone : "+91$cleanPhone";
    return "$formatted@dailyfarm.app";
  }

  // Register with phone number and password internally
  Future<bool> registerWithPhoneAndPassword({
    required String phoneNumber,
    required String password,
    required Function(String error) onError,
  }) async {
    final email = _phoneToEmail(phoneNumber);
    if (_useMock) {
      _mockPhoneNumber = phoneNumber.startsWith('+') ? phoneNumber : "+91$phoneNumber";
      _isLoggedIn = true;
      _customUid = "mock_farmer_${_mockPhoneNumber?.replaceAll('+', '') ?? 'patil'}";
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('customUid', _customUid!);
      await prefs.setString('mockPhone', _mockPhoneNumber!);
      await signInAnonymouslyIfNeeded();
      notifyListeners();
      return true;
    }

    firebaseError = null;
    notifyListeners();

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        notifyListeners();
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase registration failed: ${e.code} - ${e.message}");
      firebaseError = e.message ?? e.code;
      onError(firebaseError!);
      return false;
    } catch (e) {
      debugPrint("Registration error: $e");
      firebaseError = e.toString();
      onError(firebaseError!);
      return false;
    }
  }

  // Sign in with phone number and password internally
  Future<bool> signInWithPhoneAndPassword({
    required String phoneNumber,
    required String password,
    required Function(String error) onError,
  }) async {
    final email = _phoneToEmail(phoneNumber);
    if (_useMock) {
      _mockPhoneNumber = phoneNumber.startsWith('+') ? phoneNumber : "+91$phoneNumber";
      _isLoggedIn = true;
      _customUid = "mock_farmer_${_mockPhoneNumber?.replaceAll('+', '') ?? 'patil'}";
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('customUid', _customUid!);
      await prefs.setString('mockPhone', _mockPhoneNumber!);
      await signInAnonymouslyIfNeeded();
      notifyListeners();
      return true;
    }

    firebaseError = null;
    notifyListeners();

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        notifyListeners();
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase sign-in failed: ${e.code} - ${e.message}");
      firebaseError = e.message ?? e.code;
      onError(firebaseError!);
      return false;
    } catch (e) {
      debugPrint("Sign-in error: $e");
      firebaseError = e.toString();
      onError(firebaseError!);
      return false;
    }
  }

  // Step 1: Initiate SMS Verification for Forgot Password
  Future<void> verifyPhoneForReset({
    required String phoneNumber,
    required Function(String code) onCodeSent,
    required Function(String error) onError,
  }) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[\s\-()]+'), '');
    final formatted = cleanPhone.startsWith('+') ? cleanPhone : "+91$cleanPhone";

    if (_useMock) {
      _mockPhoneNumber = formatted;
      _resetVerificationId = "mock_reset_123456";
      onCodeSent("123456");
      return;
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: formatted,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Automatic verification callback
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint("Reset SMS verification failed: ${e.code} - ${e.message}");
          onError(e.message ?? e.code);
        },
        codeSent: (String verificationId, int? resendToken) {
          _resetVerificationId = verificationId;
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _resetVerificationId = verificationId;
        },
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  // Step 2: Verify the OTP SMS code and update the email account's password securely
  Future<bool> verifyOtpAndResetPassword({
    required String smsCode,
    required String newPassword,
    required Function(String successMsg) onSuccess,
    required Function(String error) onError,
  }) async {
    if (_useMock) {
      if (smsCode == "123456" || smsCode == "000000") {
        onSuccess("Mock Mode: Password reset successful. Please login with your new password.");
        return true;
      }
      onError("Invalid OTP SMS code entered.");
      return false;
    }

    if (_resetVerificationId == null) {
      onError("Verification session expired. Please request a new OTP.");
      return false;
    }

    try {
      // 1. Create phone auth credential
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _resetVerificationId!,
        smsCode: smsCode,
      );

      // 2. Sign in temporarily via Phone Auth
      final userCredential = await _auth.signInWithCredential(credential);
      final phoneUser = userCredential.user;
      if (phoneUser == null) {
        throw FirebaseAuthException(code: "auth-failed", message: "Failed to verify phone ownership.");
      }

      // 3. Obtain Firebase ID Token
      final idToken = await phoneUser.getIdToken();
      
      // 4. Send request to FastAPI backend
      final base = DocumentAiService.backendUrl.replaceAll('/api/v1/extract', '');
      final resetUrl = "$base/api/v1/auth/reset-password";
      
      debugPrint("FirebaseAuthService: Requesting password reset from $resetUrl");
      final response = await http.post(
        Uri.parse(resetUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({"new_password": newPassword}),
      );

      // 5. Clean up temporary phone session immediately
      await _auth.signOut();

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        onSuccess(decoded["message"] ?? "Password successfully reset. Please log in.");
        return true;
      } else {
        final decoded = jsonDecode(response.body);
        onError(decoded["detail"] ?? "Password reset failed at the server level.");
        return false;
      }
    } on FirebaseAuthException catch (e) {
      onError(e.message ?? e.code);
      return false;
    } catch (e) {
      debugPrint("Password reset request failed: $e");
      
      // If we are in development/testing mode, allow a mock fallback if the backend server is not running.
      if (kDebugMode) {
        debugPrint("Failsafe: Simulating successful password update locally.");
        onSuccess("Backend server offline. Simulating successful password reset locally for testing.");
        return true;
      }
      
      onError("Backend server is offline or unreachable. Please ensure your backend is running: $e");
      return false;
    }
  }

  // Change Password for currently active user session
  Future<bool> changePassword({
    required String newPassword,
    required Function(String error) onError,
  }) async {
    if (_useMock) {
      return true;
    }

    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
        return true;
      }
      onError("No active authenticated user session found.");
      return false;
    } on FirebaseAuthException catch (e) {
      firebaseError = e.message ?? e.code;
      onError(firebaseError!);
      return false;
    } catch (e) {
      firebaseError = e.toString();
      onError(firebaseError!);
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    if (_useMock) {
      _isLoggedIn = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
      notifyListeners();
      return;
    }

    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    notifyListeners();
  }

  // Deprecated: No longer used since shifting to Email/Password auth
  Future<void> verifyPhone({
    required String phoneNumber,
    required Function(String code) onCodeSent,
    required Function(String error) onError,
  }) async {
    onCodeSent("123456");
  }

  // Deprecated: No longer used since shifting to Email/Password auth
  Future<bool> verifyOtp(String smsCode) async {
    return smsCode == "123456";
  }
}
