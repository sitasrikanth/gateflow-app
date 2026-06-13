import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResidentHomeScreen extends StatelessWidget {
  const ResidentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('My Home',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('visitors')
            .where('status', isEqualTo: 'entered')
            .orderBy('entryTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final visitors = snapshot.data?.docs ?? [];

          return CustomScrollView(
            slivers: [
              // Welcome card
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  color: const Color(0xFF1A73E8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Welcome back! 👋',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 4),
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(user?.uid)
                            .get(),
                        builder: (context, snap) {
                          final name = snap.data?.get('name') ?? 'Resident';
                          final flat =
                              snap.data?.get('flatNumber') ?? '';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold)),
                              if (flat.isNotEmpty)
                                Text('Flat $flat',
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13)),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Stats row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _StatCard(
                        icon: Icons.people,
                        label: 'Total Visitors',
                        value: visitors.length.toString(),
                        color: const Color(0xFF1A73E8),
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        icon: Icons.today,
                        label: 'Today',
                        value: visitors.where((v) {
                          final data = v.data() as Map<String, dynamic>;
                          final time = data['entryTime'] ?? '';
                          return time.startsWith(
                              DateTime.now().toString().substring(0, 10));
                        }).length.toString(),
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ),
              ),

              // Visitors header
              const SliverToBoxAdapter(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Recent Visitors',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              // Visitors list
              visitors.isEmpty
                  ? SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Column(
                            children: [
                              Icon(Icons.people_outline,
                                  size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text('No visitors yet',
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final data = visitors[index].data()
                              as Map<String, dynamic>;
                          return _VisitorCard(
                              data: data, docId: visitors[index].id);
                        },
                        childCount: visitors.length,
                      ),
                    ),
            ],
          );
        },
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

class _VisitorCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;

  const _VisitorCard({required this.data, required this.docId});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  const Color(0xFF1A73E8).withOpacity(0.1),
              child: const Icon(Icons.person, color: Color(0xFF1A73E8)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['visitorName'] ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                      'Flat ${data['flatNumber'] ?? ''} • ${data['purpose'] ?? ''}',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                    data['entryTime']?.toString().substring(11, 16) ?? '',
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Entered',
                  style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
