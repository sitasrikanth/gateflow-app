import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/country_codes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  DocumentReference get _ref =>
      FirebaseFirestore.instance.collection('community_settings').doc('address');

  // â"€â"€ Wings â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€

  Future<void> _addWing(List<String> current) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Wing'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
              labelText: 'Wing name', hintText: 'e.g. Diamond, Rubyâ€¦'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade600),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (name == null || name.isEmpty) return;
    if (current.any((w) => w.toLowerCase() == name.toLowerCase())) {
      _snack('"$name" already exists', Colors.orange);
      return;
    }
    try {
      await _ref.set({'wings': [...current, name]}, SetOptions(merge: true));
    } catch (e) {
      _snack('Failed: $e', Colors.red);
    }
  }

  Future<void> _deleteWing(
      List<String> wings, Map<String, dynamic> wingBlocks, String wing) async {
    final ok = await _confirmDialog('Delete "$wing" Wing?',
        'Removes the wing and its blocks. Existing records are not affected.');
    if (ok == true) {
      final updatedWings = wings.where((w) => w != wing).toList();
      final updatedBlocks = Map<String, dynamic>.from(wingBlocks)..remove(wing);
      await _ref.set(
          {'wings': updatedWings, 'wingBlocks': updatedBlocks},
          SetOptions(merge: true));
    }
  }

  Future<void> _renameWing(
      List<String> wings, Map<String, dynamic> wingBlocks, String old) async {
    final name = await _inputDialog('Rename Wing', old);
    if (name == null || name.isEmpty || name == old) return;
    final updatedWings = wings.map((w) => w == old ? name : w).toList();
    final updatedBlocks = Map<String, dynamic>.from(wingBlocks);
    if (updatedBlocks.containsKey(old)) {
      updatedBlocks[name] = updatedBlocks.remove(old);
    }
    await _ref.set({'wings': updatedWings, 'wingBlocks': updatedBlocks},
        SetOptions(merge: true));
  }

  // â"€â"€ Blocks â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€

  // Returns block names for a wing (handles both old List and new Map format)
  List<String> _blocksFor(Map<String, dynamic> wingBlocks, String wing) {
    final raw = wingBlocks[wing];
    if (raw is Map) return (raw.keys.cast<String>().toList())..sort();
    if (raw is List) return List<String>.from(raw)..sort();
    return [];
  }

  // Returns flats for a block within a wing
  List<String> _flatsFor(
      Map<String, dynamic> wingBlocks, String wing, String block) {
    final raw = wingBlocks[wing];
    if (raw is Map) {
      final blockData = raw[block];
      if (blockData is List) return List<String>.from(blockData)..sort();
    }
    return [];
  }

  // Returns the wing data as Map<block, List<flat>>
  Map<String, dynamic> _wingData(Map<String, dynamic> wingBlocks, String wing) {
    final raw = wingBlocks[wing];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    // Migrate old List<String> format: blocks had no flats
    if (raw is List) {
      return {for (final b in raw as List<dynamic>) b.toString(): <String>[]};
    }
    return {};
  }

  Future<void> _addBlock(
      Map<String, dynamic> wingBlocks, String wing) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Block to $wing Wing'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
              labelText: 'Block name', hintText: 'e.g. A, B, C'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade600),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (name == null || name.isEmpty) return;
    final existing = _blocksFor(wingBlocks, wing);
    if (existing.any((b) => b.toLowerCase() == name.toLowerCase())) {
      _snack('"$name" already exists in $wing', Colors.orange);
      return;
    }
    try {
      final updated = Map<String, dynamic>.from(wingBlocks);
      final wingMap = _wingData(wingBlocks, wing);
      wingMap[name.toUpperCase()] = <String>[];
      updated[wing] = wingMap;
      await _ref.set({'wingBlocks': updated}, SetOptions(merge: true));
    } catch (e) {
      _snack('Failed: $e', Colors.red);
    }
  }

  Future<void> _renameBlock(
      Map<String, dynamic> wingBlocks, String wing, String block) async {
    final newName = await _inputDialog('Rename Block', block);
    if (newName == null || newName.trim().isEmpty || newName.trim() == block) {
      return;
    }
    final trimmed = newName.trim().toUpperCase();
    final wingMap = _wingData(wingBlocks, wing);
    if (wingMap.containsKey(trimmed)) {
      _snack('Block $trimmed already exists in $wing Wing', Colors.orange);
      return;
    }
    try {
      final updated = Map<String, dynamic>.from(wingBlocks);
      final updatedWing = Map<String, dynamic>.from(wingMap);
      updatedWing[trimmed] = updatedWing.remove(block);
      updated[wing] = updatedWing;
      await _ref.update({'wingBlocks': updated});
      _snack('Block renamed to $trimmed', Colors.green);
    } catch (e) {
      _snack('Error: $e', Colors.red);
    }
  }

  Future<void> _deleteBlock(
      Map<String, dynamic> wingBlocks, String wing, String block) async {
    final ok = await _confirmDialog(
        'Remove block "$block" from $wing Wing?',
        'All flats in this block will also be removed. Existing records are not affected.');
    if (ok == true) {
      try {
        final updated = Map<String, dynamic>.from(wingBlocks);
        final wingMap = _wingData(wingBlocks, wing);
        wingMap.remove(block);
        updated[wing] = wingMap;
        await _ref.update({'wingBlocks': updated});
        _snack('Block $block deleted', Colors.green);
      } catch (e) {
        _snack('Error: $e', Colors.red);
      }
    }
  }

  Future<void> _setFlatsPerFloor(String wing, String block, int n) async {
    final key = '${wing}_$block';
    try {
      await _ref.update({'flatsPerFloor.$key': n});
    } catch (e) {
      _snack('Error: $e', Colors.red);
    }
  }

  Future<void> _setFlatGridRows(String wing, String block, int n) async {
    final key = '${wing}_$block';
    try {
      final doc = await _ref.get();
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final existing = data['flatGridRows'];
      final merged = existing is Map
          ? (Map<String, dynamic>.from(existing)..[key] = n)
          : {key: n};
      await _ref.update({'flatGridRows': merged});
    } catch (e) {
      _snack('Error: $e', Colors.red);
    }
  }

  // â"€â"€ Flats â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€

  Future<void> _addFlat(
      Map<String, dynamic> wingBlocks, String wing, String block) async {
    final fromCtrl = TextEditingController();
    final toCtrl = TextEditingController();
    final smartPrefix = (wing.isNotEmpty ? wing[0].toUpperCase() : '') +
        (block.isNotEmpty ? block[0].toUpperCase() : '');
    final prefixCtrl = TextEditingController(text: smartPrefix);
    final singleCtrl = TextEditingController(text: smartPrefix);

    List<String>? result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) {
        bool isBulk = false;
        return StatefulBuilder(
          builder: (ctx, set) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            title: Text('Add Flats â€" $wing Wing, Block $block',
                style: const TextStyle(fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Toggle
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => set(() => isBulk = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isBulk
                                ? Colors.teal.shade600
                                : Colors.grey.shade100,
                            borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(8)),
                          ),
                          child: Center(
                            child: Text('Single',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: !isBulk
                                        ? Colors.white
                                        : Colors.grey.shade600)),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => set(() => isBulk = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isBulk
                                ? Colors.teal.shade600
                                : Colors.grey.shade100,
                            borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(8)),
                          ),
                          child: Center(
                            child: Text('Bulk Range',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isBulk
                                        ? Colors.white
                                        : Colors.grey.shade600)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!isBulk) ...[
                  TextField(
                    controller: singleCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Flat number',
                      hintText: '${smartPrefix}101',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: prefixCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Prefix (optional)',
                      hintText: smartPrefix,
                      helperText: 'Added before each number',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: fromCtrl,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'From',
                            hintText: '101',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('to',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                      Expanded(
                        child: TextField(
                          controller: toCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'To',
                            hintText: '112',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'e.g. prefix "\$smartPrefix", from 101 to 112 -> \${smartPrefix}101 ... \${smartPrefix}112',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ],
            ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                onPressed: () {
                  if (!isBulk) {
                    final v = singleCtrl.text.trim().toUpperCase();
                    if (v.isNotEmpty) Navigator.pop(ctx, [v]);
                  } else {
                    final from = int.tryParse(fromCtrl.text.trim());
                    final to = int.tryParse(toCtrl.text.trim());
                    final prefix = prefixCtrl.text.trim().toUpperCase();
                    if (from != null && to != null && to >= from) {
                      final flats = List.generate(
                          to - from + 1,
                          (i) => '$prefix${from + i}');
                      Navigator.pop(ctx, flats);
                    }
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      singleCtrl.dispose();
      fromCtrl.dispose();
      toCtrl.dispose();
      prefixCtrl.dispose();
    });

    if (result == null || result.isEmpty) return;

    final currentFlats = _flatsFor(wingBlocks, wing, block);
    final toAdd = result
        .where((f) => !currentFlats.any(
            (existing) => existing.toLowerCase() == f.toLowerCase()))
        .toList();

    if (toAdd.isEmpty) {
      _snack('All flat(s) already exist in $wing-$block', Colors.orange);
      return;
    }

    final skipped = result.length - toAdd.length;

    try {
      final updated = Map<String, dynamic>.from(wingBlocks);
      final wingMap = _wingData(wingBlocks, wing);
      final rawF = wingMap[block];
      final flats = List<String>.from(rawF is List ? rawF : []);
      flats.addAll(toAdd);
      wingMap[block] = flats;
      updated[wing] = wingMap;
      await _ref.set({'wingBlocks': updated}, SetOptions(merge: true));
      _snack(
        '${toAdd.length} flat${toAdd.length == 1 ? '' : 's'} added'
        '${skipped > 0 ? ', $skipped skipped (duplicates)' : ''}',
        Colors.teal.shade700,
      );
    } catch (e) {
      _snack('Failed: $e', Colors.red);
    }
  }

  Future<void> _deleteFlats(Map<String, dynamic> wingBlocks, String wing,
      String block, List<String> toDelete) async {
    final ok = await _confirmDialog(
      'Delete ${toDelete.length} flat${toDelete.length == 1 ? '' : 's'}?',
      toDelete.length == 1
          ? 'Remove flat "${toDelete.first}" from $wing â€" Block $block?'
          : 'Remove ${toDelete.length} flats from $wing â€" Block $block? Existing records are not affected.',
    );
    if (ok != true) return;
    final updated = Map<String, dynamic>.from(wingBlocks);
    final wingMap = _wingData(wingBlocks, wing);
    final rawF = wingMap[block];
    final flats = List<String>.from(rawF is List ? rawF : [])
      ..removeWhere((f) => toDelete.contains(f));
    wingMap[block] = flats;
    updated[wing] = wingMap;
    await _ref.set({'wingBlocks': updated}, SetOptions(merge: true));
  }

  Future<void> _renameFlat(Map<String, dynamic> wingBlocks, String wing,
      String block, String flat) async {
    final name = await _inputDialog('Rename Flat', flat);
    if (name == null || name.isEmpty || name == flat) return;
    final updated = Map<String, dynamic>.from(wingBlocks);
    final wingMap = _wingData(wingBlocks, wing);
    final rawF = wingMap[block];
    final flats = List<String>.from(rawF is List ? rawF : [])
        .map((f) => f == flat ? name.toUpperCase() : f)
        .toList();
    wingMap[block] = flats;
    updated[wing] = wingMap;
    await _ref.set({'wingBlocks': updated}, SetOptions(merge: true));
  }

  // â"€â"€ Helpers â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<bool?> _confirmDialog(String title, String body) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

  Future<String?> _inputDialog(String title, String initial) async {
    final ctrl = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8)),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    return result;
  }

  // â"€â"€ Build â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Community Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _ref.snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final wings = List<String>.from(data['wings'] ?? []);
          final wingBlocks = Map<String, dynamic>.from(data['wingBlocks'] ?? {});
          final flatsPerFloor = Map<String, int>.from(
            (data['flatsPerFloor'] as Map<String, dynamic>? ?? {})
                .map((k, v) => MapEntry(k, (v as num).toInt())),
          );
          final flatGridRows = Map<String, int>.from(
            (data['flatGridRows'] is Map
                    ? data['flatGridRows'] as Map<String, dynamic>
                    : <String, dynamic>{})
                .map((k, v) => MapEntry(k, (v as num).toInt())),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _DefaultNoteCard(ref: _ref, data: data),
              const SizedBox(height: 16),
              _ResidentLandingScreenCard(ref: _ref, data: data),
              const SizedBox(height: 16),
              _CountryCodeCard(ref: _ref, data: data),
              const SizedBox(height: 16),
              _PaymentModesCard(ref: _ref, data: data),
              const SizedBox(height: 16),
              _SectionCard(
                icon: Icons.apartment,
                iconColor: Colors.blue,
                title: 'Wings & Blocks',
                subtitle: wings.isEmpty
                    ? 'No wings yet â€" tap + to add your first wing'
                    : '${wings.length} wing${wings.length == 1 ? '' : 's'} Â· Tap âŠ• on a wing to add blocks Â· Tap âŠ• on a block to add flats',
                onAdd: () => _addWing(wings),
                addTooltip: 'Add Wing',
                children: [
                  // Info tip
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline,
                            color: Colors.amber.shade700, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Define your community\'s physical layout here. '
                            'Each wing contains blocks, and each block contains flats. '
                            'Residents are assigned to a flat when their registration is approved. '
                            'Deleting a wing, block, or flat does not remove existing resident records.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (wings.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No wings added yet. Tap + to add.',
                          style: TextStyle(color: Colors.grey)),
                    )
                  else
                    for (final wing in wings)
                      _WingTile(
                        wing: wing,
                        wingData: _wingData(wingBlocks, wing),
                        onRename: () => _renameWing(wings, wingBlocks, wing),
                        onDelete: () => _deleteWing(wings, wingBlocks, wing),
                        onAddBlock: () => _addBlock(wingBlocks, wing),
                        onDeleteBlock: (b) => _deleteBlock(wingBlocks, wing, b),
                        onRenameBlock: (b) => _renameBlock(wingBlocks, wing, b),
                        onAddFlat: (b) => _addFlat(wingBlocks, wing, b),
                        onDeleteFlats: (b, flats) =>
                            _deleteFlats(wingBlocks, wing, b, flats),
                        onRenameFlat: (b, f) =>
                            _renameFlat(wingBlocks, wing, b, f),
                        flatsPerFloor: flatsPerFloor,
                        onSetFlatsPerFloor: (b, n) => _setFlatsPerFloor(wing, b, n),
                        flatGridRows: flatGridRows,
                        onSetFlatGridRows: (b, n) => _setFlatGridRows(wing, b, n),
                      ),
                ],
              ),

            ],
          );
        },
      ),
    );
  }
}

