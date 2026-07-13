import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_service.dart';

class AuthService {
  AuthService(this.firebase);

  final FirebaseService firebase;

  Stream<User?> authStateChanges() {
    if (!firebase.ready) return const Stream<User?>.empty();
    return firebase.auth.authStateChanges();
  }

  User? get currentUser => firebase.ready ? firebase.auth.currentUser : null;

  Future<void> verifyPhone({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
  }) async {
    await firebase.auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        await firebase.auth.signInWithCredential(credential);
      },
      verificationFailed: (error) => onError(error.message ?? error.code),
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> signInWithOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await firebase.auth.signInWithCredential(credential);
  }

  Future<void> signInAnonymously() async {
    await firebase.auth.signInAnonymously();
  }

  Future<void> signOut() async {
    await firebase.auth.signOut();
  }
}
