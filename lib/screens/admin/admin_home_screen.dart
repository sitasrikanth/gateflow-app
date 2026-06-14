import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import '../auth/login_screen.dart';

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
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
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
                  tabs: const [
                    Tab(text: 'Residents'),
                    Tab(text: 'Guards'),
                    Tab(text: 'Visitors'),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── RESIDENTS TAB ────────────────────────────────────────────────────────────

class _ResidentsTab extends StatelessWidget {
  const _ResidentsTab();

  Future<void> _updateStatus(String docId, String status) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(docId)
        .update({'status': status});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'resident')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        final pending =
            docs.where((d) => (d['status'] ?? '') == 'pending').toList();
        final active =
            docs.where((d) => (d['status'] ?? '') == 'active').toList();
        final inactive =
            docs.where((d) => (d['status'] ?? '') == 'inactive').toList();

        if (docs.isEmpty) {
          return const _EmptyState(
              icon: Icons.people_outline,
              message: 'No residents registered yet');
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Pending section
            if (pending.isNotEmpty) ...[
              _SectionHeader(
                  label: 'Pending Approval',
                  count: pending.length,
                  color: Colors.orange),
              ...pending.map((doc) => _ResidentCard(
                    doc: doc,
                    onApprove: () => _updateStatus(doc.id, 'active'),
                    onReject: () => _updateStatus(doc.id, 'inactive'),
                  )),
              const SizedBox(height: 8),
            ],

            // Active section
            if (active.isNotEmpty) ...[
              _SectionHeader(
                  label: 'Active Residents',
                  count: active.length,
                  color: Colors.green),
              ...active.map((doc) => _ResidentCard(
                    doc: doc,
                    onDeactivate: () => _updateStatus(doc.id, 'inactive'),
                  )),
              const SizedBox(height: 8),
            ],

            // Inactive section
            if (inactive.isNotEmpty) ...[
              _SectionHeader(
                  label: 'Inactive',
                  count: inactive.length,
                  color: Colors.grey),
              ...inactive.map((doc) => _ResidentCard(
                    doc: doc,
                    onApprove: () => _updateStatus(doc.id, 'active'),
                  )),
            ],
          ],
        );
      },
    );
  }
}

class _ResidentCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onDeactivate;

  const _ResidentCard({
    required this.doc,
    this.onApprove,
    this.onReject,
    this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] ?? 'pending';
    final statusColor = status == 'active'
        ? Colors.green
        : status == 'pending'
            ? Colors.orange
            : Colors.grey;

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
                  backgroundColor:
                      const Color(0xFF1A73E8).withOpacity(0.1),
                  child: Text(
                    (data['name'] ?? 'R').substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        color: Color(0xFF1A73E8),
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['name'] ?? 'Unknown',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                          'Flat ${data['flatNumber'] ?? ''} • ${data['phone'] ?? ''}',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status[0].toUpperCase() + status.substring(1),
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (onApprove != null || onReject != null || onDeactivate != null) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onReject != null)
                    TextButton(
                      onPressed: onReject,
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.red),
                      child: const Text('Reject'),
                    ),
                  if (onDeactivate != null)
                    TextButton(
                      onPressed: onDeactivate,
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.red),
                      child: const Text('Deactivate'),
                    ),
                  if (onApprove != null) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: onApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(status == 'inactive'
                          ? 'Reactivate'
                          : 'Approve'),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
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
