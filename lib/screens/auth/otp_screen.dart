import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_setup_screen.dart';
import '../../main.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  String _errorMessage = '';

  String get _otpCode => _controllers.map((c) => c.text).join();

  Future<void> _verifyOTP() async {
    if (_otpCode.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _otpCode,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final uid = userCredential.user!.uid;

      // Check if profile already exists in Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (mounted) {
        if (userDoc.exists) {
          // Profile exists → go to home based on role
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const AuthWrapper()),
            (route) => false,
          );
        } else {
          // New user → go to profile setup
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.message ?? 'Invalid OTP. Please try again.';
      });
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isNotEmpty && index == 5) {
      _verifyOTP();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Enter OTP',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit OTP to\n${widget.phoneNumber}',
                style: const TextStyle(fontSize: 15, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 45,
                    height: 56,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 2),
                        ),
                      ),
                      onChanged: (value) => _onDigitChanged(index, value),
                    ),
                  );
                }),
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Verify OTP', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}