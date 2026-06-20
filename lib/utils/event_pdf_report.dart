import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<void> _showSaveDialog(
  BuildContext context,
  Uint8List bytes,
  String filename,
  ScaffoldMessengerState messenger,
) async {
  await showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(filename,
                style: const TextStyle(
                    fontSize: 13, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.download_rounded,
                    color: Colors.green.shade700),
              ),
              title: const Text('Save to Downloads',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Save PDF directly to your Downloads folder'),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final dir = Platform.isAndroid
                      ? Directory('/storage/emulated/0/Download')
                      : await getApplicationDocumentsDirectory();
                  if (!await dir.exists()) await dir.create(recursive: true);
                  final file = File('${dir.path}/$filename');
                  await file.writeAsBytes(bytes);
                  messenger.showSnackBar(SnackBar(
                    content: Text('Saved to Downloads/$filename'),
                    backgroundColor: Colors.green.shade700,
                    duration: const Duration(seconds: 4),
                  ));
                } catch (e) {
                  messenger.showSnackBar(SnackBar(
                    content: Text('Save failed: $e'),
                    backgroundColor: Colors.red,
                  ));
                }
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.share_rounded,
                    color: Colors.deepPurple.shade700),
              ),
              title: const Text('Share / Open with…',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle:
                  const Text('Share via WhatsApp, email, Drive, etc.'),
              onTap: () async {
                Navigator.pop(ctx);
                await Printing.sharePdf(bytes: bytes, filename: filename);
              },
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    ),
  );
}

const _kPurple = PdfColor(0.416, 0.106, 0.604);
const _kPurpleLight = PdfColor(0.953, 0.898, 0.965);
const _kGreen = PdfColor(0.180, 0.490, 0.196);
const _kRed = PdfColor(0.773, 0.157, 0.157);
const _kBlue = PdfColor(0.086, 0.396, 0.753);
const _kGrey100 = PdfColor(0.961, 0.961, 0.961);

Future<void> exportEventPdfReport({
  required BuildContext context,
  required String eventId,
  required Map<String, dynamic> eventData,
  required double collected,
  required double spent,
  required double balance,
  required double target,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(
    content: Text('Generating PDF report...'),
    duration: Duration(seconds: 60),
    backgroundColor: Colors.deepPurple,
  ));

  try {
    final results = await Future.wait([
      FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('contributions')
          .get(),
      FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('expenses')
          .get(),
      FirebaseFirestore.instance
          .collection('community_settings')
          .doc('address')
          .get(),
      PdfGoogleFonts.notoSansRegular(),
      PdfGoogleFonts.notoSansBold(),
    ]);

    final contribs = (results[0] as QuerySnapshot)
        .docs
        .map((d) => d.data() as Map<String, dynamic>)
        .toList()
      ..sort((a, b) =>
          (a['paidAt'] ?? '').toString().compareTo((b['paidAt'] ?? '').toString()));

    final expenses = (results[1] as QuerySnapshot)
        .docs
        .map((d) => d.data() as Map<String, dynamic>)
        .toList()
      ..sort((a, b) =>
          (a['addedAt'] ?? '').toString().compareTo((b['addedAt'] ?? '').toString()));

    // Build wing → block → flats structure from community settings
    final settingsData =
        (results[2] as DocumentSnapshot).data() as Map<String, dynamic>? ?? {};
    final rawWingBlocks =
        Map<String, dynamic>.from(settingsData['wingBlocks'] ?? {});
    final Map<String, Map<String, List<String>>> structure = {};
    for (final wing in rawWingBlocks.keys.toList()..sort()) {
      final raw = rawWingBlocks[wing];
      structure[wing] = {};
      if (raw is Map) {
        for (final block in (raw.keys.toList()..sort())) {
          structure[wing]![block] = raw[block] is List
              ? (List<String>.from(raw[block] as List)..sort())
              : <String>[];
        }
      }
    }

    // flat → 'paid' | 'pending' status and total collected amount
    final Map<String, String> flatStatus = {};
    final Map<String, double> flatAmount = {};
    for (final c in contribs) {
      final flat = (c['flatNumber'] as String?)?.trim() ?? '';
      if (flat.isEmpty) continue;
      final received = (c['amountReceived'] as bool?) ?? true;
      final amt = (c['amount'] as num?)?.toDouble() ?? 0.0;
      if (received) flatAmount[flat] = (flatAmount[flat] ?? 0) + amt;
      if (flatStatus[flat] == 'paid') continue;
      flatStatus[flat] = received ? 'paid' : 'pending';
    }

    final font = results[3] as pw.Font;
    final fontBold = results[4] as pw.Font;

    final eventName = (eventData['name'] as String?) ?? 'Event';
    final status = (eventData['status'] as String?) ?? 'active';
    final startDate = (eventData['startDate'] as String?) ?? '';
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (ctx) => _buildHeader(eventName, dateStr),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          _buildSummary(
            status: status,
            startDate: startDate,
            target: target,
            collected: collected,
            spent: spent,
            balance: balance,
            contribCount: contribs.length,
            expenseCount: expenses.length,
          ),
          pw.SizedBox(height: 20),
          _buildContributionsByWing(structure, flatStatus, flatAmount),
          pw.SizedBox(height: 20),
          _buildExpenses(expenses),
        ],
      ),
    );

    final bytes = Uint8List.fromList(await doc.save());
    final filename =
        '${eventName.replaceAll(RegExp(r'[^\w\s]'), '').trim().replaceAll(' ', '_')}_Report.pdf';

    messenger.hideCurrentSnackBar();

    if (context.mounted) {
      await _showSaveDialog(context, bytes, filename, messenger);
    }
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text('PDF generation failed: $e'),
      backgroundColor: Colors.red,
    ));
  }
}

