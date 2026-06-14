import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Contribution types
const String kTypeRegular = 'Regular Contribution';
const String kTypeCarryForward = 'Carry Forward (Previous Year)';
const String kTypeGaneshLaddu = 'Ganesh Laddu (Previous Year)';

class AddContributionScreen extends StatefulWidget {
  final String eventId;
  final String? existingDocId;
  final Map<String, dynamic>? existingData;

  const AddContributionScreen({
    super.key,
    required this.eventId,
    this.existingDocId,
    this.existingData,
  });

  @override
  State<AddContributionScreen> createState() =>
      _AddContributionScreenState();
}

class _AddContributionScreenState extends State<AddContributionScreen> {
  final _flatController = TextEditingController();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _noteController = TextEditingController();

  String _wing = '';
  String _block = '';
  String _contributionType = kTypeRegular;
  // For carry forward and Ganesh Laddu: was the amount received?
  bool _amountReceived = true;
  String _paymentMode = 'Cash';
  DateTime _paidDate = DateTime.now();
  bool _saving = false;
  String _error = '';

  bool get _isEditing => widget.existingDocId != null;
  bool get _isSpecialType =>
      _contributionType == kTypeCarryForward ||
      _contributionType == kTypeGaneshLaddu;

  final List<String> _paymentModes = ['Cash', 'UPI', 'Bank Transfer', 'Cheque'];
  final Set<String> _requiresReference = {'UPI', 'Bank Transfer', 'Cheque'};
  bool get _needsReference => _requiresReference.contains(_paymentMode);

  String get _referenceLabel {
    switch (_paymentMode) {
      case 'UPI': return 'UPI Reference / Transaction ID (Optional)';
      case 'Bank Transfer': return 'Bank Transfer Reference (Optional)';
      case 'Cheque': return 'Cheque Number (Optional)';
      default: return 'Reference ID';
    }
  }

  @override
  void initState() {
    super.initState();
    final d = widget.existingData;
    if (d != null) {
      _wing = d['wing'] ?? '';
      _block = d['block'] ?? '';
      _flatController.text = d['flatNumber'] ?? '';
      _nameController.text = d['residentName'] ?? '';
      _amountController.text = (d['amount'] ?? 0).toStringAsFixed(0);
      _contributionType = d['contributionType'] ?? kTypeRegular;
      _amountReceived = d['amountReceived'] ?? true;
      _paymentMode = d['paymentMode'] ?? 'Cash';
      _referenceController.text = d['referenceId'] ?? '';
      _noteController.text = d['note'] ?? '';
      if ((d['paidAt'] ?? '').isNotEmpty) {
        _paidDate = DateTime.tryParse(d['paidAt']) ?? DateTime.now();
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.green)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _paidDate = picked);
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.day == now.day && d.month == now.month && d.year == now.year;
  }

  Future<void> _save() async {
    if (_wing.isEmpty) {
      setState(() => _error = 'Please select a Wing');
      return;
    }
    if (_block.isEmpty) {
      setState(() => _error = 'Please select a Block');
      return;
    }
    if (_flatController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter flat number');
      return;
    }
    if (_amountController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter amount');
      return;
    }
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid amount');
      return;
    }

    setState(() { _saving = true; _error = ''; });

