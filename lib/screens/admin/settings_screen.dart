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

  Future<void> _addBlock(
      Map<String, dynamic> wingBlocks, String wing, List<String> current) async {
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
    if (current.any((b) => b.toLowerCase() == name.toLowerCase())) {
      _snack('"$name" already exists in $wing', Colors.orange);
      return;
    }
    try {
      final updated = Map<String, dynamic>.from(wingBlocks);
      updated[wing] = [...current, name.toUpperCase()];
      await _ref.set({'wingBlocks': updated}, SetOptions(merge: true));
    } catch (e) {
      _snack('Failed: $e', Colors.red);
    }
  }

  Future<void> _deleteBlock(
      Map<String, dynamic> wingBlocks, String wing, String block) async {
    final ok = await _confirmDialog(
        'Remove "$block" from $wing Wing?', 'Existing records are not affected.');
    if (ok == true) {
      final current = List<String>.from(wingBlocks[wing] ?? []);
      final updated = Map<String, dynamic>.from(wingBlocks);
      updated[wing] = current.where((b) => b != block).toList();
      await _ref.set({'wingBlocks': updated}, SetOptions(merge: true));
    }
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
                    ? 'No wings yet'
                    : '${wings.length} wing${wings.length == 1 ? '' : 's'}',
                onAdd: () => _addWing(wings),
                addTooltip: 'Add Wing',
                children: [
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
                        blocks: List<String>.from(wingBlocks[wing] ?? []),
                        onRename: () => _renameWing(wings, wingBlocks, wing),
                        onDelete: () => _deleteWing(wings, wingBlocks, wing),
                        onAddBlock: () => _addBlock(
                            wingBlocks, wing,
                            List<String>.from(wingBlocks[wing] ?? [])),
                        onDeleteBlock: (b) =>
                            _deleteBlock(wingBlocks, wing, b),
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

              const SizedBox(height: 16),

              // ── Info tip ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline,
                        color: Colors.amber.shade700, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Each wing has its own set of blocks. When recording a contribution, '
                        'selecting a wing will only show that wing\'s blocks. '
                        'Deleting a wing or block does not affect existing records.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Wing tile (expandable, shows blocks) ──────────────────────────────────────

class _WingTile extends StatelessWidget {
  final String wing;
  final List<String> blocks;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onAddBlock;
  final void Function(String) onDeleteBlock;

  const _WingTile({
    required this.wing,
    required this.blocks,
    required this.onRename,
    required this.onDelete,
    required this.onAddBlock,
    required this.onDeleteBlock,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: PageStorageKey('wing_$wing'),
      leading: CircleAvatar(
        backgroundColor: Colors.blue.shade50,
        radius: 18,
        child: Text(
          wing[0].toUpperCase(),
          style: TextStyle(
              color: Colors.blue.shade700, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text('$wing Wing',
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: blocks.isEmpty
          ? const Text('No blocks — tap to expand',
              style: TextStyle(fontSize: 12, color: Colors.orange))
          : Text(blocks.map((b) => '$b Block').join(', '),
              style: const TextStyle(fontSize: 12)),
      // Custom trailing: action icons + expand chevron
      trailing: _TileTrailing(
        actions: [
          _IconBtn(Icons.edit_outlined, Colors.blue, onRename, 'Rename'),
          _IconBtn(Icons.delete_outline, Colors.red, onDelete, 'Delete'),
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
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: blocks.map((b) => Chip(
                        label: Text('$b Block'),
                        backgroundColor: Colors.purple.shade50,
                        labelStyle: TextStyle(color: Colors.purple.shade700,
                            fontWeight: FontWeight.w600),
                        deleteIcon:
                            Icon(Icons.close, size: 16, color: Colors.red.shade400),
                        onDeleted: () => onDeleteBlock(b),
                      )).toList(),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onAddBlock,
                  icon: Icon(Icons.add, color: Colors.purple.shade600, size: 18),
                  label: Text('Add Block to $wing Wing',
                      style: TextStyle(color: Colors.purple.shade600)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.purple.shade200),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Section card (collapsible wrapper) ────────────────────────────────────────

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
        initiallyExpanded: true,
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
    // We wrap with GestureDetector to stop taps on our action buttons
    // from propagating to the ExpansionTile's own tap handler.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...actions,
        // Use a Builder trick: the ExpansionTile's animated icon is rendered
        // separately, we just put a static chevron here. Tapping the title
        // area (not the actions) will still toggle the tile.
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
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: color.shade400, size: 20),
        ),
      ),
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
    final subs = List<String>.from(cat['subCategories'] as List? ?? []);
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
    final subs = List<String>.from(cat['subCategories'] as List? ?? [])..remove(sub);
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
        initiallyExpanded: true,
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
    final subs = List<String>.from(cat['subCategories'] as List? ?? []);
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
