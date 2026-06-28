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
  final bool hideAppBarBackButton;

  const EventDashboardScreen({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.isAdmin,
    this.hideAppBarBackButton = false,
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
        length: widget.isAdmin ? 7 : 4, vsync: this);
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
      final paidFlats = <String>{};
      for (final doc in contribs.docs) {
        final d = doc.data();
        if (d['status'] == 'deleted') continue;
        if (d['selfReported'] == true && d['amountReceived'] != true) continue;
        if (d['amountReceived'] == true) {
          total += (d['amount'] as num? ?? 0).toDouble();
          final flat = (d['flatNumber'] as String? ?? '').trim();
          if (flat.isNotEmpty) paidFlats.add(flat);
        }
      }

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .update({'totalCollected': total});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Total recalculated: ₹${total.toStringAsFixed(0)} from ${paidFlats.length} flats'),
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
                        if (!widget.hideAppBarBackButton)
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
                            icon: const Icon(Icons.settings_outlined,
                                color: Colors.white),
                            tooltip: 'Event Tools',
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
                              if (val == 'cf' || val == 'laddu') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddContributionScreen(
                                      eventId: widget.eventId,
                                      prefillContributionType: val == 'cf'
                                          ? kTypeCarryForward
                                          : kTypeGaneshLaddu,
                                    ),
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
                              ],
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                  value: 'cf',
                                  child: Row(children: [
                                    Icon(Icons.history, color: Colors.blue),
                                    SizedBox(width: 8),
                                    Text('Add Carry Forward'),
                                  ])),
                              const PopupMenuItem(
                                  value: 'laddu',
                                  child: Row(children: [
                                    Icon(Icons.cookie_outlined,
                                        color: Colors.orange),
                                    SizedBox(width: 8),
                                    Text('Add Ganesh Laddu'),
                                  ])),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(children: [
                                    Icon(Icons.edit_outlined,
                                        color: Colors.deepPurple),
                                    SizedBox(width: 8),
                                    Text('Edit Event'),
                                  ])),
                              if (status == 'active')
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
                          Text('Expected: ₹${_fmt(target)}',
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

                  ],
                ),
              ),

              // ── Tab bar: grocery-style for admin, classic for resident ──
              if (widget.isAdmin)
                _CustomTabBar(
                  controller: _tabController,
                  tabs: const [
                    _TabItem(icon: Icons.dashboard_outlined, label: 'Overview'),
                    _TabItem(icon: Icons.event_note_outlined, label: 'Event'),
                    _TabItem(icon: Icons.volunteer_activism_outlined, label: 'Contributions'),
                    _TabItem(icon: Icons.receipt_long_outlined, label: 'Expenses'),
                    _TabItem(icon: Icons.pending_actions_outlined, label: 'Follow-up'),
                    _TabItem(icon: Icons.groups_outlined, label: 'Volunteers'),
                    _TabItem(icon: Icons.history_outlined, label: 'Activity'),
                  ],
                )
              else
                Container(
                  color: Colors.deepPurple,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    tabs: const [
                      Tab(text: 'Event'),
                      Tab(text: 'Overview'),
                      Tab(text: 'Expenses'),
                      Tab(text: 'Volunteers'),
                    ],
                  ),
                ),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: widget.isAdmin
                      ? [
                          // Admin: Overview | Event | Contributions | Expenses | Follow-up | Volunteers | Activity
                          _OverviewTab(
                              eventId: widget.eventId,
                              collected: collected,
                              spent: spent,
                              balance: balance,
                              data: data,
                              isAdmin: true),
                          _EventTab(
                              eventId: widget.eventId,
                              data: data,
                              isAdmin: true),
                          _ContributionsTab(
                              eventId: widget.eventId,
                              isAdmin: true,
                              status: status,
                              residentFlat: _residentFlat),
                          _ExpensesTab(
                              eventId: widget.eventId,
                              isAdmin: true,
                              status: status),
                          _FollowUpTab(
                              eventId: widget.eventId,
                              eventName: data['name'] ?? widget.eventName),
                          _VolunteersTab(
                              eventId: widget.eventId,
                              isAdmin: true),
                          _ActivityTab(eventId: widget.eventId),
                        ]
                      : [
                          // Resident: Event (default) | Overview | Expenses | Volunteers
                          _EventTab(
                              eventId: widget.eventId,
                              data: data,
                              isAdmin: false),
                          _OverviewTab(
                              eventId: widget.eventId,
                              collected: collected,
                              spent: spent,
                              balance: balance,
                              data: data,
                              isAdmin: false),
                          _ExpensesTab(
                              eventId: widget.eventId,
                              isAdmin: false,
                              status: status),
                          _VolunteersTab(
                              eventId: widget.eventId,
                              isAdmin: false),
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
                    // Admin tab order: 0=Overview, 1=Event, 2=Contributions, 3=Expenses, 4=Follow-up, 5=Volunteers, 6=Activity
                    if (tab == 2) {
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
                    if (tab == 3) {
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

// ── Custom Tab Bar ────────────────────────────────────────────────────────────

class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem({required this.icon, required this.label});
}

class _CustomTabBar extends StatefulWidget {
  final TabController controller;
  final List<_TabItem> tabs;
  const _CustomTabBar({required this.controller, required this.tabs});

  @override
  State<_CustomTabBar> createState() => _CustomTabBarState();
}

class _CustomTabBarState extends State<_CustomTabBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.controller.index;
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: List.generate(widget.tabs.length, (i) {
            final tab = widget.tabs[i];
            final isSel = selected == i;
            return GestureDetector(
              onTap: () => widget.controller.animateTo(i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSel
                                ? Colors.deepPurple.shade50
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            tab.icon,
                            size: 22,
                            color: isSel
                                ? Colors.deepPurple
                                : Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                            color: isSel
                                ? Colors.deepPurple
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 3,
                    width: isSel ? 48 : 0,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Overview Tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final String eventId;
  final double collected;
  final double spent;
  final double balance;
  final Map<String, dynamic> data;
  final bool isAdmin;

  const _OverviewTab({
    required this.eventId,
    required this.collected,
    required this.spent,
    required this.balance,
    required this.data,
    this.isAdmin = false,
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

              // Expected amount row
              if (target > 0) ...[
                _BudgetRow(
                  label: 'Expected',
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

        // ── Stat chips ────────────────────────────────────────────
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('events').doc(eventId)
              .collection('contributions').snapshots(),
          builder: (context, snap) {
            double cash = 0, online = 0;
            for (final doc in snap.data?.docs ?? []) {
              final d = doc.data() as Map<String, dynamic>;
              if (d['status'] == 'deleted') continue;
              if (d['selfReported'] == true && d['amountReceived'] != true) continue;
              if (d['amountReceived'] != true) continue;
              final amt = (d['amount'] as num? ?? 0).toDouble();
              final mode = (d['paymentMode'] as String? ?? '').toLowerCase();
              if (mode == 'cash') cash += amt; else online += amt;
            }
            final hasBoth = cash > 0 && online > 0;
            return Column(
              children: [
                if (hasBoth) ...[
                  Row(children: [
                    _StatChip(label: 'Cash', value: '₹${_fmt(cash)}',
                        icon: Icons.arrow_downward_rounded, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    _StatChip(label: 'Online', value: '₹${_fmt(online)}',
                        icon: Icons.arrow_downward_rounded, color: Colors.blue),
                    const SizedBox(width: 8),
                    _StatChip(label: 'Total', value: '₹${_fmt(collected)}',
                        icon: Icons.arrow_downward_rounded, color: Colors.green),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _StatChip(label: 'Spent', value: '₹${_fmt(spent)}',
                        icon: Icons.arrow_upward_rounded, color: Colors.red),
                    const SizedBox(width: 8),
                    _StatChip(label: 'Expected',
                        value: target > 0 ? '₹${_fmt(target)}' : '—',
                        icon: Icons.flag_outlined, color: Colors.blue.shade800),
                    const SizedBox(width: 8),
                    _StatChip(label: 'Balance',
                        value: '₹${_fmt(balance.abs())}',
                        icon: balance >= 0
                            ? Icons.account_balance_wallet
                            : Icons.warning_rounded,
                        color: balance >= 0 ? Colors.teal : Colors.red),
                  ]),
                ] else
                  Row(children: [
                    _StatChip(label: 'Collected', value: '₹${_fmt(collected)}',
                        icon: Icons.arrow_downward_rounded, color: Colors.green),
                    const SizedBox(width: 8),
                    _StatChip(label: 'Spent', value: '₹${_fmt(spent)}',
                        icon: Icons.arrow_upward_rounded, color: Colors.red),
                    const SizedBox(width: 8),
                    _StatChip(label: 'Expected',
                        value: target > 0 ? '₹${_fmt(target)}' : '—',
                        icon: Icons.flag_outlined, color: Colors.blue),
                  ]),
              ],
            );
          },
        ),

        const SizedBox(height: 16),

        // ── Block stats (grouped by wing) — live stream ───────────
        ...[
          const SizedBox(height: 16),
          _BlockStatsWidget(eventId: eventId),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  static String _fmtAmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

}

// ── Block Stats Widget — live StreamBuilder ───────────────────────────────────

class _BlockStatsWidget extends StatefulWidget {
  final String eventId;
  const _BlockStatsWidget({required this.eventId});
  @override
  State<_BlockStatsWidget> createState() => _BlockStatsWidgetState();
}

class _BlockStatsWidgetState extends State<_BlockStatsWidget> {
  Map<String, dynamic> _wingBlocks = {};
  List<String> _wings = [];
  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('community_settings')
          .doc('address')
          .get();
      if (!mounted) return;
      final data = doc.data() as Map<String, dynamic>? ?? {};
      setState(() {
        _wingBlocks = Map<String, dynamic>.from(data['wingBlocks'] as Map? ?? {});
        _wings = List<String>.from(data['wings'] as List? ?? _wingBlocks.keys.toList()..sort());
        _settingsLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _settingsLoaded = true);
    }
  }

  static String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    if (!_settingsLoaded) return const SizedBox();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('contributions')
          .snapshots(),
      builder: (context, contribSnap) {
        if (!contribSnap.hasData) return const SizedBox();

        final contribDocs = contribSnap.data!.docs;
        final wingBlocks = _wingBlocks;

        // Build a set of paid flatNumbers and a map of flatNumber → amount.
        // We match against community flat lists by flatNumber (same as Contributions
        // tab) to avoid wing/block naming mismatches between docs and structure.
        final paidFlats = <String>{};
        final flatAmount = <String, double>{};
        for (final doc in contribDocs) {
          final d = doc.data() as Map<String, dynamic>;
          if (d['amountReceived'] == true &&
              d['status'] != 'rejected' &&
              d['status'] != 'deleted') {
            final f = (d['flatNumber'] ?? '').toString().trim();
            final amt = (d['amount'] as num?)?.toDouble() ?? 0;
            if (f.isNotEmpty) {
              paidFlats.add(f);
              flatAmount[f] = (flatAmount[f] ?? 0) + amt;
            }
          }
        }

        // For each wing/block in community structure, count paid flats and
        // sum amounts using the flat list as the source of truth.
        final wings = _wings.isNotEmpty ? _wings : (wingBlocks.keys.toList()..sort());
        final byWing = <String, ({double collected, List<({String block, int total, int paid})> blocks})>{};
        for (final wing in wings) {
          final blocks = Map<String, dynamic>.from(wingBlocks[wing] as Map? ?? {});
          if (blocks.isEmpty) continue;
          final sortedBlocks = blocks.keys.toList()..sort();
          final blockList = <({String block, int total, int paid})>[];
          double wingAmt = 0;
          for (final block in sortedBlocks) {
            final flats = List<String>.from((blocks[block] as List?) ?? []);
            if (flats.isEmpty) continue;
            // Match paid flats: exact first, then suffix (for short flat numbers)
            int paid = 0;
            for (final f in flats) {
              if (paidFlats.contains(f)) {
                paid++;
                wingAmt += flatAmount[f] ?? 0;
              } else {
                final match = paidFlats.firstWhere(
                  (p) => f.endsWith(p) || p.endsWith(f),
                  orElse: () => '',
                );
                if (match.isNotEmpty) {
                  paid++;
                  wingAmt += flatAmount[match] ?? 0;
                }
              }
            }
            blockList.add((block: block, total: flats.length, paid: paid));
          }
          if (blockList.isNotEmpty) {
            byWing[wing] = (
              collected: wingAmt,
              blocks: blockList,
            );
          }
        }

        if (byWing.isEmpty) return const SizedBox();

        final sortedWings = byWing.keys.toList()..sort();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Collection Status by Block',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.3)),
            const SizedBox(height: 8),
            ...sortedWings.map((wing) {
              final entry = byWing[wing]!;
              final blocks = entry.blocks;
              final wingAmt = entry.collected;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(wing,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700)),
                      if (wingAmt > 0) ...[
                        const SizedBox(width: 6),
                        Text('₹${_fmt(wingAmt)}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade600)),
                      ],
                    ]),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: blocks.map((s) {
                        final allPaid = s.paid == s.total;
                        final nonePaid = s.paid == 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: allPaid
                                ? Colors.green.shade50
                                : nonePaid
                                    ? Colors.grey.shade100
                                    : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                                color: allPaid
                                    ? Colors.green.shade300
                                    : nonePaid
                                        ? Colors.grey.shade300
                                        : Colors.orange.shade300),
                          ),
                          child: Text(
                            '${s.block}  ${s.paid}/${s.total}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: allPaid
                                    ? Colors.green.shade700
                                    : nonePaid
                                        ? Colors.grey.shade600
                                        : Colors.orange.shade700),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ── Event Tab ─────────────────────────────────────────────────────────────────

class _EventTab extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> data;
  final bool isAdmin;
  const _EventTab({required this.eventId, required this.data, required this.isAdmin});
  @override
  State<_EventTab> createState() => _EventTabState();
}

class _EventTabState extends State<_EventTab> {
  static const _sessions = ['Morning', 'Afternoon', 'Evening', 'Night'];
  static const _sessionIcons = {
    'Morning': Icons.wb_sunny_outlined,
    'Afternoon': Icons.wb_cloudy_outlined,
    'Evening': Icons.nights_stay_outlined,
    'Night': Icons.bedtime_outlined,
  };
  static const _sessionColors = {
    'Morning': Color(0xFFF59E0B),
    'Afternoon': Color(0xFF3B82F6),
    'Evening': Color(0xFF8B5CF6),
    'Night': Color(0xFF1E293B),
  };

  Future<void> _showAddScheduleDialog({Map<String, dynamic>? existing, String? docId}) async {
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    String session = existing?['session'] ?? 'Morning';
    DateTime date = existing != null && existing['date'] is Timestamp
        ? (existing['date'] as Timestamp).toDate()
        : DateTime.now();

    final startStr = widget.data['startDate'] as String? ?? '';
    final endStr = widget.data['endDate'] as String? ?? '';
    DateTime? firstDate, lastDate;
    try {
      if (startStr.isNotEmpty) {
        final p = startStr.split('/');
        firstDate = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
      }
      if (endStr.isNotEmpty) {
        final p = endStr.split('/');
        lastDate = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
      }
    } catch (_) {}

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(existing == null ? 'Add Schedule Item' : 'Edit Schedule Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date picker
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, color: Colors.deepPurple),
                  title: Text(
                    '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Tap to change date'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: firstDate ?? DateTime(2020),
                      lastDate: lastDate ?? DateTime(2030),
                    );
                    if (picked != null) setSt(() => date = picked);
                  },
                ),
                const Divider(),
                const SizedBox(height: 8),
                // Session chips
                const Text('Session', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: _sessions.map((s) => ChoiceChip(
                    label: Text(s),
                    selected: session == s,
                    selectedColor: _sessionColors[s]?.withOpacity(0.15),
                    onSelected: (_) => setSt(() => session = s),
                  )).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Activity Title *',
                    hintText: 'e.g. Ganesh Pooja, Cultural Program',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Details (optional)',
                    hintText: 'Venue, contact, dress code…',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null && docId != null)
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await FirebaseFirestore.instance
                      .collection('events').doc(widget.eventId)
                      .collection('schedule').doc(docId).delete();
                },
                child: Text('Delete', style: TextStyle(color: Colors.red.shade600)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(ctx);
                final ref = FirebaseFirestore.instance
                    .collection('events').doc(widget.eventId)
                    .collection('schedule');
                final payload = {
                  'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
                  'session': session,
                  'title': title,
                  'description': descCtrl.text.trim(),
                  'createdAt': Timestamp.now(),
                };
                if (docId != null) {
                  await ref.doc(docId).update(payload);
                } else {
                  await ref.add(payload);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
              child: Text(existing == null ? 'Add' : 'Save',
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final startStr = data['startDate'] as String? ?? '';
    final endStr = data['endDate'] as String? ?? '';
    final description = data['description'] as String? ?? '';
    final status = data['status'] ?? 'active';
    final eventType = data['eventType'] as String? ?? '';
    final eventTypeName = data['eventTypeName'] as String? ?? eventType;
    final eventTypeEmoji = data['eventTypeEmoji'] as String? ?? '🎉';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              heroTag: 'schedule_add',
              onPressed: _showAddScheduleDialog,
              backgroundColor: Colors.deepPurple,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add to Schedule', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events').doc(widget.eventId)
            .collection('schedule')
            .orderBy('date')
            .snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];

          // Group schedule items by date string
          final grouped = <String, List<Map<String, dynamic>>>{};
          final dateOrder = <String>[];
          for (final doc in docs) {
            final d = doc.data() as Map<String, dynamic>;
            final ts = d['date'];
            final dt = ts is Timestamp ? ts.toDate() : DateTime.now();
            final key = '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
            if (!grouped.containsKey(key)) {
              grouped[key] = [];
              dateOrder.add(key);
            }
            grouped[key]!.add({...d, '_id': doc.id, '_dt': dt});
          }

          // Session order for sorting within a day
          final sessionOrder = {for (var i=0; i<_sessions.length; i++) _sessions[i]: i};

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [

              // ── Event details card ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0,3))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('$eventTypeEmoji ${eventTypeName.isNotEmpty ? eventTypeName : 'Event'}',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                  color: Colors.deepPurple.shade700)),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: status == 'active' ? Colors.green.shade50 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: status == 'active' ? Colors.green.shade300 : Colors.grey.shade300),
                          ),
                          child: Text(
                            status == 'active' ? '🟢 Active' : '🔴 Closed',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                color: status == 'active' ? Colors.green.shade700 : Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(description, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.5)),
                    ],
                    const Divider(height: 20),
                    if (startStr.isNotEmpty)
                      _EventDetailRow(icon: Icons.calendar_today_outlined, label: 'Start', value: startStr),
                    if (endStr.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _EventDetailRow(icon: Icons.event_outlined, label: 'End', value: endStr),
                    ],
                  ],
                ),
              ),

              // ── Day-by-day schedule ────────────────────────────
              const SizedBox(height: 20),
              Row(children: [
                const Icon(Icons.schedule_outlined, size: 16, color: Colors.deepPurple),
                const SizedBox(width: 6),
                Text('Event Schedule',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800, letterSpacing: 0.3)),
                if (widget.isAdmin) ...[
                  const Spacer(),
                  Text('Tap item to edit', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                ],
              ]),
              const SizedBox(height: 10),

              if (docs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.event_note_outlined, size: 40, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text(
                        widget.isAdmin
                            ? 'No schedule yet.\nTap "+ Add to Schedule" to add activities.'
                            : 'Schedule will be posted here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      ),
                    ],
                  ),
                )
              else
                ...dateOrder.map((dateKey) {
                  final items = grouped[dateKey]!;
                  // Sort items by session order
                  items.sort((a, b) {
                    final ai = sessionOrder[a['session']] ?? 99;
                    final bi = sessionOrder[b['session']] ?? 99;
                    return ai.compareTo(bi);
                  });
                  final dt = items.first['_dt'] as DateTime;
                  final dayName = _dayName(dt.weekday);
                  final monthName = _monthName(dt.month);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date header
                        Row(children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: Colors.deepPurple,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('${dt.day}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                Text(monthName.substring(0,3).toUpperCase(),
                                    style: const TextStyle(color: Colors.white70, fontSize: 9, letterSpacing: 0.5)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(dayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text('$dayName, $monthName ${dt.day}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            ],
                          ),
                        ]),
                        const SizedBox(height: 10),

                        // Schedule items for this day
                        ...items.map((item) {
                          final session = item['session'] as String? ?? 'Morning';
                          final title = item['title'] as String? ?? '';
                          final desc = item['description'] as String? ?? '';
                          final color = _sessionColors[session] ?? Colors.deepPurple;
                          final icon = _sessionIcons[session] ?? Icons.schedule;
                          final docId = item['_id'] as String;

                          return GestureDetector(
                            onTap: widget.isAdmin
                                ? () => _showAddScheduleDialog(existing: item, docId: docId)
                                : null,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Timeline line
                                  Column(children: [
                                    Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(icon, size: 18, color: color),
                                    ),
                                  ]),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: color.withOpacity(0.2)),
                                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.03), blurRadius: 6, offset: const Offset(0,2))],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: color.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(session,
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                                      color: color)),
                                            ),
                                            if (widget.isAdmin) ...[
                                              const Spacer(),
                                              Icon(Icons.edit_outlined, size: 14, color: Colors.grey.shade300),
                                            ],
                                          ]),
                                          const SizedBox(height: 5),
                                          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                          if (desc.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  static String _dayName(int wd) => const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][wd - 1];
  static String _monthName(int m) => const ['January','February','March','April','May','June',
      'July','August','September','October','November','December'][m - 1];
}

class _EventDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _EventDetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 15, color: Colors.deepPurple.shade300),
      const SizedBox(width: 8),
      Text('$label: ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      Text(value, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
    ]);
  }
}

