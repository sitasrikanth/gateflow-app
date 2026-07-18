import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../auth/login_screen.dart';
import '../admin/admin_home_screen.dart';
import '../resident/resident_events_screen.dart';
import '../resident/resident_home_screen.dart';
import 'event_type_settings_screen.dart';
import 'add_contribution_screen.dart';
import 'carry_forward_screen.dart';
import 'add_expense_screen.dart';
import 'send_notification_screen.dart';
import 'create_event_screen.dart';
import '../../utils/event_pdf_report.dart';
import '../../utils/country_codes.dart';
import '../../utils/event_status.dart';
import 'import_export_screen.dart';
import 'event_types.dart';
import 'self_report_sheet.dart';
import 'sponsor_packages_screen.dart';
import 'task_form_screen.dart';
import 'task_detail_sheet.dart';
import 'competitions_tab.dart';
import 'prasad_tab.dart';
import '../../theme/app_theme.dart';

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
    with TickerProviderStateMixin {
  // Created lazily once eventTypeConfig/{typeId}.applicableTabs (and, for
  // residents, .residentTabs) is known, so the tab count reflects per-event-
  // type config for BOTH roles — see _ensureTabController.
  TabController? _tabController;
  String _residentFlat = '';
  String _residentName = '';
  String _residentWing = '';
  String _residentBlock = '';

  @override
  void initState() {
    super.initState();
    if (!widget.isAdmin) _loadSession();
  }

  void _ensureTabController(int length) {
    if (_tabController != null && _tabController!.length == length) return;
    final oldIndex = _tabController?.index ?? 0;
    _tabController?.dispose();
    _tabController = TabController(
        length: length, vsync: this, initialIndex: oldIndex < length ? oldIndex : 0);
  }

  Tab _residentTabWidgetFor(String id) => Tab(
      text: kResidentTabDefs
          .firstWhere((t) => t.$1 == id, orElse: () => ('', id))
          .$2);

  _TabItem _adminTabItemFor(String id) {
    const icons = {
      'overview': Icons.dashboard_outlined,
      'event': Icons.event_note_outlined,
      'contributions': Icons.volunteer_activism_outlined,
      'expenses': Icons.receipt_long_outlined,
      'followup': Icons.pending_actions_outlined,
      'volunteers': Icons.groups_outlined,
      'tasks': Icons.checklist_outlined,
      'activity': Icons.history_outlined,
      'competitions': Icons.emoji_events_outlined,
      'prasad': Icons.restaurant_outlined,
      'leaderboard': Icons.leaderboard_outlined,
    };
    // Each tab gets its own distinct color (matching that feature's color
    // elsewhere in the app, e.g. green for Contributions/red for Expenses)
    // so the tab bar reads as a row of distinct destinations at a glance,
    // not a repeated single-color icon.
    final colors = {
      'overview': AppTheme.accent,
      'event': Colors.blue,
      'contributions': Colors.green.shade600,
      'expenses': Colors.red.shade400,
      'followup': Colors.orange.shade700,
      'volunteers': Colors.teal,
      'tasks': Colors.indigo,
      'activity': Colors.blueGrey,
      'competitions': Colors.amber.shade800,
      'prasad': Colors.brown.shade400,
      'leaderboard': Colors.pink.shade400,
    };
    final label = kAdminTabDefs.firstWhere((t) => t.$1 == id, orElse: () => ('', id)).$2;
    return _TabItem(
        icon: icons[id] ?? Icons.circle_outlined,
        label: label,
        color: colors[id] ?? AppTheme.accent);
  }

  Widget _adminTabViewFor(
    String id, {
    required Map<String, dynamic> data,
    required double collected,
    required double spent,
    required double balance,
    required String status,
  }) {
    switch (id) {
      case 'overview':
        return _OverviewTab(
            eventId: widget.eventId,
            collected: collected,
            spent: spent,
            balance: balance,
            data: data,
            isAdmin: true);
      case 'event':
        return _EventTab(
            eventId: widget.eventId,
            data: data,
            isAdmin: true,
            residentFlat: _residentFlat,
            residentName: _residentName,
            residentWing: _residentWing,
            residentBlock: _residentBlock);
      case 'contributions':
        return _ContributionsTab(
            eventId: widget.eventId,
            eventName: widget.eventName,
            eventTypeId: data['eventTypeId'] as String? ?? '',
            isAdmin: true,
            status: status,
            residentFlat: _residentFlat);
      case 'expenses':
        return _ExpensesTab(
            eventId: widget.eventId,
            eventTypeId: data['eventTypeId'] as String? ?? '',
            isAdmin: true,
            status: status);
      case 'followup':
        return _FollowUpTab(
            eventId: widget.eventId,
            eventName: data['name'] ?? widget.eventName);
      case 'volunteers':
        return _VolunteersTab(
            eventId: widget.eventId,
            eventTypeId: data['eventTypeId'] as String? ?? '',
            isAdmin: true);
      case 'tasks':
        return _TasksTab(eventId: widget.eventId);
      case 'activity':
        return _ActivityTab(eventId: widget.eventId);
      case 'competitions':
        return CompetitionsTab(
            eventId: widget.eventId,
            isAdmin: true,
            eventTypeId: data['eventTypeId'] as String? ?? '');
      case 'prasad':
        return PrasadTab(
            eventId: widget.eventId,
            isAdmin: true,
            eventTypeId: data['eventTypeId'] as String? ?? '');
      case 'leaderboard':
        return _LeaderboardTab(
            eventId: widget.eventId,
            isAdmin: true,
            eventTypeId: data['eventTypeId'] as String? ?? '');
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _residentTabViewFor(
    String id, {
    required Map<String, dynamic> data,
    required double collected,
    required double spent,
    required double balance,
    required String status,
  }) {
    switch (id) {
      case 'event':
        return _EventTab(
            eventId: widget.eventId,
            data: data,
            isAdmin: false,
            residentFlat: _residentFlat,
            residentName: _residentName,
            residentWing: _residentWing,
            residentBlock: _residentBlock);
      case 'overview':
        return _OverviewTab(
            eventId: widget.eventId,
            collected: collected,
            spent: spent,
            balance: balance,
            data: data,
            isAdmin: false,
            residentFlat: _residentFlat,
            residentName: _residentName,
            eventName: data['name'] ?? widget.eventName,
            status: status);
      case 'expenses':
        return _ExpensesTab(
            eventId: widget.eventId,
            eventTypeId: data['eventTypeId'] as String? ?? '',
            isAdmin: false,
            status: status);
      case 'volunteers':
        return _VolunteersTab(
            eventId: widget.eventId,
            eventTypeId: data['eventTypeId'] as String? ?? '',
            isAdmin: false,
            residentFlat: _residentFlat,
            residentName: _residentName,
            residentWing: _residentWing,
            residentBlock: _residentBlock);
      case 'competitions':
        return CompetitionsTab(
            eventId: widget.eventId,
            isAdmin: false,
            eventTypeId: data['eventTypeId'] as String? ?? '');
      case 'prasad':
        return PrasadTab(
            eventId: widget.eventId,
            isAdmin: false,
            eventTypeId: data['eventTypeId'] as String? ?? '');
      case 'leaderboard':
        return _LeaderboardTab(
            eventId: widget.eventId,
            isAdmin: false,
            eventTypeId: data['eventTypeId'] as String? ?? '');
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _residentFlat = prefs.getString('session_flat') ?? '';
        _residentName = prefs.getString('session_name') ?? '';
        _residentWing = prefs.getString('session_wing') ?? '';
        _residentBlock = prefs.getString('session_block') ?? '';
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _recalculateTotals(BuildContext context) async {
    try {
      final contribs = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('contributions')
          .get();

      // Self-heal: Carry Forward contributions have no legitimate "pending"
      // state — they're always fully received the moment they're created.
      // A stale restore (from before amountReceived/status handling was
      // fixed for admin-added types) can leave one stuck as not-received,
      // which silently drops it out of totals and the Overview chip. Force
      // it back to received before computing the total below.
      final healBatch = FirebaseFirestore.instance.batch();
      var healedCount = 0;
      for (final doc in contribs.docs) {
        final d = doc.data();
        if (d['status'] == 'deleted') continue;
        if (d['contributionType'] == kTypeCarryForward && d['amountReceived'] != true) {
          healBatch.update(doc.reference, {'amountReceived': true});
          d['amountReceived'] = true; // reflect in-memory for the sum below
          healedCount++;
        }
      }
      if (healedCount > 0) await healBatch.commit();

      double total = 0;
      final paidFlats = <String>{};
      for (final doc in contribs.docs) {
        final d = doc.data();
        if (d['status'] == 'deleted') continue;
        if (d['selfReported'] == true && d['amountReceived'] != true) continue;
        // Sponsorship amounts are often a nominal item value rather than
        // cash actually collected — kept out of totalCollected everywhere
        // (Overview "Collected" chip, Budget vs Actual, Balance), matching
        // the Contributions tab's own total.
        if (d['amountReceived'] == true && d['contributionType'] != kTypeSponsor) {
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

  // Re-derives this event's carriedForwardOut (and each transfer's reversed
  // flag) from the live status of the destination contribution each
  // transfer points to, instead of trusting the incrementally-tracked
  // field. Fixes drift from transfers created before source<->destination
  // linking existed, or from any other edge case that left them out of
  // sync (e.g. a transfer never getting reversed when its destination-side
  // contribution was deleted).
  Future<void> _recalculateCarryForwardBalance(BuildContext context) async {
    try {
      final transfers = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('carryForwardTransfers')
          .get();

      double total = 0;
      final batch = FirebaseFirestore.instance.batch();
      for (final t in transfers.docs) {
        final td = t.data();
        final destEventId = td['destEventId'] as String? ?? '';
        final amount = (td['amount'] as num? ?? 0).toDouble();
        final destContributionId = td['destContributionId'] as String?;
        bool stillActive = false;

        if (destEventId.isNotEmpty) {
          if (destContributionId != null && destContributionId.isNotEmpty) {
            final destDoc = await FirebaseFirestore.instance
                .collection('events')
                .doc(destEventId)
                .collection('contributions')
                .doc(destContributionId)
                .get();
            stillActive =
                destDoc.exists && (destDoc.data()?['status'] != 'deleted');
          } else {
            // Legacy transfer with no direct link — best-effort match by
            // source event + amount among the destination's contributions.
            final legacyQuery = await FirebaseFirestore.instance
                .collection('events')
                .doc(destEventId)
                .collection('contributions')
                .where('carryForwardSourceEventId', isEqualTo: widget.eventId)
                .where('amount', isEqualTo: amount)
                .get();
            stillActive =
                legacyQuery.docs.any((d) => d.data()['status'] != 'deleted');
          }
        }

        batch.update(t.reference, {'reversed': !stillActive});
        if (stillActive) total += amount;
      }
      batch.update(FirebaseFirestore.instance.collection('events').doc(widget.eventId),
          {'carriedForwardOut': total});
      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Carry-forward balance recalculated: ₹${total.toStringAsFixed(0)} still locked from ${transfers.docs.length} transfer${transfers.docs.length == 1 ? '' : 's'}'),
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
                ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
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

  Future<void> _reopenEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reopen Event'),
        content: const Text(
            'Move this event back to Ongoing? Residents and admins will be able to add contributions and expenses again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
            child: const Text('Reopen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .update({'status': 'active'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event reopened — now Ongoing')));
      }
    }
  }

  Future<void> _startEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Event'),
        content: const Text(
            'Move this event from Upcoming to Ongoing? Residents will be able to contribute and volunteer starting now.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
            child: const Text('Start', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .update({'status': 'active'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event started — now Ongoing')));
      }
    }
  }

  Future<void> _toggleFeatured(bool currentlyFeatured) async {
    final fs = FirebaseFirestore.instance;
    if (currentlyFeatured) {
      await fs.collection('events').doc(widget.eventId).update({'featured': false});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Removed from Featured banner')));
      }
      return;
    }
    // Only one event is featured at a time — unset any previously featured event first.
    final batch = fs.batch();
    final prevFeatured = await fs
        .collection('events')
        .where('featured', isEqualTo: true)
        .get();
    for (final doc in prevFeatured.docs) {
      batch.update(doc.reference, {'featured': false});
    }
    batch.update(fs.collection('events').doc(widget.eventId), {'featured': true});
    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Set as the Featured event')));
    }
  }

  Future<void> _deleteSubcollection(String name) async {
    final ref = FirebaseFirestore.instance
        .collection('events').doc(widget.eventId).collection(name);
    final snap = await ref.get();
    if (snap.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> _deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event?'),
        content: const Text(
            'This permanently deletes this event along with all its contributions, '
            'expenses, volunteer signups, and pooja registrations. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Event',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      for (final sub in ['contributions', 'expenses', 'poojaRegistrations', 'volunteers', 'schedule']) {
        await _deleteSubcollection(sub);
      }
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .delete();
    } finally {
      if (mounted) Navigator.pop(context); // dismiss loading dialog
    }

    if (mounted) Navigator.pop(context); // back to event list
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
        final featured = data['featured'] == true;
        final double progress =
            target > 0 ? ((collected / target).clamp(0.0, 1.0) as num).toDouble() : 0.0;

        // Resolve event type for image/gradient
        final eventType = eventTypeById(data['eventTypeId'] as String?) ??
            eventTypeByName(data['name'] as String?);
        final List<Color> headerGradient = eventType?.gradient ??
            [AppTheme.accent.shade700, AppTheme.accent.shade400];
        final String imageUrl =
            (data['bannerUrl'] as String?)?.isNotEmpty == true
                ? data['bannerUrl'] as String
                : (eventType?.imageUrl ?? '');

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              // Header
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: headerGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(children: [
                  if (imageUrl.isNotEmpty) ...[
                    Positioned.fill(
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox(),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.35),
                              Colors.black.withValues(alpha: 0.75),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                  ],
                  Padding(
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
                          onPressed: () async {
                            Widget destination = const AdminHomeScreen();
                            if (!widget.isAdmin) {
                              String landing = 'home';
                              try {
                                final doc = await FirebaseFirestore.instance
                                    .collection('community_settings')
                                    .doc('address')
                                    .get();
                                landing = (doc.data()?['residentLandingScreen']
                                        as String?) ??
                                    'home';
                              } catch (_) {}
                              destination = landing == 'events'
                                  ? const ResidentEventsScreen()
                                  : const ResidentHomeScreen();
                            }
                            if (!context.mounted) return;
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => destination),
                              (route) => false,
                            );
                          },
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                    (data['name'] as String?)?.isNotEmpty == true
                                        ? data['name']
                                        : widget.eventName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                              ),
                              if (!widget.isAdmin) ...[
                                const SizedBox(width: 8),
                                _ResidentContributeButton(
                                  eventId: widget.eventId,
                                  eventName: data['name'] ?? widget.eventName,
                                  eventTypeId: eventType?.id ?? '',
                                  status: status,
                                  startDate: data['startDate'] as String? ?? '',
                                  flatNumber: _residentFlat,
                                  residentName: _residentName,
                                ),
                              ],
                            ],
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
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('appSettings')
                                .doc('sponsorPackages')
                                .snapshots(),
                            builder: (context, sponsorSnap) {
                              final sponsorData = sponsorSnap.data?.data() as Map<String, dynamic>? ?? {};
                              final sponsorEnabledIds = List<String>.from(sponsorData['enabledTypeIds'] as List? ?? []);
                              final sponsorEnabled = sponsorEnabledIds.contains(eventType?.id ?? '');
                              return StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('appSettings')
                                .doc('deleteEvents')
                                .snapshots(),
                            builder: (context, delSnap) {
                              final delData = delSnap.data?.data() as Map<String, dynamic>? ?? {};
                              final deleteEnabledIds = List<String>.from(delData['enabledTypeIds'] as List? ?? []);
                              final deleteEnabled = deleteEnabledIds.contains(eventType?.id ?? '');
                              return PopupMenuButton<String>(
                            icon: const Icon(Icons.settings_outlined,
                                color: Colors.white),
                            tooltip: 'Event Tools',
                            onSelected: (val) {
                              if (val == 'import_export') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ImportExportScreen(
                                      eventId: widget.eventId,
                                      eventName: data['name'] ??
                                          widget.eventName,
                                      eventData: data,
                                      collected: collected,
                                      spent: spent,
                                      balance: balance,
                                      target: target,
                                    ),
                                  ),
                                );
                              }
                              if (val == 'recalculate') _recalculateTotals(context);
                              if (val == 'recalculate_carry_forward') {
                                _recalculateCarryForwardBalance(context);
                              }
                              if (val == 'carry_forward') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CarryForwardScreen(
                                        eventId: widget.eventId,
                                        eventName: data['name'] ?? widget.eventName),
                                  ),
                                );
                              }
                              if (val == 'close') _closeEvent();
                              if (val == 'reopen') _reopenEvent();
                              if (val == 'start') _startEvent();
                              if (val == 'toggle_featured') _toggleFeatured(featured);
                              if (val == 'delete') _deleteEvent();
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
                              if (val == 'sponsors') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SponsorPackagesScreen(eventId: widget.eventId),
                                  ),
                                );
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                  value: 'import_export',
                                  child: Row(children: [
                                    Icon(Icons.import_export_rounded,
                                        color: Colors.blueGrey),
                                    SizedBox(width: 8),
                                    Text('Import / Export'),
                                  ])),
                              const PopupMenuItem(
                                  value: 'recalculate',
                                  child: Row(children: [
                                    Icon(Icons.sync, color: Colors.teal),
                                    SizedBox(width: 8),
                                    Text('Recalculate Totals'),
                                  ])),
                              const PopupMenuItem(
                                  value: 'carry_forward',
                                  child: Row(children: [
                                    Icon(Icons.move_up, color: Colors.blue),
                                    SizedBox(width: 8),
                                    Text('Carry Forward Balance'),
                                  ])),
                              const PopupMenuItem(
                                  value: 'recalculate_carry_forward',
                                  child: Row(children: [
                                    Icon(Icons.sync_alt, color: Colors.teal),
                                    SizedBox(width: 8),
                                    Text('Recalculate Carry-Forward Balance'),
                                  ])),
                              PopupMenuItem(
                                  value: 'toggle_featured',
                                  child: Row(children: [
                                    Icon(
                                        featured
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: Colors.amber.shade700),
                                    const SizedBox(width: 8),
                                    Text(featured
                                        ? 'Remove from Featured'
                                        : 'Set as Featured Event'),
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
                              if (sponsorEnabled) ...[
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                    value: 'sponsors',
                                    child: Row(children: [
                                      Icon(Icons.workspace_premium_outlined,
                                          color: Colors.amber),
                                      SizedBox(width: 8),
                                      Text('Manage Sponsor Packages'),
                                    ])),
                              ],
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                  value: 'edit',
                                  child: Row(children: [
                                    Icon(Icons.edit_outlined,
                                        color: AppTheme.accent),
                                    const SizedBox(width: 8),
                                    const Text('Edit Event'),
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
                                    ]))
                              else if (status == 'upcoming')
                                PopupMenuItem(
                                    value: 'start',
                                    child: Row(children: [
                                      Icon(Icons.play_circle_outline,
                                          color: Colors.green.shade600),
                                      const SizedBox(width: 8),
                                      Text('Start Event',
                                          style: TextStyle(color: Colors.green.shade600))
                                    ]))
                              else
                                PopupMenuItem(
                                    value: 'reopen',
                                    child: Row(children: [
                                      Icon(Icons.lock_open_outlined,
                                          color: Colors.green.shade600),
                                      const SizedBox(width: 8),
                                      Text('Reopen Event',
                                          style: TextStyle(color: Colors.green.shade600))
                                    ])),
                              if (deleteEnabled) ...[
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(children: [
                                      Icon(Icons.delete_forever,
                                          color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete Event',
                                          style: TextStyle(color: Colors.red))
                                    ])),
                              ],
                            ],
                              );
                            },
                          );
                            },
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
                ]),
              ),

              // ── Tab bar + content: id-driven for both roles, filtered by
              // eventTypeConfig/{typeId}.applicableTabs (both roles) and,
              // for residents, further filtered by .residentTabs ──
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: eventType != null
                      ? FirebaseFirestore.instance
                          .collection('eventTypeConfig')
                          .doc(eventType.id)
                          .snapshots()
                      : const Stream<DocumentSnapshot>.empty(),
                  builder: (context, configSnap) {
                    final configData =
                        configSnap.data?.data() as Map<String, dynamic>? ?? {};
                    final rawApplicable = configData['applicableTabs'];
                    final applicableTabIds = rawApplicable != null
                        ? List<String>.from(rawApplicable as List)
                        : defaultApplicableTabs();
                    final rawOrder = configData['tabOrder'];
                    final tabOrder = normalizeTabOrder(
                        rawOrder != null ? List<String>.from(rawOrder as List) : null);

                    List<String> effectiveTabIds;
                    if (widget.isAdmin) {
                      effectiveTabIds = tabOrder
                          .where((id) => applicableTabIds.contains(id))
                          .toList();
                      if (effectiveTabIds.isEmpty) effectiveTabIds = ['overview'];
                    } else {
                      final rawResident = configData['residentTabs'];
                      final residentTabIds = rawResident != null
                          ? List<String>.from(rawResident as List)
                          : defaultResidentTabs();
                      effectiveTabIds = tabOrder
                          .where((id) =>
                              applicableTabIds.contains(id) && residentTabIds.contains(id))
                          .toList();
                      if (effectiveTabIds.isEmpty) {
                        effectiveTabIds = applicableTabIds.contains('event')
                            ? ['event']
                            : (applicableTabIds.isNotEmpty ? [applicableTabIds.first] : ['event']);
                      }
                    }
                    _ensureTabController(effectiveTabIds.length);
                    final tabController = _tabController;
                    if (tabController == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return Column(children: [
                      // ── Tab bar: grocery-style for admin, classic for resident ──
                      if (widget.isAdmin)
                        _CustomTabBar(
                          controller: tabController,
                          tabs: effectiveTabIds.map(_adminTabItemFor).toList(),
                        )
                      else
                        Container(
                          color: AppTheme.accent,
                          child: TabBar(
                            controller: tabController,
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            indicatorColor: Colors.white,
                            indicatorWeight: 3,
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.white60,
                            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            tabs: effectiveTabIds.map(_residentTabWidgetFor).toList(),
                          ),
                        ),

                      // Tab content
                      Expanded(
                        child: TabBarView(
                          controller: tabController,
                          children: effectiveTabIds
                              .map((id) => widget.isAdmin
                                  ? _adminTabViewFor(
                                      id,
                                      data: data,
                                      collected: collected,
                                      spent: spent,
                                      balance: balance,
                                      status: status,
                                    )
                                  : _residentTabViewFor(
                                      id,
                                      data: data,
                                      collected: collected,
                                      spent: spent,
                                      balance: balance,
                                      status: status,
                                    ))
                              .toList(),
                        ),
                      ),
                    ]);
                  },
                ),
              ),
            ],
          ),

          // Admin FABs — tab-aware. Resident payment entry lives in the header banner instead.
          floatingActionButton: widget.isAdmin && status == 'active'
              ? StreamBuilder<DocumentSnapshot>(
                  stream: eventType != null
                      ? FirebaseFirestore.instance
                          .collection('eventTypeConfig')
                          .doc(eventType.id)
                          .snapshots()
                      : const Stream<DocumentSnapshot>.empty(),
                  builder: (context, cfgSnap) {
                    final cfgData = cfgSnap.data?.data() as Map<String, dynamic>?;
                    final rawApplicable = cfgData?['applicableTabs'];
                    final applicableTabIds = rawApplicable != null
                        ? List<String>.from(rawApplicable as List)
                        : defaultApplicableTabs();
                    final rawOrder = cfgData?['tabOrder'];
                    final tabOrder = normalizeTabOrder(
                        rawOrder != null ? List<String>.from(rawOrder as List) : null);
                    var effectiveAdminTabIds = tabOrder
                        .where((id) => applicableTabIds.contains(id))
                        .toList();
                    if (effectiveAdminTabIds.isEmpty) effectiveAdminTabIds = ['overview'];

                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('appSettings')
                          .doc('payments')
                          .snapshots(),
                      builder: (context, paySnap) {
                        final payData = paySnap.data?.data() as Map<String, dynamic>? ?? {};
                        final enabledTypeIds = List<String>.from(payData['enabledTypeIds'] as List? ?? []);
                        final paymentsEnabled = enabledTypeIds.contains(eventType?.id ?? '');
                        final tabController = _tabController;
                        if (tabController == null) return const SizedBox.shrink();
                        return AnimatedBuilder(
                          animation: tabController,
                          builder: (context, _) {
                            final tab = tabController.index;
                            if (tab >= effectiveAdminTabIds.length) return const SizedBox.shrink();
                            final currentTabId = effectiveAdminTabIds[tab];
                            if (currentTabId == 'contributions' && paymentsEnabled) {
                              return FloatingActionButton.extended(
                                heroTag: 'contribution',
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddContributionScreen(
                                        eventId: widget.eventId,
                                        eventTypeId: data['eventTypeId'] as String? ?? ''),
                                  ),
                                ),
                                backgroundColor: Colors.green,
                                icon: const Icon(Icons.add, color: Colors.white),
                                label: const Text('Add Contribution',
                                    style: TextStyle(color: Colors.white)),
                              );
                            }
                            if (currentTabId == 'expenses') {
                              return FloatingActionButton.extended(
                                heroTag: 'expense',
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddExpenseScreen(
                                        eventId: widget.eventId,
                                        eventTypeId: data['eventTypeId'] as String? ?? ''),
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
                        );
                      },
                    );
                  },
                )
              : null,
        );
      },
    );
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      if (i > 0 && fromEnd % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ── Custom Tab Bar ────────────────────────────────────────────────────────────

class _TabItem {
  final IconData icon;
  final String label;
  final Color color;
  const _TabItem({required this.icon, required this.label, required this.color});
}

class _CustomTabBar extends StatefulWidget {
  final TabController controller;
  final List<_TabItem> tabs;
  const _CustomTabBar({required this.controller, required this.tabs});

  @override
  State<_CustomTabBar> createState() => _CustomTabBarState();
}

class _CustomTabBarState extends State<_CustomTabBar> {
  late List<GlobalKey> _tabKeys =
      List.generate(widget.tabs.length, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTabChange);
  }

  @override
  void didUpdateWidget(_CustomTabBar old) {
    super.didUpdateWidget(old);
    // The TabController instance can be swapped out (e.g. when the tab
    // count changes for an event type without full config yet) — without
    // re-subscribing, this bar keeps listening to the disposed controller
    // and its selected-tab highlight stops updating even though
    // TabBarView (on the new controller) still navigates correctly.
    if (!identical(old.controller, widget.controller)) {
      old.controller.removeListener(_onTabChange);
      widget.controller.addListener(_onTabChange);
    }
    if (old.tabs.length != widget.tabs.length) {
      _tabKeys = List.generate(widget.tabs.length, (_) => GlobalKey());
    }
  }

  void _onTabChange() {
    if (!mounted) return;
    setState(() {});
    _scrollToSelected();
  }

  void _scrollToSelected() {
    final key = _tabKeys[widget.controller.index];
    final ctx = key.currentContext;
    if (ctx == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    });
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
      color: Theme.of(context).cardColor,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: List.generate(widget.tabs.length, (i) {
            final tab = widget.tabs[i];
            final isSel = selected == i;
            return GestureDetector(
              key: _tabKeys[i],
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
                                ? tab.color.withValues(alpha: 0.14)
                                : tab.color.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: isSel
                                ? Border.all(color: tab.color.withValues(alpha: 0.4), width: 1.5)
                                : null,
                          ),
                          child: Icon(
                            tab.icon,
                            size: 22,
                            color: isSel ? tab.color : tab.color.withValues(alpha: 0.55),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                            color: isSel ? tab.color : Colors.grey.shade600,
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
                      color: tab.color,
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
  final String residentFlat;
  final String residentName;
  final String eventName;
  final String status;

  const _OverviewTab({
    required this.eventId,
    required this.collected,
    required this.spent,
    required this.balance,
    required this.data,
    this.isAdmin = false,
    this.residentFlat = '',
    this.residentName = '',
    this.eventName = 'Event',
    this.status = 'active',
  });

  String _fmt(double v) {
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
    final double target = (data['targetAmount'] as num?)?.toDouble() ?? 0.0;
    final double collectedPct = target > 0 ? ((collected / target).clamp(0.0, 1.0) as num).toDouble() : 0.0;
    final double spentPct     = target > 0 ? ((spent / target).clamp(0.0, 1.0) as num).toDouble() : 0.0;
    final isOverspent  = balance < 0;
    final resolvedType = eventTypeById(data['eventTypeId'] as String?) ??
        eventTypeByName(data['name'] as String?);

    return StreamBuilder<DocumentSnapshot>(
      stream: resolvedType != null
          ? FirebaseFirestore.instance
              .collection('eventTypeConfig')
              .doc(resolvedType.id)
              .snapshots()
          : const Stream<DocumentSnapshot>.empty(),
      builder: (context, configSnap) {
        final configData = configSnap.data?.data() as Map<String, dynamic>? ?? {};
        final rawChips = configData['overviewChips'];
        final enabledChips = rawChips != null
            ? List<String>.from(rawChips as List)
            : defaultOverviewChips();
        final rawSections = configData['residentOverviewSections'];
        final enabledSections = rawSections != null
            ? List<String>.from(rawSections as List)
            : defaultResidentOverviewSections();
        bool sectionVisible(String id) => isAdmin || enabledSections.contains(id);

        return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        // ── My Contribution (resident only, always shown) ────────────
        if (!isAdmin && residentFlat.isNotEmpty) ...[
          _MyContributionWidget(
            eventId: eventId,
            eventName: eventName,
            flatNumber: residentFlat,
            residentName: residentName,
            isEventActive: status == 'active',
          ),
          const SizedBox(height: 16),
        ],

        // ── Budget vs Actual Card ──────────────────────────────────
        if (sectionVisible('budget_vs_actual')) ...[
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
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

              // ── Carried forward out (to another event) ────────────
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('events')
                    .doc(eventId)
                    .collection('carryForwardTransfers')
                    .snapshots(),
                builder: (context, cfSnap) {
                  // Reversed transfers (destination-side contribution was
                  // deleted) no longer count — that balance is available
                  // again, so it shouldn't still show as "moved out".
                  final transfers = (cfSnap.data?.docs ?? []).where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return d['reversed'] != true;
                  }).toList();
                  if (transfers.isEmpty) return const SizedBox.shrink();
                  double total = 0;
                  final destNames = <String>{};
                  for (final doc in transfers) {
                    final d = doc.data() as Map<String, dynamic>;
                    total += (d['amount'] as num? ?? 0).toDouble();
                    final name = (d['destEventName'] as String?)?.trim() ?? '';
                    if (name.isNotEmpty) destNames.add(name);
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.move_up, color: Colors.blue.shade600, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Carried Forward Out',
                                    style: TextStyle(fontSize: 12, color: Colors.blue.shade600)),
                                Text('₹${_fmt(total)}',
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700)),
                                if (destNames.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text('Moved to: ${destNames.join(', ')}',
                                        style: TextStyle(fontSize: 12, color: Colors.blue.shade600)),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ],

        // ── Stat chips — visibility configurable per event type ─────
        if (sectionVisible('stat_chips')) ...[
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('events').doc(eventId)
              .collection('contributions').snapshots(),
          builder: (context, snap) {
            double cash = 0, online = 0, anonymous = 0, external = 0, carryForward = 0;
            for (final doc in snap.data?.docs ?? []) {
              final d = doc.data() as Map<String, dynamic>;
              if (d['status'] == 'deleted') continue;
              if (d['selfReported'] == true && d['amountReceived'] != true) continue;
              if (d['amountReceived'] != true) continue;
              final amt = (d['amount'] as num? ?? 0).toDouble();
              if (d['contributionType'] == kTypeCarryForward) {
                carryForward += amt;
                continue; // shown as its own chip, not in cash/online split
              }
              // Sponsorship is excluded from Cash/Online (and Collected) the
              // same way it's excluded from totalCollected — its amount is
              // often a nominal item value, not cash actually received.
              if (d['contributionType'] != kTypeSponsor) {
                final mode = (d['paymentMode'] as String? ?? '').toLowerCase();
                if (mode == 'cash') cash += amt; else online += amt;
              }
              // Anonymous takes priority — an anonymous external donation
              // counts only toward the Anonymous chip, not both.
              if (d['isAnonymous'] == true) {
                anonymous += amt;
              } else if (d['contributionType'] == kTypeExternal) {
                external += amt;
              }
            }
            final hasBoth = cash > 0 && online > 0 &&
                enabledChips.contains('cash') && enabledChips.contains('online');
            final rowsOnTop = <Widget>[];
            final rowsBottom = <Widget>[];
            if (hasBoth) {
              if (enabledChips.contains('cash')) {
                rowsOnTop.add(_StatChip(label: 'Cash', value: '₹${_fmt(cash)}',
                    icon: Icons.arrow_downward_rounded, color: Colors.amber.shade700));
              }
              if (enabledChips.contains('online')) {
                rowsOnTop.add(_StatChip(label: 'Online', value: '₹${_fmt(online)}',
                    icon: Icons.arrow_downward_rounded, color: Colors.blue));
              }
              if (enabledChips.contains('collected')) {
                rowsOnTop.add(_StatChip(label: 'Total', value: '₹${_fmt(collected)}',
                    icon: Icons.arrow_downward_rounded, color: Colors.green));
              }
              if (enabledChips.contains('spent')) {
                rowsBottom.add(_StatChip(label: 'Spent', value: '₹${_fmt(spent)}',
                    icon: Icons.arrow_upward_rounded, color: Colors.red));
              }
              if (enabledChips.contains('expected')) {
                rowsBottom.add(_StatChip(label: 'Expected',
                    value: target > 0 ? '₹${_fmt(target)}' : '—',
                    icon: Icons.flag_outlined, color: Colors.blue.shade800));
              }
              if (enabledChips.contains('balance')) {
                rowsBottom.add(_StatChip(label: 'Balance',
                    value: '₹${_fmt(balance.abs())}',
                    icon: balance >= 0
                        ? Icons.account_balance_wallet
                        : Icons.warning_rounded,
                    color: balance >= 0 ? Colors.teal : Colors.red));
              }
            } else {
              if (enabledChips.contains('collected')) {
                rowsOnTop.add(_StatChip(label: 'Collected', value: '₹${_fmt(collected)}',
                    icon: Icons.arrow_downward_rounded, color: Colors.green));
              }
              if (enabledChips.contains('spent')) {
                rowsOnTop.add(_StatChip(label: 'Spent', value: '₹${_fmt(spent)}',
                    icon: Icons.arrow_upward_rounded, color: Colors.red));
              }
              if (enabledChips.contains('expected')) {
                rowsOnTop.add(_StatChip(label: 'Expected',
                    value: target > 0 ? '₹${_fmt(target)}' : '—',
                    icon: Icons.flag_outlined, color: Colors.blue));
              }
              if (enabledChips.contains('balance')) {
                rowsBottom.add(_StatChip(label: 'Balance',
                    value: '₹${_fmt(balance.abs())}',
                    icon: balance >= 0
                        ? Icons.account_balance_wallet
                        : Icons.warning_rounded,
                    color: balance >= 0 ? Colors.teal : Colors.red));
              }
            }

            Widget spaced(List<Widget> chips) => Row(
                  children: chips
                      .expand((c) => [c, const SizedBox(width: 8)])
                      .toList()
                    ..removeLast(),
                );

            return Column(
              children: [
                if (rowsOnTop.isNotEmpty) spaced(rowsOnTop),
                if (rowsBottom.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  spaced(rowsBottom),
                ],
                if ((anonymous > 0 && enabledChips.contains('anonymous')) ||
                    (external > 0 && enabledChips.contains('external')) ||
                    carryForward > 0) ...[
                  const SizedBox(height: 16),
                  _AnonymousExternalCard(
                    anonymous: anonymous,
                    external: external,
                    showAnonymous: enabledChips.contains('anonymous'),
                    showExternal: enabledChips.contains('external'),
                    carryForward: carryForward,
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        ],

        // ── Special vs Regular contribution breakdown (admin only) ──────────
        if (isAdmin) ...[
          _SpecialContributionsWidget(eventId: eventId),
          const SizedBox(height: 16),
        ],

        // ── Block stats (grouped by wing) — live stream, gated by settings ──
        if (sectionVisible('block_stats'))
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('appSettings')
              .doc('collectionStatusByBlock')
              .snapshots(),
          builder: (context, snap) {
            final d = snap.data?.data() as Map<String, dynamic>? ?? {};
            final enabledTypeIds = List<String>.from(d['enabledTypeIds'] as List? ?? []);
            if (!enabledTypeIds.contains(resolvedType?.id ?? '')) return const SizedBox.shrink();
            return Column(children: [
              const SizedBox(height: 16),
              _BlockStatsWidget(eventId: eventId, isAdmin: isAdmin),
            ]);
          },
        ),

        // ── Our Sponsors — live stream, gated by settings ──────────────────
        if (sectionVisible('sponsors'))
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('appSettings')
              .doc('sponsorPackages')
              .snapshots(),
          builder: (context, snap) {
            final d = snap.data?.data() as Map<String, dynamic>? ?? {};
            final enabledTypeIds = List<String>.from(d['enabledTypeIds'] as List? ?? []);
            if (!enabledTypeIds.contains(resolvedType?.id ?? '')) return const SizedBox.shrink();
            return Column(children: [
              const SizedBox(height: 16),
              _SponsorsWidget(eventId: eventId),
            ]);
          },
        ),

        const SizedBox(height: 24),
      ],
        );
      },
    );
  }

  static String _fmtAmt(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      if (i > 0 && fromEnd % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

}

// ── Special vs Regular Contributions Widget (admin) ───────────────────────────

// ── My Contribution Widget (resident) ─────────────────────────────────────────
// Summary stat shown at the top of the resident Overview tab. Tapping opens a
// sheet listing every contribution this flat made to the event, with the
// ability to edit or delete entries that haven't been approved by admin yet
// (once approved, the record is locked — matches admin-side accounting needs).

class _MyContributionWidget extends StatelessWidget {
  final String eventId;
  final String eventName;
  final String flatNumber;
  final String residentName;
  final bool isEventActive;

  const _MyContributionWidget({
    required this.eventId,
    required this.eventName,
    required this.flatNumber,
    required this.residentName,
    required this.isEventActive,
  });

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

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (ctx, ctrl) => _MyContributionSheet(
          eventId: eventId,
          eventName: eventName,
          flatNumber: flatNumber,
          residentName: residentName,
          isEventActive: isEventActive,
          scrollController: ctrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('contributions')
          .where('flatNumber', isEqualTo: flatNumber)
          .snapshots(),
      builder: (context, snap) {
        final docs = (snap.data?.docs ?? [])
            .where((d) => (d.data() as Map<String, dynamic>)['status'] != 'deleted')
            .toList();
        double confirmed = 0;
        double pending = 0;
        bool hasRejected = false;
        String rejectReason = '';
        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final amt = (d['amount'] as num?)?.toDouble() ?? 0;
          if (d['amountReceived'] == true) {
            confirmed += amt;
          } else if (d['status'] == 'rejected') {
            hasRejected = true;
            rejectReason = (d['rejectionReason'] as String?)?.trim() ?? '';
          } else {
            pending += amt;
          }
        }

        final subtitleParts = <String>[
          if (pending > 0) '₹${_fmt(pending)} pending review',
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prominent rejection notice — easy to miss as just a small badge.
            if (hasRejected)
              GestureDetector(
                onTap: () => _showDetail(context),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300, width: 1.5),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('⚠️ A contribution was rejected',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade800,
                                  fontSize: 13)),
                          Text(
                              rejectReason.isNotEmpty
                                  ? 'Reason: $rejectReason — tap to view & resubmit'
                                  : 'Tap to view details & resubmit',
                              style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.red.shade400),
                  ]),
                ),
              ),
            GestureDetector(
              onTap: () => _showDetail(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.accent.shade600, AppTheme.accent.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.volunteer_activism_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('My Contribution',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                          Text('₹${_fmt(confirmed)}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          if (subtitleParts.isNotEmpty)
                            Text(subtitleParts.join(' · '),
                                style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MyContributionSheet extends StatelessWidget {
  final String eventId;
  final String eventName;
  final String flatNumber;
  final String residentName;
  final bool isEventActive;
  final ScrollController scrollController;

  const _MyContributionSheet({
    required this.eventId,
    required this.eventName,
    required this.flatNumber,
    required this.residentName,
    required this.isEventActive,
    required this.scrollController,
  });

  Future<void> _deleteMine(BuildContext context, DocumentReference ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Contribution'),
        content: const Text(
            'Remove this pending contribution? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.delete();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contribution deleted')));
    }
  }

  void _editMine(BuildContext context, QueryDocumentSnapshot doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SelfReportSheet(
        eventId: eventId,
        eventName: eventName,
        flatNumber: flatNumber,
        residentName: residentName,
        existingDoc: doc,
        onSubmitted: () {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 10),
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            Icon(Icons.volunteer_activism_rounded, color: AppTheme.accent.shade400, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('My Contributions — $eventName',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('events')
                .doc(eventId)
                .collection('contributions')
                .where('flatNumber', isEqualTo: flatNumber)
                .snapshots(),
            builder: (context, snap) {
              final docs = (snap.data?.docs ?? [])
                  .where((d) => (d.data() as Map<String, dynamic>)['status'] != 'deleted')
                  .toList()
                ..sort((a, b) {
                  final aT = (a.data() as Map<String, dynamic>)['paidAt'] as String? ?? '';
                  final bT = (b.data() as Map<String, dynamic>)['paidAt'] as String? ?? '';
                  return bT.compareTo(aT);
                });

              if (docs.isEmpty) {
                return Center(
                  child: Text('No contributions yet.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                );
              }

              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(12),
                children: docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final amt = (d['amount'] as num?)?.toDouble() ?? 0;
                  final mode = d['paymentMode'] ?? '';
                  final date = d['paidDate'] ?? '';
                  final isConfirmed = d['amountReceived'] == true;
                  final isRejected = d['status'] == 'rejected';
                  final isPending = !isConfirmed && !isRejected;
                  final reason = (d['rejectionReason'] ?? '').toString().trim();
                  final type = (d['contributionType'] as String?) ?? 'Regular Contribution';
                  final isSpecial = type != 'Regular Contribution' && type != 'Regular';

                  Color bg, border, textCol;
                  String label;
                  IconData icon;
                  if (isConfirmed) {
                    bg = Colors.green.shade50; border = Colors.green.shade200;
                    textCol = Colors.green.shade700; label = 'Confirmed';
                    icon = Icons.check_circle_rounded;
                  } else if (isRejected) {
                    bg = Colors.red.shade50; border = Colors.red.shade200;
                    textCol = Colors.red.shade700; label = 'Rejected';
                    icon = Icons.cancel_rounded;
                  } else {
                    bg = Colors.orange.shade50; border = Colors.orange.shade200;
                    textCol = Colors.orange.shade700; label = 'Pending';
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(
                                  '₹${amt.toStringAsFixed(0)}  ·  $mode${date.isNotEmpty ? '  ·  $date' : ''}',
                                  style: TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w600, color: textCol),
                                ),
                                if (isSpecial) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('Special',
                                        style: TextStyle(
                                            fontSize: 9, fontWeight: FontWeight.bold, color: Colors.purple.shade700)),
                                  ),
                                ],
                              ]),
                              if (isRejected && reason.isNotEmpty)
                                Text('Reason: $reason',
                                    style: TextStyle(fontSize: 11, color: Colors.red.shade500)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: textCol.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(label,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textCol)),
                        ),
                        // Edit/Delete — only while pending (not yet approved) on active events
                        if (isPending && isEventActive) ...[
                          const SizedBox(width: 2),
                          IconButton(
                            icon: Icon(Icons.edit_outlined, color: Colors.blue.shade400, size: 17),
                            onPressed: () => _editMine(context, doc),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.red.shade300, size: 17),
                            onPressed: () => _deleteMine(context, doc.reference),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Delete',
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Anonymous & External Contributions card — styled like the Regular vs
// Special breakdown card below it, for a consistent Overview tab look ────────

class _AnonymousExternalCard extends StatelessWidget {
  final double anonymous;
  final double external;
  final bool showAnonymous;
  final bool showExternal;
  final double carryForward;
  const _AnonymousExternalCard({
    required this.anonymous,
    required this.external,
    required this.showAnonymous,
    required this.showExternal,
    this.carryForward = 0,
  });

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
    final hasAnonymous = showAnonymous && anonymous > 0;
    final hasExternal = showExternal && external > 0;
    final hasCarryForward = carryForward > 0;
    if (!hasAnonymous && !hasExternal && !hasCarryForward) return const SizedBox();

    final presentCount =
        [hasAnonymous, hasExternal, hasCarryForward].where((v) => v).length;
    final title = presentCount > 1
        ? 'Other Contributions'
        : hasAnonymous
            ? 'Anonymous Contributions'
            : hasExternal
                ? 'External Contributions'
                : 'Carried Forward';

    final chips = <Widget>[
      if (hasAnonymous)
        _StatChip(label: 'Anonymous', value: '₹${_fmt(anonymous)}',
            icon: Icons.visibility_off_outlined, color: Colors.indigo),
      if (hasExternal)
        _StatChip(label: 'External', value: '₹${_fmt(external)}',
            icon: Icons.corporate_fare_outlined, color: Colors.teal.shade700),
      if (hasCarryForward)
        _StatChip(label: 'Carried Forward', value: '₹${_fmt(carryForward)}',
            icon: Icons.move_up, color: Colors.blue),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 2),
          Text(
              'A breakdown of your Collected total above — not additional money on top of it.',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade400, height: 1.3)),
          const SizedBox(height: 12),
          Row(
            children: chips
                .expand((c) => [c, const SizedBox(width: 8)])
                .toList()
              ..removeLast(),
          ),
        ],
      ),
    );
  }
}

// ── Sponsor Highlight — visible to everyone (admin + residents), publicly
// celebrates sponsors so the community can see and appreciate them.
class _SponsorHighlightCard extends StatelessWidget {
  final String eventId;
  const _SponsorHighlightCard({required this.eventId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('contributions')
          .snapshots(),
      builder: (context, snap) {
        final sponsors = (snap.data?.docs ?? []).where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return d['contributionType'] == kTypeSponsor &&
              d['status'] != 'deleted' &&
              d['amountReceived'] == true;
        }).toList();
        if (sponsors.isEmpty) return const SizedBox.shrink();

        sponsors.sort((a, b) {
          final da = (a.data() as Map<String, dynamic>)['amount'] as num? ?? 0;
          final db = (b.data() as Map<String, dynamic>)['amount'] as num? ?? 0;
          return db.compareTo(da);
        });

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.amber.shade50, Colors.orange.shade50],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.shade200, width: 1.2),
              boxShadow: [
                BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.emoji_events, color: Colors.amber.shade800, size: 22),
                    const SizedBox(width: 8),
                    Text('Thank You to Our Sponsors!',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Colors.amber.shade900)),
                  ],
                ),
                const SizedBox(height: 12),
                ...sponsors.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final tier = (d['sponsorPackageName'] as String? ?? '').trim();
                  final item = (d['sponsorItem'] as String? ?? '').trim();
                  final isAnon = d['isAnonymous'] == true;
                  final name = (d['residentName'] as String? ?? '').trim();
                  final who = isAnon
                      ? 'A generous resident'
                      : (name.isNotEmpty ? name : 'A sponsor');
                  final descParts = [
                    if (item.isNotEmpty) item,
                    if (tier.isNotEmpty) tier,
                  ];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.star_rounded,
                              color: Colors.amber.shade800, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                        text: who,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Colors.amber.shade900)),
                                    if (descParts.isNotEmpty)
                                      TextSpan(
                                          text: ' sponsored ${descParts.join(' · ')}',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade800))
                                    else
                                      TextSpan(
                                          text: ' sponsored this event',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade800)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SpecialContributionsWidget extends StatelessWidget {
  final String eventId;
  const _SpecialContributionsWidget({required this.eventId});

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
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('contributions')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();

        double regularTotal = 0;
        double specialTotal = 0;
        final specialEntries = <Map<String, dynamic>>[];

        for (final doc in snap.data!.docs) {
          final d = doc.data() as Map<String, dynamic>;
          if (d['amountReceived'] != true ||
              d['status'] == 'rejected' ||
              d['status'] == 'deleted') continue;
          final amt = (d['amount'] as num?)?.toDouble() ?? 0;
          final type = (d['contributionType'] as String?) ?? 'Regular Contribution';
          // External and Carry Forward are shown as their own dedicated
          // chips elsewhere in Overview, not as part of this Regular vs
          // Special breakdown.
          if (type == kTypeExternal || type == kTypeCarryForward) continue;
          final isSpecial = type != 'Regular Contribution' && type != 'Regular' && type != kTypeSponsor;
          if (isSpecial) {
            specialTotal += amt;
            specialEntries.add({
              'flat': d['flatNumber'] ?? '',
              'name': d['residentName'] ?? '',
              'amt': amt,
              'desc': d['specialDescription'] ?? '',
              'isAnonymous': d['isAnonymous'] == true,
            });
          } else if (type != kTypeSponsor) {
            regularTotal += amt;
          }
        }

        if (regularTotal <= 0 && specialTotal <= 0) return const SizedBox();

        specialEntries.sort((a, b) => (b['amt'] as double).compareTo(a['amt'] as double));

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Regular & Special Contributions',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 12),
              Row(children: [
                _StatChip(label: 'Regular', value: '₹${_fmt(regularTotal)}',
                    icon: Icons.payments_outlined, color: Colors.green),
                const SizedBox(width: 8),
                _StatChip(label: 'Special', value: '₹${_fmt(specialTotal)}',
                    icon: Icons.star_outline, color: Colors.purple),
              ]),
              if (specialEntries.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Text('Special Contributions by Flat',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                const SizedBox(height: 8),
                ...specialEntries.map((e) {
                  final isAnon = e['isAnonymous'] == true;
                  final name = isAnon ? 'Anonymous' : (e['name'] as String);
                  final desc = (e['desc'] as String).trim();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.star, size: 14, color: Colors.purple.shade300),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Flat ${e['flat']}${name.isNotEmpty ? '  ·  $name' : ''}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              if (desc.isNotEmpty)
                                Text(desc,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                        Text('₹${_fmt(e['amt'] as double)}',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold, color: Colors.purple.shade700)),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── External Donations Widget (admin-only) — donations recorded from
// non-resident external sources (broadband, builders, store operators, etc.) ──

class _ExternalDonationsWidget extends StatelessWidget {
  final String eventId;
  final List<QueryDocumentSnapshot> docs;
  const _ExternalDonationsWidget({required this.eventId, required this.docs});

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
        double total = 0, cashTotal = 0, onlineTotal = 0;
        final entries = <Map<String, dynamic>>[];

        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          if (d['amountReceived'] != true ||
              d['status'] == 'rejected' ||
              d['status'] == 'deleted') continue;
          if (d['contributionType'] != kTypeExternal) continue;
          // Anonymous takes precedence — shown only in the Anonymous
          // section, not double-listed here too.
          if (d['isAnonymous'] == true) continue;
          final amt = (d['amount'] as num?)?.toDouble() ?? 0;
          total += amt;
          final mode = (d['paymentMode'] as String? ?? '').toLowerCase();
          if (mode == 'cash') {
            cashTotal += amt;
          } else {
            onlineTotal += amt;
          }
          entries.add({
            'doc': doc,
            'data': d,
            'name': d['residentName'] ?? '',
            'amt': amt,
            'note': d['note'] ?? '',
          });
        }

        if (entries.isEmpty) return const SizedBox.shrink();

        entries.sort((a, b) => (b['amt'] as double).compareTo(a['amt'] as double));

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.shade100),
          ),
          child: ExpansionTile(
            initiallyExpanded: false,
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.teal.shade50,
              child: Icon(Icons.corporate_fare_outlined,
                  color: Colors.teal.shade600, size: 18),
            ),
            title: const Text('External Donations',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
                '${entries.length} donor${entries.length == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${_fmt(total)}',
                        style: TextStyle(
                            color: Colors.teal.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    if (cashTotal > 0 && onlineTotal > 0)
                      Text('C:${_fmt(cashTotal)} · O:${_fmt(onlineTotal)}',
                          style: TextStyle(fontSize: 9, color: Colors.blue.shade600))
                    else if (cashTotal > 0)
                      Text('Cash',
                          style: TextStyle(fontSize: 9, color: Colors.amber.shade800))
                    else if (onlineTotal > 0)
                      Text('Online',
                          style: TextStyle(fontSize: 9, color: Colors.blue.shade600)),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: entries.map((e) {
                final name = (e['name'] as String).trim();
                final note = (e['note'] as String).trim();
                final doc = e['doc'] as QueryDocumentSnapshot;
                final data = e['data'] as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.corporate_fare, size: 14, color: Colors.teal.shade300),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name.isEmpty ? 'External Donor' : name,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            if (note.isNotEmpty)
                              Text(note,
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                      Text('₹${_fmt(e['amt'] as double)}',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
                      IconButton(
                        icon: Icon(Icons.edit_outlined, color: Colors.green.shade400, size: 16),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddContributionScreen(
                              eventId: eventId,
                              existingDocId: doc.id,
                              existingData: data,
                            ),
                          ),
                        ),
                        tooltip: 'Edit',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red.shade300, size: 16),
                        onPressed: () => _ContributionsTabState._deleteContribution(context, doc, data),
                        tooltip: 'Delete',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
  }
}

// ── Block Stats Widget — live StreamBuilder ───────────────────────────────────

class _BlockStatsWidget extends StatefulWidget {
  final String eventId;
  final bool isAdmin;
  const _BlockStatsWidget({required this.eventId, this.isAdmin = false});
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
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      if (i > 0 && fromEnd % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  void _showBlockDetail(
    BuildContext context,
    String wing,
    String block,
    List<String> flats,
    Set<String> paidFlats,
    Map<String, double> flatAmount,
    Map<String, String> flatName,
  ) {
    // Same exact/suffix matching used for the paid counts above. Flat
    // numbers are matched case-insensitively so "ra302" and "RA302" are
    // treated as the same flat regardless of how each was entered.
    String? _matchedPaidFlat(String f) {
      final fUpper = f.toUpperCase();
      if (paidFlats.contains(fUpper)) return fUpper;
      final match = paidFlats.firstWhere(
          (p) => fUpper.endsWith(p) || p.endsWith(fUpper), orElse: () => '');
      return match.isEmpty ? null : match;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (ctx, ctrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(children: [
                Icon(Icons.domain_outlined, color: Colors.indigo.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('$wing → Block $block',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                padding: const EdgeInsets.all(12),
                itemCount: flats.length,
                itemBuilder: (_, i) {
                  final flat = flats[i];
                  final matched = _matchedPaidFlat(flat);
                  final paid = matched != null;
                  final amt = matched != null ? (flatAmount[matched] ?? 0) : 0;
                  final name = matched != null ? (flatName[matched] ?? '') : '';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: paid ? Colors.green.shade50 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: paid ? Colors.green.shade200 : Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          paid ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                          size: 18,
                          color: paid ? Colors.green.shade600 : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Flat $flat',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Colors.grey.shade800)),
                              if (name.isNotEmpty)
                                Text(name,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                        Text(
                          paid ? '₹${_fmt(amt.toDouble())}' : 'Pending',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: paid ? Colors.green.shade700 : Colors.grey.shade500),
                        ),
                      ],
                    ),
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
        final flatName = <String, String>{};
        for (final doc in contribDocs) {
          final d = doc.data() as Map<String, dynamic>;
          if (d['amountReceived'] == true &&
              d['status'] != 'rejected' &&
              d['status'] != 'deleted') {
            final f = (d['flatNumber'] ?? '').toString().trim().toUpperCase();
            final amt = (d['amount'] as num?)?.toDouble() ?? 0;
            if (f.isNotEmpty) {
              paidFlats.add(f);
              flatAmount[f] = (flatAmount[f] ?? 0) + amt;
              final name = (d['residentName'] ?? '').toString().trim();
              if (name.isNotEmpty && d['isAnonymous'] != true) flatName[f] = name;
            }
          }
        }

        // For each wing/block in community structure, count paid flats and
        // sum amounts using the flat list as the source of truth.
        final wings = _wings.isNotEmpty ? _wings : (wingBlocks.keys.toList()..sort());
        final byWing = <String, ({double collected, List<({String block, int total, int paid, List<String> flats})> blocks})>{};
        for (final wing in wings) {
          final blocks = Map<String, dynamic>.from(wingBlocks[wing] as Map? ?? {});
          if (blocks.isEmpty) continue;
          final sortedBlocks = blocks.keys.toList()..sort();
          final blockList = <({String block, int total, int paid, List<String> flats})>[];
          double wingAmt = 0;
          for (final block in sortedBlocks) {
            final flats = List<String>.from((blocks[block] as List?) ?? []);
            if (flats.isEmpty) continue;
            // Match paid flats: exact first, then suffix (for short flat
            // numbers). Case-insensitive so "ra302" and "RA302" match.
            int paid = 0;
            for (final rawF in flats) {
              final f = rawF.toUpperCase();
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
            blockList.add((block: block, total: flats.length, paid: paid, flats: flats));
          }
          if (blockList.isNotEmpty) {
            byWing[wing] = (
              collected: wingAmt,
              blocks: blockList,
            );
          }
        }

        if (byWing.isEmpty) return const SizedBox();

        int totalPaid = 0;
        int totalFlats = 0;
        for (final entry in byWing.values) {
          for (final block in entry.blocks) {
            totalPaid += block.paid;
            totalFlats += block.total;
          }
        }

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
            const SizedBox(height: 2),
            Text(
                'Only flats configured under Wings & Blocks — anonymous, external, '
                'or unlisted-flat contributions are already counted in the totals '
                'above but won\'t appear here.',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400, height: 1.3)),
            const SizedBox(height: 6),
            Text('$totalPaid of $totalFlats residents contributed',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700)),
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
                        return GestureDetector(
                          onTap: widget.isAdmin
                              ? () => _showBlockDetail(context, wing, s.block,
                                  s.flats, paidFlats, flatAmount, flatName)
                              : null,
                          child: Container(
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

// ── Leaderboard Widget — top contributors by flat, respecting anonymity ──────
// Anonymous contributions are excluded from the ranked (identified) list and
// summed separately as a single unranked footnote — this avoids leaking a
// flat number (which residents can usually match to a household) alongside
// an "anonymous" amount, which would defeat the point of anonymity.

class _LeaderboardWidget extends StatelessWidget {
  final String eventId;
  const _LeaderboardWidget({required this.eventId});

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
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('contributions')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();

        final flatTotals = <String, double>{};
        final flatNames = <String, String>{};
        double anonymousTotal = 0;
        int anonymousCount = 0;

        for (final doc in snap.data!.docs) {
          final d = doc.data() as Map<String, dynamic>;
          if (d['amountReceived'] != true ||
              d['status'] == 'rejected' ||
              d['status'] == 'deleted') continue;
          final amt = (d['amount'] as num?)?.toDouble() ?? 0;
          if (amt <= 0) continue;
          if (d['isAnonymous'] == true) {
            anonymousTotal += amt;
            anonymousCount++;
            continue;
          }
          final flat = (d['flatNumber'] ?? '').toString().trim();
          if (flat.isEmpty) continue;
          flatTotals[flat] = (flatTotals[flat] ?? 0) + amt;
          final name = (d['residentName'] ?? '').toString().trim();
          if (name.isNotEmpty) flatNames[flat] = name;
        }

        if (flatTotals.isEmpty && anonymousTotal <= 0) return const SizedBox();

        final ranked = flatTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top = ranked.take(10).toList();

        const medalColors = [Color(0xFFFFD700), Color(0xFFC0C0C0), Color(0xFFCD7F32)];

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('🏆', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                const Text('Top Contributors',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ]),
              const SizedBox(height: 12),
              ...top.asMap().entries.map((entry) {
                final rank = entry.key;
                final flat = entry.value.key;
                final amount = entry.value.value;
                final name = flatNames[flat] ?? '';
                final isMedal = rank < 3;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isMedal
                              ? medalColors[rank].withValues(alpha: 0.18)
                              : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          isMedal ? ['🥇', '🥈', '🥉'][rank] : '${rank + 1}',
                          style: TextStyle(
                              fontSize: isMedal ? 13 : 12,
                              fontWeight: FontWeight.bold,
                              color: isMedal ? null : Colors.grey.shade600),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          [
                            'Flat $flat',
                            if (name.isNotEmpty) name,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: rank == 0 ? FontWeight.bold : FontWeight.w600),
                        ),
                      ),
                      Text('₹${_fmt(amount)}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                );
              }),
              if (anonymousTotal > 0) ...[
                const Divider(height: 20),
                Row(children: [
                  Icon(Icons.visibility_off_outlined, size: 15, color: Colors.indigo.shade400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        '$anonymousCount anonymous contribution${anonymousCount == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ),
                  Text('₹${_fmt(anonymousTotal)}',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold, color: Colors.indigo.shade400)),
                ]),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Leaderboard Tab — full leaderboard visible to admin & residents ──────────
// Combines: Top Contributors (reuses _LeaderboardWidget), Most Active
// Volunteers (derived from completed tasks), Quiz Winners (placeholder — no
// quiz feature yet), Competition Winners (derived from competitions
// subcollection), and Apartment Participation (per-wing paid-flat %).

class _LeaderboardTab extends StatefulWidget {
  final String eventId;
  final bool isAdmin;
  final String eventTypeId;
  const _LeaderboardTab({
    required this.eventId,
    this.isAdmin = true,
    this.eventTypeId = '',
  });

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab> {
  Map<String, dynamic> _wingBlocks = {};
  List<String> _wings = [];

  @override
  void initState() {
    super.initState();
    _fetchWingBlocks();
  }

  Future<void> _fetchWingBlocks() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('community_settings')
          .doc('address')
          .get();
      if (!mounted) return;
      final data = doc.data() as Map<String, dynamic>? ?? {};
      setState(() {
        _wingBlocks = Map<String, dynamic>.from(data['wingBlocks'] as Map? ?? {});
        _wings = List<String>.from(
            data['wings'] as List? ?? (_wingBlocks.keys.toList()..sort()));
      });
    } catch (_) {}
  }

  Widget _sectionCard({required String emoji, required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<DocumentSnapshot>(
        stream: !widget.isAdmin && widget.eventTypeId.isNotEmpty
            ? FirebaseFirestore.instance
                .collection('eventTypeConfig')
                .doc(widget.eventTypeId)
                .snapshots()
            : const Stream<DocumentSnapshot>.empty(),
        builder: (context, configSnap) {
          final configData = configSnap.data?.data() as Map<String, dynamic>?;
          final enabledSections = residentTabSectionsFor(configData, 'leaderboard');
          bool sectionVisible(String id) => widget.isAdmin || enabledSections.contains(id);

          return ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
        children: [
          if (sectionVisible('main_leaderboard')) ...[
          _LeaderboardWidget(eventId: widget.eventId),
          const SizedBox(height: 14),
          ],
          if (sectionVisible('most_active_volunteers'))
          _sectionCard(
            emoji: '🙋',
            title: 'Most Active Volunteers',
            child: _MostActiveVolunteers(eventId: widget.eventId),
          ),
          if (widget.isAdmin)
          _sectionCard(
            emoji: '🧠',
            title: 'Quiz Winners',
            child: Text('Quiz feature coming soon.',
                style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 13, fontStyle: FontStyle.italic)),
          ),
          if (sectionVisible('competition_winners'))
          _sectionCard(
            emoji: '🏆',
            title: 'Competition Winners',
            child: _CompetitionWinnersList(eventId: widget.eventId),
          ),
          if (sectionVisible('apartment_participation'))
          _sectionCard(
            emoji: '🏘️',
            title: 'Apartment Participation',
            child: _ApartmentParticipation(
                eventId: widget.eventId, wingBlocks: _wingBlocks, wings: _wings),
          ),
        ],
          );
        },
      ),
    );
  }
}

class _MostActiveVolunteers extends StatelessWidget {
  final String eventId;
  const _MostActiveVolunteers({required this.eventId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('tasks')
          .where('status', isEqualTo: kTaskStatusDone)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
              height: 20, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final counts = <String, int>{};
        final flats = <String, String>{};
        for (final doc in snap.data!.docs) {
          final d = doc.data() as Map<String, dynamic>;
          final assignees = (d['assignees'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          for (final a in assignees) {
            final name = (a['name'] ?? '').toString().trim();
            if (name.isEmpty) continue;
            counts[name] = (counts[name] ?? 0) + 1;
            final flat = (a['flat'] ?? '').toString().trim();
            if (flat.isNotEmpty) flats[name] = flat;
          }
        }
        if (counts.isEmpty) {
          return Text('No completed tasks yet.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13));
        }
        final ranked = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final top = ranked.take(5).toList();
        return Column(
          children: top.asMap().entries.map((e) {
            final rank = e.key;
            final name = e.value.key;
            final count = e.value.value;
            final flat = flats[name] ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Text('${rank + 1}.',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text([name, if (flat.isNotEmpty) flat].join(' · '),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                Text('$count task${count == 1 ? '' : 's'}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.teal.shade700, fontWeight: FontWeight.bold)),
              ]),
            );
          }).toList(),
        );
      },
    );
  }
}

class _CompetitionWinnersList extends StatelessWidget {
  final String eventId;
  const _CompetitionWinnersList({required this.eventId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('competitions')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
              height: 20, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final declared = snap.data!.docs.where((d) {
          final winners = (d.data() as Map<String, dynamic>)['winners'] as Map? ?? {};
          return winners['first'] != null;
        }).toList();
        if (declared.isEmpty) {
          return Text('No competition winners announced yet.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13));
        }
        return Column(
          children: declared.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final name = d['name'] as String? ?? '';
            final winners = Map<String, dynamic>.from(d['winners'] as Map);
            final first = Map<String, dynamic>.from(winners['first'] as Map);
            final flat = (first['flat'] ?? '').toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                const Text('🥇', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        '$name — ${first['name']}${flat.isNotEmpty ? ' ($flat)' : ''}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              ]),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ApartmentParticipation extends StatelessWidget {
  final String eventId;
  final Map<String, dynamic> wingBlocks;
  final List<String> wings;
  const _ApartmentParticipation(
      {required this.eventId, required this.wingBlocks, required this.wings});

  @override
  Widget build(BuildContext context) {
    if (wingBlocks.isEmpty) {
      return Text('Wing/block data not configured yet.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('contributions')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
              height: 20, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }

        final paidFlatsByWing = <String, Set<String>>{};
        for (final doc in snap.data!.docs) {
          final d = doc.data() as Map<String, dynamic>;
          if (d['amountReceived'] != true ||
              d['status'] == 'rejected' ||
              d['status'] == 'deleted') continue;
          final wing = (d['wing'] ?? '').toString().trim().toUpperCase();
          final flat = (d['flatNumber'] ?? '').toString().trim();
          if (wing.isEmpty || flat.isEmpty) continue;
          paidFlatsByWing.putIfAbsent(wing, () => {}).add(flat);
        }

        final rows = <MapEntry<String, double>>[];
        for (final wing in wings) {
          final blocks = Map<String, dynamic>.from(wingBlocks[wing] as Map? ?? {});
          int totalFlats = 0;
          for (final list in blocks.values) {
            totalFlats += (list as List? ?? []).length;
          }
          if (totalFlats == 0) continue;
          final paid = paidFlatsByWing[wing.toUpperCase()]?.length ?? 0;
          rows.add(MapEntry(wing, (paid / totalFlats * 100).clamp(0, 100)));
        }
        rows.sort((a, b) => b.value.compareTo(a.value));

        if (rows.isEmpty) {
          return Text('No participation data yet.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13));
        }

        return Column(
          children: rows.map((r) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(r.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${r.value.toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                        value: r.value / 100,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: const AlwaysStoppedAnimation(Colors.indigo)),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Sponsors Widget — "Our Sponsors" recognition wall ─────────────────────────
// Sponsors are shown publicly by name/tier (that's the point of sponsorship —
// unlike regular contributions, which stay private between resident and
// admin). isAnonymous is still respected for sponsors who explicitly asked
// not to be named.

class _SponsorsWidget extends StatelessWidget {
  final String eventId;
  const _SponsorsWidget({required this.eventId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('contributions')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();

        final sponsors = snap.data!.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .where((d) =>
                d['contributionType'] == kTypeSponsor &&
                d['amountReceived'] == true &&
                d['status'] != 'rejected' &&
                d['status'] != 'deleted')
            .toList()
          ..sort((a, b) =>
              ((b['amount'] as num?)?.toDouble() ?? 0)
                  .compareTo((a['amount'] as num?)?.toDouble() ?? 0));

        if (sponsors.isEmpty) return const SizedBox();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('🎖️', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                const Text('Our Sponsors',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ]),
              const SizedBox(height: 12),
              ...sponsors.map((d) {
                final tier = (d['sponsorPackageName'] as String? ?? '').trim();
                final isAnon = d['isAnonymous'] == true;
                final name = isAnon
                    ? 'Anonymous Sponsor'
                    : ((d['residentName'] as String?)?.trim().isNotEmpty == true
                        ? d['residentName'] as String
                        : 'Sponsor');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.workspace_premium_outlined,
                          size: 16, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      if (tier.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(tier,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber.shade800)),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
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
  final String residentFlat;
  final String residentName;
  final String residentWing;
  final String residentBlock;
  const _EventTab({
    required this.eventId,
    required this.data,
    required this.isAdmin,
    this.residentFlat = '',
    this.residentName = '',
    this.residentWing = '',
    this.residentBlock = '',
  });
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
                  leading: Icon(Icons.calendar_today, color: AppTheme.accent),
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
                      borderSide: BorderSide(color: AppTheme.accent, width: 2),
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
                      borderSide: BorderSide(color: AppTheme.accent, width: 2),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
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
    // Resolve robustly (falls back to name-matching for legacy events with a
    // missing/stale eventTypeId) rather than trusting the raw stored fields.
    final resolvedType = eventTypeById(data['eventTypeId'] as String?) ??
        eventTypeByName(data['name'] as String?);
    final eventTypeEmoji = resolvedType?.emoji ??
        (data['eventTypeEmoji'] as String? ?? '🎉');
    final eventTypeLabel = resolvedType != null
        ? '${resolvedType.category.label} → ${resolvedType.name}'
        : (data['eventTypeName'] as String? ?? 'Event');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              heroTag: 'schedule_add',
              onPressed: _showAddScheduleDialog,
              backgroundColor: AppTheme.accent,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add to Schedule', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: StreamBuilder<DocumentSnapshot>(
        stream: !widget.isAdmin && resolvedType != null
            ? FirebaseFirestore.instance
                .collection('eventTypeConfig')
                .doc(resolvedType.id)
                .snapshots()
            : const Stream<DocumentSnapshot>.empty(),
        builder: (context, configSnap) {
          final configData = configSnap.data?.data() as Map<String, dynamic>?;
          final enabledSections = residentTabSectionsFor(configData, 'event');
          bool sectionVisible(String id) => widget.isAdmin || enabledSections.contains(id);

          return StreamBuilder<QuerySnapshot>(
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

              // ── Countdown banner ────────────────────────────────
              _CountdownBanner(startStr: startStr, endStr: endStr),
              const SizedBox(height: 12),

              // ── Event details card ──────────────────────────────
              if (sectionVisible('event_details')) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
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
                            color: AppTheme.accent.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('$eventTypeEmoji $eventTypeLabel',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                  color: AppTheme.accent.shade700)),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: eventStatusColor(status).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: eventStatusColor(status).withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '${status == 'active' ? '🟢' : status == 'upcoming' ? '🔵' : '🔴'} ${eventStatusLabel(status)}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                color: eventStatusColor(status)),
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
              ],

              // ── Sponsor Highlights — celebrates sponsors, configurable ──
              if (sectionVisible('sponsor_highlights')) ...[
              const SizedBox(height: 20),
              _SponsorHighlightCard(eventId: widget.eventId),
              ],

              // ── Day-by-day schedule ────────────────────────────
              if (sectionVisible('event_schedule')) ...[
              const SizedBox(height: 20),
              Row(children: [
                Icon(Icons.schedule_outlined, size: 16, color: AppTheme.accent),
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
                    color: Theme.of(context).cardColor,
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
                              color: AppTheme.accent,
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
                          final color = _sessionColors[session] ?? AppTheme.accent;
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
                                        color: Theme.of(context).cardColor,
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

              // ── Pooja Schedule section ──────────────────────────
              if (sectionVisible('pooja_schedule'))
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('appSettings')
                    .doc('poojaSchedule')
                    .snapshots(),
                builder: (context, catSnap) {
                  final catData = catSnap.data?.data() as Map<String, dynamic>? ?? {};
                  final enabledIds = List<String>.from(catData['enabledTypeIds'] as List? ?? []);
                  final resolvedType = eventTypeById(widget.data['eventTypeId'] as String?) ??
                      eventTypeByName(widget.data['name'] as String?);
                  if (!enabledIds.contains(resolvedType?.id ?? '')) return const SizedBox.shrink();
                  final defaultMorning = (catData['morningCapacity'] as int?) ?? 2;
                  final defaultAfternoon = (catData['afternoonCapacity'] as int?) ?? 2;
                  final defaultEvening = (catData['eveningCapacity'] as int?) ?? 2;
                  return Column(children: [
                    const SizedBox(height: 28),
                    _PoojaScheduleSection(
                      eventId: widget.eventId,
                      data: widget.data,
                      isAdmin: widget.isAdmin,
                      residentFlat: widget.residentFlat,
                      residentName: widget.residentName,
                      residentWing: widget.residentWing,
                      residentBlock: widget.residentBlock,
                      defaultMorningCap: defaultMorning,
                      defaultAfternoonCap: defaultAfternoon,
                      defaultEveningCap: defaultEvening,
                    ),
                  ]);
                },
              ),
            ],
          );
        },
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
      Icon(icon, size: 15, color: AppTheme.accent.shade300),
      const SizedBox(width: 8),
      Text('$label: ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      Text(value, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
    ]);
  }
}

// ── Countdown Banner ─────────────────────────────────────────────────────────

class _CountdownBanner extends StatefulWidget {
  final String startStr;
  final String endStr;
  const _CountdownBanner({required this.startStr, required this.endStr});
  @override
  State<_CountdownBanner> createState() => _CountdownBannerState();
}

class _CountdownBannerState extends State<_CountdownBanner> {
  late Timer _timer;
  Duration _remaining = Duration.zero;
  bool _started = false;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _update());
    });
  }

  void _update() {
    final now = DateTime.now();
    final start = _parse(widget.startStr);
    final end = _parse(widget.endStr);
    if (start == null) return;
    if (now.isBefore(start)) {
      _remaining = start.difference(now);
      _started = false;
      _ended = false;
    } else if (end != null && now.isAfter(end.add(const Duration(days: 1)))) {
      _started = true;
      _ended = true;
    } else {
      _started = true;
      _ended = false;
    }
  }

  DateTime? _parse(String s) {
    if (s.isEmpty) return null;
    try {
      final p = s.split('/');
      return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
    } catch (_) { return null; }
  }

  @override
  void dispose() { _timer.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_parse(widget.startStr) == null) return const SizedBox.shrink();

    if (_ended) return const SizedBox.shrink();

    if (_started) {
      // Event is ongoing
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.green.shade600, Colors.teal.shade500]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const Icon(Icons.celebration_outlined, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Event is Happening Now! 🎉', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            SizedBox(height: 2),
            Text('Join us and be part of the celebration', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
        ]),
      );
    }

    // Countdown
    final d = _remaining.inDays;
    final h = _remaining.inHours % 24;
    final m = _remaining.inMinutes % 60;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.accent.shade700, Colors.indigo.shade500],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.timer_outlined, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          const Text('Event starts in', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _CountUnit(value: d, label: 'Days'),
          _Divider(),
          _CountUnit(value: h, label: 'Hrs'),
          _Divider(),
          _CountUnit(value: m, label: 'Min'),
        ]),
      ]),
    );
  }
}

class _CountUnit extends StatelessWidget {
  final int value;
  final String label;
  const _CountUnit({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text('${value.toString().padLeft(2, '0')}',
        style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, height: 1)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 0.5)),
  ]);
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Text(':', style: TextStyle(color: Colors.white38, fontSize: 28, fontWeight: FontWeight.w300));
}

// ── Pooja Schedule Section ────────────────────────────────────────────────────

class _PoojaScheduleSection extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> data;
  final bool isAdmin;
  final String residentFlat;
  final String residentName;
  final String residentWing;
  final String residentBlock;
  final int defaultMorningCap;
  final int defaultAfternoonCap;
  final int defaultEveningCap;
  const _PoojaScheduleSection({
    required this.eventId,
    required this.data,
    required this.isAdmin,
    this.residentFlat = '',
    this.residentName = '',
    this.residentWing = '',
    this.residentBlock = '',
    this.defaultMorningCap = 2,
    this.defaultAfternoonCap = 2,
    this.defaultEveningCap = 2,
  });
  @override
  State<_PoojaScheduleSection> createState() => _PoojaScheduleSectionState();
}

class _PoojaScheduleSectionState extends State<_PoojaScheduleSection> {
  CollectionReference get _col => FirebaseFirestore.instance
      .collection('events').doc(widget.eventId).collection('poojaRegistrations');

  DocumentReference get _eventRef =>
      FirebaseFirestore.instance.collection('events').doc(widget.eventId);

  // Parse DD/MM/YYYY
  DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    try { final p = s.split('/'); return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0])); } catch (_) { return null; }
  }

  List<DateTime> _eventDates([Map<String, dynamic>? poojaConfig]) {
    final start = _parseDate(poojaConfig?['startDate'] as String? ??
        widget.data['startDate'] as String? ?? '');
    final end = _parseDate(poojaConfig?['endDate'] as String? ??
        widget.data['endDate'] as String? ?? '');
    if (start == null) return [];
    final e = end ?? start;
    return List.generate(
      e.difference(start).inDays + 1,
      (i) => start.add(Duration(days: i)),
    );
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';

  String _fmtDate(DateTime dt) {
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${days[dt.weekday-1]}, ${months[dt.month-1]} ${dt.day}';
  }

  String _fmtDDMMYYYY(DateTime dt) =>
      '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';

  Future<void> _showConfigDialog(Map<String, dynamic> currentConfig) async {
    int morning = (currentConfig['morningCapacity'] as int?) ?? widget.defaultMorningCap;
    int afternoon = (currentConfig['afternoonCapacity'] as int?) ?? widget.defaultAfternoonCap;
    int evening = (currentConfig['eveningCapacity'] as int?) ?? widget.defaultEveningCap;
    DateTime? startDate = _parseDate(currentConfig['startDate'] as String? ??
        widget.data['startDate'] as String? ?? '');
    DateTime? endDate = _parseDate(currentConfig['endDate'] as String? ??
        widget.data['endDate'] as String? ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
        title: const Text('Pooja Slot Configuration'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Set max participants per shift per day:',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.wb_sunny_outlined, color: Color(0xFFF59E0B), size: 20),
            const SizedBox(width: 8),
            const Text('Morning capacity:', style: TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.remove_circle_outline), iconSize: 20,
                onPressed: morning > 0 ? () => setSt(() => morning--) : null),
            Text('$morning', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(icon: const Icon(Icons.add_circle_outline), iconSize: 20,
                onPressed: () => setSt(() => morning++)),
          ]),
          Row(children: [
            const Icon(Icons.light_mode_outlined, color: Color(0xFFFB923C), size: 20),
            const SizedBox(width: 8),
            const Text('Afternoon capacity:', style: TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.remove_circle_outline), iconSize: 20,
                onPressed: afternoon > 0 ? () => setSt(() => afternoon--) : null),
            Text('$afternoon', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(icon: const Icon(Icons.add_circle_outline), iconSize: 20,
                onPressed: () => setSt(() => afternoon++)),
          ]),
          Row(children: [
            const Icon(Icons.nights_stay_outlined, color: Color(0xFF8B5CF6), size: 20),
            const SizedBox(width: 8),
            const Text('Evening capacity:', style: TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.remove_circle_outline), iconSize: 20,
                onPressed: evening > 0 ? () => setSt(() => evening--) : null),
            Text('$evening', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(icon: const Icon(Icons.add_circle_outline), iconSize: 20,
                onPressed: () => setSt(() => evening++)),
          ]),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          const Text('Pooja schedule date range (optional — defaults to event dates):',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined, size: 15),
                label: Text(startDate == null ? 'Start date' : _fmtDDMMYYYY(startDate!),
                    style: const TextStyle(fontSize: 12)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: startDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (picked != null) setSt(() => startDate = picked);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined, size: 15),
                label: Text(endDate == null ? 'End date' : _fmtDDMMYYYY(endDate!),
                    style: const TextStyle(fontSize: 12)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: endDate ?? startDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (picked != null) setSt(() => endDate = picked);
                },
              ),
            ),
          ]),
        ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _eventRef.update({'poojaConfig': {
                'morningCapacity': morning,
                'afternoonCapacity': afternoon,
                'eveningCapacity': evening,
                if (startDate != null) 'startDate': _fmtDDMMYYYY(startDate!),
                if (endDate != null) 'endDate': _fmtDDMMYYYY(endDate!),
              }});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      )),
    );
  }

  static const _shiftLabels = {
    'morning': '☀ Morning', 'afternoon': '🌤 Afternoon', 'evening': '🌙 Evening',
  };

  Future<void> _showRegisterDialog(DateTime date, String shift,
      List<Map<String, dynamic>> existingRegs, int capacity,
      {Map<String, dynamic>? myReg, String? myRegId, List<DateTime>? registrableDates}) async {
    // If resident already has an approved reg, allow date change
    if (myReg != null && myReg['status'] == 'approved') {
      // Show date change dialog
      final dates = registrableDates ?? _eventDates();
      if (dates.isEmpty) return;
      DateTime? picked;
      String pickedShift = shift;
      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
          title: const Text('Change Pooja Date'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Select a new date and shift:',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: pickedShift,
              decoration: const InputDecoration(labelText: 'Shift', isDense: true),
              items: _shiftLabels.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setSt(() => pickedShift = v!),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: dates.map((d) {
              final sel = picked != null && _dateKey(picked!) == _dateKey(d);
              return ChoiceChip(
                label: Text(_fmtDate(d), style: TextStyle(fontSize: 12,
                    color: sel ? Colors.white : Colors.grey.shade700)),
                selected: sel,
                selectedColor: AppTheme.accent,
                onSelected: (_) => setSt(() => picked = d),
              );
            }).toList()),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: picked == null ? null : () async {
                await _col.doc(myRegId).update({
                  'date': _dateKey(picked!),
                  'shift': pickedShift,
                  'status': 'pending',
                  'requestedAt': Timestamp.now(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
              child: const Text('Change Date', style: TextStyle(color: Colors.white)),
            ),
          ],
        )),
      );
      return;
    }

    // New registration
    final approvedCount = existingRegs.where((r) => r['status'] == 'approved').length;
    if (approvedCount >= capacity) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$shift slot is full for ${_fmtDate(date)}')),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Register for ${_shiftLabels[shift] ?? shift} Pooja'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Date: ${_fmtDate(date)}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          const Text('You will be seated beside the idol to offer prayers during this shift. Your request will be reviewed by the admin.',
              style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            child: const Text('Request Slot', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _col.add({
        'flat': widget.residentFlat,
        'name': widget.residentName,
        'wing': widget.residentWing,
        'block': widget.residentBlock,
        'date': _dateKey(date),
        'shift': shift,
        'status': 'pending',
        'requestedAt': Timestamp.now(),
      });
    }
  }

  Future<void> _updateStatus(String docId, String status) async {
    await _col.doc(docId).update({'status': status, '${status}At': Timestamp.now()});
  }

  Future<void> _toggleNoSchedule(String dateKey, Set<String> current) async {
    final updated = Set<String>.from(current);
    updated.contains(dateKey) ? updated.remove(dateKey) : updated.add(dateKey);
    await _eventRef.update({'poojaConfig.noScheduleDates': updated.toList()});
  }

  @override
  Widget build(BuildContext context) {
    // poojaConfig comes straight from widget.data (already kept fresh by the
    // single event-doc listener owned by EventDashboardScreen/_EventTab) —
    // this used to re-subscribe to the whole event doc a second time here,
    // which caused this entire (potentially large) day/shift widget tree to
    // rebuild on every unrelated event-doc write (e.g. any contribution or
    // expense added anywhere in the event), making the Event tab feel slow.
    final poojaConfig = widget.data['poojaConfig'] as Map<String, dynamic>? ?? {};
    final morningCap = (poojaConfig['morningCapacity'] as int?) ?? widget.defaultMorningCap;
    final afternoonCap = (poojaConfig['afternoonCapacity'] as int?) ?? widget.defaultAfternoonCap;
    final eveningCap = (poojaConfig['eveningCapacity'] as int?) ?? widget.defaultEveningCap;
    final dates = _eventDates(poojaConfig);
    final noScheduleDates = Set<String>.from(poojaConfig['noScheduleDates'] as List? ?? []);
    final visibleDates = widget.isAdmin
        ? dates
        : dates.where((d) => !noScheduleDates.contains(_dateKey(d))).toList();
    final registrableDates =
        dates.where((d) => !noScheduleDates.contains(_dateKey(d))).toList();

    return StreamBuilder<QuerySnapshot>(
      stream: _col.orderBy('requestedAt').snapshots(),
      builder: (context, snap) {
            final allRegs = (snap.data?.docs ?? []).map((d) {
              return {...(d.data() as Map<String, dynamic>), '_id': d.id};
            }).toList();

            // Group registrations by date+shift
            Map<String, Map<String, List<Map<String, dynamic>>>> grouped = {};
            for (final r in allRegs) {
              final date = r['date'] as String? ?? '';
              final shift = r['shift'] as String? ?? 'morning';
              grouped.putIfAbsent(date, () => {});
              grouped[date]!.putIfAbsent(shift, () => []);
              grouped[date]![shift]!.add(r);
            }

            // My registrations (for residents)
            final myRegs = widget.isAdmin ? <Map<String, dynamic>>[] :
                allRegs.where((r) => r['flat'] == widget.residentFlat).toList();

            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Section header
              Row(children: [
                const Text('🙏', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text('Pooja Schedule',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                        color: Colors.grey.shade800, letterSpacing: 0.3)),
                const Spacer(),
                if (widget.isAdmin)
                  TextButton.icon(
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Configure', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    onPressed: () => _showConfigDialog(poojaConfig),
                  ),
              ]),
              const SizedBox(height: 4),
              Text('Capacity: ☀ Morning ${morningCap}p  ·  🌤 Afternoon ${afternoonCap}p  ·  🌙 Evening ${eveningCap}p per day',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(height: 14),

              if (visibleDates.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Center(child: Text('Set event start/end dates to enable Pooja scheduling.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13), textAlign: TextAlign.center)),
                )
              else
                ...visibleDates.map((date) {
                  final dk = _dateKey(date);
                  final isNoSchedule = noScheduleDates.contains(dk);
                  final dayRegs = grouped[dk] ?? {};
                  final morningRegs = dayRegs['morning'] ?? [];
                  final afternoonRegs = dayRegs['afternoon'] ?? [];
                  final eveningRegs = dayRegs['evening'] ?? [];

                  final myMorning = myRegs.where((r) => r['date'] == dk && r['shift'] == 'morning').firstOrNull;
                  final myAfternoon = myRegs.where((r) => r['date'] == dk && r['shift'] == 'afternoon').firstOrNull;
                  final myEvening = myRegs.where((r) => r['date'] == dk && r['shift'] == 'evening').firstOrNull;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Date header
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        decoration: BoxDecoration(
                          color: isNoSchedule ? Colors.grey.shade100 : AppTheme.accent.shade50,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        ),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isNoSchedule ? Colors.grey.shade400 : AppTheme.accent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('${date.day}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          const SizedBox(width: 8),
                          Text(_fmtDate(date),
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                                  color: isNoSchedule ? Colors.grey.shade600 : AppTheme.accent.shade800)),
                          const Spacer(),
                          if (widget.isAdmin)
                            GestureDetector(
                              onTap: () => _toggleNoSchedule(dk, noScheduleDates),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isNoSchedule ? AppTheme.accent.withValues(alpha: 0.1) : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(isNoSchedule ? 'Enable' : 'No Schedule',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                        color: isNoSchedule ? AppTheme.accent : Colors.grey.shade600)),
                              ),
                            )
                          else
                            Text('Day ${dates.indexOf(date) + 1}',
                                style: TextStyle(fontSize: 11, color: AppTheme.accent.shade300)),
                        ]),
                      ),
                      if (isNoSchedule)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          child: Text('No pooja scheduled on this day',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                        )
                      else ...() {
                        // A capacity of 0 means that shift doesn't run at all
                        // (distinct from "No Schedule" for the whole day) —
                        // skip rendering it entirely, including its divider.
                        final shifts = <Widget>[
                          if (morningCap > 0)
                            _PoojaShift(
                              shift: 'morning',
                              label: 'Morning',
                              icon: Icons.wb_sunny_outlined,
                              color: const Color(0xFFF59E0B),
                              regs: morningRegs,
                              capacity: morningCap,
                              isAdmin: widget.isAdmin,
                              myReg: myMorning,
                              onRegister: () => _showRegisterDialog(date, 'morning', morningRegs, morningCap,
                                  myReg: myMorning, myRegId: myMorning?['_id'] as String?,
                                  registrableDates: registrableDates),
                              onApprove: (id) => _updateStatus(id, 'approved'),
                              onReject: (id) => _updateStatus(id, 'rejected'),
                            ),
                          if (afternoonCap > 0)
                            _PoojaShift(
                              shift: 'afternoon',
                              label: 'Afternoon',
                              icon: Icons.light_mode_outlined,
                              color: const Color(0xFFFB923C),
                              regs: afternoonRegs,
                              capacity: afternoonCap,
                              isAdmin: widget.isAdmin,
                              myReg: myAfternoon,
                              onRegister: () => _showRegisterDialog(date, 'afternoon', afternoonRegs, afternoonCap,
                                  myReg: myAfternoon, myRegId: myAfternoon?['_id'] as String?,
                                  registrableDates: registrableDates),
                              onApprove: (id) => _updateStatus(id, 'approved'),
                              onReject: (id) => _updateStatus(id, 'rejected'),
                            ),
                          if (eveningCap > 0)
                            _PoojaShift(
                              shift: 'evening',
                              label: 'Evening',
                              icon: Icons.nights_stay_outlined,
                              color: const Color(0xFF8B5CF6),
                              regs: eveningRegs,
                              capacity: eveningCap,
                              isAdmin: widget.isAdmin,
                              myReg: myEvening,
                              onRegister: () => _showRegisterDialog(date, 'evening', eveningRegs, eveningCap,
                                  myReg: myEvening, myRegId: myEvening?['_id'] as String?,
                                  registrableDates: registrableDates),
                              onApprove: (id) => _updateStatus(id, 'approved'),
                              onReject: (id) => _updateStatus(id, 'rejected'),
                            ),
                        ];
                        if (shifts.isEmpty) {
                          return [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                              child: Text('No pooja shifts configured for this day',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                            ),
                          ];
                        }
                        return [
                          for (var i = 0; i < shifts.length; i++) ...[
                            if (i > 0) const Divider(height: 1, indent: 14, endIndent: 14),
                            shifts[i],
                          ],
                        ];
                      }(),
                    ]),
                  );
                }),
            ]);
          },
        );
  }
}

