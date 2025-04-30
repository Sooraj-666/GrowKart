import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';

class OtpService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Generate a 6-digit OTP
  String generateOTP() {
    return (100000 + Random().nextInt(900000)).toString();
  }

  // Send OTP via Firebase Phone Authentication
  Future<void> sendOTP(String phoneNumber) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-sign in on verification completed
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        print('OTP Verification Failed: ${e.message}');
        throw e;
      },
      codeSent: (String verificationId, int? resendToken) {
        // Store verification ID for later use
        print('Verification ID: $verificationId');
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Handle auto-retrieval timeout
        print('OTP Auto Retrieval Timeout');
      },
    );
  }

  // Verify OTP
  Future<bool> verifyOTP(String verificationId, String smsCode) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId, 
        smsCode: smsCode
      );
      await _auth.signInWithCredential(credential);
      return true;
    } catch (e) {
      print('OTP Verification Error: $e');
      return false;
    }
  }
}
