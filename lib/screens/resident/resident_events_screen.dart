import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../auth/login_screen.dart';
import '../events/event_dashboard_screen.dart';
import '../events/event_types.dart';
import '../events/self_report_sheet.dart';
import 'contribution_history_screen.dart';
import '../../utils/event_status.dart';
import '../events/featured_event_banner.dart';
import '../../theme/app_theme.dart';
import '../settings/theme_settings_sheet.dart';

const _kMonthNames = [
  '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
String _monthName(int m) => _kMonthNames[m.clamp(1, 12)];

class ResidentEventsScreen extends StatefulWidget {
  const ResidentEventsScreen({super.key});

  @override
  State<ResidentEventsScreen> createState() => _ResidentEventsScreenState();
}

class _ResidentEventsScreenState extends State<ResidentEventsScreen>
    with SingleTickerProviderStateMixin {
  String _flatNumber = '';
  String _residentName = '';
  String _wing = '';
  String _block = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
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
      _wing = prefs.getString('session_wing') ?? '';
      _block = prefs.getString('session_block') ?? '';
    });
  }

  String get _addressLabel => [
        if (_wing.isNotEmpty) _wing,
        if (_block.isNotEmpty) 'Block $_block',
        if (_flatNumber.isNotEmpty) 'Flat $_flatNumber',
      ].join(' → ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 168,
            pinned: true,
            backgroundColor: AppTheme.accent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    const Positioned(
                      right: 20,
                      top: 78,
                      child: Icon(Icons.celebration,
                          size: 40, color: Colors.white24),
                    ),
                    if (_residentName.isNotEmpty || _addressLabel.isNotEmpty)
                      Positioned(
                        left: 16,
                        right: 16,
                        top: 50,
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline,
                                color: Colors.white70, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                [
                                  if (_residentName.isNotEmpty) _residentName,
                                  if (_addressLabel.isNotEmpty) _addressLabel,
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Positioned(
                      left: 16,
                      right: 16,
                      top: 76,
                      child: Text('My Events',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 19,
                              color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.receipt_long_outlined, color: Colors.white70),
                tooltip: 'My Contribution History',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ContributionHistoryScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.palette_outlined, color: Colors.white70),
                tooltip: 'Theme',
                onPressed: () => showThemeSettingsSheet(context),
              ),
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
                Tab(text: 'Upcoming'),
                Tab(text: 'Ongoing'),
                Tab(text: 'Past'),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: FeaturedEventBanner(isAdmin: false)),
        ],
        body: _flatNumber.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _EventsTab(flatNumber: _flatNumber, residentName: _residentName, status: 'upcoming'),
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
                  status == 'upcoming'
                      ? 'No upcoming events yet'
                      : status == 'active'
                          ? 'No ongoing events right now'
                          : 'No past events yet',
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 15,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.78,
          ),
          itemCount: events.length,
          itemBuilder: (context, i) {
            final data = events[i].data() as Map<String, dynamic>;
            final eventType = eventTypeById(data['eventTypeId'] as String?);
            final imageUrl =
                (data['bannerUrl'] as String?)?.isNotEmpty == true
                    ? data['bannerUrl'] as String
                    : (eventType?.imageUrl ?? '');
            return _ResidentEventGridCard(
              eventDoc: events[i],
              flatNumber: flatNumber,
              residentName: residentName,
              status: status,
              imageUrl: imageUrl,
              gradientColors: eventType?.gradient ??
                  [AppTheme.accent, AppTheme.accent.shade300],
              typeEmoji: eventType?.emoji ?? '🎉',
              tagline: eventType?.tagline ?? '',
            );
          },
        );
      },
    );
  }
}

// ── Resident Event Grid Card ──────────────────────────────────────────────────

class _ResidentEventGridCard extends StatefulWidget {
  final QueryDocumentSnapshot eventDoc;
  final String flatNumber, residentName, imageUrl, typeEmoji, tagline;
  final String status;
  final List<Color> gradientColors;

  const _ResidentEventGridCard({
    required this.eventDoc,
    required this.flatNumber,
    required this.residentName,
    required this.status,
    required this.imageUrl,
    required this.gradientColors,
    required this.typeEmoji,
    required this.tagline,
  });

  bool get isActive => status == 'active';

  @override
  State<_ResidentEventGridCard> createState() => _ResidentEventGridCardState();
}

class _ResidentEventGridCardState extends State<_ResidentEventGridCard> {
  String _paymentStatus = 'loading'; // loading | none | paid | pending | rejected
  String _resolvedFlat = '';
  double _paidAmt = 0;
  double _pendingAmt = 0;
  double _rejectedAmt = 0;
  StreamSubscription<QuerySnapshot>? _statusSub;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    await _statusSub?.cancel();
    final prefs = await SharedPreferences.getInstance();
    final sessionFlat = widget.flatNumber.trim();
    final wing = prefs.getString('session_wing') ?? '';
    final block = prefs.getString('session_block') ?? '';
    String resolvedFlat = sessionFlat;

