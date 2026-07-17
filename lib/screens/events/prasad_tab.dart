import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import 'event_type_settings_screen.dart' show residentTabSectionsFor;

const _kMonthNames = [
  '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _dateLabel(DateTime d) => '${d.day} ${_kMonthNames[d.month]} ${d.year}';

class PrasadTab extends StatelessWidget {
  final String eventId;
  final bool isAdmin;
  final String eventTypeId;
  const PrasadTab({
    super.key,
    required this.eventId,
    required this.isAdmin,
    this.eventTypeId = '',
  });

  CollectionReference get _col => FirebaseFirestore.instance
      .collection('events').doc(eventId).collection('prasad');

  Future<void> _editMenu(BuildContext context, {DateTime? forDate, List<String> existingItems = const []}) async {
    DateTime selectedDate = forDate ?? DateTime.now();
    final items = List<String>.from(existingItems);
    final itemCtrl = TextEditingController();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom +
                MediaQuery.of(ctx).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(forDate != null ? 'Edit Prasad Menu' : 'Add Prasad Menu',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setSheetState(() => selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(_dateLabel(selectedDate)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: itemCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        hintText: 'e.g. Modak', isDense: true, border: OutlineInputBorder()),
                    onSubmitted: (v) {
                      final t = v.trim();
                      if (t.isNotEmpty) setSheetState(() { items.add(t); itemCtrl.clear(); });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.add_circle, color: AppTheme.accent),
                  onPressed: () {
                    final t = itemCtrl.text.trim();
                    if (t.isNotEmpty) setSheetState(() { items.add(t); itemCtrl.clear(); });
                  },
                ),
              ]),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: items
                    .map((it) => Chip(
                          label: Text(it),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () => setSheetState(() => items.remove(it)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: items.isEmpty ? null : () => Navigator.pop(ctx, true),
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved == true) {
      await _col.doc(_dateKey(selectedDate)).set({
        'date': Timestamp.fromDate(DateTime(selectedDate.year, selectedDate.month, selectedDate.day)),
        'items': items,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> _delete(BuildContext context, DocumentReference ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Menu'),
        content: const Text('Remove this day\'s prasad menu?'),
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
    if (confirm == true) await ref.delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: isAdmin
          ? Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
              child: FloatingActionButton.extended(
                onPressed: () => _editMenu(context),
                backgroundColor: AppTheme.accent,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Add Menu',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          : null,
      body: StreamBuilder<DocumentSnapshot>(
        stream: !isAdmin && eventTypeId.isNotEmpty
            ? FirebaseFirestore.instance
                .collection('eventTypeConfig')
                .doc(eventTypeId)
                .snapshots()
            : const Stream<DocumentSnapshot>.empty(),
        builder: (context, configSnap) {
          final configData = configSnap.data?.data() as Map<String, dynamic>?;
          final enabledSections = residentTabSectionsFor(configData, 'prasad');
          bool sectionVisible(String id) => isAdmin || enabledSections.contains(id);

          return StreamBuilder<QuerySnapshot>(
        stream: _col.orderBy('date', descending: false).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          final todayKey = _dateKey(DateTime.now());
          final todayDoc = docs.where((d) => d.id == todayKey).toList();
          final otherDocs = docs.where((d) => d.id != todayKey).toList();

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.restaurant_outlined, size: 56, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                        isAdmin
                            ? 'No prasad menu set yet — tap + to add one'
                            : 'Prasad menu hasn\'t been announced yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                  ],
                ),
              ),
            );
          }

          Widget menuCard(QueryDocumentSnapshot doc, {bool isToday = false}) {
            final data = doc.data() as Map<String, dynamic>;
            final ts = data['date'] as Timestamp?;
            final dt = ts?.toDate() ?? DateTime.now();
            final items = List<String>.from(data['items'] as List? ?? []);
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final todayBg = isDark
                ? AppTheme.accent.shade900.withValues(alpha: 0.35)
                : AppTheme.accent.shade50;
            final todayBorder = isDark ? AppTheme.accent.shade400 : AppTheme.accent.shade200;
            final todayTitleColor = isDark ? AppTheme.accent.shade100 : AppTheme.accent.shade700;
            final chipBg = isDark
                ? AppTheme.accent.shade900.withValues(alpha: 0.35)
                : AppTheme.accent.shade50;
            final chipTextColor = isDark ? AppTheme.accent.shade100 : AppTheme.accent.shade800;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isToday ? todayBg : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: isToday ? Border.all(color: todayBorder, width: 1.5) : null,
                boxShadow: isToday
                    ? []
                    : [
                        BoxShadow(
                            color: AppTheme.accent.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 3)),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.restaurant, color: AppTheme.accent.shade400, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          isToday ? "Today's Prasad — ${_dateLabel(dt)}" : _dateLabel(dt),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isToday ? 15 : 13,
                              color: isToday ? todayTitleColor : null)),
                    ),
                    if (isAdmin)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: Colors.grey.shade500, size: 18),
                        onSelected: (v) {
                          if (v == 'edit') _editMenu(context, forDate: dt, existingItems: items);
                          if (v == 'delete') _delete(context, doc.reference);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: items
                        .map((it) => Chip(
                              label: Text(it,
                                  style: TextStyle(fontSize: 12, color: chipTextColor)),
                              backgroundColor: chipBg,
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
            children: [
              if (sectionVisible('prasad_today'))
              ...todayDoc.map((d) => menuCard(d, isToday: true)),
              if (sectionVisible('prasad_other_days') && otherDocs.isNotEmpty) ...[
                if (todayDoc.isNotEmpty) const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Other Days',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade600)),
                ),
                ...otherDocs.map((d) => menuCard(d)),
              ],
            ],
          );
        },
      );
        },
      ),
    );
  }
}
