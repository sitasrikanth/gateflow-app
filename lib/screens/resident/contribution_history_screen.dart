import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/event_pdf_report.dart';
import '../../theme/app_theme.dart';

// ── My Contribution History ───────────────────────────────────────────────────
// Cross-event history for a resident's own flat. Contributions live in
// per-event subcollections (events/{id}/contributions), so this fetches all
// events and queries each one's subcollection for this flat rather than a
// Firestore collectionGroup query — avoids requiring a composite index the
// user would otherwise have to create manually via the Firebase console.

class _HistoryEntry {
  final String docId;
  final String eventName;
  final String eventId;
  final double amount;
  final String contributionType;
  final String paymentMode;
  final String paidDate;
  final String note;
  final String referenceId;
  final bool amountReceived;
  final bool isAnonymous;
  final bool selfReported;
  final Map<String, dynamic> raw;

  _HistoryEntry({
    required this.docId,
    required this.eventName,
    required this.eventId,
    required this.amount,
    required this.contributionType,
    required this.paymentMode,
    required this.paidDate,
    required this.note,
    required this.referenceId,
    required this.amountReceived,
    required this.isAnonymous,
    required this.selfReported,
    required this.raw,
  });
}

class ContributionHistoryScreen extends StatefulWidget {
  const ContributionHistoryScreen({super.key});

  @override
  State<ContributionHistoryScreen> createState() => _ContributionHistoryScreenState();
}

class _ContributionHistoryScreenState extends State<ContributionHistoryScreen> {
  bool _loading = true;
  List<_HistoryEntry> _entries = [];
  double _totalPaid = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionFlat = (prefs.getString('session_flat') ?? '').trim();
    final wing = prefs.getString('session_wing') ?? '';
    final block = prefs.getString('session_block') ?? '';

    // Resolve the exact flat string used in community structure (handles
    // "404" vs "DA404" style suffix differences), same as the event card.
    String resolvedFlat = sessionFlat;
    if (wing.isNotEmpty && block.isNotEmpty) {
      try {
        final settingsDoc = await FirebaseFirestore.instance
            .collection('community_settings')
            .doc('address')
            .get();
        if (settingsDoc.exists) {
          final wingBlocks = (settingsDoc.data() as Map<String, dynamic>?)?['wingBlocks']
                  as Map<String, dynamic>? ??
              {};
          final wingData = wingBlocks[wing] as Map<String, dynamic>? ?? {};
          final flats = (wingData[block] as List?)?.cast<String>() ?? [];
          if (!flats.contains(sessionFlat)) {
            for (final f in flats) {
              if (f.endsWith(sessionFlat) || sessionFlat.endsWith(f)) {
                resolvedFlat = f;
                break;
              }
            }
          }
        }
      } catch (_) {}
    }

    final queryFlats = {sessionFlat, resolvedFlat}.where((f) => f.isNotEmpty).toList();
    if (queryFlats.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final eventsSnap = await FirebaseFirestore.instance.collection('events').get();
      final entries = <_HistoryEntry>[];

      for (final eventDoc in eventsSnap.docs) {
        final eventData = eventDoc.data();
        final eventName = (eventData['name'] as String?) ?? 'Event';
        final contribSnap = await eventDoc.reference
            .collection('contributions')
            .where('flatNumber', whereIn: queryFlats)
            .get();
        for (final doc in contribSnap.docs) {
          final d = doc.data();
          if (d['status'] == 'deleted' || d['status'] == 'rejected') continue;
          entries.add(_HistoryEntry(
            docId: doc.id,
            eventName: eventName,
            eventId: eventDoc.id,
            amount: (d['amount'] as num?)?.toDouble() ?? 0,
            contributionType: (d['contributionType'] as String?) ?? 'Regular Contribution',
            paymentMode: (d['paymentMode'] as String?) ?? 'Cash',
            paidDate: (d['paidDate'] as String?) ?? '',
            note: (d['note'] as String?) ?? '',
            referenceId: (d['referenceId'] as String?) ?? '',
            amountReceived: d['amountReceived'] != false,
            isAnonymous: d['isAnonymous'] == true,
            selfReported: d['selfReported'] == true,
            raw: d,
          ));
        }
      }

      // Most recent first — paidDate is dd/mm/yyyy so sort by parsed date.
      entries.sort((a, b) {
        DateTime? parse(String s) {
          final parts = s.split('/');
          if (parts.length != 3) return null;
          final d = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          final y = int.tryParse(parts[2]);
          if (d == null || m == null || y == null) return null;
          return DateTime(y, m, d);
        }
        final da = parse(a.paidDate);
        final db = parse(b.paidDate);
        if (da == null || db == null) return 0;
        return db.compareTo(da);
      });

      final total = entries
          .where((e) => e.amountReceived)
          .fold<double>(0, (total, e) => total + e.amount);

      if (mounted) {
        setState(() {
          _entries = entries;
          _totalPaid = total;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Contribution History',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.volunteer_activism_rounded,
                          color: Colors.white, size: 30),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('₹${_totalPaid.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold)),
                            const Text('Total contributed across all events',
                                style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _entries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined,
                                  size: 56, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text('No contributions yet',
                                  style: TextStyle(
                                      color: Colors.grey.shade400, fontSize: 15)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _entries.length,
                          itemBuilder: (context, i) => _HistoryCard(entry: _entries[i]),
                        ),
                ),
              ],
            ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final _HistoryEntry entry;
  const _HistoryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isPending = !entry.amountReceived;
    final isSpecial = entry.contributionType != 'Regular Contribution' &&
        entry.contributionType != 'Regular';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isPending ? Colors.orange.shade200 : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: isPending ? Colors.orange.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPending ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
              color: isPending ? Colors.orange.shade600 : Colors.green.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(entry.eventName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    Text('₹${entry.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      [
                        if (entry.paidDate.isNotEmpty) entry.paidDate,
                        entry.paymentMode,
                      ].join(' • '),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    if (isSpecial)
                      _chip('Special', Colors.blue),
                    if (entry.isAnonymous)
                      _chip('Anonymous', Colors.indigo),
                    if (entry.selfReported && isPending)
                      _chip('Awaiting Verification', Colors.orange),
                    if (isPending && !entry.selfReported)
                      _chip('Pending', Colors.orange),
                  ],
                ),
                if (entry.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Note: ${entry.note}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
                if (!isPending) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => exportContributionReceipt(
                      context: context,
                      eventName: entry.eventName,
                      docId: entry.docId,
                      contribution: entry.raw,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download_rounded,
                            size: 14, color: AppTheme.accent.shade400),
                        const SizedBox(width: 4),
                        Text('Download Receipt',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accent.shade400)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, MaterialColor color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: color.shade700)),
      );
}
