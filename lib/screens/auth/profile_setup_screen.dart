import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import '../../main.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _flatController = TextEditingController();
  final TextEditingController _towerController = TextEditingController();
  String _selectedRole = 'resident';
  bool _isLoading = false;
  String _errorMessage = '';

  final List<Map<String, dynamic>> _roles = [
    {'value': 'resident', 'label': 'Resident', 'icon': Icons.home},
    {'value': 'guard', 'label': 'Security Guard', 'icon': Icons.security},
    {'value': 'admin', 'label': 'Society Admin', 'icon': Icons.admin_panel_settings},
  ];

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your name');
      return;
    }
    if (_flatController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your flat number');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'phone': user.phoneNumber,
        'flatNumber': _flatController.text.trim(),
        'tower': _towerController.text.trim(),
        'role': _selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved! Welcome to GateFlow 🎉'),
            backgroundColor: Color(0xFF1A73E8),
          ),
        );
        // Navigate to AuthWrapper — it will route based on role
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Set up your\nprofile',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A), height: 1.2),
              ),
              const SizedBox(height: 8),
              const Text('Tell us about yourself', style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 40),

              // Name
              const Text('Full Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Enter your full name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Flat Number
              const Text('Flat Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _flatController,
                decoration: InputDecoration(
                  hintText: 'e.g. 404, B-202',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Tower
              const Text('Tower / Block (optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _towerController,
                decoration: InputDecoration(
                  hintText: 'e.g. Tower A, Block 2',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Role
              const Text('I am a...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ...(_roles.map((role) {
                final isSelected = _selectedRole == role['value'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedRole = role['value']),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? const Color(0xFF1A73E8) : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected ? const Color(0xFF1A73E8).withOpacity(0.05) : Colors.white,
                    ),
                    child: Row(
                      children: [
                        Icon(role['icon'] as IconData,
                            color: isSelected ? const Color(0xFF1A73E8) : Colors.grey),
                        const SizedBox(width: 12),
                        Text(role['label'] as String,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? const Color(0xFF1A73E8) : const Color(0xFF1A1A1A),
                            )),
                        const Spacer(),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: Color(0xFF1A73E8)),
                      ],
                    ),
                  ),
                );
              })),

              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save & Continue', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final String role;
  const HomeScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A73E8),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 80),
            const SizedBox(height: 24),
            const Text('You\'re in! 🎉',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text('Logged in as $role',
                style: const TextStyle(fontSize: 16, color: Colors.white70)),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1A73E8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}