// ── Volunteers Tab ────────────────────────────────────────────────────────────

class _VolunteersTab extends StatefulWidget {
  final String eventId;
  final bool isAdmin;
  const _VolunteersTab({required this.eventId, required this.isAdmin});
  @override
  State<_VolunteersTab> createState() => _VolunteersTabState();
}

class _VolunteersTabState extends State<_VolunteersTab> {
  static const _defaultRoles = [
    'Coordinator', 'Decoration', 'Food & Prasad', 'Security',
    'Music & Sound', 'Collection', 'Photography', 'Transport', 'Other',
  ];
  static const _roleIcons = {
    'Coordinator': Icons.manage_accounts_outlined,
    'Decoration': Icons.celebration_outlined,
    'Food & Prasad': Icons.restaurant_outlined,
    'Security': Icons.security_outlined,
    'Music & Sound': Icons.music_note_outlined,
    'Collection': Icons.payments_outlined,
    'Photography': Icons.camera_alt_outlined,
    'Transport': Icons.directions_car_outlined,
    'Other': Icons.volunteer_activism_outlined,
  };
  static const _roleColors = {
    'Coordinator': Color(0xFF7C3AED),
    'Decoration': Color(0xFFEC4899),
    'Food & Prasad': Color(0xFFF59E0B),
    'Security': Color(0xFF1E40AF),
    'Music & Sound': Color(0xFF0891B2),
    'Collection': Color(0xFF16A34A),
    'Photography': Color(0xFFEA580C),
    'Transport': Color(0xFF6B7280),
    'Other': Color(0xFF374151),
  };

