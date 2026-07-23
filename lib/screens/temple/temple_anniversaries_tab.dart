import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_temple_donation_screen.dart';

// ── Anniversary Pooja Reminders ────────────────────────────────────────────
// Recurring yearly occasions (month + day, no year) with an in-app "upcoming"
// list standing in for automatic reminders — this app has no push
// notification infra yet, so the reminder is a WhatsApp deep link (same
// pattern as the existing Follow-up tab's reminder feature) sent by the
// admin, plus residents can confirm or sponsor their own pooja.

const List<String> kOccasionTypes = [
  'Wedding Anniversary', 'Birthday Pooja', 'House Warming', 'Naming Ceremony', 'Other',
];

class TempleAnniversariesTab extends StatefulWidget {
  final bool isAdmin;
  const TempleAnniversariesTab({super.key, required this.isAdmin});

  @override
  State<TempleAnniversariesTab> createState() => _TempleAnniversariesTabState();
}

class _TempleAnniversariesTabState extends State<TempleAnniversariesTab> {
  String _sessionFlat = '';

  CollectionReference get _col => FirebaseFirestore.instance.collection('templeAnniversaries');

  @override
  void initState() {
    super.initState();
    if (!widget.isAdmin) _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _sessionFlat = prefs.getString('session_flat') ?? '');
  }

  // Days until the next occurrence of (month, day) from today, handling
  // year wraparound — an occasion that already passed this year is next
  // due next year.
  int _daysUntil(int month, int day) {
    final now = DateTime.now();
    var next = DateTime(now.year, month, day);
    final today = DateTime(now.year, now.month, now.day);
    if (next.isBefore(today)) next = DateTime(now.year + 1, month, day);
    return next.difference(today).inDays;
  }

  Future<void> _addOrEdit({DocumentSnapshot? existing}) async {
    final d = existing?.data() as Map<String, dynamic>?;
    final nameCtrl = TextEditingController(text: d?['residentName'] as String? ?? '');
    final wingCtrl = TextEditingController(text: d?['wing'] as String? ?? '');
    final blockCtrl = TextEditingController(text: d?['block'] as String? ?? '');
    final flatCtrl = TextEditingController(text: d?['flatNumber'] as String? ?? '');
    final phoneCtrl = TextEditingController(text: d?['phone'] as String? ?? '');
    final noteCtrl = TextEditingController(text: d?['note'] as String? ?? '');
    String occasionType = d?['occasionType'] as String? ?? kOccasionTypes.first;
    DateTime date = d != null
        ? DateTime(2020, (d['month'] as num?)?.toInt() ?? 1, (d['day'] as num?)?.toInt() ?? 1)
        : DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setSt) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(existing == null ? 'Add Anniversary' : 'Edit Anniversary'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Resident Name'),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: wingCtrl, decoration: const InputDecoration(labelText: 'Wing'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: blockCtrl, decoration: const InputDecoration(labelText: 'Block'))),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: TextField(controller: flatCtrl, decoration: const InputDecoration(labelText: 'Flat No'))),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone (Optional)', hintText: 'For WhatsApp reminders'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Occasion', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: kOccasionTypes.map((o) {
                      final sel = occasionType == o;
                      return ChoiceChip(
                        label: Text(o, style: const TextStyle(fontSize: 12)),
                        selected: sel,
                        onSelected: (_) => setSt(() => occasionType = o),
                        selectedColor: Colors.deepOrange.shade600,
                        labelStyle: TextStyle(color: sel ? Colors.white : Colors.grey.shade700),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_repeat_outlined),
                    title: Text('${date.day}/${date.month} (yearly)'),
                    subtitle: const Text('Tap to change date'),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setSt(() => date = picked);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Note (Optional)'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) {
                    setSt(() => error = 'Enter a resident name');
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange.shade700),
                child: Text(existing == null ? 'Add' : 'Save', style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameCtrl.dispose();
      wingCtrl.dispose();
      blockCtrl.dispose();
      flatCtrl.dispose();
      phoneCtrl.dispose();
      noteCtrl.dispose();
    });
    if (result != true) return;

    final payload = {
      'residentName': nameCtrl.text.trim(),
      'wing': wingCtrl.text.trim().toUpperCase(),
      'block': blockCtrl.text.trim().toUpperCase(),
      'flatNumber': flatCtrl.text.trim(),
      'phone': phoneCtrl.text.trim(),
      'occasionType': occasionType,
      'month': date.month,
      'day': date.day,
      'note': noteCtrl.text.trim(),
    };
    if (existing != null) {
      await existing.reference.update(payload);
    } else {
      payload['confirmed'] = false;
      payload['createdAt'] = DateTime.now().toIso8601String();
      await _col.add(payload);
    }
  }

  Future<void> _delete(DocumentReference ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Anniversary'),
        content: const Text('This will permanently remove this reminder.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) await ref.delete();
  }

  Future<void> _sendReminder(Map<String, dynamic> d) async {
    final phone = (d['phone'] as String? ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number on file for this entry')),
      );
      return;
    }
    final msg = Uri.encodeComponent(
        'Hi ${d['residentName']}, a gentle reminder that your ${d['occasionType']} pooja is coming up soon 🙏. '
        'Let us know if you\'d like to confirm or sponsor it at the temple.');
    final url = Uri.parse('https://wa.me/91$phone?text=$msg');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _toggleConfirmed(DocumentReference ref, bool current) => ref.update({
        'confirmed': !current,
        'confirmedAt': !current ? DateTime.now().toIso8601String() : null,
      });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _col.snapshots(),
      builder: (context, snap) {
        var docs = snap.data?.docs ?? [];
        if (!widget.isAdmin && _sessionFlat.isNotEmpty) {
          docs = docs
              .where((doc) => (doc.data() as Map<String, dynamic>)['flatNumber'] == _sessionFlat)
              .toList();
        }
        final sorted = docs.toList()
          ..sort((a, b) {
            final ad = a.data() as Map<String, dynamic>;
            final bd = b.data() as Map<String, dynamic>;
            final aDays = _daysUntil((ad['month'] as num?)?.toInt() ?? 1, (ad['day'] as num?)?.toInt() ?? 1);
            final bDays = _daysUntil((bd['month'] as num?)?.toInt() ?? 1, (bd['day'] as num?)?.toInt() ?? 1);
            return aDays.compareTo(bDays);
          });

        return Column(
          children: [
            if (widget.isAdmin)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _addOrEdit(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Anniversary'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: sorted.isEmpty
                  ? Center(
                      child: Text(
                          widget.isAdmin
                              ? 'No anniversaries recorded yet'
                              : 'No upcoming pooja for your flat',
                          style: TextStyle(color: Colors.grey.shade400)))
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(16, widget.isAdmin ? 0 : 16, 16, 16),
                      itemCount: sorted.length,
                      itemBuilder: (context, i) {
                        final doc = sorted[i];
                        final d = doc.data() as Map<String, dynamic>;
                        final days = _daysUntil(
                            (d['month'] as num?)?.toInt() ?? 1, (d['day'] as num?)?.toInt() ?? 1);
                        final confirmed = d['confirmed'] == true;
                        final soon = days <= 7;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: soon ? Colors.deepOrange.shade50 : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: soon ? Colors.deepOrange.shade200 : Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.celebration_outlined,
                                    size: 18,
                                    color: soon ? Colors.deepOrange.shade700 : Colors.grey.shade500),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(d['residentName'] as String? ?? '',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: Theme.of(context).textTheme.bodyLarge?.color)),
                                      Text(
                                          '${d['occasionType']} · ${d['flatNumber'] ?? ''}',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                    ],
                                  ),
                                ),
                                Text(days == 0 ? 'Today!' : 'in $days days',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: soon ? Colors.deepOrange.shade700 : Colors.grey.shade600)),
                              ]),
                              const SizedBox(height: 8),
                              Row(children: [
                                if (confirmed)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text('Confirmed',
                                        style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
                                  )
                                else
                                  TextButton.icon(
                                    onPressed: () => _toggleConfirmed(doc.reference, confirmed),
                                    icon: const Icon(Icons.check_circle_outline, size: 16),
                                    label: const Text('Confirm', style: TextStyle(fontSize: 12)),
                                  ),
                                TextButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddTempleDonationScreen(isAdmin: widget.isAdmin),
                                    ),
                                  ),
                                  icon: const Icon(Icons.favorite_outline, size: 16),
                                  label: const Text('Sponsor', style: TextStyle(fontSize: 12)),
                                ),
                                if (widget.isAdmin) ...[
                                  IconButton(
                                    icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.green),
                                    tooltip: 'Send WhatsApp Reminder',
                                    onPressed: () => _sendReminder(d),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 16),
                                    onPressed: () => _addOrEdit(existing: doc),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade400),
                                    onPressed: () => _delete(doc.reference),
                                  ),
                                ],
                              ]),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
