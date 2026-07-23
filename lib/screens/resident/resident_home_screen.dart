import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/login_screen.dart';
import '../events/event_list_screen.dart';
import 'resident_events_screen.dart';
import '../../theme/app_theme.dart';
import '../settings/theme_settings_sheet.dart';
import '../temple/temple_home_screen.dart';

class ResidentHomeScreen extends StatefulWidget {
  const ResidentHomeScreen({super.key});

  @override
  State<ResidentHomeScreen> createState() => _ResidentHomeScreenState();
}

class _ResidentHomeScreenState extends State<ResidentHomeScreen> {
  String _flatNumber = '';
  String _residentName = '';
  String _userId = '';
  String _wing = '';
  String _block = '';
  String _photoUrl = '';
  bool _loading = true;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('session_user_id') ?? '';
    setState(() {
      _residentName = prefs.getString('session_name') ?? 'Resident';
      _flatNumber = prefs.getString('session_flat') ?? '';
      _userId = userId;
      _wing = prefs.getString('session_wing') ?? '';
      _block = prefs.getString('session_block') ?? '';
      _loading = false;
    });
    // Load photo from Firestore
    if (userId.isNotEmpty) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists && mounted) {
        setState(() => _photoUrl = doc.data()?['photoBase64'] ?? '');
      }
    }
  }

  Future<void> _changePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 200, maxHeight: 200, imageQuality: 70);
    if (picked == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await File(picked.path).readAsBytes();
      final base64Str = base64Encode(bytes);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .update({'photoBase64': base64Str});
      if (mounted) setState(() { _photoUrl = base64Str; _uploadingPhoto = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save photo: $e')));
      }
    }
  }

  Future<void> _changeCode() async {
    final ctrl = TextEditingController();
    String currentCode = '';
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_userId).get();
      currentCode = doc.data()?['quickCode'] as String? ?? '';
    } catch (_) {}
    if (!mounted) return;

    bool codeVisible = false;
    String error = '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Change My Quick Code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (currentCode.isNotEmpty) ...[
                const Text('Current code', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                Row(children: [
                  Text(
                    codeVisible ? currentCode : '•' * currentCode.length,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 4),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => setSt(() => codeVisible = !codeVisible),
                    child: Icon(
                        codeVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20, color: Colors.grey.shade600),
                  ),
                ]),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
              ],
              const Text('Enter a new 6-digit code you can remember.',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                onChanged: (_) {
                  if (error.isNotEmpty) setSt(() => error = '');
                },
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 6),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '------',
                  errorText: error.isEmpty ? null : error,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF1A73E8), width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => ctrl.dispose());
                Navigator.pop(ctx);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (ctrl.text.length != 6) {
                  setSt(() => error = 'Code must be exactly 6 digits');
                  return;
                }
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(_userId)
                    .update({'quickCode': ctrl.text});
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => ctrl.dispose());
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Quick code updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
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
    final greeting = today.hour < 12
        ? 'Good Morning'
        : today.hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // ── Hero Header ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _uploadingPhoto ? null : _changePhoto,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              backgroundImage: _photoUrl.isNotEmpty
                                  ? MemoryImage(base64Decode(_photoUrl))
                                  : null,
                              child: _uploadingPhoto
                                  ? const SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : _photoUrl.isEmpty
                                      ? Text(
                                          _residentName.isNotEmpty
                                              ? _residentName[0].toUpperCase()
                                              : 'R',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold))
                                      : null,
                            ),
                            if (!_uploadingPhoto)
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt,
                                      size: 10, color: Color(0xFF1A73E8)),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(greeting,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                            Text(_residentName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.key,
                            color: Colors.white70, size: 20),
                        tooltip: 'Change My Code',
                        onPressed: _changeCode,
                      ),
                      IconButton(
                        icon: const Icon(Icons.palette_outlined,
                            color: Colors.white70, size: 20),
                        tooltip: 'Theme',
                        onPressed: () => showThemeSettingsSheet(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout,
                            color: Colors.white70, size: 20),
                        tooltip: 'Logout',
                        onPressed: _signOut,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Flat info card
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.home, color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            [
                              if (_wing.isNotEmpty) _wing,
                              if (_block.isNotEmpty) 'Block $_block',
                              if (_flatNumber.isNotEmpty) 'Flat $_flatNumber',
                            ].join(' › '),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15),
                          ),
                        ),
                        const Icon(Icons.apartment,
                            color: Colors.white54, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Quick Actions ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quick Access',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _QuickActionCard(
                        icon: Icons.celebration,
                        label: 'My Events',
                        subtitle: 'Contributions',
                        color: AppTheme.accent,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ResidentEventsScreen()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _QuickActionCard(
                        icon: Icons.people_outline,
                        label: 'Visitors',
                        subtitle: 'History',
                        color: const Color(0xFF1A73E8),
                        onTap: () {},
                      ),
                      const SizedBox(width: 12),
                      _QuickActionCard(
                        icon: Icons.temple_hindu_outlined,
                        label: 'Temple',
                        subtitle: 'Donations',
                        color: Colors.deepOrange,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TempleHomeScreen(isAdmin: false)),
                        ),
                      ),
                    ],
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