class _PoojaShift extends StatelessWidget {
  final String shift;
  final String label;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> regs;
  final int capacity;
  final bool isAdmin;
  final Map<String, dynamic>? myReg;
  final VoidCallback onRegister;
  final void Function(String) onApprove;
  final void Function(String) onReject;

  const _PoojaShift({
    required this.shift,
    required this.label,
    required this.icon,
    required this.color,
    required this.regs,
    required this.capacity,
    required this.isAdmin,
    required this.myReg,
    required this.onRegister,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final approved = regs.where((r) => r['status'] == 'approved').toList();
    final pending = regs.where((r) => r['status'] == 'pending').toList();
    final rejected = regs.where((r) => r['status'] == 'rejected').toList();
    final isFull = approved.length >= capacity;
    final myStatus = myReg?['status'] as String?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Shift header row
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
          const SizedBox(width: 8),
          // Slot count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isFull ? Colors.red.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isFull ? Colors.red.shade200 : Colors.green.shade200),
            ),
            child: Text('${approved.length}/$capacity slots',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    color: isFull ? Colors.red.shade700 : Colors.green.shade700)),
          ),
          const Spacer(),
          // Register / Change date button (residents only)
          if (!isAdmin)
            myStatus == 'approved'
              ? GestureDetector(
                  onTap: onRegister,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade300),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.swap_horiz, size: 12, color: Colors.teal.shade700),
                      const SizedBox(width: 3),
                      Text('Change', style: TextStyle(fontSize: 11, color: Colors.teal.shade700, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                )
              : myStatus == 'pending'
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Requested', style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.w600)),
                  )
                : isFull
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                      child: Text('Full', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    )
                  : GestureDetector(
                      onTap: onRegister,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withValues(alpha: 0.4)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add, size: 13, color: color),
                          const SizedBox(width: 3),
                          Text('Join', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
        ]),

        // Approved list (always visible)
        if (approved.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...approved.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
              const SizedBox(width: 6),
              Text('${r['flat']} — ${r['name']}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const Spacer(),
              if (isAdmin)
                GestureDetector(
                  onTap: () => onReject(r['_id'] as String),
                  child: Icon(Icons.close, size: 14, color: Colors.red.shade300),
                ),
            ]),
          )),
        ],

        // Admin: pending requests in request order
        if (isAdmin && pending.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...pending.asMap().entries.map((entry) {
            final i = entry.key;
            final r = entry.value;
            final reqTime = (r['requestedAt'] as Timestamp?)?.toDate();
            final agoStr = reqTime != null ? _ago(reqTime) : '';
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(children: [
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: i == 0 ? AppTheme.accent : Colors.orange.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Text('${i+1}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r['flat']} — ${r['name']}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  if (agoStr.isNotEmpty)
                    Text('Requested $agoStr${i == 0 ? ' · First in queue' : ''}',
                        style: TextStyle(fontSize: 10, color: Colors.orange.shade700)),
                ])),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(
                    onTap: approved.length < capacity ? () => onApprove(r['_id'] as String) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: approved.length < capacity ? Colors.green.shade600 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Approve', style: TextStyle(fontSize: 11, color: approved.length < capacity ? Colors.white : Colors.grey.shade500, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => onReject(r['_id'] as String),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.red.shade200)),
                      child: Text('Reject', style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ]),
            );
          }),
        ],

        // Resident: show if rejected
        if (!isAdmin && myStatus == 'rejected')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Icon(Icons.cancel_outlined, size: 14, color: Colors.red.shade400),
              const SizedBox(width: 6),
              Text('Your request was not approved for this slot.',
                  style: TextStyle(fontSize: 11, color: Colors.red.shade600)),
            ]),
          ),

        // Vacant indicator
        if (approved.isEmpty && pending.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Icon(Icons.circle_outlined, size: 12, color: Colors.green.shade400),
              const SizedBox(width: 5),
              Text('All $capacity slot${capacity > 1 ? 's' : ''} available',
                  style: TextStyle(fontSize: 11, color: Colors.green.shade600)),
            ]),
          ),
      ]),
    );
  }

  static String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