pw.Widget _buildHeader(String eventName, String dateStr) {
  return pw.Column(children: [
    pw.Container(
      color: _kPurple,
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('GateFlow',
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold)),
              pw.Text('Event Financial Report',
                  style: const pw.TextStyle(
                      color: PdfColors.grey, fontSize: 9)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(eventName,
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold)),
              pw.Text('Generated: $dateStr',
                  style: const pw.TextStyle(
                      color: PdfColors.grey, fontSize: 9)),
            ],
          ),
        ],
      ),
    ),
    pw.SizedBox(height: 12),
  ]);
}

pw.Widget _buildFooter(pw.Context ctx) {
  return pw.Column(children: [
    pw.Divider(color: PdfColors.grey300),
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('GateFlow — Confidential',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      ],
    ),
  ]);
}

pw.Widget _buildSummary({
  required String status,
  required String startDate,
  required double target,
  required double collected,
  required double spent,
  required double balance,
  required int contribCount,
  required int expenseCount,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(14),
    decoration: const pw.BoxDecoration(
      color: _kPurpleLight,
      borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Event Summary',
            style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: _kPurple)),
        pw.SizedBox(height: 10),
        pw.Row(children: [
          _summaryBox('Status', status == 'active' ? 'Active' : 'Closed'),
          pw.SizedBox(width: 8),
          _summaryBox('Start Date', startDate.isNotEmpty ? startDate : '-'),
          pw.SizedBox(width: 8),
          _summaryBox('Contributions', '$contribCount'),
          pw.SizedBox(width: 8),
          _summaryBox('Expenses', '$expenseCount'),
        ]),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          if (target > 0) ...[
            _summaryBox('Target', 'Rs.${_fmt(target)}'),
            pw.SizedBox(width: 8),
            _summaryBox(
                'Progress',
                '${((collected / target).clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%'),
            pw.SizedBox(width: 8),
          ],
          _summaryBox('Collected', 'Rs.${_fmt(collected)}',
              textColor: _kGreen),
          pw.SizedBox(width: 8),
          _summaryBox('Spent', 'Rs.${_fmt(spent)}', textColor: _kRed),
          pw.SizedBox(width: 8),
          _summaryBox('Balance', 'Rs.${_fmt(balance)}',
              textColor: balance >= 0 ? _kBlue : _kRed),
        ]),
      ],
    ),
  );
}

