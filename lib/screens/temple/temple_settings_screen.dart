import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_temple_donation_screen.dart' show kDefaultTempleCategories;
import 'add_temple_expense_screen.dart' show kDefaultTempleExpenseCategories;

// ── Temple Donation Settings ──────────────────────────────────────────────────
// Admin-only screen to configure contribution tiers (name, amount, benefits,
// recognition) and donation categories, stored in a single settings doc
// (following the community_settings/appSettings live-stream pattern used
// throughout the rest of the app).

class TempleSettingsScreen extends StatefulWidget {
  const TempleSettingsScreen({super.key});

  @override
  State<TempleSettingsScreen> createState() => _TempleSettingsScreenState();
}

class _TempleSettingsScreenState extends State<TempleSettingsScreen> {
  static final DocumentReference _ref =
      FirebaseFirestore.instance.collection('appSettings').doc('templeDonationConfig');

  Future<void> _writeTiers(List<Map<String, dynamic>> tiers) =>
      _ref.set({'tiers': tiers}, SetOptions(merge: true));

  Future<void> _writeCategories(List<String> categories) =>
      _ref.set({'categories': categories}, SetOptions(merge: true));

  Future<void> _writeExpenseCategories(List<String> categories) =>
      _ref.set({'expenseCategories': categories}, SetOptions(merge: true));

  Future<void> _addOrEditTier(
      List<Map<String, dynamic>> current, {Map<String, dynamic>? existing, int? index}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] as String? ?? '');
    final existingAmount = (existing?['amount'] as num?) ?? 0;
    final amountCtrl =
        TextEditingController(text: existingAmount > 0 ? existingAmount.toStringAsFixed(0) : '');
    final benefitsCtrl = TextEditingController(text: existing?['benefits'] as String? ?? '');
    final recognitionCtrl = TextEditingController(text: existing?['recognition'] as String? ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(existing == null ? 'Add Contribution Tier' : 'Edit Contribution Tier'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                          labelText: 'Tier Name', hintText: 'e.g. Gold, Silver, Patron'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Amount (₹)', hintText: 'e.g. 5000'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: benefitsCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Benefits (optional)',
                          hintText: 'e.g. Free prasad on festival days'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: recognitionCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Recognition (optional)',
                          hintText: 'e.g. Name on donor board'),
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
                    final name = nameCtrl.text.trim();
                    final amount = double.tryParse(
                        amountCtrl.text.trim().replaceAll(',', '').replaceAll('₹', ''));
                    if (name.isEmpty) {
                      setDialogState(() => error = 'Enter a tier name');
                      return;
                    }
                    if (amount == null || amount <= 0) {
                      setDialogState(() => error = 'Enter a valid amount greater than 0');
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange.shade700),
                  child: Text(existing == null ? 'Add' : 'Save',
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameCtrl.dispose();
      amountCtrl.dispose();
      benefitsCtrl.dispose();
      recognitionCtrl.dispose();
    });

    if (result != true) return;
    final entry = {
      'name': nameCtrl.text.trim(),
      'amount': double.tryParse(
              amountCtrl.text.trim().replaceAll(',', '').replaceAll('₹', '')) ??
          0,
      'benefits': benefitsCtrl.text.trim(),
      'recognition': recognitionCtrl.text.trim(),
    };
    final updated = List<Map<String, dynamic>>.from(current);
    if (index != null) {
      updated[index] = entry;
    } else {
      updated.add(entry);
    }
    try {
      await _writeTiers(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteTier(List<Map<String, dynamic>> current, int index) async {
    final name = current[index]['name'] as String? ?? 'this tier';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: const Text('Existing donations already recorded at this tier are kept.'),
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
    if (confirmed != true) return;
    final updated = List<Map<String, dynamic>>.from(current)..removeAt(index);
    await _writeTiers(updated);
  }

  Future<void> _addCategory(List<String> current) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Annadanam'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange.shade700),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (result == null || result.isEmpty || current.contains(result)) return;
    await _writeCategories([...current, result]);
  }

  Future<void> _deleteCategory(List<String> current, String category) async {
    await _writeCategories(current.where((c) => c != category).toList());
  }

  Future<void> _addExpenseCategory(List<String> current) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Expense Category'),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Pooja Materials'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange.shade700),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (result == null || result.isEmpty || current.contains(result)) return;
    await _writeExpenseCategories([...current, result]);
  }

  Future<void> _deleteExpenseCategory(List<String> current, String category) async {
    await _writeExpenseCategories(current.where((c) => c != category).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Temple Donation Settings',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.deepOrange.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _ref.snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() as Map<String, dynamic>? ?? {};
          final rawTiers = data['tiers'] as List?;
          final tiers = rawTiers != null
              ? List<Map<String, dynamic>>.from(
                  rawTiers.map((e) => Map<String, dynamic>.from(e as Map)))
              : <Map<String, dynamic>>[];
          final rawCats = data['categories'] as List?;
          final categories = rawCats != null && rawCats.isNotEmpty
              ? List<String>.from(rawCats)
              : kDefaultTempleCategories;
          final rawExpenseCats = data['expenseCategories'] as List?;
          final expenseCategories = rawExpenseCats != null && rawExpenseCats.isNotEmpty
              ? List<String>.from(rawExpenseCats)
              : kDefaultTempleExpenseCategories;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Contribution Tiers',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15, color: Colors.grey.shade800)),
              const SizedBox(height: 4),
              Text(
                  'Configurable tiers (e.g. ₹5,000, ₹10,000, ₹25,000) shown when recording a donation.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(height: 12),
              if (tiers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('No tiers configured yet',
                      style: TextStyle(color: Colors.grey.shade400)),
                )
              else
                ...tiers.asMap().entries.map((entry) {
                  final i = entry.key;
                  final t = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t['name'] as String? ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('₹${((t['amount'] as num?) ?? 0).toStringAsFixed(0)}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade700)),
                              if ((t['benefits'] as String? ?? '').isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text('Benefits: ${t['benefits']}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                ),
                              if ((t['recognition'] as String? ?? '').isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text('Recognition: ${t['recognition']}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: Colors.grey.shade500, size: 18),
                          onPressed: () => _addOrEditTier(tiers, existing: t, index: i),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.red.shade300, size: 18),
                          onPressed: () => _deleteTier(tiers, i),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _addOrEditTier(tiers),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Tier'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepOrange.shade700,
                    side: BorderSide(color: Colors.deepOrange.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text('Donation Categories',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15, color: Colors.grey.shade800)),
              const SizedBox(height: 4),
              Text('Purpose tags shown when recording a donation (e.g. Annadanam, Festival).',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...categories.map((c) => Chip(
                        label: Text(c),
                        onDeleted: () => _deleteCategory(categories, c),
                        deleteIconColor: Colors.red.shade300,
                        backgroundColor: Colors.deepOrange.shade50,
                      )),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                    onPressed: () => _addCategory(categories),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text('Expense Categories',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15, color: Colors.grey.shade800)),
              const SizedBox(height: 4),
              Text('Categories shown when recording a temple expense.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...expenseCategories.map((c) => Chip(
                        label: Text(c),
                        onDeleted: () => _deleteExpenseCategory(expenseCategories, c),
                        deleteIconColor: Colors.red.shade300,
                        backgroundColor: Colors.deepOrange.shade50,
                      )),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                    onPressed: () => _addExpenseCategory(expenseCategories),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
