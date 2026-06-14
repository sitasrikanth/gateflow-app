import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SendNotificationScreen extends StatefulWidget {
  final String eventId;
  final String eventName;
  const SendNotificationScreen(
      {super.key, required this.eventId, required this.eventName});

  @override
  State<SendNotificationScreen> createState() =>
      _SendNotificationScreenState();
}

class _SendNotificationScreenState
    extends State<SendNotificationScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _type = 'Announcement';
  bool _sending = false;

  final List<Map<String, dynamic>> _types = [
    {'name': 'Announcement', 'icon': '📢', 'color': Colors.blue},
    {'name': 'Pooja Alert', 'icon': '🙏', 'color': Colors.deepPurple},
    {'name': 'Prasad', 'icon': '🍱', 'color': Colors.orange},
    {'name': 'Reminder', 'icon': '⏰', 'color': Colors.green},
  ];

  final List<String> _quickMessages = [
    'Ganesh Chaturthi pooja starting at 6:00 PM today. All residents are welcome!',
    'Prasad distribution at the community hall now. Please collect!',
    'Evening aarti at 7:30 PM. Kindly join.',
    'Ganpati visarjan procession starts at 10:00 AM tomorrow.',
    'Thank you for your generous contributions! Event total collected: ',
  ];

  Future<void> _sendNotification() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }

    setState(() => _sending = true);

    await FirebaseFirestore.instance.collection('notifications').add({
      'eventId': widget.eventId,
      'eventName': widget.eventName,
      'title': _titleController.text.trim(),
      'message': _messageController.text.trim(),
      'type': _type,
      'sentAt': DateTime.now().toIso8601String(),
      'targetAudience': 'all_residents',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification sent to all residents ✅'),
          backgroundColor: Colors.deepPurple,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Send Notification',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event context
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.celebration,
                      color: Colors.deepPurple, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.eventName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Notification type
            const Text('Notification Type',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _types.map((t) {
                final selected = _type == t['name'];
                return GestureDetector(
                  onTap: () =>
                      setState(() => _type = t['name'] as String),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? (t['color'] as Color).withOpacity(0.15)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? (t['color'] as Color)
                            : Colors.grey.shade200,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      '${t['icon']} ${t['name']}',
                      style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: selected
                            ? (t['color'] as Color)
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Title
            const Text('Title *',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'e.g. Pooja Alert 🙏',
                prefixIcon: const Icon(Icons.title),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Colors.deepPurple, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Quick message templates
            const Text('Quick Templates',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _quickMessages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) => ActionChip(
                  label: Text(
                    _quickMessages[i].length > 30
                        ? '${_quickMessages[i].substring(0, 30)}...'
                        : _quickMessages[i],
                    style: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () => _messageController.text =
                      _quickMessages[i],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Message
            const Text('Message *',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText:
                    'Type your message to all residents...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Colors.deepPurple, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _sendNotification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(
                    _sending ? 'Sending...' : 'Send to All Residents'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