    try {
      final firestore = FirebaseFirestore.instance;
      final flat = _flatController.text.trim();
      final fullAddress = '$_wing Wing - $_block Block - Flat $flat';

      final payload = {
        'wing': _wing,
        'block': _block,
        'flatNumber': flat,
        'fullAddress': fullAddress,
        'residentName': _nameController.text.trim(),
        'amount': amount,
        'contributionType': _contributionType,
        // For carry forward / Ganesh Laddu: track if the amount was received
        'amountReceived': _isSpecialType ? _amountReceived : true,
        'paymentMode': _isSpecialType && !_amountReceived ? 'Pending' : _paymentMode,
        'referenceId': _referenceController.text.trim(),
        'note': _noteController.text.trim(),
        'paidAt': _paidDate.toIso8601String(),
        'paidDate': _formatDate(_paidDate),
      };

      final eventRef = firestore.collection('events').doc(widget.eventId);

      if (_isEditing) {
        final oldAmount = (widget.existingData!['amount'] ?? 0).toDouble();
        final oldReceived = widget.existingData!['amountReceived'] ?? true;
        final batch = firestore.batch();
        batch.update(
          eventRef.collection('contributions').doc(widget.existingDocId),
          payload,
        );
        // Only adjust totalCollected if the received status or amount changed
        final wasCountedBefore = !_isSpecialType || oldReceived;
        final isCountedNow = !_isSpecialType || _amountReceived;
        double diff = 0;
        if (wasCountedBefore && isCountedNow) diff = amount - oldAmount;
        else if (wasCountedBefore && !isCountedNow) diff = -oldAmount;
        else if (!wasCountedBefore && isCountedNow) diff = amount;
        if (diff != 0) {
          batch.update(eventRef, {'totalCollected': FieldValue.increment(diff)});
        }
        await batch.commit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Contribution updated ✅'),
            backgroundColor: Colors.green,
          ));
          Navigator.pop(context);
        }
      } else {
        final batch = firestore.batch();
        batch.set(eventRef.collection('contributions').doc(), payload);
        // Only add to totalCollected if received (or regular contribution)
        if (!_isSpecialType || _amountReceived) {
          batch.update(eventRef, {'totalCollected': FieldValue.increment(amount)});
        }
        await batch.commit();
        if (mounted) {
          final status = _isSpecialType
              ? (_amountReceived ? 'Received ✅' : 'Pending ⏳')
              : '✅';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('₹${amount.toStringAsFixed(0)} — $fullAddress $status'),
            backgroundColor: Colors.green,
          ));
          _flatController.clear();
          _nameController.clear();
          _amountController.clear();
          _referenceController.clear();
          _noteController.clear();
          setState(() {
            _wing = '';
            _block = '';
            _contributionType = kTypeRegular;
            _amountReceived = true;
            _paymentMode = 'Cash';
            _paidDate = DateTime.now();
            _saving = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = 'Failed: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Contribution' : 'Record Contribution',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('community_settings')
            .doc('address')
            .snapshots(),
        builder: (context, snap) {
          final settings = snap.data?.data() as Map<String, dynamic>? ?? {};
          final wings = List<String>.from(settings['wings'] ?? []);
          final wingBlocksMap =
              Map<String, dynamic>.from(settings['wingBlocks'] ?? {});
          // Blocks for the currently selected wing
          final blocksForWing = _wing.isNotEmpty
              ? List<String>.from(wingBlocksMap[_wing] ?? [])
              : <String>[];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Contribution Type ────────────────────────────
                _label('Contribution Type *'),
                const SizedBox(height: 8),
                _typeSelector(),
                const SizedBox(height: 16),

                // ── Special type status (received / pending) ─────
                if (_isSpecialType) ...[
                  _specialStatusCard(),
                  const SizedBox(height: 16),
                ],

                // ── Wing ─────────────────────────────────────────
                _label('Wing *'),
                const SizedBox(height: 8),
                wings.isEmpty
                    ? _hint('No wings configured — go to Admin → Settings')
                    : _chips(
                        items: wings,
                        selected: _wing,
                        activeColor: Colors.blue.shade600,
                        onTap: (w) => setState(() {
                          _wing = w;
                          _block = ''; // reset block when wing changes
                        }),
                      ),
                const SizedBox(height: 20),

                // ── Block (only for selected wing) ───────────────
                _label('Block *'),
                const SizedBox(height: 8),
                _wing.isEmpty
                    ? _hint('Select a wing first to see its blocks')
                    : blocksForWing.isEmpty
                        ? _hint('No blocks for $_wing Wing — add in Settings')
                        : _chips(
                            items: blocksForWing,
                            selected: _block,
                            activeColor: Colors.purple.shade600,
                            onTap: (b) => setState(() => _block = b),
                          ),
                const SizedBox(height: 20),

                // ── Flat number (digits only) ─────────────────────
                _label('Flat Number *'),
                const SizedBox(height: 4),
                Text('Numbers only  e.g. 101, 204, 501',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: _flatController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _dec('e.g. 101', Icons.home_outlined),
                ),
                const SizedBox(height: 20),

                // ── Resident name ─────────────────────────────────
                _label('Resident Name (Optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _dec('Optional', Icons.person_outlined),
                ),
                const SizedBox(height: 20),

                // ── Amount ────────────────────────────────────────
                _label('Amount (₹) *'),
                const SizedBox(height: 4),
                if (!_isSpecialType)
                  Text('Enter the exact amount given by the resident',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'))
                  ],
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '0',
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Colors.green, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Payment mode (only when received) ────────────
                if (!_isSpecialType || _amountReceived) ...[
                  _label('Payment Mode *'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _paymentModes.map((mode) {
                      final sel = _paymentMode == mode;
                      return ChoiceChip(
                        label: Text(mode),
                        selected: sel,
                        selectedColor: Colors.green.shade100,
                        labelStyle: TextStyle(
                          color: sel
                              ? Colors.green.shade800
                              : Colors.grey.shade700,
                          fontWeight:
                              sel ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (_) => setState(() {
                          _paymentMode = mode;
                          _referenceController.clear();
                        }),
                      );
                    }).toList(),
                  ),

                  if (_needsReference) ...[
                    const SizedBox(height: 20),
                    _label(_referenceLabel),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _referenceController,
                      decoration: _dec(
                          'e.g. UTR number, cheque no.', Icons.tag_outlined),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],

                // ── Date ─────────────────────────────────────────
                _label('Date *'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 20, color: Colors.green.shade600),
                        const SizedBox(width: 12),
                        Text(_formatDate(_paidDate),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Text(
                          _isToday(_paidDate) ? 'Today' : 'Tap to change',
                          style: TextStyle(
                              color: Colors.green.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Note ─────────────────────────────────────────
                _label('Note (Optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  decoration: _dec(
                      'e.g. Will pay on Chaturthi day', Icons.note_outlined),
                ),

                // ── Error ─────────────────────────────────────────
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade600, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error,
                              style: TextStyle(
                                  color: Colors.red.shade700, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSpecialType && !_amountReceived
                          ? Colors.orange
                          : Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Icon(_isSpecialType && !_amountReceived
                            ? Icons.hourglass_empty
                            : Icons.check),
                    label: Text(_saving
                        ? 'Saving...'
                        : _isEditing
                            ? 'Update Contribution'
                            : _isSpecialType && !_amountReceived
                                ? 'Save as Pending'
                                : 'Record Contribution'),
                  ),
                ),
                if (!_isEditing) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Form clears after save — add multiple entries',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Type selector ──────────────────────────────────────────────────────────

  Widget _typeSelector() {
    final types = [
      {'type': kTypeRegular, 'icon': Icons.payments_outlined, 'color': Colors.green},
      {'type': kTypeCarryForward, 'icon': Icons.history, 'color': Colors.blue},
      {'type': kTypeGaneshLaddu, 'icon': Icons.cookie_outlined, 'color': Colors.orange},
    ];
    return Column(
      children: types.map((t) {
        final type = t['type'] as String;
        final icon = t['icon'] as IconData;
        final color = t['color'] as Color;
        final sel = _contributionType == type;
        return GestureDetector(
          onTap: () => setState(() {
            _contributionType = type;
            _amountReceived = true;
          }),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: sel ? color.withOpacity(0.08) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: sel ? color : Colors.grey.shade200,
                  width: sel ? 2 : 1),
            ),
            child: Row(
              children: [
                Icon(icon, color: sel ? color : Colors.grey, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(type,
                      style: TextStyle(
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                          color: sel ? color : Colors.grey.shade700)),
                ),
                if (sel)
                  Icon(Icons.check_circle, color: color, size: 20),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Special type received/pending status card ──────────────────────────────

  Widget _specialStatusCard() {
    final isCarryForward = _contributionType == kTypeCarryForward;
    final label = isCarryForward
        ? 'Carry Forward Amount Status'
        : 'Ganesh Laddu Amount Status';
    final desc = isCarryForward
        ? 'Has this flat paid their carry forward amount from last year?'
        : 'Has this flat paid their Ganesh Laddu amount from last year?';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _amountReceived
            ? Colors.green.shade50
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _amountReceived
                ? Colors.green.shade200
                : Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(desc,
              style:
                  TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _amountReceived = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _amountReceived
                          ? Colors.green
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _amountReceived
                              ? Colors.green
                              : Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle,
                            color: _amountReceived
                                ? Colors.white
                                : Colors.grey,
                            size: 18),
                        const SizedBox(width: 6),
                        Text('Received',
                            style: TextStyle(
                                color: _amountReceived
                                    ? Colors.white
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _amountReceived = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !_amountReceived
                          ? Colors.orange
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: !_amountReceived
                              ? Colors.orange
                              : Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.hourglass_empty,
                            color: !_amountReceived
                                ? Colors.white
                                : Colors.grey,
                            size: 18),
                        const SizedBox(width: 6),
                        Text('Pending',
                            style: TextStyle(
                                color: !_amountReceived
                                    ? Colors.white
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Widget _label(String text) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.w600));

  Widget _hint(String msg) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(msg,
            style:
                TextStyle(color: Colors.orange.shade700, fontSize: 12)),
      );

  Widget _chips({
    required List<String> items,
    required String selected,
    required Color activeColor,
    required void Function(String) onTap,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final isSel = selected == item;
        return GestureDetector(
          onTap: () => onTap(item),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSel ? activeColor : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isSel ? activeColor : Colors.grey.shade300),
            ),
            child: Text(item,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSel ? Colors.white : Colors.grey.shade700,
                    fontSize: 14)),
          ),
        );
      }).toList(),
    );
  }

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.green, width: 2),
        ),
      );
}
