import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

// Shared "save CSV to Downloads" helper — CSVs are meant to be opened directly
// in the Google Sheets app / uploaded via sheets.google.com (File > Import),
// so a plain file save (same pattern as the existing template downloads) is
// all that's needed; no share sheet required.
Future<void> _saveCsv(BuildContext context, String filename, String content) async {
  final bytes = Uint8List.fromList(content.codeUnits);
  try {
    final dir = Platform.isAndroid
        ? Directory('/storage/emulated/0/Download')
        : await getApplicationDocumentsDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Saved to Downloads/$filename — open it in the Google Sheets app or import at sheets.google.com'),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 5),
      ));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export failed: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }
}

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

DateTime? _parseIsoOrDdMmYyyy(String? s) {
  if (s == null || s.isEmpty) return null;
  try {
    return DateTime.parse(s);
  } catch (_) {}
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
  return null;
}

/// Exports every contribution for [eventId] as a CSV. The first 8 columns
/// match `import_contributions_screen.dart`'s expected column order exactly,
/// so a round trip (export → edit in Google Sheets → re-import) works;
/// trailing columns are read-only context for the user and ignored on import.
Future<void> exportContributionsCsv({
  required BuildContext context,
  required String eventId,
  required String eventName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final snap = await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .collection('contributions')
        .get();

    final rows = <List<dynamic>>[
      [
        'Flat Number', 'Resident Name', 'Amount', 'Payment Mode',
        'Paid Date (DD/MM/YYYY)', 'Contribution Type', 'Reference ID', 'Note',
        'Status', 'Anonymous', 'Wing', 'Block',
      ],
    ];

    for (final doc in snap.docs) {
      final d = doc.data();
      if (d['status'] == 'deleted') continue;
      final paidDateStr = d['paidDate'] as String? ?? '';
      final paidDate = paidDateStr.isNotEmpty
          ? paidDateStr
          : _fmtDate(_parseIsoOrDdMmYyyy(d['paidAt'] as String?) ?? DateTime.now());
      rows.add([
        d['flatNumber'] ?? '',
        d['residentName'] ?? '',
        (d['amount'] as num?) ?? 0,
        d['paymentMode'] ?? '',
        paidDate,
        d['contributionType'] ?? '',
        d['referenceId'] ?? '',
        d['note'] ?? '',
        d['amountReceived'] == true ? 'Received' : 'Pending',
        d['isAnonymous'] == true ? 'Yes' : 'No',
        d['wing'] ?? '',
        d['block'] ?? '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final safeName = eventName.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
    await _saveCsv(context, 'contributions_${safeName.isEmpty ? eventId : safeName}.csv', '$csv\n');
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red));
  }
}

/// Exports every expense for [eventId] as a CSV. The first 7 columns match
/// `import_expenses_screen.dart`'s expected column order exactly.
Future<void> exportExpensesCsv({
  required BuildContext context,
  required String eventId,
  required String eventName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final snap = await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .collection('expenses')
        .get();

    final rows = <List<dynamic>>[
      ['Item', 'Category', 'Sub-category', 'Vendor', 'Amount', 'Note', 'Date (DD/MM/YYYY)', 'Receipt URL'],
    ];

    for (final doc in snap.docs) {
      final d = doc.data();
      final date = _parseIsoOrDdMmYyyy(d['addedAt'] as String?) ?? DateTime.now();
      rows.add([
        d['item'] ?? '',
        d['category'] ?? '',
        d['subCategory'] ?? '',
        d['vendor'] ?? '',
        (d['amount'] as num?) ?? 0,
        d['note'] ?? '',
        _fmtDate(date),
        d['receiptUrl'] ?? '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final safeName = eventName.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
    await _saveCsv(context, 'expenses_${safeName.isEmpty ? eventId : safeName}.csv', '$csv\n');
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red));
  }
}
