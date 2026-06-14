import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import '../events/event_list_screen.dart';

class ResidentHomeScreen extends StatefulWidget {
  const ResidentHomeScreen({super.key});

  @override
  State<ResidentHomeScreen> createState() => _ResidentHomeScreenState();
}

class _ResidentHomeScreenState extends State<ResidentHomeScreen> {
  String _flatNumber = '';
  String _residentName = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists) {
      setState(() {
        _flatNumber = doc['flatNumber'] ?? '';
        _residentName = doc['name'] ?? 'Resident';
        _loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_pin');
    await prefs.setBool('pin_verified_session', false);
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _respondToVisitor(String docId, String response) async {
    await FirebaseFirestore.instance
        .collection('visitors')
        .doc(docId)
        .update({'status': response});
  }

  void _showVisitorDialog(Map<String, dynamic> data, String docId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  Icon(Icons.person_add, color: Colors.orange.shade700),
            ),
            const SizedBox(width: 12),
            const Text('Visitor at Gate',
                style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(label: 'Name', value: data['visitorName'] ?? ''),
            const SizedBox(height: 8),
            _InfoRow(label: 'Purpose', value: data['purpose'] ?? ''),
            const SizedBox(height: 8),
            _InfoRow(label: 'Flat', value: data['flatNumber'] ?? ''),
            if ((data['visitorPhone'] ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(label: 'Phone', value: data['visitorPhone']),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _respondToVisitor(docId, 'denied');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Deny Entry',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _respondToVisitor(docId, 'approved');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Allow Entry',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final today = DateTime.now();
    final todayStart =
        DateTime(today.year, today.month, today.day).toIso8601String();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF1A73E8),
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Text(
                      _residentName.isNotEmpty
                          ? _residentName[0].toUpperCase()
                          : 'R',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome, $_residentName',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        Text('Flat $_flatNumber',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: _signOut,
                  ),
                ],
              ),
            ),
          ),

          // ── Pending visitor alert banner ─────────────────────────
          if (_flatNumber.isNotEmpty)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('visitors')
                  .where('flatNumber', isEqualTo: _flatNumber)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (ctx, snapshot) {
                final pending = snapshot.data?.docs ?? [];
                if (pending.isEmpty) return const SliverToBoxAdapter(child: SizedBox());

                return SliverToBoxAdapter(
                  child: Column(
                    children: pending.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return GestureDetector(
                        onTap: () => _showVisitorDialog(data, doc.id),
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.orange.shade300, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.notifications_active,
                                    color: Colors.orange.shade700, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '🔔 Visitor at Gate!',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade800,
                                          fontSize: 14),
                                    ),
                                    Text(
                                      '${data['visitorName'] ?? ''} • ${data['purpose'] ?? ''}',
                                      style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade600,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('Respond',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),

          // ── Stats row ────────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('visitors')
                .where('flatNumber', isEqualTo: _flatNumber)
                .snapshots(),
            builder: (ctx, snapshot) {
              final all = snapshot.data?.docs ?? [];
              final todayCount = all.where((d) {
                final entry =
                    ((d.data() as Map<String, dynamic>)['entryTime'] ?? '')
                        as String;
                return entry.startsWith(todayStart.substring(0, 10));
              }).length;

              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _StatCard(
                        icon: Icons.people,
                        label: 'Total Visitors',
                        value: all.length.toString(),
                        color: const Color(0xFF1A73E8),
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        icon: Icons.today,
                        label: 'Today',
                        value: todayCount.toString(),
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ── Recent visitors header ───────────────────────────────
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('Recent Visitors',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),

          // ── Visitors list ────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('visitors')
                .where('flatNumber', isEqualTo: _flatNumber)
                .snapshots(),
            builder: (ctx, snapshot) {
              final docs = snapshot.data?.docs ?? [];

              // Sort in memory
              final sorted = List.of(docs);
              sorted.sort((a, b) {
                final aT = ((a.data() as Map)['entryTime'] ?? '') as String;
                final bT = ((b.data() as Map)['entryTime'] ?? '') as String;
                return bT.compareTo(aT);
              });

              if (sorted.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Column(
                      children: [
                        Icon(Icons.people_outline,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No visitors yet',
                            style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 15)),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final data =
                        sorted[i].data() as Map<String, dynamic>;
                    final status = data['status'] ?? 'pending';
                    final entryTime =
                        (data['entryTime'] as String?) ?? '';
                    final displayTime = entryTime.length >= 16
                        ? entryTime.substring(11, 16)
                        : '';

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 5),
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor:
                              const Color(0xFF1A73E8).withOpacity(0.1),
                          child: Text(
                            (data['visitorName'] ?? 'V').isNotEmpty
                                ? (data['visitorName'] as String)[0]
                                    .toUpperCase()
                                : 'V',
                            style: const TextStyle(
                                color: Color(0xFF1A73E8),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(data['visitorName'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '${data['purpose'] ?? ''} • $displayTime'),
                        trailing: _VisitorStatusBadge(status: status),
                        // Allow tapping pending visitors to respond
                        onTap: status == 'pending'
                            ? () => _showVisitorDialog(
                                data, sorted[i].id)
                            : null,
                      ),
                    );
                  },
                  childCount: sorted.length,
                ),
              );
            },
          ),

          // ── Events shortcut ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EventListScreen(isAdmin: false),
                  ),
                ),
                icon: const Icon(Icons.celebration_outlined),
                label: const Text('View Event Fund Dashboard'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.deepPurple,
                  side: const BorderSide(color: Colors.deepPurple),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text('$label:',
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ],
    );
  }
}

class _VisitorStatusBadge extends StatelessWidget {
  final String status;
  const _VisitorStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'approved':
        color = Colors.green;
        label = '✅ Allowed';
        break;
      case 'denied':
        color = Colors.red;
        label = '❌ Denied';
        break;
      case 'entered':
        color = Colors.blue;
        label = '🟢 Entered';
        break;
      default:
        color = Colors.orange;
        label = '⏳ Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color)),
                Text(label,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