// ── Volunteers Tab ────────────────────────────────────────────────────────────

class _VolunteersTab extends StatefulWidget {
  final String eventId;
  final String eventTypeId;
  final bool isAdmin;
  final String residentFlat;
  final String residentName;
  final String residentWing;
  final String residentBlock;
  const _VolunteersTab({
    required this.eventId,
    this.eventTypeId = '',
    required this.isAdmin,
    this.residentFlat = '',
    this.residentName = '',
    this.residentWing = '',
    this.residentBlock = '',
  });
  @override
  State<_VolunteersTab> createState() => _VolunteersTabState();
}

class _VolunteersTabState extends State<_VolunteersTab> {
  // Load session directly so flat is always available even if parent hasn't loaded yet
  String _flat = '';
  String _name = '';
  String _wing = '';
  String _block = '';
  final Map<String, bool> _volExpanded = {};
  List<String> _roles = _defaultRoles;

  @override
  void initState() {
    super.initState();
    _flat = widget.residentFlat;
    _name = widget.residentName;
    _wing = widget.residentWing;
    _block = widget.residentBlock;
    if (!widget.isAdmin && _flat.isEmpty) _loadSession();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    if (widget.eventTypeId.isEmpty) return;
    final snap = await FirebaseFirestore.instance
        .collection('eventTypeConfig')
        .doc(widget.eventTypeId)
        .get();
    if (!mounted) return;
    final d = snap.data() as Map<String, dynamic>? ?? {};
    final raw = d['volunteerRoles'];
    if (raw != null) {
      setState(() => _roles = List<String>.from(raw as List));
    }
  }