  Future<void> _showAddDialog({Map<String, dynamic>? existing, String? docId}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final flatCtrl = TextEditingController(text: existing?['flat'] ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone'] ?? '');
    String role = existing?['role'] ?? _defaultRoles.first;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(existing == null ? 'Add Volunteer' : 'Edit Volunteer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Name *',
                    hintText: 'e.g. Ramesh Kumar',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Role', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: _defaultRoles.map((r) => ChoiceChip(
                    label: Text(r, style: const TextStyle(fontSize: 12)),
                    selected: role == r,
                    selectedColor: (_roleColors[r] ?? Colors.deepPurple).withOpacity(0.15),
                    onSelected: (_) => setSt(() => role = r),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: flatCtrl,
                  decoration: InputDecoration(
                    labelText: 'Flat / Unit (optional)',
                    hintText: 'e.g. DA101',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone (optional)',
                    hintText: 'e.g. 9876543210',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null && docId != null)
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await FirebaseFirestore.instance
                      .collection('events').doc(widget.eventId)
                      .collection('volunteers').doc(docId).delete();
                },
                child: Text('Remove', style: TextStyle(color: Colors.red.shade600)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                final ref = FirebaseFirestore.instance
                    .collection('events').doc(widget.eventId)
                    .collection('volunteers');
                final payload = {
                  'name': name,
                  'role': role,
                  'flat': flatCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'addedAt': Timestamp.now(),
                };
                if (docId != null) {
                  await ref.doc(docId).update(payload);
                } else {
                  await ref.add(payload);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
              child: Text(existing == null ? 'Add' : 'Save',
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              heroTag: 'volunteer_add',
              onPressed: _showAddDialog,
              backgroundColor: Colors.deepPurple,
              icon: const Icon(Icons.person_add_outlined, color: Colors.white),
              label: const Text('Add Volunteer', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events').doc(widget.eventId)
            .collection('volunteers')
            .orderBy('addedAt')
            .snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.groups_outlined, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    widget.isAdmin
                        ? 'No volunteers yet.\nTap "+ Add Volunteer" to add team members.'
                        : 'Volunteer list will be posted here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          // Group by role
          final byRole = <String, List<Map<String, dynamic>>>{};
          for (final doc in docs) {
            final d = doc.data() as Map<String, dynamic>;
            final role = d['role'] as String? ?? 'Other';
            byRole.putIfAbsent(role, () => []).add({...d, '_id': doc.id});
          }

          // Sort roles by default order, unknowns at end
          final sortedRoles = byRole.keys.toList()
            ..sort((a, b) {
              final ai = _defaultRoles.indexOf(a);
              final bi = _defaultRoles.indexOf(b);
              return (ai < 0 ? 99 : ai).compareTo(bi < 0 ? 99 : bi);
            });

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // Total count chip
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${docs.length} Volunteers',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: Colors.deepPurple.shade700)),
                  ),
                ]),
              ),

              ...sortedRoles.map((role) {
                final members = byRole[role]!;
                final color = _roleColors[role] ?? const Color(0xFF374151);
                final icon = _roleIcons[role] ?? Icons.volunteer_activism_outlined;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Role header
                      Row(children: [
                        Icon(icon, size: 16, color: color),
                        const SizedBox(width: 6),
                        Text(role,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${members.length}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                        ),
                      ]),
                      const SizedBox(height: 8),

                      // Member cards
                      ...members.map((m) {
                        final name = m['name'] as String? ?? '';
                        final flat = m['flat'] as String? ?? '';
                        final phone = m['phone'] as String? ?? '';
                        final docId = m['_id'] as String;

                        return GestureDetector(
                          onTap: widget.isAdmin
                              ? () => _showAddDialog(existing: m, docId: docId)
                              : null,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: color.withOpacity(0.15)),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.03), blurRadius:4, offset: const Offset(0,2))],
                            ),
                            child: Row(children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: color.withOpacity(0.12),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    if (flat.isNotEmpty || phone.isNotEmpty)
                                      Text(
                                        [if (flat.isNotEmpty) flat, if (phone.isNotEmpty) phone].join('  ·  '),
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                      ),
                                  ],
                                ),
                              ),
                              if (widget.isAdmin)
                                Icon(Icons.edit_outlined, size: 16, color: Colors.grey.shade300),
                            ]),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
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

