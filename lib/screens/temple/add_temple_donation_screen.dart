import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kTempleInKindMode = 'In-Kind';
const List<String> kDefaultTempleCategories = [
  'Annadanam', 'Festival', 'General Fund', 'Renovation', 'General',
];
const List<String> kDefaultPaymentModesForTemple = [
  'Cash', 'UPI', 'PhonePe', 'Google Pay', 'Bank Transfer', 'NEFT / RTGS', 'Cheque', 'Other',
];

class AddTempleDonationScreen extends StatefulWidget {
  final bool isAdmin;
  final String? existingDocId;
  final Map<String, dynamic>? existingData;
  const AddTempleDonationScreen({
    super.key,
    required this.isAdmin,
    this.existingDocId,
    this.existingData,
  });

  @override
  State<AddTempleDonationScreen> createState() => _AddTempleDonationScreenState();
}

class _AddTempleDonationScreenState extends State<AddTempleDonationScreen> {
  final _nameCtrl = TextEditingController();
  final _wingCtrl = TextEditingController();
  final _blockCtrl = TextEditingController();
  final _flatCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _inKindCtrl = TextEditingController();

  bool get _isEditing => widget.existingDocId != null;

  String _tierName = '';
  String _category = kDefaultTempleCategories.first;
  String _paymentMode = kDefaultPaymentModesForTemple.first;
  bool _isAnonymous = false;
  bool _isExternalDonor = false;
  DateTime _date = DateTime.now();
  bool _saving = false;
  String _error = '';

  List<String> _paymentModes = kDefaultPaymentModesForTemple;
  List<Map<String, dynamic>> _tiers = [];
  List<String> _categories = kDefaultTempleCategories;

