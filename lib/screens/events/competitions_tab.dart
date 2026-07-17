import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import 'event_type_settings_screen.dart' show residentTabSectionsFor;

const List<String> kPresetCompetitions = [
  'Singing', 'Dancing', 'Rangoli', 'Cricket', 'Chess', 'Fancy Dress',
];

const Map<String, String> _kPlaceLabels = {
  'first': '🥇 1st Place',
  'second': '🥈 2nd Place',
  'third': '🥉 3rd Place',
};

class CompetitionsTab extends StatelessWidget {
  final String eventId;
  final bool isAdmin;
  final String eventTypeId;
  const CompetitionsTab({
    super.key,
    required this.eventId,
    required this.isAdmin,
    this.eventTypeId = '',
  });

  CollectionReference get _col => FirebaseFirestore.instance
      .collection('events').doc(eventId).collection('competitions');

  Future<void> _addCompetition(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          String? selectedPreset;
          return Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Competition',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kPresetCompetitions.map((p) => ChoiceChip(
                        label: Text(p),
                        selected: selectedPreset == p,
                        onSelected: (sel) => setSheetState(() {
                          selectedPreset = sel ? p : null;
                          if (sel) nameCtrl.text = p;
                        }),
                      )).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Competition name',
                    hintText: 'Or type a custom name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
                    child: const Text('Add', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (name != null && name.isNotEmpty) {
      await _col.add({
        'name': name,
        'createdAt': DateTime.now().toIso8601String(),
        'winners': {},
      });
    }
  }

  Future<void> _setWinners(BuildContext context, DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final winners = Map<String, dynamic>.from(data['winners'] as Map? ?? {});
    final places = ['first', 'second', 'third'];
    final nameCtrls = <String, TextEditingController>{
      for (final p in places)
        p: TextEditingController(
            text: ((winners[p] as Map?)?['name'] ?? '') as String),
    };
    final flatCtrls = <String, TextEditingController>{
      for (final p in places)
        p: TextEditingController(
            text: ((winners[p] as Map?)?['flat'] ?? '') as String),
    };

    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Winners — ${data['name']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              for (final place in places) ...[
                Text(_kPlaceLabels[place]!,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: nameCtrls[place],
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                          hintText: 'Name', isDense: true, border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: flatCtrls[place],
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                          hintText: 'Flat', isDense: true, border: OutlineInputBorder()),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save Winners', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (save == true) {
      final newWinners = <String, dynamic>{};
      for (final place in places) {
        final name = nameCtrls[place]!.text.trim();
        final flat = flatCtrls[place]!.text.trim();
        if (name.isNotEmpty) newWinners[place] = {'name': name, 'flat': flat};
      }
      await doc.reference.update({'winners': newWinners});
    }
  }

  Future<void> _delete(BuildContext context, DocumentReference ref, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Competition'),
        content: Text('Remove "$name" and its winners?'),
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
                onPressed: () => _addCompetition(context),
                backgroundColor: AppTheme.accent,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Add Competition',
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
          final enabledSections = residentTabSectionsFor(configData, 'competitions');
          if (!isAdmin && !enabledSections.contains('competitions_list')) {
            return const SizedBox.shrink();
          }

          return StreamBuilder<QuerySnapshot>(
        stream: _col.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events_outlined, size: 56, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                        isAdmin
                            ? 'No competitions yet — tap + to add one'
                            : 'No competitions announced yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] as String? ?? '';
              final winners = Map<String, dynamic>.from(data['winners'] as Map? ?? {});
              final hasWinners = winners.isNotEmpty;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
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
                      Icon(Icons.emoji_events, color: Colors.amber.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15))),
                      if (isAdmin)
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: Colors.grey.shade500, size: 18),
                          onSelected: (v) {
                            if (v == 'winners') _setWinners(context, doc);
                            if (v == 'delete') _delete(context, doc.reference, name);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'winners', child: Text('Set Winners')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                    ]),
                    const SizedBox(height: 8),
                    if (!hasWinners)
                      Text(
                          isAdmin
                              ? 'Winners not set yet — tap ⋮ to add'
                              : 'Winners will be announced soon',
                          style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              fontStyle: FontStyle.italic))
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final place in ['first', 'second', 'third'])
                            if (winners[place] != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Builder(builder: (_) {
                                  final w = Map<String, dynamic>.from(winners[place] as Map);
                                  final flat = (w['flat'] ?? '').toString();
                                  return Text(
                                    '${_kPlaceLabels[place]!.split(' ').first} ${w['name']}'
                                    '${flat.isNotEmpty ? ' ($flat)' : ''}',
                                    style: const TextStyle(fontSize: 13),
                                  );
                                }),
                              ),
                        ],
                      ),
                  ],
                ),
              );
            },
          );
        },
      );
        },
      ),
    );
  }
}
