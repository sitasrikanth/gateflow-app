import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

// ── Data model for a parsed row ───────────────────────────────────────────────

class _Row {
  final int lineNo;
  final String flatNumber;
  final String residentName;
  final double amount;
  final String paymentMode;
  final DateTime paidDate;
  final String contributionType;
  final String referenceId;
  final String note;
  final String? error;

  const _Row({
    required this.lineNo,
    required this.flatNumber,
    required this.residentName,
    required this.amount,
    required this.paymentMode,
    required this.paidDate,
    required this.contributionType,
    required this.referenceId,
    required this.note,
    this.error,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ImportContributionsScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const ImportContributionsScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<ImportContributionsScreen> createState() =>
      _ImportContributionsScreenState();
}

class _ImportContributionsScreenState
    extends State<ImportContributionsScreen> {
  // flat → {wing, block}
  Map<String, Map<String, String>> _flatLookup = {};
  bool _loadingSettings = true;

  List<_Row> _rows = [];
  bool _hasParsed = false;
  bool _importing = false;
  String? _fileName;

  @override
  void initState() {
    super.initState();
    _loadFlatLookup();
  }

  Future<void> _loadFlatLookup() async {
    final snap = await FirebaseFirestore.instance
        .collection('community_settings')
        .doc('address')
        .get();
    final raw = Map<String, dynamic>.from(
        (snap.data() ?? {})['wingBlocks'] ?? {});

    final Map<String, Map<String, String>> lookup = {};
    raw.forEach((wing, blocks) {
      if (blocks is Map) {
        blocks.forEach((block, flats) {
          if (flats is List) {
            for (final f in flats) {
              lookup[f.toString()] = {'wing': wing, 'block': block.toString()};
            }
          }
        });
      }
    });

    setState(() {
      _flatLookup = lookup;
      _loadingSettings = false;
    });
  }

  // ── Template CSV ─────────────────────────────────────────────────────────

  Future<void> _downloadTemplate() async {
    const header =
        'Flat Number,Resident Name,Amount,Payment Mode,Paid Date (DD/MM/YYYY),Contribution Type,Reference ID,Note';
    const samples = '''DA101,Ramesh Kumar,1500,Cash,15/10/2025,Regular,,
DA102,Suresh Sharma,1500,UPI,16/10/2025,Regular,UPI9876543210,
DA103,Priya Nair,1500,Bank Transfer,17/10/2025,Regular,TXN123456,Festival contribution''';

    final content = '$header\n$samples\n';
    final bytes = Uint8List.fromList(content.codeUnits);

    try {
      final dir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getApplicationDocumentsDirectory();
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}/contributions_template.csv');
      await file.writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Template saved to Downloads/contributions_template.csv'),
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
    final result = await FilePicker.platform.pickFiles(
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
      final content = String.fromCharCodes(bytes);
      rawRows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
          .convert(content);
    } else {
      // xlsx / xls
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables.values.first;
      rawRows = sheet.rows
          .map((r) => r.map((c) => c?.value?.toString() ?? '').toList())
          .toList();
    }

    setState(() {
      _fileName = file.name;
      _rows = _parseRows(rawRows);
      _hasParsed = true;
    });
  }

  List<_Row> _parseRows(List<List<dynamic>> rawRows) {
    if (rawRows.isEmpty) return [];

    // Skip header row (detect by checking if first cell looks like a header)
    int start = 0;
    final firstCell = rawRows[0].isNotEmpty
        ? rawRows[0][0].toString().toLowerCase().trim()
        : '';
    if (firstCell.contains('flat') || firstCell.contains('#')) start = 1;

    final rows = <_Row>[];
    for (int i = start; i < rawRows.length; i++) {
      final r = rawRows[i];
      if (r.isEmpty || r.every((c) => c.toString().trim().isEmpty)) continue;

      String cell(int idx) =>
          idx < r.length ? r[idx].toString().trim() : '';

      final flat = cell(0);
      final name = cell(1);
      final amtStr = cell(2).replaceAll(',', '').replaceAll('₹', '').replaceAll('Rs.', '').trim();
      final mode = cell(3).isEmpty ? 'Cash' : cell(3);
      final dateStr = cell(4);
      final type = cell(5).isEmpty ? 'Regular' : cell(5);
      final ref = cell(6);
      final note = cell(7);

      // Validate
      if (flat.isEmpty) {
        rows.add(_errorRow(i + 1, 'Flat Number is missing'));
        continue;
      }
      final amount = double.tryParse(amtStr);
      if (amount == null || amount <= 0) {
        rows.add(_errorRow(i + 1, 'Invalid amount "$amtStr" for flat $flat'));
        continue;
      }
      final date = _parseDate(dateStr);
      if (date == null) {
        rows.add(_errorRow(
            i + 1, 'Invalid date "$dateStr" — use DD/MM/YYYY for flat $flat'));
        continue;
      }

      rows.add(_Row(
        lineNo: i + 1,
        flatNumber: flat,
        residentName: name,
        amount: amount,
        paymentMode: mode,
        paidDate: date,
        contributionType: type,
        referenceId: ref,
        note: note,
        error: _flatLookup.containsKey(flat)
            ? null
            : null, // allow unknown flats with a warning
      ));
    }
    return rows;
  }

  _Row _errorRow(int lineNo, String msg) => _Row(
        lineNo: lineNo,
        flatNumber: '',
        residentName: '',
        amount: 0,
        paymentMode: '',
        paidDate: DateTime.now(),
        contributionType: '',
        referenceId: '',
        note: '',
        error: msg,
      );

  DateTime? _parseDate(String s) {
    if (s.isEmpty) return DateTime.now();
    // Try DD/MM/YYYY
    final parts = s.split(RegExp(r'[/\-.]'));
    if (parts.length == 3) {
      final d = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (d != null && m != null && y != null) {
        try {
          return DateTime(y < 100 ? 2000 + y : y, m, d);
        } catch (_) {}
      }
    }
    // Try ISO
    try {
      return DateTime.parse(s);
    } catch (_) {}
    return null;
  }

  // ── Import ────────────────────────────────────────────────────────────────

  Future<void> _import() async {
    final valid = _rows.where((r) => r.error == null).toList();
    if (valid.isEmpty) return;

    setState(() => _importing = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final eventRef = firestore.collection('events').doc(widget.eventId);
      double totalAdded = 0;

      var batch = firestore.batch();
      int count = 0;

      for (final row in valid) {
        final contribRef = eventRef.collection('contributions').doc();
        final info = _flatLookup[row.flatNumber] ?? {};
        final wing = info['wing'] ?? '';
        final block = info['block'] ?? '';
        final parts = [
          if (wing.isNotEmpty) '$wing Wing',
          if (block.isNotEmpty) 'Block $block',
          'Flat ${row.flatNumber}',
        ];

        batch.set(contribRef, {
          'flatNumber': row.flatNumber,
          'residentName': row.residentName,
          'wing': wing,
          'block': block,
          'fullAddress': parts.join(' - '),
          'amount': row.amount,
          'contributionType': row.contributionType,
          'amountReceived': true,
          'paymentMode': row.paymentMode,
          'referenceId': row.referenceId,
          'note': row.note,
          'paidAt': row.paidDate.toIso8601String(),
          'paidDate': _fmtDate(row.paidDate),
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

      // Increment totalCollected on event doc
      batch.update(eventRef,
          {'totalCollected': FieldValue.increment(totalAdded)});
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${valid.length} contributions imported  •  Rs.${_fmt(totalAdded)} added'),
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
    final validRows = _rows.where((r) => r.error == null).toList();
    final errorRows = _rows.where((r) => r.error != null).toList();
    final totalAmount = validRows.fold(0.0, (s, r) => s + r.amount);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Import Contributions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.eventName,
                style:
                    const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: _loadingSettings
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Step 1: Instructions ──────────────────────────────────
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
                      _columnHint('Flat Number', 'e.g. DA101', required: true),
                      _columnHint('Resident Name', 'e.g. Ramesh Kumar'),
                      _columnHint('Amount', 'e.g. 1500', required: true),
                      _columnHint('Payment Mode',
                          'Cash / UPI / Bank Transfer / Cheque'),
                      _columnHint('Paid Date',
                          'DD/MM/YYYY  e.g. 15/10/2025'),
                      _columnHint('Contribution Type',
                          'Regular / Carry Forward / Ganesh Laddu'),
                      _columnHint('Reference ID', 'UPI ref, cheque no., etc.'),
                      _columnHint('Note', 'Optional notes'),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _downloadTemplate,
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Download Template CSV'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.teal.shade700,
                            side:
                                BorderSide(color: Colors.teal.shade400),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Step 2: Pick file ─────────────────────────────────────
                _StepCard(
                  step: '2',
                  title: 'Pick your file',
                  child: Column(children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _pickAndParse,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: Text(_fileName == null
                            ? 'Pick CSV or Excel File'
                            : 'Change File'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    if (_fileName != null) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.insert_drive_file,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(_fileName!,
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12)),
                        ),
                      ]),
                    ],
                  ]),
                ),

                // ── Step 3: Preview ───────────────────────────────────────
                if (_hasParsed) ...[
                  const SizedBox(height: 12),
                  _StepCard(
                    step: '3',
                    title: 'Preview & Import',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _Chip('${validRows.length} valid',
                                Colors.green.shade700,
                                Colors.green.shade50),
                            if (errorRows.isNotEmpty)
                              _Chip('${errorRows.length} errors',
                                  Colors.red.shade700, Colors.red.shade50),
                            if (totalAmount > 0)
                              _Chip('Rs.${_fmt(totalAmount)} total',
                                  Colors.deepPurple.shade700,
                                  Colors.deepPurple.shade50),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Rows list
                        ..._rows.map((row) => _RowCard(
                              row: row,
                              knownFlat:
                                  _flatLookup.containsKey(row.flatNumber),
                              fmtDate: _fmtDate,
                            )),

                        const SizedBox(height: 12),

                        // Import button
                        if (validRows.isNotEmpty)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _importing ? null : _import,
                              icon: _importing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
                                  : const Icon(Icons.cloud_upload_rounded),
                              label: Text(_importing
                                  ? 'Importing…'
                                  : 'Import ${validRows.length} Contributions  •  Rs.${_fmt(totalAmount)}'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold),
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
  const _StepCard(
      {required this.step, required this.title, required this.child});

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
                backgroundColor: Colors.deepPurple,
                child: Text(step,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
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
  final bool knownFlat;
  final String Function(DateTime) fmtDate;

  const _RowCard(
      {required this.row,
      required this.knownFlat,
      required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    final isError = row.error != null;
    final isUnknownFlat = !isError && !knownFlat && row.flatNumber.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isError
            ? Colors.red.shade50
            : isUnknownFlat
                ? Colors.orange.shade50
                : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError
              ? Colors.red.shade200
              : isUnknownFlat
                  ? Colors.orange.shade200
                  : Colors.green.shade200,
        ),
      ),
      child: isError
          ? Row(children: [
              Icon(Icons.error_outline,
                  color: Colors.red.shade600, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Row ${row.lineNo}: ${row.error}',
                    style: TextStyle(
                        color: Colors.red.shade700, fontSize: 12)),
              ),
            ])
          : Row(children: [
              Icon(
                isUnknownFlat
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_rounded,
                color: isUnknownFlat
                    ? Colors.orange.shade700
                    : Colors.green.shade700,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(row.flatNumber,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      const SizedBox(width: 6),
                      if (row.residentName.isNotEmpty)
                        Expanded(
                          child: Text(row.residentName,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700),
                              overflow: TextOverflow.ellipsis),
                        ),
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      'Rs.${row.amount.toStringAsFixed(0)}  •  ${row.paymentMode}  •  ${fmtDate(row.paidDate)}  •  ${row.contributionType}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                    if (isUnknownFlat)
                      Text('Flat ${row.flatNumber} not in community settings — will still import',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange.shade700)),
                  ],
                ),
              ),
              Text('Rs.${row.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

Widget _columnHint(String name, String hint, {bool required = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.arrow_right, size: 16, color: Colors.deepPurple.shade300),
        const SizedBox(width: 2),
        Text(name,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 12)),
        if (required)
          Text(' *',
              style: TextStyle(color: Colors.red.shade600, fontSize: 12)),
        const SizedBox(width: 4),
        Expanded(
          child: Text('— $hint',
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ),
      ],
    ),
  );
}