  @override
  void didUpdateWidget(_VolunteersTab old) {
    super.didUpdateWidget(old);
    if (widget.residentFlat.isNotEmpty && widget.residentFlat != _flat) {
      setState(() {
        _flat = widget.residentFlat;
        _name = widget.residentName;
        _wing = widget.residentWing;
        _block = widget.residentBlock;
      });
    }
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _flat = prefs.getString('session_flat') ?? '';
      _name = prefs.getString('session_name') ?? '';
      _wing = prefs.getString('session_wing') ?? '';
      _block = prefs.getString('session_block') ?? '';
    });
  }

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

  CollectionReference get _col => FirebaseFirestore.instance
      .collection('events').doc(widget.eventId).collection('volunteers');

  // ── Admin: manually add volunteer (auto-approved) ──────────────────────────
  Future<void> _showAdminAddDialog({Map<String, dynamic>? existing, String? docId}) async {
    final nameCtrl  = TextEditingController(text: existing?['name']  ?? '');
    final wingCtrl  = TextEditingController(text: existing?['wing']  ?? '');
    final blockCtrl = TextEditingController(text: existing?['block'] ?? '');
    final flatCtrl  = TextEditingController(text: existing?['flat']  ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone'] ?? '');
    String role = existing?['role'] ?? _roles.first;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(existing == null ? 'Add Volunteer' : 'Edit Volunteer'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              _volTextField(nameCtrl, 'Name *', 'e.g. Ramesh Kumar', TextInputType.name),
              const SizedBox(height: 12),
              const Text('Role', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 6),
              _roleChips(role, (r) => setSt(() => role = r)),
              const SizedBox(height: 12),
              // Wing · Block · Flat row
              Row(children: [
                Expanded(child: _volTextField(wingCtrl,  'Wing',  'e.g. D', TextInputType.text)),
                const SizedBox(width: 8),
                Expanded(child: _volTextField(blockCtrl, 'Block', 'e.g. A', TextInputType.text)),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: _volTextField(flatCtrl, 'Flat No', 'e.g. 101', TextInputType.text)),
              ]),
              const SizedBox(height: 10),
              _volTextField(phoneCtrl, 'Phone (optional)', 'e.g. 9876543210', TextInputType.phone),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                final wing  = wingCtrl.text.trim().toUpperCase();
                final block = blockCtrl.text.trim().toUpperCase();
                final flatNo = flatCtrl.text.trim();
                final flat = flatNo.isNotEmpty ? '$wing$block $flatNo' : '$wing$block';
                final payload = {
                  'name': name, 'role': role,
                  'wing': wing, 'block': block, 'flat': flat,
                  'phone': phoneCtrl.text.trim(),
                  'status': 'approved', 'addedBy': 'admin',
                  'approvedAt': Timestamp.now(),
                  'addedAt': Timestamp.now(),
                };
                if (docId != null) { await _col.doc(docId).update(payload); }
                else { await _col.add(payload); }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
              child: Text(existing == null ? 'Add' : 'Save', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Admin: soft-delete volunteer (keeps log intact) ──────────────────────
  Future<void> _confirmRemove(String docId, String name, String currentStatus) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Volunteer'),
        content: Text('Remove $name from the active list?\nYou can restore them later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _col.doc(docId).update({
        'status': 'deleted',
        'preDeleteStatus': currentStatus,
        'deletedAt': Timestamp.now(),
      });
    }
  }

  // ── Admin: restore deleted volunteer ────────────────────────────────────
  Future<void> _restoreVolunteer(String docId, String preDeleteStatus) async {
    final restoreTo = preDeleteStatus.isEmpty || preDeleteStatus == 'deleted'
        ? 'pending'
        : preDeleteStatus;
    await _col.doc(docId).update({
      'status': restoreTo,
      'restoredAt': Timestamp.now(),
      'preDeleteStatus': FieldValue.delete(),
    });
  }

  // ── Admin / resident: move volunteer back to pending ─────────────────────
  Future<void> _moveToPending(String docId) async {
    await _col.doc(docId).update({
      'status': 'pending',
      'pendingAt': Timestamp.now(),
    });
  }

  // ── Resident: self-register dialog ────────────────────────────────────────
  Future<void> _showRegisterDialog({Map<String, dynamic>? existing, String? docId, Set<String> excludeRoles = const {}}) async {
    final availableRoles = _roles.where((r) => existing?['role'] == r || !excludeRoles.contains(r)).toList();
    String role = existing?['role'] ?? (availableRoles.isNotEmpty ? availableRoles.first : _roles.first);
    final noteCtrl = TextEditingController(text: existing?['note'] ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(existing == null ? 'Register as Volunteer' : 'Edit Registration'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Name + flat (read-only, from session)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accent.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 18, backgroundColor: AppTheme.accent.shade100,
                    child: Text(
                      _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                      style: TextStyle(color: AppTheme.accent.shade700, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (_flat.isNotEmpty)
                      Text('Flat $_flat', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ]),
                ]),
              ),
              const SizedBox(height: 14),
              const Text('Choose your role', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 6),
              _roleChips(role, (r) => setSt(() => role = r), availableRoles: availableRoles),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'Any specific availability or skills…',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppTheme.accent, width: 2),
                  ),
                ),
              ),
            ]),
          ),
          actions: [
            if (existing != null && docId != null)
              TextButton(
                onPressed: () async { Navigator.pop(ctx); await _col.doc(docId).delete(); },
                child: Text('Withdraw', style: TextStyle(color: Colors.red.shade600)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final payload = {
                  'name': _name,
                  'flat': _flat,
                  'wing': _wing,
                  'block': _block,
                  'role': role,
                  'note': noteCtrl.text.trim(),
                  'status': 'pending',
                  'addedBy': 'resident',
                  'addedAt': Timestamp.now(),
                };
                if (docId != null) { await _col.doc(docId).update(payload); }
                else { await _col.add(payload); }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
              child: Text(existing == null ? 'Submit Registration' : 'Update',
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Admin: approve / reject / waitlist ────────────────────────────────────
  Future<void> _updateStatus(String docId, String status) async {
    await _col.doc(docId).update({
      'status': status,
      '${status}At': Timestamp.now(),
    });
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  Widget _roleChips(String selected, void Function(String) onSelect, {List<String>? availableRoles}) {
    final roles = availableRoles ?? _roles;
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: roles.map((r) => ChoiceChip(
        label: Text(r, style: const TextStyle(fontSize: 12)),
        selected: selected == r,
        selectedColor: (_roleColors[r] ?? AppTheme.accent).withValues(alpha: 0.15),
        onSelected: (_) => onSelect(r),
      )).toList(),
    );
  }

  Widget _volTextField(TextEditingController ctrl, String label, String hint, TextInputType kbt) =>
    TextField(
      controller: ctrl,
      keyboardType: kbt,
      textCapitalization: kbt == TextInputType.name ? TextCapitalization.words : TextCapitalization.none,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.accent, width: 2),
        ),
      ),
    );

  Widget _memberCard(Map<String, dynamic> m, Color color, {bool editable = false, bool removable = false, List<_CardAction>? extraActions, VoidCallback? onTap}) {
    final name = m['name'] as String? ?? '';
    final flat = m['flat'] as String? ?? '';
    final phone = m['phone'] as String? ?? '';
    final note = m['note'] as String? ?? '';
    final docId = m['_id'] as String? ?? '';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.18)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            if (flat.isNotEmpty || phone.isNotEmpty)
              Text([if (flat.isNotEmpty) flat, if (phone.isNotEmpty) phone].join('  ·  '),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            if (note.isNotEmpty)
              Text(note, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
            if (extraActions != null && extraActions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: extraActions.map((a) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: a.onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: a.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: a.color.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (a.icon != null) ...[
                        Icon(a.icon, size: 11, color: a.color),
                        const SizedBox(width: 3),
                      ],
                      Text(a.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: a.color)),
                    ]),
                  ),
                ),
              )).toList()),
            ],
          ])),
          if (editable) ...[
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 16, color: Colors.grey.shade400),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              onPressed: onTap,
            ),
          ],
          if (removable && docId.isNotEmpty) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade300),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              onPressed: () => _confirmRemove(docId, name, m['status'] as String? ?? ''),
            ),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              heroTag: 'volunteer_add',
              onPressed: _showAdminAddDialog,
              backgroundColor: AppTheme.accent,
              icon: const Icon(Icons.person_add_outlined, color: Colors.white),
              label: const Text('Add Volunteer', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: StreamBuilder<DocumentSnapshot>(
        stream: !widget.isAdmin && widget.eventTypeId.isNotEmpty
            ? FirebaseFirestore.instance
                .collection('eventTypeConfig')
                .doc(widget.eventTypeId)
                .snapshots()
            : const Stream<DocumentSnapshot>.empty(),
        builder: (context, configSnap) {
          final configData = configSnap.data?.data() as Map<String, dynamic>?;
          final enabledSections = residentTabSectionsFor(configData, 'volunteers');
          bool sectionVisible(String id) => widget.isAdmin || enabledSections.contains(id);

          return StreamBuilder<QuerySnapshot>(
        stream: _col.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}', style: const TextStyle(color: Colors.red)));
          }
          final docs = snap.data?.docs ?? [];
          final all = (docs.map((d) => {...d.data() as Map<String, dynamic>, '_id': d.id}).toList())
            ..sort((a, b) {
              final at = a['addedAt'];
              final bt = b['addedAt'];
              if (at == null || bt == null) return 0;
              return (at as Timestamp).compareTo(bt as Timestamp);
            });

          // Partition
          final pending   = all.where((m) => m['status'] == 'pending').toList();
          final approved  = all.where((m) => m['status'] == 'approved').toList();
          final waitlisted = all.where((m) => m['status'] == 'waitlisted').toList();
          final rejected  = all.where((m) => m['status'] == 'rejected').toList();
          final deleted   = all.where((m) => m['status'] == 'deleted').toList();

          // Resident's own registrations (can register for multiple roles, excludes deleted)
          final myRegs = widget.isAdmin ? <Map<String,dynamic>>[] : all.where((m) =>
              m['addedBy'] == 'resident' && m['flat'] == _flat && m['status'] != 'deleted').toList();
          final hasRegistered = myRegs.isNotEmpty;
          final myRegisteredRoles = myRegs.map((m) => m['role'] as String? ?? '').toSet();

          // Group approved by role
          final byRole = <String, List<Map<String, dynamic>>>{};
          for (final m in approved) {
            byRole.putIfAbsent(m['role'] as String? ?? 'Other', () => []).add(m);
          }
          final sortedRoles = byRole.keys.toList()
            ..sort((a, b) {
              final ai = _roles.indexOf(a); final bi = _roles.indexOf(b);
              return (ai < 0 ? 99 : ai).compareTo(bi < 0 ? 99 : bi);
            });

          // Expand/collapse state for volunteer sections
          final allSections = ['approved', 'waitlisted', 'rejected', 'deleted'];

          Widget volSection({
                required String key,
                required String label,
                required int count,
                required Color color,
                required IconData icon,
                required bool initiallyExpanded,
                required List<Widget> children,
              }) {
                _volExpanded.putIfAbsent(key, () => initiallyExpanded);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _volExpanded[key] = !(_volExpanded[key] ?? true)),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          _SectionHeader(label: label, count: count, color: color, icon: icon),
                          const Spacer(),
                          Icon(
                            (_volExpanded[key] ?? true) ? Icons.expand_less : Icons.expand_more,
                            size: 18, color: color,
                          ),
                        ]),
                      ),
                    ),
                    if (_volExpanded[key] ?? true) ...children,
                    const SizedBox(height: 8),
                  ],
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [

                // ── RESIDENT: my assigned tasks (only shown if any exist) ────
                if (!widget.isAdmin) ...[
                  _MyTasksSection(eventId: widget.eventId, flat: _flat, name: _name),
                ],

                // ── RESIDENT: volunteer invitation / appreciation ────
                if (!widget.isAdmin) ...[
                  if (!hasRegistered) ...[
                    if (sectionVisible('volunteer_invitation')) ...[
                    // ── Invitation banner ──────────────────────────────
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                            blurRadius: 20, offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Decorative circle top-right
                          Positioned(
                            top: -20, right: -20,
                            child: Container(
                              width: 100, height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.07),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -30, left: -10,
                            child: Container(
                              width: 130, height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.volunteer_activism,
                                        color: Colors.white, size: 26),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Be Part of Something Beautiful',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              height: 1.2,
                                            )),
                                        const SizedBox(height: 3),
                                        Text('Help make this event unforgettable',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.75),
                                              fontSize: 12,
                                            )),
                                      ],
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 14),
                                Text('Every helping hand counts. Choose a role that suits you and join our volunteer team!',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.88),
                                      fontSize: 13,
                                      height: 1.5,
                                    )),
                                const SizedBox(height: 14),
                                // Role preview chips
                                Wrap(
                                  spacing: 6, runSpacing: 6,
                                  children: _roles.take(6).map((r) {
                                    final icon = _roleIcons[r] ?? Icons.volunteer_activism_outlined;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                      ),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.9)),
                                        const SizedBox(width: 4),
                                        Text(r, style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontSize: 11, fontWeight: FontWeight.w500,
                                        )),
                                      ]),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showRegisterDialog(excludeRoles: myRegisteredRoles),
                                    icon: const Icon(Icons.add_circle_outline, size: 18),
                                    label: const Text('I Want to Volunteer!',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF4F46E5),
                                      padding: const EdgeInsets.symmetric(vertical: 13),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ],
                  ] else ...[
                    if (sectionVisible('volunteer_appreciation')) ...[
                    // ── Appreciation banner ────────────────────────────
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF059669), const Color(0xFF0D9488)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF059669).withValues(alpha: 0.28),
                            blurRadius: 18, offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Stack(children: [
                        Positioned(
                          top: -15, right: -15,
                          child: Container(
                            width: 90, height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.07),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.favorite_rounded,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Thank You for Stepping Up! 🙏',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15, fontWeight: FontWeight.w800,
                                    )),
                                const SizedBox(height: 5),
                                Text(
                                  'Your spirit of service makes this event shine. '
                                  'We\'ll review your registration and get back to you soon.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 12, height: 1.5,
                                  ),
                                ),
                                if (myRegisteredRoles.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 5, runSpacing: 5,
                                    children: myRegisteredRoles.map((r) {
                                      final icon = _roleIcons[r] ?? Icons.volunteer_activism_outlined;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                          Icon(icon, size: 11, color: Colors.white),
                                          const SizedBox(width: 4),
                                          Text(r, style: const TextStyle(
                                            color: Colors.white, fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          )),
                                        ]),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            )),
                          ]),
                        ),
                      ]),
                    ),
                    ],
                    if (sectionVisible('my_registrations')) ...[
                    // Register for another role (right after banner)
                    if (myRegisteredRoles.length < _roles.length)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: OutlinedButton.icon(
                          onPressed: () => _showRegisterDialog(excludeRoles: myRegisteredRoles),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Register for Another Role',
                              style: TextStyle(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.teal.shade700,
                            side: BorderSide(color: Colors.teal.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    // My registrations grouped by status (collapsible)
                    ...() {
                      final myPending    = myRegs.where((r) => r['status'] == 'pending').toList();
                      final myApproved   = myRegs.where((r) => r['status'] == 'approved').toList();
                      final myWaitlisted = myRegs.where((r) => r['status'] == 'waitlisted').toList();
                      final myRejected   = myRegs.where((r) => r['status'] == 'rejected').toList();
                      Widget regCard(Map<String, dynamic> reg) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _MyRegistrationCard(
                          reg: reg,
                          onEdit: () => _showRegisterDialog(existing: reg, docId: reg['_id'] as String, excludeRoles: myRegisteredRoles),
                        ),
                      );
                      return [
                        if (myApproved.isNotEmpty)
                          volSection(
                            key: 'my_approved', label: 'Approved', count: myApproved.length,
                            color: Colors.green.shade700, icon: Icons.check_circle_outline,
                            initiallyExpanded: false,
                            children: myApproved.map(regCard).toList(),
                          ),
                        if (myPending.isNotEmpty)
                          volSection(
                            key: 'my_pending', label: 'Pending', count: myPending.length,
                            color: Colors.orange.shade700, icon: Icons.pending_outlined,
                            initiallyExpanded: false,
                            children: myPending.map(regCard).toList(),
                          ),
                        if (myWaitlisted.isNotEmpty)
                          volSection(
                            key: 'my_waitlisted', label: 'Waitlisted', count: myWaitlisted.length,
                            color: Colors.blue.shade700, icon: Icons.schedule_outlined,
                            initiallyExpanded: false,
                            children: myWaitlisted.map(regCard).toList(),
                          ),
                        if (myRejected.isNotEmpty)
                          volSection(
                            key: 'my_rejected', label: 'Not Selected', count: myRejected.length,
                            color: Colors.red.shade400, icon: Icons.cancel_outlined,
                            initiallyExpanded: false,
                            children: myRejected.map(regCard).toList(),
                          ),
                      ];
                    }(),
                    ],
                  ],
                  const SizedBox(height: 16),
                ],

                // ── ADMIN: pending registrations (not collapsible — requires action) ──
                if (widget.isAdmin && pending.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'Pending Registrations', count: pending.length,
                    color: Colors.orange.shade700, icon: Icons.pending_outlined,
                  ),
                  const SizedBox(height: 8),
                  ...pending.map((m) => _PendingCard(
                    m: m,
                    onApprove: () => _updateStatus(m['_id'] as String, 'approved'),
                    onWaitlist: () => _updateStatus(m['_id'] as String, 'waitlisted'),
                    onReject: () => _updateStatus(m['_id'] as String, 'rejected'),
                  )),
                  const SizedBox(height: 12),
                ],

                // ── ADMIN: waitlisted ─────────────────────────────────
                if (widget.isAdmin && waitlisted.isNotEmpty)
                  volSection(
                    key: 'waitlisted', label: 'Waitlisted', count: waitlisted.length,
                    color: Colors.blue.shade700, icon: Icons.schedule_outlined,
                    initiallyExpanded: false,
                    children: waitlisted.map((m) {
                      final color = _roleColors[m['role']] ?? const Color(0xFF374151);
                      return _memberCard(m, color,
                        editable: true, removable: true,
                        extraActions: [
                          _CardAction(label: 'Approve', color: Colors.green.shade700,
                              icon: Icons.check_circle_outline,
                              onTap: () => _updateStatus(m['_id'] as String, 'approved')),
                          _CardAction(label: 'Revert', color: Colors.orange.shade700,
                              icon: Icons.undo_outlined,
                              onTap: () => _moveToPending(m['_id'] as String)),
                        ],
                        onTap: () => _showAdminAddDialog(existing: m, docId: m['_id'] as String),
                      );
                    }).toList(),
                  ),

                // ── Admin: approved volunteers (collapsible by role) ──
                if (widget.isAdmin && approved.isNotEmpty)
                  volSection(
                      key: 'approved', label: 'Approved', count: approved.length,
                      color: Colors.green.shade700, icon: Icons.check_circle_outline,
                      initiallyExpanded: false,
                      children: sortedRoles.map((role) {
                        final members = byRole[role]!;
                        final color = _roleColors[role] ?? const Color(0xFF374151);
                        final rIcon = _roleIcons[role] ?? Icons.volunteer_activism_outlined;
                        return volSection(
                          key: 'role_$role', label: role, count: members.length,
                          color: color, icon: rIcon,
                          initiallyExpanded: false,
                          children: members.map((m) => _memberCard(m, color,
                            editable: true, removable: true,
                            extraActions: [
                              _CardAction(label: 'Revert', color: Colors.orange.shade700,
                                  icon: Icons.undo_outlined,
                                  onTap: () => _moveToPending(m['_id'] as String)),
                            ],
                            onTap: () => _showAdminAddDialog(existing: m, docId: m['_id'] as String),
                          )).toList(),
                        );
                      }).toList(),
                    ),

                // ── ADMIN: rejected ────────────────────────────────────
                if (widget.isAdmin && rejected.isNotEmpty)
                  volSection(
                    key: 'rejected', label: 'Rejected', count: rejected.length,
                    color: Colors.red.shade400, icon: Icons.cancel_outlined,
                    initiallyExpanded: false,
                    children: rejected.map((m) {
                      final color = _roleColors[m['role']] ?? const Color(0xFF374151);
                      return Opacity(opacity: 0.7, child: _memberCard(m, color,
                        removable: true,
                        extraActions: [
                          _CardAction(label: 'Revert', color: Colors.orange.shade700,
                              icon: Icons.undo_outlined,
                              onTap: () => _moveToPending(m['_id'] as String)),
                          _CardAction(label: 'Approve', color: Colors.green.shade700,
                              icon: Icons.check_circle_outline,
                              onTap: () => _updateStatus(m['_id'] as String, 'approved')),
                        ],
                      ));
                    }).toList(),
                  ),

                // ── ADMIN: removed (restore + hard delete) ─────────────
                if (widget.isAdmin && deleted.isNotEmpty)
                  volSection(
                    key: 'deleted', label: 'Removed', count: deleted.length,
                    color: Colors.grey.shade500, icon: Icons.delete_outline,
                    initiallyExpanded: false,
                    children: deleted.map((m) {
                      final color = _roleColors[m['role']] ?? const Color(0xFF374151);
                      return Opacity(opacity: 0.5, child: _memberCard(m, color,
                        extraActions: [
                          _CardAction(label: 'Restore', color: Colors.teal.shade700,
                              icon: Icons.restore_outlined,
                              onTap: () => _restoreVolunteer(m['_id'] as String, m['preDeleteStatus'] as String? ?? '')),
                          _CardAction(label: 'Delete', color: Colors.red.shade700,
                              icon: Icons.delete_forever_outlined,
                              onTap: () async {
                                final ok = await showDialog<bool>(context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Permanently Delete'),
                                    content: Text('Permanently delete ${m['name']}? This cannot be undone.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                                        child: const Text('Delete Forever', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) await _col.doc(m['_id'] as String).delete();
                              }),
                        ],
                      ));
                    }).toList(),
                  ),
              ],
            );
        },
      );
        },
      ),
    );
  }
}