    if (wing.isNotEmpty && block.isNotEmpty) {
      try {
        final settingsDoc = await FirebaseFirestore.instance
            .collection('community_settings').doc('address').get();
        if (settingsDoc.exists) {
          final wingBlocks = (settingsDoc.data() as Map<String, dynamic>?)?['wingBlocks']
              as Map<String, dynamic>? ?? {};
          final flats = ((wingBlocks[wing] as Map<String, dynamic>?)?[block] as List?)
              ?.cast<String>() ?? [];
          for (final f in flats) {
            if (f == sessionFlat || f.endsWith(sessionFlat) || sessionFlat.endsWith(f)) {
              resolvedFlat = f;
              break;
            }
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _resolvedFlat = resolvedFlat);

    final queryFlats = {sessionFlat, resolvedFlat}.toList();
    _statusSub = FirebaseFirestore.instance
        .collection('events').doc(widget.eventDoc.id)
        .collection('contributions')
        .where('flatNumber', whereIn: queryFlats)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      double paidAmt = 0, pendingAmt = 0, rejectedAmt = 0;
      for (final doc in snap.docs) {
        final d = doc.data() as Map<String, dynamic>;
        if (d['status'] == 'deleted') continue;
        final amt = (d['amount'] as num? ?? 0).toDouble();
        if (d['status'] == 'rejected') {
          rejectedAmt += amt;
        } else if (d['amountReceived'] == true) {
          paidAmt += amt;
        } else {
          pendingAmt += amt;
        }
      }
      String status;
      if (paidAmt > 0) status = 'paid';
      else if (pendingAmt > 0) status = 'pending';
      else if (rejectedAmt > 0) status = 'rejected';
      else status = 'none';
      setState(() {
        _paymentStatus = status;
        _paidAmt = paidAmt;
        _pendingAmt = pendingAmt;
        _rejectedAmt = rejectedAmt;
      });
    });
  }