class _ChipLegend extends StatelessWidget {
  final Color color, border, textColor;
  final String text;
  const _ChipLegend({required this.color, required this.border,
      required this.text, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}

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
      builder: (sheetCtx) => DraggableScrollableSheet(
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
                Expanded(
                  child: Text('$wing › Block $block › $flat',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                if (widget.isAdmin && widget.status == 'active')
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddContributionScreen(
                          eventId: widget.eventId,
                          prefillFlat: flat,
                          prefillWing: wing,
                          prefillBlock: block,
                        ),
                      ),
                    ),
                    icon: Icon(Icons.add, size: 16, color: Colors.green.shade600),
                    label: Text('Add',
                        style: TextStyle(
                            color: Colors.green.shade600, fontSize: 13)),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4)),
                  ),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('events')
                    .doc(widget.eventId)
                    .collection('contributions')
                    .where('flatNumber', isEqualTo: flat)
                    .snapshots(),
                builder: (context, snap) {
                  final liveDocs = (snap.data?.docs ?? [])
                      .where((d) =>
                          (d.data() as Map<String, dynamic>)['status'] != 'deleted')
                      .toList();

                  if (liveDocs.isEmpty) {
                    return Column(
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
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddContributionScreen(
                                  eventId: widget.eventId,
                                  prefillFlat: flat,
                                  prefillWing: wing,
                                  prefillBlock: block,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  }

                  return ListView(
                    controller: ctrl,
                    padding: const EdgeInsets.all(12),
                    children: liveDocs.map((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      final isRejected = d['status'] == 'rejected';
                      final isPending = d['amountReceived'] == false && !isRejected;
                      final cType = d['contributionType'] ?? kTypeRegular;
                      final amt = (d['amount'] as num?)?.toDouble() ?? 0;
                      final rejReason = (d['rejectionReason'] ?? '').toString().trim();

                      Color cardColor, borderColor, amtColor, iconColor, avatarBg;
                      if (isRejected) {
                        cardColor = Colors.red.shade50;
                        borderColor = Colors.red.shade200;
                        amtColor = Colors.red.shade700;
                        iconColor = Colors.red.shade700;
                        avatarBg = Colors.red.shade100;
                      } else if (isPending) {
                        cardColor = Colors.orange.shade50;
                        borderColor = Colors.orange.shade200;
                        amtColor = Colors.orange.shade700;
                        iconColor = Colors.orange.shade700;
                        avatarBg = Colors.orange.shade100;
                      } else {
                        cardColor = Colors.white;
                        borderColor = Colors.grey.shade200;
                        amtColor = Colors.green.shade700;
                        iconColor = Colors.green.shade700;
                        avatarBg = Colors.green.shade50;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: avatarBg,
                                child: Icon(
                                  isRejected ? Icons.cancel_outlined : Icons.home,
                                  size: 16,
                                  color: iconColor,
                                ),
                              ),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Flat ${d['flatNumber'] ?? ''}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  Row(children: [
                                    if (cType != kTypeRegular) ...[
                                      _typeBadge(cType),
                                      const SizedBox(width: 4),
                                    ],
                                    if (isRejected)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text('Rejected',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red.shade800)),
                                      )
                                    else if (isPending)
                                      _pendingBadge(),
                                  ]),
                                ],
                              ),
                              subtitle: Text(
                                [
                                  if ((d['residentName'] ?? '').isNotEmpty)
                                    d['residentName'],
                                  d['paymentMode'] ?? 'Cash',
                                  if ((d['paidDate'] ?? '').isNotEmpty)
                                    d['paidDate'],
                                  if ((d['note'] ?? '').toString().trim().isNotEmpty)
                                    'Note: ${d['note']}',
                                ].join(' • '),
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade600),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('₹${amt.toStringAsFixed(0)}',
                                      style: TextStyle(
                                          color: amtColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                  if (widget.isAdmin) ...[
                                    const SizedBox(width: 2),
                                    if (!isRejected)
                                      IconButton(
                                        icon: Icon(Icons.edit_outlined,
                                            color: Colors.green.shade400,
                                            size: 17),
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => AddContributionScreen(
                                              eventId: widget.eventId,
                                              existingDocId: doc.id,
                                              existingData: d,
                                            ),
                                          ),
                                        ),
                                        tooltip: 'Edit',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline,
                                          color: Colors.red.shade300,
                                          size: 17),
                                      onPressed: () =>
                                          _deleteContribution(context, doc, d),
                                      tooltip: 'Delete',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isRejected && rejReason.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                child: Text('Reason: $rejReason',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.red.shade600)),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
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
            return data['amountReceived'] != false &&
                    data['status'] != 'rejected' &&
                    data['status'] != 'deleted'
                ? s + (data['amount'] as num? ?? 0).toDouble()
                : s;
          });
          final hasPaid = myDocs.any((d) {
            final data = d.data() as Map;
            return data['amountReceived'] != false &&
                data['status'] != 'rejected' &&
                data['status'] != 'deleted';
          });
          final hasPending = myDocs.any((d) {
            final data = d.data() as Map;
            return data['amountReceived'] == false &&
                data['status'] != 'rejected' &&
                data['status'] != 'deleted';
          });
          final hasRejected =
              myDocs.any((d) => (d.data() as Map)['status'] == 'rejected');

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
                          : hasRejected
                              ? Colors.red.shade50
                              : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: hasPaid
                          ? Colors.green.shade200
                          : hasPending
                              ? Colors.orange.shade200
                              : hasRejected
                                  ? Colors.red.shade200
                                  : Colors.grey.shade300),
                ),
                child: Row(children: [
                  CircleAvatar(
                    backgroundColor: hasPaid
                        ? Colors.green.shade100
                        : hasPending
                            ? Colors.orange.shade100
                            : hasRejected
                                ? Colors.red.shade100
                                : Colors.grey.shade200,
                    child: Icon(
                      hasPaid
                          ? Icons.check_circle
                          : hasPending
                              ? Icons.hourglass_top
                              : hasRejected
                                  ? Icons.cancel_outlined
                                  : Icons.payments_outlined,
                      color: hasPaid
                          ? Colors.green.shade700
                          : hasPending
                              ? Colors.orange.shade700
                              : hasRejected
                                  ? Colors.red.shade600
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
                                  : hasRejected
                                      ? 'Payment rejected — please re-submit'
                                      : 'No contribution recorded yet',
                          style: TextStyle(
                              fontSize: 13,
                              color: hasPaid
                                  ? Colors.green.shade700
                                  : hasPending
                                      ? Colors.orange.shade700
                                      : hasRejected
                                          ? Colors.red.shade600
                                          : Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
              if (myDocs.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...myDocs.where((doc) {
                  final s = (doc.data() as Map<String, dynamic>)['status'];
                  return s != 'deleted';
                }).map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final isRejected = d['status'] == 'rejected';
                  final isPending = d['amountReceived'] == false && !isRejected;
                  final amt = (d['amount'] as num?)?.toDouble() ?? 0;
                  final rejectionReason =
                      d['rejectionReason'] ?? 'Payment not verified';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isRejected
                          ? Colors.red.shade50
                          : isPending
                              ? Colors.orange.shade50
                              : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isRejected
                              ? Colors.red.shade200
                              : isPending
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isRejected
                                  ? Colors.red.shade100
                                  : isPending
                                      ? Colors.orange.shade100
                                      : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isRejected
                                  ? 'Rejected'
                                  : isPending
                                      ? 'Pending'
                                      : 'Confirmed',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isRejected
                                      ? Colors.red.shade800
                                      : isPending
                                          ? Colors.orange.shade800
                                          : Colors.green.shade800),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('₹${amt.toStringAsFixed(0)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isRejected
                                      ? Colors.red.shade700
                                      : isPending
                                          ? Colors.orange.shade700
                                          : Colors.green.shade700)),
                        ]),
                        if (isRejected) ...[
                          const SizedBox(height: 6),
                          Text('Reason: $rejectionReason',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.red.shade600)),
                          const SizedBox(height: 2),
                          Text('Please re-submit with correct details.',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.red.shade400)),
                        ],
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
              data['status'] != 'rejected' &&
              data['status'] != 'deleted';
        }).toList();

        // All confirmed contributions for summary totals
        double grandTotal = 0;
        int totalCount = 0;
        // flat → list of contribution docs
        final Map<String, List<QueryDocumentSnapshot>> flatDocs = {};
        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          // Skip deleted and unconfirmed self-reports
          if (d['status'] == 'deleted') continue;
          if (d['selfReported'] == true && d['amountReceived'] != true) continue;
          final flat = (d['flatNumber'] ?? '').toString().trim();
          if (flat.isNotEmpty) {
            flatDocs.putIfAbsent(flat, () => []);
            flatDocs[flat]!.add(doc);
          }
          if (d['amountReceived'] == true) {
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
            final flatGridRows = Map<String, int>.from(
              (settings['flatGridRows'] is Map
                      ? settings['flatGridRows'] as Map<String, dynamic>
                      : <String, dynamic>{})
                  .map((k, v) => MapEntry(k, (v as num).toInt())),
            );

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // ── Pending Verification section ──────────────────
                if (widget.isAdmin && pendingVerification.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.pending_actions,
                              color: Colors.orange.shade700, size: 15),
                          const SizedBox(width: 6),
                          Text(
                            '${pendingVerification.length} Pending Verification',
                            style: TextStyle(
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        ...pendingVerification.map((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          final amt = (d['amount'] as num?)?.toDouble() ?? 0;
                          final flat = d['flatNumber'] ?? '';
                          final name = d['residentName'] ?? '';
                          final mode = d['paymentMode'] ?? '';
                          final ref = (d['referenceId'] ?? '').toString().trim();
                          final pWing = (d['wing'] ?? '').toString().trim();
                          final pBlock = (d['block'] ?? '').toString().trim();
                          final isAdditional = d['isAdditional'] == true;
                          final locationParts = [
                            if (pWing.isNotEmpty) pWing,
                            if (pBlock.isNotEmpty) 'Block $pBlock',
                            'Flat $flat',
                          ];
                          final locationStr = locationParts.join(' › ');
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isAdditional ? Colors.amber.shade50 : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: isAdditional
                                      ? Colors.amber.shade400
                                      : Colors.orange.shade100),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (isAdditional)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Row(children: [
                                            Icon(Icons.warning_amber_rounded,
                                                size: 13, color: Colors.amber.shade800),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text('Already paid — Additional payment',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.amber.shade800)),
                                            ),
                                          ]),
                                        ),
                                      Text(
                                        '$locationStr${name.isNotEmpty ? '  ·  $name' : ''}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13),
                                      ),
                                      Text(
                                        '₹${amt.toStringAsFixed(0)}  ·  $mode${ref.isNotEmpty ? '  ·  $ref' : ''}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => _rejectSelfReport(context, doc),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red.shade700,
                                    side: BorderSide(color: Colors.red.shade300),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: const Text('Reject', style: TextStyle(fontSize: 12)),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton(
                                  onPressed: () => _confirmSelfReport(context, doc, amt),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: const Text('Confirm', style: TextStyle(fontSize: 12)),
                                ),
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

                // ── Flat chip colour legend ────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _ChipLegend(color: Colors.green.shade50, border: Colors.green.shade400,
                          text: 'Cash', textColor: Colors.green.shade700),
                      _ChipLegend(color: Colors.blue.shade50, border: Colors.blue.shade300,
                          text: 'Online', textColor: Colors.blue.shade700),
                      _ChipLegend(color: Colors.purple.shade50, border: Colors.purple.shade300,
                          text: 'Cash + Online', textColor: Colors.purple.shade800),
                      _ChipLegend(color: Colors.orange.shade50, border: Colors.orange.shade300,
                          text: 'Pending', textColor: Colors.orange.shade700),
                      _ChipLegend(color: Colors.grey.shade100, border: Colors.grey.shade300,
                          text: 'Not paid', textColor: Colors.grey.shade500),
                    ],
                  ),
                ),

                // ── Wing → Block → Flat chip hierarchy ────────────
                for (final wing in wings) ...[
                  _buildWingTile(
                      context, wing, wingBlocks, flatDocs, flatsPerFloor, flatGridRows),
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

                  // Try to suffix-match each unassigned flat to a known flat
                  String? resolveFlat(String orphan) {
                    for (final known in knownFlats) {
                      if (known.endsWith(orphan) || orphan.endsWith(known)) {
                        return known;
                      }
                    }
                    return null;
                  }

                  Future<void> fixOrphan(
                      String orphanFlat,
                      String resolvedFlat,
                      List<QueryDocumentSnapshot> docs) async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Fix Flat Number'),
                        content: Text(
                          'Re-assign ${docs.length} contribution${docs.length == 1 ? '' : 's'} '
                          'from "$orphanFlat" → "$resolvedFlat"?\n\n'
                          'This will update the flat number in Firestore so the '
                          'amounts appear in the correct wing/block.',
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Fix')),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    final batch = FirebaseFirestore.instance.batch();
                    for (final doc in docs) {
                      batch.update(doc.reference, {'flatNumber': resolvedFlat});
                    }
                    await batch.commit();
                  }

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
                              final resolved = resolveFlat(flat);
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
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (resolved != null)
                                            TextButton.icon(
                                              icon: const Icon(Icons.auto_fix_high, size: 14),
                                              label: Text('Fix → $resolved'),
                                              style: TextButton.styleFrom(
                                                  foregroundColor: Colors.green.shade700,
                                                  textStyle: const TextStyle(fontSize: 12)),
                                              onPressed: () => fixOrphan(flat, resolved, docs),
                                            ),
                                          TextButton(
                                            onPressed: () => _showFlatContribution(
                                                context, '', '', flat, docs),
                                            child: const Text('View'),
                                          ),
                                        ],
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
    Map<String, int> flatGridRows,
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
    double wingTotal = 0, wingCash = 0, wingOnline = 0;
    for (final e in flatDocs.entries) {
      bool inWing = false;
      for (final block in blocks) {
        final flats = List<String>.from(wingData[block] is List ? wingData[block] : []);
        if (flats.contains(e.key)) { inWing = true; break; }
      }
      if (!inWing) continue;
      for (final doc in e.value) {
        final d = doc.data() as Map<String, dynamic>;
        if (d['amountReceived'] != true) continue;
        final amt = (d['amount'] as num? ?? 0).toDouble();
        final mode = (d['paymentMode'] as String? ?? '').toLowerCase();
        wingTotal += amt;
        if (mode == 'cash') wingCash += amt; else wingOnline += amt;
      }
    }

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
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${_fmt(wingTotal)}',
                    style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                if (wingCash > 0 && wingOnline > 0)
                  Text('C:${_fmt(wingCash)} · O:${_fmt(wingOnline)}',
                      style: TextStyle(fontSize: 9, color: Colors.grey.shade500))
                else if (wingCash > 0)
                  Text('Cash', style: TextStyle(fontSize: 9, color: Colors.amber.shade800))
                else if (wingOnline > 0)
                  Text('Online', style: TextStyle(fontSize: 9, color: Colors.blue.shade600)),
              ],
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
                    context, wing, block, wingData, flatDocs, flatsPerFloor, flatGridRows))
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
    Map<String, int> flatGridRows,
  ) {
    final flats = List<String>.from(
        wingData[block] is List ? wingData[block] : [])
      ..sort();
    final fpf = flatsPerFloor['${wing}_$block'];
    final gridRows = (flatGridRows['${wing}_$block'] ?? 1).clamp(1, 3);

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
    double blockTotal = 0, blockCash = 0, blockOnline = 0;
    for (final doc in flats.expand((f) => flatDocs[f] ?? [])) {
      final d = doc.data() as Map<String, dynamic>;
      if (d['amountReceived'] != true) continue;
      final amt = (d['amount'] as num? ?? 0).toDouble();
      final mode = (d['paymentMode'] as String? ?? '').toLowerCase();
      blockTotal += amt;
      if (mode == 'cash') blockCash += amt; else blockOnline += amt;
    }

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
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${_fmt(blockTotal)}',
                      style: TextStyle(
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  if (blockCash > 0 && blockOnline > 0)
                    Text('C:${_fmt(blockCash)} · O:${_fmt(blockOnline)}',
                        style: TextStyle(fontSize: 9, color: Colors.grey.shade500))
                  else if (blockCash > 0)
                    Text('Cash', style: TextStyle(fontSize: 9, color: Colors.amber.shade800))
                  else if (blockOnline > 0)
                    Text('Online', style: TextStyle(fontSize: 9, color: Colors.blue.shade600)),
                ],
              ),
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
                      context, wing, block, flats, flatDocs, fpf, gridRows),
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
    int gridRows,
  ) {
    Widget chip(String flat) {
      final docs = flatDocs[flat] ?? [];
      final paidDocs = docs.where((d) =>
          (d.data() as Map<String, dynamic>)['amountReceived'] == true).toList();
      final isPending = docs.isNotEmpty && paidDocs.isEmpty;

      // Determine payment mode of paid contributions
      bool hasCash = false, hasOnline = false;
      final List<double> paidAmounts = [];
      for (final d in paidDocs) {
        final data = d.data() as Map<String, dynamic>;
        final mode = (data['paymentMode'] as String? ?? '').toLowerCase();
        final amt = (data['amount'] as num? ?? 0).toDouble();
        paidAmounts.add(amt);
        if (mode == 'cash') hasCash = true; else hasOnline = true;
      }
      final hasBoth = hasCash && hasOnline;
      final amount = paidAmounts.fold(0.0, (s, v) => s + v);

      Color chipColor, textColor, borderColor;
      if (docs.isEmpty) {
        // Not paid
        chipColor = Colors.grey.shade100;
        textColor = Colors.grey.shade500;
        borderColor = Colors.grey.shade300;
      } else if (isPending) {
        // Pending confirmation — orange
        chipColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        borderColor = Colors.orange.shade300;
      } else if (hasBoth) {
        // Cash + Online — purple
        chipColor = Colors.purple.shade50;
        textColor = Colors.purple.shade800;
        borderColor = Colors.purple.shade300;
      } else if (hasCash) {
        // Cash paid — green
        chipColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        borderColor = Colors.green.shade400;
      } else {
        // Online paid — blue
        chipColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        borderColor = Colors.blue.shade300;
      }

      return GestureDetector(
        onTap: () => _showFlatContribution(context, wing, block, flat, docs),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: chipColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(flat,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  docs.isEmpty
                      ? '—'
                      : paidAmounts.isEmpty
                          ? '⏳'
                          : paidAmounts.length == 1
                              ? '₹${paidAmounts[0].toStringAsFixed(0)}'
                              : paidAmounts.map((a) => '₹${a.toStringAsFixed(0)}').join('+'),
                  style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.8)),
                ),
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
          Builder(builder: (_) {
            final floorFlats = flats.skip(floor * fpf).take(fpf).toList();
            final floorTotal = floorFlats.fold<double>(0, (s, f) {
              return s + (flatDocs[f] ?? []).fold<double>(0, (s2, d) {
                final data = d.data() as Map<String, dynamic>;
                return data['amountReceived'] != false
                    ? s2 + (data['amount'] as num? ?? 0).toDouble()
                    : s2;
              });
            });
            final paidOnFloor = floorFlats.where((f) {
              final docs = flatDocs[f] ?? [];
              return docs.any((d) =>
                  (d.data() as Map<String, dynamic>)['amountReceived'] != false);
            }).length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
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
                      const SizedBox(width: 6),
                      Text('$paidOnFloor/${floorFlats.length} paid',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade500)),
                      if (floorTotal > 0) ...[
                        const SizedBox(width: 6),
                        Text('· ₹${_fmt(floorTotal)}',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700)),
                      ],
                    ],
                  ),
                ),
                Builder(builder: (_) {
                  final perRow = (floorFlats.length / gridRows).ceil();
                  return Column(
                    children: List.generate(gridRows, (r) {
                      final rowFlats = floorFlats.skip(r * perRow).take(perRow).toList();
                      if (rowFlats.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: EdgeInsets.only(bottom: r < gridRows - 1 ? 3 : 0),
                        child: Row(
                          children: List.generate(perRow, (i) {
                            if (i >= rowFlats.length) return Expanded(child: const SizedBox());
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(right: i < perRow - 1 ? 3 : 0),
                                child: chip(rowFlats[i]),
                              ),
                            );
                          }),
                        ),
                      );
                    }),
                  );
                }),
              ],
            );
          }),
        ],
      ],
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  Widget _typeBadge(String type) {
    String label;
    Color bg, fg;
    if (type == kTypeCarryForward) {
      label = 'Carry Fwd';
      bg = Colors.blue.shade50;
      fg = Colors.blue.shade700;
    } else if (type == kTypeGaneshLaddu) {
      label = 'Special';
      bg = Colors.purple.shade50;
      fg = Colors.purple.shade700;
    } else {
      label = 'Special';
      bg = Colors.purple.shade50;
      fg = Colors.purple.shade700;
    }
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.bold, color: fg)),
    );
  }

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
    // Soft-delete: keep doc for Activity log history & restore capability
    batch.update(doc.reference, {
      'status': 'deleted',
      'deletedAt': DateTime.now().toIso8601String(),
      'preDeleteStatus': d['status'] ?? '',
      'preDeleteAmountReceived': d['amountReceived'],
    });
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

    // Build location label from wing/block stored on doc
    final docWingLabel = (d['wing'] ?? '').toString().trim();
    final docBlockLabel = (d['block'] ?? '').toString().trim();
    final locationLabel = [
      if (docWingLabel.isNotEmpty) '$docWingLabel Wing',
      if (docBlockLabel.isNotEmpty) 'Block $docBlockLabel',
      'Flat $flat',
    ].join(' › ');

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
            Text('Mark ₹${amt.toStringAsFixed(0)} as received?'),
            const SizedBox(height: 4),
            Text(locationLabel,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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

    // Resolve flat number against community structure.
    // Use wing+block from the doc to avoid matching the wrong block
    // (e.g. "404" in "Diamond B" must not resolve to "Diamond A 404").
    final docWing = (d['wing'] ?? '').toString().trim();
    final docBlock = (d['block'] ?? '').toString().trim();
    String resolvedFlat = flat;
    final settingsDoc = await FirebaseFirestore.instance
        .collection('community_settings')
        .doc('address')
        .get();
    if (settingsDoc.exists) {
      final wingBlocks = (settingsDoc.data()?['wingBlocks'] as Map?)
              ?.cast<String, dynamic>() ??
          {};
      bool _wingMatch(String communityWing) {
        if (docWing.isEmpty) return true;
        final cw = communityWing.toLowerCase();
        final dw = docWing.toLowerCase();
        return cw == dw || cw.contains(dw) || dw.contains(cw);
      }
      bool _blockMatch(String communityBlock) {
        if (docBlock.isEmpty) return true;
        final cb = communityBlock.toLowerCase();
        final db = docBlock.toLowerCase();
        return cb == db || cb.contains(db) || db.contains(cb);
      }
      // Pass 1: try to match within the same wing+block (flexible string match)
      outer1:
      for (final wing in wingBlocks.keys) {
        if (!_wingMatch(wing)) continue;
        final blocks = wingBlocks[wing] as Map<String, dynamic>? ?? {};
        for (final block in blocks.keys) {
          if (!_blockMatch(block)) continue;
          final flats = (blocks[block] as List?)?.cast<String>() ?? [];
          for (final f in flats) {
            if (f == flat) { resolvedFlat = f; break outer1; }
            if (f.endsWith(flat) || flat.endsWith(f)) {
              resolvedFlat = f; break outer1;
            }
          }
        }
      }
      // Pass 2: fallback to global search only if not yet resolved
      if (resolvedFlat == flat) {
        outer2:
        for (final wingData in wingBlocks.values) {
          if (wingData is! Map) continue;
          for (final flats in wingData.values) {
            if (flats is! List) continue;
            for (final f in flats.cast<String>()) {
              if (f == flat) { resolvedFlat = f; break outer2; }
              if (f.endsWith(flat) || flat.endsWith(f)) {
                resolvedFlat = f; break outer2;
              }
            }
          }
        }
      }
    }

    final batch = FirebaseFirestore.instance.batch();
    batch.update(doc.reference, {
      'amountReceived': true,
      'status': 'confirmed',
      'confirmedAt': DateTime.now().toIso8601String(),
      if (resolvedFlat != flat) 'flatNumber': resolvedFlat,
    });
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
              child: const Text('OK')),
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

    // Return the reason string directly from the sheet so we never
    // read from the controller after it may have been torn down.
    final reasonCtrl = TextEditingController();
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.cancel_outlined, color: Colors.red.shade600, size: 20),
              const SizedBox(width: 8),
              const Text('Reject Payment',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 4),
            Text('Flat $flat — ₹${amt.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. Payment not found in bank records',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 6),
            Text('Resident will see this reason and can re-submit.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()),
                  child: const Text('Reject'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    // Defer dispose until the sheet's close animation finishes (~300ms).
    // Disposing synchronously crashes because the TextField still holds the
    // controller during the closing animation frames.
    Future<void>.delayed(const Duration(milliseconds: 500))
        .then((_) => reasonCtrl.dispose());

    if (reason == null || !context.mounted) return;

    // Build WhatsApp details before any async work
    final rejReason = reason.isEmpty ? 'payment could not be verified in bank records' : reason;
    final waMsg = Uri.encodeComponent(
      'Hi $name, your payment report of ₹${amt.toStringAsFixed(0)} could not be confirmed. Reason: $rejReason. Please contact the admin or re-submit with correct details.',
    );
    final waUrl = Uri.parse('https://wa.me/91$phone?text=$waMsg');
    final messenger = ScaffoldMessenger.of(context);

    // Show WhatsApp dialog BEFORE Firestore update — avoids StreamBuilder
    // rebuilding mid-dialog which causes duplicate GlobalKey crashes.
    bool sendWa = false;
    if (phone.isNotEmpty && context.mounted) {
      // ignore: use_build_context_synchronously
      sendWa = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Row(children: [
                Icon(Icons.cancel_outlined, color: Colors.red.shade600),
                const SizedBox(width: 8),
                const Text('Reject Payment'),
              ]),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reject Flat $flat\'s report of ₹${amt.toStringAsFixed(0)}?'),
                  const SizedBox(height: 4),
                  Text('They will see the rejection reason in their app.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 10),
                  Text('Notify $name via WhatsApp after rejecting?',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Reject only')),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white),
                  icon: const Icon(Icons.chat, size: 16),
                  label: const Text('Reject + WhatsApp'),
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
          ) ??
          false;
    }

    // Defer Firestore update by one frame so any lingering dialog-cleanup
    // frames finish before the StreamBuilder inside the flat sheet rebuilds.
    await Future<void>.delayed(Duration.zero);
    if (!context.mounted) return;

    await doc.reference.update({
      'status': 'rejected',
      'rejectionReason': reason.isEmpty ? 'Payment not verified' : reason,
      'rejectedAt': DateTime.now().toIso8601String(),
    });

    messenger.showSnackBar(
        SnackBar(content: Text('Payment report for Flat $flat rejected')));

    if (sendWa) {
      final canLaunch = await canLaunchUrl(waUrl);
      await launchUrl(waUrl,
          mode: canLaunch
              ? LaunchMode.externalApplication
              : LaunchMode.platformDefault);
    }
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
              final receiptUrl = d['receiptUrl'] as String?;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
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
                          if (receiptUrl != null) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showReceiptFullScreen(context, receiptUrl),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(receiptUrl,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                        Icons.receipt,
                                        color: Colors.grey.shade400)),
                              ),
                            ),
                          ],
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

  void _showReceiptFullScreen(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Receipt'),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
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
        final flatGridRows = Map<String, int>.from(
          (settings['flatGridRows'] is Map
                  ? settings['flatGridRows'] as Map<String, dynamic>
                  : <String, dynamic>{})
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
                      context, wing, wingBlocks, flatStatus, flatsPerFloor, flatGridRows),
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
    Map<String, int> flatGridRows,
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
                context, wing, block, wingData, flatStatus, flatsPerFloor, flatGridRows))
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
    Map<String, int> flatGridRows,
  ) {
    final flats = List<String>.from(
        wingData[block] is List ? wingData[block] : [])
      ..sort();
    final fpf = flatsPerFloor['${wing}_$block'];
    final gridRows = (flatGridRows['${wing}_$block'] ?? 1).clamp(1, 3);

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
              child: _buildFlatChips(context, flats, flatStatus, fpf, gridRows),
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
    int gridRows,
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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(flat,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor)),
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
          Builder(builder: (_) {
            final floorFlats = flats.skip(floor * fpf).take(fpf).toList();
            final perRow = (floorFlats.length / gridRows).ceil();
            return Column(
              children: List.generate(gridRows, (r) {
                final rowFlats = floorFlats.skip(r * perRow).take(perRow).toList();
                if (rowFlats.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: EdgeInsets.only(bottom: r < gridRows - 1 ? 3 : 0),
                  child: Row(
                    children: List.generate(perRow, (i) {
                      if (i >= rowFlats.length) return Expanded(child: const SizedBox());
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i < perRow - 1 ? 3 : 0),
                          child: chip(rowFlats[i]),
                        ),
                      );
                    }),
                  ),
                );
              }),
            );
          }),
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

