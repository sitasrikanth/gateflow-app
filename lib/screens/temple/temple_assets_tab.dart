import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Temple Assets — inventory + maintenance history ───────────────────────────
// Tracks idols, ornaments, utensils, furniture, sound systems, etc. Each asset
// has its own maintenance/inventory log subcollection (same pattern as Task
// comments — small bounded lists embedded, unbounded history as a
// subcollection with its own live stream).

const List<String> kTempleAssetCategories = [
  'Idol', 'Ornament', 'Utensil', 'Furniture', 'Sound System', 'Other',
];
const List<String> kTempleAssetConditions = ['Good', 'Needs Repair', 'Damaged'];

class TempleAssetsTab extends StatefulWidget {
  final bool isAdmin;
  const TempleAssetsTab({super.key, required this.isAdmin});

  @override
  State<TempleAssetsTab> createState() => _TempleAssetsTabState();
}

class _TempleAssetsTabState extends State<TempleAssetsTab> {
  String _categoryFilter = 'All';

  CollectionReference get _col => FirebaseFirestore.instance.collection('templeAssets');

  Future<void> _addOrEditAsset({DocumentSnapshot? existing}) async {
    final d = existing?.data() as Map<String, dynamic>?;
    final nameCtrl = TextEditingController(text: d?['name'] as String? ?? '');
    final descCtrl = TextEditingController(text: d?['description'] as String? ?? '');
    final valueCtrl = TextEditingController(
        text: ((d?['value'] as num?) ?? 0) > 0 ? (d!['value'] as num).toStringAsFixed(0) : '');
    String category = d?['category'] as String? ?? kTempleAssetCategories.first;
    String condition = d?['condition'] as String? ?? kTempleAssetConditions.first;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setSt) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(existing == null ? 'Add Asset' : 'Edit Asset'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Asset Name', hintText: 'e.g. Silver Kalasam'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Category', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: kTempleAssetCategories.map((c) {
                      final sel = category == c;
                      return ChoiceChip(
                        label: Text(c, style: const TextStyle(fontSize: 12)),
                        selected: sel,
                        onSelected: (_) => setSt(() => category = c),
                        selectedColor: Colors.deepOrange.shade600,
                        labelStyle: TextStyle(color: sel ? Colors.white : Colors.grey.shade700),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text('Condition', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: kTempleAssetConditions.map((c) {
                      final sel = condition == c;
                      return ChoiceChip(
                        label: Text(c, style: const TextStyle(fontSize: 12)),
                        selected: sel,
                        onSelected: (_) => setSt(() => condition = c),
                        selectedColor: Colors.deepOrange.shade600,
                        labelStyle: TextStyle(color: sel ? Colors.white : Colors.grey.shade700),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: valueCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Estimated Value (₹) (Optional)', hintText: 'e.g. 25000'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Description / Location (Optional)',
                        hintText: 'e.g. Kept in the sanctum store room'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) {
                    setSt(() => error = 'Enter an asset name');
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange.shade700),
                child: Text(existing == null ? 'Add' : 'Save', style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameCtrl.dispose();
      descCtrl.dispose();
      valueCtrl.dispose();
    });
    if (result != true) return;

    final payload = {
      'name': nameCtrl.text.trim(),
      'category': category,
      'condition': condition,
      'value': double.tryParse(valueCtrl.text.trim()) ?? 0,
      'description': descCtrl.text.trim(),
    };
    if (existing != null) {
      await existing.reference.update(payload);
    } else {
      payload['createdAt'] = DateTime.now().toIso8601String();
      await _col.add(payload);
    }
  }

  Future<void> _deleteAsset(DocumentReference ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Asset'),
        content: const Text('This will permanently remove this asset and its maintenance history.'),
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
    if (confirmed == true) await ref.delete();
  }

  Future<void> _addMaintenanceEntry(DocumentReference assetRef) async {
    final descCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final performedByCtrl = TextEditingController();
    DateTime date = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Add Maintenance Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text('${date.day}/${date.month}/${date.year}'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setSt(() => date = picked);
                  },
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'What was done', hintText: 'e.g. Polishing'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: costCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Cost (₹) (Optional)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: performedByCtrl,
                  decoration: const InputDecoration(labelText: 'Performed By (Optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange.shade700),
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      descCtrl.dispose();
      costCtrl.dispose();
      performedByCtrl.dispose();
    });
    if (result != true || descCtrl.text.trim().isEmpty) return;

    await assetRef.collection('maintenanceLog').add({
      'date': date.toIso8601String(),
      'description': descCtrl.text.trim(),
      'cost': double.tryParse(costCtrl.text.trim()) ?? 0,
      'performedBy': performedByCtrl.text.trim(),
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  void _showAssetDetail(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(d['name'] as String? ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ),
                if (widget.isAdmin) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _addOrEditAsset(existing: doc);
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade600),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteAsset(doc.reference);
                    },
                  ),
                ],
              ]),
              Text('${d['category']} · ${d['condition']}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              if ((d['description'] as String? ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(d['description'] as String, style: const TextStyle(fontSize: 13)),
              ],
              const SizedBox(height: 16),
              Row(children: [
                Text('Maintenance History',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.grey.shade800)),
                const Spacer(),
                if (widget.isAdmin)
                  TextButton.icon(
                    onPressed: () => _addMaintenanceEntry(doc.reference),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                  ),
              ]),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: doc.reference
                      .collection('maintenanceLog')
                      .orderBy('date', descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    final logs = snap.data?.docs ?? [];
                    if (logs.isEmpty) {
                      return Center(
                          child: Text('No maintenance history yet',
                              style: TextStyle(color: Colors.grey.shade400)));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: logs.length,
                      itemBuilder: (context, i) {
                        final l = logs[i].data() as Map<String, dynamic>;
                        final date = DateTime.tryParse(l['date'] as String? ?? '');
                        final cost = (l['cost'] as num?)?.toDouble() ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.build_outlined, size: 16, color: Colors.deepOrange.shade400),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l['description'] as String? ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    Text(
                                        '${date != null ? '${date.day}/${date.month}/${date.year}' : ''}'
                                        '${(l['performedBy'] as String? ?? '').isNotEmpty ? ' · ${l['performedBy']}' : ''}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                  ],
                                ),
                              ),
                              if (cost > 0)
                                Text('₹${cost.toStringAsFixed(0)}',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _conditionColor(String condition) {
    switch (condition) {
      case 'Good':
        return Colors.green;
      case 'Needs Repair':
        return Colors.orange;
      case 'Damaged':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _col.snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final filtered = _categoryFilter == 'All'
            ? docs
            : docs
                .where((doc) => (doc.data() as Map<String, dynamic>)['category'] == _categoryFilter)
                .toList();

        return Column(
          children: [
            if (widget.isAdmin)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _addOrEditAsset(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Asset'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, widget.isAdmin ? 0 : 16, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', ...kTempleAssetCategories].map((c) {
                    final sel = _categoryFilter == c;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: sel,
                        onSelected: (_) => setState(() => _categoryFilter = c),
                        selectedColor: Colors.deepOrange.shade600,
                        labelStyle: TextStyle(
                            color: sel ? Colors.white : Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text('No assets recorded yet', style: TextStyle(color: Colors.grey.shade400)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final doc = filtered[i];
                        final d = doc.data() as Map<String, dynamic>;
                        final condition = d['condition'] as String? ?? 'Good';
                        final value = (d['value'] as num?)?.toDouble() ?? 0;
                        return GestureDetector(
                          onTap: () => _showAssetDetail(doc),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.museum_outlined, color: Colors.deepOrange.shade700, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(d['name'] as String? ?? '',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: Theme.of(context).textTheme.bodyLarge?.color)),
                                    Text(d['category'] as String? ?? '',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _conditionColor(condition).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(condition,
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: _conditionColor(condition))),
                                  ),
                                  if (value > 0) ...[
                                    const SizedBox(height: 4),
                                    Text('₹${value.toStringAsFixed(0)}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                  ],
                                ],
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
