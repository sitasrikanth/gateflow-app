import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_contribution_screen.dart' show kTypeCarryForward;

// Lets an admin bring forward a leftover balance from ANY past event (any
// type, e.g. Independence Day) into the current event (e.g. Ganesh
// Chaturthi). The source event's available-to-carry-forward balance is
// reduced by `carriedForwardOut` so the same leftover can't be double-spent
// across multiple destination events, while still allowing partial amounts.
class CarryForwardScreen extends StatefulWidget {
  final String eventId;
  final String eventName;
  const CarryForwardScreen(
      {super.key, required this.eventId, required this.eventName});

  @override
  State<CarryForwardScreen> createState() => _CarryForwardScreenState();
}

class _CarryForwardScreenState extends State<CarryForwardScreen> {
  String? _selectedEventId;
  Map<String, dynamic>? _selectedEventData;
  final _amountController = TextEditingController();
  bool _saving = false;
  String _error = '';

  double _availableBalance(Map<String, dynamic> d) {
    final collected = ((d['totalCollected'] ?? 0) as num).toDouble();
    final spent = ((d['totalSpent'] ?? 0) as num).toDouble();
    final carriedOut = ((d['carriedForwardOut'] ?? 0) as num).toDouble();
    final bal = collected - spent - carriedOut;
    return bal > 0 ? bal : 0;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final selId = _selectedEventId;
    final selData = _selectedEventData;
    if (selId == null || selData == null) {
      setState(() => _error = 'Select a source event first');
      return;
    }
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    final available = _availableBalance(selData);
    if (amount > available) {
      setState(() => _error =
          'Amount exceeds available balance (₹${available.toStringAsFixed(0)})');
      return;
    }

    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      final firestore = FirebaseFirestore.instance;
      final destRef = firestore.collection('events').doc(widget.eventId);
      final sourceRef = firestore.collection('events').doc(selId);
      final now = DateTime.now();
      final sourceName = (selData['name'] as String?)?.trim().isNotEmpty == true
          ? selData['name'] as String
          : 'Previous Event';

      // Create both doc references upfront so the destination contribution
      // and the source's transfer-audit record can point at each other —
      // this is what lets deleting/restoring one side correctly reverse
      // (and un-reverse) the other, instead of the two drifting out of sync.
      final destContribRef = destRef.collection('contributions').doc();
      final transferRef = sourceRef.collection('carryForwardTransfers').doc();

      final batch = firestore.batch();
      batch.set(destContribRef, {
        'wing': '',
        'block': '',
        'flatNumber': '',
        'fullAddress': 'Carry Forward',
        'residentName': '',
        'amount': amount,
        'contributionType': kTypeCarryForward,
        'amountReceived': true,
        'paymentMode': 'Carry Forward',
        'isAnonymous': false,
        'sponsorPackageName': '',
        'referenceId': '',
        'note': '',
        'specialDescription': '',
        'paidAt': now.toIso8601String(),
        'paidDate': '${now.day}/${now.month}/${now.year}',
        'carryForwardSourceEventId': selId,
        'carryForwardSourceEventName': sourceName,
        'carryForwardTransferId': transferRef.id,
      });
      batch.update(destRef, {'totalCollected': FieldValue.increment(amount)});
      batch.update(sourceRef, {'carriedForwardOut': FieldValue.increment(amount)});
      // Auditable record on the source event: how much moved out, and to
      // where — powers the Overview note and Activity log entry there.
      batch.set(transferRef, {
        'amount': amount,
        'destEventId': widget.eventId,
        'destEventName': widget.eventName,
        'destContributionId': destContribRef.id,
        'createdAt': now.toIso8601String(),
        'reversed': false,
      });
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '₹${amount.toStringAsFixed(0)} carried forward from $sourceName ✅'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Carry Forward Balance'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('events').snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snap.data!.docs.where((d) {
            if (d.id == widget.eventId) return false;
            final data = d.data() as Map<String, dynamic>;
            return data['status'] != 'deleted';
          }).toList();
          events.sort((a, b) {
            final ad = (a.data() as Map<String, dynamic>)['createdAt'] as String? ?? '';
            final bd = (b.data() as Map<String, dynamic>)['createdAt'] as String? ?? '';
            return bd.compareTo(ad);
          });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Carrying forward into: ${widget.eventName}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              Text(
                  'Pick any past event with a remaining balance to bring some or all of it into this event.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(height: 18),
              Text('Source Event',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.4)),
              const SizedBox(height: 8),
              if (events.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text('No other events found.',
                      style: TextStyle(color: Colors.grey.shade500)),
                ),
              ...events.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['name'] as String?)?.trim().isNotEmpty == true
                    ? data['name'] as String
                    : 'Unnamed Event';
                final bal = _availableBalance(data);
                final sel = _selectedEventId == doc.id;
                final canPick = bal > 0;
                final collected = ((data['totalCollected'] ?? 0) as num).toDouble();
                final spent = ((data['totalSpent'] ?? 0) as num).toDouble();
                final carriedOut = ((data['carriedForwardOut'] ?? 0) as num).toDouble();
                // When unavailable, spell out why (net balance vs. already
                // carried out elsewhere) instead of a bare "No remaining
                // balance" — makes it clear whether that's expected or
                // looks like stale data worth recalculating.
                final subtitleText = canPick
                    ? 'Available: ₹${bal.toStringAsFixed(0)}'
                    : carriedOut > 0
                        ? 'Net ₹${(collected - spent).toStringAsFixed(0)} — ₹${carriedOut.toStringAsFixed(0)} already carried out elsewhere'
                        : 'No remaining balance (collected ₹${collected.toStringAsFixed(0)} − spent ₹${spent.toStringAsFixed(0)})';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: sel ? Colors.blue.shade50 : Theme.of(context).cardColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                        color: sel ? Colors.blue.shade300 : Colors.grey.shade200),
                  ),
                  child: ListTile(
                    enabled: canPick,
                    title: Text(name,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: canPick ? null : Colors.grey.shade400)),
                    subtitle: Text(subtitleText,
                        style: TextStyle(
                            color: canPick ? Colors.green.shade700 : Colors.grey.shade400,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                    trailing: sel
                        ? Icon(Icons.check_circle, color: Colors.blue.shade600)
                        : null,
                    onTap: canPick
                        ? () => setState(() {
                              _selectedEventId = doc.id;
                              _selectedEventData = data;
                              _error = '';
                              _amountController.text = bal.toStringAsFixed(0);
                            })
                        : null,
                  ),
                );
              }),
              if (_selectedEventId != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                Text('Amount to carry forward (₹)',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.4)),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'e.g. 30000',
                    prefixIcon: const Icon(Icons.currency_rupee),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                    ),
                  ),
                ),
              ],
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(_error, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _selectedEventId == null || _saving ? null : _confirm,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Carry Forward',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}