// ── Default Contribution Note Card ────────────────────────────────────────────

class _DefaultNoteCard extends StatefulWidget {
  final DocumentReference ref;
  final Map<String, dynamic> data;
  const _DefaultNoteCard({required this.ref, required this.data});

  @override
  State<_DefaultNoteCard> createState() => _DefaultNoteCardState();
}

class _DefaultNoteCardState extends State<_DefaultNoteCard> {
  late TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.data['defaultContributionNote'] as String? ?? '');
  }

  @override
  void didUpdateWidget(_DefaultNoteCard old) {
    super.didUpdateWidget(old);
    final newVal = widget.data['defaultContributionNote'] as String? ?? '';
    if (_ctrl.text != newVal && !_saving) {
      _ctrl.text = newVal;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.ref.set(
          {'defaultContributionNote': _ctrl.text.trim()},
          SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Default note saved'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CollapsibleCard(
      icon: Icons.note_outlined,
      iconColor: Colors.teal,
      title: 'Default Contribution Note',
      subtitle: 'Pre-filled in the Note field when admin adds a new contribution.',
      child: TextField(
        controller: _ctrl,
        decoration: InputDecoration(
          hintText: 'e.g. Will pay on Chaturthi day',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.teal, width: 2),
          ),
          suffixIcon: _saving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(
                  icon: const Icon(Icons.save_outlined, color: Colors.teal),
                  onPressed: _save,
                  tooltip: 'Save',
                ),
        ),
        onSubmitted: (_) => _save(),
      ),
    );
  }
}

