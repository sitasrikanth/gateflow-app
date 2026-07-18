import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Manage Sponsor Packages ───────────────────────────────────────────────────
// Admin-only screen to define sponsorship tiers (e.g. Gold/Silver/Bronze) for
// one specific event. Stored as a plain list on the event doc itself, since
// tiers/amounts are typically specific to that year's event rather than a
// reusable catalog per event type.

const List<Color> kSponsorTierColors = [
  Color(0xFFFFD700), // gold
  Color(0xFFC0C0C0), // silver
  Color(0xFFCD7F32), // bronze
  Color(0xFF9C27B0), // fallback purple for extra tiers
];

class SponsorPackagesScreen extends StatefulWidget {
  final String eventId;
  const SponsorPackagesScreen({super.key, required this.eventId});

  @override
  State<SponsorPackagesScreen> createState() => _SponsorPackagesScreenState();
}

class _SponsorPackagesScreenState extends State<SponsorPackagesScreen> {
  DocumentReference get _eventRef =>
      FirebaseFirestore.instance.collection('events').doc(widget.eventId);

  Future<void> _write(List<Map<String, dynamic>> packages) =>
      _eventRef.update({'sponsorPackages': packages});

  Future<void> _addOrEditPackage(
      List<Map<String, dynamic>> current, {Map<String, dynamic>? existing, int? index}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final existingAmount = (existing?['amount'] as num?) ?? 0;
    final amountCtrl = TextEditingController(
        text: existingAmount > 0 ? existingAmount.toStringAsFixed(0) : '');
    final perksCtrl = TextEditingController(text: existing?['perks'] as String? ?? '');

    // Validate inline (instead of silently no-op'ing after the dialog closes)
    // so a blank name shows the user why nothing was added, rather than the
    // item just never appearing with no explanation. Amount is optional —
    // not every sponsor item (e.g. a donated idol or flowers) has a fixed
    // price attached.
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        // Declared here (not inside StatefulBuilder's builder) so it survives
        // across setDialogState-triggered rebuilds instead of resetting to
        // null each time.
        String? error;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(existing == null ? 'Add Sponsor Item' : 'Edit Sponsor Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                          labelText: 'Item Name', hintText: 'e.g. Gold, Idol, Flowers'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Amount (₹) (Optional)', hintText: 'e.g. 10000'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: perksCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Perks (optional)',
                          hintText: 'e.g. Logo on banner + mention in program'),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final amountText =
                        amountCtrl.text.trim().replaceAll(',', '').replaceAll('₹', '');
                    if (name.isEmpty) {
                      setDialogState(() => error = 'Enter an item name');
                      return;
                    }
                    if (amountText.isNotEmpty) {
                      final amount = double.tryParse(amountText);
                      if (amount == null || amount < 0) {
                        setDialogState(() => error = 'Enter a valid amount, or leave it blank');
                        return;
                      }
                    }
                    Navigator.pop(ctx, true);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800),
                  child: Text(existing == null ? 'Add' : 'Save',
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameCtrl.dispose();
      amountCtrl.dispose();
      perksCtrl.dispose();
    });

    if (result != true) return;
    final name = nameCtrl.text.trim();
    final amount =
        double.tryParse(amountCtrl.text.trim().replaceAll(',', '').replaceAll('₹', '')) ?? 0;
    final entry = {'name': name, 'amount': amount, 'perks': perksCtrl.text.trim()};

    final updated = List<Map<String, dynamic>>.from(current);
    if (index != null) {
      updated[index] = entry;
    } else {
      updated.add(entry);
    }
    try {
      await _write(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deletePackage(List<Map<String, dynamic>> current, int index) async {
    final name = current[index]['name'] as String? ?? 'this item';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: const Text('Existing sponsorships already recorded for this item are kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final updated = List<Map<String, dynamic>>.from(current)..removeAt(index);
    await _write(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Sponsor Packages',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.amber.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _eventRef.snapshots(),
        builder: (context, snap) {
          final raw = (snap.data?.data() as Map<String, dynamic>?)?['sponsorPackages'];
          final packages = raw != null
              ? List<Map<String, dynamic>>.from(
                  (raw as List).map((e) => Map<String, dynamic>.from(e as Map)))
              : <Map<String, dynamic>>[];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Define sponsor items for this event (e.g. Idol, Flowers, or a named '
                      'tier). Sponsors are then recorded as a "Sponsorship" contribution and '
                      'shown on the "Our Sponsors" wall.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ),
                ]),
              ),
              Expanded(
                child: packages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.workspace_premium_outlined,
                                size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No sponsor items yet',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: packages.length,
                        itemBuilder: (context, i) {
                          final p = packages[i];
                          final color = kSponsorTierColors[i % kSponsorTierColors.length];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p['name'] as String? ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 14)),
                                      if (((p['amount'] as num?) ?? 0) > 0)
                                        Text('₹${(p['amount'] as num).toStringAsFixed(0)}',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green.shade700)),
                                      if ((p['perks'] as String? ?? '').isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(p['perks'] as String,
                                              style: TextStyle(
                                                  fontSize: 11, color: Colors.grey.shade500)),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.edit_outlined,
                                      color: Colors.grey.shade500, size: 18),
                                  onPressed: () =>
                                      _addOrEditPackage(packages, existing: p, index: i),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      color: Colors.red.shade300, size: 18),
                                  onPressed: () => _deletePackage(packages, i),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _addOrEditPackage(packages),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Sponsor Item'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