// ── My Registration Card (resident) ──────────────────────────────────────────

class _MyRegistrationCard extends StatelessWidget {
  final Map<String, dynamic> reg;
  final VoidCallback onEdit;
  const _MyRegistrationCard({required this.reg, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final status = reg['status'] as String? ?? 'pending';
    final role = reg['role'] as String? ?? '';
    final note = reg['note'] as String? ?? '';

    final (Color bg, Color border, Color text, IconData icon, String label) = switch (status) {
      'approved'   => (Colors.green.shade50,  Colors.green.shade300,  Colors.green.shade700,  Icons.check_circle_rounded, 'Approved ✓'),
      'rejected'   => (Colors.red.shade50,    Colors.red.shade200,    Colors.red.shade700,    Icons.cancel_rounded,       'Not Selected'),
      'waitlisted' => (Colors.blue.shade50,   Colors.blue.shade200,   Colors.blue.shade700,   Icons.schedule_rounded,     'Waitlisted'),
      _            => (Colors.orange.shade50, Colors.orange.shade200, Colors.orange.shade700, Icons.pending_rounded,      'Pending Review'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: text),
          const SizedBox(width: 8),
          Text('My Registration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: text)),
          const Spacer(),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: text)),
        ]),
        const Divider(height: 14),
        Row(children: [
          Text('Role: ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Text(role, style: const TextStyle(fontSize: 13)),
        ]),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(note, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
        ],
        if (status == 'pending' || status == 'waitlisted') ...[
          const SizedBox(height: 10),
          Row(children: [
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 15),
              label: const Text('Edit', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: text, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
            ),
          ]),
        ],
      ]),
    );
  }
}

// ── Pending Card (admin) ──────────────────────────────────────────────────────

class _PendingCard extends StatelessWidget {
  final Map<String, dynamic> m;
  final VoidCallback onApprove;
  final VoidCallback onWaitlist;
  final VoidCallback onReject;
  const _PendingCard({required this.m, required this.onApprove, required this.onWaitlist, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final name = m['name'] as String? ?? '';
    final flat = m['flat'] as String? ?? '';
    final role = m['role'] as String? ?? '';
    final note = m['note'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 17, backgroundColor: Colors.orange.shade100,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text([if (flat.isNotEmpty) flat, role].where((s) => s.isNotEmpty).join('  ·  '),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)),
            child: Text('New', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.orange.shade800)),
          ),
        ]),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(8)),
            child: Text('"$note"', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
          ),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: onApprove,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green.shade700,
              side: BorderSide(color: Colors.green.shade400),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: const Text('Approve', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(
            onPressed: onWaitlist,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue.shade700,
              side: BorderSide(color: Colors.blue.shade300),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: const Text('Waitlist', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(
            onPressed: onReject,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade600,
              side: BorderSide(color: Colors.red.shade300),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: const Text('Reject', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          )),
        ]),
      ]),
    );
  }
}

// ── Card Action (inline chip button on volunteer cards) ──────────────────────

class _CardAction {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;
  const _CardAction({required this.label, required this.color, required this.onTap, this.icon});
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const _SectionHeader({required this.label, required this.count, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ),
    ]);
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
  final String eventName;
  final String eventTypeId;
  final bool isAdmin;
  final String status;
  final String residentFlat;

  const _ContributionsTab(
      {required this.eventId,
      this.eventName = 'Event',
      this.eventTypeId = '',
      required this.isAdmin,
      required this.status,
      this.residentFlat = ''});

  @override
  State<_ContributionsTab> createState() => _ContributionsTabState();
}

