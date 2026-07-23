import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_temple_donation_screen.dart';
import '../../utils/temple_pdf_report.dart';

// ── Temple Donations — tiers, receipts, searchable history ────────────────────
// Admin gets full CRUD; residents can view totals/tiers and submit a donation
// for admin confirmation (self-report pattern, same as Events).

class TempleDonationsTab extends StatefulWidget {
  final bool isAdmin;
  const TempleDonationsTab({super.key, required this.isAdmin});

  @override
  State<TempleDonationsTab> createState() => _TempleDonationsTabState();
}

class _TempleDonationsTabState extends State<TempleDonationsTab> {
  String _search = '';
  String _categoryFilter = 'All';

  static String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      if (i > 0 && fromEnd % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Future<void> _confirmDonation(DocumentReference ref) => ref.update({
        'amountReceived': true,
        'confirmedAt': DateTime.now().toIso8601String(),
      });

  Future<void> _rejectDonation(DocumentReference ref) => ref.update({
        'status': 'rejected',
        'rejectedAt': DateTime.now().toIso8601String(),
      });

  Future<void> _deleteDonation(BuildContext context, DocumentReference ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Donation'),
        content: const Text('This will permanently remove this donation record.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) await ref.delete();
  }

  void _showDetail(BuildContext context, DocumentSnapshot doc, Map<String, dynamic> d) {
    final isAnonymous = d['isAnonymous'] == true;
    final name = isAnonymous ? 'Anonymous Donor' : ((d['donorName'] as String?) ?? '');
    final amount = (d['amount'] as num?)?.toDouble() ?? 0;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(amount > 0 ? '₹${_fmt(amount)}' : (d['inKindDescription'] as String? ?? 'In-Kind'),
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
              const SizedBox(height: 12),
              _detailRow('Category', d['category'] as String? ?? '-'),
              if ((d['tierName'] as String? ?? '').isNotEmpty)
                _detailRow('Tier', d['tierName'] as String),
              _detailRow('Payment Mode', d['paymentMode'] as String? ?? '-'),
              _detailRow('Date', d['donatedDate'] as String? ?? '-'),
              if ((d['note'] as String? ?? '').isNotEmpty) _detailRow('Note', d['note'] as String),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Receipt'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      exportTempleDonationReceipt(context: context, docId: doc.id, donation: d);
                    },
                  ),
                ),
                if (widget.isAdmin) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddTempleDonationScreen(
                                isAdmin: true, existingDocId: doc.id, existingData: d),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade600),
                      label: Text('Delete', style: TextStyle(color: Colors.red.shade600)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deleteDonation(context, doc.reference);
                      },
                    ),
                  ),
                ],
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appSettings')
          .doc('templeDonationConfig')
          .snapshots(),
      builder: (context, configSnap) {
        final configData = configSnap.data?.data() as Map<String, dynamic>? ?? {};
        final rawTiers = configData['tiers'] as List?;
        final tiers = rawTiers != null
            ? List<Map<String, dynamic>>.from(
                rawTiers.map((e) => Map<String, dynamic>.from(e as Map)))
            : <Map<String, dynamic>>[];
        final rawCats = configData['categories'] as List?;
        final categories = rawCats != null && rawCats.isNotEmpty
            ? List<String>.from(rawCats)
            : kDefaultTempleCategories;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('templeDonations').snapshots(),
          builder: (context, snap) {
            final allDocs = snap.data?.docs ?? [];
            final activeDocs = allDocs.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return d['status'] != 'deleted' && d['status'] != 'rejected';
            }).toList();

            final confirmed = activeDocs.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return d['amountReceived'] == true;
            }).toList();
            final pending = activeDocs.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return d['selfReported'] == true && d['amountReceived'] != true;
            }).toList();

            double totalRaised = 0;
            double thisMonth = 0;
            final donors = <String>{};
            final now = DateTime.now();
            for (final doc in confirmed) {
              final d = doc.data() as Map<String, dynamic>;
              final amt = (d['amount'] as num? ?? 0).toDouble();
              totalRaised += amt;
              final name = (d['donorName'] as String? ?? '').trim();
              if (name.isNotEmpty && d['isAnonymous'] != true) donors.add(name);
              final donatedAt = DateTime.tryParse(d['donatedAt'] as String? ?? '');
              if (donatedAt != null &&
                  donatedAt.year == now.year &&
                  donatedAt.month == now.month) {
                thisMonth += amt;
              }
            }

            // Client-side search/filter over the already-fetched confirmed list —
            // matches the pattern used across the app's other search/filter UIs.
            final filtered = confirmed.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              if (_categoryFilter != 'All' && d['category'] != _categoryFilter) return false;
              if (_search.isNotEmpty) {
                final name = (d['donorName'] as String? ?? '').toLowerCase();
                if (!name.contains(_search.toLowerCase())) return false;
              }
              return true;
            }).toList()
              ..sort((a, b) {
                final ad = (a.data() as Map<String, dynamic>)['donatedAt'] as String? ?? '';
                final bd = (b.data() as Map<String, dynamic>)['donatedAt'] as String? ?? '';
                return bd.compareTo(ad);
              });

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Stats ──────────────────────────────────────────
                Row(children: [
                  Expanded(child: _statCard('Total Raised', '₹${_fmt(totalRaised)}', Colors.green)),
                  const SizedBox(width: 10),
                  Expanded(child: _statCard('This Month', '₹${_fmt(thisMonth)}', Colors.blue)),
                  const SizedBox(width: 10),
                  Expanded(child: _statCard('Donors', '${donors.length}', Colors.deepOrange)),
                ]),
                const SizedBox(height: 20),

                // ── Contribute / Record button ─────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddTempleDonationScreen(isAdmin: widget.isAdmin),
                      ),
                    ),
                    icon: const Icon(Icons.favorite_outline),
                    label: Text(widget.isAdmin ? 'Record Donation' : 'Contribute'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                // ── Tiers ───────────────────────────────────────────
                if (tiers.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Contribution Tiers',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14, color: Colors.grey.shade800)),
                  const SizedBox(height: 10),
                  ...tiers.map((t) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.deepOrange.shade100),
                        ),
                        child: Row(children: [
                          Icon(Icons.workspace_premium_outlined, color: Colors.deepOrange.shade700),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t['name'] as String? ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                if ((t['benefits'] as String? ?? '').isNotEmpty)
                                  Text(t['benefits'] as String,
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                          Text('₹${_fmt(((t['amount'] as num?) ?? 0).toDouble())}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                        ]),
                      )),
                ],

                // ── Pending verification (admin only) ──────────────
                if (widget.isAdmin && pending.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Pending Verification',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14, color: Colors.orange.shade800)),
                  const SizedBox(height: 10),
                  ...pending.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final amount = (d['amount'] as num?)?.toDouble() ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d['donorName'] as String? ?? '',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                              Text(amount > 0 ? '₹${_fmt(amount)} · ${d['category']}' : '${d['category']}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.check_circle, color: Colors.green.shade600),
                          tooltip: 'Confirm',
                          onPressed: () => _confirmDonation(doc.reference),
                        ),
                        IconButton(
                          icon: Icon(Icons.cancel, color: Colors.red.shade400),
                          tooltip: 'Reject',
                          onPressed: () => _rejectDonation(doc.reference),
                        ),
                      ]),
                    );
                  }),
                ],

                // ── History / search + filter ──────────────────────
                const SizedBox(height: 24),
                Text('Donation History',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14, color: Colors.grey.shade800)),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search by donor name…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', ...categories].map((c) {
                      final sel = _categoryFilter == c;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(c),
                          selected: sel,
                          onSelected: (_) => setState(() => _categoryFilter = c),
                          selectedColor: Colors.deepOrange.shade600,
                          labelStyle: TextStyle(
                              color: sel ? Colors.white : Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 12),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('No donations found', style: TextStyle(color: Colors.grey.shade400)),
                    ),
                  )
                else
                  ...filtered.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final isAnonymous = d['isAnonymous'] == true;
                    final name = isAnonymous ? 'Anonymous Donor' : ((d['donorName'] as String?) ?? '');
                    final amount = (d['amount'] as num?)?.toDouble() ?? 0;
                    return GestureDetector(
                      onTap: () => _showDetail(context, doc, d),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.deepOrange.shade50,
                            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(
                                    color: Colors.deepOrange.shade700, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: Theme.of(context).textTheme.bodyLarge?.color)),
                                Text('${d['category']} · ${d['donatedDate']}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                          Text(amount > 0 ? '₹${_fmt(amount)}' : 'In-Kind',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                        ]),
                      ),
                    );
                  }),
                const SizedBox(height: 24),
              ],
            );
          },
        );
      },
    );
  }

  Widget _statCard(String label, String value, MaterialColor color) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.shade100),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color.shade800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: color.shade600)),
        ]),
      );
}
