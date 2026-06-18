import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../admin/settings_screen.dart' show kDefaultCategories;

class AddExpenseScreen extends StatefulWidget {
  final String eventId;
  final String? existingExpenseId;
  final Map<String, dynamic>? existingData;
  const AddExpenseScreen({
    super.key,
    required this.eventId,
    this.existingExpenseId,
    this.existingData,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _itemController = TextEditingController();
  final _amountController = TextEditingController();
  final _vendorController = TextEditingController();
  final _noteController = TextEditingController();
  String _mainCategory = '';
  String _subCategory = '';
  bool _saving = false;
  String _error = '';

  bool get _isEdit => widget.existingExpenseId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit && widget.existingData != null) {
      final d = widget.existingData!;
      _itemController.text = d['item'] ?? '';
      _amountController.text = (d['amount'] ?? '').toString();
      _vendorController.text = d['vendor'] ?? '';
      _noteController.text = d['note'] ?? '';
      _mainCategory = d['category'] ?? '';
      _subCategory = d['subCategory'] ?? '';
    }
  }

  @override
  void dispose() {
    _itemController.dispose();
    _amountController.dispose();
    _vendorController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _addExpense(List<Map<String, dynamic>> categories) async {
    if (_itemController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter expense item');
      return;
    }
    if (_amountController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter amount');
      return;
    }
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid amount');
      return;
    }
    if (_mainCategory.isEmpty) {
      setState(() => _error = 'Please select a category');
      return;
    }

    setState(() {
      _saving = true;
      _error = '';
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final catMap = categories.firstWhere(
          (c) => c['name'] == _mainCategory,
          orElse: () => {'name': _mainCategory, 'icon': '📦', 'subCategories': []});

      final payload = {
        'item': _itemController.text.trim(),
        'amount': amount,
        'category': _mainCategory,
        'categoryIcon': catMap['icon'] ?? '📦',
        'subCategory': _subCategory,
        'vendor': _vendorController.text.trim(),
        'note': _noteController.text.trim(),
      };

      if (_isEdit) {
        // Edit mode — update doc and adjust totalSpent by diff
        final oldAmount =
            (widget.existingData!['amount'] as num?)?.toDouble() ?? 0;
        final diff = amount - oldAmount;

        final expenseRef = firestore
            .collection('events')
            .doc(widget.eventId)
            .collection('expenses')
            .doc(widget.existingExpenseId);

        batch.update(expenseRef, payload);
        if (diff != 0) {
          batch.update(
            firestore.collection('events').doc(widget.eventId),
            {'totalSpent': FieldValue.increment(diff)},
          );
        }
      } else {
        // Add mode
        final expenseRef = firestore
            .collection('events')
            .doc(widget.eventId)
            .collection('expenses')
            .doc();

        batch.set(expenseRef, {
          ...payload,
          'addedAt': DateTime.now().toIso8601String(),
        });

        batch.update(
          firestore.collection('events').doc(widget.eventId),
          {'totalSpent': FieldValue.increment(amount)},
        );
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit
                ? 'Expense updated ✅'
                : '₹${amount.toStringAsFixed(0)} expense recorded ✅'),
            backgroundColor: Colors.red.shade400,
          ),
        );
        if (_isEdit) {
          Navigator.pop(context);
          return;
        }
        _itemController.clear();
        _amountController.clear();
        _vendorController.clear();
        _noteController.clear();
        setState(() {
          _mainCategory = '';
          _subCategory = '';
          _saving = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _saving = false;
        _error = 'Failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Expense' : 'Record Expense',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red.shade400,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('community_settings')
            .doc('address')
            .snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() as Map<String, dynamic>? ?? {};
          final rawCats = data['expenseCategories'];

          final List<Map<String, dynamic>> categories = rawCats != null
              ? List<Map<String, dynamic>>.from(
                  (rawCats as List).map((e) => Map<String, dynamic>.from(e)))
              : List<Map<String, dynamic>>.from(kDefaultCategories);

          // Auto-select first main category on load
          if (_mainCategory.isEmpty && categories.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => setState(() => _mainCategory = categories.first['name'] as String));
          }

          // Sub-categories for selected main category
          final selCat = categories.cast<Map<String, dynamic>?>()
              .firstWhere((c) => c!['name'] == _mainCategory, orElse: () => null);
          final subs = List<String>.from(
              selCat?['subCategories'] is List ? selCat!['subCategories'] as List : []);

          // Reset sub if current sub is not in new list
          if (_subCategory.isNotEmpty && !subs.contains(_subCategory)) {
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => setState(() => _subCategory = ''));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Expense item ─────────────────────────────────
                const Text('Expense Item *',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _itemController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _dec(
                      'e.g. Ganesh idol, flower garlands',
                      Icons.receipt_long_outlined),
                ),
                const SizedBox(height: 20),

                // ── Amount ────────────────────────────────────────
                const Text('Amount (₹) *',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '0',
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.red.shade400, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Main category ─────────────────────────────────
                Row(
                  children: [
                    const Text('Category *',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('Manage in Settings',
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 8),
                if (categories.isEmpty)
                  _warningBox(
                      'No categories configured. Go to Admin → Settings → Expense Categories.')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final name = cat['name'] as String;
                      final icon = cat['icon'] as String? ?? '📦';
                      final sel = _mainCategory == name;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _mainCategory = name;
                          _subCategory = '';
                        }),
                        child: _categoryChip(
                            '$icon $name', sel, Colors.red),
                      );
                    }).toList(),
                  ),

                // ── Sub-category (shown only when subs exist) ─────
                if (_mainCategory.isNotEmpty && subs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Sub-category',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Text('(Optional)',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: subs.map((sub) {
                      final sel = _subCategory == sub;
                      return GestureDetector(
                        onTap: () => setState(() =>
                            _subCategory = sel ? '' : sub),
                        child: _categoryChip(sub, sel, Colors.deepOrange),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 20),

                // ── Vendor ────────────────────────────────────────
                const Text('Vendor / Paid To (Optional)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _vendorController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _dec(
                      'e.g. Raju Flowers, Sharma Caterers',
                      Icons.store_outlined),
                ),
                const SizedBox(height: 20),

                // ── Note ─────────────────────────────────────────
                const Text('Note (Optional)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  decoration: _dec(
                      'e.g. Paid in advance, receipt attached',
                      Icons.note_outlined),
                ),

                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade600, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error,
                              style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed:
                        _saving ? null : () => _addExpense(categories),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
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
                    label: Text(_saving ? 'Saving...' : 'Record Expense'),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Form clears after save — add multiple expenses',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _categoryChip(String label, bool selected, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? color.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? color.shade300 : Colors.grey.shade200,
          width: selected ? 2 : 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected ? color.shade800 : Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _warningBox(String msg) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_outlined,
                color: Colors.orange.shade600, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 12))),
          ],
        ),
      );

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
      );
}
