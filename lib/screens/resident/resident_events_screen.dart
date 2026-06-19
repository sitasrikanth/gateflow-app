import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import '../events/event_dashboard_screen.dart';

class ResidentEventsScreen extends StatefulWidget {
  const ResidentEventsScreen({super.key});

  @override
  State<ResidentEventsScreen> createState() => _ResidentEventsScreenState();
}

class _ResidentEventsScreenState extends State<ResidentEventsScreen>
    with SingleTickerProviderStateMixin {
  String _flatNumber = '';
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
    setState(() => _flatNumber = prefs.getString('session_flat') ?? '');
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
                  _EventsTab(
                      flatNumber: _flatNumber, status: 'active'),
                  _EventsTab(
                      flatNumber: _flatNumber, status: 'closed'),
                ],
              ),
      ),
    );
  }
}

// ── Events Tab (active or closed) ─────────────────────────────────────────────

class _EventsTab extends StatelessWidget {
  final String flatNumber;
  final String status;
  const _EventsTab({required this.flatNumber, required this.status});

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
  final bool isActive;
  const _EventContributionCard({
    required this.eventDoc,
    required this.flatNumber,
    required this.isActive,
  });

  @override
  State<_EventContributionCard> createState() => _EventContributionCardState();
}

class _EventContributionCardState extends State<_EventContributionCard> {
  List<Map<String, dynamic>> _contributions = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventDoc.id)
        .collection('contributions')
        .where('flatNumber', isEqualTo: widget.flatNumber)
        .get();
    if (mounted) {
      setState(() {
        _contributions = snap.docs.map((d) => d.data()).toList();
        _loaded = true;
      });
    }
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

    final hasPaid = _contributions.isNotEmpty &&
        _contributions.any((c) => c['amountReceived'] != false);
    final hasPending = _contributions.isNotEmpty &&
        _contributions.any((c) => c['amountReceived'] == false);
    final notRecorded = _contributions.isEmpty;

    final statusLabel = notRecorded
        ? 'Not Recorded'
        : hasPending
            ? 'Pending'
            : 'Paid ✓';
    final statusColor = notRecorded
        ? Colors.white60
        : hasPending
            ? Colors.orange.shade200
            : Colors.greenAccent;

    return GestureDetector(
      onTap: () => _openDashboard(context, eventName),
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
            else if (notRecorded)
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
            else
              ...(_contributions.map((c) {
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
                          isPending ? 'Pending' : 'Paid',
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
              })),

            // Tap hint
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Row(
                children: [
                  Icon(Icons.touch_app,
                      size: 14, color: Colors.deepPurple.shade300),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to view $eventName dashboard',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.deepPurple.shade300,
                        fontStyle: FontStyle.italic),
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
