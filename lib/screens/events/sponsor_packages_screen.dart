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
    final amountCtrl = TextEditingController(
        text: existing != null ? (existing['amount'] as num).toStringAsFixed(0) : '');
    final perksCtrl = TextEditingController(text: existing?['perks'] as String? ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(existing == null ? 'Add Sponsor Tier' : 'Edit Sponsor Tier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Tier Name', hintText: 'e.g. Gold, Silver, Bronze'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Amount (₹)', hintText: 'e.g. 10000'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: perksCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Perks (optional)',
                    hintText: 'e.g. Logo on banner + mention in program'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800),
            child: Text(existing == null ? 'Add' : 'Save',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameCtrl.dispose();
      amountCtrl.dispose();
      perksCtrl.dispose();
    });

    if (result != true) return;
    final name = nameCtrl.text.trim();
    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    if (name.isEmpty || amount <= 0) return;
    final entry = {'name': name, 'amount': amount, 'perks': perksCtrl.text.trim()};

    final updated = List<Map<String, dynamic>>.from(current);
    if (index != null) {
      updated[index] = entry;
    } else {
      updated.add(entry);
    }
    await _write(updated);
  }

  Future<void> _deletePackage(List<Map<String, dynamic>> current, int index) async {
    final name = current[index]['name'] as String? ?? 'this tier';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: const Text('Existing sponsorships already recorded at this tier are kept.'),
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
                      'Define sponsorship tiers for this event. Sponsors are then recorded '
                      'as a "Sponsorship" contribution and shown on the "Our Sponsors" wall.',
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
                            Text('No sponsor tiers yet',
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
                    label: const Text('Add Sponsor Tier'),
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
