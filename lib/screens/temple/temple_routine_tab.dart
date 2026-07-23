import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Daily Temple Routine ──────────────────────────────────────────────────────
// Four sections in one scrollable tab: daily pooja schedule, priest
// assignments (both configured in one settings doc, same live-stream pattern
// used everywhere else), festival/special-event calendar (its own
// collection, dated), and a ritual checklist template whose completion state
// resets automatically every day (a fresh date = a fresh, empty log doc).

const List<String> kWeekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class TempleRoutineTab extends StatefulWidget {
  final bool isAdmin;
  const TempleRoutineTab({super.key, required this.isAdmin});

  @override
  State<TempleRoutineTab> createState() => _TempleRoutineTabState();
}

class _TempleRoutineTabState extends State<TempleRoutineTab> {
  static final DocumentReference _routineRef =
      FirebaseFirestore.instance.collection('appSettings').doc('templeRoutine');
  static CollectionReference get _festivalsCol =>
      FirebaseFirestore.instance.collection('templeFestivals');

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  DocumentReference get _todayLogRef =>
      FirebaseFirestore.instance.collection('templeRitualLog').doc(_todayKey);

  Future<void> _writeSchedule(List<Map<String, dynamic>> schedule) =>
      _routineRef.set({'dailySchedule': schedule}, SetOptions(merge: true));

  Future<void> _writePriests(List<Map<String, dynamic>> priests) =>
      _routineRef.set({'priests': priests}, SetOptions(merge: true));

  Future<void> _writeChecklist(List<String> checklist) =>
      _routineRef.set({'ritualChecklist': checklist}, SetOptions(merge: true));