  Future<void> _selfReport(BuildContext context, String eventName) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SelfReportSheet(
        eventId: widget.eventDoc.id,
        eventName: eventName,
        flatNumber: _resolvedFlat.isNotEmpty ? _resolvedFlat : widget.flatNumber,
        residentName: widget.residentName,
        onSubmitted: () => _loadStatus(),
      ),
    );
  }

  void _showPaymentsDialog(BuildContext context, String eventName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (ctx, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(children: [
                  Icon(Icons.receipt_long_outlined,
                      color: AppTheme.accent.shade400, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(eventName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('events')
                      .doc(widget.eventDoc.id)
                      .collection('contributions')
                      .where('flatNumber', whereIn:
                          {_resolvedFlat.isNotEmpty ? _resolvedFlat : widget.flatNumber,
                           widget.flatNumber}.toList())
                      .snapshots(),
                  builder: (context, snap) {
                    final docs = (snap.data?.docs ?? [])
                        .where((d) =>
                            (d.data() as Map<String, dynamic>)['status'] !=
                            'deleted')
                        .toList()
                      ..sort((a, b) {
                        final aT = (a.data() as Map<String, dynamic>)['reportedAt']
                            as String? ??
                            (a.data() as Map<String, dynamic>)['paidAt'] as String? ?? '';
                        final bT = (b.data() as Map<String, dynamic>)['reportedAt']
                            as String? ??
                            (b.data() as Map<String, dynamic>)['paidAt'] as String? ?? '';
                        return bT.compareTo(aT); // latest first
                      });

                    if (docs.isEmpty) {
                      return Center(
                        child: Text('No payments recorded yet.',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 14)),
                      );
                    }

                    double totalPaid = 0;
                    for (final doc in docs) {
                      final d = doc.data() as Map<String, dynamic>;
                      if (d['amountReceived'] == true) {
                        totalPaid += (d['amount'] as num? ?? 0).toDouble();
                      }
                    }

                    return ListView(
                      controller: ctrl,
                      padding: const EdgeInsets.all(12),
                      children: [
                        ...docs.map((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          final amt =
                              (d['amount'] as num?)?.toDouble() ?? 0;
                          final mode = d['paymentMode'] ?? '';
                          final date = d['paidDate'] ?? '';
                          final isConfirmed = d['amountReceived'] == true;
                          final isRejected = d['status'] == 'rejected';
                          final isPending = !isConfirmed && !isRejected;
                          final reason =
                              (d['rejectionReason'] ?? '').toString().trim();

                          Color bg, border, textCol;
                          String label;
                          IconData icon;
                          if (isConfirmed) {
                            bg = Colors.green.shade50;
                            border = Colors.green.shade200;
                            textCol = Colors.green.shade700;
                            label = 'Confirmed';
                            icon = Icons.check_circle_rounded;
                          } else if (isRejected) {
                            bg = Colors.red.shade50;
                            border = Colors.red.shade200;
                            textCol = Colors.red.shade700;
                            label = 'Rejected';
                            icon = Icons.cancel_rounded;
                          } else {
                            bg = Colors.orange.shade50;
                            border = Colors.orange.shade200;
                            textCol = Colors.orange.shade700;
                            label = 'Pending';
                            icon = Icons.hourglass_top_rounded;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: border),
                            ),
                            child: Row(
                              children: [
                                Icon(icon, color: textCol, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '₹${amt.toStringAsFixed(0)}  ·  $mode${date.isNotEmpty ? '  ·  $date' : ''}',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: textCol),
                                      ),
                                      if (isRejected && reason.isNotEmpty)
                                        Text('Reason: $reason',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.red.shade500)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: textCol.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(label,
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: textCol)),
                                ),
                                // Edit button — only for pending payments on active events
                                if (isPending && widget.isActive) ...[
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined,
                                        color: Colors.blue.shade400,
                                        size: 17),
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      await showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (_) => SelfReportSheet(
                                          eventId: widget.eventDoc.id,
                                          eventName: eventName,
                                          flatNumber: _resolvedFlat.isNotEmpty
                                              ? _resolvedFlat
                                              : widget.flatNumber,
                                          residentName: widget.residentName,
                                          existingDoc: doc,
                                          onSubmitted: () => _loadStatus(),
                                        ),
                                      );
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Edit',
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                        if (totalPaid > 0) ...[
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('Total Confirmed: ',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600)),
                              Text('₹${totalPaid.toStringAsFixed(0)}',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700)),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.eventDoc.data() as Map<String, dynamic>;
    final name = data['name'] ?? '';
    final double collected = ((data['totalCollected'] ?? 0) as num).toDouble();
    final double target = ((data['targetAmount'] ?? 0) as num).toDouble();
    final double progress = target > 0 ? (collected / target).clamp(0.0, 1.0) : 0.0;

    String _fmt(double v) =>
        v >= 1000 && v % 1000 == 0 ? '₹${(v / 1000).toStringAsFixed(0)}K' : '₹${v.toStringAsFixed(0)}';

    Widget pill(String text, Color bg) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: bg.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(text,
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
        );

    // Status badge — tappable; shows payments dialog
    final hasAnyPayment = _paidAmt > 0 || _pendingAmt > 0 || _rejectedAmt > 0;
    Widget statusBadge() {
      if (_paymentStatus == 'loading') return const SizedBox.shrink();
      final parts = <Widget>[];
      if (_paidAmt > 0) parts.add(pill('✅ ${_fmt(_paidAmt)}', Colors.green));
      if (_pendingAmt > 0) parts.add(pill('⏳ ${_fmt(_pendingAmt)}', Colors.orange));
      if (_rejectedAmt > 0) parts.add(pill('❌ ${_fmt(_rejectedAmt)}', Colors.red));
      if (parts.isEmpty) parts.add(pill(eventStatusLabel(widget.status), eventStatusColor(widget.status)));
      final badge = Row(
        mainAxisSize: MainAxisSize.min,
        children: parts
            .expand((w) => [w, const SizedBox(width: 3)])
            .toList()
          ..removeLast(),
      );
      if (!hasAnyPayment) return badge;
      return GestureDetector(
        onTap: () => _showPaymentsDialog(context, name),
        child: badge,
      );
    }

    // Pay button label & color — only for active events
    Color payBtnColor;
    String payBtnLabel;
    if (_pendingAmt > 0) {
      payBtnColor = Colors.orange.shade700;
      payBtnLabel = 'Pay';
    } else if (_paymentStatus == 'paid') {
      payBtnColor = Colors.teal.shade600;
      payBtnLabel = 'Pay+';
    } else if (_paymentStatus == 'rejected') {
      payBtnColor = Colors.red.shade600;
      payBtnLabel = 'Pay';
    } else {
      payBtnColor = Colors.green.shade600;
      payBtnLabel = 'Pay';
    }

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => EventDashboardScreen(
          eventId: widget.eventDoc.id,
          eventName: name,
          isAdmin: false,
        ),
      )),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: widget.gradientColors[0].withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 5))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              if (widget.imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: widget.imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: widget.gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: widget.gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                  ),
                ),
              // Dark overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              // Content (leaves bottom-right 44px free for pay button)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(widget.typeEmoji, style: const TextStyle(fontSize: 14)),
                        ),
                        const Spacer(),
                        statusBadge(),
                      ],
                    ),
                    const Spacer(),
                    // Reserve space at bottom so text doesn't overlap pay button
                    Padding(
                      padding: EdgeInsets.only(
                          bottom: widget.isActive ? 44 : 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  height: 1.2)),
                          if (widget.tagline.isNotEmpty)
                            Text(widget.tagline,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 10)),
                          if (target > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('₹${collected.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11)),
                                Text('${(progress * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 10)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                                backgroundColor: Colors.white24,
                                valueColor:
                                    AlwaysStoppedAnimation(widget.gradientColors[0]),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Small pay button — bottom-right, active events only
              if (widget.isActive && _paymentStatus != 'loading')
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('appSettings')
                      .doc('payments')
                      .snapshots(),
                  builder: (context, paySnap) {
                    final payData = paySnap.data?.data() as Map<String, dynamic>? ?? {};
                    final enabledTypeIds = List<String>.from(payData['enabledTypeIds'] as List? ?? []);
                    final resolvedType = eventTypeById(data['eventTypeId'] as String?) ??
                        eventTypeByName(data['name'] as String?);
                    if (!enabledTypeIds.contains(resolvedType?.id ?? '')) {
                      return const SizedBox.shrink();
                    }
                    return Positioned(
                  right: 8,
                  bottom: 10,
                  child: GestureDetector(
                    onTap: () => _selfReport(context, name),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: payBtnColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.payments_rounded,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(payBtnLabel,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
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
          _contributions = snap.docs
              .map((d) => d.data())
              .where((d) => d['status'] != 'deleted')
              .toList();
          _loaded = true;
        });
      }
    });
  }

  Future<void> _selfReport(BuildContext context, String eventName) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SelfReportSheet(
        eventId: widget.eventDoc.id,
        eventName: eventName,
        flatNumber: _resolvedFlat.isNotEmpty ? _resolvedFlat : widget.flatNumber,
        residentName: widget.residentName,
        onSubmitted: () {},
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

    final statusLabel = widget.isActive ? '🟢 Active' : '🔴 Closed';
    const statusColor = Colors.white70;

    // Only allow card tap when no action has been taken yet (pending/not recorded).
    // Rejected and confirmed states are shown inline; user can use the Dashboard button explicitly.
    final onCardTap = (hasPaid || hasRejected)
        ? null
        : () => _openDashboard(context, eventName);

    return GestureDetector(
      onTap: onCardTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.08),
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
                            '₹${collected.toStringAsFixed(0)} collected',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accent)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation(
                            AppTheme.accent),
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
                // Format confirmed date if available
                String confirmedOn = '';
                if (!isPending) {
                  final raw = c['confirmedAt'] as String?;
                  if (raw != null && raw.isNotEmpty) {
                    try {
                      final dt = DateTime.parse(raw).toLocal();
                      confirmedOn =
                          '${dt.day} ${_monthName(dt.month)} ${dt.year}';
                    } catch (_) {}
                  }
                }
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isPending
                        ? Colors.orange.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isPending
                            ? Colors.orange.shade200
                            : Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(
                          isPending
                              ? Icons.hourglass_top_rounded
                              : Icons.check_circle_rounded,
                          color: isPending
                              ? Colors.orange.shade600
                              : Colors.green.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '₹$amount${mode.isNotEmpty ? ' · $mode' : ''}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isPending
                                  ? Colors.orange.shade700
                                  : Colors.green.shade700),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPending
                                ? Colors.orange.shade100
                                : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isPending ? 'Pending Verification' : 'Confirmed',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isPending
                                    ? Colors.orange.shade700
                                    : Colors.green.shade700),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        [type, if (mode.isNotEmpty) mode].join(' · '),
                        style: TextStyle(
                            fontSize: 12,
                            color: isPending
                                ? Colors.orange.shade600
                                : Colors.green.shade600),
                      ),
                      const SizedBox(height: 2),
                      if (isPending)
                        Text('Admin will verify and confirm your payment.',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade400))
                      else
                        Text(
                          confirmedOn.isNotEmpty
                              ? 'Payment confirmed by admin on $confirmedOn.'
                              : 'Payment confirmed by admin.',
                          style: TextStyle(
                              fontSize: 11, color: Colors.green.shade500),
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
                  // I've Paid button — shown for all active events
                  if (widget.isActive)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _selfReport(context, eventName),
                        icon: const Icon(Icons.payments_rounded, size: 16),
                        label: Text(
                          hasPaid ? 'Pay Again' : hasRejected ? 'Re-submit Payment' : hasPending ? 'Report Another Payment' : "I've Paid",
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasPaid ? Colors.teal.shade600 : Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  if (widget.isActive) const SizedBox(width: 10),
                  // View dashboard hint
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openDashboard(context, eventName),
                      icon: Icon(Icons.open_in_new,
                          size: 14, color: AppTheme.accent.shade400),
                      label: Text('Dashboard',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.accent.shade400)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.accent.shade200),
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

