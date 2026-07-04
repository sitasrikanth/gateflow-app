import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'task_form_screen.dart';

Future<void> showTaskDetailSheet(
  BuildContext context, {
  required String eventId,
  required String taskId,
  required bool isAdmin,
  String viewerFlat = '',
  String viewerName = '',
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => _TaskDetailSheet(
      eventId: eventId,
      taskId: taskId,
      isAdmin: isAdmin,
      viewerFlat: viewerFlat,
      viewerName: viewerName,
    ),
  );
}

class _TaskDetailSheet extends StatefulWidget {
  final String eventId;
  final String taskId;
  final bool isAdmin;
  final String viewerFlat;
  final String viewerName;
  const _TaskDetailSheet({
    required this.eventId,
    required this.taskId,
    required this.isAdmin,
    required this.viewerFlat,
    required this.viewerName,
  });

  @override
  State<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<_TaskDetailSheet> {
  final _commentController = TextEditingController();
  bool _uploadingPhoto = false;

  DocumentReference get _taskRef => FirebaseFirestore.instance
      .collection('events')
      .doc(widget.eventId)
      .collection('tasks')
      .doc(widget.taskId);

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _toggleChecklistItem(List<dynamic> checklist, int index) async {
    final updated = checklist.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    updated[index]['done'] = !(updated[index]['done'] == true);
    await _taskRef.update({'checklist': updated});
  }

  Future<void> _setStatus(String status) async {
    await _taskRef.update({'status': status, 'updatedAt': Timestamp.now()});
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    _commentController.clear();
    await _taskRef.collection('comments').add({
      'text': text,
      'authorName': widget.viewerName.isNotEmpty ? widget.viewerName : (widget.isAdmin ? 'Admin' : 'Resident'),
      'authorFlat': widget.viewerFlat,
      'isAdmin': widget.isAdmin,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> _attachPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1600);
    final fallback = picked ?? await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
    if (fallback == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final ref = FirebaseStorage.instance.ref(
          'tasks/${widget.eventId}/${widget.taskId}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(File(fallback.path));
      final url = await ref.getDownloadURL();
      await _taskRef.update({'photos': FieldValue.arrayUnion([url])});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _removePhoto(String url) async {
    await _taskRef.update({'photos': FieldValue.arrayRemove([url])});
    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (ctx, scrollCtrl) => StreamBuilder<DocumentSnapshot>(
        stream: _taskRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Task not found')));
          }
          final d = snap.data!.data() as Map<String, dynamic>;
          final title = d['title'] as String? ?? '';
          final description = d['description'] as String? ?? '';
          final status = d['status'] as String? ?? kTaskStatusPending;
          final due = d['dueDate'];
          final dueDate = due is Timestamp ? due.toDate() : null;
          final overdue = dueDate != null && status != kTaskStatusDone && dueDate.isBefore(DateTime.now());
          final assignees = List<Map<String, dynamic>>.from(d['assignees'] as List? ?? []);
          final checklist = List<dynamic>.from(d['checklist'] as List? ?? []);
          final checklistDone = checklist.where((c) => (c as Map)['done'] == true).length;
          final dependsOn = List<String>.from(d['dependsOn'] as List? ?? []);
          final photos = List<String>.from(d['photos'] as List? ?? []);

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(20),
              children: [
                Row(children: [
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  if (widget.isAdmin) ...[
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () async {
                        Navigator.pop(context);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TaskFormScreen(
                                eventId: widget.eventId, existingTaskId: widget.taskId, existingData: d),
                          ),
                        );
                      },
                    ),
                  ],
                ]),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(description, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                ],
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _statusChip(status),
                  if (dueDate != null)
                    Chip(
                      avatar: Icon(Icons.calendar_today_outlined,
                          size: 14, color: overdue ? Colors.red : Colors.grey.shade700),
                      label: Text('${dueDate.day}/${dueDate.month}/${dueDate.year}',
                          style: TextStyle(fontSize: 12, color: overdue ? Colors.red : Colors.black87)),
                      backgroundColor: overdue ? Colors.red.shade50 : Colors.grey.shade100,
                    ),
                  if (checklist.isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.checklist, size: 14),
                      label: Text('$checklistDone/${checklist.length} done', style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.grey.shade100,
                    ),
                ]),
                const SizedBox(height: 16),
                const Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  _statusButton(kTaskStatusPending, status),
                  _statusButton(kTaskStatusInProgress, status),
                  _statusButton(kTaskStatusDone, status),
                ]),
                if (assignees.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Assigned To', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: assignees.map((a) => Chip(
                        avatar: const Icon(Icons.person, size: 14),
                        label: Text('${a['name']}${(a['flat'] ?? '').toString().isNotEmpty ? ' · ${a['flat']}' : ''}',
                            style: const TextStyle(fontSize: 12)),
                      )).toList()),
                ],
                if (checklist.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Checklist', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...checklist.asMap().entries.map((e) {
                    final item = e.value as Map;
                    final done = item['done'] == true;
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: done,
                      onChanged: (_) => _toggleChecklistItem(checklist, e.key),
                      title: Text(item['text'] as String? ?? '',
                          style: TextStyle(
                              decoration: done ? TextDecoration.lineThrough : null,
                              color: done ? Colors.grey : Colors.black87)),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  }),
                ],
                if (dependsOn.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Dependencies', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...dependsOn.map((depId) => _DependencyRow(eventId: widget.eventId, taskId: depId)),
                ],
                const SizedBox(height: 16),
                Row(children: [
                  const Expanded(
                    child: Text('Photos', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  TextButton.icon(
                    onPressed: _uploadingPhoto ? null : _attachPhoto,
                    icon: _uploadingPhoto
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_a_photo_outlined, size: 16),
                    label: const Text('Add'),
                  ),
                ]),
                if (photos.isNotEmpty)
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, i) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(photos[i], width: 90, height: 90, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 2, right: 2,
                            child: GestureDetector(
                              onTap: () => _removePhoto(photos[i]),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text('Comments', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: _taskRef.collection('comments').orderBy('createdAt').snapshots(),
                  builder: (context, cSnap) {
                    final docs = cSnap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Text('No comments yet', style: TextStyle(color: Colors.grey.shade500, fontSize: 12));
                    }
                    return Column(
                      children: docs.map((doc) {
                        final c = doc.data() as Map<String, dynamic>;
                        final isAdminComment = c['isAdmin'] == true;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: isAdminComment ? Colors.deepPurple.shade100 : Colors.teal.shade100,
                                child: Icon(isAdminComment ? Icons.shield_outlined : Icons.person,
                                    size: 14, color: isAdminComment ? Colors.deepPurple : Colors.teal.shade700),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c['authorName'] as String? ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                    Text(c['text'] as String? ?? '', style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Add a comment…',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onSubmitted: (_) => _postComment(),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.send, color: Colors.deepPurple), onPressed: _postComment),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statusChip(String status) => Chip(
        label: Text(taskStatusLabel(status),
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        backgroundColor: taskStatusColor(status),
      );

  Widget _statusButton(String value, String current) {
    final selected = value == current;
    return ChoiceChip(
      label: Text(taskStatusLabel(value)),
      selected: selected,
      selectedColor: taskStatusColor(value).withValues(alpha: 0.2),
      onSelected: (_) => _setStatus(value),
    );
  }
}

class _DependencyRow extends StatelessWidget {
  final String eventId;
  final String taskId;
  const _DependencyRow({required this.eventId, required this.taskId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('tasks')
          .doc(taskId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox();
        final d = snap.data!.data() as Map<String, dynamic>;
        final title = d['title'] as String? ?? '(untitled)';
        final status = d['status'] as String? ?? kTaskStatusPending;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Icon(Icons.link, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 13))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: taskStatusColor(status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(taskStatusLabel(status),
                  style: TextStyle(fontSize: 11, color: taskStatusColor(status), fontWeight: FontWeight.w600)),
            ),
          ]),
        );
      },
    );
  }
}