// ── Activity Tab ───────────────────────────────────────────────────────────────

class _ActivityTab extends StatefulWidget {
  final String eventId;
  const _ActivityTab({required this.eventId});

  @override
  State<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<_ActivityTab> {
  final Set<String> _expandedMonths = {};
  final Set<String> _expandedDates = {};
  final TextEditingController _searchCtrl = TextEditingController();
  String _flatFilter = '';
  bool _showSearch = false;
  bool _autoExpanded = false; // expand current month on first data load

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _flatFilter = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _restore(DocumentReference ref, Map<String, dynamic> e) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Contribution'),
        content: Text(
            'Restore ₹${(e['amt'] as double).toStringAsFixed(0)} for ${e['flat']}?\n\n'
            'The contribution will be marked as pending for admin review.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final update = <String, dynamic>{
      'status': 'pending',
      'amountReceived': false,
      'deletedAt': FieldValue.delete(),
      'preDeleteStatus': FieldValue.delete(),
      'preDeleteAmountReceived': FieldValue.delete(),
    };
    // If it was previously confirmed, restore totalCollected
    final wasConfirmed = e['preDeleteAmountReceived'] == true;
    if (wasConfirmed) {
      final eventId = ref.parent.parent!.id;
      final eventRef = FirebaseFirestore.instance.collection('events').doc(eventId);
      final batch = FirebaseFirestore.instance.batch();
      batch.update(ref, update);
      batch.update(eventRef, {'totalCollected': FieldValue.increment(e['amt'] as double)});
      await batch.commit();
    } else {
      await ref.update(update);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contribution restored to pending')));
    }
  }

