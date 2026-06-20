import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  List<String> _wingNames = [];
  Map<String, dynamic> _wingBlocks = {};
  String? _selectedWing;
  String? _selectedBlock;
  String? _selectedFlat;

  bool _loading = false;
  bool _loadingStructure = true;
  String _error = '';
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _loadStructure();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStructure() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('community_settings')
          .doc('address')
          .get();
      if (doc.exists) {
        setState(() {
          _wingNames = List<String>.from(doc.data()?['wings'] ?? []);
          _wingBlocks = Map<String, dynamic>.from(doc.data()?['wingBlocks'] ?? {});
        });
      }
    } catch (_) {}
    setState(() => _loadingStructure = false);
  }

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

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Please enter your full name');
      return;
    }
    if (phone.length < 10) {
      setState(() => _error = 'Please enter a valid 10-digit phone number');
      return;
    }
    if (_selectedWing == null) {
      setState(() => _error = 'Please select your wing');
      return;
    }
    if (_selectedBlock == null) {
      setState(() => _error = 'Please select your block');
      return;
    }
    if (_selectedFlat == null) {
      setState(() => _error = 'Please select your flat');
      return;
    }

    setState(() { _loading = true; _error = ''; });

    try {
      await FirebaseFirestore.instance.collection('pending_registrations').add({
        'name': name,
        'phone': phone,
        'wing': _selectedWing,
        'block': _selectedBlock,
        'flatNumber': _selectedFlat,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });
      setState(() { _submitted = true; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to submit. Please try again.'; _loading = false; });
    }
  }

  Widget _dropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required String Function(String) display,
    required ValueChanged<String?>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
            color: onChanged == null ? Colors.grey.shade300 : Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
        color: onChanged == null ? Colors.grey.shade50 : Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        hint: Text(hint,
            style: TextStyle(
                color: onChanged == null ? Colors.grey.shade400 : Colors.grey.shade500,
                fontSize: 14)),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(display(i)))).toList(),
        onChanged: onChanged,
      ),
    );
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
        title: const Text('Request Access',
            style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: _submitted ? _successView() : _formView(),
      ),
    );
  }

  Widget _successView() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_outline,
                size: 64, color: Colors.green.shade600),
          ),
          const SizedBox(height: 24),
          const Text('Request Submitted!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            'Your registration request has been sent to the society admin. '
            'Once approved, you\'ll receive a 6-digit Quick Code to log in.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Contact your society admin or check your WhatsApp for your Quick Code once approved.',
                  style: TextStyle(color: Colors.blue.shade800, fontSize: 13),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back to Login'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New Resident?',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Fill in your details and the admin will approve your access.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 28),

          // Name
          _label('Full Name *'),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: _inputDeco('e.g. Laasya Sri', Icons.person_outline),
          ),
          const SizedBox(height: 16),

          // Phone
          _label('Phone Number *'),
          const SizedBox(height: 6),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDeco('10-digit mobile number', Icons.phone_outlined),
          ),
          const SizedBox(height: 16),

          if (_loadingStructure)
            const Center(child: CircularProgressIndicator())
          else if (_wingNames.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                'Community structure not set up yet. Contact your admin.',
                style: TextStyle(color: Colors.orange.shade800),
              ),
            )
          else ...[
            // Wing
            _label('Wing *'),
            const SizedBox(height: 6),
            _dropdown(
              hint: 'Select your wing',
              value: _selectedWing,
              items: List<String>.from(_wingNames)..sort(),
              display: (w) => w,
              onChanged: (val) => setState(() {
                _selectedWing = val;
                _selectedBlock = null;
                _selectedFlat = null;
              }),
            ),
            const SizedBox(height: 16),

            // Block
            _label('Block *'),
            const SizedBox(height: 6),
            _dropdown(
              hint: _selectedWing == null ? 'Select wing first' : 'Select your block',
              value: _selectedBlock,
              items: _blockNames,
              display: (b) => 'Block $b',
              onChanged: _selectedWing == null ? null : (val) => setState(() {
                _selectedBlock = val;
                _selectedFlat = null;
              }),
            ),
            const SizedBox(height: 16),

            // Flat
            _label('Flat *'),
            const SizedBox(height: 6),
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
                      color: Colors.orange.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No flats added to Block $_selectedBlock yet. Please inform your admin.',
                      style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                    ),
                  ),
                ]),
              )
            else
              _dropdown(
                hint: _selectedBlock == null ? 'Select block first' : 'Select your flat',
                value: _selectedFlat,
                items: _flatNames,
                display: (f) => f,
                onChanged: _selectedBlock == null
                    ? null
                    : (val) => setState(() => _selectedFlat = val),
              ),
          ],

          if (_error.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(children: [
                Icon(Icons.error_outline, color: Colors.red.shade600, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Submit Request',
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _label(String text) =>
      Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600));

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 2),
        ),
      );
}