class _ContributionsTabState extends State<_ContributionsTab>
    with AutomaticKeepAliveClientMixin {
  // Keeps this tab's Firestore listeners + built widget tree alive when the
  // admin switches to another tab and back, instead of tearing down and
  // rebuilding the whole wing/block/flat hierarchy from scratch every time.
  @override
  bool get wantKeepAlive => true;

  // community_settings/address (wings/blocks/flats layout) is fetched once
  // here, independently of the contributions stream, so the wing/block/flat
  // hierarchy no longer waits on a nested StreamBuilder to resolve before it
  // can render.
  Map<String, dynamic> _settings = {};
  StreamSubscription<DocumentSnapshot>? _settingsSub;

  @override
  void initState() {
    super.initState();
    _settingsSub = FirebaseFirestore.instance
        .collection('community_settings')
        .doc('address')
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _settings = snap.data() ?? {};
        });
      }
    });
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    super.dispose();
  }

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
                          eventTypeId: widget.eventTypeId,
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
                                  eventTypeId: widget.eventTypeId,
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
                      // "Regular" (short form, e.g. from a CSV import) is a
                      // synonym for the canonical kTypeRegular string.
                      final rawCType = d['contributionType'] as String?;
                      final cType = (rawCType == null ||
                              rawCType.isEmpty ||
                              rawCType == 'Regular')
                          ? kTypeRegular
                          : rawCType;
                      final amt = (d['amount'] as num?)?.toDouble() ?? 0;
                      final rejReason = (d['rejectionReason'] ?? '').toString().trim();
                      final isAnonymous = d['isAnonymous'] == true;

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
                                    if (isAnonymous) ...[
                                      _anonymousBadge(),
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
                                  // Admins always see the real name — the
                                  // ANONYMOUS badge above is enough to remind
                                  // them not to share it with other residents.
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
                                    if (!isRejected && !isPending)
                                      IconButton(
                                        icon: Icon(Icons.download_rounded,
                                            color: AppTheme.accent.shade300,
                                            size: 17),
                                        onPressed: () => exportContributionReceipt(
                                          context: context,
                                          eventName: widget.eventName,
                                          docId: doc.id,
                                          contribution: d,
                                        ),
                                        tooltip: 'Download Receipt',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
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
    super.build(context); // required by AutomaticKeepAliveClientMixin
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appSettings')
          .doc('payments')
          .snapshots(),
      builder: (context, paySnap) {
        final payData = paySnap.data?.data() as Map<String, dynamic>? ?? {};
        final paymentsEnabled = List<String>.from(
                payData['enabledTypeIds'] as List? ?? [])
            .contains(widget.eventTypeId);

        return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('contributions')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          if (widget.isAdmin && !paymentsEnabled) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.payments_outlined,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('Payments aren\'t enabled for this event type yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(
                        'Enable Payments for this event type in Event Settings to start recording contributions.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EventTypeSettingsScreen()),
                      ),
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: const Text('Go to Event Settings'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ),
            );
          }
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
                              : Theme.of(context).cardColor,
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
          // Anonymous contributions are shown exclusively in the Anonymous
          // section below, not also under their wing/block/flat (or
          // Unassigned, which is also derived from flatDocs) — otherwise
          // the same amount visibly appears twice even though it's only
          // counted once in the grand total below.
          final flat = (d['flatNumber'] ?? '').toString().trim();
          if (flat.isNotEmpty && d['isAnonymous'] != true) {
            flatDocs.putIfAbsent(flat, () => []);
            flatDocs[flat]!.add(doc);
          }
          // Sponsorship amounts are often a nominal item value (e.g. a
          // donated idol) rather than cash the event actually collected, so
          // they're kept out of this Contributions tab total — they're
          // still shown individually in the Sponsored Contributions section
          // below.
          if (d['amountReceived'] == true && d['contributionType'] != kTypeSponsor) {
            grandTotal += (d['amount'] ?? 0).toDouble();
          }
          totalCount++;
        }

        {
          final settings = _settings;
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
                          final isAnonymous = d['isAnonymous'] == true;
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
                              color: isAdditional ? Colors.amber.shade50 : Theme.of(context).cardColor,
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
                                      Row(children: [
                                        Flexible(
                                          // Admins always see the real name here too —
                                          // the ANONYMOUS badge is the reminder, not a mask.
                                          child: Text(
                                            '$locationStr${name.isNotEmpty ? '  ·  $name' : ''}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13),
                                          ),
                                        ),
                                        if (isAnonymous) ...[
                                          const SizedBox(width: 4),
                                          _anonymousBadge(),
                                        ],
                                      ]),
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

                // ── Residents (Wing → Block → Flat hierarchy) ──────
                if (wings.isNotEmpty)
                  Builder(builder: (_) {
                    double residentsTotal = 0, residentsCash = 0, residentsOnline = 0;
                    for (final wing in wings) {
                      final raw = wingBlocks[wing];
                      if (raw is! Map) continue;
                      for (final block in raw.keys) {
                        final flatsList = raw[block];
                        if (flatsList is! List) continue;
                        for (final flat in flatsList) {
                          final docsForFlat = flatDocs[flat.toString()];
                          if (docsForFlat == null) continue;
                          for (final doc in docsForFlat) {
                            final d = doc.data() as Map<String, dynamic>;
                            if (d['amountReceived'] != true) continue;
                            final amt = (d['amount'] as num? ?? 0).toDouble();
                            residentsTotal += amt;
                            final mode = (d['paymentMode'] as String? ?? '').toLowerCase();
                            if (mode == 'cash') {
                              residentsCash += amt;
                            } else {
                              residentsOnline += amt;
                            }
                          }
                        }
                      }
                    }
                    return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade100),
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.green.shade50,
                        child: Icon(Icons.home_work_outlined,
                            color: Colors.green.shade600, size: 18),
                      ),
                      title: const Text('Residents',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${wings.length} wing${wings.length == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('₹${_fmt(residentsTotal)}',
                                  style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              if (residentsCash > 0 && residentsOnline > 0)
                                Text(
                                    'C:${_fmt(residentsCash)} · O:${_fmt(residentsOnline)}',
                                    style: TextStyle(
                                        fontSize: 9, color: Colors.blue.shade600))
                              else if (residentsCash > 0)
                                Text('Cash',
                                    style: TextStyle(
                                        fontSize: 9, color: Colors.amber.shade800))
                              else if (residentsOnline > 0)
                                Text('Online',
                                    style: TextStyle(
                                        fontSize: 9, color: Colors.blue.shade600)),
                            ],
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.expand_more),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Flat chip colour legend ─────────────
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
                              // ── Wing → Block → Flat chip hierarchy ──
                              for (final wing in wings) ...[
                                _buildWingTile(context, wing, wingBlocks,
                                    flatDocs, flatsPerFloor, flatGridRows),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                  }),

                // ── Sponsored Contributions ─────────────────────────
                Builder(builder: (_) {
                  final sponsorEntries = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return data['contributionType'] == kTypeSponsor &&
                        data['status'] != 'deleted' &&
                        data['isAnonymous'] != true;
                  }).toList();
                  if (sponsorEntries.isEmpty) return const SizedBox.shrink();

                  final sponsorTotal = sponsorEntries.fold<double>(0, (s, d) {
                    final data = d.data() as Map<String, dynamic>;
                    if (data['amountReceived'] != true) return s;
                    return s + (data['amount'] as num? ?? 0).toDouble();
                  });

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade100),
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.amber.shade50,
                        child: Icon(Icons.workspace_premium_outlined,
                            color: Colors.amber.shade800, size: 18),
                      ),
                      title: const Text('Sponsored Contributions',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${sponsorEntries.length} entr${sponsorEntries.length == 1 ? 'y' : 'ies'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('₹${_fmt(sponsorTotal)}',
                              style: TextStyle(
                                  color: Colors.amber.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          const SizedBox(width: 4),
                          const Icon(Icons.expand_more),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: sponsorEntries.map((doc) {
                              final d = doc.data() as Map<String, dynamic>;
                              final amt = (d['amount'] as num? ?? 0).toDouble();
                              final tier = (d['sponsorPackageName'] as String? ?? '').trim();
                              final item = (d['sponsorItem'] as String? ?? '').trim();
                              final isAnon = d['isAnonymous'] == true;
                              final name = (d['residentName'] as String? ?? '').trim();
                              final who = isAnon
                                  ? 'Anonymous'
                                  : (name.isNotEmpty ? name : 'Sponsor');
                              final subtitleParts = [
                                if (tier.isNotEmpty) tier,
                                if (item.isNotEmpty) 'for $item',
                              ];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.workspace_premium_outlined,
                                        size: 14, color: Colors.amber.shade600),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(who,
                                              style: const TextStyle(
                                                  fontSize: 13, fontWeight: FontWeight.w600)),
                                          if (subtitleParts.isNotEmpty)
                                            Text(subtitleParts.join(' · '),
                                                style: TextStyle(
                                                    fontSize: 11, color: Colors.grey.shade500)),
                                        ],
                                      ),
                                    ),
                                    Text('₹${_fmt(amt)}',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade800)),
                                    if (widget.isAdmin) ...[
                                      const SizedBox(width: 6),
                                      IconButton(
                                        icon: Icon(Icons.edit_outlined,
                                            color: Colors.blue.shade300, size: 16),
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
                                      const SizedBox(width: 6),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline,
                                            color: Colors.red.shade300, size: 16),
                                        onPressed: () => _ContributionsTabState
                                            ._deleteContribution(context, doc, d),
                                        tooltip: 'Delete',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // ── Carry Forward Contributions ────────────────────
                // Balances brought forward from other (any type) past events.
                Builder(builder: (_) {
                  final cfEntries = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return data['contributionType'] == kTypeCarryForward &&
                        data['status'] != 'deleted';
                  }).toList();
                  if (cfEntries.isEmpty) return const SizedBox.shrink();

                  final cfTotal = cfEntries.fold<double>(0, (s, d) {
                    final data = d.data() as Map<String, dynamic>;
                    return s + (data['amount'] as num? ?? 0).toDouble();
                  });

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blue.shade50,
                        child: Icon(Icons.move_up, color: Colors.blue.shade600, size: 18),
                      ),
                      title: const Text('Carry Forward Contributions',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${cfEntries.length} entr${cfEntries.length == 1 ? 'y' : 'ies'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('₹${_fmt(cfTotal)}',
                              style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          const SizedBox(width: 4),
                          const Icon(Icons.expand_more),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: cfEntries.map((doc) {
                              final d = doc.data() as Map<String, dynamic>;
                              final amt = (d['amount'] as num? ?? 0).toDouble();
                              final source =
                                  (d['carryForwardSourceEventName'] as String?)
                                              ?.trim()
                                              .isNotEmpty ==
                                          true
                                      ? d['carryForwardSourceEventName'] as String
                                      : 'Previous event';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.move_up, size: 14, color: Colors.blue.shade300),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('From: $source',
                                              style: const TextStyle(
                                                  fontSize: 13, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                    Text('₹${_fmt(amt)}',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade700)),
                                    if (widget.isAdmin) ...[
                                      const SizedBox(width: 6),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline,
                                            color: Colors.red.shade300, size: 16),
                                        onPressed: () => _ContributionsTabState
                                            ._deleteContribution(context, doc, d),
                                        tooltip: 'Delete',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // ── External Donations (admin only) ────────────────
                if (widget.isAdmin)
                  _ExternalDonationsWidget(eventId: widget.eventId, docs: docs),

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

                  double unassignedTotal = 0, unassignedCash = 0, unassignedOnline = 0;
                  for (final entry in unassigned) {
                    for (final doc in entry.value) {
                      final d = doc.data() as Map<String, dynamic>;
                      if (d['amountReceived'] != true) continue;
                      final amt = (d['amount'] as num? ?? 0).toDouble();
                      final mode = (d['paymentMode'] as String? ?? '').toLowerCase();
                      unassignedTotal += amt;
                      if (mode == 'cash') {
                        unassignedCash += amt;
                      } else {
                        unassignedOnline += amt;
                      }
                    }
                  }

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
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: false,
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('₹${_fmt(unassignedTotal)}',
                                  style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              if (unassignedCash > 0 && unassignedOnline > 0)
                                Text(
                                    'C:${_fmt(unassignedCash)} · O:${_fmt(unassignedOnline)}',
                                    style: TextStyle(
                                        fontSize: 9, color: Colors.blue.shade600))
                              else if (unassignedCash > 0)
                                Text('Cash',
                                    style: TextStyle(
                                        fontSize: 9, color: Colors.amber.shade800))
                              else if (unassignedOnline > 0)
                                Text('Online',
                                    style: TextStyle(
                                        fontSize: 9, color: Colors.blue.shade600)),
                            ],
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.expand_more),
                        ],
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

                // ── Anonymous Contributions ─────────────────────────
                Builder(builder: (_) {
                  final anonEntries = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return data['isAnonymous'] == true && data['status'] != 'deleted';
                  }).toList();
                  if (anonEntries.isEmpty) return const SizedBox.shrink();

                  double anonTotal = 0, anonCash = 0, anonOnline = 0;
                  for (final doc in anonEntries) {
                    final data = doc.data() as Map<String, dynamic>;
                    if (data['amountReceived'] != true) continue;
                    final amt = (data['amount'] as num? ?? 0).toDouble();
                    anonTotal += amt;
                    final mode = (data['paymentMode'] as String? ?? '').toLowerCase();
                    if (mode == 'cash') {
                      anonCash += amt;
                    } else {
                      anonOnline += amt;
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.shade100),
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.purple.shade50,
                        child: Icon(Icons.visibility_off_outlined,
                            color: Colors.purple.shade600, size: 18),
                      ),
                      title: const Text('Anonymous',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${anonEntries.length} entr${anonEntries.length == 1 ? 'y' : 'ies'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('₹${_fmt(anonTotal)}',
                                  style: TextStyle(
                                      color: Colors.purple.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              if (anonCash > 0 && anonOnline > 0)
                                Text('C:${_fmt(anonCash)} · O:${_fmt(anonOnline)}',
                                    style: TextStyle(fontSize: 9, color: Colors.blue.shade600))
                              else if (anonCash > 0)
                                Text('Cash',
                                    style: TextStyle(fontSize: 9, color: Colors.amber.shade800))
                              else if (anonOnline > 0)
                                Text('Online',
                                    style: TextStyle(fontSize: 9, color: Colors.blue.shade600)),
                            ],
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.expand_more),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: anonEntries.map((doc) {
                              final d = doc.data() as Map<String, dynamic>;
                              final amt = (d['amount'] as num? ?? 0).toDouble();
                              final flat = (d['flatNumber'] as String? ?? '').trim();
                              final pending = d['amountReceived'] != true;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.visibility_off_outlined,
                                        size: 14, color: Colors.purple.shade300),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              flat.isNotEmpty
                                                  ? 'Flat $flat  (hidden from residents)'
                                                  : 'Anonymous donor',
                                              style: const TextStyle(
                                                  fontSize: 13, fontWeight: FontWeight.w600)),
                                          if (pending)
                                            Text('Pending',
                                                style: TextStyle(
                                                    fontSize: 11, color: Colors.orange.shade700)),
                                        ],
                                      ),
                                    ),
                                    Text('₹${_fmt(amt)}',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple.shade700)),
                                    if (widget.isAdmin) ...[
                                      const SizedBox(width: 6),
                                      IconButton(
                                        icon: Icon(Icons.edit_outlined,
                                            color: Colors.blue.shade300, size: 16),
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
                                      const SizedBox(width: 6),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline,
                                            color: Colors.red.shade300, size: 16),
                                        onPressed: () => _ContributionsTabState
                                            ._deleteContribution(context, doc, d),
                                        tooltip: 'Delete',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ],
                                ),
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
        }
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
        color: Theme.of(context).cardColor,
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
                      style: TextStyle(fontSize: 9, color: Colors.blue.shade600))
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
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.purple.shade900)),
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
                        style: TextStyle(fontSize: 9, color: Colors.blue.shade600))
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
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      if (i > 0 && fromEnd % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Widget _typeBadge(String type) {
    String label;
    Color bg, fg;
    if (type == kTypeCarryForward) {
      label = 'Carry Fwd';
      bg = Colors.blue.shade50;
      fg = Colors.blue.shade700;
    } else if (type == kTypeExternal) {
      label = 'External';
      bg = Colors.teal.shade50;
      fg = Colors.teal.shade700;
    } else if (type == kTypeSponsor) {
      label = 'Sponsor';
      bg = Colors.amber.shade50;
      fg = Colors.amber.shade800;
    } else {
      // Ganesh Laddu (legacy) and any custom special-contribution
      // description all read as a generic "Special" badge.
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

  Widget _anonymousBadge() => Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.visibility_off_outlined, size: 9, color: Colors.indigo.shade700),
          const SizedBox(width: 2),
          Text('ANONYMOUS',
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade700)),
        ]),
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
    if (d['amountReceived'] != false && d['contributionType'] != kTypeSponsor) {
      final eventRef = FirebaseFirestore.instance
          .collection('events')
          .doc(doc.reference.parent.parent!.id);
      batch.update(eventRef, {'totalCollected': FieldValue.increment(-amt)});
    }
    // Carry-forward contributions are mirrored by a transfer-audit record on
    // the SOURCE event — reverse it too, so that event's available-to-carry
    // balance frees back up instead of staying permanently locked.
    DocumentReference? sourceRefToRecalc;
    if (d['contributionType'] == kTypeCarryForward &&
        (d['carryForwardSourceEventId'] as String?)?.isNotEmpty == true) {
      final sourceRef = FirebaseFirestore.instance
          .collection('events')
          .doc(d['carryForwardSourceEventId'] as String);
      final transferId = d['carryForwardTransferId'] as String?;
      if (transferId != null && transferId.isNotEmpty) {
        batch.update(sourceRef.collection('carryForwardTransfers').doc(transferId),
            {'reversed': true});
        sourceRefToRecalc = sourceRef;
      } else {
        // Legacy transfer, created before the destination contribution and
        // source transfer record were linked by ID — best-effort match on
        // destination event + amount so older records can still be reversed.
        final destEventId = doc.reference.parent.parent!.id;
        final legacyMatch = await sourceRef
            .collection('carryForwardTransfers')
            .where('destEventId', isEqualTo: destEventId)
            .where('amount', isEqualTo: amt)
            .get();
        // Firestore != queries exclude docs missing the field entirely, so
        // filter "not already reversed" client-side instead — legacy docs
        // never had a 'reversed' field, and missing means still active.
        final stillActive =
            legacyMatch.docs.where((t) => t.data()['reversed'] != true).toList();
        if (stillActive.isNotEmpty) {
          batch.update(stillActive.first.reference, {'reversed': true});
          sourceRefToRecalc = sourceRef;
        }
      }
    }
    await batch.commit();
    // Recompute the source event's locked balance fresh from its transfer
    // records (like Recalculate Carry-Forward Balance) instead of trusting
    // FieldValue.increment — makes every delete self-healing, so the source
    // event is reliably selectable again in Carry Forward Balance right
    // after this, with no manual recalculation step needed.
    if (sourceRefToRecalc != null) {
      final transfers = await sourceRefToRecalc.collection('carryForwardTransfers').get();
      double locked = 0;
      for (final t in transfers.docs) {
        final td = t.data();
        if (td['reversed'] != true) locked += (td['amount'] as num? ?? 0).toDouble();
      }
      await sourceRefToRecalc.update({'carriedForwardOut': locked});
    }
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
  final String eventTypeId;
  final bool isAdmin;
  final String status;

  const _ExpensesTab(
      {required this.eventId,
      this.eventTypeId = '',
      required this.isAdmin,
      required this.status});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: !isAdmin && eventTypeId.isNotEmpty
          ? FirebaseFirestore.instance
              .collection('eventTypeConfig')
              .doc(eventTypeId)
              .snapshots()
          : const Stream<DocumentSnapshot>.empty(),
      builder: (context, configSnap) {
        final configData = configSnap.data?.data() as Map<String, dynamic>?;
        final enabledSections = residentTabSectionsFor(configData, 'expenses');
        bool sectionVisible(String id) => isAdmin || enabledSections.contains(id);

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
            if (sectionVisible('expenses_summary')) ...[
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
            ],

            // Category breakdown
            if (sectionVisible('expenses_by_category')) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
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
                            Text(_expenseCategoryIcon(e.key),
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
            ],

            if (sectionVisible('expenses_list'))
              _ExpensesByDateList(
                docs: docs,
                isAdmin: isAdmin,
                eventId: eventId,
                eventTypeId: eventTypeId,
              ),
          ],
        );
      },
    );
      },
    );
  }
}

String _expenseDateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _expenseDateLabel(DateTime d) {
  const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month]} ${d.year}';
}