  Future<void> _restoreRejected(DocumentReference ref, Map<String, dynamic> e) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revert Rejection'),
        content: Text('Move ₹${(e['amt'] as double).toStringAsFixed(0)} for ${e['flat']} back to pending so it can be reviewed again?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade600, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revert'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.update({
      'status': 'pending',
      'amountReceived': false,
      'rejectionReason': FieldValue.delete(),
      'rejectedAt': FieldValue.delete(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rejection reverted — contribution is pending again')));
    }
  }

  static const _months = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const _days = [
    '', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  // Returns just HH:mm for the inline time on each row
  String _fmtTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // "25 June 2026"
  String _dateLabel(DateTime dt) =>
      '${dt.day} ${_months[dt.month]} ${dt.year}';

  // "June 2026"
  String _monthLabel(DateTime dt) => '${_months[dt.month]} ${dt.year}';

  DateTime? _parse(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try { return DateTime.parse(iso).toLocal(); } catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('contributions')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Build a flat list of log entries from contribution docs
        final entries = <Map<String, dynamic>>[];
        for (final doc in snap.data!.docs) {
          final d = doc.data() as Map<String, dynamic>;
          final flat = d['flatNumber'] ?? '';
          final name = d['residentName'] ?? '';
          final amt = (d['amount'] as num?)?.toDouble() ?? 0;
          final mode = d['paymentMode'] ?? '';
          final selfReported = d['selfReported'] == true;
          final status = d['status'] ?? '';

          if (status == 'deleted') {
            entries.add({
              'type': 'deleted',
              'flat': flat, 'name': name, 'amt': amt,
              'ref': doc.reference,
              'preDeleteStatus': d['preDeleteStatus'] ?? '',
              'preDeleteAmountReceived': d['preDeleteAmountReceived'],
              'ts': d['deletedAt'] ?? d['paidAt'] ?? '',
            });
          } else if (selfReported) {
            entries.add({
              'type': 'submitted',
              'flat': flat, 'name': name, 'amt': amt, 'mode': mode,
              'ts': d['reportedAt'] ?? d['paidAt'] ?? '',
            });
            if (status == 'confirmed' && (d['confirmedAt'] ?? '').isNotEmpty) {
              entries.add({
                'type': 'confirmed',
                'flat': flat, 'name': name, 'amt': amt, 'mode': mode,
                'ts': d['confirmedAt'],
              });
            }
            if (status == 'rejected' && (d['rejectedAt'] ?? '').isNotEmpty) {
              entries.add({
                'type': 'rejected',
                'flat': flat, 'name': name, 'amt': amt,
                'reason': d['rejectionReason'] ?? '',
                'ref': doc.reference,
                'ts': d['rejectedAt'],
              });
            }
          } else {
            entries.add({
              'type': 'added',
              'flat': flat, 'name': name, 'amt': amt, 'mode': mode,
              'ts': d['paidAt'] ?? '',
            });
          }
        }

        // Attach parsed DateTime, apply flat filter, sort newest first
        for (final e in entries) {
          e['dt'] = _parse(e['ts'] as String?);
        }
        final displayEntries = _flatFilter.isEmpty
            ? entries
            : entries.where((e) =>
                (e['flat'] as String? ?? '').toLowerCase().contains(_flatFilter)).toList();
        displayEntries.sort((a, b) {
          final dtA = a['dt'] as DateTime?;
          final dtB = b['dt'] as DateTime?;
          if (dtA == null && dtB == null) return 0;
          if (dtA == null) return 1;
          if (dtB == null) return -1;
          return dtB.compareTo(dtA);
        });

        if (displayEntries.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(_flatFilter.isEmpty ? 'No activity yet' : 'No activity for "$_flatFilter"',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
              ],
            ),
          );
        }

        // Collect all unique month and date keys for expand/collapse all
        final allMonthKeys = <String>{};
        final allDateKeys = <String>{};
        for (final e in displayEntries) {
          final dt = e['dt'] as DateTime?;
          if (dt == null) continue;
          allMonthKeys.add('${dt.year}-${dt.month.toString().padLeft(2, '0')}');
          allDateKeys.add('${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}');
        }
        final allExpanded = _expandedMonths.containsAll(allMonthKeys) &&
            _expandedDates.containsAll(allDateKeys);

        // Auto-expand the most recent month on first data load
        if (!_autoExpanded && allMonthKeys.isNotEmpty) {
          _autoExpanded = true;
          final mostRecent = allMonthKeys.reduce(
              (a, b) => a.compareTo(b) > 0 ? a : b);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _expandedMonths.add(mostRecent));
          });
        }

        // Group by month key ("2026-06"), then by date key ("2026-06-25")
        final listItems = <_ActivityItem>[];
        String lastMonth = '';
        String lastDate = '';

        for (final e in displayEntries) {
          final dt = e['dt'] as DateTime?;
          final monthKey = dt != null ? '${dt.year}-${dt.month.toString().padLeft(2, '0')}' : '';
          final dateKey  = dt != null ? '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}' : '';

          if (monthKey != lastMonth) {
            final count = displayEntries.where((x) {
              final xdt = x['dt'] as DateTime?;
              final xkey = xdt != null ? '${xdt.year}-${xdt.month.toString().padLeft(2, '0')}' : '';
              return xkey == monthKey;
            }).length;
            listItems.add(_ActivityItem.monthHeader(
                dt != null ? _monthLabel(dt) : 'Unknown', monthKey, count));
            lastMonth = monthKey;
            lastDate = '';
          }
          if (!_expandedMonths.contains(lastMonth)) continue;
          if (dateKey != lastDate) {
            final dayCount = displayEntries.where((x) {
              final xdt = x['dt'] as DateTime?;
              final xkey = xdt != null
                  ? '${xdt.year}-${xdt.month.toString().padLeft(2, '0')}-${xdt.day.toString().padLeft(2, '0')}'
                  : '';
              return xkey == dateKey;
            }).length;
            listItems.add(_ActivityItem.dateHeader(
              dt != null ? '${_days[dt.weekday]}, ${_dateLabel(dt)}' : 'Unknown date',
              dateKey,
              dayCount,
            ));
            lastDate = dateKey;
          }
          if (!_expandedDates.contains(lastDate)) continue;
          listItems.add(_ActivityItem.entry(e, dt));
        }

        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        return Column(
          children: [
            // Toolbar: search toggle (left) + expand/collapse (right)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  // Search icon toggles inline field
                  IconButton(
                    icon: Icon(
                      _showSearch ? Icons.search_off : Icons.search,
                      size: 20,
                      color: _flatFilter.isNotEmpty
                          ? Colors.deepPurple.shade600
                          : Colors.grey.shade500),
                    tooltip: 'Filter by flat',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() {
                      _showSearch = !_showSearch;
                      if (!_showSearch) _searchCtrl.clear();
                    }),
                  ),
                  if (_flatFilter.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Chip(
                      label: Text(_flatFilter,
                          style: const TextStyle(fontSize: 11)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => _searchCtrl.clear(),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.deepPurple.shade50,
                      side: BorderSide(color: Colors.deepPurple.shade200),
                    ),
                  ],
                  const Spacer(),
                  TextButton.icon(
                    icon: Icon(
                      allExpanded ? Icons.unfold_less : Icons.unfold_more,
                      size: 16),
                    label: Text(allExpanded ? 'Collapse All' : 'Expand All',
                        style: const TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.deepPurple.shade400,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                    onPressed: () => setState(() {
                      if (allExpanded) {
                        _expandedMonths.clear();
                        _expandedDates.clear();
                      } else {
                        _expandedMonths.addAll(allMonthKeys);
                        _expandedDates.addAll(allDateKeys);
                      }
                    }),
                  ),
                ],
              ),
            ),
            // Inline search field — only visible when toggled
            if (_showSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Flat number (e.g. DA404)',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade400),
                    suffixIcon: _flatFilter.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => _searchCtrl.clear())
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade200)),
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(12, 4, 12, keyboardHeight + 80),
                itemCount: listItems.length,
          itemBuilder: (_, i) {
            final item = listItems[i];

            // Month header — tappable to expand/collapse
            if (item.isMonthHeader) {
              final isExpanded = _expandedMonths.contains(item.monthKey);
              return GestureDetector(
                onTap: () => setState(() {
                  if (isExpanded) {
                    _expandedMonths.remove(item.monthKey);
                  } else {
                    _expandedMonths.add(item.monthKey!);
                  }
                }),
                child: Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 16, bottom: 4),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade600,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item.label!,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5)),
                          const SizedBox(width: 4),
                          Text('(${item.entryCount})',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 10)),
                          const SizedBox(width: 4),
                          Icon(
                            isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: Colors.white, size: 14),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Divider(color: Colors.deepPurple.shade100)),
                  ]),
                ),
              );
            }

            // Date header — tappable to expand/collapse
            if (item.isDateHeader) {
              final isExpanded = _expandedDates.contains(item.dateKey);
              return GestureDetector(
                onTap: () => setState(() {
                  if (isExpanded) {
                    _expandedDates.remove(item.dateKey);
                  } else {
                    _expandedDates.add(item.dateKey!);
                  }
                }),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4, left: 2),
                  child: Row(
                    children: [
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(item.label!,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700)),
                      const SizedBox(width: 6),
                      Text('(${item.entryCount})',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade400)),
                    ],
                  ),
                ),
              );
            }

            // Entry row
            final e = item.entry!;
            final dt = item.dt;
            final type = e['type'] as String;

            Color iconBg; Color iconColor; IconData icon;
            String title; String subtitle;

            DocumentReference? actionRef;
            VoidCallback? onRestore;

            switch (type) {
              case 'confirmed':
                iconBg = Colors.green.shade50; iconColor = Colors.green.shade700;
                icon = Icons.check_circle_outline;
                title = 'Confirmed ₹${_fmt(e['amt'] as double)} from ${e['flat']}';
                subtitle = '${e['name']}  ·  ${e['mode']}';
              case 'rejected':
                iconBg = Colors.red.shade50; iconColor = Colors.red.shade600;
                icon = Icons.cancel_outlined;
                title = 'Rejected payment from ${e['flat']}';
                subtitle = '${e['name']}  ·  Reason: ${e['reason']}';
                actionRef = e['ref'] as DocumentReference?;
                if (actionRef != null) onRestore = () => _restoreRejected(actionRef!, e);
              case 'deleted':
                iconBg = Colors.grey.shade100; iconColor = Colors.grey.shade600;
                icon = Icons.delete_outline;
                title = 'Deleted ₹${_fmt(e['amt'] as double)} from ${e['flat']}';
                subtitle = e['name'] as String;
                actionRef = e['ref'] as DocumentReference?;
                if (actionRef != null) onRestore = () => _restore(actionRef!, e);
              case 'submitted':
                iconBg = Colors.orange.shade50; iconColor = Colors.orange.shade700;
                icon = Icons.upload_outlined;
                title = 'Resident submitted ₹${_fmt(e['amt'] as double)} from ${e['flat']}';
                subtitle = '${e['name']}  ·  ${e['mode']}';
              default:
                iconBg = Colors.blue.shade50; iconColor = Colors.blue.shade700;
                icon = Icons.add_circle_outline;
                title = 'Admin recorded ₹${_fmt(e['amt'] as double)} for ${e['flat']}';
                subtitle = (e['name'] as String).isNotEmpty
                    ? '${e['name']}  ·  ${e['mode']}' : e['mode'] as String;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: type == 'deleted' ? Colors.grey.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: type == 'deleted'
                      ? Colors.grey.shade200 : Colors.grey.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                          color: iconBg, borderRadius: BorderRadius.circular(8)),
                      child: Icon(icon, size: 18, color: iconColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: type == 'deleted'
                                      ? Colors.grey.shade500 : null,
                                  decoration: type == 'deleted'
                                      ? TextDecoration.lineThrough : null)),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(subtitle,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade600)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (dt != null)
                          Text(_fmtTime(dt),
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade400)),
                        if (onRestore != null) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: onRestore,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: type == 'deleted'
                                    ? Colors.blue.shade50
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: type == 'deleted'
                                        ? Colors.blue.shade200
                                        : Colors.orange.shade200),
                              ),
                              child: Text(
                                type == 'deleted' ? 'Restore' : 'Revert',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: type == 'deleted'
                                        ? Colors.blue.shade700
                                        : Colors.orange.shade700),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),      // ListView.builder
        ),      // Expanded
          ],
        );     // Column
      },
    );
  }
}

class _ActivityItem {
  final bool isMonthHeader;
  final bool isDateHeader;
  final String? label;
  final String? monthKey;
  final String? dateKey;
  final int entryCount;
  final Map<String, dynamic>? entry;
  final DateTime? dt;

  const _ActivityItem._({
    required this.isMonthHeader,
    required this.isDateHeader,
    this.label,
    this.monthKey,
    this.dateKey,
    this.entryCount = 0,
    this.entry,
    this.dt,
  });

  factory _ActivityItem.monthHeader(String label, String monthKey, int count) =>
      _ActivityItem._(
          isMonthHeader: true, isDateHeader: false,
          label: label, monthKey: monthKey, entryCount: count);

  factory _ActivityItem.dateHeader(String label, String dateKey, int count) =>
      _ActivityItem._(
          isMonthHeader: false, isDateHeader: true,
          label: label, dateKey: dateKey, entryCount: count);

  factory _ActivityItem.entry(Map<String, dynamic> e, DateTime? dt) =>
      _ActivityItem._(isMonthHeader: false, isDateHeader: false, entry: e, dt: dt);
}
