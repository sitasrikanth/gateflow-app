import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../main.dart';
import 'login_screen.dart';

class PinEntryScreen extends StatefulWidget {
  const PinEntryScreen({super.key});

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  final List<String> _pin = [];
  String _errorMessage = '';
  int _attempts = 0;

  void _onDigitPressed(String digit) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin.add(digit);
      _errorMessage = '';
    });
    if (_pin.length == 4) {
      _verifyPin();
    }
  }

  void _onDeletePressed() {
    if (_pin.isEmpty) return;
    setState(() => _pin.removeLast());
  }

  Future<void> _verifyPin() async {
    await Future.delayed(const Duration(milliseconds: 200));
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('user_pin') ?? '';

    if (_pin.join() == savedPin) {
      await prefs.setBool('pin_verified_session', true);
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      }
    } else {
      _attempts++;
      setState(() {
        _pin.clear();
        _errorMessage = _attempts >= 3
            ? 'Too many attempts. Please login with OTP.'
            : 'Incorrect PIN. ${3 - _attempts} attempts left.';
      });
    }
  }

  Future<void> _loginWithOtp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_pin');
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.lock_outline,
                  size: 56, color: Color(0xFF1A73E8)),
              const SizedBox(height: 24),
              const Text(
                'Welcome back!',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A)),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your 4-digit PIN to continue',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 48),

              // PIN dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final filled = index < _pin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? const Color(0xFF1A73E8)
                          : Colors.grey.shade300,
                    ),
                  );
                }),
              ),

              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(_errorMessage,
                    style:
                        const TextStyle(color: Colors.red, fontSize: 13)),
              ],

              const SizedBox(height: 48),

              // Number pad
              _buildNumberPad(),

              const SizedBox(height: 16),

              // Forgot PIN
              TextButton(
                onPressed: _loginWithOtp,
                child: const Text(
                  'Forgot PIN? Login with OTP',
                  style: TextStyle(color: Color(0xFF1A73E8), fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    final buttons = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      children: buttons.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((label) {
            if (label.isEmpty) return const SizedBox(width: 80, height: 80);
            return GestureDetector(
              onTap: () {
                if (label == '⌫') {
                  _onDeletePressed();
                } else {
                  _onDigitPressed(label);
                }
              },
              child: Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade100,
                ),
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