void _showExpenseReceiptFullScreen(BuildContext context, String url) {
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

String _expenseCategoryIcon(String cat) {
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

// ── Expenses grouped by date, collapsible per day ────────────────────────────
// Only the current date's group starts expanded; every other date starts
// collapsed. The expand/collapse choice is computed once per mount (not
// recomputed on every live-stream update), so a user's manual toggles
// survive new expenses arriving elsewhere.

class _ExpensesByDateList extends StatefulWidget {
  final List<QueryDocumentSnapshot> docs;
  final bool isAdmin;
  final String eventId;
  final String eventTypeId;

  const _ExpensesByDateList({
    required this.docs,
    required this.isAdmin,
    required this.eventId,
    required this.eventTypeId,
  });

  @override
  State<_ExpensesByDateList> createState() => _ExpensesByDateListState();
}

class _ExpensesByDateListState extends State<_ExpensesByDateList> {
  Set<String>? _expandedKeys;

  @override
  Widget build(BuildContext context) {
    final Map<String, List<QueryDocumentSnapshot>> grouped = {};
    final orderedKeys = <String>[];
    for (final doc in widget.docs) {
      final d = doc.data() as Map<String, dynamic>;
      final dt = DateTime.tryParse(d['addedAt'] as String? ?? '') ?? DateTime.now();
      final key = _expenseDateKey(dt);
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
        orderedKeys.add(key);
      }
      grouped[key]!.add(doc);
    }

    _expandedKeys ??= {
      if (grouped.containsKey(_expenseDateKey(DateTime.now())))
        _expenseDateKey(DateTime.now()),
    };

    return Column(
      children: [
        for (final key in orderedKeys) ...[
          _buildDateSection(context, key, grouped[key]!),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildDateSection(
      BuildContext context, String key, List<QueryDocumentSnapshot> docs) {
    final expanded = _expandedKeys!.contains(key);
    final parts = key.split('-').map(int.parse).toList();
    final dt = DateTime(parts[0], parts[1], parts[2]);
    final isToday = key == _expenseDateKey(DateTime.now());
    final subtotal = docs.fold<double>(0,
        (s, doc) => s + ((doc.data() as Map<String, dynamic>)['amount'] ?? 0).toDouble());

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: expanded ? Radius.zero : const Radius.circular(12),
            ),
            onTap: () => setState(() {
              expanded ? _expandedKeys!.remove(key) : _expandedKeys!.add(key);
            }),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 15, color: Colors.red.shade400),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(isToday ? 'Today — ${_expenseDateLabel(dt)}' : _expenseDateLabel(dt),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Text('₹${subtotal.toStringAsFixed(0)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                      const SizedBox(width: 6),
                      Icon(expanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey.shade500),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 23),
                    child: Text('${docs.length} expense${docs.length == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                children: docs.map((doc) => _expenseCard(context, doc)).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _expenseCard(BuildContext context, QueryDocumentSnapshot doc) {
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.red.shade50,
            child: Text(
                (d['categoryIcon'] as String?)?.isNotEmpty == true
                    ? d['categoryIcon']
                    : _expenseCategoryIcon(d['category'] ?? 'Misc'),
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
              Text(
                '₹${(d['amount'] ?? 0).toStringAsFixed(0)}',
                style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              if (receiptUrl != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showExpenseReceiptFullScreen(context, receiptUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(receiptUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Icon(Icons.receipt, color: Colors.grey.shade400)),
                  ),
                ),
              ],
              if (widget.isAdmin) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddExpenseScreen(
                        eventId: widget.eventId,
                        eventTypeId: widget.eventTypeId,
                        existingExpenseId: doc.id,
                        existingData: d,
                      ),
                    ),
                  ),
                  child: Icon(Icons.edit, size: 18, color: Colors.grey.shade400),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

// ── Resident's small "Contribute" pill — sits beside the event name ────────────
// Label/color change based on payment-enabled state, event lifecycle, and
// whether the resident has already contributed to this event.

class _ResidentContributeButton extends StatelessWidget {
  final String eventId;
  final String eventName;
  final String eventTypeId;
  final String status; // 'active' | 'closed'
  final String startDate; // 'd/M/yyyy' or ''
  final String flatNumber;
  final String residentName;

  const _ResidentContributeButton({
    required this.eventId,
    required this.eventName,
    required this.eventTypeId,
    required this.status,
    required this.startDate,
    required this.flatNumber,
    required this.residentName,
  });

  DateTime? _parseDate(String s) {
    final parts = s.split('/');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  void _openSheet(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SelfReportSheet(
          eventId: eventId,
          eventName: eventName,
          flatNumber: flatNumber,
          residentName: residentName,
          onSubmitted: () {},
        ),
      );

  Widget _pill(BuildContext context, String label, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('appSettings').doc('payments').snapshots(),
      builder: (context, paySnap) {
        final payData = paySnap.data?.data() as Map<String, dynamic>? ?? {};
        final enabledTypeIds = List<String>.from(payData['enabledTypeIds'] as List? ?? []);
        if (!enabledTypeIds.contains(eventTypeId)) return const SizedBox.shrink();

        if (status == 'closed') {
          return _pill(context, 'Contributions Closed', Colors.grey.shade500);
        }
        if (status == 'upcoming') {
          return _pill(context, 'Contributions open soon', Colors.amber.shade700);
        }

        final start = _parseDate(startDate);
        if (start != null && DateTime.now().isBefore(start)) {
          return _pill(context, 'Contributions open soon', Colors.amber.shade700);
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('events').doc(eventId)
              .collection('contributions')
              .where('flatNumber', isEqualTo: flatNumber)
              .snapshots(),
          builder: (context, contribSnap) {
            final hasAny = (contribSnap.data?.docs ?? []).any(
                (d) => (d.data() as Map<String, dynamic>)['status'] != 'deleted');
            return hasAny
                ? _pill(context, 'Contribute More', Colors.blue.shade700,
                    onTap: () => _openSheet(context))
                : _pill(context, 'Contribute Now', Colors.green.shade600,
                    onTap: () => _openSheet(context));
          },
        );
      },
    );
  }
}

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
        color: Theme.of(context).cardColor,
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

  // Prepends the community's configured country code to a locally-stored
  // number (e.g. "8886110823" → "918886110823"). Numbers already fully
  // qualified are left untouched: a leading '+' (Firebase Auth's E.164
  // format) is treated as already-complete, and so is anything longer than
  // a typical 10-digit local mobile number.
  String _normalizePhoneWithCountryCode(String raw, String countryCode) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.trim().startsWith('+')) return digits;
    if (digits.length > 10) return digits;
    return '$countryCode$digits';
  }

  Future<void> _launchWhatsApp(BuildContext context, String message, {String? phone}) async {
    final encoded = Uri.encodeComponent(message);
    final digits = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return; // WhatsApp button is disabled without a registered number
    final uri = Uri.parse('https://wa.me/$digits?text=$encoded');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not open WhatsApp. Is it installed?'),
        backgroundColor: Colors.red,
      ));
    }
  }

  // scopeTitle appears in the dialog header (e.g. "A Wing", "A Wing – Block 1",
  // "Flat A101"); scopeDescription is used inline in the reminder message text
  // (e.g. "A Wing", "A Wing – Block 1"). isPaidFlat softens the wording for a
  // flat that has already paid (admin explicitly selected it, so it isn't a
  // payment-chasing reminder). The WhatsApp button only works — and is only
  // enabled — when a registered phone number is known for the target flat;
  // bulk wing/block reminders never have a single number, so it's always
  // disabled there and Copy is the only option.
  void _sendReminderDialog(
    BuildContext context,
    String scopeTitle,
    String scopeDescription,
    List<String> flats, {
    bool isPaidFlat = false,
    String? phone,
    double amountReceived = 0,
  }) {
    final hasPhone = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '').isNotEmpty;
    final flatList = flats.join(', ');
    final isSingle = flats.length == 1;
    final message = isPaidFlat
        ? 'Hi, thank you for your contribution to "$eventName"! We have received '
            '₹${amountReceived.toStringAsFixed(0)} from $scopeDescription. '
            'Please reach out to the admin if you have any questions. Thank you!'
        : 'Hi, this is a reminder for your contribution to "$eventName". '
            '${isSingle ? 'Your flat' : 'The following flats'} in $scopeDescription '
            '${isSingle ? 'has' : 'are'} not yet paid: $flatList. '
            'Please make the payment at the earliest. Thank you!';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(isPaidFlat ? Icons.chat_outlined : Icons.notifications_active,
              color: AppTheme.accent, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text('${isPaidFlat ? 'Message' : 'Reminder'} — $scopeTitle')),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${flats.length} flat${flats.length == 1 ? '' : 's'}: $flatList',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 13, height: 1.4, color: Colors.black87)),
            ),
            const SizedBox(height: 8),
            Text(
                hasPhone
                    ? 'Sends directly to the resident on file for this flat.'
                    : 'No phone number on file — WhatsApp is disabled. Copy the message instead.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'Message copied for ${flats.length} flat${flats.length == 1 ? '' : 's'}'),
                backgroundColor: AppTheme.accent,
                duration: const Duration(seconds: 2),
              ));
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy'),
          ),
          Tooltip(
            message: hasPhone ? '' : 'No phone number on file for this flat',
            child: ElevatedButton.icon(
              onPressed: hasPhone
                  ? () {
                      Navigator.pop(ctx);
                      _launchWhatsApp(context, message, phone: phone);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade500,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.chat, size: 16),
              label: const Text('WhatsApp'),
            ),
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

            // flat → 'paid' | 'pending', and flat → total amount received
            // (for the "thank you, we received ₹X" message on paid flats/blocks)
            final Map<String, String> flatStatus = {};
            final Map<String, double> flatAmount = {};
            for (final doc in contribDocs) {
              final d = doc.data() as Map<String, dynamic>;
              if (d['status'] == 'deleted' || d['status'] == 'rejected') continue;
              final flat = (d['flatNumber'] as String?)?.trim() ?? '';
              if (flat.isEmpty) continue;
              final received = d['amountReceived'] != false;
              final amt = (d['amount'] as num?)?.toDouble() ?? 0;
              if (received) flatAmount[flat] = (flatAmount[flat] ?? 0) + amt;
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

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, usersSnap) {
                final countryCode =
                    (settings['countryCode'] as String?) ?? kDefaultCountryDialCode;

                // flat → phone (normalized with the community's country code),
                // for direct WhatsApp targeting
                final Map<String, String> flatPhone = {};
                for (final doc in usersSnap.data?.docs ?? <QueryDocumentSnapshot>[]) {
                  final u = doc.data() as Map<String, dynamic>;
                  final flat = (u['flatNumber'] as String?)?.trim() ?? '';
                  final rawPhone = (u['phone'] as String?)?.trim() ?? '';
                  if (flat.isNotEmpty && rawPhone.isNotEmpty) {
                    flatPhone[flat] = _normalizePhoneWithCountryCode(rawPhone, countryCode);
                  }
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

                    // Wing tiles
                    for (final wing in wings) ...[
                      _buildWingTile(context, wing, wingBlocks, flatStatus,
                          flatsPerFloor, flatGridRows, flatPhone, flatAmount),
                    ],
                  ],
                );
              },
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
    Map<String, String> flatPhone,
    Map<String, double> flatAmount,
  ) {
    final raw = wingBlocks[wing];
    final wingData =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final blocks = wingData.keys.toList()..sort();
    if (blocks.isEmpty) return const SizedBox.shrink();

    final wingUnpaidFlats = <String>[];
    final wingAllFlats = <String>[];
    double wingPaidAmount = 0;
    for (final block in blocks) {
      final flats = List<String>.from(
          wingData[block] is List ? wingData[block] : []);
      for (final f in flats) {
        wingAllFlats.add(f);
        final s = flatStatus[f];
        if (s == null || s == 'pending') {
          wingUnpaidFlats.add(f);
        } else {
          wingPaidAmount += flatAmount[f] ?? 0;
        }
      }
    }
    if (wingAllFlats.isEmpty) return const SizedBox.shrink();
    final wingUnpaid = wingUnpaidFlats.length;
    final wingFullyPaid = wingUnpaid == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
          backgroundColor: wingFullyPaid ? Colors.green.shade600 : Colors.blue.shade600,
          child: Text(wing[0].toUpperCase(),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Text('$wing Wing',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          wingFullyPaid
              ? 'All flats paid ✓'
              : '$wingUnpaid flat${wingUnpaid == 1 ? '' : 's'} pending',
          style: TextStyle(
              color: wingFullyPaid ? Colors.green.shade700 : Colors.orange.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                  wingFullyPaid ? Icons.celebration_outlined : Icons.notifications_active_outlined,
                  color: wingFullyPaid ? Colors.green.shade600 : AppTheme.accent.shade400,
                  size: 20),
              tooltip: wingFullyPaid ? 'Send Thank You to whole wing' : 'Send Reminder to whole wing',
              onPressed: () => wingFullyPaid
                  ? _sendReminderDialog(context, '$wing Wing', '$wing Wing', wingAllFlats,
                      isPaidFlat: true, amountReceived: wingPaidAmount)
                  : _sendReminderDialog(context, '$wing Wing', '$wing Wing', wingUnpaidFlats),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
            ),
            Icon(Icons.expand_more, color: Colors.grey.shade500),
          ],
        ),
        children: blocks
            .map((block) => _buildBlockTile(context, wing, block, wingData,
                flatStatus, flatsPerFloor, flatGridRows, flatPhone, flatAmount))
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
    Map<String, String> flatPhone,
    Map<String, double> flatAmount,
  ) {
    final flats = List<String>.from(
        wingData[block] is List ? wingData[block] : [])
      ..sort();
    final fpf = flatsPerFloor['${wing}_$block'];
    final gridRows = (flatGridRows['${wing}_$block'] ?? 1).clamp(1, 3);

    if (flats.isEmpty) return const SizedBox.shrink();
    final unpaidFlats = flats
        .where((f) => flatStatus[f] == null || flatStatus[f] == 'pending')
        .toList();
    final blockUnpaid = unpaidFlats.length;
    final blockFullyPaid = blockUnpaid == 0;
    final blockPaidAmount = blockFullyPaid
        ? flats.fold<double>(0, (s, f) => s + (flatAmount[f] ?? 0))
        : 0.0;

    final pendingCount =
        flats.where((f) => flatStatus[f] == 'pending').length;
    final notRecordedCount =
        flats.where((f) => flatStatus[f] == null).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: blockFullyPaid ? Colors.green.shade50 : Colors.purple.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: blockFullyPaid ? Colors.green.shade100 : Colors.purple.shade100),
        ),
        child: ExpansionTile(
          key: PageStorageKey('followup_block_${wing}_$block'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          controlAffinity: ListTileControlAffinity.leading,
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: blockFullyPaid ? Colors.green.shade100 : Colors.purple.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(block,
                  style: TextStyle(
                      color: blockFullyPaid ? Colors.green.shade800 : Colors.purple.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ),
          title: Text('Block $block',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: blockFullyPaid ? Colors.green.shade900 : Colors.purple.shade900)),
          subtitle: blockFullyPaid
              ? Text('All paid ✓ · ₹${blockPaidAmount.toStringAsFixed(0)} received',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade700))
              : Row(children: [
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
            icon: Icon(
                blockFullyPaid ? Icons.celebration_outlined : Icons.notifications_active_outlined,
                color: blockFullyPaid ? Colors.green.shade600 : AppTheme.accent.shade400,
                size: 20),
            tooltip: blockFullyPaid ? 'Send Thank You' : 'Send Reminder',
            onPressed: () => blockFullyPaid
                ? _sendReminderDialog(
                    context, '$wing Wing – Block $block', '$wing Wing – Block $block', flats,
                    isPaidFlat: true, amountReceived: blockPaidAmount)
                : _sendReminderDialog(
                    context, '$wing Wing – Block $block', '$wing Wing – Block $block', unpaidFlats),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: _buildFlatChips(context, wing, block, flats, flatStatus, fpf,
                  gridRows, flatPhone, flatAmount),
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
    Map<String, String> flatStatus,
    int? fpf,
    int gridRows,
    Map<String, String> flatPhone,
    Map<String, double> flatAmount,
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
      final container = Container(
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
      return GestureDetector(
        onTap: () => _sendReminderDialog(
            context, 'Flat $flat', '$wing Wing – Block $block', [flat],
            isPaidFlat: s == 'paid', phone: flatPhone[flat],
            amountReceived: flatAmount[flat] ?? 0),
        child: container,
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
                color: AppTheme.accent, size: 22),
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
                  style: const TextStyle(
                      fontSize: 13, height: 1.4, color: Colors.black87)),
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
                  backgroundColor: AppTheme.accent,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
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
            color: Theme.of(context).cardColor,
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
                      color: AppTheme.accent.shade400),
                  tooltip: 'Send Reminder',
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.accent.shade50,
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

// ── My Tasks Section (resident) — tasks assigned to this resident's flat,
// shown inside the Volunteers tab since residents have no dedicated Tasks tab ──

class _MyTasksSection extends StatelessWidget {
  final String eventId;
  final String flat;
  final String name;
  const _MyTasksSection({required this.eventId, required this.flat, required this.name});

  @override
  Widget build(BuildContext context) {
    if (flat.isEmpty) return const SizedBox();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('tasks')
          .where('assigneeFlats', arrayContains: flat)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox();
        final docs = snap.data!.docs;
        final pending = docs.where((d) => (d.data() as Map)['status'] != kTaskStatusDone).length;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.checklist, size: 18, color: AppTheme.accent),
                const SizedBox(width: 8),
                const Text('My Tasks', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const Spacer(),
                if (pending > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(20)),
                    child: Text('$pending pending', style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
                  ),
              ]),
              const SizedBox(height: 10),
              ...docs.map((doc) => _TaskCard(
                    eventId: eventId,
                    taskId: doc.id,
                    data: doc.data() as Map<String, dynamic>,
                    isAdmin: false,
                    viewerFlat: flat,
                    viewerName: name,
                  )),
            ],
          ),
        );
      },
    );
  }
}

// ── Tasks Tab (admin only) — birds-eye view of task management ──────────────

class _TasksTab extends StatefulWidget {
  final String eventId;
  const _TasksTab({required this.eventId});
  @override
  State<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<_TasksTab> {
  String _statusFilter = 'all'; // all | pending | in_progress | done

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .collection('tasks')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final allTasks = snap.data!.docs;

          if (allTasks.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.checklist_outlined, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No tasks yet',
                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Create tasks and assign them to your volunteers.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ]),
              ),
            );
          }

          int pending = 0, inProgress = 0, done = 0, overdue = 0;
          final now = DateTime.now();
          for (final doc in allTasks) {
            final d = doc.data() as Map<String, dynamic>;
            final status = d['status'] as String? ?? kTaskStatusPending;
            if (status == kTaskStatusPending) {
              pending++;
            } else if (status == kTaskStatusInProgress) {
              inProgress++;
            } else if (status == kTaskStatusDone) {
              done++;
            }
            final due = d['dueDate'];
            if (due is Timestamp && status != kTaskStatusDone && due.toDate().isBefore(now)) overdue++;
          }

          final filtered = _statusFilter == 'all'
              ? allTasks
              : allTasks.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == _statusFilter).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              Row(children: [
                Expanded(child: _TaskStat(label: 'Total', value: '${allTasks.length}', color: AppTheme.accent)),
                const SizedBox(width: 8),
                Expanded(child: _TaskStat(label: 'Pending', value: '$pending', color: Colors.blueGrey)),
                const SizedBox(width: 8),
                Expanded(child: _TaskStat(label: 'In Progress', value: '$inProgress', color: Colors.orange)),
                const SizedBox(width: 8),
                Expanded(child: _TaskStat(label: 'Done', value: '$done', color: Colors.green)),
              ]),
              if (overdue > 0) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Text('$overdue task${overdue == 1 ? '' : 's'} overdue',
                        style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _filterChip('all', 'All'),
                  const SizedBox(width: 8),
                  _filterChip(kTaskStatusPending, 'Pending'),
                  const SizedBox(width: 8),
                  _filterChip(kTaskStatusInProgress, 'In Progress'),
                  const SizedBox(width: 8),
                  _filterChip(kTaskStatusDone, 'Done'),
                ]),
              ),
              const SizedBox(height: 12),
              ...filtered.map((doc) => _TaskCard(
                    eventId: widget.eventId,
                    taskId: doc.id,
                    data: doc.data() as Map<String, dynamic>,
                    isAdmin: true,
                  )),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'create_task',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TaskFormScreen(eventId: widget.eventId)),
        ),
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Create Task', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _statusFilter = value),
    );
  }
}

