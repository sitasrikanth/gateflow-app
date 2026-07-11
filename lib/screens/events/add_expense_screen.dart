import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'expense_categories_screen.dart'
    show kDefaultCategories, expenseCategoriesRef, eventTypeCategoriesRef;

class AddExpenseScreen extends StatefulWidget {
  final String eventId;
  final String eventTypeId;
  final String? existingExpenseId;
  final Map<String, dynamic>? existingData;
  const AddExpenseScreen({
    super.key,
    required this.eventId,
    this.eventTypeId = '',
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

  DocumentReference get _catRef => widget.eventTypeId.isNotEmpty
      ? eventTypeCategoriesRef(widget.eventTypeId)
      : expenseCategoriesRef;
  String _subCategory = '';
  File? _receiptFile;
  String? _existingReceiptUrl;
  bool _removeExistingReceipt = false;
  bool _saving = false;
  bool _deleting = false;
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
      _existingReceiptUrl = d['receiptUrl'] as String?;
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

  Future<void> _pickReceipt(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
        source: source, imageQuality: 80, maxWidth: 1600);
    if (picked == null || !mounted) return;
    setState(() => _receiptFile = File(picked.path));
  }

  Future<void> _deleteExpense() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text(
            'Delete "${_itemController.text.trim()}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final oldAmount =
          (widget.existingData!['amount'] as num?)?.toDouble() ?? 0;
      final batch = firestore.batch();

      batch.delete(firestore
          .collection('events')
          .doc(widget.eventId)
          .collection('expenses')
          .doc(widget.existingExpenseId));

      if (oldAmount > 0) {
        batch.update(
          firestore.collection('events').doc(widget.eventId),
          {'totalSpent': FieldValue.increment(-oldAmount)},
        );
      }

      await batch.commit();

      // Delete receipt from Storage if one exists
      final url = widget.existingData!['receiptUrl'] as String?;
      if (url != null && url.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(url).delete();
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted'), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() {
        _deleting = false;
        _error = 'Delete failed: $e';
      });
    }
  }

  Future<void> _showAddCategoryDialog(
      List<Map<String, dynamic>> currentCategories) async {
    final nameCtrl = TextEditingController();
    String icon = '📦';
    const commonIcons = [
      '📦', '🎉', '🍽️', '🎨', '🔧', '💡', '🎵', '🌸', '🪔', '🛒',
      '📸', '🚗', '💐', '🍬', '🧹', '🎪', '📢', '💌', '🏮', '✨',
    ];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('New Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Category Name *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                const Text('Icon',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: commonIcons.map((e) {
                    final sel = icon == e;
                    return GestureDetector(
                      onTap: () => setS(() => icon = e),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: sel ? Colors.red.shade50 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: sel ? Colors.red.shade300 : Colors.grey.shade200,
                              width: sel ? 2 : 1),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 20)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx, {'name': name, 'icon': icon});
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  foregroundColor: Colors.white),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    if (result == null || !mounted) return;

    final name = result['name'] as String;
    final newCat = {'name': name, 'icon': result['icon'], 'subCategories': []};
    final updated = [...currentCategories, newCat];
    try {
      await _catRef.set(
          {'expenseCategories': updated}, SetOptions(merge: true));
      if (mounted) setState(() => _mainCategory = name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save category: $e')),
        );
      }
    }
  }

  Future<void> _showAddSubCategoryDialog(
      List<Map<String, dynamic>> categories) async {
    final nameCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New Sub-category under $_mainCategory'),
        content: TextField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
              labelText: 'Sub-category Name *', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx, name);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    if (result == null || !mounted) return;

    final updated = categories.map((cat) {
      if (cat['name'] == _mainCategory) {
        final subs = List<String>.from(cat['subCategories'] as List? ?? []);
        if (!subs.contains(result)) subs.add(result);
        return {...cat, 'subCategories': subs};
      }
      return cat;
    }).toList();
    try {
      await _catRef.set(
          {'expenseCategories': updated}, SetOptions(merge: true));
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) { if (mounted) setState(() => _subCategory = result); });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save sub-category: $e')),
        );
      }
    }
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

      // Pre-create the expense doc reference so we have a stable ID for Storage
      final expenseRef = _isEdit
          ? firestore
              .collection('events')
              .doc(widget.eventId)
              .collection('expenses')
              .doc(widget.existingExpenseId)
          : firestore
              .collection('events')
              .doc(widget.eventId)
              .collection('expenses')
              .doc();

      final catMap = categories.firstWhere(
          (c) => c['name'] == _mainCategory,
          orElse: () => {'name': _mainCategory, 'icon': '📦', 'subCategories': []});

      // Upload receipt if a new file was picked
      String? receiptUrl;
      if (_receiptFile != null) {
        final ref = FirebaseStorage.instance
            .ref('expenses/${widget.eventId}/${expenseRef.id}/receipt.jpg');
        await ref.putFile(_receiptFile!);
        receiptUrl = await ref.getDownloadURL();
        // Delete old receipt if replacing in edit mode
        if (_isEdit) {
          final oldUrl = widget.existingData!['receiptUrl'] as String?;
          if (oldUrl != null && oldUrl.isNotEmpty) {
            try { await FirebaseStorage.instance.refFromURL(oldUrl).delete(); } catch (_) {}
          }
        }
      } else if (_isEdit && _removeExistingReceipt) {
        final oldUrl = widget.existingData!['receiptUrl'] as String?;
        if (oldUrl != null && oldUrl.isNotEmpty) {
          try { await FirebaseStorage.instance.refFromURL(oldUrl).delete(); } catch (_) {}
        }
      }

      final payload = <String, dynamic>{
        'item': _itemController.text.trim(),
        'amount': amount,
        'category': _mainCategory,
        'categoryIcon': catMap['icon'] ?? '📦',
        'subCategory': _subCategory,
        'vendor': _vendorController.text.trim(),
        'note': _noteController.text.trim(),
        if (receiptUrl != null) 'receiptUrl': receiptUrl,
        if (_isEdit && _removeExistingReceipt && receiptUrl == null)
          'receiptUrl': FieldValue.delete(),
      };

      if (_isEdit) {
        final oldAmount =
            (widget.existingData!['amount'] as num?)?.toDouble() ?? 0;
        final diff = amount - oldAmount;

        batch.update(expenseRef, payload);
        if (diff != 0) {
          batch.update(
            firestore.collection('events').doc(widget.eventId),
            {'totalSpent': FieldValue.increment(diff)},
          );
        }
      } else {
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Expense' : 'Record Expense',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red.shade400,
        foregroundColor: Colors.white,
        actions: _isEdit
            ? [
                IconButton(
                  icon: _deleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.delete_outline),
                  tooltip: 'Delete expense',
                  onPressed: _deleting ? null : _deleteExpense,
                ),
              ]
            : null,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _catRef.snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() as Map<String, dynamic>? ?? {};
          final rawCats = data['expenseCategories'];

          final List<Map<String, dynamic>> categories = rawCats != null
              ? List<Map<String, dynamic>>.from(
                  (rawCats as List).map((e) => Map<String, dynamic>.from(e)))
              : List<Map<String, dynamic>>.from(kDefaultCategories);

          // Auto-select first main category on load
          if (_mainCategory.isEmpty && categories.isNotEmpty) {
            final firstName = categories.first['name'] as String;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _mainCategory.isEmpty) {
                setState(() => _mainCategory = firstName);
              }
            });
          }

          // Sub-categories for selected main category
          final selCat = categories.cast<Map<String, dynamic>?>()
              .firstWhere((c) => c!['name'] == _mainCategory, orElse: () => null);
          final subs = List<String>.from(
              selCat?['subCategories'] is List ? selCat!['subCategories'] as List : []);

          // Reset sub only if the sub truly disappeared (not during dialog open)
          if (_subCategory.isNotEmpty && !subs.contains(_subCategory)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _subCategory.isNotEmpty && !subs.contains(_subCategory)) {
                setState(() => _subCategory = '');
              }
            });
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
                const Text('Category *',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...categories.map((cat) {
                      final name = cat['name'] as String;
                      final icon = cat['icon'] as String? ?? '📦';
                      final sel = _mainCategory == name;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _mainCategory = name;
                          _subCategory = '';
                        }),
                        child: _categoryChip('$icon $name', sel, Colors.red),
                      );
                    }),
                    GestureDetector(
                      onTap: () => _showAddCategoryDialog(categories),
                      child: _addChip(),
                    ),
                  ],
                ),

                // ── Sub-category ─────────────────────────────────
                if (_mainCategory.isNotEmpty) ...[
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
                    children: [
                      ...subs.map((sub) {
                        final sel = _subCategory == sub;
                        return GestureDetector(
                          onTap: () => setState(() =>
                              _subCategory = sel ? '' : sub),
                          child: _categoryChip(sub, sel, Colors.deepOrange),
                        );
                      }),
                      GestureDetector(
                        onTap: () => _showAddSubCategoryDialog(categories),
                        child: _addChip(color: Colors.deepOrange),
                      ),
                    ],
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

                const SizedBox(height: 20),

                // ── Receipt attachment ───────────────────────────
                const Text('Receipt / Bill Photo (Optional)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (_receiptFile != null) ...[
                  // Preview newly picked image
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_receiptFile!,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () => setState(() => _receiptFile = null),
                          child: Container(
                            decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (_existingReceiptUrl != null &&
                    !_removeExistingReceipt) ...[
                  // Show existing receipt with option to view/remove
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: () => _showReceiptFullScreen(
                            context, _existingReceiptUrl!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            _existingReceiptUrl!,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, prog) => prog == null
                                ? child
                                : Container(
                                    height: 160,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: const CircularProgressIndicator()),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => _showPickOptions(),
                              child: Container(
                                decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(Icons.edit,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => setState(
                                  () => _removeExistingReceipt = true),
                              child: Container(
                                decoration: BoxDecoration(
                                    color: Colors.red.shade700,
                                    borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(Icons.delete_outline,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // No receipt yet — pick buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _pickReceipt(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Camera'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade600,
                            side: BorderSide(color: Colors.red.shade200),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _pickReceipt(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Gallery'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade600,
                            side: BorderSide(color: Colors.red.shade200),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

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
                    label: Text(_saving
                        ? 'Saving...'
                        : _isEdit
                            ? 'Update Expense'
                            : 'Record Expense'),
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

  void _showPickOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickReceipt(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickReceipt(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiptFullScreen(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Receipt'),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
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

  Widget _addChip({MaterialColor? color}) {
    final c = color ?? Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.shade300, width: 1.5),
      ),
      child: Text(
        '+ New',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: c.shade600,
        ),
      ),
    );
  }

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
