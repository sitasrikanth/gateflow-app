import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import '../events/event_dashboard_screen.dart';

// Payment modes shown to residents
const _kPaymentModes = ['PhonePe', 'Google Pay', 'NEFT / RTGS', 'Cash', 'Other'];

class ResidentEventsScreen extends StatefulWidget {
  const ResidentEventsScreen({super.key});

  @override
  State<ResidentEventsScreen> createState() => _ResidentEventsScreenState();
}

class _ResidentEventsScreenState extends State<ResidentEventsScreen>
    with SingleTickerProviderStateMixin {
  String _flatNumber = '';
  String _residentName = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _flatNumber = prefs.getString('session_flat') ?? '';
      _residentName = prefs.getString('session_name') ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: Colors.deepPurple,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('My Events',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.celebration,
                      size: 48, color: Colors.white24),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white70),
                tooltip: 'Logout',
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Active Events'),
                Tab(text: 'Closed Events'),
              ],
            ),
          ),
        ],
        body: _flatNumber.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _EventsTab(flatNumber: _flatNumber, residentName: _residentName, status: 'active'),
                  _EventsTab(flatNumber: _flatNumber, residentName: _residentName, status: 'closed'),
                ],
              ),
      ),
    );
  }
}

// ── Events Tab (active or closed) ─────────────────────────────────────────────

class _EventsTab extends StatelessWidget {
  final String flatNumber;
  final String residentName;
  final String status;
  const _EventsTab({required this.flatNumber, required this.residentName, required this.status});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final events = snapshot.data?.docs ?? [];

        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.celebration_outlined,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  status == 'active'
                      ? 'No active events right now'
                      : 'No closed events yet',
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 15,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (context, i) => _EventContributionCard(
            eventDoc: events[i],
            flatNumber: flatNumber,
            residentName: residentName,
            isActive: status == 'active',
          ),
        );
      },
    );
  }
}

// ── Event Contribution Card ───────────────────────────────────────────────────

class _EventContributionCard extends StatefulWidget {
  final QueryDocumentSnapshot eventDoc;
  final String flatNumber;
  final String residentName;
  final bool isActive;
  const _EventContributionCard({
    required this.eventDoc,
    required this.flatNumber,
    required this.residentName,
    required this.isActive,
  });

  @override
  State<_EventContributionCard> createState() => _EventContributionCardState();
}

class _EventContributionCardState extends State<_EventContributionCard> {
  List<Map<String, dynamic>> _contributions = [];
  List<({String label, int total, int paid})> _blockStats = [];
  bool _loaded = false;
  StreamSubscription<QuerySnapshot>? _contribSub;
  // Flat number as it appears in community structure (may differ from session_flat)
  String _resolvedFlat = '';

  @override
  void initState() {
    super.initState();
    _resolveAndSubscribe();
  }

  @override
  void dispose() {
    _contribSub?.cancel();
    super.dispose();
  }