// ── My Contributions Section ─────────────────────────────────────────────────

class _MyContributionsSection extends StatelessWidget {
  final String flatNumber;
  const _MyContributionsSection({required this.flatNumber});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final events = snapshot.data?.docs ?? [];

        if (events.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.celebration_outlined,
                      color: Colors.grey.shade400, size: 28),
                  const SizedBox(width: 12),
                  Text('No active events right now',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 14)),
                ],
              ),
            ),
          );
        }

        return Column(
          children: events
              .map((eventDoc) => _EventContributionCard(
                    eventDoc: eventDoc,
                    flatNumber: flatNumber,
                  ))
              .toList(),
        );
      },
    );
  }
}

class _EventContributionCard extends StatefulWidget {
  final QueryDocumentSnapshot eventDoc;
  final String flatNumber;
  const _EventContributionCard(
      {required this.eventDoc, required this.flatNumber});

  @override
  State<_EventContributionCard> createState() => _EventContributionCardState();
}

class _EventContributionCardState extends State<_EventContributionCard> {
  List<Map<String, dynamic>> _contributions = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventDoc.id)
        .collection('contributions')
        .where('flatNumber', isEqualTo: widget.flatNumber)
        .get();
    if (mounted) {
      setState(() {
        _contributions =
            snap.docs.map((d) => d.data()).toList();
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.eventDoc.data() as Map<String, dynamic>;
    final eventName = event['name'] ?? 'Event';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventListScreen(isAdmin: false),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event header
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                color: AppTheme.accent.shade50,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.celebration,
                      color: AppTheme.accent.shade400, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(eventName,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.accent.shade700)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Active',
                        style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            // Contributions for this flat
            if (!_loaded)
              const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_contributions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.grey.shade400, size: 18),
                    const SizedBox(width: 8),
                    Text('No contribution recorded yet',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13)),
                  ],
                ),
              )
            else
              ...(_contributions.map((c) {
                final isPending = c['amountReceived'] == false;
                final amount = (c['amount'] ?? 0).toStringAsFixed(0);
                final type = c['contributionType'] ?? 'Regular';
                final mode = c['paymentMode'] ?? '';
                final note = c['notes'] ?? '';

                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Row(
                    children: [
                      // Status icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isPending
                              ? Colors.orange.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isPending
                              ? Icons.hourglass_top_rounded
                              : Icons.check_circle_rounded,
                          color: isPending
                              ? Colors.orange.shade600
                              : Colors.green.shade600,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Amount + details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('₹$amount',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                const SizedBox(width: 8),
                                if (type != 'Regular')
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      type == 'Carry Forward'
                                          ? 'CF'
                                          : 'Laddu',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (mode.isNotEmpty) mode,
                                if (note.isNotEmpty) note,
                              ].join(' • '),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      // Paid / Pending badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isPending
                              ? Colors.orange.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isPending
                                ? Colors.orange.shade200
                                : Colors.green.shade200,
                          ),
                        ),
                        child: Text(
                          isPending ? 'Pending' : 'Paid',
                          style: TextStyle(
                              color: isPending
                                  ? Colors.orange.shade700
                                  : Colors.green.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              })),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 14),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
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
          color: Theme.of(context).cardColor,
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