  @override
  void initState() {
    super.initState();
    final d = widget.existingData;
    if (d != null) {
      _nameCtrl.text = d['donorName'] as String? ?? '';
      _wingCtrl.text = d['wing'] as String? ?? '';
      _blockCtrl.text = d['block'] as String? ?? '';
      _flatCtrl.text = d['flatNumber'] as String? ?? '';
      _amountCtrl.text = ((d['amount'] as num?) ?? 0) > 0
          ? (d['amount'] as num).toStringAsFixed(0)
          : '';
      _referenceCtrl.text = d['referenceId'] as String? ?? '';
      _noteCtrl.text = d['note'] as String? ?? '';
      _inKindCtrl.text = d['inKindDescription'] as String? ?? '';
      _tierName = d['tierName'] as String? ?? '';
      _category = (d['category'] as String?)?.isNotEmpty == true
          ? d['category'] as String
          : kDefaultTempleCategories.first;
      _paymentMode = (d['paymentMode'] as String?)?.isNotEmpty == true
          ? d['paymentMode'] as String
          : kDefaultPaymentModesForTemple.first;
      _isAnonymous = d['isAnonymous'] == true;
      _isExternalDonor = d['isExternalDonor'] == true;
      final donatedAt = d['donatedAt'] as String?;
      if (donatedAt != null && donatedAt.isNotEmpty) {
        _date = DateTime.tryParse(donatedAt) ?? DateTime.now();
      }
    } else if (!widget.isAdmin) {
      _loadSession();
    }
    _loadSettings();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nameCtrl.text = prefs.getString('session_name') ?? '';
      _wingCtrl.text = prefs.getString('session_wing') ?? '';
      _blockCtrl.text = prefs.getString('session_block') ?? '';
      _flatCtrl.text = prefs.getString('session_flat') ?? '';
    });
  }

  Future<void> _loadSettings() async {
    final results = await Future.wait([
      FirebaseFirestore.instance.collection('community_settings').doc('address').get(),
      FirebaseFirestore.instance.collection('appSettings').doc('templeDonationConfig').get(),
    ]);
    if (!mounted) return;
    final community = results[0].data() ?? {};
    final temple = results[1].data() ?? {};
    setState(() {
      final modes = community['paymentModes'] as List?;
      _paymentModes = modes != null && modes.isNotEmpty
          ? List<String>.from(modes)
          : kDefaultPaymentModesForTemple;
      if (!_paymentModes.contains(_paymentMode)) _paymentMode = _paymentModes.first;
      final tiers = temple['tiers'] as List?;
      _tiers = tiers != null
          ? tiers.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : [];
      final cats = temple['categories'] as List?;
      _categories = cats != null && cats.isNotEmpty
          ? List<String>.from(cats)
          : kDefaultTempleCategories;
      if (!_categories.contains(_category)) _category = _categories.first;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _wingCtrl.dispose();
    _blockCtrl.dispose();
    _flatCtrl.dispose();
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    _noteCtrl.dispose();
    _inKindCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  bool get _isInKind => _paymentMode == kTempleInKindMode;

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter donor name');
      return;
    }
    double amount = 0;
    if (_isInKind) {
      if (_inKindCtrl.text.trim().isEmpty) {
        setState(() => _error = 'Describe what was donated in-kind');
        return;
      }
      amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    } else {
      amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
      if (amount <= 0) {
        setState(() => _error = 'Please enter a valid amount');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = '';
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final payload = {
        'donorName': name,
        'wing': _isExternalDonor ? '' : _wingCtrl.text.trim().toUpperCase(),
        'block': _isExternalDonor ? '' : _blockCtrl.text.trim().toUpperCase(),
        'flatNumber': _isExternalDonor ? '' : _flatCtrl.text.trim(),
        'isExternalDonor': _isExternalDonor,
        'isAnonymous': _isAnonymous,
        'amount': amount,
        'tierName': _tierName,
        'category': _category,
        'paymentMode': _paymentMode,
        'inKindDescription': _isInKind ? _inKindCtrl.text.trim() : '',
        'referenceId': _referenceCtrl.text.trim(),
        'note': _noteCtrl.text.trim(),
        'donatedAt': _date.toIso8601String(),
        'donatedDate': _fmtDate(_date),
      };

      if (_isEditing) {
        await firestore
            .collection('templeDonations')
            .doc(widget.existingDocId)
            .update(payload);
      } else {
        payload['amountReceived'] = widget.isAdmin;
        payload['selfReported'] = !widget.isAdmin;
        payload['createdAt'] = DateTime.now().toIso8601String();
        await firestore.collection('templeDonations').add(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.isAdmin
              ? (_isEditing ? 'Donation updated ✅' : '₹${amount.toStringAsFixed(0)} recorded ✅')
              : 'Thank you! Submitted for admin confirmation 🙏'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _label(String text) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.w600));

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.deepOrange.shade400, width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Donation' : 'Temple Donation'),
        backgroundColor: Colors.deepOrange.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_tiers.isNotEmpty) ...[
              _label('Contribution Tier (Optional)'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tiers.map((t) {
                  final name = t['name'] as String? ?? '';
                  final tAmount = (t['amount'] as num?)?.toDouble() ?? 0;
                  final sel = _tierName == name;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _tierName = sel ? '' : name;
                      if (!sel && tAmount > 0) {
                        _amountCtrl.text = tAmount.toStringAsFixed(0);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? Colors.deepOrange.shade600 : Colors.deepOrange.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel ? Colors.deepOrange.shade600 : Colors.deepOrange.shade200),
                      ),
                      child: Text(
                          tAmount > 0 ? '$name · ₹${tAmount.toStringAsFixed(0)}' : name,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : Colors.deepOrange.shade800)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            _label('Donor Name *'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: _dec('e.g. Ramesh Kumar', Icons.person_outline),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Checkbox(
                value: _isExternalDonor,
                onChanged: (v) => setState(() => _isExternalDonor = v ?? false),
              ),
              const Expanded(child: Text('External / non-resident donor (no flat)')),
            ]),
            if (!_isExternalDonor) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _wingCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: _dec('Wing', Icons.apartment_outlined),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _blockCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: _dec('Block', Icons.grid_view_outlined),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _flatCtrl,
                    decoration: _dec('Flat No', Icons.home_outlined),
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 16),
            _label('Payment Mode *'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: [..._paymentModes, kTempleInKindMode].contains(_paymentMode)
                  ? _paymentMode
                  : _paymentModes.first,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: Theme.of(context).cardColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: [..._paymentModes, kTempleInKindMode]
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _paymentMode = v ?? _paymentModes.first),
            ),
            if (_isInKind) ...[
              const SizedBox(height: 16),
              _label('What was donated? *'),
              const SizedBox(height: 8),
              TextField(
                controller: _inKindCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: _dec('e.g. Silver lamp, flowers, fruits', Icons.redeem_outlined),
              ),
            ],
            const SizedBox(height: 16),
            _label(_isInKind ? 'Estimated Value (₹) (Optional)' : 'Amount (₹) *'),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: _dec('e.g. 5000', Icons.currency_rupee),
            ),
            const SizedBox(height: 16),
            _label('Category *'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _categories.contains(_category) ? _category : _categories.first,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: Theme.of(context).cardColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _categories.first),
            ),
            if (!_isInKind) ...[
              const SizedBox(height: 16),
              _label('Reference / Transaction ID (Optional)'),
              const SizedBox(height: 8),
              TextField(
                controller: _referenceCtrl,
                decoration: _dec('e.g. UPI ref number', Icons.receipt_long_outlined),
              ),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Checkbox(
                value: _isAnonymous,
                onChanged: (v) => setState(() => _isAnonymous = v ?? false),
              ),
              const Expanded(child: Text('Keep donor anonymous publicly')),
            ]),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.calendar_today_outlined, color: Colors.deepOrange.shade700),
              title: Text(_fmtDate(_date), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Tap to change date'),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 8),
            _label('Note (Optional)'),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: _dec('Any additional details', Icons.notes_outlined),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_error, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        widget.isAdmin
                            ? (_isEditing ? 'Save Changes' : 'Record Donation')
                            : 'Submit',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
