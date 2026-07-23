import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> kDefaultTempleExpenseCategories = [
  'Pooja Materials', 'Priest Honorarium', 'Maintenance', 'Utilities', 'Festival', 'Other',
];

class AddTempleExpenseScreen extends StatefulWidget {
  final String? existingDocId;
  final Map<String, dynamic>? existingData;
  const AddTempleExpenseScreen({super.key, this.existingDocId, this.existingData});

  @override
  State<AddTempleExpenseScreen> createState() => _AddTempleExpenseScreenState();
}

class _AddTempleExpenseScreenState extends State<AddTempleExpenseScreen> {
  final _vendorCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _category = kDefaultTempleExpenseCategories.first;
  DateTime _date = DateTime.now();
  List<String> _categories = kDefaultTempleExpenseCategories;
  bool _saving = false;
  String _error = '';

  bool get _isEditing => widget.existingDocId != null;

  @override
  void initState() {
    super.initState();
    final d = widget.existingData;
    if (d != null) {
      _vendorCtrl.text = d['vendor'] as String? ?? '';
      _amountCtrl.text = ((d['amount'] as num?) ?? 0).toStringAsFixed(0);
      _noteCtrl.text = d['note'] as String? ?? '';
      _category = d['category'] as String? ?? kDefaultTempleExpenseCategories.first;
      final date = DateTime.tryParse(d['date'] as String? ?? '');
      if (date != null) _date = date;
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final snap = await FirebaseFirestore.instance
        .collection('appSettings')
        .doc('templeDonationConfig')
        .get();
    if (!mounted) return;
    final cats = snap.data()?['expenseCategories'] as List?;
    setState(() {
      _categories = cats != null && cats.isNotEmpty
          ? List<String>.from(cats)
          : kDefaultTempleExpenseCategories;
      if (!_categories.contains(_category)) _category = _categories.first;
    });
  }

  @override
  void dispose() {
    _vendorCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid amount');
      return;
    }
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      final payload = {
        'category': _category,
        'vendor': _vendorCtrl.text.trim(),
        'amount': amount,
        'note': _noteCtrl.text.trim(),
        'date': _date.toIso8601String(),
      };
      final col = FirebaseFirestore.instance.collection('templeExpenses');
      if (_isEditing) {
        await col.doc(widget.existingDocId).update(payload);
      } else {
        payload['createdAt'] = DateTime.now().toIso8601String();
        await col.add(payload);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing ? 'Expense updated ✅' : '₹${amount.toStringAsFixed(0)} recorded ✅'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Temple Expense' : 'Add Temple Expense'),
        backgroundColor: Colors.deepOrange.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Category *', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _categories.contains(_category) ? _category : _categories.first,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: Theme.of(context).cardColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v ?? _categories.first),
            ),
            const SizedBox(height: 16),
            const Text('Vendor (Optional)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _vendorCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. Local Flower Shop',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Amount (₹) *', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'e.g. 2000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.calendar_today_outlined, color: Colors.deepOrange.shade700),
              title: Text('${_date.day}/${_date.month}/${_date.year}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Tap to change date'),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 8),
            const Text('Note (Optional)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_error, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isEditing ? 'Save Changes' : 'Record Expense',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
