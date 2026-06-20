import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import '../auth/login_screen.dart';
import '../events/event_dashboard_screen.dart';
import '../events/create_event_screen.dart';
import 'settings_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 3);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Header
          Container(
            color: const Color(0xFF1A73E8),
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.admin_panel_settings,
                        color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Admin Panel',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined,
                          color: Colors.white),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      ),
                      tooltip: 'Settings',
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: _signOut,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  isScrollable: true,
                  tabs: const [
                    Tab(text: 'Residents'),
                    Tab(text: 'Guards'),
                    Tab(text: 'Visitors'),
                    Tab(text: 'Events'),
                  ],
                ),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _ResidentsTab(),
                _GuardsTab(),
                _VisitorsTab(),
                _EventsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── RESIDENTS TAB ────────────────────────────────────────────────────────────

class _ResidentsTab extends StatefulWidget {
  const _ResidentsTab();

  @override
  State<_ResidentsTab> createState() => _ResidentsTabState();
}

class _ResidentsTabState extends State<_ResidentsTab> {
  String _generateCode() =>
      List.generate(6, (_) => Random().nextInt(10)).join();

  Widget _dropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required String Function(String) displayText,
    required ValueChanged<String?>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              underline: const SizedBox(),
              hint: Text(label,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
              items: items
                  .map((i) => DropdownMenuItem(
                      value: i, child: Text(displayText(i))))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addUser(String role) async {
    final nameCtrl = TextEditingController();

    final code = _generateCode();

    // Load community structure for wing/block dropdowns
    List<String> wingNames = [];
    Map<String, dynamic> wingBlocks = {};
    try {
      final doc = await FirebaseFirestore.instance
          .collection('community_settings')
          .doc('address')
          .get();
      if (doc.exists) {
        wingNames = List<String>.from(doc.data()?['wings'] ?? []);
        wingBlocks = Map<String, dynamic>.from(doc.data()?['wingBlocks'] ?? {});
      }
    } catch (_) {}

    if (!mounted) return;

    String? selectedWing;
    String? selectedBlock;
    String? selectedFlat;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final sortedWingNames = List<String>.from(wingNames)..sort();

          List<String> blocksForWing(String? wing) {
            if (wing == null) return [];
            final raw = wingBlocks[wing];
            if (raw is Map) return (raw.keys.cast<String>().toList())..sort();
            if (raw is List) return List<String>.from(raw)..sort();
            return [];
          }

          List<String> flatsForBlock(String? wing, String? block) {
            if (wing == null || block == null) return [];
            final raw = wingBlocks[wing];
            if (raw is Map) {
              final blockData = raw[block];
              if (blockData is List) return List<String>.from(blockData)..sort();
            }
            return [];
          }

          final blockNames = blocksForWing(selectedWing);
          final flatNames = flatsForBlock(selectedWing, selectedBlock);

          return Padding(
            padding: EdgeInsets.fromLTRB(
                24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(children: [
                    Text('Add ${role == 'admin' ? 'Admin' : 'Resident'}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close)),
                  ]),
                  const SizedBox(height: 16),

                  // Name
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Full Name *',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Wing / Block / Flat — only for residents
                  if (role == 'resident') ...[
                    if (sortedWingNames.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text(
                          'No community structure set up yet. Go to Community Settings first.',
                          style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                        ),
                      )
                    else ...[
                      _dropdownField(
                        label: 'Wing *',
                        icon: Icons.apartment_outlined,
                        value: selectedWing,
                        items: sortedWingNames,
                        displayText: (w) => w,
                        onChanged: (val) => setSheet(() {
                          selectedWing = val;
                          selectedBlock = null;
                          selectedFlat = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      _dropdownField(
                        label: selectedWing == null ? 'Select wing first' : 'Block *',
                        icon: Icons.domain_outlined,
                        value: selectedBlock,
                        items: blockNames,
                        displayText: (b) => 'Block $b',
                        onChanged: selectedWing == null
                            ? null
                            : (val) => setSheet(() {
                                  selectedBlock = val;
                                  selectedFlat = null;
                                }),
                      ),
                      const SizedBox(height: 12),
                      if (selectedBlock != null && flatNames.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.orange.shade700, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No flats added to Block $selectedBlock yet. Please add flats in Community Settings first.',
                                style: TextStyle(
                                    color: Colors.orange.shade800, fontSize: 12),
                              ),
                            ),
                          ]),
                        )
                      else ...[
                        _dropdownField(
                          label: selectedBlock == null ? 'Select block first' : 'Flat *',
                          icon: Icons.home_outlined,
                          value: selectedFlat,
                          items: flatNames,
                          displayText: (f) => f,
                          onChanged: selectedBlock == null
                              ? null
                              : (val) => setSheet(() => selectedFlat = val),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ],
                  const SizedBox(height: 16),

                  // Quick code display
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(children: [
                      Icon(Icons.key, color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Quick Code (auto-generated)',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.blue.shade600)),
                          Text(code,
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4,
                                  color: Colors.blue.shade800)),
                        ],
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) return;
                        if (role == 'resident') {
                          if (sortedWingNames.isNotEmpty && selectedWing == null) return;
                          if (sortedWingNames.isNotEmpty && selectedBlock == null) return;
                          if (sortedWingNames.isNotEmpty && selectedFlat == null) return;
                        }
                        final name = nameCtrl.text.trim();
                        await FirebaseFirestore.instance
                            .collection('users')
                            .add({
                          'name': name,
                          'flatNumber': selectedFlat ?? '',
                          'wing': selectedWing ?? '',
                          'block': selectedBlock ?? '',
                          'role': role,
                          'status': 'active',
                          'quickCode': code,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          _showCodeDialog(name, code, role);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A73E8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Add & Save Code'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameCtrl.dispose();
    });
  }

  void _showPendingSheet(BuildContext context, List<DocumentSnapshot> pending) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(children: [
                  Icon(Icons.pending_actions, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Text(
                    '${pending.length} Pending Registration${pending.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: pending.length,
                  itemBuilder: (ctx, i) {
                    final doc = pending[i];
                    final d = doc.data() as Map<String, dynamic>;
                    final flat = d['flatNumber'] ?? '';
                    final wing = d['wing'] ?? '';
                    final block = d['block'] ?? '';
                    final location = [
                      if (wing.isNotEmpty) wing,
                      if (block.isNotEmpty) 'Block $block',
                      if (flat.isNotEmpty) flat,
                    ].join(' › ');
                    return _PendingRegistrationCard(
                      doc: doc,
                      data: d,
                      location: location,
                      flat: flat,
                      onApprove: () {
                        Navigator.pop(context);
                        _approveRegistration(context, doc, d);
                      },
                      onReject: () {
                        Navigator.pop(context);
                        _rejectRegistration(context, doc, d);
                      },
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

  Future<void> _approveRegistration(BuildContext context,
      DocumentSnapshot doc, Map<String, dynamic> d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Approve Registration'),
        content: Text('Approve ${d['name']} for flat ${d['flatNumber']}? '
            'A Quick Code will be generated for them.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Approve')),
        ],
      ),
    );
    if (confirmed != true) return;

    final code = _generateCode();
    final wing = d['wing'] ?? '';
    final block = d['block'] ?? '';
    final flat = d['flatNumber'] ?? '';
    final location = [
      if (wing.isNotEmpty) wing,
      if (block.isNotEmpty) 'Block $block',
      if (flat.isNotEmpty) flat,
    ].join(' › ');

    await FirebaseFirestore.instance.collection('users').add({
      'name': d['name'] ?? '',
      'phone': d['phone'] ?? '',
      'flatNumber': flat,
      'wing': wing,
      'block': block,
      'role': 'resident',
      'status': 'active',
      'quickCode': code,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await doc.reference.delete();

    if (context.mounted) {
      _showCodeDialog(d['name'] ?? '', code, 'resident',
          phone: d['phone'] ?? '', location: location);
    }
  }

  Future<void> _rejectRegistration(BuildContext context,
      DocumentSnapshot doc, Map<String, dynamic> d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Registration'),
        content: Text('Reject registration request from ${d['name']}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reject')),
        ],
      ),
    );
    if (confirmed != true) return;

    await doc.reference.update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
    });

    if (!context.mounted) return;

    final name = d['name'] ?? '';
    final phone = d['phone'] ?? '';
    final flat = d['flatNumber'] ?? '';
    final wing = d['wing'] ?? '';
    final block = d['block'] ?? '';
    final location = [
      if (wing.isNotEmpty) wing,
      if (block.isNotEmpty) 'Block $block',
      if (flat.isNotEmpty) flat,
    ].join(' › ');

    final message = Uri.encodeComponent(
      'Hi $name, your registration request for $location has not been approved by the society admin. '
      'Please contact the society office for more information.',
    );
    final waUrl = Uri.parse('https://wa.me/91$phone?text=$message');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          Icon(Icons.cancel_outlined, color: Colors.red.shade600),
          const SizedBox(width: 8),
          const Text('Registration Rejected'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$name has been rejected.'),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Notify them via WhatsApp?',
                  style: TextStyle(
                      color: Colors.grey.shade700, fontSize: 13)),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip')),
          if (phone.isNotEmpty)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white),
              icon: const Icon(Icons.chat, size: 16),
              label: const Text('Open WhatsApp'),
              onPressed: () async {
                Navigator.pop(context);
                await launchUrl(waUrl,
                    mode: LaunchMode.externalApplication);
              },
            ),
        ],
      ),
    );
  }

  void _showCodeDialog(String name, String code, String role,
      {String phone = '', String location = ''}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('User Created!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share this code with $name:',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(code,
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6)),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied!')),
                      );
                    },
                    child: Icon(Icons.copy, color: Colors.green.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'They can use this code to log in as ${role == 'admin' ? 'Admin' : 'Resident'}.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
          if (phone.isNotEmpty)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.chat, size: 16),
              label: const Text('WhatsApp'),
              onPressed: () async {
                Navigator.pop(ctx);
                final msg = Uri.encodeComponent(
                  'Hi $name, your registration for${location.isNotEmpty ? ' $location' : ''} has been approved! '
                  'Your GateFlow Quick Code is: *$code*. '
                  'Use this 6-digit code to log in to the app.',
                );
                final url = Uri.parse('https://wa.me/91$phone?text=$msg');
                await launchUrl(url, mode: LaunchMode.externalApplication);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _toggleStatus(String docId, String current) async {
    final newStatus = current == 'active' ? 'inactive' : 'active';
    await FirebaseFirestore.instance
        .collection('users')
        .doc(docId)
        .update({'status': newStatus});
  }

  Future<void> _deleteUser(String docId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade600),
          const SizedBox(width: 8),
          const Text('Delete Resident'),
        ]),
        content: Text(
          'Delete $name permanently? They will lose access to the app and cannot log in.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await FirebaseFirestore.instance.collection('users').doc(docId).delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name has been deleted')));
    }
  }

  Future<void> _resetCode(String docId, String name, String role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Quick Code?'),
        content: Text(
            'This will generate a new code for $name. Their current code will stop working immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final newCode = _generateCode();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(docId)
        .update({'quickCode': newCode});
    if (mounted) _showCodeDialog(name, newCode, role);
  }

  void _showFlatResidents(BuildContext context, String flatLabel,
      List<Map<String, dynamic>> residents) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(children: [
                  const Icon(Icons.home, color: Color(0xFF1A73E8)),
                  const SizedBox(width: 8),
                  Text(flatLabel,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('${residents.length} resident${residents.length == 1 ? '' : 's'}',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ]),
              ),
              const Divider(height: 1),
              if (residents.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No residents registered for this flat.',
                      style: TextStyle(color: Colors.grey)),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: ctrl,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: residents.length,
                    itemBuilder: (ctx, i) {
                      final r = residents[i];
                      final docId = r['_docId'] as String;
                      final name = r['name'] ?? 'Unknown';
                      final status = r['status'] ?? 'active';
                      final role = r['role'] ?? 'resident';
                      final isActive = status == 'active';
                      final isAdmin = role == 'admin';

                      return Container(
                        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isAdmin
                                      ? Colors.deepPurple.shade50
                                      : const Color(0xFF1A73E8)
                                          .withValues(alpha: 0.1),
                                  child: Icon(
                                    isAdmin
                                        ? Icons.admin_panel_settings
                                        : Icons.person,
                                    color: isAdmin
                                        ? Colors.deepPurple
                                        : const Color(0xFF1A73E8),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14)),
                                      Text(
                                        role[0].toUpperCase() + role.substring(1),
                                        style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? Colors.green.shade50
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                        color: isActive
                                            ? Colors.green.shade700
                                            : Colors.grey.shade600,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(children: [
                                  Icon(Icons.key,
                                      size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 6),
                                  Text(r['quickCode'] ?? '------',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          letterSpacing: 4)),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(
                                          text: r['quickCode'] ?? ''));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text('Code copied!')));
                                    },
                                    child: Icon(Icons.copy,
                                        size: 14, color: Colors.grey.shade400),
                                  ),
                                ]),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _resetCode(docId, name, role);
                                    },
                                    style: TextButton.styleFrom(
                                        foregroundColor: Colors.blue.shade700,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8)),
                                    icon: const Icon(Icons.refresh, size: 14),
                                    label: const Text('Reset',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                  const SizedBox(width: 4),
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _toggleStatus(docId, status);
                                    },
                                    style: TextButton.styleFrom(
                                        foregroundColor: isActive
                                            ? Colors.orange
                                            : Colors.green,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8)),
                                    icon: Icon(
                                      isActive
                                          ? Icons.block
                                          : Icons.check_circle_outline,
                                      size: 14,
                                    ),
                                    label: Text(
                                        isActive ? 'Deactivate' : 'Reactivate',
                                        style: const TextStyle(fontSize: 12)),
                                  ),
                                  const SizedBox(width: 4),
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _deleteUser(docId, name);
                                    },
                                    style: TextButton.styleFrom(
                                        foregroundColor: Colors.red.shade700,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8)),
                                    icon: const Icon(Icons.delete_outline,
                                        size: 14),
                                    label: const Text('Delete',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
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
    return Column(
      children: [
        // Add buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _addUser('resident'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Add Resident'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _addUser('admin'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.admin_panel_settings, size: 18),
                  label: const Text('Add Admin'),
                ),
              ),
            ],
          ),
        ),
        // Pending Registrations banner
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('pending_registrations')
              .where('status', isEqualTo: 'pending')
              .orderBy('requestedAt', descending: false)
              .snapshots(),
          builder: (context, snap) {
            final pending = snap.data?.docs ?? [];
            if (pending.isEmpty) return const SizedBox();
            return InkWell(
              onTap: () => _showPendingSheet(context, pending),
              child: Container(
                color: Colors.orange.shade50,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.pending_actions,
                        color: Colors.orange.shade700, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${pending.length} Pending Registration${pending.length > 1 ? 's' : ''}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                              fontSize: 14),
                        ),
                        Text('Tap to review',
                            style: TextStyle(
                                color: Colors.orange.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.orange.shade700),
                ]),
              ),
            );
          },
        ),
        const Divider(height: 1),
        // Wing → Block → Flat hierarchy
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .snapshots(),
            builder: (context, userSnap) {
              // Build flat → residents map from all users
              final allUsers = userSnap.data?.docs ?? [];
              final Map<String, List<Map<String, dynamic>>> flatResidents = {};
              for (final doc in allUsers) {
                final d = doc.data() as Map<String, dynamic>;
                final flat = (d['flatNumber'] ?? '').toString();
                if (flat.isEmpty) continue;
                flatResidents.putIfAbsent(flat, () => []);
                flatResidents[flat]!.add({...d, '_docId': doc.id});
              }

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('community_settings')
                    .doc('address')
                    .snapshots(),
                builder: (context, settingsSnap) {
                  final settings = settingsSnap.data?.data()
                          as Map<String, dynamic>? ??
                      {};
                  final wings =
                      List<String>.from(settings['wings'] ?? [])..sort();
                  final wingBlocks = Map<String, dynamic>.from(
                      settings['wingBlocks'] ?? {});

                  if (wings.isEmpty) {
                    return const _EmptyState(
                      icon: Icons.apartment_outlined,
                      message:
                          'No community structure set up yet.\nGo to Community Settings to add wings.',
                    );
                  }

                  // Also show admin users (no flat) separately
                  final admins = allUsers
                      .where((d) =>
                          (d.data() as Map)['role'] == 'admin')
                      .toList();

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    children: [
                      // Wing expansion tiles
                      for (final wing in wings)
                        _buildWingTile(
                            context, wing, wingBlocks, flatResidents),
                      // Admins section
                      if (admins.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildAdminsTile(context, admins),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWingTile(
    BuildContext context,
    String wing,
    Map<String, dynamic> wingBlocks,
    Map<String, List<Map<String, dynamic>>> flatResidents,
  ) {
    final raw = wingBlocks[wing];
    final Map<String, dynamic> wingData =
        raw is Map ? Map<String, dynamic>.from(raw) : {};
    final blocks = wingData.keys.toList()..sort();

    int totalFlats = 0;
    int occupied = 0;
    for (final block in blocks) {
      final flats = List<String>.from(
          wingData[block] is List ? wingData[block] : []);
      totalFlats += flats.length;
      occupied +=
          flats.where((f) => (flatResidents[f]?.isNotEmpty ?? false)).length;
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
        key: PageStorageKey('res_wing_$wing'),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.blue.shade50,
          child: Text(wing[0].toUpperCase(),
              style: TextStyle(
                  color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
        ),
        title: Text('$wing Wing',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '$occupied/$totalFlats flats occupied',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
                    context, wing, block, wingData, flatResidents))
                .toList(),
      ),
    );
  }

  Widget _buildBlockTile(
    BuildContext context,
    String wing,
    String block,
    Map<String, dynamic> wingData,
    Map<String, List<Map<String, dynamic>>> flatResidents,
  ) {
    final flats = List<String>.from(
        wingData[block] is List ? wingData[block] : [])
      ..sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.purple.shade100),
        ),
        child: ExpansionTile(
          key: PageStorageKey('res_block_${wing}_$block'),
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
          subtitle: Text(
            '${flats.length} flat${flats.length == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: flats.isEmpty
                  ? Text('No flats added.',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12))
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: flats.map((flat) {
                        final residents = flatResidents[flat] ?? [];
                        // Determine chip color by resident statuses
                        Color chipColor;
                        Color textColor;
                        Color borderColor;
                        if (residents.isEmpty) {
                          chipColor = Colors.grey.shade100;
                          textColor = Colors.grey.shade500;
                          borderColor = Colors.grey.shade300;
                        } else if (residents.any(
                            (r) => r['status'] == 'active')) {
                          chipColor = Colors.green.shade50;
                          textColor = Colors.green.shade700;
                          borderColor = Colors.green.shade300;
                        } else if (residents.any(
                            (r) => r['status'] == 'pending')) {
                          chipColor = Colors.orange.shade50;
                          textColor = Colors.orange.shade700;
                          borderColor = Colors.orange.shade300;
                        } else {
                          chipColor = Colors.red.shade50;
                          textColor = Colors.red.shade700;
                          borderColor = Colors.red.shade200;
                        }

                        final location =
                            '$wing › Block $block › $flat';

                        return GestureDetector(
                          onTap: () => _showFlatResidents(
                              context, location, residents),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: chipColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            child: Text(
                              flat,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textColor),
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

  Widget _buildAdminsTile(
      BuildContext context, List<QueryDocumentSnapshot> admins) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.shade100),
      ),
      child: ExpansionTile(
        key: const PageStorageKey('res_admins'),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.deepPurple.shade50,
          child: Icon(Icons.admin_panel_settings,
              color: Colors.deepPurple, size: 18),
        ),
        title: const Text('Admins',
            style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${admins.length} admin${admins.length == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        children: admins.map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final name = d['name'] ?? 'Unknown';
          final isActive = d['status'] == 'active';
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.deepPurple.shade50,
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'A',
                  style: TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold)),
            ),
            title: Text(name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(d['quickCode'] ?? '------',
                style: const TextStyle(letterSpacing: 3, fontSize: 13)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                        color: isActive
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.more_vert,
                      color: Colors.grey.shade500, size: 20),
                  onPressed: () => _showFlatResidents(context,
                      'Admin: $name', [{...d, '_docId': doc.id}]),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── PENDING REGISTRATION CARD ───────────────────────────────────────────────

class _PendingRegistrationCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final Map<String, dynamic> data;
  final String location;
  final String flat;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingRegistrationCard({
    required this.doc,
    required this.data,
    required this.location,
    required this.flat,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] ?? '';
    final phone = data['phone'] ?? '';

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .where('flatNumber', isEqualTo: flat)
          .where('status', isEqualTo: 'active')
          .get(),
      builder: (context, snap) {
        final existing = snap.data?.docs ?? [];
        final isDuplicateName = existing.any((d) =>
            (d.data() as Map)['name']?.toString().toLowerCase() ==
            name.toLowerCase());

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + location
                Row(children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.orange.shade100,
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(location,
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13)),
                        if (phone.isNotEmpty)
                          Text('+91 $phone',
                              style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ]),

                // Existing residents for this flat
                if (existing.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDuplicateName
                          ? Colors.red.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isDuplicateName
                              ? Colors.red.shade200
                              : Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(
                            isDuplicateName
                                ? Icons.warning_amber_rounded
                                : Icons.info_outline,
                            size: 14,
                            color: isDuplicateName
                                ? Colors.red.shade700
                                : Colors.blue.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isDuplicateName
                                ? 'Possible duplicate — same name already active'
                                : '${existing.length} active resident(s) in this flat:',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDuplicateName
                                    ? Colors.red.shade700
                                    : Colors.blue.shade700),
                          ),
                        ]),
                        ...existing.map((e) {
                          final ed = e.data() as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4, left: 20),
                            child: Text(
                              '• ${ed['name'] ?? 'Unknown'}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade700),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── GUARDS TAB ───────────────────────────────────────────────────────────────

class _GuardsTab extends StatefulWidget {
  const _GuardsTab();

  @override
  State<_GuardsTab> createState() => _GuardsTabState();
}

class _GuardsTabState extends State<_GuardsTab> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isAdding = false;
  bool _saving = false;

  String _generateCode() {
    final rng = Random();
    return List.generate(6, (_) => rng.nextInt(10)).join();
  }

  Future<void> _addGuard() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);

    final code = _generateCode();
    await FirebaseFirestore.instance.collection('guards').add({
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'quickCode': code,
      'status': 'active',
      'createdAt': DateTime.now().toIso8601String(),
    });

    _nameController.clear();
    _phoneController.clear();
    setState(() {
      _saving = false;
      _isAdding = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Guard added! Quick Code: $code'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _deactivateGuard(String docId) async {
    await FirebaseFirestore.instance
        .collection('guards')
        .doc(docId)
        .update({'status': 'inactive'});
  }

  Future<void> _reactivateGuard(String docId) async {
    await FirebaseFirestore.instance
        .collection('guards')
        .doc(docId)
        .update({'status': 'active'});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Add guard button / form
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: _isAdding
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add New Guard',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Guard Name *',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: InputDecoration(
                        labelText: 'Phone (optional)',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () =>
                              setState(() => _isAdding = false),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saving ? null : _addGuard,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A73E8),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2))
                                : const Text('Add Guard & Generate Code'),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _isAdding = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A73E8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add New Guard'),
                  ),
                ),
        ),
        const Divider(height: 1),

        // Guards list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('guards')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const _EmptyState(
                    icon: Icons.security,
                    message: 'No guards added yet');
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final isActive = (data['status'] ?? '') == 'active';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
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
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.indigo.shade50,
                                child: Icon(Icons.security,
                                    color: Colors.indigo.shade400,
                                    size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(data['name'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                    if ((data['phone'] ?? '').isNotEmpty)
                                      Text(data['phone'],
                                          style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 13)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? Colors.green.shade50
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                      color: isActive
                                          ? Colors.green.shade700
                                          : Colors.grey.shade600,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Quick code display
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.lock_outline,
                                    size: 16,
                                    color: Colors.grey.shade500),
                                const SizedBox(width: 8),
                                Text('Quick Code: ',
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 13)),
                                Text(
                                  data['quickCode'] ?? '------',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      letterSpacing: 4),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(
                                        text: data['quickCode'] ?? ''));
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(
                                      content:
                                          Text('Code copied to clipboard'),
                                      duration: Duration(seconds: 2),
                                    ));
                                  },
                                  child: Icon(Icons.copy,
                                      size: 16,
                                      color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (isActive)
                                TextButton(
                                  onPressed: () =>
                                      _deactivateGuard(docs[i].id),
                                  style: TextButton.styleFrom(
                                      foregroundColor: Colors.red),
                                  child: const Text('Deactivate'),
                                )
                              else
                                TextButton(
                                  onPressed: () =>
                                      _reactivateGuard(docs[i].id),
                                  style: TextButton.styleFrom(
                                      foregroundColor: Colors.green),
                                  child: const Text('Reactivate'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── VISITORS TAB ─────────────────────────────────────────────────────────────

class _VisitorsTab extends StatelessWidget {
  const _VisitorsTab();

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStart =
        DateTime(today.year, today.month, today.day).toIso8601String();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('visitors')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        // Sort in memory by entryTime descending
        final sorted = List.of(docs);
        sorted.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['entryTime'] ?? '';
          final bTime = (b.data() as Map<String, dynamic>)['entryTime'] ?? '';
          return bTime.compareTo(aTime);
        });

        final todayCount = sorted.where((d) {
          final entry = ((d.data() as Map<String, dynamic>)['entryTime'] ?? '') as String;
          return entry.startsWith(todayStart.substring(0, 10));
        }).length;

        if (sorted.isEmpty) {
          return const _EmptyState(
              icon: Icons.people_outline,
              message: 'No visitors logged yet');
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Stats row
            Row(
              children: [
                _MiniStat(
                    label: 'Today',
                    value: todayCount.toString(),
                    color: const Color(0xFF1A73E8)),
                const SizedBox(width: 12),
                _MiniStat(
                    label: 'Total',
                    value: sorted.length.toString(),
                    color: Colors.purple),
              ],
            ),
            const SizedBox(height: 16),
            const Text('All Visitors',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...sorted.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final visitorName = (data['visitorName'] as String?) ?? 'Unknown';
              final entryTime = (data['entryTime'] as String?) ?? '';
              final displayTime = entryTime.length >= 16
                  ? entryTime.substring(11, 16)
                  : '';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
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
                  leading: CircleAvatar(
                    backgroundColor:
                        const Color(0xFF1A73E8).withOpacity(0.1),
                    child: Text(
                      visitorName.isNotEmpty
                          ? visitorName[0].toUpperCase()
                          : 'V',
                      style: const TextStyle(
                          color: Color(0xFF1A73E8),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(visitorName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      'Flat ${data['flatNumber'] ?? ''} • ${data['purpose'] ?? ''}'),
                  trailing: Text(
                    displayTime,
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 12),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ─── SHARED WIDGETS ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SectionHeader(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color)),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Text('$count',
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(message,
              style:
                  TextStyle(color: Colors.grey.shade400, fontSize: 15)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color.withOpacity(0.7), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ─── EVENTS TAB ───────────────────────────────────────────────────────────────

// ─── EVENTS TAB ───────────────────────────────────────────────────────────────

class _EventsTab extends StatefulWidget {
  const _EventsTab();

  @override
  State<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<_EventsTab>
    with SingleTickerProviderStateMixin {
  late TabController _innerTab;

  @override
  void initState() {
    super.initState();
    _innerTab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _innerTab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub-tab bar + Create button row
        Container(
          color: Colors.deepPurple.shade50,
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _innerTab,
                  labelColor: Colors.deepPurple,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.deepPurple,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Active'),
                    Tab(text: 'Closed'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle,
                    color: Colors.deepPurple, size: 28),
                tooltip: 'Create Event',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CreateEventScreen()),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _innerTab,
            children: const [
              _AdminEventList(status: 'active'),
              _AdminEventList(status: 'closed'),
            ],
          ),
        ),
      ],
    );
  }
}

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

class _AdminEventList extends StatelessWidget {
  final String status;
  const _AdminEventList({required this.status});

  Color _colorFor(int i) => _kEventColors[i % _kEventColors.length];

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

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
                  status == 'active'
                      ? 'No active events'
                      : 'No closed events yet',
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 15,
                      fontWeight: FontWeight.w500),
                ),
                if (status == 'active') ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CreateEventScreen()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Create First Event'),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          itemCount: events.length,
          itemBuilder: (context, i) {
            final data = events[i].data() as Map<String, dynamic>;
            final double collected = ((data['totalCollected'] ?? 0) as num).toDouble();
            final double spent = ((data['totalSpent'] ?? 0) as num).toDouble();
            final double target = ((data['targetAmount'] ?? 0) as num).toDouble();
            final double balance = collected - spent;
            final double progress =
                target > 0 ? ((collected / target).clamp(0.0, 1.0) as num).toDouble() : 0.0;
            final cardColor = _colorFor(i);

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventDashboardScreen(
                    eventId: events[i].id,
                    eventName: data['name'] ?? '',
                    isAdmin: true,
                  ),
                ),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: cardColor.withValues(alpha: 0.18),
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
                        padding:
                            const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
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
                                          fontWeight: FontWeight.bold,
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
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
                                _MiniStatChip(
                                    label: 'Collected',
                                    value: '₹${_fmt(collected)}',
                                    color: Colors.green),
                                const SizedBox(width: 8),
                                _MiniStatChip(
                                    label: 'Spent',
                                    value: '₹${_fmt(spent)}',
                                    color: Colors.red),
                                const SizedBox(width: 8),
                                _MiniStatChip(
                                    label: 'Balance',
                                    value: '₹${_fmt(balance)}',
                                    color: Colors.blue),
                              ],
                            ),
                            if (target > 0) ...[
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Target: ₹${_fmt(target)}',
                                      style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 12)),
                                  Text(
                                      '${(progress * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: cardColor)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor:
                                      AlwaysStoppedAnimation(cardColor),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('View Dashboard',
                                    style: TextStyle(
                                        color: cardColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_forward_rounded,
                                    color: cardColor, size: 16),
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
        );
      },
    );
  }
}

class _MiniStatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
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
                    fontSize: 10,
                    color: color.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }
}