pw.Widget _summaryBox(String label, String value, {PdfColor? textColor}) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: const pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.SizedBox(height: 3),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: textColor ?? _kPurple)),
        ],
      ),
    ),
  );
}

// Colours for flat status chips in the PDF
const _kChipGreen = PdfColor(0.878, 0.969, 0.882);
const _kChipGreenText = PdfColor(0.106, 0.369, 0.125);
const _kChipOrange = PdfColor(1.0, 0.929, 0.851);
const _kChipOrangeText = PdfColor(0.690, 0.361, 0.0);
const _kChipGrey = PdfColor(0.933, 0.933, 0.933);
const _kChipGreyText = PdfColor(0.376, 0.376, 0.376);

pw.Widget _buildContributionsByWing(
  Map<String, Map<String, List<String>>> structure,
  Map<String, String> flatStatus,
  Map<String, double> flatAmount,
) {
  // Overall totals
  int totalFlats = 0, totalPaid = 0, totalPending = 0;
  for (final blocks in structure.values) {
    for (final flats in blocks.values) {
      for (final f in flats) {
        totalFlats++;
        final s = flatStatus[f];
        if (s == 'paid') totalPaid++;
        else if (s == 'pending') totalPending++;
      }
    }
  }
  final totalNotRecorded = totalFlats - totalPaid - totalPending;

  final widgets = <pw.Widget>[
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('Contributions by Wing / Block',
            style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: _kPurple)),
        pw.Spacer(),
        _legend('Paid ($totalPaid)', _kChipGreen, _kChipGreenText),
        pw.SizedBox(width: 6),
        _legend('Pending ($totalPending)', _kChipOrange, _kChipOrangeText),
        pw.SizedBox(width: 6),
        _legend('Not Recorded ($totalNotRecorded)', _kChipGrey, _kChipGreyText),
      ],
    ),
    pw.SizedBox(height: 10),
  ];

  for (final wingEntry in structure.entries) {
    final wing = wingEntry.key;
    final blocks = wingEntry.value;
    if (blocks.isEmpty) continue;

    int wingPaid = 0, wingTotal = 0;
    double wingCollected = 0;
    for (final flats in blocks.values) {
      for (final f in flats) {
        wingTotal++;
        if (flatStatus[f] == 'paid') wingPaid++;
        wingCollected += flatAmount[f] ?? 0;
      }
    }

    final blockWidgets = <pw.Widget>[];
    for (final blockEntry in blocks.entries) {
      final block = blockEntry.key;
      final flats = blockEntry.value;
      if (flats.isEmpty) continue;

      int blockPaid = 0;
      double blockCollected = 0;
      for (final f in flats) {
        if (flatStatus[f] == 'paid') blockPaid++;
        blockCollected += flatAmount[f] ?? 0;
      }

      final chips = flats.map((flat) {
        final s = flatStatus[flat];
        final amt = flatAmount[flat] ?? 0;
        final bg = s == 'paid'
            ? _kChipGreen
            : s == 'pending'
                ? _kChipOrange
                : _kChipGrey;
        final fg = s == 'paid'
            ? _kChipGreenText
            : s == 'pending'
                ? _kChipOrangeText
                : _kChipGreyText;
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          margin: const pw.EdgeInsets.only(right: 5, bottom: 5),
          decoration: pw.BoxDecoration(
            color: bg,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(flat,
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: fg)),
              if (amt > 0) ...[
                pw.SizedBox(height: 2),
                pw.Text('Rs.${_fmt(amt)}',
                    style: pw.TextStyle(fontSize: 7, color: fg)),
              ],
            ],
          ),
        );
      }).toList();

      blockWidgets.add(pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Block header row
          pw.Row(children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: const pw.BoxDecoration(
                color: _kPurpleLight,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text('Block $block',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _kPurple)),
            ),
            pw.SizedBox(width: 6),
            pw.Text('$blockPaid / ${flats.length} paid',
                style: const pw.TextStyle(
                    fontSize: 8, color: PdfColors.grey700)),
            pw.Spacer(),
            if (blockCollected > 0)
              pw.Text('Rs.${_fmt(blockCollected)}',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _kGreen)),
          ]),
          pw.SizedBox(height: 5),
          pw.Wrap(children: chips),
          pw.SizedBox(height: 10),
        ],
      ));
    }

    widgets.add(pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Wing header bar
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: const pw.BoxDecoration(
              color: _kPurple,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Row(children: [
              pw.Text('$wing Wing',
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(width: 10),
              pw.Text('$wingPaid / $wingTotal paid',
                  style: const pw.TextStyle(
                      color: PdfColors.white, fontSize: 9)),
              pw.Spacer(),
              if (wingCollected > 0)
                pw.Text('Rs.${_fmt(wingCollected)}',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold)),
            ]),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 2),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: blockWidgets),
          ),
        ],
      ),
    ));
  }

  if (widgets.length == 2) {
    widgets.add(pw.Text('No flat structure configured.',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)));
  }

  return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start, children: widgets);
}

