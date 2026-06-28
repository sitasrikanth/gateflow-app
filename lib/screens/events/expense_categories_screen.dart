import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'event_types.dart';

// ── Canonical Firestore location for event expense categories ──────────────────
// Path: event_config/categories  field: expenseCategories
// Migrated from community_settings/address on first load if needed.

const List<Map<String, dynamic>> kDefaultCategories = [
  {
    'name': 'Food & Catering',
    'icon': '🍽️',
    'subCategories': ['Catering Service', 'Raw Materials', 'Snacks & Beverages', 'Plates & Cups', 'Cooking Fuel'],
  },
  {
    'name': 'Decoration',
    'icon': '🎨',
    'subCategories': ['Flowers & Garlands', 'Balloons', 'Banners & Flex', 'Stage Setup', 'Lighting'],
  },
  {
    'name': 'Venue & Setup',
    'icon': '🏠',
    'subCategories': ['Hall / Venue Rental', 'Chairs & Tables', 'Tent / Shamiana', 'Cleaning Charges'],
  },
  {
    'name': 'Entertainment',
    'icon': '🎤',
    'subCategories': ['Performers / Artists', 'Anchor / Compere', 'Kids Activities', 'Games & Prizes'],
  },
  {
    'name': 'Music & Sound',
    'icon': '🎵',
    'subCategories': ['Sound System', 'DJ / Band', 'Microphone Rental'],
  },
  {
    'name': 'Photography',
    'icon': '📸',
    'subCategories': ['Photographer', 'Videographer', 'Drone', 'Printing'],
  },
  {
    'name': 'Transport',
    'icon': '🚗',
    'subCategories': ['Vehicle Rental', 'Fuel', 'Parking Charges'],
  },
  {
    'name': 'Gifts & Prizes',
    'icon': '🎁',
    'subCategories': ['Trophies', 'Gift Hampers', 'Certificates', 'Mementos'],
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

DocumentReference get expenseCategoriesRef =>
    FirebaseFirestore.instance.collection('event_config').doc('categories');

// Per-event-type categories stored at /eventTypeConfig/{typeId}
DocumentReference eventTypeCategoriesRef(String typeId) =>
    FirebaseFirestore.instance.collection('eventTypeConfig').doc(typeId);

// Load categories for a specific event type, seeding defaults from event_types.dart if first use
Future<List<Map<String, dynamic>>> loadEventTypeCategories(String typeId) async {
  if (typeId.isEmpty) return loadExpenseCategories();
  final snap = await eventTypeCategoriesRef(typeId).get();
  final data = snap.data() as Map<String, dynamic>? ?? {};
  if (data['expenseCategories'] != null) {
    return List<Map<String, dynamic>>.from(
        (data['expenseCategories'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
  }
  // Seed from event_types.dart defaults for this event type
  final evType = eventTypeById(typeId);
  final defaults = evType != null
      ? evType.expenseCategories.map((e) => Map<String, dynamic>.from(e)).toList()
      : List<Map<String, dynamic>>.from(kDefaultCategories.map((e) => Map<String, dynamic>.from(e)));
  await eventTypeCategoriesRef(typeId).set({'expenseCategories': defaults});
  return defaults;
}

/// Loads categories from event_config/categories, migrating from
/// community_settings/address if the new location is empty.
Future<List<Map<String, dynamic>>> loadExpenseCategories() async {
  final snap = await expenseCategoriesRef.get();
  final data = snap.data() as Map<String, dynamic>? ?? {};
  if (data['expenseCategories'] != null) {
    return List<Map<String, dynamic>>.from(
        (data['expenseCategories'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
  }

  // Migrate from old location
  final oldSnap = await FirebaseFirestore.instance
      .collection('community_settings')
      .doc('address')
      .get();
  final oldData = oldSnap.data() as Map? ?? {};
  if (oldData['expenseCategories'] != null) {
    final migrated = List<Map<String, dynamic>>.from(
        (oldData['expenseCategories'] as List).map((e) => Map<String, dynamic>.from(e)));
    await expenseCategoriesRef.set({'expenseCategories': migrated}, SetOptions(merge: true));
    return migrated;
  }

  // Seed defaults on first use
  final defaults = List<Map<String, dynamic>>.from(
      kDefaultCategories.map((e) => Map<String, dynamic>.from(e)));
  await expenseCategoriesRef.set({'expenseCategories': defaults}, SetOptions(merge: true));
  return defaults;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ExpenseCategoriesScreen extends StatefulWidget {
  const ExpenseCategoriesScreen({super.key});

  @override
  State<ExpenseCategoriesScreen> createState() => _ExpenseCategoriesScreenState();
}

class _ExpenseCategoriesScreenState extends State<ExpenseCategoriesScreen> {
  final _ref = expenseCategoriesRef;

  Future<void> _write(List<Map<String, dynamic>> updated) =>
      _ref.set({'expenseCategories': updated}, SetOptions(merge: true));

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Future<void> _seedDefaults(List<Map<String, dynamic>> current) async {
    final existingNames = current.map((c) => c['name'] as String).toSet();
    final toAdd = kDefaultCategories
        .where((d) => !existingNames.contains(d['name'] as String))
        .map((d) => Map<String, dynamic>.from(d))
        .toList();
    await _write([...current, ...toAdd]);
    _snack(
      toAdd.isEmpty
          ? 'All defaults already present'
          : '${toAdd.length} default categor${toAdd.length == 1 ? 'y' : 'ies'} added',
      Colors.green,
    );
  }

  // ── Main category ops ─────────────────────────────────────────────────────

  Future<void> _addMain(List<Map<String, dynamic>> current) async {
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
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'e.g. Annadam…'),
                  onSubmitted: (_) => Navigator.pop(ctx, true),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
    if (current.any((c) => (c['name'] as String).toLowerCase() == name.toLowerCase())) {
      _snack('"$name" already exists', Colors.orange);
      return;
    }
    try {
      await _write([...current, {'name': name, 'icon': emoji, 'subCategories': <String>[]}]);
    } catch (e) {
      _snack('Failed: $e', Colors.red);
    }
  }

  Future<void> _renameMain(
      List<Map<String, dynamic>> current, Map<String, dynamic> cat) async {
    final ctrl = TextEditingController(text: cat['name'] as String);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Category'),
        content: TextField(
          controller: ctrl,
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
    await _write(current
        .map((c) => c['name'] == cat['name'] ? {...c, 'name': newName} : c)
        .toList());
  }

  Future<void> _deleteMain(
      List<Map<String, dynamic>> current, Map<String, dynamic> cat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${cat['name']}"?'),
        content: const Text(
            'All sub-categories will be removed. Existing expense records are not affected.'),
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
      await _write(current.where((c) => c['name'] != cat['name']).toList());
    }
  }

  Future<void> _changeIcon(
      List<Map<String, dynamic>> current, Map<String, dynamic> cat) async {
    final picked = await _pickEmoji(context, cat['icon'] as String? ?? '📦');
    if (picked != null) {
      await _write(current
          .map((c) => c['name'] == cat['name'] ? {...c, 'icon': picked} : c)
          .toList());
    }
  }

  // ── Sub-category ops ──────────────────────────────────────────────────────

  Future<void> _addSub(
      List<Map<String, dynamic>> current, Map<String, dynamic> cat) async {
    final ctrl = TextEditingController();
    final sub = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add to "${cat['name']}"'),
        content: TextField(
          controller: ctrl,
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
    final subs = List<String>.from(
        cat['subCategories'] is List ? cat['subCategories'] as List : []);
    if (subs.any((s) => s.toLowerCase() == sub.toLowerCase())) {
      _snack('"$sub" already exists', Colors.orange);
      return;
    }
    subs.add(sub);
    await _write(current
        .map((c) => c['name'] == cat['name'] ? {...c, 'subCategories': subs} : c)
        .toList());
  }

  Future<void> _deleteSub(
      List<Map<String, dynamic>> current, Map<String, dynamic> cat, String sub) async {
    final subs = List<String>.from(
        cat['subCategories'] is List ? cat['subCategories'] as List : [])
      ..remove(sub);
    await _write(current
        .map((c) => c['name'] == cat['name'] ? {...c, 'subCategories': subs} : c)
        .toList());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Expense Categories',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _ref.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data?.data() as Map<String, dynamic>? ?? {};
          final rawCats = data['expenseCategories'];
          final List<Map<String, dynamic>> cats = rawCats != null
              ? List<Map<String, dynamic>>.from(
                  (rawCats as List).map((e) => Map<String, dynamic>.from(e as Map)))
              : [];

          // Auto-seed on first open
          if (rawCats == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => loadExpenseCategories());
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.deepPurple.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.deepPurple.shade400, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'These categories are shared across all events. '
                        'Add, rename, or remove categories and sub-categories here.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Action row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _seedDefaults(cats),
                      icon: Icon(Icons.auto_fix_high,
                          size: 16, color: Colors.deepPurple.shade600),
                      label: Text('Load Defaults',
                          style: TextStyle(color: Colors.deepPurple.shade700)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.deepPurple.shade200),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _addMain(cats),
                      icon: const Icon(Icons.add, size: 16, color: Colors.white),
                      label: const Text('Add Category',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade500,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (cats.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No categories yet',
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('Tap "Load Defaults" to add the standard set',
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 12)),
                      ],
                    ),
                  ),
                )
              else
                ...cats.map((cat) => _CategoryTile(
                      cat: cat,
                      onRename: () => _renameMain(cats, cat),
                      onDelete: () => _deleteMain(cats, cat),
                      onChangeIcon: () => _changeIcon(cats, cat),
                      onAddSub: () => _addSub(cats, cat),
                      onDeleteSub: (sub) => _deleteSub(cats, cat, sub),
                    )),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}

// ── Category tile ─────────────────────────────────────────────────────────────

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
    final subs = List<String>.from(
        cat['subCategories'] is List ? cat['subCategories'] as List : []);
    final name = cat['name'] as String? ?? '';
    final icon = cat['icon'] as String? ?? '📦';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_outlined,
                  size: 18, color: Colors.blue.shade400),
              tooltip: 'Rename',
              onPressed: onRename,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 18, color: Colors.red.shade400),
              tooltip: 'Delete',
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
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
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 12)),
                  )
                else
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: subs
                        .map((sub) => Chip(
                              label: Text(sub,
                                  style: const TextStyle(fontSize: 12)),
                              backgroundColor: Colors.red.shade50,
                              labelStyle:
                                  TextStyle(color: Colors.red.shade700),
                              deleteIcon: Icon(Icons.close,
                                  size: 14, color: Colors.red.shade300),
                              onDeleted: () => onDeleteSub(sub),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
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
