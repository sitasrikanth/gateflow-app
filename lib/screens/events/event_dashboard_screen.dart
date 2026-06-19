import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import '../admin/admin_home_screen.dart';
import '../resident/resident_home_screen.dart';
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
    _tabController = TabController(
        length: widget.isAdmin ? 4 : 3, vsync: this);
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
        final double collected = ((data['totalCollected'] ?? 0) as num).toDouble();
        final double spent = ((data['totalSpent'] ?? 0) as num).toDouble();
        final double target = ((data['targetAmount'] ?? 0) as num).toDouble();
        final double balance = collected - spent;
        final status = data['status'] ?? 'active';
        final double progress =
            target > 0 ? ((collected / target).clamp(0.0, 1.0) as num).toDouble() : 0.0;

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
                        IconButton(
                          icon: const Icon(Icons.home_rounded,
                              color: Colors.white70),
                          tooltip: 'Home',
                          onPressed: () => Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => widget.isAdmin
                                  ? const AdminHomeScreen()
                                  : const ResidentHomeScreen(),
                            ),
                            (route) => false,
                          ),
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
                        // Logout always visible
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white70),
                          tooltip: 'Logout',
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.clear();
                            if (context.mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen()),
                                (route) => false,
                              );
                            }
                          },
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
                              const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(children: [
                                    Icon(Icons.edit_outlined,
                                        color: Colors.deepPurple),
                                    SizedBox(width: 8),
                                    Text('Edit Event'),
                                  ])),
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
                      tabs: [
                        const Tab(text: 'Overview'),
                        const Tab(text: 'Contributions'),
                        const Tab(text: 'Expenses'),
                        if (widget.isAdmin)
                          const Tab(text: 'Follow-up'),
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
                    if (widget.isAdmin)
                      _FollowUpTab(
                          eventId: widget.eventId,
                          eventName: data['name'] ?? widget.eventName),
                  ],
                ),
              ),
            ],
          ),

          // Admin FABs — tab-aware
          floatingActionButton: widget.isAdmin && status == 'active'
              ? AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) {
                    final tab = _tabController.index;
                    if (tab == 1) {
                      return FloatingActionButton.extended(
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
                      );
                    }
                    if (tab == 2) {
                      return FloatingActionButton.extended(
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
                      );
                    }
                    return const SizedBox.shrink();
                  },
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

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final double target = (data['targetAmount'] as num?)?.toDouble() ?? 0.0;
    final double collectedPct = target > 0 ? ((collected / target).clamp(0.0, 1.0) as num).toDouble() : 0.0;
    final double spentPct     = target > 0 ? ((spent / target).clamp(0.0, 1.0) as num).toDouble() : 0.0;
    final isOverspent  = balance < 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        // ── Budget vs Actual Card ──────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Budget vs Actual',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  if (isOverspent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Overspent!',
                          style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Target row
              if (target > 0) ...[
                _BudgetRow(
                  label: 'Target',
                  value: target,
                  pct: 1.0,
                  color: Colors.grey.shade300,
                  fmt: _fmt,
                  showPct: false,
                ),
                const SizedBox(height: 14),
              ],

              // Collected row
              _BudgetRow(
                label: 'Collected',
                value: collected,
                pct: collectedPct,
                color: Colors.green,
                fmt: _fmt,
                showPct: target > 0,
              ),
              const SizedBox(height: 14),

              // Spent row
              _BudgetRow(
                label: 'Spent',
                value: spent,
                pct: spentPct,
                color: Colors.red.shade400,
                fmt: _fmt,
                showPct: target > 0,
              ),
              const SizedBox(height: 20),

              // Balance highlight
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isOverspent
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOverspent
                        ? Colors.red.shade200
                        : Colors.green.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOverspent
                          ? Icons.warning_rounded
                          : Icons.account_balance_wallet,
                      color: isOverspent
                          ? Colors.red.shade600
                          : Colors.green.shade600,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOverspent ? 'Overspent by' : 'Balance Available',
                          style: TextStyle(
                              fontSize: 12,
                              color: isOverspent
                                  ? Colors.red.shade600
                                  : Colors.green.shade600),
                        ),
                        Text(
                          '₹${_fmt(balance.abs())}',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isOverspent
                                  ? Colors.red.shade700
                                  : Colors.green.shade700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── 3 stat chips ──────────────────────────────────────────
        Row(
          children: [
            _StatChip(
              label: 'Collected',
              value: '₹${_fmt(collected)}',
              icon: Icons.arrow_downward_rounded,
              color: Colors.green,
            ),
            const SizedBox(width: 8),
            _StatChip(
              label: 'Spent',
              value: '₹${_fmt(spent)}',
              icon: Icons.arrow_upward_rounded,
              color: Colors.red,
            ),
            const SizedBox(width: 8),
            _StatChip(
              label: 'Target',
              value: target > 0 ? '₹${_fmt(target)}' : '—',
              icon: Icons.flag_outlined,
              color: Colors.blue,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Event Details ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Event Details',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              if ((data['description'] ?? '').isNotEmpty) ...[
                Text(data['description'],
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 13)),
                const Divider(height: 20),
              ],
              if ((data['startDate'] ?? '').isNotEmpty)
                _DetailRow(label: 'Start Date', value: data['startDate']),
              if ((data['endDate'] ?? '').isNotEmpty)
                _DetailRow(label: 'End Date', value: data['endDate']),
              _DetailRow(
                  label: 'Status',
                  value: data['status'] == 'active'
                      ? '🟢 Active'
                      : '🔴 Closed'),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Budget Row Widget ─────────────────────────────────────────────────────────

class _BudgetRow extends StatelessWidget {
  final String label;
  final double value;
  final double pct;
  final Color color;
  final String Function(double) fmt;
  final bool showPct;

  const _BudgetRow({
    required this.label,
    required this.value,
    required this.pct,
    required this.color,
    required this.fmt,
    required this.showPct,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const Spacer(),
            Text('₹${fmt(value)}',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold)),
            if (showPct) ...[
              const SizedBox(width: 6),
              Text('(${(pct * 100).toStringAsFixed(0)}%)',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

// ── Stat Chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color)),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
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
                    initiallyExpanded: false,
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
                    title: Text(wing,
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
                                    child: Icon(
                                      Icons.home,
                                      size: 16,
                                      color: isPending
                                          ? Colors.orange.shade700
                                          : Colors.green.shade700,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Flat ${d['flatNumber'] ?? ''}',
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
                                    [
                                      if ((d['residentName'] ?? '').isNotEmpty) d['residentName'],
                                      d['paymentMode'] ?? 'Cash',
                                      if ((d['paidDate'] ?? '').isNotEmpty) d['paidDate'],
                                      if ((d['note'] ?? '').isNotEmpty) d['note'],
                                    ].join(' • '),
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
                        color: Colors.black.withValues(alpha: 0.04),
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
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text([
                    d['category'] ?? 'Misc',
                    if ((d['subCategory'] ?? '').isNotEmpty) d['subCategory'],
                    if ((d['vendor'] ?? '').isNotEmpty) d['vendor'],
                    if ((d['note'] ?? '').isNotEmpty) d['note'],
                  ].join(' • ')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
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
                      if (isAdmin) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddExpenseScreen(
                                eventId: eventId,
                                existingExpenseId: doc.id,
                                existingData: d,
                              ),
                            ),
                          ),
                          child: Icon(Icons.edit,
                              size: 18, color: Colors.grey.shade400),
                        ),
                      ],
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

// ── Follow-up Tab ─────────────────────────────────────────────────────────────

class _FollowUpTab extends StatelessWidget {
  final String eventId;
  final String eventName;

  const _FollowUpTab({required this.eventId, required this.eventName});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('community_settings')
          .doc('address')
          .get(),
      builder: (context, settingsSnap) {
        if (!settingsSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final settingsData =
            settingsSnap.data!.data() as Map<String, dynamic>? ?? {};
        final wingBlocks =
            Map<String, dynamic>.from(settingsData['wingBlocks'] ?? {});

        // Build structure: wing → block → flats
        final Map<String, Map<String, List<String>>> structure = {};
        for (final wing in wingBlocks.keys.toList()..sort()) {
          final raw = wingBlocks[wing];
          structure[wing] = {};
          if (raw is Map) {
            for (final block in (raw.keys.toList()..sort())) {
              structure[wing]![block] =
                  (raw[block] is List ? List<String>.from(raw[block] as List) : <String>[])..sort();
            }
          } else if (raw is List) {
            for (final block in (List<String>.from(raw)..sort())) {
              structure[wing]![block] = [block];
            }
          }
        }

        final hasAnyFlats = structure.values
            .any((b) => b.values.any((f) => f.isNotEmpty));

        if (!hasAnyFlats) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.apartment_outlined,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('No flats configured in Settings',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 15)),
              ],
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('events')
              .doc(eventId)
              .collection('contributions')
              .snapshots(),
          builder: (context, contribSnap) {
            final contribDocs = contribSnap.data?.docs ?? [];

            // flat → 'paid' | 'pending'
            final Map<String, String> flatStatus = {};
            for (final doc in contribDocs) {
              final d = doc.data() as Map<String, dynamic>;
              final flat = (d['flatNumber'] as String?)?.trim() ?? '';
              if (flat.isEmpty) continue;
              final received = d['amountReceived'] != false;
              if (flatStatus[flat] == 'paid') continue;
              flatStatus[flat] = received ? 'paid' : 'pending';
            }

            // Count totals
            int totalPending = 0, totalNotRecorded = 0;
            for (final blocks in structure.values) {
              for (final flats in blocks.values) {
                for (final flat in flats) {
                  final s = flatStatus[flat];
                  if (s == null) totalNotRecorded++;
                  else if (s == 'pending') totalPending++;
                }
              }
            }
            final totalUnpaid = totalPending + totalNotRecorded;

            if (totalUnpaid == 0) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 72, color: Colors.green.shade400),
                    const SizedBox(height: 16),
                    const Text('All flats have paid!',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('No pending follow-ups',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 14)),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              children: [
                // Summary banner
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.pending_actions,
                          color: Colors.orange.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$totalUnpaid flat${totalUnpaid == 1 ? '' : 's'} need follow-up',
                          style: TextStyle(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w600,
                              fontSize: 15),
                        ),
                      ),
                      Text(
                        '$totalPending pending · $totalNotRecorded not recorded',
                        style: TextStyle(
                            color: Colors.orange.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // Wing → Block collapsible structure
                ...structure.entries.map((wingEntry) {
                  final wing = wingEntry.key;
                  final blocks = wingEntry.value;

                  // Count unpaid across all blocks in this wing
                  int wingUnpaid = 0;
                  for (final flats in blocks.values) {
                    for (final f in flats) {
                      final s = flatStatus[f];
                      if (s == null || s == 'pending') wingUnpaid++;
                    }
                  }
                  if (wingUnpaid == 0) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: ExpansionTile(
                        initiallyExpanded: false,
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade600,
                          radius: 18,
                          child: Text(wing[0].toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text('$wing Wing',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        subtitle: Text(
                          '$wingUnpaid flat${wingUnpaid == 1 ? '' : 's'} pending',
                          style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                        children: blocks.entries.map((blockEntry) {
                          final block = blockEntry.key;
                          final flats = blockEntry.value;

                          final pendingInBlock = <String>[];
                          final notRecordedInBlock = <String>[];
                          for (final flat in flats) {
                            final s = flatStatus[flat];
                            if (s == null) notRecordedInBlock.add(flat);
                            else if (s == 'pending') pendingInBlock.add(flat);
                          }
                          final blockUnpaid =
                              pendingInBlock.length + notRecordedInBlock.length;
                          if (blockUnpaid == 0) return const SizedBox.shrink();

                          return Container(
                            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: Colors.grey.shade200),
                            ),
                            child: ExpansionTile(
                              key: PageStorageKey(
                                  'followup_${wing}_$block'),
                              initiallyExpanded: false,
                              tilePadding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                              leading: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(block,
                                      style: TextStyle(
                                          color: Colors.purple.shade800,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                ),
                              ),
                              title: Text('Block $block',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              subtitle: Text(
                                '$blockUnpaid flat${blockUnpaid == 1 ? '' : 's'} pending',
                                style: TextStyle(
                                    color: Colors.orange.shade600,
                                    fontSize: 11),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      12, 0, 12, 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (pendingInBlock.isNotEmpty) ...[
                                        _FollowUpChipRow(
                                          label: 'Pending',
                                          flats: pendingInBlock,
                                          color: Colors.orange,
                                          wing: wing,
                                          block: block,
                                          eventName: eventName,
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      if (notRecordedInBlock.isNotEmpty)
                                        _FollowUpChipRow(
                                          label: 'Not Recorded',
                                          flats: notRecordedInBlock,
                                          color: Colors.grey,
                                          wing: wing,
                                          block: block,
                                          eventName: eventName,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }
}

// ── Follow-up chip row (compact, auto-fit) ────────────────────────────────────

class _FollowUpChipRow extends StatelessWidget {
  final String label;
  final List<String> flats;
  final MaterialColor color;
  final String wing;
  final String block;
  final String eventName;

  const _FollowUpChipRow({
    required this.label,
    required this.flats,
    required this.color,
    required this.wing,
    required this.block,
    required this.eventName,
  });

  void _sendBulkReminder(BuildContext context) {
    final flatList = flats.join(', ');
    final message =
        'Hi, this is a reminder for your contribution to "$eventName". '
        'The following flats in $wing Wing – Block $block are yet to pay: $flatList. '
        'Please make the payment at the earliest. Thank you!';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.notifications_active,
                color: Colors.deepPurple, size: 22),
            const SizedBox(width: 8),
            Text('Reminder — $wing Block $block'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${flats.length} flat${flats.length == 1 ? '' : 's'}: $flatList',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(message,
                  style: const TextStyle(fontSize: 13, height: 1.4)),
            ),
            const SizedBox(height: 8),
            Text('Copy and send via WhatsApp or SMS.',
                style:
                    TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Reminder copied for ${flats.length} flat${flats.length == 1 ? '' : 's'}'),
                backgroundColor: Colors.deepPurple,
                duration: const Duration(seconds: 2),
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Message'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.shade200),
              ),
              child: Text(label,
                  style: TextStyle(
                      color: color.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => _sendBulkReminder(context),
              child: Row(
                children: [
                  Icon(Icons.notifications_active_outlined,
                      size: 14, color: Colors.deepPurple.shade400),
                  const SizedBox(width: 3),
                  Text('Send Reminder',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.deepPurple.shade400,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: flats.asMap().entries.map((e) {
              final i = e.key;
              final flat = e.value;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (i > 0) const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color.shade200),
                    ),
                    child: Text(flat,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color.shade700)),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _FollowUpSectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _FollowUpSectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}

// _FollowUpFlatCard removed — replaced by _FollowUpChipRow
class _FollowUpFlatCard extends StatelessWidget {
  final String wing;
  final String block;
  final String flatNumber;
  final String tag;
  final MaterialColor tagColor;
  final String eventName;

  const _FollowUpFlatCard({
    required this.wing,
    required this.block,
    required this.flatNumber,
    required this.tag,
    required this.tagColor,
    required this.eventName,
  });

  void _sendReminder(BuildContext context) {
    final message =
        'Hi, this is a reminder for your contribution to "$eventName" '
        'for flat $flatNumber ($wing). '
        'Please make the payment at the earliest. Thank you!';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.notifications_active,
                color: Colors.deepPurple, size: 22),
            const SizedBox(width: 8),
            const Text('Send Reminder'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Flat: $flatNumber  ·  $wing',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(message,
                  style: const TextStyle(fontSize: 13, height: 1.4)),
            ),
            const SizedBox(height: 10),
            Text('Copy this message and send via WhatsApp or SMS.',
                style:
                    TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Reminder message copied for $flatNumber'),
                  backgroundColor: Colors.deepPurple,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Message'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .where('flatNumber', isEqualTo: flatNumber)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get(),
      builder: (context, snap) {
        final residentName = snap.hasData && snap.data!.docs.isNotEmpty
            ? (snap.data!.docs.first.data()
                        as Map<String, dynamic>)['name'] as String? ??
                ''
            : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tagColor.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(Icons.home_outlined,
                        color: tagColor.shade600, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(flatNumber,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      Text(
                        [
                          '$wing Wing',
                          if (block.isNotEmpty && block != flatNumber)
                            'Block $block',
                          if (residentName.isNotEmpty) residentName,
                        ].join(' · '),
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: tagColor.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: tagColor.shade200),
                  ),
                  child: Text(tag,
                      style: TextStyle(
                          color: tagColor.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  onPressed: () => _sendReminder(context),
                  icon: Icon(Icons.notifications_active_outlined,
                      color: Colors.deepPurple.shade400),
                  tooltip: 'Send Reminder',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade50,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