pw.Widget _legend(String label, PdfColor bg, PdfColor fg) {
  return pw.Row(children: [
    pw.Container(
      width: 10,
      height: 10,
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
    ),
    pw.SizedBox(width: 3),
    pw.Text(label, style: pw.TextStyle(fontSize: 8, color: fg)),
  ]);
}

pw.Widget _buildExpenses(List<Map<String, dynamic>> expenses) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Expenses (${expenses.length})',
          style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _kPurple)),
      pw.SizedBox(height: 8),
      if (expenses.isEmpty)
        pw.Text('No expenses recorded.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))
      else
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(20),
            1: const pw.FlexColumnWidth(2.5),
            2: const pw.FlexColumnWidth(1.8),
            3: const pw.FlexColumnWidth(1.0),
            4: const pw.FlexColumnWidth(1.5),
            5: const pw.FlexColumnWidth(1.5),
          },
          children: [
            _tableHeader(['#', 'Item', 'Category', 'Amount', 'Vendor', 'Date']),
            ...expenses.asMap().entries.map((e) {
              final exp = e.value;
              final cat = exp['category']?.toString() ?? '';
              final sub = exp['subCategory']?.toString() ?? '';
              final catLabel = sub.isNotEmpty ? '$cat > $sub' : cat;
              return _tableRow([
                '${e.key + 1}',
                exp['item']?.toString() ?? '-',
                catLabel,
                'Rs.${_fmt((exp['amount'] as num?)?.toDouble() ?? 0)}',
                exp['vendor']?.toString() ?? '-',
                _fmtDate(exp['addedAt']),
              ], e.key.isEven);
            }),
          ],
        ),
    ],
  );
}

pw.TableRow _tableHeader(List<String> cols) {
  return pw.TableRow(
    decoration: const pw.BoxDecoration(color: _kPurple),
    children: cols
        .map((h) => pw.Padding(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              child: pw.Text(h,
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold)),
            ))
        .toList(),
  );
}

pw.TableRow _tableRow(List<String> cells, bool isEven) {
  return pw.TableRow(
    decoration: pw.BoxDecoration(color: isEven ? _kGrey100 : PdfColors.white),
    children: cells
        .map((c) => pw.Padding(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              child: pw.Text(c, style: const pw.TextStyle(fontSize: 9)),
            ))
        .toList(),
  );
}

String _fmt(double v) {
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}

String _fmtDate(dynamic d) {
  if (d == null) return '-';
  try {
    final dt = DateTime.parse(d.toString());
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  } catch (_) {
    return d.toString();
  }
}
