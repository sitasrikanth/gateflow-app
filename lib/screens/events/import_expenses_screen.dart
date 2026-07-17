import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/app_theme.dart';

// ── Data model for a parsed row ───────────────────────────────────────────────

class _Row {
  final int lineNo;
  final String item;
  final String category;
  final String subCategory;
  final String vendor;
  final double amount;
  final String note;
  final DateTime date;
  final String? error;
  final bool isDuplicate;

  const _Row({
    required this.lineNo,
    required this.item,
    required this.category,
    required this.subCategory,
    required this.vendor,
    required this.amount,
    required this.note,
    required this.date,
    this.error,
    this.isDuplicate = false,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ImportExpensesScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const ImportExpensesScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<ImportExpensesScreen> createState() => _ImportExpensesScreenState();
}

class _ImportExpensesScreenState extends State<ImportExpensesScreen> {
  List<_Row> _rows = [];
  bool _hasParsed = false;
  bool _importing = false;
  bool _checkingDuplicates = false;
  String? _fileName;

  // ── Duplicate detection ─────────────────────────────────────────────────
  // Builds an "item|amount|date" signature for every existing expense on
  // this event, so re-importing the same file (or overlapping rows) can be
  // caught and skipped instead of silently creating duplicates and
  // double-counting totalSpent.

  String _signature(String item, double amount, DateTime date) =>
      '${item.trim().toLowerCase()}|${amount.toStringAsFixed(2)}|${_fmtDate(date)}';

  Future<Set<String>> _loadExistingSignatures() async {
    final snap = await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('expenses')
        .get();

    final signatures = <String>{};
    for (final doc in snap.docs) {
      final d = doc.data();
      final item = (d['item'] as String? ?? '');
      final amount = (d['amount'] as num?)?.toDouble();
      final date = DateTime.tryParse(d['addedAt'] as String? ?? '');
      if (item.isEmpty || amount == null || date == null) continue;
      signatures.add(_signature(item, amount, date));
    }
    return signatures;
  }

  // ── Template CSV ─────────────────────────────────────────────────────────

  Future<void> _downloadTemplate() async {
    const header = 'Item,Category,Sub-category,Vendor,Amount,Note,Date (DD/MM/YYYY)';
    const samples = '''Flower Decoration,Decoration,Flowers & Garlands,Green Leaf Florist,3500,,15/10/2025
Catering Service,Food & Catering,Catering Service,Annapurna Caterers,25000,Lunch for 200 people,16/10/2025''';

    final content = '$header\n$samples\n';
    final bytes = Uint8List.fromList(content.codeUnits);

    try {
      final dir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getApplicationDocumentsDirectory();
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}/expenses_template.csv');
      await file.writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Template saved to Downloads/expenses_template.csv'),
          backgroundColor: Colors.teal,
          duration: Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save template: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ── File picking + parsing ────────────────────────────────────────────────

  Future<void> _pickAndParse() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    final ext = (file.extension ?? '').toLowerCase();
    List<List<dynamic>> rawRows;

    if (ext == 'csv') {
      var content = utf8.decode(bytes, allowMalformed: true);
      if (content.isNotEmpty && content.codeUnitAt(0) == 0xFEFF) {
        content = content.substring(1);
      }
      rawRows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
          .convert(content);
    } else {
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables.values.first;
      rawRows = sheet.rows
          .map((r) => r.map((c) => c?.value?.toString() ?? '').toList())
          .toList();
    }

    setState(() => _checkingDuplicates = true);
    final existingSignatures = await _loadExistingSignatures();

    setState(() {
      _fileName = file.name;
      _rows = _parseRows(rawRows, existingSignatures);
      _hasParsed = true;
      _checkingDuplicates = false;
    });
  }

  List<_Row> _parseRows(
      List<List<dynamic>> rawRows, Set<String> existingSignatures) {
    if (rawRows.isEmpty) return [];

    int start = 0;
    final firstCell = rawRows[0].isNotEmpty
        ? rawRows[0][0].toString().toLowerCase().trim()
        : '';
    if (firstCell.contains('item') || firstCell.contains('#')) start = 1;

    final rows = <_Row>[];
    for (int i = start; i < rawRows.length; i++) {
      final r = rawRows[i];
      if (r.isEmpty || r.every((c) => c.toString().trim().isEmpty)) continue;

      String cell(int idx) => idx < r.length ? r[idx].toString().trim() : '';

      final item = cell(0);
      final category = cell(1);
      final subCategory = cell(2);
      final vendor = cell(3);
      final amtStr = cell(4).replaceAll(',', '').replaceAll('₹', '').replaceAll('Rs.', '').trim();
      final note = cell(5);
      final dateStr = cell(6);

      if (item.isEmpty) {
        rows.add(_errorRow(i + 1, 'Item is missing'));
        continue;
      }
      if (category.isEmpty) {
        rows.add(_errorRow(i + 1, 'Category is missing for "$item"'));
        continue;
      }
      final amount = double.tryParse(amtStr);
      if (amount == null || amount <= 0) {
        rows.add(_errorRow(i + 1, 'Invalid amount "$amtStr" for "$item"'));
        continue;
      }
      if (dateStr.isEmpty) {
        rows.add(_errorRow(i + 1, 'Date is missing for "$item" — use DD/MM/YYYY'));
        continue;
      }
      final date = _parseDate(dateStr);
      if (date == null) {
        rows.add(_errorRow(i + 1, 'Invalid date "$dateStr" — use DD/MM/YYYY for "$item"'));
        continue;
      }

      rows.add(_Row(
        lineNo: i + 1,
        item: item,
        category: category,
        subCategory: subCategory,
        vendor: vendor,
        amount: amount,
        note: note,
        date: date,
        isDuplicate: existingSignatures.contains(_signature(item, amount, date)),
      ));
    }
    return rows;
  }

  _Row _errorRow(int lineNo, String msg) => _Row(
        lineNo: lineNo,
        item: '',
        category: '',
        subCategory: '',
        vendor: '',
        amount: 0,
        note: '',
        date: DateTime.now(),
        error: msg,
      );

  DateTime? _parseDate(String s) {
    // Google Sheets/Excel often export dates as ISO (YYYY-MM-DD), which uses
    // the same '-' delimiter as DD-MM-YYYY — disambiguate by checking whether
    // the first segment is a 4-digit year.
    final parts = s.split(RegExp(r'[/\-.]'));
    if (parts.length == 3) {
      final p0 = int.tryParse(parts[0]);
      final p1 = int.tryParse(parts[1]);
      final p2 = int.tryParse(parts[2]);
      if (p0 != null && p1 != null && p2 != null) {
        try {
          if (parts[0].length == 4) {
            return DateTime(p0, p1, p2); // YYYY-MM-DD
          }
          return DateTime(p2 < 100 ? 2000 + p2 : p2, p1, p0); // DD/MM/YYYY
        } catch (_) {}
      }
    }
    try {
      return DateTime.parse(s);
    } catch (_) {}
    return null;
  }

  // ── Import ────────────────────────────────────────────────────────────────

  Future<void> _import() async {
    final valid =
        _rows.where((r) => r.error == null && !r.isDuplicate).toList();
    if (valid.isEmpty) return;

    setState(() => _importing = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final eventRef = firestore.collection('events').doc(widget.eventId);
      double totalAdded = 0;

      var batch = firestore.batch();
      int count = 0;

      for (final row in valid) {
        final expenseRef = eventRef.collection('expenses').doc();

        batch.set(expenseRef, {
          'item': row.item,
          'category': row.category,
          'categoryIcon': '📦',
          'subCategory': row.subCategory,
          'vendor': row.vendor,
          'amount': row.amount,
          'note': row.note,
          'addedAt': row.date.toIso8601String(),
          'importedAt': DateTime.now().toIso8601String(),
        });

        totalAdded += row.amount;
        count++;

        if (count == 499) {
          await batch.commit();
          batch = firestore.batch();
          count = 0;
        }
      }

      batch.update(eventRef, {'totalSpent': FieldValue.increment(totalAdded)});
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${valid.length} expenses imported  •  Rs.${_fmt(totalAdded)} added'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 4),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: Colors.red,
        ));
        setState(() => _importing = false);
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final okRows = _rows.where((r) => r.error == null).toList();
    final duplicateRows = okRows.where((r) => r.isDuplicate).toList();
    final validRows = okRows.where((r) => !r.isDuplicate).toList();
    final errorRows = _rows.where((r) => r.error != null).toList();
    final totalAmount = validRows.fold(0.0, (s, r) => s + r.amount);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Import Expenses',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.eventName,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StepCard(
            step: '1',
            title: 'Prepare your file',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your CSV / Excel file must have these columns in order:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                _columnHint('Item', 'e.g. Flower Decoration', required: true),
                _columnHint('Category', 'e.g. Decoration', required: true),
                _columnHint('Sub-category', 'e.g. Flowers & Garlands'),
                _columnHint('Vendor', 'e.g. Green Leaf Florist'),
                _columnHint('Amount', 'e.g. 3500', required: true),
                _columnHint('Note', 'Optional notes'),
                _columnHint('Date', 'DD/MM/YYYY  e.g. 15/10/2025', required: true),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _downloadTemplate,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Download Template CSV'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal.shade700,
                      side: BorderSide(color: Colors.teal.shade400),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _StepCard(
            step: '2',
            title: 'Pick your file',
            child: Column(children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _checkingDuplicates ? null : _pickAndParse,
                  icon: _checkingDuplicates
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.upload_file_rounded),
                  label: Text(_checkingDuplicates
                      ? 'Checking for duplicates…'
                      : _fileName == null
                          ? 'Pick CSV or Excel File'
                          : 'Change File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (_fileName != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.insert_drive_file, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(_fileName!,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ),
                ]),
              ],
            ]),
          ),
          if (_hasParsed) ...[
            const SizedBox(height: 12),
            _StepCard(
              step: '3',
              title: 'Preview & Import',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    _Chip('${validRows.length} valid', Colors.green.shade700, Colors.green.shade50),
                    if (duplicateRows.isNotEmpty)
                      _Chip('${duplicateRows.length} duplicates (skipped)',
                          Colors.blueGrey.shade700, Colors.blueGrey.shade50),
                    if (errorRows.isNotEmpty)
                      _Chip('${errorRows.length} errors', Colors.red.shade700, Colors.red.shade50),
                    if (totalAmount > 0)
                      _Chip('Rs.${_fmt(totalAmount)} total', AppTheme.accent.shade700, AppTheme.accent.shade50),
                  ]),
                  const SizedBox(height: 12),
                  ..._rows.map((row) => _RowCard(row: row, fmtDate: _fmtDate)),
                  const SizedBox(height: 12),
                  if (validRows.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _importing ? null : _import,
                        icon: _importing
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.cloud_upload_rounded),
                        label: Text(_importing
                            ? 'Importing…'
                            : 'Import ${validRows.length} Expenses  •  Rs.${_fmt(totalAmount)}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final String step;
  final String title;
  final Widget child;
  const _StepCard({required this.step, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: AppTheme.accent,
                child: Text(step,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  final _Row row;
  final String Function(DateTime) fmtDate;

  const _RowCard({required this.row, required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    final isError = row.error != null;
    final isDuplicate = !isError && row.isDuplicate;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isError
            ? Colors.red.shade50
            : isDuplicate
                ? Colors.blueGrey.shade50
                : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError
              ? Colors.red.shade200
              : isDuplicate
                  ? Colors.blueGrey.shade200
                  : Colors.green.shade200,
        ),
      ),
      child: isError
          ? Row(children: [
              Icon(Icons.error_outline, color: Colors.red.shade600, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Row ${row.lineNo}: ${row.error}',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
              ),
            ])
          : Row(children: [
              Icon(
                isDuplicate ? Icons.content_copy_rounded : Icons.check_circle_rounded,
                color: isDuplicate ? Colors.blueGrey.shade600 : Colors.green.shade700,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.item, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                      '${row.category}${row.subCategory.isNotEmpty ? ' • ${row.subCategory}' : ''}  •  ${fmtDate(row.date)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    if (isDuplicate)
                      Text('Same item/amount/date already exists — skipping',
                          style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade600)),
                  ],
                ),
              ),
              Text('Rs.${row.amount.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  const _Chip(this.label, this.fg, this.bg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

Widget _columnHint(String name, String hint, {bool required = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.arrow_right, size: 16, color: AppTheme.accent.shade300),
        const SizedBox(width: 2),
        Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        if (required)
          Text(' *', style: TextStyle(color: Colors.red.shade600, fontSize: 12)),
        const SizedBox(width: 4),
        Expanded(
          child: Text('— $hint', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ),
      ],
    ),
  );
}
