import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';
import '../../theme/app_theme.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  String _errorMessage = '';
  int _attempts = 0;

  String get _code => _controllers.map((c) => c.text).join();

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_code.length == 6) _verifyCode();
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyCode() async {
    if (_code.length < 6) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Search users (admin / resident)
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('quickCode', isEqualTo: _code)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final doc = userQuery.docs.first;
        final data = doc.data();
        await _saveSession(
          userId: doc.id,
          role: data['role'] ?? 'resident',
          name: data['name'] ?? '',
          flatNumber: data['flatNumber'] ?? '',
          userWing: data['wing'] ?? '',
          userBlock: data['block'] ?? '',
        );
        return;
      }

      // Search guards
      final guardQuery = await FirebaseFirestore.instance
          .collection('guards')
          .where('quickCode', isEqualTo: _code)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (guardQuery.docs.isNotEmpty) {
        final doc = guardQuery.docs.first;
        final data = doc.data();
        await _saveSession(
          userId: doc.id,
          role: 'guard',
          name: data['name'] ?? '',
          flatNumber: '',
        );
        return;
      }

      // Not found
      _attempts++;
      setState(() {
        _isLoading = false;
        _errorMessage = _attempts >= 3
            ? 'Too many wrong attempts. Contact your admin.'
            : 'Invalid code. ${3 - _attempts} attempt${_attempts == 2 ? '' : 's'} left.';
      });
      for (final c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error verifying code. Try again.';
      });
    }
  }

  Future<void> _saveSession({
    required String userId,
    required String role,
    required String name,
    required String flatNumber,
    String userWing = '',
    String userBlock = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('session_role', role);
    await prefs.setString('session_user_id', userId);
    await prefs.setString('session_name', name);
    await prefs.setString('session_flat', flatNumber);

    // Resolve wing/block for this flat
    if (role == 'resident' && flatNumber.isNotEmpty) {
      String wing = userWing;
      String block = userBlock;
      // If not in user doc, fall back to community_settings lookup
      if (wing.isEmpty || block.isEmpty) {
        try {
          final settingsDoc = await FirebaseFirestore.instance
              .collection('community_settings')
              .doc('address')
              .get();
          if (settingsDoc.exists) {
            final wingBlocks = (settingsDoc.data()?['wingBlocks'] as Map<String, dynamic>? ?? {});
            outer:
            for (final wEntry in wingBlocks.entries) {
              final raw = wEntry.value;
              if (raw is! Map) continue;
              for (final bEntry in (raw as Map).entries) {
                final flats = bEntry.value is List
                    ? List<String>.from(bEntry.value)
                    : <String>[];
                if (flats.contains(flatNumber)) {
                  wing = wEntry.key;
                  block = bEntry.key.toString();
                  break outer;
                }
              }
            }
          }
        } catch (_) {}
      }
      await prefs.setString('session_wing', wing);
      await prefs.setString('session_block', block);
    }
    // Legacy guard keys (guard_home_screen reads these)
    if (role == 'guard') {
      await prefs.setBool('is_guard_session', true);
      await prefs.setString('guard_id', userId);
      await prefs.setString('guard_name', name);
    } else {
      await prefs.setBool('is_guard_session', false);
    }
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accent;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.apartment, size: 56, color: accent),
              ),
              const SizedBox(height: 20),
              Text('GateFlow',
                  style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Your community, connected.',
                  style: TextStyle(fontSize: 15, color: Colors.grey)),
              const SizedBox(height: 56),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Enter your Quick Code',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('6-digit code provided by your society admin',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 48,
                    height: 58,
                    child: KeyboardListener(
                      focusNode: FocusNode(),
                      onKeyEvent: (e) => _onKeyEvent(index, e),
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade50,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: accent, width: 2),
                          ),
                        ),
                        onChanged: (value) => _onDigitChanged(index, value),
                      ),
                    ),
                  );
                }),
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade600, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage,
                            style: TextStyle(
                                color: Colors.red.shade700, fontSize: 13)),
                      ),
                      TextButton(
                        onPressed: () {
                          for (final c in _controllers) c.clear();
                          setState(() {
                            _errorMessage = '';
                            _attempts = 0;
                          });
                          _focusNodes[0].requestFocus();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Reset',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Login',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('New resident?',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RegisterScreen()),
                    ),
                    child: Text('Request Access',
                        style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
