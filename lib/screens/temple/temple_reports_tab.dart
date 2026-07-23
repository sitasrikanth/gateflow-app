import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_temple_expense_screen.dart';

// ── Transparency & Tracking ────────────────────────────────────────────────
// Read-only rollup for members (admin sees the same view, plus an Add
// Expense button) — total collected/spent/balance, category breakdowns, and
// a merged, date-sorted audit feed of donations + expenses + asset
// additions, so nothing that moves money or property is invisible to the
// community.

class TempleReportsTab extends StatelessWidget {
  final bool isAdmin;
  const TempleReportsTab({super.key, required this.isAdmin});

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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('templeDonations').snapshots(),
      builder: (context, donationSnap) {
        final donations = (donationSnap.data?.docs ?? []).where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return d['status'] != 'deleted' && d['status'] != 'rejected' && d['amountReceived'] == true;
        }).toList();

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('templeExpenses').snapshots(),
          builder: (context, expenseSnap) {
            final expenses = expenseSnap.data?.docs ?? [];

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('templeAssets').snapshots(),
              builder: (context, assetSnap) {
                final assets = assetSnap.data?.docs ?? [];

                double totalCollected = 0;
                final byCategory = <String, double>{};
                for (final doc in donations) {
                  final d = doc.data() as Map<String, dynamic>;
                  final amt = (d['amount'] as num? ?? 0).toDouble();
                  totalCollected += amt;
                  final cat = d['category'] as String? ?? 'General';
                  byCategory[cat] = (byCategory[cat] ?? 0) + amt;
                }

                double totalSpent = 0;
                final spentByCategory = <String, double>{};
                for (final doc in expenses) {
                  final d = doc.data() as Map<String, dynamic>;
                  final amt = (d['amount'] as num? ?? 0).toDouble();
                  totalSpent += amt;
                  final cat = d['category'] as String? ?? 'Other';
                  spentByCategory[cat] = (spentByCategory[cat] ?? 0) + amt;
                }

                final balance = totalCollected - totalSpent;

                // Merged audit feed — donations, expenses, and asset
                // additions, sorted newest first.
                final feed = <_ActivityEntry>[
                  ...donations.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final name = d['isAnonymous'] == true ? 'Anonymous' : (d['donorName'] as String? ?? '');
                    return _ActivityEntry(
                      date: DateTime.tryParse(d['donatedAt'] as String? ?? '') ?? DateTime.now(),
                      icon: Icons.favorite_outline,
                      color: Colors.green,
                      title: 'Donation from $name',
                      subtitle: '${d['category']} · ${d['donatedDate'] ?? ''}',
                      amount: (d['amount'] as num? ?? 0).toDouble(),
                      isCredit: true,
                    );
                  }),
                  ...expenses.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return _ActivityEntry(
                      date: DateTime.tryParse(d['date'] as String? ?? '') ?? DateTime.now(),
                      icon: Icons.receipt_long_outlined,
                      color: Colors.red,
                      title: d['category'] as String? ?? 'Expense',
                      subtitle: (d['vendor'] as String? ?? '').isNotEmpty
                          ? d['vendor'] as String
                          : 'Temple expense',
                      amount: (d['amount'] as num? ?? 0).toDouble(),
                      isCredit: false,
                    );
                  }),
                  ...assets.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return _ActivityEntry(
                      date: DateTime.tryParse(d['createdAt'] as String? ?? '') ?? DateTime.now(),
                      icon: Icons.museum_outlined,
                      color: Colors.blue,
                      title: 'Asset added: ${d['name']}',
                      subtitle: d['category'] as String? ?? '',
                      amount: null,
                      isCredit: true,
                    );
                  }),
                ]..sort((a, b) => b.date.compareTo(a.date));

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(children: [
                      Expanded(child: _statCard('Collected', '₹${_fmt(totalCollected)}', Colors.green)),
                      const SizedBox(width: 10),
                      Expanded(child: _statCard('Spent', '₹${_fmt(totalSpent)}', Colors.red)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _statCard('Balance', '₹${_fmt(balance)}',
                              balance >= 0 ? Colors.blue : Colors.orange)),
                    ]),
                    if (isAdmin) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AddTempleExpenseScreen()),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Record Expense'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.deepOrange.shade700,
                            side: BorderSide(color: Colors.deepOrange.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                    if (byCategory.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text('Donations by Category',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.grey.shade800)),
                      const SizedBox(height: 10),
                      ..._categoryBars(byCategory, totalCollected, Colors.green),
                    ],
                    if (spentByCategory.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text('Expenses by Category',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.grey.shade800)),
                      const SizedBox(height: 10),
                      ..._categoryBars(spentByCategory, totalSpent, Colors.red),
                    ],
                    const SizedBox(height: 24),
                    Text('Activity Log (Audit Trail)',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.grey.shade800)),
                    const SizedBox(height: 10),
                    if (feed.isEmpty)
                      Text('No temple activity recorded yet', style: TextStyle(color: Colors.grey.shade400))
                    else
                      ...feed.take(50).map((e) => _feedRow(context, e)),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  List<Widget> _categoryBars(Map<String, double> data, double total, MaterialColor color) {
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) {
      final pct = total > 0 ? (e.value / total).clamp(0.0, 1.0) : 0.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              Text('₹${_fmt(e.value)}', style: TextStyle(fontSize: 12, color: color.shade700)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: color.shade50,
                valueColor: AlwaysStoppedAnimation(color.shade400),
              ),
            ),
          ],
        ),
      );
    }).toList();
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

  Widget _feedRow(BuildContext context, _ActivityEntry e) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(children: [
          Icon(e.icon, size: 18, color: e.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodyLarge?.color)),
                Text(e.subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          if (e.amount != null)
            Text('${e.isCredit ? '+' : '−'}₹${_fmt(e.amount!)}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: e.isCredit ? Colors.green.shade700 : Colors.red.shade700)),
        ]),
      );
}

class _ActivityEntry {
  final DateTime date;
  final IconData icon;
  final MaterialColor color;
  final String title;
  final String subtitle;
  final double? amount;
  final bool isCredit;
  _ActivityEntry({
    required this.date,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isCredit,
  });
}
