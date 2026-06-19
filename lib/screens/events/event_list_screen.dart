import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import 'event_dashboard_screen.dart';
import 'create_event_screen.dart';

// Color palette — one per event card (cycles if more than 8 events)
const List<Color> _kEventColors = [
  Color(0xFF6C63FF), // purple
  Color(0xFF00897B), // teal
  Color(0xFFE64A19), // deep orange
  Color(0xFF1565C0), // dark blue
  Color(0xFF6D4C41), // brown
  Color(0xFF00695C), // dark teal
  Color(0xFFAD1457), // pink
  Color(0xFF37474F), // blue grey
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

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final data =
                        events[i].data() as Map<String, dynamic>;
                    final status = data['status'] ?? 'active';
                    final double target =
                        ((data['targetAmount'] ?? 0) as num).toDouble();
                    final double collected =
                        ((data['totalCollected'] ?? 0) as num).toDouble();
                    final double spent = ((data['totalSpent'] ?? 0) as num).toDouble();
                    final double balance = collected - spent;
                    final double progress = target > 0
                        ? ((collected / target).clamp(0.0, 1.0) as num).toDouble()
                        : 0.0;
                    final cardColor = _colorFor(i);

                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventDashboardScreen(
                            eventId: events[i].id,
                            eventName: data['name'] ?? '',
                            isAdmin: isAdmin,
                          ),
                        ),
                      ),
                      child: Container(
                        margin:
                            const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: cardColor.withOpacity(0.18),
                                blurRadius: 10,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            children: [
                              // Colored top band
                              Container(
                                color: cardColor,
                                padding: const EdgeInsets.fromLTRB(
                                    16, 14, 16, 14),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withOpacity(0.2),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.celebration,
                                          color: Colors.white, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(data['name'] ?? '',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  fontSize: 16)),
                                          if ((data['startDate'] ?? '')
                                              .isNotEmpty)
                                            Text(data['startDate'],
                                                style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withOpacity(0.2),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        status == 'active'
                                            ? '🟢 Active'
                                            : '🔴 Closed',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // White bottom section
                              Container(
                                color: Colors.white,
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        _StatChip(
                                            label: 'Collected',
                                            value:
                                                '₹${_fmt(collected)}',
                                            color: Colors.green),
                                        const SizedBox(width: 8),
                                        _StatChip(
                                            label: 'Spent',
                                            value: '₹${_fmt(spent)}',
                                            color: Colors.red),
                                        const SizedBox(width: 8),
                                        _StatChip(
                                            label: 'Balance',
                                            value:
                                                '₹${_fmt(balance)}',
                                            color: Colors.blue),
                                      ],
                                    ),

                                    if (target > 0) ...[
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment
                                                .spaceBetween,
                                        children: [
                                          Text(
                                              'Target: ₹${_fmt(target)}',
                                              style: TextStyle(
                                                  color:
                                                      Colors.grey.shade500,
                                                  fontSize: 12)),
                                          Text(
                                              '${(progress * 100).toStringAsFixed(0)}%',
                                              style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  fontSize: 12,
                                                  color: cardColor)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          minHeight: 6,
                                          backgroundColor:
                                              Colors.grey.shade200,
                                          valueColor:
                                              AlwaysStoppedAnimation(
                                                  cardColor),
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 10),
                                    // Tap hint
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          'View Dashboard',
                                          style: TextStyle(
                                              color: cardColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                            Icons.arrow_forward_rounded,
                                            color: cardColor,
                                            size: 16),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: events.length,
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
                    builder: (_) => const CreateEventScreen()),
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

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}