// ── Resident Landing Screen Card ──────────────────────────────────────────────
// Controls what residents see immediately after logging in: the full Home
// dashboard (visitors, quick actions, profile) or straight into My Events.

class _ResidentLandingScreenCard extends StatelessWidget {
  final DocumentReference ref;
  final Map<String, dynamic> data;
  const _ResidentLandingScreenCard({required this.ref, required this.data});

  String get _current => (data['residentLandingScreen'] as String?) ?? 'home';

  Future<void> _save(String value) =>
      ref.set({'residentLandingScreen': value}, SetOptions(merge: true));

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return _CollapsibleCard(
      icon: Icons.home_outlined,
      iconColor: Colors.deepPurple,
      title: 'Resident Landing Screen',
      subtitle: 'What residents see right after logging in.',
      child: Row(children: [
        Expanded(
          child: _LandingOption(
            label: 'Home Screen',
            subtitle: 'Visitors, quick actions, profile',
            icon: Icons.dashboard_outlined,
            selected: current == 'home',
            onTap: () => _save('home'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _LandingOption(
            label: 'My Events',
            subtitle: 'Straight into events & contributions',
            icon: Icons.celebration_outlined,
            selected: current == 'events',
            onTap: () => _save('events'),
          ),
        ),
      ]),
    );
  }
}

class _LandingOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _LandingOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? Colors.deepPurple.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? Colors.deepPurple.shade300 : Colors.grey.shade200,
              width: selected ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.deepPurple : Colors.grey.shade500),
              const Spacer(),
              if (selected)
                Icon(Icons.check_circle, size: 16, color: Colors.deepPurple.shade400),
            ]),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.deepPurple.shade700 : Colors.grey.shade700)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

