import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  Future<void> _addUser(String role) async {
    final nameCtrl = TextEditingController();
    final flatCtrl = TextEditingController();
    final code = _generateCode();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add ${role == 'admin' ? 'Admin' : 'Resident'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            TextField(
              controller: flatCtrl,
              decoration: InputDecoration(
                labelText: role == 'admin' ? 'Flat (optional)' : 'Flat Number *',
                prefixIcon: const Icon(Icons.home_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
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
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => nameCtrl.dispose());
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => flatCtrl.dispose());
              Navigator.pop(ctx);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              if (role == 'resident' && flatCtrl.text.trim().isEmpty) return;
              await FirebaseFirestore.instance.collection('users').add({
                'name': nameCtrl.text.trim(),
                'flatNumber': flatCtrl.text.trim(),
                'role': role,
                'status': 'active',
                'quickCode': code,
                'createdAt': FieldValue.serverTimestamp(),
              });
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => nameCtrl.dispose());
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => flatCtrl.dispose());
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                _showCodeDialog(nameCtrl.text.trim(), code, role);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A73E8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Add & Save Code'),
          ),
        ],
      ),
    );
  }

  void _showCodeDialog(String name, String code, String role) {
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
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Done'),
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
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const _EmptyState(
                    icon: Icons.people_outline,
                    message: 'No users yet. Add a resident or admin.');
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final role = data['role'] ?? 'resident';
                  final isActive = data['status'] == 'active';
                  final isAdmin = role == 'admin';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
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
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isAdmin
                                    ? Colors.deepPurple.shade50
                                    : const Color(0xFF1A73E8)
                                        .withValues(alpha: 0.1),
                                child: Icon(
                                  isAdmin
                                      ? Icons.admin_panel_settings
                                      : Icons.home,
                                  color: isAdmin
                                      ? Colors.deepPurple
                                      : const Color(0xFF1A73E8),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(data['name'] ?? 'Unknown',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                    Text(
                                      [
                                        if ((data['flatNumber'] ?? '')
                                            .isNotEmpty)
                                          'Flat ${data['flatNumber']}',
                                        role[0].toUpperCase() +
                                            role.substring(1),
                                      ].join(' • '),
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13),
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
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Quick code row
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.key,
                                    size: 16, color: Colors.grey.shade500),
                                const SizedBox(width: 8),
                                Text('Code: ',
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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Code copied!')),
                                    );
                                  },
                                  child: Icon(Icons.copy,
                                      size: 16, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _resetCode(
                                    docs[i].id, data['name'] ?? '', data['role'] ?? 'resident'),
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.blue.shade700),
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Reset Code'),
                              ),
                              TextButton(
                                onPressed: () => _toggleStatus(
                                    docs[i].id, data['status'] ?? 'active'),
                                style: TextButton.styleFrom(
                                    foregroundColor: isActive
                                        ? Colors.red
                                        : Colors.green),
                                child: Text(
                                    isActive ? 'Deactivate' : 'Reactivate'),
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
            final collected = (data['totalCollected'] ?? 0).toDouble();
            final spent = (data['totalSpent'] ?? 0).toDouble();
            final target = (data['targetAmount'] ?? 0).toDouble();
            final balance = collected - spent;
            final progress =
                target > 0 ? (collected / target).clamp(0.0, 1.0) : 0.0;
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
