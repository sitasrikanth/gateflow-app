import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  DocumentReference get _ref =>
      FirebaseFirestore.instance.collection('community_settings').doc('address');

  // ── Wings ──────────────────────────────────────────────────────────────────

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
              labelText: 'Wing name', hintText: 'e.g. Diamond, Ruby…'),
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

  // ── Blocks ─────────────────────────────────────────────────────────────────

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

  // ── Flats ──────────────────────────────────────────────────────────────────

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
            title: Text('Add Flats — $wing Wing, Block $block',
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
                    'e.g. prefix "$smartPrefix", from 101 to 112  →  ${smartPrefix}101 … ${smartPrefix}112',
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
          ? 'Remove flat "${toDelete.first}" from $wing – Block $block?'
          : 'Remove ${toDelete.length} flats from $wing – Block $block? Existing records are not affected.',
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

  // ── Helpers ────────────────────────────────────────────────────────────────

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

  // ── Build ──────────────────────────────────────────────────────────────────

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
          final rawCats = data['expenseCategories'];
          final List<Map<String, dynamic>> categories = rawCats != null
              ? List<Map<String, dynamic>>.from(
                  (rawCats as List).map((e) => Map<String, dynamic>.from(e)))
              : [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Wings & Blocks ────────────────────────────────────
              _SectionCard(
                icon: Icons.apartment,
                iconColor: Colors.blue,
                title: 'Wings & Blocks',
                subtitle: wings.isEmpty
                    ? 'No wings yet — tap + to add your first wing'
                    : '${wings.length} wing${wings.length == 1 ? '' : 's'} · Tap ⊕ on a wing to add blocks · Tap ⊕ on a block to add flats',
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
                      ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Expense Categories ────────────────────────────────
              _CategoriesCard(
                categories: categories,
                settingsRef: _ref,
                onSnack: _snack,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Wing tile (Wing → Block → Flats) ─────────────────────────────────────────

class _WingTile extends StatelessWidget {
  final String wing;
  final Map<String, dynamic> wingData; // block → List<flat>
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
                        '${blocks.length} block${blocks.length == 1 ? '' : 's'} · $totalFlats flat${totalFlats == 1 ? '' : 's'}',
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
                            onDeleteFlats: (selected) =>
                                onDeleteFlats(block, selected),
                            onRenameFlat: (flat) =>
                                onRenameFlat(block, flat),
                            onAddFlat: () => onAddFlat(block),
                            onSetFlatsPerFloor: (n) =>
                                onSetFlatsPerFloor(block, n),
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

// ── Section card (collapsible wrapper) ────────────────────────────────────────

// ── Flat grid with multi-select ───────────────────────────────────────────────

class _FlatGrid extends StatefulWidget {
  final List<String> flats;
  final int? flatsPerFloor;
  final void Function(List<String> selected) onDeleteFlats;
  final void Function(String flat) onRenameFlat;
  final VoidCallback onAddFlat;
  final void Function(int n) onSetFlatsPerFloor;

  const _FlatGrid({
    required this.flats,
    required this.flatsPerFloor,
    required this.onDeleteFlats,
    required this.onRenameFlat,
    required this.onAddFlat,
    required this.onSetFlatsPerFloor,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              const SizedBox(width: 4),
            ],
            Text(
              flat,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSel ? Colors.white : Colors.teal.shade700),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Floor size header
        Row(
          children: [
            Icon(Icons.layers_outlined, size: 13, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              fpf != null ? '$fpf flats / floor' : 'Floor size not set',
              style: TextStyle(
                  fontSize: 11,
                  color:
                      fpf != null ? Colors.grey.shade600 : Colors.orange.shade700),
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
          // No floor grouping — plain wrap
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.flats.map(_buildFlatChip).toList(),
          )
        else ...[
          // Grouped by floor
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
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.flats
                  .skip(floor * fpf)
                  .take(fpf)
                  .map(_buildFlatChip)
                  .toList(),
            ),
          ],
        ],
        const SizedBox(height: 8),
        // Action bar — only shown in selection mode
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

// ── Shared trailing widget (actions + animated chevron) ───────────────────────

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

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final MaterialColor color;
  final VoidCallback onTap;
  final String tooltip;
  const _IconBtn(this.icon, this.color, this.onTap, this.tooltip);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, color: color.shade600, size: 20),
      onPressed: onTap,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(),
      splashRadius: 20,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── Expense Categories Card ────────────────────────────────────────────────────

const List<Map<String, dynamic>> kDefaultCategories = [
  {
    'name': 'Annadam',
    'icon': '🍚',
    'subCategories': ['Rice', 'Dal / Lentils', 'Vegetables', 'Cooking Oil', 'Spices', 'Plates & Cups', 'Fruits'],
  },
  {
    'name': 'Decoration',
    'icon': '🎨',
    'subCategories': ['Flowers', 'Balloons', 'Banners & Flex', 'Rangoli'],
  },
  {
    'name': 'Ganesh Idol',
    'icon': '🪔',
    'subCategories': ['Idol Cost', 'Transportation', 'Visarjan Charges'],
  },
  {
    'name': 'Priest / Pandit',
    'icon': '🙏',
    'subCategories': ['Dakshina', 'Pooja Items', 'Agarbatti & Camphor'],
  },
  {
    'name': 'Music & Sound',
    'icon': '🎵',
    'subCategories': ['Sound System', 'DJ / Band', 'Microphone Rental'],
  },
  {
    'name': 'Lighting',
    'icon': '💡',
    'subCategories': ['LED Lights', 'Candles & Diyas', 'Generator Rental'],
  },
  {
    'name': 'Transport',
    'icon': '🚗',
    'subCategories': ['Vehicle Rental', 'Fuel', 'Parking Charges'],
  },
  {
    'name': 'Prasad',
    'icon': '🍬',
    'subCategories': ['Modak', 'Laddu', 'Fruits', 'Peda', 'Dry Fruits'],
  },
  {
    'name': 'Misc',
    'icon': '📦',
    'subCategories': [],
  },
];

const List<String> kEmojiPicker = [
  '🎨', '🍱', '🙏', '🎵', '🚗', '🌸', '💡', '📦',
  '🎊', '🪔', '🥁', '🎺', '🍬', '🌺', '🧨', '🎁',
  '🏮', '🕯️', '🎤', '📸', '🧹', '🛒', '💰', '🔧',
  '🍚', '🥬', '🍲', '🫙', '🍽️', '🧂',
];

class _CategoriesCard extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final DocumentReference settingsRef;
  final void Function(String, Color) onSnack;

  const _CategoriesCard({
    required this.categories,
    required this.settingsRef,
    required this.onSnack,
  });

  @override
  State<_CategoriesCard> createState() => _CategoriesCardState();
}

class _CategoriesCardState extends State<_CategoriesCard> {
  bool _seeded = false;

  @override
  void didUpdateWidget(_CategoriesCard old) {
    super.didUpdateWidget(old);
    if (!_seeded && widget.categories.isEmpty) {
      _seeded = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _seedDefaults(silent: true));
    }
  }

  // ── Firestore ─────────────────────────────────────────────────────────────

  Future<void> _write(List<Map<String, dynamic>> updated) =>
      widget.settingsRef.set({'expenseCategories': updated}, SetOptions(merge: true));

  Future<void> _seedDefaults({bool silent = false}) async {
    await _write(List<Map<String, dynamic>>.from(kDefaultCategories));
    if (!silent) widget.onSnack('Default categories loaded', Colors.green);
  }

  // ── Main category ops ─────────────────────────────────────────────────────

  Future<void> _addMain() async {
    String emoji = '📦';
    final ctrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Add Category'),
          content: Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final picked = await _pickEmoji(ctx, emoji);
                  if (picked != null) set(() => emoji = picked);
                },
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'e.g. Annadam…'),
                  onSubmitted: (_) => Navigator.pop(ctx, true),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    final name = ctrl.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (ok != true || name.isEmpty) return;
    if (widget.categories.any(
        (c) => (c['name'] as String).toLowerCase() == name.toLowerCase())) {
      widget.onSnack('"$name" already exists', Colors.orange);
      return;
    }
    try {
      await _write([
        ...widget.categories,
        {'name': name, 'icon': emoji, 'subCategories': <String>[]},
      ]);
    } catch (e) {
      widget.onSnack('Failed: $e', Colors.red);
    }
  }

  Future<void> _renameMain(Map<String, dynamic> cat) async {
    final ctrl = TextEditingController(text: cat['name'] as String);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Category'),
        content: TextField(
          controller: ctrl, autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (newName == null || newName.isEmpty || newName == cat['name']) return;
    final updated = widget.categories
        .map((c) => c['name'] == cat['name'] ? {...c, 'name': newName} : c)
        .toList();
    await _write(updated);
  }

  Future<void> _deleteMain(Map<String, dynamic> cat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${cat['name']}"?'),
        content: const Text('All sub-categories will be removed. Existing records are not affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _write(widget.categories.where((c) => c['name'] != cat['name']).toList());
    }
  }

  // ── Sub-category ops ──────────────────────────────────────────────────────

  Future<void> _addSub(Map<String, dynamic> cat) async {
    final ctrl = TextEditingController();
    final sub = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add to "${cat['name']}"'),
        content: TextField(
          controller: ctrl, autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Rice, Vegetables…'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (sub == null || sub.isEmpty) return;
    final rawSubs = cat['subCategories'];
    final subs = List<String>.from(rawSubs is List ? rawSubs : []);
    if (subs.any((s) => s.toLowerCase() == sub.toLowerCase())) {
      widget.onSnack('"$sub" already exists', Colors.orange);
      return;
    }
    subs.add(sub);
    final updated = widget.categories
        .map((c) => c['name'] == cat['name'] ? {...c, 'subCategories': subs} : c)
        .toList();
    await _write(updated);
  }

  Future<void> _deleteSub(Map<String, dynamic> cat, String sub) async {
    final rawSubs2 = cat['subCategories'];
    final subs = List<String>.from(rawSubs2 is List ? rawSubs2 : [])..remove(sub);
    final updated = widget.categories
        .map((c) => c['name'] == cat['name'] ? {...c, 'subCategories': subs} : c)
        .toList();
    await _write(updated);
  }

  Future<String?> _pickEmoji(BuildContext ctx, String current) =>
      showDialog<String>(
        context: ctx,
        builder: (dlg) => AlertDialog(
          title: const Text('Pick an Icon'),
          content: SizedBox(
            width: 300,
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: kEmojiPicker.map((e) => GestureDetector(
                    onTap: () => Navigator.pop(dlg, e),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: current == e ? Colors.red.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: current == e ? Colors.red.shade300 : Colors.transparent,
                        ),
                      ),
                      child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
                    ),
                  )).toList(),
            ),
          ),
        ),
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cats = widget.categories;

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
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.receipt_long, color: Colors.red.shade600, size: 20),
        ),
        title: const Text('Expense Categories',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(
          cats.isEmpty ? 'Loading…' : '${cats.length} categories',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: _TileTrailing(
          actions: [
            Tooltip(
              message: 'Load Defaults',
              child: InkWell(
                onTap: () => _seedDefaults(),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.auto_fix_high,
                      size: 20, color: Colors.red.shade400),
                ),
              ),
            ),
            Tooltip(
              message: 'Add Category',
              child: InkWell(
                onTap: _addMain,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 30, height: 30,
                  margin: const EdgeInsets.only(left: 4, right: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Icon(Icons.add, size: 18, color: Colors.red.shade700),
                ),
              ),
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          if (cats.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Loading categories…',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
            )
          else
            for (final cat in cats)
              _CategoryTile(
                cat: cat,
                onRename: () => _renameMain(cat),
                onDelete: () => _deleteMain(cat),
                onChangeIcon: () async {
                  final picked = await _pickEmoji(
                      context, cat['icon'] as String? ?? '📦');
                  if (picked != null) {
                    final updated = widget.categories
                        .map((c) =>
                            c['name'] == cat['name'] ? {...c, 'icon': picked} : c)
                        .toList();
                    await _write(updated);
                  }
                },
                onAddSub: () => _addSub(cat),
                onDeleteSub: (sub) => _deleteSub(cat, sub),
              ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Category tile (expandable, shows sub-categories) ──────────────────────────

class _CategoryTile extends StatelessWidget {
  final Map<String, dynamic> cat;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onChangeIcon;
  final VoidCallback onAddSub;
  final void Function(String) onDeleteSub;

  const _CategoryTile({
    required this.cat,
    required this.onRename,
    required this.onDelete,
    required this.onChangeIcon,
    required this.onAddSub,
    required this.onDeleteSub,
  });

  @override
  Widget build(BuildContext context) {
    final rawSubs = cat['subCategories'];
    final subs = List<String>.from(rawSubs is List ? rawSubs : []);
    final name = cat['name'] as String? ?? '';
    final icon = cat['icon'] as String? ?? '📦';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        key: PageStorageKey('cat_$name'),
        leading: GestureDetector(
          onTap: onChangeIcon,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 20))),
          ),
        ),
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          subs.isEmpty ? 'No sub-categories' : subs.join(' · '),
          style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _TileTrailing(
          actions: [
            _IconBtn(Icons.edit_outlined, Colors.blue, onRename, 'Rename'),
            _IconBtn(Icons.delete_outline, Colors.red, onDelete, 'Delete'),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text('No sub-categories yet.',
                        style:
                            TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  )
                else
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: subs
                        .map((sub) => Chip(
                              label: Text(sub, style: const TextStyle(fontSize: 12)),
                              backgroundColor: Colors.red.shade50,
                              labelStyle: TextStyle(color: Colors.red.shade700),
                              deleteIcon: Icon(Icons.close,
                                  size: 14, color: Colors.red.shade300),
                              onDeleted: () => onDeleteSub(sub),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                            ))
                        .toList(),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onAddSub,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Sub-category',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
