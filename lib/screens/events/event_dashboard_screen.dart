import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/login_screen.dart';
import '../admin/admin_home_screen.dart';
import '../resident/resident_home_screen.dart';
import 'add_contribution_screen.dart';
import 'add_expense_screen.dart';
import 'send_notification_screen.dart';
import 'create_event_screen.dart';
import '../../utils/event_pdf_report.dart';
import 'import_contributions_screen.dart';

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
  String _residentFlat = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: widget.isAdmin ? 4 : 3, vsync: this);
    if (!widget.isAdmin) _loadFlat();
  }

  Future<void> _loadFlat() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _residentFlat = prefs.getString('session_flat') ?? '';
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _recalculateTotals(BuildContext context) async {
    try {
      final contribs = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('contributions')
          .get();

      double total = 0;
      for (final doc in contribs.docs) {
        final d = doc.data();
        if (d['amountReceived'] != false) {
          total += (d['amount'] as num? ?? 0).toDouble();
        }
      }

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .update({'totalCollected': total});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Total recalculated: ₹${total.toStringAsFixed(0)} from ${contribs.docs.length} contributions'),
          backgroundColor: Colors.teal,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
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
                        if (!widget.isAdmin)
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf,
                                color: Colors.white70),
                            tooltip: 'Export PDF Report',
                            onPressed: () => exportEventPdfReport(
                              context: context,
                              eventId: widget.eventId,
                              eventData: data,
                              collected: collected,
                              spent: spent,
                              balance: balance,
                              target: target,
                            ),
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
                              if (val == 'import') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ImportContributionsScreen(
                                      eventId: widget.eventId,
                                      eventName: data['name'] ??
                                          widget.eventName,
                                    ),
                                  ),
                                );
                              }
                              if (val == 'pdf') {
                                exportEventPdfReport(
                                  context: context,
                                  eventId: widget.eventId,
                                  eventData: data,
                                  collected: collected,
                                  spent: spent,
                                  balance: balance,
                                  target: target,
                                );
                              }
                              if (val == 'recalculate') _recalculateTotals(context);
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
                                  value: 'import',
                                  child: Row(children: [
                                    Icon(Icons.upload_file_rounded,
                                        color: Colors.teal),
                                    SizedBox(width: 8),
                                    Text('Import Contributions'),
                                  ])),
                              const PopupMenuItem(
                                  value: 'pdf',
                                  child: Row(children: [
                                    Icon(Icons.picture_as_pdf,
                                        color: Colors.deepPurple),
                                    SizedBox(width: 8),
                                    Text('Export PDF Report'),
                                  ])),
                              const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(children: [
                                    Icon(Icons.edit_outlined,
                                        color: Colors.deepPurple),
                                    SizedBox(width: 8),
                                    Text('Edit Event'),
                                  ])),
                              const PopupMenuItem(
                                  value: 'recalculate',
                                  child: Row(children: [
                                    Icon(Icons.sync, color: Colors.teal),
                                    SizedBox(width: 8),
                                    Text('Recalculate Totals'),
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
                        status: status,
                        residentFlat: _residentFlat),
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

class _ContributionsTab extends StatefulWidget {
  final String eventId;
  final bool isAdmin;
  final String status;
  final String residentFlat;

  const _ContributionsTab(
      {required this.eventId,
      required this.isAdmin,
      required this.status,
      this.residentFlat = ''});

  @override
  State<_ContributionsTab> createState() => _ContributionsTabState();
}

class _ContributionsTabState extends State<_ContributionsTab> {

  void _showFlatContribution(
    BuildContext context,
    String wing,
    String block,
    String flat,
    List<QueryDocumentSnapshot> contribs,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (ctx, ctrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                Icon(Icons.home_outlined,
                    color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Text('$wing › Block $block › $flat',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: contribs.isEmpty
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payments_outlined,
                            size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text('No contribution recorded',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 14)),
                        if (widget.isAdmin && widget.status == 'active') ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8))),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Record Contribution'),
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddContributionScreen(
                                    eventId: widget.eventId,
                                    prefillFlat: flat,
                                    prefillWing: wing,
                                    prefillBlock: block,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    )
                  : ListView(
                      controller: ctrl,
                      padding: const EdgeInsets.all(12),
                      children: contribs.map((doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        final isPending = d['amountReceived'] == false;
                        final cType = d['contributionType'] ?? kTypeRegular;
                        final amt =
                            (d['amount'] as num?)?.toDouble() ?? 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isPending
                                ? Colors.orange.shade50
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: isPending
                                    ? Colors.orange.shade200
                                    : Colors.grey.shade200),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: isPending
                                  ? Colors.orange.shade100
                                  : Colors.green.shade50,
                              child: Icon(Icons.home,
                                  size: 16,
                                  color: isPending
                                      ? Colors.orange.shade700
                                      : Colors.green.shade700),
                            ),
                            title: Row(children: [
                              Expanded(
                                  child: Text('Flat ${d['flatNumber'] ?? ''}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13))),
                              if (cType != kTypeRegular) _typeBadge(cType),
                              if (isPending) _pendingBadge(),
                            ]),
                            subtitle: Text(
                              [
                                if ((d['residentName'] ?? '').isNotEmpty)
                                  d['residentName'],
                                d['paymentMode'] ?? 'Cash',
                                if ((d['paidDate'] ?? '').isNotEmpty)
                                  d['paidDate'],
                                if ((d['note'] ?? '').isNotEmpty) d['note'],
                              ].join(' • '),
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('₹${amt.toStringAsFixed(0)}',
                                    style: TextStyle(
                                        color: isPending
                                            ? Colors.orange.shade700
                                            : Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                if (widget.isAdmin) ...[
                                  const SizedBox(width: 2),
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined,
                                        color: Colors.green.shade400,
                                        size: 17),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              AddContributionScreen(
                                            eventId: widget.eventId,
                                            existingDocId: doc.id,
                                            existingData: d,
                                          ),
                                        ),
                                      );
                                    },
                                    tooltip: 'Edit',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        color: Colors.red.shade300,
                                        size: 17),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _deleteContribution(context, doc, d);
                                    },
                                    tooltip: 'Delete',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
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
                if (widget.isAdmin && widget.status == 'active')
                  const Text('Tap + to record a contribution',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          );
        }

        // ── Resident view: show only own flat ──────────────────
        if (!widget.isAdmin) {
          final myFlat = widget.residentFlat.trim();
          final myDocs = myFlat.isEmpty
              ? <QueryDocumentSnapshot>[]
              : docs
                  .where((d) =>
                      (d.data() as Map<String, dynamic>)['flatNumber']
                          ?.toString()
                          .trim() ==
                      myFlat)
                  .toList();
          final myAmount = myDocs.fold<double>(0, (s, d) {
            final data = d.data() as Map<String, dynamic>;
            return data['amountReceived'] != false
                ? s + (data['amount'] as num? ?? 0).toDouble()
                : s;
          });
          final hasPaid =
              myDocs.any((d) => (d.data() as Map)['amountReceived'] != false);
          final hasPending =
              myDocs.any((d) => (d.data() as Map)['amountReceived'] == false);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: hasPaid
                      ? Colors.green.shade50
                      : hasPending
                          ? Colors.orange.shade50
                          : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: hasPaid
                          ? Colors.green.shade200
                          : hasPending
                              ? Colors.orange.shade200
                              : Colors.grey.shade300),
                ),
                child: Row(children: [
                  CircleAvatar(
                    backgroundColor: hasPaid
                        ? Colors.green.shade100
                        : hasPending
                            ? Colors.orange.shade100
                            : Colors.grey.shade200,
                    child: Icon(
                      hasPaid
                          ? Icons.check_circle
                          : hasPending
                              ? Icons.hourglass_top
                              : Icons.payments_outlined,
                      color: hasPaid
                          ? Colors.green.shade700
                          : hasPending
                              ? Colors.orange.shade700
                              : Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Flat $myFlat',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(
                          hasPaid
                              ? 'Payment confirmed  •  ₹${myAmount.toStringAsFixed(0)}'
                              : hasPending
                                  ? 'Payment pending verification'
                                  : 'No contribution recorded yet',
                          style: TextStyle(
                              fontSize: 13,
                              color: hasPaid
                                  ? Colors.green.shade700
                                  : hasPending
                                      ? Colors.orange.shade700
                                      : Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
              if (myDocs.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...myDocs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final isPending = d['amountReceived'] == false;
                  final amt = (d['amount'] as num?)?.toDouble() ?? 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isPending
                          ? Colors.orange.shade50
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isPending
                              ? Colors.orange.shade200
                              : Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(
                            d['contributionType'] ?? kTypeRegular,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          )),
                          if (isPending)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('Pending',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange.shade800,
                                      fontWeight: FontWeight.bold)),
                            ),
                          const SizedBox(width: 8),
                          Text('₹${amt.toStringAsFixed(0)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isPending
                                      ? Colors.orange.shade700
                                      : Colors.green.shade700)),
                        ]),
                        if ([
                          d['paymentMode'],
                          d['paidDate'],
                          d['note']
                        ].any((v) => v?.toString().isNotEmpty == true)) ...[
                          const SizedBox(height: 6),
                          Text(
                            [
                              if ((d['paymentMode'] ?? '').isNotEmpty)
                                d['paymentMode'],
                              if ((d['paidDate'] ?? '').isNotEmpty)
                                d['paidDate'],
                              if ((d['note'] ?? '').isNotEmpty) d['note'],
                            ].join('  •  '),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ],
          );
        }

        // Pending verification cards (self-reported, awaiting admin action)
        final pendingVerification = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['selfReported'] == true &&
              data['amountReceived'] == false &&
              data['status'] != 'rejected';
        }).toList();

        // All confirmed contributions for summary totals
        double grandTotal = 0;
        int totalCount = 0;
        // flat → list of contribution docs
        final Map<String, List<QueryDocumentSnapshot>> flatDocs = {};
        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          if (d['selfReported'] == true &&
              d['amountReceived'] == false &&
              d['status'] != 'rejected') continue;
          final flat = (d['flatNumber'] ?? '').toString().trim();
          if (flat.isNotEmpty) {
            flatDocs.putIfAbsent(flat, () => []);
            flatDocs[flat]!.add(doc);
          }
          if (d['amountReceived'] != false) {
            grandTotal += (d['amount'] ?? 0).toDouble();
          }
          totalCount++;
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('community_settings')
              .doc('address')
              .snapshots(),
          builder: (context, settingsSnap) {
            final settings =
                settingsSnap.data?.data() as Map<String, dynamic>? ?? {};
            final wings =
                List<String>.from(settings['wings'] ?? [])..sort();
            final wingBlocks =
                Map<String, dynamic>.from(settings['wingBlocks'] ?? {});
            final flatsPerFloor = Map<String, int>.from(
              (settings['flatsPerFloor'] as Map<String, dynamic>? ?? {})
                  .map((k, v) => MapEntry(k, (v as num).toInt())),
            );

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // ── Pending Verification section ──────────────────
                if (widget.isAdmin && pendingVerification.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.pending_actions,
                              color: Colors.orange.shade700, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '${pendingVerification.length} Pending Verification',
                            style: TextStyle(
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ]),
                        const SizedBox(height: 2),
                        Text(
                            'Residents reported these payments — confirm or reject each one.',
                            style: TextStyle(
                                color: Colors.orange.shade700, fontSize: 12)),
                        const SizedBox(height: 10),
                        ...pendingVerification.map((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          final amt = (d['amount'] as num?)?.toDouble() ?? 0;
                          final flat = d['flatNumber'] ?? '';
                          final name = d['residentName'] ?? '';
                          final wing = d['wing'] ?? '';
                          final block = d['block'] ?? '';
                          final mode = d['paymentMode'] ?? '';
                          final ref = d['referenceId'] ?? '';
                          final date = d['paidDate'] ?? '';
                          final location = [
                            if (wing.isNotEmpty) wing,
                            if (block.isNotEmpty) 'Block $block',
                            if (flat.isNotEmpty) 'Flat $flat',
                          ].join(' › ');
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: Colors.orange.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          location.isNotEmpty ? location : flat,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14),
                                        ),
                                        if (name.isNotEmpty)
                                          Text(name,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      Colors.grey.shade700)),
                                        const SizedBox(height: 2),
                                        Text(
                                          [
                                            mode,
                                            if (ref.isNotEmpty) 'Ref: $ref',
                                            if (date.isNotEmpty) date,
                                          ].join('  ·  '),
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text('₹${amt.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ]),
                                const SizedBox(height: 10),
                                Row(children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _rejectSelfReport(context, doc),
                                      icon: const Icon(Icons.close, size: 16),
                                      label: const Text('Reject'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red.shade700,
                                        side: BorderSide(
                                            color: Colors.red.shade300),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _confirmSelfReport(
                                          context, doc, amt),
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Confirm'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade600,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ]),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],

                // ── Grand total banner ────────────────────────────
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

                // ── Wing → Block → Flat chip hierarchy ────────────
                for (final wing in wings) ...[
                  _buildWingTile(
                      context, wing, wingBlocks, flatDocs, flatsPerFloor),
                ],

                // ── Unassigned contributions ───────────────────────
                // Contributions whose flatNumber doesn't exist in community settings
                Builder(builder: (_) {
                  final knownFlats = <String>{};
                  for (final wing in wings) {
                    final raw = wingBlocks[wing];
                    if (raw is Map) {
                      for (final block in raw.keys) {
                        final flats = raw[block];
                        if (flats is List) {
                          knownFlats.addAll(flats.map((f) => f.toString()));
                        }
                      }
                    }
                  }
                  final unassigned = flatDocs.entries
                      .where((e) => !knownFlats.contains(e.key))
                      .toList();
                  if (unassigned.isEmpty) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.red.shade50,
                        child: Icon(Icons.warning_amber_rounded,
                            color: Colors.red.shade400, size: 18),
                      ),
                      title: const Text('Unassigned',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${unassigned.length} flat${unassigned.length == 1 ? '' : 's'} not in community structure',
                        style: TextStyle(
                            fontSize: 12, color: Colors.red.shade400),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: unassigned.map((entry) {
                              final flat = entry.key;
                              final docs = entry.value;
                              final amt = docs.fold<double>(0, (s, d) {
                                final data = d.data() as Map<String, dynamic>;
                                return data['amountReceived'] != false
                                    ? s + (data['amount'] as num? ?? 0).toDouble()
                                    : s;
                              });
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.home_outlined,
                                    color: Colors.grey.shade400),
                                title: Text('Flat $flat',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                subtitle: Text(
                                    '${docs.length} contribution${docs.length == 1 ? '' : 's'} · ₹${amt.toStringAsFixed(0)}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500)),
                                trailing: widget.isAdmin
                                    ? TextButton(
                                        onPressed: () => _showFlatContribution(
                                            context, '', '', flat, docs),
                                        child: const Text('View / Delete'),
                                      )
                                    : null,
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 80),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildWingTile(
    BuildContext context,
    String wing,
    Map<String, dynamic> wingBlocks,
    Map<String, List<QueryDocumentSnapshot>> flatDocs,
    Map<String, int> flatsPerFloor,
  ) {
    final raw = wingBlocks[wing];
    final Map<String, dynamic> wingData =
        raw is Map ? Map<String, dynamic>.from(raw) : {};
    final blocks = wingData.keys.toList()..sort();

    int totalFlats = 0;
    int paidFlats = 0;
    for (final block in blocks) {
      final flats = List<String>.from(
          wingData[block] is List ? wingData[block] : []);
      totalFlats += flats.length;
      paidFlats += flats.where((f) => flatDocs[f]?.isNotEmpty ?? false).length;
    }
    final wingTotal = flatDocs.entries
        .where((e) {
          // check if this flat belongs to this wing
          for (final block in blocks) {
            final flats = List<String>.from(
                wingData[block] is List ? wingData[block] : []);
            if (flats.contains(e.key)) return true;
          }
          return false;
        })
        .expand((e) => e.value)
        .fold<double>(0, (s, doc) {
          final d = doc.data() as Map<String, dynamic>;
          return d['amountReceived'] != false
              ? s + (d['amount'] ?? 0).toDouble()
              : s;
        });

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: ExpansionTile(
        key: PageStorageKey('contrib_wing_$wing'),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.blue.shade600,
          child: Text(wing[0].toUpperCase(),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Text('$wing Wing',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$paidFlats/$totalFlats flats paid',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('₹${_fmt(wingTotal)}',
                  style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: blocks.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No blocks configured.',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 13)),
                )
              ]
            : blocks
                .map((block) => _buildBlockTile(
                    context, wing, block, wingData, flatDocs, flatsPerFloor))
                .toList(),
      ),
    );
  }

  Widget _buildBlockTile(
    BuildContext context,
    String wing,
    String block,
    Map<String, dynamic> wingData,
    Map<String, List<QueryDocumentSnapshot>> flatDocs,
    Map<String, int> flatsPerFloor,
  ) {
    final flats = List<String>.from(
        wingData[block] is List ? wingData[block] : [])
      ..sort();
    final fpf = flatsPerFloor['${wing}_$block'];

    final paidCount = flats.where((f) {
      final docs = flatDocs[f] ?? [];
      return docs.any((d) =>
          (d.data() as Map<String, dynamic>)['amountReceived'] != false);
    }).length;
    final pendingCount = flats.where((f) {
      final docs = flatDocs[f] ?? [];
      return docs.isNotEmpty &&
          docs.every((d) =>
              (d.data() as Map<String, dynamic>)['amountReceived'] == false);
    }).length;
    final blockTotal = flats
        .expand((f) => flatDocs[f] ?? [])
        .fold<double>(0, (s, doc) {
      final d = doc.data() as Map<String, dynamic>;
      return d['amountReceived'] != false
          ? s + (d['amount'] ?? 0).toDouble()
          : s;
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.purple.shade100),
        ),
        child: ExpansionTile(
          key: PageStorageKey('contrib_block_${wing}_$block'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
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
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Row(
            children: [
              Text('$paidCount/${flats.length} paid',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              if (pendingCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('$pendingCount pending',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800)),
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('₹${_fmt(blockTotal)}',
                  style: TextStyle(
                      color: Colors.purple.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const Icon(Icons.expand_more),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: flats.isEmpty
                  ? Text('No flats added.',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12))
                  : _buildFlatChips(
                      context, wing, block, flats, flatDocs, fpf),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlatChips(
    BuildContext context,
    String wing,
    String block,
    List<String> flats,
    Map<String, List<QueryDocumentSnapshot>> flatDocs,
    int? fpf,
  ) {
    Widget chip(String flat) {
      final docs = flatDocs[flat] ?? [];
      Color chipColor;
      Color textColor;
      Color borderColor;
      if (docs.isEmpty) {
        chipColor = Colors.grey.shade100;
        textColor = Colors.grey.shade500;
        borderColor = Colors.grey.shade300;
      } else if (docs.any((d) =>
          (d.data() as Map<String, dynamic>)['amountReceived'] != false)) {
        chipColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        borderColor = Colors.green.shade300;
      } else {
        chipColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        borderColor = Colors.orange.shade300;
      }
      final amount = docs.fold<double>(0, (s, d) {
        final data = d.data() as Map<String, dynamic>;
        return data['amountReceived'] != false
            ? s + (data['amount'] as num? ?? 0).toDouble()
            : s;
      });
      return GestureDetector(
        onTap: () => _showFlatContribution(context, wing, block, flat, docs),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: chipColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(flat,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor)),
              Text(
                docs.isEmpty ? '—' : '₹${amount.toStringAsFixed(0)}',
                style: TextStyle(
                    fontSize: 10,
                    color: textColor.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ),
      );
    }

    if (fpf == null || fpf <= 0) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: flats.map(chip).toList(),
      );
    }
    final floors = (flats.length / fpf).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int floor = 0; floor < floors; floor++) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Text('Floor ${floor + 1}',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700)),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children:
                flats.skip(floor * fpf).take(fpf).map(chip).toList(),
          ),
        ],
      ],
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

  static Future<void> _deleteContribution(BuildContext context,
      DocumentSnapshot doc, Map<String, dynamic> d) async {
    final amt = (d['amount'] as num?)?.toDouble() ?? 0;
    final flat = d['flatNumber'] ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Contribution'),
        content: Text(
            'Delete ₹${amt.toStringAsFixed(0)} contribution from Flat $flat? '
            '${d['amountReceived'] != false ? 'This will also deduct the amount from total collected.' : ''}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(doc.reference);
    if (d['amountReceived'] != false) {
      final eventRef = FirebaseFirestore.instance
          .collection('events')
          .doc(doc.reference.parent.parent!.id);
      batch.update(eventRef, {'totalCollected': FieldValue.increment(-amt)});
    }
    await batch.commit();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contribution deleted')));
    }
  }

  static Future<void> _confirmSelfReport(
      BuildContext context, DocumentSnapshot doc, double amt) async {
    final d = doc.data() as Map<String, dynamic>;
    final flat = d['flatNumber'] ?? '';
    final name = d['residentName'] ?? '';
    final phone = d['phone'] ?? '';
    final mode = d['paymentMode'] ?? '';
    final ref = (d['referenceId'] ?? '').toString().trim();
    final eventName = d['eventName'] ?? 'the event';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.check_circle, color: Colors.green.shade600),
          const SizedBox(width: 8),
          const Text('Confirm Payment'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mark ₹${amt.toStringAsFixed(0)} from Flat $flat as received?'),
            const SizedBox(height: 6),
            if (mode.isNotEmpty)
              Text('Mode: $mode${ref.isNotEmpty ? '  ·  Ref: $ref' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final batch = FirebaseFirestore.instance.batch();
    batch.update(doc.reference, {'amountReceived': true, 'status': 'confirmed'});
    final eventRef = FirebaseFirestore.instance
        .collection('events')
        .doc(doc.reference.parent.parent!.id);
    batch.update(eventRef, {'totalCollected': FieldValue.increment(amt)});
    await batch.commit();

    if (!context.mounted) return;

    // WhatsApp option for admin
    final waMsg = Uri.encodeComponent(
      'Hi $name, your payment of ₹${amt.toStringAsFixed(0)} for $eventName has been confirmed by the admin. Thank you!',
    );
    final waUrl = Uri.parse('https://wa.me/91$phone?text=$waMsg');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.check_circle, color: Colors.green.shade600),
          const SizedBox(width: 8),
          const Text('Payment Confirmed'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('₹${amt.toStringAsFixed(0)} from Flat $flat has been added to total collected.'),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Notify $name via WhatsApp?',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Skip')),
          if (phone.isNotEmpty)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white),
              icon: const Icon(Icons.chat, size: 16),
              label: const Text('WhatsApp'),
              onPressed: () async {
                Navigator.pop(ctx);
                final canLaunch = await canLaunchUrl(waUrl);
                await launchUrl(waUrl,
                    mode: canLaunch
                        ? LaunchMode.externalApplication
                        : LaunchMode.platformDefault);
              },
            ),
        ],
      ),
    );
  }

  static Future<void> _rejectSelfReport(
      BuildContext context, DocumentSnapshot doc) async {
    final d = doc.data() as Map<String, dynamic>;
    final flat = d['flatNumber'] ?? '';
    final name = d['residentName'] ?? '';
    final phone = d['phone'] ?? '';
    final amt = (d['amount'] as num?)?.toDouble() ?? 0;

    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.cancel_outlined, color: Colors.red.shade600),
          const SizedBox(width: 8),
          const Text('Reject Payment Report'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Flat $flat — ₹${amt.toStringAsFixed(0)}'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                labelText: 'Reason for rejection',
                hintText: 'e.g. Payment not found in bank records',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Text('The resident will see this reason and can re-submit.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reject')),
        ],
      ),
    );

    final reason = reasonCtrl.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) => reasonCtrl.dispose());

    if (confirmed != true || !context.mounted) return;

    // Mark as rejected (don't delete — resident needs to see the reason)
    await doc.reference.update({
      'status': 'rejected',
      'rejectionReason': reason.isEmpty ? 'Payment not verified' : reason,
      'rejectedAt': DateTime.now().toIso8601String(),
    });

    if (!context.mounted) return;

    // WhatsApp option for admin
    final rejReason = reason.isEmpty ? 'payment could not be verified in bank records' : reason;
    final waMsg = Uri.encodeComponent(
      'Hi $name, your payment report of ₹${amt.toStringAsFixed(0)} could not be confirmed. Reason: $rejReason. Please contact the admin or re-submit with correct details.',
    );
    final waUrl = Uri.parse('https://wa.me/91$phone?text=$waMsg');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.cancel_outlined, color: Colors.red.shade600),
          const SizedBox(width: 8),
          const Text('Report Rejected'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Flat $flat\'s report has been rejected.'),
            const SizedBox(height: 4),
            Text('They will see the rejection reason in their app.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Notify $name via WhatsApp?',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Skip')),
          if (phone.isNotEmpty)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white),
              icon: const Icon(Icons.chat, size: 16),
              label: const Text('WhatsApp'),
              onPressed: () async {
                Navigator.pop(ctx);
                final canLaunch = await canLaunchUrl(waUrl);
                await launchUrl(waUrl,
                    mode: canLaunch
                        ? LaunchMode.externalApplication
                        : LaunchMode.platformDefault);
              },
            ),
        ],
      ),
    );
  }
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

  void _sendReminderDialog(
    BuildContext context,
    String wing,
    String block,
    List<String> unpaidFlats,
  ) {
    final flatList = unpaidFlats.join(', ');
    final message =
        'Hi, this is a reminder for your contribution to "$eventName". '
        'The following flats in $wing Wing – Block $block are yet to pay: $flatList. '
        'Please make the payment at the earliest. Thank you!';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.notifications_active,
              color: Colors.deepPurple, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text('Reminder — $wing Block $block')),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${unpaidFlats.length} flat${unpaidFlats.length == 1 ? '' : 's'}: $flatList',
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
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
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
                content: Text(
                    'Reminder copied for ${unpaidFlats.length} flat${unpaidFlats.length == 1 ? '' : 's'}'),
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
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('community_settings')
          .doc('address')
          .snapshots(),
      builder: (context, settingsSnap) {
        final settings =
            settingsSnap.data?.data() as Map<String, dynamic>? ?? {};
        final wings = List<String>.from(settings['wings'] ?? [])..sort();
        final wingBlocks =
            Map<String, dynamic>.from(settings['wingBlocks'] ?? {});
        final flatsPerFloor = Map<String, int>.from(
          (settings['flatsPerFloor'] as Map<String, dynamic>? ?? {})
              .map((k, v) => MapEntry(k, (v as num).toInt())),
        );

        if (wings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.apartment_outlined,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('No flats configured in Settings',
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 15)),
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
            for (final wing in wings) {
              final raw = wingBlocks[wing];
              final wingData =
                  raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
              for (final block in wingData.keys) {
                final flats = List<String>.from(
                    wingData[block] is List ? wingData[block] : []);
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
                  child: Row(children: [
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
                  ]),
                ),

                // Wing tiles — only wings with unpaid flats
                for (final wing in wings) ...[
                  _buildWingTile(
                      context, wing, wingBlocks, flatStatus, flatsPerFloor),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildWingTile(
    BuildContext context,
    String wing,
    Map<String, dynamic> wingBlocks,
    Map<String, String> flatStatus,
    Map<String, int> flatsPerFloor,
  ) {
    final raw = wingBlocks[wing];
    final wingData =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final blocks = wingData.keys.toList()..sort();

    int wingUnpaid = 0;
    for (final block in blocks) {
      final flats = List<String>.from(
          wingData[block] is List ? wingData[block] : []);
      for (final f in flats) {
        final s = flatStatus[f];
        if (s == null || s == 'pending') wingUnpaid++;
      }
    }
    if (wingUnpaid == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: ExpansionTile(
        key: PageStorageKey('followup_wing_$wing'),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.blue.shade600,
          child: Text(wing[0].toUpperCase(),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Text('$wing Wing',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '$wingUnpaid flat${wingUnpaid == 1 ? '' : 's'} pending',
          style: TextStyle(
              color: Colors.orange.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500),
        ),
        children: blocks
            .map((block) => _buildBlockTile(
                context, wing, block, wingData, flatStatus, flatsPerFloor))
            .toList(),
      ),
    );
  }

  Widget _buildBlockTile(
    BuildContext context,
    String wing,
    String block,
    Map<String, dynamic> wingData,
    Map<String, String> flatStatus,
    Map<String, int> flatsPerFloor,
  ) {
    final flats = List<String>.from(
        wingData[block] is List ? wingData[block] : [])
      ..sort();
    final fpf = flatsPerFloor['${wing}_$block'];

    final unpaidFlats = flats
        .where((f) => flatStatus[f] == null || flatStatus[f] == 'pending')
        .toList();
    final blockUnpaid = unpaidFlats.length;
    if (blockUnpaid == 0) return const SizedBox.shrink();

    final pendingCount =
        flats.where((f) => flatStatus[f] == 'pending').length;
    final notRecordedCount =
        flats.where((f) => flatStatus[f] == null).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.purple.shade100),
        ),
        child: ExpansionTile(
          key: PageStorageKey('followup_block_${wing}_$block'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          controlAffinity: ListTileControlAffinity.leading,
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
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Row(children: [
            if (pendingCount > 0) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('$pendingCount pending',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800)),
              ),
              const SizedBox(width: 4),
            ],
            if (notRecordedCount > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('$notRecordedCount not recorded',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700)),
              ),
          ]),
          trailing: IconButton(
            icon: Icon(Icons.notifications_active_outlined,
                color: Colors.deepPurple.shade400, size: 20),
            tooltip: 'Send Reminder',
            onPressed: () =>
                _sendReminderDialog(context, wing, block, unpaidFlats),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: _buildFlatChips(context, flats, flatStatus, fpf),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlatChips(
    BuildContext context,
    List<String> flats,
    Map<String, String> flatStatus,
    int? fpf,
  ) {
    Widget chip(String flat) {
      final s = flatStatus[flat];
      Color chipColor;
      Color textColor;
      Color borderColor;
      if (s == 'paid') {
        chipColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        borderColor = Colors.green.shade300;
      } else if (s == 'pending') {
        chipColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        borderColor = Colors.orange.shade300;
      } else {
        chipColor = Colors.grey.shade100;
        textColor = Colors.grey.shade500;
        borderColor = Colors.grey.shade300;
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Text(flat,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor)),
      );
    }

    if (fpf == null || fpf <= 0) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: flats.map(chip).toList(),
      );
    }
    final floors = (flats.length / fpf).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int floor = 0; floor < floors; floor++) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Text('Floor ${floor + 1}',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700)),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children:
                flats.skip(floor * fpf).take(fpf).map(chip).toList(),
          ),
        ],
      ],
    );
  }
}

// Dead code kept for reference — superseded by _FollowUpTab inline methods
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