// ── Country Code Card ──────────────────────────────────────────────────────────
// Sets the community's default calling code, used to normalize resident phone
// numbers before opening a WhatsApp deep link from the Follow-up tab.

class _CountryCodeCard extends StatelessWidget {
  final DocumentReference ref;
  final Map<String, dynamic> data;
  const _CountryCodeCard({required this.ref, required this.data});

  String get _current => (data['countryCode'] as String?) ?? kDefaultCountryDialCode;

  Future<void> _pickCountry(BuildContext context) async {
    final searchCtrl = TextEditingController();
    var filtered = List<CountryCode>.from(kCountryCodes);

    final picked = await showModalBottomSheet<CountryCode>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          builder: (ctx, scrollCtrl) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Country',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                TextField(
                  controller: searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search country or code…',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (q) => setSt(() {
                    final query = q.trim().toLowerCase();
                    filtered = kCountryCodes
                        .where((c) =>
                            c.name.toLowerCase().contains(query) ||
                            c.dialCode.contains(query))
                        .toList();
                  }),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No matches'))
                      : ListView.builder(
                          controller: scrollCtrl,
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final c = filtered[i];
                            return ListTile(
                              leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                              title: Text(c.name),
                              trailing: Text('+${c.dialCode}',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              onTap: () => Navigator.pop(ctx, c),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => searchCtrl.dispose());
    if (picked != null) {
      await ref.set({'countryCode': picked.dialCode}, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = countryByDialCode(_current);
    return _CollapsibleCard(
      icon: Icons.public,
      iconColor: Colors.teal,
      title: 'Country Code',
      subtitle: 'Used to complete resident phone numbers for WhatsApp reminders.',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _pickCountry(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(children: [
            Text(current.flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Text('${current.name}  (+${current.dialCode})',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ]),
        ),
      ),
    );
  }
}

// ── Payment Modes Card ────────────────────────────────────────────────────────

const _kDefaultPaymentModes = ['Cash', 'UPI', 'PhonePe', 'Google Pay', 'Bank Transfer', 'NEFT / RTGS', 'Cheque', 'Other'];

class _PaymentModesCard extends StatelessWidget {
  final DocumentReference ref;
  final Map<String, dynamic> data;
  const _PaymentModesCard({required this.ref, required this.data});

  List<String> get _modes {
    final raw = data['paymentModes'];
    if (raw is List && raw.isNotEmpty) return List<String>.from(raw);
    return List<String>.from(_kDefaultPaymentModes);
  }

  Future<void> _save(List<String> modes) =>
      ref.set({'paymentModes': modes}, SetOptions(merge: true));

  Future<void> _addMode(BuildContext context) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Payment Mode'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Paytm'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (result == null || result.isEmpty) return;
    final updated = [..._modes, result];
    await _save(updated);
  }

  @override
  Widget build(BuildContext context) {
    final modes = _modes;
    return _CollapsibleCard(
      icon: Icons.payments_outlined,
      iconColor: Colors.teal,
      title: 'Payment Modes',
      subtitle: 'Shown to both admin and residents when recording payments.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _addMode(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
              style: TextButton.styleFrom(foregroundColor: Colors.teal),
            ),
          ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIdx, newIdx) {
              final updated = List<String>.from(modes);
              if (newIdx > oldIdx) newIdx--;
              updated.insert(newIdx, updated.removeAt(oldIdx));
              _save(updated);
            },
            children: modes.asMap().entries.map((e) {
              final i = e.key;
              final mode = e.value;
              return ListTile(
                key: ValueKey(mode),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                dense: true,
                leading: const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                title: Text(mode, style: const TextStyle(fontSize: 14)),
                trailing: IconButton(
                  icon: Icon(Icons.remove_circle_outline,
                      color: Colors.red.shade300, size: 20),
                  onPressed: modes.length <= 1
                      ? null
                      : () {
                          final updated = List<String>.from(modes)..removeAt(i);
                          _save(updated);
                        },
                  tooltip: 'Remove',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Wing tile (Wing → Block → Flats) ──────────────────────────────────────────

class _WingTile extends StatelessWidget {
  final String wing;
  final Map<String, dynamic> wingData; // block â†' List<flat>
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onAddBlock;
  final void Function(String block) onDeleteBlock;
  final void Function(String block) onRenameBlock;
  final void Function(String block) onAddFlat;
  final void Function(String block, List<String> flats) onDeleteFlats;
  final void Function(String block, String flat) onRenameFlat;
  final Map<String, int> flatsPerFloor;
  final void Function(String block, int n) onSetFlatsPerFloor;
  final Map<String, int> flatGridRows;
  final void Function(String block, int n) onSetFlatGridRows;

  const _WingTile({
    required this.wing,
    required this.wingData,
    required this.onRename,
    required this.onDelete,
    required this.onAddBlock,
    required this.onDeleteBlock,
    required this.onRenameBlock,
    required this.onAddFlat,
    required this.onDeleteFlats,
    required this.onRenameFlat,
    required this.flatsPerFloor,
    required this.onSetFlatsPerFloor,
    required this.flatGridRows,
    required this.onSetFlatGridRows,
  });

  @override
  Widget build(BuildContext context) {
    final blocks = wingData.keys.toList()..sort();
    final totalFlats = wingData.values
        .fold<int>(0, (sum, v) => sum + (v is List ? v.length : 0));

    return ExpansionTile(
      key: PageStorageKey('wing_$wing'),
      controlAffinity: ListTileControlAffinity.leading,
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.shade50,
            radius: 18,
            child: Text(wing[0].toUpperCase(),
                style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$wing Wing',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                blocks.isEmpty
                    ? const Text('No blocks yet',
                        style: TextStyle(fontSize: 12, color: Colors.orange))
                    : Text(
                        '${blocks.length} block${blocks.length == 1 ? '' : 's'} Â· $totalFlats flat${totalFlats == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline,
                color: Colors.purple.shade600, size: 20),
            tooltip: 'Add Block',
            onPressed: onAddBlock,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined,
                color: Colors.blue.shade400, size: 20),
            tooltip: 'Rename Wing',
            onPressed: onRename,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: Colors.red.shade400, size: 20),
            tooltip: 'Delete Wing',
            onPressed: onDelete,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (blocks.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('No blocks configured.',
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                )
              else
                // One sub-tile per block
                ...blocks.map((block) {
                  final flats = List<String>.from(
                      wingData[block] is List ? wingData[block] as List : [])
                    ..sort();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.purple.shade100),
                    ),
                    child: ExpansionTile(
                      key: PageStorageKey('block_${wing}_$block'),
                      tilePadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(block,
                                  style: TextStyle(
                                      color: Colors.purple.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Block $block',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                Text(
                                  flats.isEmpty
                                      ? 'No flats yet'
                                      : '${flats.length} flat${flats.length == 1 ? '' : 's'}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: flats.isEmpty
                                          ? Colors.orange
                                          : Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add_circle_outline,
                                color: Colors.teal.shade600, size: 20),
                            tooltip: 'Add Flat',
                            onPressed: () => onAddFlat(block),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            icon: Icon(Icons.edit_outlined,
                                color: Colors.blue.shade400, size: 20),
                            tooltip: 'Rename Block',
                            onPressed: () => onRenameBlock(block),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: Colors.red.shade400, size: 20),
                            tooltip: 'Delete Block',
                            onPressed: () => onDeleteBlock(block),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: _FlatGrid(
                            flats: flats,
                            flatsPerFloor: flatsPerFloor['${wing}_$block'],
                            flatGridRows: flatGridRows['${wing}_$block'] ?? 1,
                            onDeleteFlats: (selected) =>
                                onDeleteFlats(block, selected),
                            onRenameFlat: (flat) =>
                                onRenameFlat(block, flat),
                            onAddFlat: () => onAddFlat(block),
                            onSetFlatsPerFloor: (n) =>
                                onSetFlatsPerFloor(block, n),
                            onSetFlatGridRows: (n) =>
                                onSetFlatGridRows(block, n),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

            ],
          ),
        ),
      ],
    );
  }
}

// â"€â"€ Section card (collapsible wrapper) â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€

// â"€â"€ Flat grid with multi-select â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€

class _FlatGrid extends StatefulWidget {
  final List<String> flats;
  final int? flatsPerFloor;
  final int flatGridRows;
  final void Function(List<String> selected) onDeleteFlats;
  final void Function(String flat) onRenameFlat;
  final VoidCallback onAddFlat;
  final void Function(int n) onSetFlatsPerFloor;
  final void Function(int n) onSetFlatGridRows;

  const _FlatGrid({
    required this.flats,
    required this.flatsPerFloor,
    required this.flatGridRows,
    required this.onDeleteFlats,
    required this.onRenameFlat,
    required this.onAddFlat,
    required this.onSetFlatsPerFloor,
    required this.onSetFlatGridRows,
  });

  @override
  State<_FlatGrid> createState() => _FlatGridState();
}

class _FlatGridState extends State<_FlatGrid> {
  final Set<String> _selected = {};

  void _toggle(String flat) {
    setState(() {
      if (_selected.contains(flat)) {
        _selected.remove(flat);
      } else {
        _selected.add(flat);
      }
    });
  }

  void _clearSelection() => setState(() => _selected.clear());

  void _showSetFloorSizeDialog(BuildContext context) async {
    final ctrl = TextEditingController(
        text: widget.flatsPerFloor?.toString() ?? '');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Flats per Floor'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Number of flats per floor',
            hintText: 'e.g. 12',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              final n = int.tryParse(ctrl.text.trim());
              if (n != null && n > 0) Navigator.pop(ctx, n);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (result != null) widget.onSetFlatsPerFloor(result);
  }

  Widget _buildFlatChip(String flat) {
    final isSel = _selected.contains(flat);
    return GestureDetector(
      onTap: () => _toggle(flat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? Colors.teal.shade600 : Colors.teal.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: isSel ? Colors.teal.shade700 : Colors.teal.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSel) ...[
              const Icon(Icons.check, size: 11, color: Colors.white),
              const SizedBox(width: 2),
            ],
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  flat,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSel ? Colors.white : Colors.teal.shade700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selecting = _selected.isNotEmpty;
    final fpf = widget.flatsPerFloor;

    final rows = widget.flatGridRows.clamp(1, 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Floor size + rows-per-floor header
        Row(
          children: [
            Icon(Icons.layers_outlined, size: 13, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              fpf != null ? '$fpf flats / floor' : 'Floor size not set',
              style: TextStyle(
                  fontSize: 11,
                  color: fpf != null
                      ? Colors.grey.shade600
                      : Colors.orange.shade700),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _showSetFloorSizeDialog(context),
              child: Text(
                fpf != null ? 'Change' : 'Set',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.teal.shade700,
                    decoration: TextDecoration.underline),
              ),
            ),
            if (fpf != null && fpf > 0) ...[
              const SizedBox(width: 12),
              Text('Rows:',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(width: 4),
              ...([1, 2, 3].map((n) {
                final isSel = rows == n;
                return GestureDetector(
                  onTap: () => widget.onSetFlatGridRows(n),
                  child: Container(
                    margin: const EdgeInsets.only(left: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSel
                          ? Colors.teal.shade600
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: isSel
                              ? Colors.teal.shade600
                              : Colors.grey.shade300),
                    ),
                    child: Text('$n',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSel
                                ? Colors.white
                                : Colors.grey.shade700)),
                  ),
                );
              })),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (widget.flats.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('No flats added yet.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          )
        else if (fpf == null || fpf <= 0)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.flats.map(_buildFlatChip).toList(),
          )
        else ...[
          // Grouped by floor, split into `rows` sub-rows
          for (int floor = 0;
              floor < (widget.flats.length / fpf).ceil();
              floor++) ...[
            Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6, bottom: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Text(
                    'Floor ${floor + 1}',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
            Builder(builder: (_) {
              final floorFlats =
                  widget.flats.skip(floor * fpf).take(fpf).toList();
              final perRow = (floorFlats.length / rows).ceil();
              return Column(
                children: List.generate(rows, (r) {
                  final rowFlats = floorFlats
                      .skip(r * perRow)
                      .take(perRow)
                      .toList();
                  if (rowFlats.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: EdgeInsets.only(bottom: r < rows - 1 ? 3 : 0),
                    child: Row(
                      children: List.generate(perRow, (i) {
                        if (i >= rowFlats.length) {
                          return Expanded(child: const SizedBox());
                        }
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                                right: i < perRow - 1 ? 3 : 0),
                            child: _buildFlatChip(rowFlats[i]),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              );
            }),
          ],
        ],
        const SizedBox(height: 8),
        // Action bar â€" only shown in selection mode
        if (selecting)
          Row(
            children: [
              Text('${_selected.length} selected',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.teal.shade700,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton(
                onPressed: _clearSelection,
                style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8)),
                child: const Text('Cancel', style: TextStyle(fontSize: 12)),
              ),
              if (_selected.length == 1)
                TextButton.icon(
                  onPressed: () {
                    final flat = _selected.first;
                    _clearSelection();
                    widget.onRenameFlat(flat);
                  },
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8)),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Rename', style: TextStyle(fontSize: 12)),
                ),
              TextButton.icon(
                onPressed: () {
                  final toDelete = _selected.toList();
                  _clearSelection();
                  widget.onDeleteFlats(toDelete);
                },
                style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8)),
                icon: const Icon(Icons.delete_outline, size: 14),
                label: const Text('Delete', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final MaterialColor iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onAdd;
  final String addTooltip;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onAdd,
    required this.addTooltip,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        initiallyExpanded: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: iconColor.shade50,
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor.shade600, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle:
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: _TileTrailing(
          actions: [
            Tooltip(
              message: addTooltip,
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 30,
                  height: 30,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: iconColor.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: iconColor.shade200),
                  ),
                  child: Icon(Icons.add, size: 18, color: iconColor.shade700),
                ),
              ),
            ),
          ],
        ),
        children: children,
      ),
    );
  }
}

// ── Generic collapsible card — every top-level settings section uses this so
// the screen isn't a wall of always-open content; collapsed by default. ──────

class _CollapsibleCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget child;

  const _CollapsibleCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        initiallyExpanded: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [child],
      ),
    );
  }
}

// â"€â"€ Shared trailing widget (actions + animated chevron) â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€

class _TileTrailing extends StatelessWidget {
  final List<Widget> actions;
  const _TileTrailing({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...actions,
        const Icon(Icons.expand_more, color: Colors.grey),
      ],
    );
  }
}
