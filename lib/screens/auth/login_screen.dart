import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _sendOTP() async {
    final phone = _phoneController.text.trim();

    if (phone.length != 10) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit number');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: '+91$phone',
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.message ?? 'Verification failed. Try again.';
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() => _isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(
              verificationId: verificationId,
              phoneNumber: '+91$phone',
            ),
          ),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              const Icon(Icons.apartment, size: 56, color: Color(0xFF1A73E8)),
              const SizedBox(height: 24),
              const Text(
                'Welcome to\nGateFlow',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your community, connected.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 48),
              const Text(
                'Enter your mobile number',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('+91', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: '10-digit mobile number',
                        counterText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Send OTP', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}