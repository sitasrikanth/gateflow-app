import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';

const kTaskStatusPending = 'pending';
const kTaskStatusInProgress = 'in_progress';
const kTaskStatusDone = 'done';

String taskStatusLabel(String status) {
  switch (status) {
    case kTaskStatusInProgress:
      return 'In Progress';
    case kTaskStatusDone:
      return 'Done';
    default:
      return 'Pending';
  }
}

Color taskStatusColor(String status) {
  switch (status) {
    case kTaskStatusInProgress:
      return Colors.orange.shade700;
    case kTaskStatusDone:
      return Colors.green.shade700;
    default:
      return Colors.blueGrey.shade400;
  }
}

// ── Create / Edit Task Screen (admin only) ────────────────────────────────────

class TaskFormScreen extends StatefulWidget {
  final String eventId;
  final String? existingTaskId;
  final Map<String, dynamic>? existingData;
  const TaskFormScreen({
    super.key,
    required this.eventId,
    this.existingTaskId,
    this.existingData,
  });

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _checklistItemController = TextEditingController();

  DateTime? _dueDate;
  final List<Map<String, String>> _assignees = []; // {volunteerId, name, flat, role}
  final List<Map<String, dynamic>> _checklist = []; // {text, done}
  final List<String> _dependsOn = [];
  final Map<String, String> _dependsOnTitles = {};
  bool _saving = false;
  bool _deleting = false;
  String _error = '';