class _TaskStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _TaskStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ]),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final String eventId;
  final String taskId;
  final Map<String, dynamic> data;
  final bool isAdmin;
  final String viewerFlat;
  final String viewerName;
  const _TaskCard({
    required this.eventId,
    required this.taskId,
    required this.data,
    required this.isAdmin,
    this.viewerFlat = '',
    this.viewerName = '',
  });

  static String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '';
    final status = data['status'] as String? ?? kTaskStatusPending;
    final due = data['dueDate'];
    final dueDate = due is Timestamp ? due.toDate() : null;
    final overdue = dueDate != null && status != kTaskStatusDone && dueDate.isBefore(DateTime.now());
    final assignees = List<Map<String, dynamic>>.from(data['assignees'] as List? ?? []);
    final checklist = List<dynamic>.from(data['checklist'] as List? ?? []);
    final checklistDone = checklist.where((c) => (c as Map)['done'] == true).length;
    final dependsOn = List<String>.from(data['dependsOn'] as List? ?? []);

    return GestureDetector(
      onTap: () => showTaskDetailSheet(context,
          eventId: eventId, taskId: taskId, isAdmin: isAdmin, viewerFlat: viewerFlat, viewerName: viewerName),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: taskStatusColor(status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(taskStatusLabel(status),
                    style: TextStyle(fontSize: 11, color: taskStatusColor(status), fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 4, children: [
              if (assignees.isNotEmpty)
                _metaRow(Icons.person_outline,
                    assignees.map((a) => a['name']).join(', '), Colors.grey.shade600),
              if (dueDate != null)
                _metaRow(Icons.calendar_today_outlined, _fmtDate(dueDate),
                    overdue ? Colors.red : Colors.grey.shade600),
              if (checklist.isNotEmpty)
                _metaRow(Icons.checklist, '$checklistDone/${checklist.length}', Colors.grey.shade600),
              if (dependsOn.isNotEmpty)
                _metaRow(Icons.link, '${dependsOn.length} dependency', Colors.grey.shade600),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(IconData icon, String text, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: color)),
        ],
      );
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
  String _flatFilter = '';
  bool _autoExpanded = false; // expand current month on first data load
  DateTime? _dateFilter;
  String _wingFilter = '';
  String _blockFilter = '';
  String _statusFilter = ''; // '', 'confirmed', 'rejected', 'deleted', 'submitted'
  String _lastFilterSignature = '';

  Map<String, dynamic> _wingBlocks = {};
  List<String> _wings = [];

  static const Map<String, String> _statusLabels = {
    'confirmed': 'Confirmed / Approved',
    'rejected': 'Rejected',
    'deleted': 'Deleted',
    'submitted': 'Submitted (Pending)',
    'external': 'External Donation',
    'anonymous': 'Anonymous',
  };

  @override
  void initState() {
    super.initState();
    _fetchWingBlockSettings();
  }

  Future<void> _fetchWingBlockSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('community_settings')
          .doc('address')
          .get();
      if (!mounted) return;
      final data = doc.data() as Map<String, dynamic>? ?? {};
      setState(() {
        _wingBlocks = Map<String, dynamic>.from(data['wingBlocks'] as Map? ?? {});
        _wings = List<String>.from(
            data['wings'] as List? ?? (_wingBlocks.keys.toList()..sort()));
      });
    } catch (_) {
      // Keep empty defaults; pickers will just show nothing to choose from.
    }
  }

  // Blocks configured for the currently-selected wing filter (empty = all wings' blocks)
  List<String> get _blocksForSelectedWing {
    if (_wingFilter.isEmpty) {
      final all = <String>{};
      for (final v in _wingBlocks.values) {
        all.addAll(Map<String, dynamic>.from(v as Map? ?? {}).keys);
      }
      return all.toList()..sort();
    }
    final raw = _wingBlocks[_wingFilter];
    if (raw == null) return [];
    return (Map<String, dynamic>.from(raw as Map).keys.toList())..sort();
  }

  // Flat numbers available for the currently-selected wing/block filters
  List<String> get _flatsForSelectedFilters {
    final flats = <String>{};
    void addFromBlockMap(Map<String, dynamic> blockMap) {
      if (_blockFilter.isNotEmpty) {
        final list = blockMap[_blockFilter];
        if (list != null) flats.addAll(List<String>.from(list as List));
      } else {
        for (final list in blockMap.values) {
          flats.addAll(List<String>.from(list as List? ?? []));
        }
      }
    }

    if (_wingFilter.isNotEmpty) {
      final raw = _wingBlocks[_wingFilter];
      if (raw != null) addFromBlockMap(Map<String, dynamic>.from(raw as Map));
    } else {
      for (final raw in _wingBlocks.values) {
        addFromBlockMap(Map<String, dynamic>.from(raw as Map? ?? {}));
      }
    }
    final sorted = flats.toList()
      ..sort((a, b) {
        final na = int.tryParse(RegExp(r'\d+').firstMatch(a)?.group(0) ?? '');
        final nb = int.tryParse(RegExp(r'\d+').firstMatch(b)?.group(0) ?? '');
        if (na != null && nb != null) return na.compareTo(nb);
        return a.compareTo(b);
      });
    return sorted;
  }

  Future<String?> _showPickerSheet({
    required String title,
    required List<String> options,
    required String current,
    bool allowClear = true,
  }) {
    final searchCtrl = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => StatefulBuilder(
          builder: (ctx, setSheetState) {
            final query = searchCtrl.text.trim().toLowerCase();
            final filtered = query.isEmpty
                ? options
                : options.where((o) => o.toLowerCase().contains(query)).toList();
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: searchCtrl,
                      autofocus: false,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search…',
                        isDense: true,
                        prefixIcon: const Icon(Icons.search, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        if (allowClear)
                          ListTile(
                            title: const Text('All'),
                            trailing: current.isEmpty
                                ? Icon(Icons.check, color: AppTheme.accent)
                                : null,
                            onTap: () => Navigator.pop(ctx, ''),
                          ),
                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text('No matches',
                                style: TextStyle(color: Colors.grey.shade400)),
                          ),
                        ...filtered.map((o) => ListTile(
                              title: Text(o),
                              trailing: current == o
                                  ? Icon(Icons.check, color: AppTheme.accent)
                                  : null,
                              onTap: () => Navigator.pop(ctx, o),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _restore(DocumentReference ref, Map<String, dynamic> e) async {
    final rawData = e['data'] as Map<String, dynamic>?;
    // Self-reported contributions go through admin verification, so a
    // restore intentionally drops them back to pending for re-review.
    // Admin-added types (Regular/Special/Anonymous/External/Sponsor/Carry
    // Forward/Imported) never had that workflow — restoring them should put
    // them back exactly as they were, not force a fake 'pending' state that
    // desyncs amountReceived from totalCollected.
    final selfReported = rawData?['selfReported'] == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Contribution'),
        content: Text(
            'Restore ₹${(e['amt'] as double).toStringAsFixed(0)} for ${e['flat']}?\n\n'
            '${selfReported ? 'The contribution will be marked as pending for admin review.' : 'The contribution will be restored to its previous state.'}'),
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
    final now = DateTime.now().toIso8601String();
    // Mirror the delete path's own condition ('!= false', i.e. counted
    // unless explicitly marked not-received) instead of a strict '== true'
    // check, so a missing/null preDeleteAmountReceived can't silently drop
    // the amount out of totalCollected on restore.
    final wasConfirmed = e['preDeleteAmountReceived'] != false;
    final restoredStatus = selfReported
        ? 'pending'
        : ((e['preDeleteStatus'] as String?)?.isNotEmpty == true
            ? e['preDeleteStatus'] as String
            : 'confirmed');
    final update = <String, dynamic>{
      'status': restoredStatus,
      'amountReceived': selfReported ? false : wasConfirmed,
      'deletedAt': FieldValue.delete(),
      'preDeleteStatus': FieldValue.delete(),
      'preDeleteAmountReceived': FieldValue.delete(),
      'restoredAt': now,
    };
    final batch = FirebaseFirestore.instance.batch();
    batch.update(ref, update);
    // Carry-forward: un-reverse the linked transfer-audit record on the
    // source event so its available-to-carry balance goes back down again.
    if (rawData?['contributionType'] == kTypeCarryForward &&
        (rawData?['carryForwardSourceEventId'] as String?)?.isNotEmpty == true &&
        (rawData?['carryForwardTransferId'] as String?)?.isNotEmpty == true) {
      final sourceRef = FirebaseFirestore.instance
          .collection('events')
          .doc(rawData!['carryForwardSourceEventId'] as String);
      batch.update(
          sourceRef.collection('carryForwardTransfers').doc(rawData['carryForwardTransferId'] as String),
          {'reversed': false});
      batch.update(sourceRef, {'carriedForwardOut': FieldValue.increment(e['amt'] as double)});
    }
    await batch.commit();
    // Recompute totalCollected from scratch (like Recalculate Totals) rather
    // than trusting FieldValue.increment — guarantees the restored amount is
    // reflected correctly regardless of any prior increment/decrement drift.
    if (wasConfirmed) {
      final eventId = ref.parent.parent!.id;
      final eventRef = FirebaseFirestore.instance.collection('events').doc(eventId);
      final contribs = await eventRef.collection('contributions').get();
      double total = 0;
      for (final doc in contribs.docs) {
        final cd = doc.data();
        if (cd['status'] == 'deleted') continue;
        if (cd['selfReported'] == true && cd['amountReceived'] != true) continue;
        if (cd['amountReceived'] == true && cd['contributionType'] != kTypeSponsor) {
          total += (cd['amount'] as num? ?? 0).toDouble();
        }
      }
      await eventRef.update({'totalCollected': total});
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(selfReported
              ? 'Contribution restored to pending'
              : 'Contribution restored')));
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
      'revertedAt': DateTime.now().toIso8601String(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rejection reverted — contribution is pending again')));
    }
  }

  Future<void> _deleteRejected(DocumentReference ref, Map<String, dynamic> e) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Rejected Contribution'),
        content: Text(
            'Permanently remove this rejected ₹${(e['amt'] as double).toStringAsFixed(0)} entry for ${e['flat']}? '
            'It was never counted toward total collected, so nothing else is affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.update({
      'status': 'deleted',
      'deletedAt': DateTime.now().toIso8601String(),
      'preDeleteStatus': 'rejected',
      'preDeleteAmountReceived': false,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rejected contribution deleted')));
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
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      if (i > 0 && fromEnd % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
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

  // Normalize flat format: "DB104" → "DB 104" (letters then space then digits)
  String _fmtFlat(String flat) {
    final m = RegExp(r'^([A-Za-z]+)(\d+)$').firstMatch(flat.trim());
    if (m != null) return '${m.group(1)} ${m.group(2)}';
    return flat;
  }

  // Build volunteer log entries from volunteer docs
  List<Map<String, dynamic>> _volEntries(List<QueryDocumentSnapshot> docs) {
    final entries = <Map<String, dynamic>>[];
    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      final name = d['name'] as String? ?? '';
      final rawFlat = d['flat'] as String? ?? '';
      final flat = _fmtFlat(rawFlat);
      final wing = (d['wing'] as String? ?? '').trim().toUpperCase();
      final block = (d['block'] as String? ?? '').trim().toUpperCase();
      final role = d['role'] as String? ?? '';
      final addedBy = d['addedBy'] as String? ?? '';

      Timestamp? _ts(String key) => d[key] as Timestamp?;
      String _label() => flat.isNotEmpty ? '$name ($flat)' : name;

      // Registered / added
      if (_ts('addedAt') != null) {
        entries.add({
          'type': addedBy == 'resident' ? 'vol_registered' : 'vol_added',
          'name': _label(), 'flat': flat, 'wing': wing, 'block': block, 'role': role,
          'ts': _ts('addedAt')!.toDate().toIso8601String(),
        });
      }
      if (_ts('approvedAt') != null) {
        entries.add({
          'type': 'vol_approved',
          'name': _label(), 'flat': flat, 'wing': wing, 'block': block, 'role': role,
          'ts': _ts('approvedAt')!.toDate().toIso8601String(),
        });
      }
      if (_ts('rejectedAt') != null) {
        entries.add({
          'type': 'vol_rejected',
          'name': _label(), 'flat': flat, 'wing': wing, 'block': block, 'role': role,
          'ts': _ts('rejectedAt')!.toDate().toIso8601String(),
        });
      }
      if (_ts('waitlistedAt') != null) {
        entries.add({
          'type': 'vol_waitlisted',
          'name': _label(), 'flat': flat, 'wing': wing, 'block': block, 'role': role,
          'ts': _ts('waitlistedAt')!.toDate().toIso8601String(),
        });
      }
      if (_ts('deletedAt') != null) {
        entries.add({
          'type': 'vol_deleted',
          'name': _label(), 'flat': flat, 'wing': wing, 'block': block, 'role': role,
          'ts': _ts('deletedAt')!.toDate().toIso8601String(),
        });
      }
      if (_ts('restoredAt') != null) {
        entries.add({
          'type': 'vol_restored',
          'name': _label(), 'flat': flat, 'wing': wing, 'block': block, 'role': role,
          'ts': _ts('restoredAt')!.toDate().toIso8601String(),
        });
      }
      if (_ts('pendingAt') != null) {
        entries.add({
          'type': 'vol_pending',
          'name': _label(), 'flat': flat, 'wing': wing, 'block': block, 'role': role,
          'ts': _ts('pendingAt')!.toDate().toIso8601String(),
        });
      }
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events').doc(widget.eventId).collection('volunteers')
          .snapshots(),
      builder: (context, volSnap) => StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events').doc(widget.eventId).collection('carryForwardTransfers')
          .snapshots(),
      builder: (context, cfOutSnap) => StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('contributions')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Build a flat list of log entries from contribution docs + volunteer docs
        final entries = <Map<String, dynamic>>[];
        entries.addAll(_volEntries(volSnap.data?.docs ?? []));
        for (final doc in cfOutSnap.data?.docs ?? []) {
          final d = doc.data() as Map<String, dynamic>;
          entries.add({
            'type': 'carry_forward_out',
            'flat': '', 'name': '',
            'amt': (d['amount'] as num? ?? 0).toDouble(),
            'wing': '', 'block': '',
            'destEventName': d['destEventName'] ?? 'another event',
            'ts': d['createdAt'] ?? '',
            'ref': doc.reference,
            'reversed': d['reversed'] == true,
          });
        }
        for (final doc in snap.data!.docs) {
          final d = doc.data() as Map<String, dynamic>;
          final flat = _fmtFlat((d['flatNumber'] ?? '') as String);
          final wing = (d['wing'] as String? ?? '').trim().toUpperCase();
          final block = (d['block'] as String? ?? '').trim().toUpperCase();
          final name = d['residentName'] ?? '';
          final amt = (d['amount'] as num?)?.toDouble() ?? 0;
          final mode = d['paymentMode'] ?? '';
          final selfReported = d['selfReported'] == true;
          final status = d['status'] ?? '';
          final contributionType = d['contributionType'] as String? ?? '';
          final isAnonymous = d['isAnonymous'] == true;
          // Shared fields so every entry type can be searched/filtered by
          // contribution type (External/Anonymous) and, for admin-added
          // entries, edited or deleted directly from Activity.
          final imported = d['importedAt'] != null;
          final common = {
            'contributionType': contributionType,
            'isAnonymous': isAnonymous,
            'doc': doc,
            'data': d,
            'imported': imported,
          };

          if (status == 'deleted') {
            entries.add({
              'type': 'deleted',
              'flat': flat, 'name': name, 'amt': amt, 'wing': wing, 'block': block,
              'ref': doc.reference,
              'preDeleteStatus': d['preDeleteStatus'] ?? '',
              'preDeleteAmountReceived': d['preDeleteAmountReceived'],
              'ts': d['deletedAt'] ?? d['paidAt'] ?? '',
              ...common,
            });
          } else {
            // Restored from deleted
            if ((d['restoredAt'] as String?)?.isNotEmpty == true) {
              entries.add({
                'type': 'restored',
                'flat': flat, 'name': name, 'amt': amt, 'wing': wing, 'block': block,
                'ts': d['restoredAt'],
                ...common,
              });
            }
            if (selfReported) {
              entries.add({
                'type': 'submitted',
                'flat': flat, 'name': name, 'amt': amt, 'mode': mode, 'wing': wing, 'block': block,
                'ts': d['reportedAt'] ?? d['paidAt'] ?? '',
                ...common,
              });
              if (status == 'confirmed' && (d['confirmedAt'] ?? '').isNotEmpty) {
                entries.add({
                  'type': 'confirmed',
                  'flat': flat, 'name': name, 'amt': amt, 'mode': mode, 'wing': wing, 'block': block,
                  'ts': d['confirmedAt'],
                  ...common,
                });
              }
              if ((d['rejectedAt'] as String?)?.isNotEmpty == true) {
                entries.add({
                  'type': 'rejected',
                  'flat': flat, 'name': name, 'amt': amt, 'wing': wing, 'block': block,
                  'reason': d['rejectionReason'] ?? '',
                  'ref': status == 'rejected' ? doc.reference : null,
                  'ts': d['rejectedAt'],
                  ...common,
                });
              }
              if ((d['revertedAt'] as String?)?.isNotEmpty == true) {
                entries.add({
                  'type': 'reverted',
                  'flat': flat, 'name': name, 'amt': amt, 'wing': wing, 'block': block,
                  'ts': d['revertedAt'],
                  ...common,
                });
              }
            } else {
              entries.add({
                'type': 'added',
                'flat': flat, 'name': name, 'amt': amt, 'mode': mode, 'wing': wing, 'block': block,
                // createdAt (real add-time) is preferred; paidAt is a
                // date-only field the admin picks, so it always reads 00:00.
                'ts': d['createdAt'] ?? d['paidAt'] ?? '',
                ...common,
              });
            }
          }
        }

        // Attach parsed DateTime, apply flat filter, sort newest first
        for (final e in entries) {
          e['dt'] = _parse(e['ts'] as String?);
        }
        // Match on just the trailing digit run so any flat-number formatting
        // style (letters, hyphens, spaces before the number) still matches
        // the bare number shown in the Flat filter picker.
        String numericTail(String s) =>
            RegExp(r'(\d+)\s*$').firstMatch(s)?.group(1) ?? s;

        bool _matchEntry(Map<String, dynamic> e) {
          final flat = (e['flat'] as String? ?? '').toUpperCase();
          final wing = (e['wing'] as String? ?? '').trim().toUpperCase();
          final block = (e['block'] as String? ?? '').trim().toUpperCase();
          if (_flatFilter.isNotEmpty) {
            if (numericTail(flat) != numericTail(_flatFilter.toUpperCase())) {
              return false;
            }
          }
          if (_wingFilter.isNotEmpty && wing != _wingFilter.trim().toUpperCase()) return false;
          if (_blockFilter.isNotEmpty && block != _blockFilter.trim().toUpperCase()) return false;
          if (_dateFilter != null) {
            final dt = e['dt'] as DateTime?;
            if (dt == null) return false;
            if (dt.year != _dateFilter!.year || dt.month != _dateFilter!.month || dt.day != _dateFilter!.day) return false;
          }
          if (_statusFilter.isNotEmpty) {
            final type = e['type'] as String;
            switch (_statusFilter) {
              case 'confirmed':
                if (type != 'confirmed' && type != 'added') return false;
              case 'rejected':
                if (type != 'rejected') return false;
              case 'deleted':
                if (type != 'deleted') return false;
              case 'submitted':
                if (type != 'submitted') return false;
              case 'external':
                if (e['contributionType'] != kTypeExternal) return false;
              case 'anonymous':
                if (e['isAnonymous'] != true) return false;
            }
          }
          return true;
        }
        final displayEntries = (_flatFilter.isEmpty && _wingFilter.isEmpty && _blockFilter.isEmpty &&
                _dateFilter == null && _statusFilter.isEmpty)
            ? entries
            : entries.where(_matchEntry).toList();
        displayEntries.sort((a, b) {
          final dtA = a['dt'] as DateTime?;
          final dtB = b['dt'] as DateTime?;
          if (dtA == null && dtB == null) return 0;
          if (dtA == null) return 1;
          if (dtB == null) return -1;
          return dtB.compareTo(dtA);
        });

        final noFiltersActive = _flatFilter.isEmpty && _wingFilter.isEmpty &&
            _blockFilter.isEmpty && _dateFilter == null && _statusFilter.isEmpty;

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

        // Auto-expand every group whenever a filter is actively narrowing results,
        // so filtered results are visible immediately instead of staying collapsed.
        final filtersActive = _flatFilter.isNotEmpty || _wingFilter.isNotEmpty ||
            _blockFilter.isNotEmpty || _dateFilter != null || _statusFilter.isNotEmpty;
        final filterSignature = filtersActive
            ? '$_flatFilter|$_wingFilter|$_blockFilter|$_statusFilter|${_dateFilter?.toIso8601String() ?? ''}'
            : '';
        if (filtersActive && filterSignature != _lastFilterSignature) {
          _lastFilterSignature = filterSignature;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {
              _expandedMonths.addAll(allMonthKeys);
              _expandedDates.addAll(allDateKeys);
            });
          });
        } else if (!filtersActive) {
          _lastFilterSignature = '';
        }

        // Auto-expand today's month and date on first data load
        if (!_autoExpanded && allMonthKeys.isNotEmpty) {
          _autoExpanded = true;
          final now = DateTime.now();
          final todayMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
          final todayDateKey  = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          final targetMonth = allMonthKeys.contains(todayMonthKey)
              ? todayMonthKey
              : allMonthKeys.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
          final targetDate = allDateKeys.contains(todayDateKey)
              ? todayDateKey
              : (allDateKeys.where((k) => k.startsWith(targetMonth)).toList()
                    ..sort()).lastOrNull ?? '';
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {
              _expandedMonths.add(targetMonth);
              if (targetDate.isNotEmpty) _expandedDates.add(targetDate);
            });
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
            // Toolbar: expand/collapse (right)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  const Spacer(),
                  TextButton.icon(
                    icon: Icon(
                      allExpanded ? Icons.unfold_less : Icons.unfold_more,
                      size: 16),
                    label: Text(allExpanded ? 'Collapse All' : 'Expand All',
                        style: const TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.accent.shade400,
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
            // Wing / Block / Flat / Date / Status filter row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  // Wing filter chip (dropdown picker)
                  ActionChip(
                    avatar: Icon(Icons.home_work_outlined, size: 14,
                        color: _wingFilter.isNotEmpty ? AppTheme.accent.shade700 : Colors.grey.shade500),
                    label: Text(_wingFilter.isEmpty ? 'Wing' : 'Wing: $_wingFilter',
                        style: TextStyle(fontSize: 11,
                            color: _wingFilter.isNotEmpty ? AppTheme.accent.shade700 : Colors.grey.shade600)),
                    backgroundColor: _wingFilter.isNotEmpty ? AppTheme.accent.shade50 : Colors.grey.shade100,
                    side: BorderSide(color: _wingFilter.isNotEmpty ? AppTheme.accent.shade200 : Colors.grey.shade300),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    onPressed: () async {
                      final val = await _showPickerSheet(
                          title: 'Filter by Wing', options: _wings, current: _wingFilter);
                      if (val != null) {
                        setState(() {
                          _wingFilter = val;
                          _blockFilter = '';
                          _flatFilter = '';
                        });
                      }
                    },
                  ),
                  // Block filter chip (dropdown picker, scoped to selected wing)
                  ActionChip(
                    avatar: Icon(Icons.domain_outlined, size: 14,
                        color: _blockFilter.isNotEmpty ? Colors.indigo.shade700 : Colors.grey.shade500),
                    label: Text(_blockFilter.isEmpty ? 'Block' : 'Block: $_blockFilter',
                        style: TextStyle(fontSize: 11,
                            color: _blockFilter.isNotEmpty ? Colors.indigo.shade700 : Colors.grey.shade600)),
                    backgroundColor: _blockFilter.isNotEmpty ? Colors.indigo.shade50 : Colors.grey.shade100,
                    side: BorderSide(color: _blockFilter.isNotEmpty ? Colors.indigo.shade200 : Colors.grey.shade300),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    onPressed: () async {
                      final val = await _showPickerSheet(
                          title: 'Filter by Block', options: _blocksForSelectedWing, current: _blockFilter);
                      if (val != null) {
                        setState(() {
                          _blockFilter = val;
                          _flatFilter = '';
                        });
                      }
                    },
                  ),
                  // Flat filter chip (dropdown picker, scoped to selected wing/block)
                  ActionChip(
                    avatar: Icon(Icons.meeting_room_outlined, size: 14,
                        color: _flatFilter.isNotEmpty ? Colors.brown.shade700 : Colors.grey.shade500),
                    label: Text(_flatFilter.isEmpty ? 'Flat' : 'Flat: $_flatFilter',
                        style: TextStyle(fontSize: 11,
                            color: _flatFilter.isNotEmpty ? Colors.brown.shade700 : Colors.grey.shade600)),
                    backgroundColor: _flatFilter.isNotEmpty ? Colors.brown.shade50 : Colors.grey.shade100,
                    side: BorderSide(color: _flatFilter.isNotEmpty ? Colors.brown.shade200 : Colors.grey.shade300),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    onPressed: () async {
                      final val = await _showPickerSheet(
                          title: 'Filter by Flat', options: _flatsForSelectedFilters, current: _flatFilter);
                      if (val != null) setState(() => _flatFilter = val);
                    },
                  ),
                  // Date filter chip
                  ActionChip(
                    avatar: Icon(Icons.calendar_today_outlined, size: 14,
                        color: _dateFilter != null ? Colors.teal.shade700 : Colors.grey.shade500),
                    label: Text(_dateFilter == null
                        ? 'Date'
                        : '${_dateFilter!.day}/${_dateFilter!.month}/${_dateFilter!.year}',
                        style: TextStyle(fontSize: 11,
                            color: _dateFilter != null ? Colors.teal.shade700 : Colors.grey.shade600)),
                    backgroundColor: _dateFilter != null ? Colors.teal.shade50 : Colors.grey.shade100,
                    side: BorderSide(color: _dateFilter != null ? Colors.teal.shade200 : Colors.grey.shade300),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dateFilter ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _dateFilter = picked);
                    },
                  ),
                  // Status filter chip
                  ActionChip(
                    avatar: Icon(Icons.filter_alt_outlined, size: 14,
                        color: _statusFilter.isNotEmpty ? Colors.purple.shade700 : Colors.grey.shade500),
                    label: Text(_statusFilter.isEmpty ? 'Status' : _statusLabels[_statusFilter]!,
                        style: TextStyle(fontSize: 11,
                            color: _statusFilter.isNotEmpty ? Colors.purple.shade700 : Colors.grey.shade600)),
                    backgroundColor: _statusFilter.isNotEmpty ? Colors.purple.shade50 : Colors.grey.shade100,
                    side: BorderSide(color: _statusFilter.isNotEmpty ? Colors.purple.shade200 : Colors.grey.shade300),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    onPressed: () async {
                      final val = await showModalBottomSheet<String>(
                        context: context,
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                        builder: (ctx) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Filter by Status',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ),
                              ..._statusLabels.entries.map((entry) => ListTile(
                                    title: Text(entry.value),
                                    trailing: _statusFilter == entry.key
                                        ? const Icon(Icons.check, color: Colors.purple)
                                        : null,
                                    onTap: () => Navigator.pop(ctx, entry.key),
                                  )),
                              ListTile(
                                title: const Text('All'),
                                trailing: _statusFilter.isEmpty
                                    ? const Icon(Icons.check, color: Colors.purple)
                                    : null,
                                onTap: () => Navigator.pop(ctx, ''),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (val != null) setState(() => _statusFilter = val);
                    },
                  ),
                  // Clear all filters
                  if (_wingFilter.isNotEmpty || _blockFilter.isNotEmpty || _flatFilter.isNotEmpty ||
                      _dateFilter != null || _statusFilter.isNotEmpty)
                    ActionChip(
                      avatar: const Icon(Icons.clear_all, size: 14, color: Colors.red),
                      label: const Text('Clear', style: TextStyle(fontSize: 11, color: Colors.red)),
                      backgroundColor: Colors.red.shade50,
                      side: BorderSide(color: Colors.red.shade200),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      onPressed: () => setState(() {
                        _wingFilter = '';
                        _blockFilter = '';
                        _flatFilter = '';
                        _dateFilter = null;
                        _statusFilter = '';
                      }),
                    ),
                ],
              ),
            ),
            Expanded(
              child: displayEntries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                              noFiltersActive
                                  ? 'No activity yet'
                                  : 'No activity found for the selected filters',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
                          if (!noFiltersActive) ...[
                            const SizedBox(height: 6),
                            Text('Try adjusting or clearing the filters above',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                padding: EdgeInsets.fromLTRB(12, 4, 12, keyboardHeight + 80),
                itemCount: listItems.length,
          itemBuilder: (_, i) {
            final item = listItems[i];

            // Month header — tappable to expand/collapse
            if (item.isMonthHeader) {
              final isExpanded = _expandedMonths.contains(item.monthKey);
              final datesInMonth =
                  allDateKeys.where((k) => k.startsWith(item.monthKey!)).toList();
              final allDatesInMonthExpanded =
                  datesInMonth.isNotEmpty && _expandedDates.containsAll(datesInMonth);
              return Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 16, bottom: 4),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => setState(() {
                      if (isExpanded) {
                        _expandedMonths.remove(item.monthKey);
                      } else {
                        _expandedMonths.add(item.monthKey!);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.shade600,
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
                  ),
                  if (isExpanded && datesInMonth.length > 1) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() {
                        if (allDatesInMonthExpanded) {
                          _expandedDates.removeAll(datesInMonth);
                        } else {
                          _expandedDates.addAll(datesInMonth);
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.accent.shade200),
                        ),
                        child: Text(
                            allDatesInMonthExpanded ? 'Collapse dates' : 'Expand dates',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accent.shade700)),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Expanded(child: Divider(color: AppTheme.accent.shade100)),
                ]),
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
            VoidCallback? onDelete;
            VoidCallback? onEdit;

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
                if (actionRef != null) {
                  onRestore = () => _restoreRejected(actionRef!, e);
                  onDelete = () => _deleteRejected(actionRef!, e);
                }
              case 'deleted':
                iconBg = Colors.grey.shade100; iconColor = Colors.grey.shade600;
                icon = Icons.delete_outline;
                title = 'Deleted ₹${_fmt(e['amt'] as double)} from ${e['flat']}';
                subtitle = e['contributionType'] == kTypeCarryForward
                    ? '${e['name']}  ·  Carry forward balance is available again in its source event'
                    : e['name'] as String;
                actionRef = e['ref'] as DocumentReference?;
                // Carry-forward deletions are log-only — no Restore here.
                // The freed-up balance is already selectable again from
                // Carry Forward Balance on the source event; re-adding it
                // that way (rather than an in-place restore) keeps the
                // source/destination bookkeeping unambiguous.
                if (actionRef != null && e['contributionType'] != kTypeCarryForward) {
                  onRestore = () => _restore(actionRef!, e);
                }
              case 'restored':
                iconBg = Colors.teal.shade50; iconColor = Colors.teal.shade700;
                icon = Icons.restore_outlined;
                title = 'Contribution restored for ${e['flat']}';
                subtitle = '${e['name']}  ·  ₹${_fmt(e['amt'] as double)}';
              case 'reverted':
                iconBg = Colors.orange.shade50; iconColor = Colors.orange.shade800;
                icon = Icons.undo_outlined;
                title = 'Rejection reverted for ${e['flat']}';
                subtitle = '${e['name']}  ·  ₹${_fmt(e['amt'] as double)} moved back to pending';
              case 'submitted':
                iconBg = Colors.orange.shade50; iconColor = Colors.orange.shade700;
                icon = Icons.upload_outlined;
                title = 'Resident submitted ₹${_fmt(e['amt'] as double)} from ${e['flat']}';
                subtitle = '${e['name']}  ·  ${e['mode']}';
              case 'vol_registered':
                iconBg = Colors.purple.shade50; iconColor = Colors.purple.shade700;
                icon = Icons.volunteer_activism_outlined;
                title = '${e['name']} registered as volunteer';
                subtitle = 'Role: ${e['role']}';
              case 'vol_added':
                iconBg = Colors.purple.shade50; iconColor = Colors.purple.shade700;
                icon = Icons.person_add_outlined;
                title = 'Volunteer added: ${e['name']}';
                subtitle = 'Role: ${e['role']}';
              case 'vol_approved':
                iconBg = Colors.green.shade50; iconColor = Colors.green.shade700;
                icon = Icons.how_to_reg_outlined;
                title = 'Volunteer approved: ${e['name']}';
                subtitle = 'Role: ${e['role']}';
              case 'vol_rejected':
                iconBg = Colors.red.shade50; iconColor = Colors.red.shade600;
                icon = Icons.person_remove_outlined;
                title = 'Volunteer rejected: ${e['name']}';
                subtitle = 'Role: ${e['role']}';
              case 'vol_waitlisted':
                iconBg = Colors.blue.shade50; iconColor = Colors.blue.shade700;
                icon = Icons.schedule_outlined;
                title = 'Volunteer waitlisted: ${e['name']}';
                subtitle = 'Role: ${e['role']}';
              case 'vol_deleted':
                iconBg = Colors.grey.shade100; iconColor = Colors.grey.shade600;
                icon = Icons.person_remove_outlined;
                title = 'Volunteer removed: ${e['name']}';
                subtitle = 'Role: ${e['role']}';
              case 'vol_restored':
                iconBg = Colors.teal.shade50; iconColor = Colors.teal.shade700;
                icon = Icons.restore_outlined;
                title = 'Volunteer restored: ${e['name']}';
                subtitle = 'Role: ${e['role']}';
              case 'vol_pending':
                iconBg = Colors.orange.shade50; iconColor = Colors.orange.shade700;
                icon = Icons.pending_outlined;
                title = 'Volunteer moved to pending: ${e['name']}';
                subtitle = 'Role: ${e['role']}';
              case 'carry_forward_out':
                final isReversed = e['reversed'] == true;
                iconBg = isReversed ? Colors.grey.shade100 : Colors.blue.shade50;
                iconColor = isReversed ? Colors.grey.shade500 : Colors.blue.shade700;
                icon = Icons.move_up;
                title = 'Carried forward ₹${_fmt(e['amt'] as double)} out'
                    '${isReversed ? ' (reversed)' : ''}';
                subtitle = isReversed
                    ? 'No longer moved to ${e['destEventName']} — balance available again'
                    : 'Moved to: ${e['destEventName']}';
                // Only let admin permanently clear this log entry once the
                // transfer has already been reversed (the destination-side
                // contribution was deleted) — deleting it while still active
                // would hide history without freeing the destination's money.
                if (isReversed) {
                  final transferRef = e['ref'] as DocumentReference?;
                  if (transferRef != null) {
                    onDelete = () async {
                      final confirmDel = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Remove Log Entry'),
                          content: const Text(
                              'Permanently remove this carry-forward record from Activity? This cannot be undone.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel')),
                            ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade600,
                                    foregroundColor: Colors.white),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Remove')),
                          ],
                        ),
                      );
                      if (confirmDel == true) {
                        await transferRef.delete();
                      }
                    };
                  }
                }
              default:
                final contribType = e['contributionType'] as String? ?? '';
                final isAnon = e['isAnonymous'] == true;
                iconBg = Colors.blue.shade50; iconColor = Colors.blue.shade700;
                icon = Icons.add_circle_outline;
                title = contribType == kTypeExternal
                    ? 'Admin recorded external donation ₹${_fmt(e['amt'] as double)}'
                    : isAnon
                        ? 'Admin recorded anonymous ₹${_fmt(e['amt'] as double)} contribution'
                        : 'Admin recorded ₹${_fmt(e['amt'] as double)} for ${e['flat']}';
                subtitle = (e['name'] as String).isNotEmpty
                    ? '${e['name']}  ·  ${e['mode']}' : e['mode'] as String;
                final editDoc = e['doc'] as QueryDocumentSnapshot?;
                final editData = e['data'] as Map<String, dynamic>?;
                if (editDoc != null && editData != null) {
                  onEdit = () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddContributionScreen(
                            eventId: widget.eventId,
                            existingDocId: editDoc.id,
                            existingData: editData,
                          ),
                        ),
                      );
                  onDelete = () => _ContributionsTabState._deleteContribution(
                      context, editDoc, editData);
                }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: type == 'deleted'
                      ? Colors.grey.withValues(alpha: 0.08)
                      : Theme.of(context).cardColor,
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
                        if (e['imported'] == true)
                          Text('N/A',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade400))
                        else if (dt != null)
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
                        if (onEdit != null || onDelete != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (onEdit != null)
                                GestureDetector(
                                  onTap: onEdit,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.blue.shade200),
                                    ),
                                    child: Text('Edit',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue.shade700)),
                                  ),
                                ),
                              if (onEdit != null && onDelete != null)
                                const SizedBox(width: 6),
                              if (onDelete != null)
                                GestureDetector(
                                  onTap: onDelete,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Text('Delete',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red.shade700)),
                                  ),
                                ),
                            ],
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
      ),      // contributions StreamBuilder
      ),      // carryForwardTransfers StreamBuilder
    );        // volunteers StreamBuilder
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
