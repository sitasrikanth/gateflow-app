import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_contribution_screen.dart';
import 'add_expense_screen.dart';
import 'send_notification_screen.dart';
import 'create_event_screen.dart';

class EventDashboardScreen extends StatefulWidget {
  final String eventId;
  final String eventName;
  final bool isAdmin;

  const EventDashboardScreen({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.isAdmin,
  });

  @override
  State<EventDashboardScreen> createState() => _EventDashboardScreenState();
}

class _EventDashboardScreenState extends State<EventDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _closeEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Event'),
        content: const Text(
            'Are you sure you want to close this event? No more contributions or expenses can be added.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('Close Event',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .update({'status': 'closed'});
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .snapshots(),
      builder: (context, snapshot) {
        final data =
            snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final collected = (data['totalCollected'] ?? 0).toDouble();
        final spent = (data['totalSpent'] ?? 0).toDouble();
        final target = (data['targetAmount'] ?? 0).toDouble();
        final balance = collected - spent;
        final status = data['status'] ?? 'active';
        final progress =
            target > 0 ? (collected / target).clamp(0.0, 1.0) : 0.0;

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          body: Column(
            children: [
              // Header
              Container(
                color: Colors.deepPurple,
                padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                              (data['name'] as String?)?.isNotEmpty == true
                                  ? data['name']
                                  : widget.eventName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ),
                        if (widget.isAdmin)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert,
                                color: Colors.white),
                            onSelected: (val) {
                              if (val == 'close') _closeEvent();
                              if (val == 'edit') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CreateEventScreen(
                                      existingEventId: widget.eventId,
                                      existingData: data,
                                    ),
                                  ),
                                );
                              }
                              if (val == 'notify') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SendNotificationScreen(
                                        eventId: widget.eventId,
                                        eventName: widget.eventName),
                                  ),
                                );
                              }
                            },
                            itemBuilder: (_) => [
                              // Edit always available to admin
                              const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(children: [
                                    Icon(Icons.edit_outlined,
                                        color: Colors.deepPurple),
                                    SizedBox(width: 8),
                                    Text('Edit Event'),
                                  ])),
                              // Notify & close only when active
                              if (status == 'active') ...[
                                const PopupMenuItem(
                                    value: 'notify',
                                    child: Row(children: [
                                      Icon(Icons.notifications_outlined),
                                      SizedBox(width: 8),
                                      Text('Send Notification')
                                    ])),
                                const PopupMenuItem(
                                    value: 'close',
                                    child: Row(children: [
                                      Icon(Icons.lock_outline,
                                          color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Close Event',
                                          style: TextStyle(color: Colors.red))
                                    ])),
                              ],
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Stats cards
                    Row(
                      children: [
                        _HeaderStat(
                            label: 'Collected',
                            value: '₹${_fmt(collected)}',
                            icon: Icons.arrow_downward,
                            color: Colors.green.shade300),
                        const SizedBox(width: 8),
                        _HeaderStat(
                            label: 'Spent',
                            value: '₹${_fmt(spent)}',
                            icon: Icons.arrow_upward,
                            color: Colors.red.shade300),
                        const SizedBox(width: 8),
                        _HeaderStat(
                            label: 'Balance',
                            value: '₹${_fmt(balance)}',
                            icon: Icons.account_balance_wallet_outlined,
                            color: balance >= 0
                                ? Colors.blue.shade200
                                : Colors.orange.shade300),
                      ],
                    ),

                    if (target > 0) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Target: ₹${_fmt(target)}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          Text(
                              '${(progress * 100).toStringAsFixed(0)}% reached',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation(
                              Colors.greenAccent),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.white,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white60,
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Contributions'),
                        Tab(text: 'Expenses'),
                      ],
                    ),
                  ],
                ),
              ),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _OverviewTab(
                        eventId: widget.eventId,
                        collected: collected,
                        spent: spent,
                        balance: balance,
                        data: data),
                    _ContributionsTab(
                        eventId: widget.eventId,
                        isAdmin: widget.isAdmin,
                        status: status),
                    _ExpensesTab(
                        eventId: widget.eventId,
                        isAdmin: widget.isAdmin,
                        status: status),
                  ],
                ),
              ),
            ],
          ),

          // Admin FABs
          floatingActionButton: widget.isAdmin && status == 'active'
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.extended(
                      heroTag: 'expense',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddExpenseScreen(
                              eventId: widget.eventId),
                        ),
                      ),
                      backgroundColor: Colors.red.shade400,
                      icon: const Icon(Icons.remove, color: Colors.white),
                      label: const Text('Add Expense',
                          style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton.extended(
                      heroTag: 'contribution',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddContributionScreen(
                              eventId: widget.eventId),
                        ),
                      ),
                      backgroundColor: Colors.green,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Add Contribution',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ── Overview Tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final String eventId;
  final double collected;
  final double spent;
  final double balance;
  final Map<String, dynamic> data;

  const _OverviewTab({
    required this.eventId,
    required this.collected,
    required this.spent,
    required this.balance,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary cards
        _SummaryCard(
          title: 'Total Collected',
          value: '₹${_fmt(collected)}',
          subtitle: 'From all contributions',
          icon: Icons.arrow_downward,
          color: Colors.green,
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          title: 'Total Spent',
          value: '₹${_fmt(spent)}',
          subtitle: 'All expenses combined',
          icon: Icons.arrow_upward,
          color: Colors.red,
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          title: 'Available Balance',
          value: '₹${_fmt(balance)}',
          subtitle: balance >= 0 ? 'Funds available' : 'Overspent!',
          icon: Icons.account_balance_wallet,
          color: balance >= 0 ? Colors.blue : Colors.orange,
        ),

        if ((data['description'] ?? '').isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('About this Event',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                Text(data['description'],
                    style: TextStyle(
                        color: Colors.grey.shade700, fontSize: 13)),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Quick stats
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Event Details',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              if ((data['startDate'] ?? '').isNotEmpty)
                _DetailRow(
                    label: 'Start Date', value: data['startDate']),
              if ((data['endDate'] ?? '').isNotEmpty)
                _DetailRow(label: 'End Date', value: data['endDate']),
              _DetailRow(
                  label: 'Status',
                  value: data['status'] == 'active'
                      ? '🟢 Active'
                      : '🔴 Closed'),
              if ((data['targetAmount'] ?? 0) > 0)
                _DetailRow(
                    label: 'Target',
                    value: '₹${_fmt((data['targetAmount'] ?? 0).toDouble())}'),
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ── Contributions Tab ─────────────────────────────────────────────────────────

class _ContributionsTab extends StatelessWidget {
  final String eventId;
  final bool isAdmin;
  final String status;

  const _ContributionsTab(
      {required this.eventId,
      required this.isAdmin,
      required this.status});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('contributions')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.payments_outlined,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('No contributions yet',
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 15)),
                if (isAdmin && status == 'active')
                  const Text('Tap + to record a contribution',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          );
        }

        // ── Group by Wing → Block ──────────────────────────────
        // Map<wing, Map<block, List<doc>>>
        final Map<String, Map<String, List<QueryDocumentSnapshot>>> grouped = {};
        double grandTotal = 0;
        int totalCount = 0;

        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final wing = (d['wing'] as String?)?.trim().isNotEmpty == true
              ? d['wing'] as String
              : 'No Wing';
          final block = (d['block'] as String?)?.trim().isNotEmpty == true
              ? d['block'] as String
              : 'No Block';
          grouped.putIfAbsent(wing, () => {});
          grouped[wing]!.putIfAbsent(block, () => []);
          grouped[wing]![block]!.add(doc);
          // Only count received amounts in total
          if (d['amountReceived'] != false) {
            grandTotal += (d['amount'] ?? 0).toDouble();
          }
          totalCount++;
        }

        // Sort wings and blocks alphabetically
        final sortedWings = grouped.keys.toList()..sort();

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // ── Grand total banner ─────────────────────────────
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.payments, color: Colors.green.shade600),
                  const SizedBox(width: 10),
                  Text('$totalCount contributions',
                      style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('Total: ₹${grandTotal.toStringAsFixed(0)}',
                      style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
            ),

            // ── Wing-level expandable tiles ────────────────────
            ...sortedWings.map((wing) {
              final blocksMap = grouped[wing]!;
              final sortedBlocks = blocksMap.keys.toList()..sort();
              final wingTotal = blocksMap.values
                  .expand((list) => list)
                  .fold<double>(0, (sum, doc) {
                final d = doc.data() as Map<String, dynamic>;
                return d['amountReceived'] != false
                    ? sum + (d['amount'] ?? 0).toDouble()
                    : sum;
              });
              final wingCount = blocksMap.values
                  .fold<int>(0, (s, list) => s + list.length);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    // Wing header
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade600,
                      radius: 20,
                      child: Text(
                        wing[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ),
                    title: Text('$wing Wing',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: Text(
                        '$wingCount entries • ₹${wingTotal.toStringAsFixed(0)} received',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '₹${_fmt(wingTotal)}',
                            style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                        const Icon(Icons.expand_more),
                      ],
                    ),
                    children: [
                      // ── Block-level expandable tiles ───────────
                      ...sortedBlocks.map((block) {
                        final blockDocs = blocksMap[block]!;
                        // Sort by flat number within block
                        blockDocs.sort((a, b) {
                          final fa = (a['flatNumber'] ?? '').toString();
                          final fb = (b['flatNumber'] ?? '').toString();
                          final ia = int.tryParse(fa) ?? 0;
                          final ib = int.tryParse(fb) ?? 0;
                          return ia.compareTo(ib);
                        });
                        final blockTotal = blockDocs.fold<double>(0, (s, doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          return d['amountReceived'] != false
                              ? s + (d['amount'] ?? 0).toDouble()
                              : s;
                        });
                        final pendingCount = blockDocs
                            .where((doc) =>
                                (doc.data()
                                    as Map)['amountReceived'] ==
                                false)
                            .length;

                        return Container(
                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.grey.shade200),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: false,
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(block,
                                    style: TextStyle(
                                        color: Colors.purple.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                              ),
                            ),
                            title: Text('$block Block',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            subtitle: Row(
                              children: [
                                Text(
                                    '${blockDocs.length} flats',
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12)),
                                if (pendingCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                    child: Text('$pendingCount pending',
                                        style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                Colors.orange.shade800)),
                                  ),
                                ],
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '₹${_fmt(blockTotal)}',
                                  style: TextStyle(
                                      color: Colors.purple.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                                const Icon(Icons.expand_more),
                              ],
                            ),
                            children: blockDocs.map((doc) {
                              final d =
                                  doc.data() as Map<String, dynamic>;
                              final isPending =
                                  d['amountReceived'] == false;
                              final cType =
                                  d['contributionType'] ?? kTypeRegular;

                              return Container(
                                margin: const EdgeInsets.fromLTRB(
                                    8, 0, 8, 6),
                                decoration: BoxDecoration(
                                  color: isPending
                                      ? Colors.orange.shade50
                                      : Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isPending
                                        ? Colors.orange.shade200
                                        : Colors.grey.shade100,
                                  ),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: isPending
                                        ? Colors.orange.shade100
                                        : Colors.green.shade50,
                                    child: Text(
                                      'F${d['flatNumber'] ?? ''}',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isPending
                                              ? Colors.orange.shade700
                                              : Colors.green.shade700),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          d['residentName']?.isNotEmpty ==
                                                  true
                                              ? d['residentName']
                                              : 'Flat ${d['flatNumber'] ?? ''}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13),
                                        ),
                                      ),
                                      if (cType != kTypeRegular)
                                        _typeBadge(cType),
                                      if (isPending)
                                        _pendingBadge(),
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${d['paymentMode'] ?? 'Cash'} • ${d['paidDate'] ?? ''}${(d['note'] ?? '').isNotEmpty ? ' • ${d['note']}' : ''}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '₹${(d['amount'] ?? 0).toStringAsFixed(0)}',
                                        style: TextStyle(
                                            color: isPending
                                                ? Colors.orange.shade700
                                                : Colors.green.shade700,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14),
                                      ),
                                      if (isAdmin) ...[
                                        const SizedBox(width: 2),
                                        IconButton(
                                          icon: Icon(Icons.edit_outlined,
                                              color:
                                                  Colors.green.shade400,
                                              size: 17),
                                          onPressed: () =>
                                              Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  AddContributionScreen(
                                                eventId: eventId,
                                                existingDocId: doc.id,
                                                existingData: d,
                                              ),
                                            ),
                                          ),
                                          tooltip: 'Edit',
                                          padding: EdgeInsets.zero,
                                          constraints:
                                              const BoxConstraints(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  Widget _typeBadge(String type) => Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: type == kTypeCarryForward
              ? Colors.blue.shade50
              : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          type == kTypeCarryForward ? 'CF' : 'Laddu',
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: type == kTypeCarryForward
                  ? Colors.blue.shade700
                  : Colors.orange.shade700),
        ),
      );

  Widget _pendingBadge() => Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('PENDING',
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade800)),
      );
}

// ── Expenses Tab ──────────────────────────────────────────────────────────────

class _ExpensesTab extends StatelessWidget {
  final String eventId;
  final bool isAdmin;
  final String status;

  const _ExpensesTab(
      {required this.eventId,
      required this.isAdmin,
      required this.status});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('expenses')
          .orderBy('addedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final total = docs.fold<double>(
            0, (acc, d) => acc + ((d['amount'] ?? 0).toDouble()));

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('No expenses recorded',
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 15)),
                if (isAdmin && status == 'active')
                  const Text('Tap + to record an expense',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          );
        }

        // Group by category
        final Map<String, double> byCategory = {};
        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final cat = d['category'] ?? 'Misc';
          byCategory[cat] = (byCategory[cat] ?? 0) + (d['amount'] ?? 0).toDouble();
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Total banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.receipt_long, color: Colors.red.shade600),
                  const SizedBox(width: 10),
                  Text('${docs.length} expenses',
                      style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('Total: ₹${total.toStringAsFixed(0)}',
                      style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Category breakdown
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('By Category',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...byCategory.entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Text(_categoryIcon(e.key),
                                style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(e.key)),
                            Text('₹${e.value.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 12),

            ...docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.shade50,
                    child: Text(
                        (d['categoryIcon'] as String?)?.isNotEmpty == true
                            ? d['categoryIcon']
                            : _categoryIcon(d['category'] ?? 'Misc'),
                        style: const TextStyle(fontSize: 18)),
                  ),
                  title: Text(d['item'] ?? '',
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text([
                    d['category'] ?? 'Misc',
                    if ((d['subCategory'] ?? '').isNotEmpty)
                      d['subCategory'],
                    if ((d['vendor'] ?? '').isNotEmpty) d['vendor'],
                    if ((d['note'] ?? '').isNotEmpty) d['note'],
                  ].join(' • ')),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${(d['amount'] ?? 0).toStringAsFixed(0)}',
                        style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      Text(
                        (d['addedAt'] ?? '').length >= 10
                            ? d['addedAt'].substring(0, 10)
                            : '',
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  String _categoryIcon(String cat) {
    switch (cat) {
      case 'Decoration': return '🎨';
      case 'Food & Prasad': return '🍱';
      case 'Priest / Pandit': return '🙏';
      case 'Music & Sound': return '🎵';
      case 'Transport': return '🚗';
      case 'Flowers': return '🌸';
      case 'Lighting': return '💡';
      default: return '📦';
    }
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _HeaderStat(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SummaryCard(
      {required this.title,
      required this.value,
      required this.subtitle,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 13)),
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              Text(subtitle,
                  style: TextStyle(
                      color: Colors.grey.shade400, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
              width: 80,
              child: Text(label,
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 13))),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