  // Resolve the exact flat string from community structure, then start subscription
  Future<void> _resolveAndSubscribe() async {
    final prefs = await SharedPreferences.getInstance();
    final wing = prefs.getString('session_wing') ?? '';
    final block = prefs.getString('session_block') ?? '';
    final sessionFlat = widget.flatNumber.trim();
    String resolvedFlat = sessionFlat;

    if (wing.isNotEmpty && block.isNotEmpty) {
      try {
        final settingsDoc = await FirebaseFirestore.instance
            .collection('community_settings')
            .doc('address')
            .get();
        if (settingsDoc.exists) {
          final wingBlocks = (settingsDoc.data() as Map<String, dynamic>?)?['wingBlocks']
              as Map<String, dynamic>? ?? {};
          final wingData = wingBlocks[wing] as Map<String, dynamic>? ?? {};
          final flats = (wingData[block] as List?)?.cast<String>() ?? [];
          if (flats.contains(sessionFlat)) {
            resolvedFlat = sessionFlat; // exact match
          } else {
            // Suffix match: "404" → "DA404"
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

    if (!mounted) return;
    setState(() => _resolvedFlat = resolvedFlat);

    // Query using both session flat and resolved flat to catch old and new data
    final queryFlats = {sessionFlat, resolvedFlat}.toList();

    _contribSub = FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventDoc.id)
        .collection('contributions')
        .where('flatNumber', whereIn: queryFlats)
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _contributions = snap.docs.map((d) => d.data()).toList();
          _loaded = true;
        });
        _loadBlockStats();
      }
    });

    _loadBlockStats();
  }

  Future<void> _loadBlockStats() async {
    final eventId = widget.eventDoc.id;
    final results = await Future.wait([
      FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('contributions')
          .get(),
      FirebaseFirestore.instance
          .collection('community_settings')
          .doc('address')
          .get(),
    ]);

    final allSnap = results[0] as QuerySnapshot;
    final settingsDoc = results[1] as DocumentSnapshot;

    final paidFlats = <String>{};
    for (final d in allSnap.docs) {
      final data = d.data() as Map<String, dynamic>;
      if (data['amountReceived'] != false && data['status'] != 'rejected') {
        paidFlats.add(data['flatNumber'] as String? ?? '');
      }
    }

    final blockStatsList = <({String label, int total, int paid})>[];
    if (settingsDoc.exists) {
      final data = settingsDoc.data() as Map<String, dynamic>;
      final wingBlocks = data['wingBlocks'] as Map<String, dynamic>? ?? {};
      for (final wing in wingBlocks.keys) {
        final blocks = wingBlocks[wing] as Map<String, dynamic>? ?? {};
        for (final block in blocks.keys) {
          final flats = (blocks[block] as List?)?.cast<String>() ?? [];
          if (flats.isEmpty) continue;
          final paid = flats.where((f) => paidFlats.contains(f)).length;
          blockStatsList.add((label: '$wing $block', total: flats.length, paid: paid));
        }
      }
    }

    if (mounted) setState(() => _blockStats = blockStatsList);
  }

  Future<void> _selfReport(BuildContext context, String eventName) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SelfReportSheet(
        eventId: widget.eventDoc.id,
        eventName: eventName,
        flatNumber: _resolvedFlat.isNotEmpty ? _resolvedFlat : widget.flatNumber,
        residentName: widget.residentName,
        onSubmitted: _loadBlockStats,
      ),
    );
  }

  void _openDashboard(BuildContext context, String eventName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDashboardScreen(
          eventId: widget.eventDoc.id,
          eventName: eventName,
          isAdmin: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.eventDoc.data() as Map<String, dynamic>;
    final eventName = event['name'] ?? 'Event';
    final double target = (event['targetAmount'] as num?)?.toDouble() ?? 0.0;
    final double collected = (event['totalCollected'] as num?)?.toDouble() ?? 0.0;
    final double progress =
        target > 0 ? ((collected / target).clamp(0.0, 1.0) as num).toDouble() : 0.0;

    final confirmedContribs = _contributions
        .where((c) => c['amountReceived'] != false && c['status'] != 'rejected')
        .toList();
    final pendingContribs = _contributions
        .where((c) => c['amountReceived'] == false && c['status'] != 'rejected')
        .toList();
    final rejectedContribs = _contributions
        .where((c) => c['status'] == 'rejected')
        .toList();

    final hasPaid = confirmedContribs.isNotEmpty;
    final hasPending = pendingContribs.isNotEmpty;
    final hasRejected = rejectedContribs.isNotEmpty;
    final notRecorded = _contributions.isEmpty || (!hasPaid && !hasPending && hasRejected);

    final statusLabel = !_loaded
        ? '...'
        : hasPaid
            ? 'Paid ✓'
            : hasPending
                ? 'Pending'
                : hasRejected
                    ? 'Action Required'
                    : 'Not Recorded';
    final statusColor = !_loaded
        ? Colors.white60
        : hasPaid
            ? Colors.greenAccent
            : hasPending
                ? Colors.orange.shade200
                : hasRejected
                    ? Colors.red.shade200
                    : Colors.white60;

    // Don't navigate to dashboard when rejection is shown inline — resident
    // should read the reason and re-submit, not be taken away from the card.
    final onCardTap = hasRejected && !hasPaid
        ? null
        : () => _openDashboard(context, eventName);

    return GestureDetector(
      onTap: onCardTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.deepPurple.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.isActive
                      ? [const Color(0xFF6A1B9A), const Color(0xFF9C27B0)]
                      : [Colors.grey.shade600, Colors.grey.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.isActive
                        ? Icons.celebration
                        : Icons.celebration_outlined,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(eventName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            // Progress bar
            if (target > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Event Progress',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500)),
                        Text(
                            '₹${collected.toStringAsFixed(0)} / ₹${target.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.deepPurple)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: const AlwaysStoppedAnimation(
                            Colors.deepPurple),
                      ),
                    ),
                  ],
                ),
              ),

            // Block-level collection summary
            if (_loaded && _blockStats.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text('Collection Status by Block',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.3)),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _blockStats.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final s = _blockStats[i];
                    final allPaid = s.paid == s.total;
                    final nonePaid = s.paid == 0;
                    final bgColor = allPaid
                        ? Colors.green.shade50
                        : nonePaid
                            ? Colors.grey.shade100
                            : Colors.orange.shade50;
                    final borderColor = allPaid
                        ? Colors.green.shade300
                        : nonePaid
                            ? Colors.grey.shade300
                            : Colors.orange.shade300;
                    final textColor = allPaid
                        ? Colors.green.shade700
                        : nonePaid
                            ? Colors.grey.shade600
                            : Colors.orange.shade700;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        '${s.label}  ${s.paid}/${s.total}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textColor),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
            ],

            const Divider(height: 20, indent: 16, endIndent: 16),

            // Contribution details
            if (!_loaded)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                    child: SizedBox(
                        height: 20,
                        width: 20,
                        child:
                            CircularProgressIndicator(strokeWidth: 2))),
              )
            else if (notRecorded && !hasRejected)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.grey.shade400, size: 16),
                    const SizedBox(width: 8),
                    Text('Your contribution has not been recorded yet.',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13)),
                  ],
                ),
              )
            else ...[
              // Confirmed & pending entries
              ...[...confirmedContribs, ...pendingContribs].map((c) {
                final isPending = c['amountReceived'] == false;
                final amount = (c['amount'] ?? 0).toStringAsFixed(0);
                final type = c['contributionType'] ?? 'Regular';
                final mode = c['paymentMode'] ?? '';
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Row(
                    children: [
                      Icon(
                        isPending
                            ? Icons.hourglass_top_rounded
                            : Icons.check_circle_rounded,
                        color: isPending
                            ? Colors.orange.shade600
                            : Colors.green.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          [type, if (mode.isNotEmpty) mode].join(' • '),
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ),
                      Text('₹$amount',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isPending
                              ? Colors.orange.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: isPending
                                  ? Colors.orange.shade200
                                  : Colors.green.shade200),
                        ),
                        child: Text(
                          isPending ? 'Pending Verification' : 'Paid',
                          style: TextStyle(
                              color: isPending
                                  ? Colors.orange.shade700
                                  : Colors.green.shade700,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              // Rejected entries with reason
              ...rejectedContribs.map((c) {
                final amount = (c['amount'] ?? 0).toStringAsFixed(0);
                final mode = c['paymentMode'] ?? '';
                final reason = c['rejectionReason'] ?? 'Payment not verified';
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.cancel_outlined,
                            color: Colors.red.shade600, size: 16),
                        const SizedBox(width: 6),
                        Text('₹$amount${mode.isNotEmpty ? ' · $mode' : ''}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Rejected',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade700)),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text('Reason: $reason',
                          style: TextStyle(
                              fontSize: 12, color: Colors.red.shade600)),
                      const SizedBox(height: 2),
                      Text('Please re-submit with correct details.',
                          style: TextStyle(
                              fontSize: 11, color: Colors.red.shade400)),
                    ],
                  ),
                );
              }),
            ],

            // Action row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  // I've Paid button — show for active events when not fully paid
                  if (widget.isActive && !hasPaid)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _selfReport(context, eventName),
                        icon: const Icon(Icons.payments_rounded, size: 16),
                        label: Text(
                          hasRejected ? 'Re-submit Payment' : hasPending ? 'Report Another Payment' : "I've Paid",
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  if (widget.isActive && !hasPaid) const SizedBox(width: 10),
                  // View dashboard hint
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openDashboard(context, eventName),
                      icon: Icon(Icons.open_in_new,
                          size: 14, color: Colors.deepPurple.shade400),
                      label: Text('Dashboard',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.deepPurple.shade400)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.deepPurple.shade200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Self-Report Payment Bottom Sheet ─────────────────────────────────────────

class _SelfReportSheet extends StatefulWidget {
  final String eventId;
  final String eventName;
  final String flatNumber;
  final String residentName;
  final VoidCallback onSubmitted;

  const _SelfReportSheet({
    required this.eventId,
    required this.eventName,
    required this.flatNumber,
    required this.residentName,
    required this.onSubmitted,
  });

  @override
  State<_SelfReportSheet> createState() => _SelfReportSheetState();
}

class _SelfReportSheetState extends State<_SelfReportSheet> {
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  String _mode = 'PhonePe';
  DateTime _date = DateTime.now();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
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

      // widget.flatNumber is already resolved to community structure exact string by the caller
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
        'contributionType': 'Regular',
        'paymentMode': _mode,
        'referenceId': _refCtrl.text.trim(),
        'note': '',
        'amountReceived': false,
        'selfReported': true,
        'status': 'pending',
        'eventName': widget.eventName,
        'paidAt': _date.toIso8601String(),
        'paidDate': _fmtDate(_date),
        'reportedAt': DateTime.now().toIso8601String(),
      });

      widget.onSubmitted();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
              'Payment reported! The admin will verify and confirm it shortly.'),
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
                    const Text('Report Your Payment',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(widget.eventName,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 20),

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
                style:
                    TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _kPaymentModes.map((m) {
                final sel = _mode == m;
                return GestureDetector(
                  onTap: () => setState(() => _mode = m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel
                          ? Colors.green.shade600
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel
                              ? Colors.green.shade600
                              : Colors.grey.shade300),
                    ),
                    child: Text(m,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: sel
                                ? Colors.white
                                : Colors.grey.shade700)),
                  ),
                );
              }).toList(),
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
                label: Text(_submitting ? 'Submitting…' : 'Submit Payment Report'),
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
