import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kDefaultPaymentModes = ['Cash', 'UPI', 'PhonePe', 'Google Pay', 'Bank Transfer', 'NEFT / RTGS', 'Cheque', 'Other'];

// ── Self-Report Payment Bottom Sheet ─────────────────────────────────────────
// Lets a resident report a contribution payment from anywhere in the app
// (event list card or inside the event dashboard). Saved as
// selfReported: true, amountReceived: false until an admin confirms it.

class SelfReportSheet extends StatefulWidget {
  final String eventId;
  final String eventName;
  final String flatNumber;
  final String residentName;
  final VoidCallback onSubmitted;
  final QueryDocumentSnapshot? existingDoc; // non-null = edit mode

  const SelfReportSheet({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.flatNumber,
    required this.residentName,
    required this.onSubmitted,
    this.existingDoc,
  });

  @override
  State<SelfReportSheet> createState() => _SelfReportSheetState();
}

class _SelfReportSheetState extends State<SelfReportSheet> {
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _specialDescCtrl = TextEditingController();
  String _mode = 'PhonePe';
  String _contributionType = 'Regular Contribution';
  DateTime _date = DateTime.now();
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.existingDoc != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final d = widget.existingDoc!.data() as Map<String, dynamic>;
      _amountCtrl.text = (d['amount'] as num?)?.toStringAsFixed(0) ?? '';
      _refCtrl.text = (d['referenceId'] ?? '').toString();
      _specialDescCtrl.text = (d['specialDescription'] ?? '').toString();
      _mode = (d['paymentMode'] as String?) ?? kDefaultPaymentModes.first;
      _contributionType = (d['contributionType'] as String?) ?? 'Regular Contribution';
      final rawDate = d['paidAt'] as String?;
      if (rawDate != null) {
        try { _date = DateTime.parse(rawDate).toLocal(); } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _specialDescCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';


  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final amtStr = _amountCtrl.text.trim();
    final amount = double.tryParse(amtStr);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid amount');
      return;
    }

    setState(() { _submitting = true; _error = null; });

    try {
      final prefs = await SharedPreferences.getInstance();
      final wing = prefs.getString('session_wing') ?? '';
      final block = prefs.getString('session_block') ?? '';
      final userId = prefs.getString('session_user_id') ?? '';

      // Fetch phone from user doc
      String phone = '';
      if (userId.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        phone = (userDoc.data() as Map<String, dynamic>?)?['phone']?.toString() ?? '';
        if (phone.startsWith('+91')) phone = phone.substring(3);
      }

      if (_isEditing) {
        // Update existing pending doc
        await widget.existingDoc!.reference.update({
          'amount': amount,
          'paymentMode': _mode,
          'contributionType': _contributionType,
          'specialDescription': _contributionType == 'Special Contribution' ? _specialDescCtrl.text.trim() : '',
          'referenceId': _refCtrl.text.trim(),
          'paidAt': _date.toIso8601String(),
          'paidDate': _fmtDate(_date),
          'updatedAt': DateTime.now().toIso8601String(),
        });
      } else {
        // Check if this flat already has confirmed payment (for admin notification)
        final existingSnap = await FirebaseFirestore.instance
            .collection('events').doc(widget.eventId)
            .collection('contributions')
            .where('flatNumber', isEqualTo: widget.flatNumber)
            .get();
        final alreadyPaid = existingSnap.docs.any((d) {
          final data = d.data();
          return data['amountReceived'] == true && data['status'] != 'deleted';
        });

        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .collection('contributions')
            .add({
          'flatNumber': widget.flatNumber,
          'residentName': widget.residentName,
          'phone': phone,
          'wing': wing,
          'block': block,
          'amount': amount,
          'contributionType': _contributionType,
          'specialDescription': _contributionType == 'Special Contribution' ? _specialDescCtrl.text.trim() : '',
          'paymentMode': _mode,
          'referenceId': _refCtrl.text.trim(),
          'note': '',
          'amountReceived': false,
          'selfReported': true,
          'isAdditional': alreadyPaid,
          'status': 'pending',
          'eventName': widget.eventName,
          'paidAt': _date.toIso8601String(),
          'paidDate': _fmtDate(_date),
          'reportedAt': DateTime.now().toIso8601String(),
        });
      }

      widget.onSubmitted();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing
              ? 'Payment updated! Awaiting admin verification.'
              : 'Payment reported! The admin will verify and confirm it shortly.'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      setState(() { _error = 'Failed to submit: $e'; _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),

            // Title
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.payments_rounded,
                    color: Colors.green.shade700, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_isEditing ? 'Edit Payment' : 'Report Your Payment',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(widget.eventName,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // Contribution type selector
            const Text('Contribution Type',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final type in ['Regular Contribution', 'Special Contribution'])
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _contributionType = type),
                      child: Container(
                        margin: EdgeInsets.only(right: type == 'Regular Contribution' ? 6 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _contributionType == type
                              ? Colors.green.shade600
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _contributionType == type
                                ? Colors.green.shade600
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          type == 'Regular Contribution' ? 'Regular' : 'Special',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _contributionType == type
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Special description
            if (_contributionType == 'Special Contribution') ...[
              const Text('What is this special contribution for? *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _specialDescCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'e.g. Carry Forward from last year, Ganesh Laddu donation…',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Amount
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount Paid (₹) *',
                prefixText: '₹ ',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 14),

            // Payment mode chips
            const Text('Payment Mode',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('community_settings')
                  .doc('address')
                  .snapshots(),
              builder: (ctx, snap) {
                final d = snap.data?.data() as Map<String, dynamic>? ?? {};
                final modes = d['paymentModes'] is List
                    ? List<String>.from(d['paymentModes'] as List)
                    : List<String>.from(kDefaultPaymentModes);
                if (!modes.contains(_mode)) {
                  WidgetsBinding.instance.addPostFrameCallback(
                      (_) => setState(() => _mode = modes.first));
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: modes.map((m) {
                    final sel = _mode == m;
                    return GestureDetector(
                      onTap: () => setState(() => _mode = m),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? Colors.green.shade600 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: sel ? Colors.green.shade600 : Colors.grey.shade300),
                        ),
                        child: Text(m,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: sel ? Colors.white : Colors.grey.shade700)),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 14),

            // Transaction reference
            TextField(
              controller: _refCtrl,
              decoration: InputDecoration(
                labelText: _mode == 'Cash'
                    ? 'Note (optional)'
                    : 'Transaction Ref / UTR No.',
                hintText: _mode == 'Cash'
                    ? 'e.g. Given to treasurer'
                    : 'e.g. T2410151234567',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 14),

            // Date
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today,
                      size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 10),
                  Text('Date of Payment: ${_fmtDate(_date)}',
                      style: const TextStyle(fontSize: 14)),
                  const Spacer(),
                  Icon(Icons.edit, size: 16, color: Colors.grey.shade400),
                ]),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: TextStyle(
                      color: Colors.red.shade600, fontSize: 13)),
            ],

            const SizedBox(height: 20),

            // Info note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your payment will be marked as Pending Verification. '
                      'The admin will confirm it after checking records.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.blue.shade800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(_submitting
                    ? 'Saving…'
                    : _isEditing ? 'Update Payment' : 'Submit Payment Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
