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
  String _selectedRole = 'resident';
  bool _isLoading = false;
  String _errorMessage = '';

  // Wing / Block from community_settings
  List<String> _wingNames2 = [];
  Map<String, dynamic> _wingBlocks = {}; // { wing: { block: [flats] } }
  String? _selectedWing;
  String? _selectedBlock;
  bool _loadingStructure = true;

  final List<Map<String, dynamic>> _roles = [
    {'value': 'resident', 'label': 'Resident', 'icon': Icons.home},
    {'value': 'guard', 'label': 'Security Guard', 'icon': Icons.security},
    {'value': 'admin', 'label': 'Society Admin', 'icon': Icons.admin_panel_settings},
  ];

  @override
  void initState() {
    super.initState();
    _loadStructure();
  }

  Future<void> _loadStructure() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('community_settings')
          .doc('address')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _wingNames2 = List<String>.from(data['wings'] ?? []);
          _wingBlocks = Map<String, dynamic>.from(data['wingBlocks'] ?? {});
        });
      }
    } catch (_) {}
    setState(() => _loadingStructure = false);
  }

  String? _selectedFlat;

  List<String> get _wingNames => List<String>.from(_wingNames2)..sort();

  List<String> get _blockNames {
    if (_selectedWing == null) return [];
    final raw = _wingBlocks[_selectedWing];
    if (raw is Map) return (raw.keys.cast<String>().toList())..sort();
    if (raw is List) return List<String>.from(raw)..sort();
    return [];
  }

  List<String> get _flatNames {
    if (_selectedWing == null || _selectedBlock == null) return [];
    final raw = _wingBlocks[_selectedWing];
    if (raw is Map) {
      final blockData = raw[_selectedBlock];
      if (blockData is List) return List<String>.from(blockData)..sort();
    }
    return [];
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your name');
      return;
    }
    if (_selectedRole == 'resident') {
      if (_selectedWing == null) {
        setState(() => _errorMessage = 'Please select your wing');
        return;
      }
      if (_selectedBlock == null) {
        setState(() => _errorMessage = 'Please select your block');
        return;
      }
      if (_selectedFlat == null) {
        setState(() => _errorMessage = 'Please select your flat');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;

      final status = _selectedRole == 'resident' ? 'pending' : 'active';
      final permissions = _selectedRole == 'admin'
          ? ['admin-resident', 'admin-guard', 'admin-notice', 'admin-complaint']
          : [];

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'phone': user.phoneNumber,
        'flatNumber': _selectedFlat ?? '',
        'wing': _selectedWing ?? '',
        'block': _selectedBlock ?? '',
        'role': _selectedRole,
        'status': status,
        'permissions': permissions,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved! Welcome to GateFlow 🎉'),
            backgroundColor: Color(0xFF1A73E8),
          ),
        );
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

  Widget _styledDropdown<T>({
    required String hint,
    required T? value,
    required List<T> items,
    required String Function(T) displayText,
    required ValueChanged<T?>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
            color: onChanged == null ? Colors.grey.shade300 : Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
        color: onChanged == null ? Colors.grey.shade50 : Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        hint: Text(hint,
            style: TextStyle(
                color: onChanged == null ? Colors.grey.shade400 : Colors.grey.shade500,
                fontSize: 14)),
        items: items
            .map((i) => DropdownMenuItem<T>(value: i, child: Text(displayText(i))))
            .toList(),
        onChanged: onChanged,
      ),
    );
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

              // Role selector (shown before wing/block so resident fields are conditional)
              const Text('I am a...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ...(_roles.map((role) {
                final isSelected = _selectedRole == role['value'];
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedRole = role['value'];
                    _selectedWing = null;
                    _selectedBlock = null;
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? const Color(0xFF1A73E8) : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected ? const Color(0xFF1A73E8).withValues(alpha: 0.05) : Colors.white,
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

              // Wing / Block / Flat — only for residents
              if (_selectedRole == 'resident') ...[
                const SizedBox(height: 8),
                if (_loadingStructure)
                  const Center(child: CircularProgressIndicator())
                else if (_wingNames.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      'Community structure not set up yet. Contact your admin.',
                      style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                    ),
                  )
                else ...[
                  // Wing → Block → Flat dropdowns
                  const Text('Wing', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _styledDropdown<String>(
                    hint: 'Select your wing',
                    value: _selectedWing,
                    items: _wingNames,
                    displayText: (w) => w,
                    onChanged: (val) => setState(() {
                      _selectedWing = val;
                      _selectedBlock = null;
                      _selectedFlat = null;
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Block dropdown
                  const Text('Block', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _styledDropdown<String>(
                    hint: _selectedWing == null ? 'Select wing first' : 'Select your block',
                    value: _selectedBlock,
                    items: _blockNames,
                    displayText: (b) => 'Block $b',
                    onChanged: _selectedWing == null ? null : (val) => setState(() {
                      _selectedBlock = val;
                      _selectedFlat = null;
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Flat dropdown
                  const Text('Flat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (_selectedBlock != null && _flatNames.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No flats added to Block $_selectedBlock yet. Please inform your admin.',
                            style: TextStyle(
                                color: Colors.orange.shade800, fontSize: 13),
                          ),
                        ),
                      ]),
                    )
                  else
                    _styledDropdown<String>(
                      hint: _selectedBlock == null ? 'Select block first' : 'Select your flat',
                      value: _selectedFlat,
                      items: _flatNames,
                      displayText: (f) => f,
                      onChanged: _selectedBlock == null ? null : (val) => setState(() => _selectedFlat = val),
                    ),
                  const SizedBox(height: 20),
                ],
              ],

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