  bool get _isEdit => widget.existingTaskId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit && widget.existingData != null) {
      final d = widget.existingData!;
      _titleController.text = d['title'] ?? '';
      _descController.text = d['description'] ?? '';
      final due = d['dueDate'];
      if (due is Timestamp) _dueDate = due.toDate();
      _assignees.addAll(List<Map<String, dynamic>>.from(d['assignees'] as List? ?? [])
          .map((e) => e.map((k, v) => MapEntry(k, v.toString()))));
      _checklist.addAll(List<Map<String, dynamic>>.from(
          (d['checklist'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map))));
      _dependsOn.addAll(List<String>.from(d['dependsOn'] as List? ?? []));
      if (_dependsOn.isNotEmpty) _loadDependencyTitles();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _checklistItemController.dispose();
    super.dispose();
  }

  Future<void> _loadDependencyTitles() async {
    final snap = await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('tasks')
        .get();
    if (!mounted) return;
    setState(() {
      for (final doc in snap.docs) {
        if (_dependsOn.contains(doc.id)) {
          _dependsOnTitles[doc.id] = doc.data()['title'] as String? ?? '(untitled)';
        }
      }
    });
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _addChecklistItem() {
    final text = _checklistItemController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _checklist.add({'text': text, 'done': false});
      _checklistItemController.clear();
    });
  }

  Future<void> _pickAssignees() async {
    final snap = await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('volunteers')
        .where('status', isEqualTo: 'approved')
        .get();
    if (!mounted) return;
    final volunteers = snap.docs
        .map((d) => {'id': d.id, ...d.data()})
        .toList();
    if (volunteers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No approved volunteers yet for this event')));
      return;
    }
    final selectedIds = _assignees.map((a) => a['volunteerId']).toSet();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (ctx, scrollCtrl) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Assign Volunteers',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    itemCount: volunteers.length,
                    itemBuilder: (ctx, i) {
                      final v = volunteers[i];
                      final id = v['id'] as String;
                      final name = v['name'] as String? ?? '';
                      final role = v['role'] as String? ?? '';
                      final flat = v['flat'] as String? ?? '';
                      final checked = selectedIds.contains(id);
                      return CheckboxListTile(
                        value: checked,
                        title: Text(name),
                        subtitle: Text([role, if (flat.isNotEmpty) flat].join(' · ')),
                        onChanged: (val) {
                          setSt(() {
                            if (val == true) {
                              selectedIds.add(id);
                            } else {
                              selectedIds.remove(id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _assignees
                          ..clear()
                          ..addAll(volunteers.where((v) => selectedIds.contains(v['id'])).map((v) => {
                                'volunteerId': v['id'] as String,
                                'name': v['name'] as String? ?? '',
                                'flat': v['flat'] as String? ?? '',
                                'role': v['role'] as String? ?? '',
                              }));
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                    child: const Text('Done', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDependencies() async {
    final query = await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('tasks')
        .get();
    if (!mounted) return;
    final others = query.docs.where((d) => d.id != widget.existingTaskId).toList();
    if (others.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No other tasks to depend on yet')));
      return;
    }
    final selected = Set<String>.from(_dependsOn);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (ctx, scrollCtrl) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Depends On',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('This task will be blocked until the selected tasks are done.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    itemCount: others.length,
                    itemBuilder: (ctx, i) {
                      final t = others[i].data();
                      final id = others[i].id;
                      final title = t['title'] as String? ?? '(untitled)';
                      final status = t['status'] as String? ?? kTaskStatusPending;
                      return CheckboxListTile(
                        value: selected.contains(id),
                        title: Text(title),
                        subtitle: Text(taskStatusLabel(status),
                            style: TextStyle(color: taskStatusColor(status), fontSize: 12)),
                        onChanged: (val) {
                          setSt(() {
                            if (val == true) {
                              selected.add(id);
                            } else {
                              selected.remove(id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _dependsOn
                          ..clear()
                          ..addAll(selected);
                        _dependsOnTitles.clear();
                        for (final doc in others) {
                          if (selected.contains(doc.id)) {
                            _dependsOnTitles[doc.id] = doc.data()['title'] as String? ?? '(untitled)';
                          }
                        }
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                    child: const Text('Done', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Please enter a task title');
      return;
    }
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      final firestore = FirebaseFirestore.instance;
      final taskRef = _isEdit
          ? firestore.collection('events').doc(widget.eventId).collection('tasks').doc(widget.existingTaskId)
          : firestore.collection('events').doc(widget.eventId).collection('tasks').doc();

      final payload = <String, dynamic>{
        'title': title,
        'description': _descController.text.trim(),
        'dueDate': _dueDate != null ? Timestamp.fromDate(_dueDate!) : null,
        'assignees': _assignees,
        'assigneeFlats': _assignees.map((a) => a['flat'] ?? '').where((f) => f.isNotEmpty).toList(),
        'checklist': _checklist,
        'dependsOn': _dependsOn,
        'updatedAt': Timestamp.now(),
      };

      if (_isEdit) {
        await taskRef.update(payload);
      } else {
        payload['status'] = kTaskStatusPending;
        payload['createdAt'] = Timestamp.now();
        payload['createdBy'] = 'admin';
        payload['photos'] = <String>[];
        await taskRef.set(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEdit ? 'Task updated' : 'Task created'),
            backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() {
        _saving = false;
        _error = 'Save failed: $e';
      });
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "${_titleController.text.trim()}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('tasks')
          .doc(widget.existingTaskId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task deleted'), backgroundColor: Colors.red));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() {
        _deleting = false;
        _error = 'Delete failed: $e';
      });
    }
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Task' : 'Create Task'),
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        actions: [
          if (_isEdit)
            IconButton(
              icon: _deleting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.delete_outline),
              onPressed: _deleting ? null : _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel('Title *'),
          TextField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'e.g. Set up stage decoration',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 16),
          _sectionLabel('Description'),
          TextField(
            controller: _descController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Details about what needs to be done…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 16),
          _sectionLabel('Due Date'),
          InkWell(
            onTap: _pickDueDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 10),
                Text(
                  _dueDate == null
                      ? 'Select a due date'
                      : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                  style: TextStyle(color: _dueDate == null ? Colors.grey.shade600 : Colors.black87),
                ),
                const Spacer(),
                if (_dueDate != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _dueDate = null),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          _sectionLabel('Assign Owners'),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: [
              ..._assignees.map((a) => Chip(
                    label: Text(a['name'] ?? ''),
                    avatar: const Icon(Icons.person, size: 16),
                    onDeleted: () => setState(() => _assignees.remove(a)),
                  )),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('Add Volunteer'),
                onPressed: _pickAssignees,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sectionLabel('Checklist'),
          ..._checklist.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  const Icon(Icons.check_box_outline_blank, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.value['text'] as String)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _checklist.removeAt(e.key)),
                  ),
                ]),
              )),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _checklistItemController,
                decoration: InputDecoration(
                  hintText: 'Add checklist item…',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
                onSubmitted: (_) => _addChecklistItem(),
              ),
            ),
            IconButton(
                icon: Icon(Icons.add_circle, color: AppTheme.accent), onPressed: _addChecklistItem),
          ]),
          const SizedBox(height: 16),
          _sectionLabel('Dependencies'),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: [
              ..._dependsOn.map((id) => Chip(
                    label: Text(_dependsOnTitles[id] ?? 'Task', style: const TextStyle(fontSize: 11)),
                    avatar: const Icon(Icons.link, size: 14),
                    onDeleted: () => setState(() {
                      _dependsOn.remove(id);
                      _dependsOnTitles.remove(id);
                    }),
                  )),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('Add Dependency'),
                onPressed: _pickDependencies,
              ),
            ],
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_error, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_isEdit ? 'Save Changes' : 'Create Task',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