  Future<void> _addOrEditScheduleItem(
      List<Map<String, dynamic>> current, {Map<String, dynamic>? existing, int? index}) async {
    final titleCtrl = TextEditingController(text: existing?['title'] as String? ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] as String? ?? '');
    TimeOfDay time = existing != null && (existing['time'] as String?)?.isNotEmpty == true
        ? TimeOfDay(
            hour: int.tryParse((existing['time'] as String).split(':')[0]) ?? 6,
            minute: int.tryParse((existing['time'] as String).split(':')[1]) ?? 0)
        : const TimeOfDay(hour: 6, minute: 0);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(existing == null ? 'Add Schedule Item' : 'Edit Schedule Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: Text(time.format(ctx)),
                  onTap: () async {
                    final picked = await showTimePicker(context: ctx, initialTime: time);
                    if (picked != null) setSt(() => time = picked);
                  },
                ),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Suprabhatam'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description (Optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange.shade700),
              child: Text(existing == null ? 'Add' : 'Save', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      titleCtrl.dispose();
      descCtrl.dispose();
    });
    if (result != true || titleCtrl.text.trim().isEmpty) return;

    final entry = {
      'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      'title': titleCtrl.text.trim(),
      'description': descCtrl.text.trim(),
    };
    final updated = List<Map<String, dynamic>>.from(current);
    if (index != null) {
      updated[index] = entry;
    } else {
      updated.add(entry);
    }
    updated.sort((a, b) => (a['time'] as String).compareTo(b['time'] as String));
    await _writeSchedule(updated);
  }

  Future<void> _addOrEditPriest(
      List<Map<String, dynamic>> current, {Map<String, dynamic>? existing, int? index}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone'] as String? ?? '');
    final days = Set<String>.from((existing?['days'] as List?) ?? []);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(existing == null ? 'Add Priest' : 'Edit Priest'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone (Optional)'),
                ),
                const SizedBox(height: 12),
                const Text('Assigned Days', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: kWeekDays.map((day) {
                    final sel = days.contains(day);
                    return FilterChip(
                      label: Text(day, style: const TextStyle(fontSize: 12)),
                      selected: sel,
                      onSelected: (v) => setSt(() => v ? days.add(day) : days.remove(day)),
                      selectedColor: Colors.deepOrange.shade600,
                      labelStyle: TextStyle(color: sel ? Colors.white : Colors.grey.shade700),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange.shade700),
              child: Text(existing == null ? 'Add' : 'Save', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameCtrl.dispose();
      phoneCtrl.dispose();
    });
    if (result != true || nameCtrl.text.trim().isEmpty) return;

    final entry = {
      'name': nameCtrl.text.trim(),
      'phone': phoneCtrl.text.trim(),
      'days': days.toList(),
    };
    final updated = List<Map<String, dynamic>>.from(current);
    if (index != null) {
      updated[index] = entry;
    } else {
      updated.add(entry);
    }
    await _writePriests(updated);
  }

  Future<void> _addOrEditFestival({DocumentSnapshot? existing}) async {
    final d = existing?.data() as Map<String, dynamic>?;
    final nameCtrl = TextEditingController(text: d?['name'] as String? ?? '');
    final descCtrl = TextEditingController(text: d?['description'] as String? ?? '');
    DateTime date = d != null
        ? DateTime.tryParse(d['date'] as String? ?? '') ?? DateTime.now()
        : DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(existing == null ? 'Add Festival' : 'Edit Festival'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text('${date.day}/${date.month}/${date.year}'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setSt(() => date = picked);
                  },
                ),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description (Optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange.shade700),
              child: Text(existing == null ? 'Add' : 'Save', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameCtrl.dispose();
      descCtrl.dispose();
    });
    if (result != true || nameCtrl.text.trim().isEmpty) return;

    final payload = {
      'name': nameCtrl.text.trim(),
      'date': date.toIso8601String(),
      'description': descCtrl.text.trim(),
    };
    if (existing != null) {
      await existing.reference.update(payload);
    } else {
      payload['createdAt'] = DateTime.now().toIso8601String();
      await _festivalsCol.add(payload);
    }
  }

  Future<void> _addChecklistTask(List<String> current) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Ritual Task'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'e.g. Light the lamps')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange.shade700),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (result == null || result.isEmpty || current.contains(result)) return;
    await _writeChecklist([...current, result]);
  }

  Future<void> _toggleChecklistTask(String task, bool done, List<String> completed) async {
    final updated = List<String>.from(completed);
    done ? updated.add(task) : updated.remove(task);
    await _todayLogRef.set({'completed': updated}, SetOptions(merge: true));
  }

  String _formatTime(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayHour = h % 12 == 0 ? 12 : h % 12;
    return '$displayHour:${m.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _routineRef.snapshots(),
      builder: (context, routineSnap) {
        final routineData = routineSnap.data?.data() as Map<String, dynamic>? ?? {};
        final rawSchedule = routineData['dailySchedule'] as List?;
        final schedule = rawSchedule != null
            ? List<Map<String, dynamic>>.from(rawSchedule.map((e) => Map<String, dynamic>.from(e as Map)))
            : <Map<String, dynamic>>[];
        final rawPriests = routineData['priests'] as List?;
        final priests = rawPriests != null
            ? List<Map<String, dynamic>>.from(rawPriests.map((e) => Map<String, dynamic>.from(e as Map)))
            : <Map<String, dynamic>>[];
        final rawChecklist = routineData['ritualChecklist'] as List?;
        final checklist = rawChecklist != null ? List<String>.from(rawChecklist) : <String>[];

        return StreamBuilder<DocumentSnapshot>(
          stream: _todayLogRef.snapshots(),
          builder: (context, logSnap) {
            final logData = logSnap.data?.data() as Map<String, dynamic>? ?? {};
            final completed = List<String>.from(logData['completed'] as List? ?? []);

            return StreamBuilder<QuerySnapshot>(
              stream: _festivalsCol.snapshots(),
              builder: (context, festSnap) {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final upcomingFestivals = (festSnap.data?.docs ?? []).where((doc) {
                  final date = DateTime.tryParse((doc.data() as Map<String, dynamic>)['date'] as String? ?? '');
                  return date != null && !date.isBefore(today);
                }).toList()
                  ..sort((a, b) {
                    final ad = (a.data() as Map<String, dynamic>)['date'] as String;
                    final bd = (b.data() as Map<String, dynamic>)['date'] as String;
                    return ad.compareTo(bd);
                  });

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── Daily Schedule ──────────────────────────────
                    _sectionHeader('Daily Pooja Schedule', Icons.schedule_outlined,
                        onAdd: widget.isAdmin ? () => _addOrEditScheduleItem(schedule) : null),
                    if (schedule.isEmpty)
                      _emptyHint('No daily schedule configured yet')
                    else
                      ...schedule.asMap().entries.map((e) => _scheduleCard(e.value, schedule, e.key)),
                    const SizedBox(height: 24),

                    // ── Ritual Checklist ────────────────────────────
                    _sectionHeader('Today\'s Ritual Checklist', Icons.checklist_outlined,
                        onAdd: widget.isAdmin ? () => _addChecklistTask(checklist) : null),
                    if (checklist.isEmpty)
                      _emptyHint('No ritual checklist configured yet')
                    else
                      ...checklist.map((task) {
                        final done = completed.contains(task);
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: done,
                          onChanged: (v) => _toggleChecklistTask(task, v ?? false, completed),
                          title: Text(task,
                              style: TextStyle(
                                  fontSize: 13,
                                  decoration: done ? TextDecoration.lineThrough : null,
                                  color: done
                                      ? Colors.grey.shade400
                                      : Theme.of(context).textTheme.bodyLarge?.color)),
                          activeColor: Colors.deepOrange.shade600,
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        );
                      }),
                    const SizedBox(height: 24),

                    // ── Priest Assignments ──────────────────────────
                    _sectionHeader('Priest Assignments', Icons.person_outline,
                        onAdd: widget.isAdmin ? () => _addOrEditPriest(priests) : null),
                    if (priests.isEmpty)
                      _emptyHint('No priests assigned yet')
                    else
                      ...priests.asMap().entries.map((e) => _priestCard(e.value, priests, e.key)),
                    const SizedBox(height: 24),

                    // ── Festival Calendar ───────────────────────────
                    _sectionHeader('Upcoming Festivals', Icons.celebration_outlined,
                        onAdd: widget.isAdmin ? () => _addOrEditFestival() : null),
                    if (upcomingFestivals.isEmpty)
                      _emptyHint('No upcoming festivals scheduled')
                    else
                      ...upcomingFestivals.map((doc) => _festivalCard(doc)),
                    const SizedBox(height: 16),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _sectionHeader(String title, IconData icon, {VoidCallback? onAdd}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(icon, size: 18, color: Colors.deepOrange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.grey.shade800)),
          ),
          if (onAdd != null)
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: Colors.deepOrange.shade700, size: 20),
              onPressed: onAdd,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ]),
      );

  Widget _emptyHint(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
      );

  Widget _scheduleCard(Map<String, dynamic> item, List<Map<String, dynamic>> all, int index) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(children: [
          SizedBox(
            width: 76,
            child: Text(_formatTime(item['time'] as String? ?? '00:00'),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepOrange.shade700)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['title'] as String? ?? '',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodyLarge?.color)),
                if ((item['description'] as String? ?? '').isNotEmpty)
                  Text(item['description'] as String, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          if (widget.isAdmin) ...[
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 16, color: Colors.grey.shade500),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _addOrEditScheduleItem(all, existing: item, index: index),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade300),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                final updated = List<Map<String, dynamic>>.from(all)..removeAt(index);
                _writeSchedule(updated);
              },
            ),
          ],
        ]),
      );

  Widget _priestCard(Map<String, dynamic> priest, List<Map<String, dynamic>> all, int index) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.deepOrange.shade50,
            child: Icon(Icons.person, color: Colors.deepOrange.shade700, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(priest['name'] as String? ?? '',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodyLarge?.color)),
                Text(((priest['days'] as List?) ?? []).join(', '),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          if (widget.isAdmin) ...[
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 16, color: Colors.grey.shade500),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _addOrEditPriest(all, existing: priest, index: index),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade300),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                final updated = List<Map<String, dynamic>>.from(all)..removeAt(index);
                _writePriests(updated);
              },
            ),
          ],
        ]),
      );

  Widget _festivalCard(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final date = DateTime.tryParse(d['date'] as String? ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepOrange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.deepOrange.shade100),
      ),
      child: Row(children: [
        Column(children: [
          Text('${date?.day ?? ''}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange.shade800)),
          Text(date != null ? _monthShort(date.month) : '', style: TextStyle(fontSize: 10, color: Colors.deepOrange.shade600)),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              if ((d['description'] as String? ?? '').isNotEmpty)
                Text(d['description'] as String, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ),
        if (widget.isAdmin) ...[
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _addOrEditFestival(existing: doc),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade400),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => doc.reference.delete(),
          ),
        ],
      ]),
    );
  }

  String _monthShort(int m) =>
      const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];
}
