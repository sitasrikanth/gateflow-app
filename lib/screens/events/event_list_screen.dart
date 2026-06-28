import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../auth/login_screen.dart';
import 'event_dashboard_screen.dart';
import 'create_event_screen.dart';
import 'expense_categories_screen.dart';
import 'event_types.dart';
import 'event_type_settings_screen.dart';

// Fallback color palette for events without a type
const List<Color> _kEventColors = [
  Color(0xFF6C63FF),
  Color(0xFF00897B),
  Color(0xFFE64A19),
  Color(0xFF1565C0),
  Color(0xFF6D4C41),
  Color(0xFF00695C),
  Color(0xFFAD1457),
  Color(0xFF37474F),
];

class EventListScreen extends StatelessWidget {
  final bool isAdmin;
  const EventListScreen({super.key, required this.isAdmin});

  Color _colorFor(int index) => _kEventColors[index % _kEventColors.length];

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              color: Colors.deepPurple,
              padding: EdgeInsets.fromLTRB(16, canPop ? 52 : 52, 16, 20),
              child: Row(
                children: [
                  if (canPop)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  const Icon(Icons.celebration, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Event Fund Manager',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        Text('Tap an event to view dashboard',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (isAdmin)
                    IconButton(
                      icon: const Icon(Icons.tune, color: Colors.white70),
                      tooltip: 'Event Settings',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EventTypeSettingsScreen()),
                      ),
                    ),
                  if (isAdmin)
                    IconButton(
                      icon: const Icon(Icons.category_outlined,
                          color: Colors.white70),
                      tooltip: 'Expense Categories',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const ExpenseCategoriesScreen()),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white70),
                    tooltip: 'Logout',
                    onPressed: () => _logout(context),
                  ),
                ],
              ),
            ),
          ),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('events')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              final events = snapshot.data?.docs ?? [];

              if (events.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: Column(
                      children: [
                        Icon(Icons.celebration_outlined,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No events yet',
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 16)),
                        const SizedBox(height: 4),
                        if (isAdmin)
                          Text('Tap + below to create your first event',
                              style: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 13)),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.78,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final data = events[i].data() as Map<String, dynamic>;
                      final status = data['status'] ?? 'active';
                      final double target =
                          ((data['targetAmount'] ?? 0) as num).toDouble();
                      final double collected =
                          ((data['totalCollected'] ?? 0) as num).toDouble();
                      final double spent =
                          ((data['totalSpent'] ?? 0) as num).toDouble();
                      final double balance = collected - spent;
                      final double progress = target > 0
                          ? (collected / target).clamp(0.0, 1.0)
                          : 0.0;
                      final eventType =
                          eventTypeById(data['eventTypeId'] as String?) ??
                          eventTypeByName(data['name'] as String?);
                      final List<Color> gradientColors = eventType?.gradient ??
                          [_colorFor(i), _colorFor(i).withValues(alpha: 0.75)];
                      final String typeEmoji = eventType?.emoji ?? '🎉';
                      // Per-event banner takes priority over event type image
                      final String imageUrl =
                          (data['bannerUrl'] as String?)?.isNotEmpty == true
                              ? data['bannerUrl'] as String
                              : (eventType?.imageUrl ?? '');

                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _EventPageView(
                              events: events,
                              initialIndex: i,
                              isAdmin: isAdmin,
                            ),
                          ),
                        ),
                        child: _EventGridCard(
                          name: data['name'] ?? '',
                          status: status,
                          collected: collected,
                          spent: spent,
                          balance: balance,
                          target: target,
                          progress: progress,
                          gradientColors: gradientColors,
                          typeEmoji: typeEmoji,
                          imageUrl: imageUrl,
                          startDate: data['startDate'] as String? ?? '',
                          tagline: eventType?.tagline ?? '',
                        ),
                      );
                    },
                    childCount: events.length,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CreateEventScreen(isAdmin: isAdmin)),
              ),
              backgroundColor: Colors.deepPurple,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Create Event',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

}

class _EventGridCard extends StatelessWidget {
  final String name;
  final String status;
  final double collected;
  final double spent;
  final double balance;
  final double target;
  final double progress;
  final List<Color> gradientColors;
  final String typeEmoji;
  final String imageUrl;
  final String startDate;
  final String tagline;

  const _EventGridCard({
    required this.name,
    required this.status,
    required this.collected,
    required this.spent,
    required this.balance,
    required this.target,
    required this.progress,
    required this.gradientColors,
    required this.typeEmoji,
    required this.imageUrl,
    required this.startDate,
    required this.tagline,
  });

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = gradientColors.first;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: primaryColor,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.30),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (ctx, url) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                errorWidget: (ctx, url, err) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

            // Dark overlay for legibility
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.10),
                    Colors.black.withValues(alpha: 0.70),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

            // Color tint top-left
            Positioned(
              top: 0, left: 0, right: 0,
              height: 70,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      gradientColors.first.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: emoji + status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Text(typeEmoji,
                            style: const TextStyle(fontSize: 18)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: status == 'active'
                              ? Colors.green.withValues(alpha: 0.85)
                              : Colors.red.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status == 'active' ? 'Active' : 'Closed',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Event name
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      height: 1.2,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (startDate.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(startDate,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 9,
                            shadows: [Shadow(blurRadius: 3, color: Colors.black45)])),
                  ],

                  const SizedBox(height: 8),

                  // Stats row
                  Row(
                    children: [
                      _MiniStat(label: '₹${_fmt(collected)}', sub: 'Collected',
                          color: Colors.greenAccent),
                      const SizedBox(width: 6),
                      _MiniStat(label: '₹${_fmt(balance)}', sub: 'Balance',
                          color: Colors.lightBlueAccent),
                    ],
                  ),

                  // Progress bar
                  if (target > 0) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}% of ₹${_fmt(target)}',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 8),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String sub;
  final Color color;
  const _MiniStat(
      {required this.label, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
            Text(sub,
                style: const TextStyle(color: Colors.white54, fontSize: 8)),
          ],
        ),
      ),
    );
  }
}

// ── Horizontal swipe between events ──────────────────────────────────────────

class _EventPageView extends StatefulWidget {
  final List<QueryDocumentSnapshot> events;
  final int initialIndex;
  final bool isAdmin;

  const _EventPageView({
    required this.events,
    required this.initialIndex,
    required this.isAdmin,
  });

  @override
  State<_EventPageView> createState() => _EventPageViewState();
}

class _EventPageViewState extends State<_EventPageView> {
  late final PageController _ctrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.events.length;
    final data = widget.events[_current].data() as Map<String, dynamic>;
    final eventType = eventTypeById(data['eventTypeId'] as String?) ??
        eventTypeByName(data['name'] as String?);
    final accentColor = eventType?.gradient.first ?? Colors.deepPurple;

    return Scaffold(
      body: PageView.builder(
        controller: _ctrl,
        itemCount: total,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (ctx, i) {
          final d = widget.events[i].data() as Map<String, dynamic>;
          return EventDashboardScreen(
            eventId: widget.events[i].id,
            eventName: d['name'] ?? '',
            isAdmin: widget.isAdmin,
            hideAppBarBackButton: true,
          );
        },
      ),
    );
  }
}
