import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateEventScreen extends StatefulWidget {
  /// Pass these to open in edit mode
  final String? existingEventId;
  final Map<String, dynamic>? existingData;

  const CreateEventScreen({
    super.key,
    this.existingEventId,
    this.existingData,
  });

  bool get isEdit => existingEventId != null;

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _targetController = TextEditingController();
  String _startDate = '';
  String _endDate = '';
  bool _saving = false;
  bool _loading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      _prefill(widget.existingData ?? {});
      // Also fetch fresh from Firestore in case passed data was stale/empty
      if ((widget.existingData ?? {})['name'] == null ||
          (widget.existingData!['name'] as String).isEmpty) {
        _fetchAndPrefill();
      }
    }
  }

  void _prefill(Map<String, dynamic> d) {
    _nameController.text = (d['name'] as String?) ?? '';
    _descController.text = (d['description'] as String?) ?? '';
    final target = (d['targetAmount'] as num?)?.toDouble() ?? 0;
    _targetController.text = target > 0 ? target.toStringAsFixed(0) : '';
    _startDate = (d['startDate'] as String?) ?? '';
    _endDate = (d['endDate'] as String?) ?? '';
  }

  Future<void> _fetchAndPrefill() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.existingEventId)
          .get();
      if (snap.exists && mounted) {
        setState(() {
          _prefill(snap.data()!);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      final formatted =
          '${picked.day}/${picked.month}/${picked.year}';
      setState(() {
        if (isStart) {
          _startDate = formatted;
        } else {
          _endDate = formatted;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter event name');
      return;
    }
    setState(() {
      _saving = true;
      _error = '';
    });

    final target = double.tryParse(_targetController.text) ?? 0;

    try {
      final firestore = FirebaseFirestore.instance;

      if (widget.isEdit) {
        await firestore.collection('events').doc(widget.existingEventId).update({
          'name': _nameController.text.trim(),
          'description': _descController.text.trim(),
          'targetAmount': target,
          'startDate': _startDate,
          'endDate': _endDate,
        });
      } else {
        await firestore.collection('events').add({
          'name': _nameController.text.trim(),
          'description': _descController.text.trim(),
          'targetAmount': target,
          'totalCollected': 0,
          'totalSpent': 0,
          'startDate': _startDate,
          'endDate': _endDate,
          'status': 'active',
          'createdAt': DateTime.now().toIso8601String(),
          'createdBy': FirebaseAuth.instance.currentUser?.uid ?? '',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(widget.isEdit
                  ? 'Event updated! ✅'
                  : 'Event created! ✅'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '${widget.isEdit ? 'Update' : 'Create'} failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Event' : 'Create Event',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event name
            const Text('Event Name *',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDec(
                  'e.g. Ganesh Chaturthi 2026', Icons.celebration_outlined),
            ),
            const SizedBox(height: 20),

            // Description
            const Text('Description',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: _inputDec(
                  'What is this event about?', Icons.description_outlined),
            ),
            const SizedBox(height: 20),

            // Target amount
            const Text('Collection Target (₹)',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Optional — set a goal amount for the event',
                style:
                    TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _targetController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration:
                  _inputDec('e.g. 50000', Icons.track_changes_outlined),
            ),
            const SizedBox(height: 20),

            // Date range
            const Text('Event Dates',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDate(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16, color: Colors.grey.shade500),
                          const SizedBox(width: 8),
                          Text(
                            _startDate.isEmpty ? 'Start Date' : _startDate,
                            style: TextStyle(
                                color: _startDate.isEmpty
                                    ? Colors.grey.shade400
                                    : Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDate(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16, color: Colors.grey.shade500),
                          const SizedBox(width: 8),
                          Text(
                            _endDate.isEmpty ? 'End Date' : _endDate,
                            style: TextStyle(
                                color: _endDate.isEmpty
                                    ? Colors.grey.shade400
                                    : Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_error.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(_error,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check),
                label: Text(_saving
                    ? (widget.isEdit ? 'Saving...' : 'Creating...')
                    : (widget.isEdit ? 'Save Changes' : 'Create Event')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
      ),
    );
  }
}
