import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final List<String> _pin = [];
  List<String>? _firstPin;
  bool _isConfirming = false;
  String _errorMessage = '';

  void _onDigitPressed(String digit) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin.add(digit);
      _errorMessage = '';
    });
    if (_pin.length == 4) {
      _handlePinComplete();
    }
  }

  void _onDeletePressed() {
    if (_pin.isEmpty) return;
    setState(() => _pin.removeLast());
  }

  Future<void> _handlePinComplete() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!_isConfirming) {
      setState(() {
        _firstPin = List.from(_pin);
        _pin.clear();
        _isConfirming = true;
      });
    } else {
      if (_pin.join() == _firstPin!.join()) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_pin', _pin.join());
        await prefs.setBool('pin_verified_session', true);
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const AuthWrapper()),
            (route) => false,
          );
        }
      } else {
        setState(() {
          _pin.clear();
          _firstPin = null;
          _isConfirming = false;
          _errorMessage = 'PINs do not match. Please try again.';
        });
      }
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
              const Icon(Icons.lock_outline, size: 56, color: Color(0xFF1A73E8)),
              const SizedBox(height: 16),
              Text(
                _isConfirming ? 'Confirm your PIN' : 'Set a 4-digit PIN',
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A)),
              ),
              const SizedBox(height: 8),
              Text(
                _isConfirming
                    ? 'Re-enter your PIN to confirm'
                    : 'You\'ll use this to login next time',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
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
                      color: filled ? const Color(0xFF1A73E8) : Colors.grey.shade300,
                    ),
                  );
                }),
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(_errorMessage,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 32),
              _buildNumberPad(),
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
              onTap: () => label == '⌫' ? _onDeletePressed() : _onDigitPressed(label),
              child: Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade100,
                ),
                child: Center(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w600)),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
