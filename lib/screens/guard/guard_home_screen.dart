import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'new_visitor_screen.dart';
import '../auth/login_screen.dart';
import '../settings/theme_settings_sheet.dart';

class GuardHomeScreen extends StatefulWidget {
  const GuardHomeScreen({super.key});

  @override
  State<GuardHomeScreen> createState() => _GuardHomeScreenState();
}

class _GuardHomeScreenState extends State<GuardHomeScreen> {
  String _guardId = '';
  String _guardName = '';
  String? _shiftDocId;
  DateTime? _shiftStartTime;
  DateTime? _breakStartTime;
  bool _shiftActive = false;
  bool _onBreak = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGuardSession();
  }

  Future<void> _loadGuardSession() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _guardId = prefs.getString('guard_id') ?? '';
      _guardName = prefs.getString('guard_name') ?? 'Guard';
    });
    await _checkActiveShift();
    setState(() => _loading = false);
  }

  Future<void> _checkActiveShift() async {
    if (_guardId.isEmpty) return;
    try {
      final query = await FirebaseFirestore.instance
          .collection('guards')
          .doc(_guardId)
          .collection('shifts')
          .where('endTime', isNull: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final shift = query.docs.first;
        final breaks =
            List<Map<String, dynamic>>.from(shift['breaks'] ?? []);
        final onBreak =
            breaks.isNotEmpty && breaks.last['endTime'] == null;
        setState(() {
          _shiftDocId = shift.id;
          _shiftStartTime = DateTime.parse(shift['startTime']);
          _shiftActive = true;
          _onBreak = onBreak;
          if (onBreak) {
            _breakStartTime = DateTime.parse(breaks.last['startTime']);
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _startShift() async {
    final now = DateTime.now();
    final doc = await FirebaseFirestore.instance
        .collection('guards')
        .doc(_guardId)
        .collection('shifts')
        .add({
      'startTime': now.toIso8601String(),
      'endTime': null,
      'breaks': [],
      'guardName': _guardName,
    });
    setState(() {
      _shiftDocId = doc.id;
      _shiftStartTime = now;
      _shiftActive = true;
      _onBreak = false;
    });
  }

  Future<void> _endShift() async {
    if (_shiftDocId == null) return;
    final confirmed = await _confirmDialog(
        'End Shift', 'Are you sure you want to end your shift?');
    if (!confirmed) return;

    await FirebaseFirestore.instance
        .collection('guards')
        .doc(_guardId)
        .collection('shifts')
        .doc(_shiftDocId)
        .update({'endTime': DateTime.now().toIso8601String()});

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('guard_id');
    await prefs.remove('guard_name');
    await prefs.remove('guard_phone');
    await prefs.setBool('is_guard_session', false);
    await prefs.setBool('pin_verified_session', false);

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _startBreak() async {
    if (_shiftDocId == null) return;
    final ref = FirebaseFirestore.instance
        .collection('guards')
        .doc(_guardId)
        .collection('shifts')
        .doc(_shiftDocId);
    final doc = await ref.get();
    final breaks =
        List<Map<String, dynamic>>.from(doc['breaks'] ?? []);
    breaks.add({
      'startTime': DateTime.now().toIso8601String(),
      'endTime': null,
    });
    await ref.update({'breaks': breaks});
    setState(() {
      _onBreak = true;
      _breakStartTime = DateTime.now();
    });
  }

  Future<void> _endBreak() async {
    if (_shiftDocId == null) return;
    final ref = FirebaseFirestore.instance
        .collection('guards')
        .doc(_guardId)
        .collection('shifts')
        .doc(_shiftDocId);
    final doc = await ref.get();
    final breaks =
        List<Map<String, dynamic>>.from(doc['breaks'] ?? []);
    if (breaks.isNotEmpty) {
      breaks.last['endTime'] = DateTime.now().toIso8601String();
    }
    await ref.update({'breaks': breaks});
    setState(() {
      _onBreak = false;
      _breakStartTime = null;
    });
  }

  Future<bool> _confirmDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8)),
                child: const Text('Confirm',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _elapsed(DateTime start) {
    final d = DateTime.now().difference(start);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h ${m}m';
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── Header ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF1A73E8),
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: Text(
                          _guardName.isNotEmpty
                              ? _guardName[0].toUpperCase()
                              : 'G',
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
                            Text(_guardName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                            Text(
                              '${today.day}/${today.month}/${today.year}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _shiftActive
                              ? (_onBreak
                                  ? Colors.orange.shade600
                                  : Colors.green.shade500)
                              : Colors.grey.shade500,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _shiftActive
                              ? (_onBreak ? '☕ On Break' : '🟢 On Duty')
                              : '⚫ Off Duty',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.palette_outlined, color: Colors.white),
                        tooltip: 'Theme',
                        onPressed: () => showThemeSettingsSheet(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        tooltip: 'Logout',
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.clear();
                          if (mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                      ),
                    ],
                  ),

                  // Shift timer
                  if (_shiftActive && _shiftStartTime != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time,
                              color: Colors.white70, size: 18),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Shift Time',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11)),
                              Text(_elapsed(_shiftStartTime!),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          if (_onBreak && _breakStartTime != null) ...[
                            const SizedBox(width: 32),
                            const Icon(Icons.free_breakfast,
                                color: Colors.white70, size: 18),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Break Time',
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11)),
                                Text(_elapsed(_breakStartTime!),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Shift control buttons ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: !_shiftActive
                  ? SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _startShift,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.play_arrow,
                            color: Colors.white),
                        label: const Text('Start Shift',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _onBreak ? _endBreak : _startBreak,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _onBreak
                                    ? Colors.green.shade600
                                    : Colors.orange.shade600,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                              icon: Icon(
                                _onBreak
                                    ? Icons.play_arrow
                                    : Icons.free_breakfast,
                                color: Colors.white,
                                size: 20,
                              ),
                              label: Text(
                                _onBreak ? 'End Break' : 'Start Break',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _endShift,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade500,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.stop,
                                  color: Colors.white, size: 20),
                              label: const Text('End Shift',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // ── Visitors header ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Today's Visitors",
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('visitors')
                        .where('loggedBy', isEqualTo: _guardId)
                        .where('entryTime',
                            isGreaterThanOrEqualTo: todayStart)
                        .snapshots(),
                    builder: (ctx, snap) {
                      final count = snap.data?.docs.length ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A73E8).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('$count entries',
                            style: const TextStyle(
                                color: Color(0xFF1A73E8),
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── Visitor list ───────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('visitors')
                .where('loggedBy', isEqualTo: _guardId)
                .where('entryTime', isGreaterThanOrEqualTo: todayStart)
                .orderBy('entryTime', descending: true)
                .snapshots(),
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()));
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Column(
                      children: [
                        Icon(Icons.people_outline,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No visitors logged yet',
                            style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(
                          _shiftActive
                              ? 'Tap + to log a visitor'
                              : 'Start your shift first',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final data =
                        docs[i].data() as Map<String, dynamic>;
                    final time = data['entryTime']?.toString() ?? '';
                    final displayTime =
                        time.length >= 16 ? time.substring(11, 16) : '';
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 5),
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
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        leading: CircleAvatar(
                          backgroundColor:
                              const Color(0xFF1A73E8).withOpacity(0.1),
                          child: Text(
                            (data['visitorName'] ?? 'V')
                                .isNotEmpty
                                ? (data['visitorName'] as String)
                                    .substring(0, 1)
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
                            'Flat ${data['flatNumber'] ?? ''} • ${data['purpose'] ?? ''}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(displayTime,
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 11)),
                            const SizedBox(height: 4),
                            _StatusBadge(status: data['status'] ?? 'pending'),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: docs.length,
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      // FAB only visible when shift active and not on break
      floatingActionButton: (_shiftActive && !_onBreak)
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => NewVisitorScreen(guardId: _guardId)),
              ),
              backgroundColor: const Color(0xFF1A73E8),
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('Log Visitor',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'approved':
        color = Colors.green;
        label = '✅ Approved';
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}
