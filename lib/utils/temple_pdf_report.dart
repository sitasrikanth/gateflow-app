import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../theme/app_theme.dart';

// ── Single Temple Donation Receipt ────────────────────────────────────────────
// Deliberately self-contained (not sharing helpers with event_pdf_report.dart)
// since the Temple module is a separate top-level module, not nested under
// Events.

const _kOrange = PdfColor(0.827, 0.325, 0.024);
const _kGreen = PdfColor(0.180, 0.490, 0.196);

Future<void> exportTempleDonationReceipt({
  required BuildContext context,
  required String docId,
  required Map<String, dynamic> donation,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(SnackBar(
    content: const Text('Generating receipt...'),
    duration: const Duration(seconds: 30),
    backgroundColor: Colors.deepOrange.shade700,
  ));

  try {
    final results = await Future.wait([
      PdfGoogleFonts.notoSansRegular(),
      PdfGoogleFonts.notoSansBold(),
    ]);
    final font = results[0];
    final fontBold = results[1];

    final isAnonymous = donation['isAnonymous'] == true;
    final donorName = (donation['donorName'] as String?)?.trim() ?? '';
    final payerName = isAnonymous
        ? 'Anonymous Donor'
        : (donorName.isNotEmpty ? donorName : 'Donor');
    final flat = (donation['flatNumber'] as String?) ?? '';
    final wing = (donation['wing'] as String?) ?? '';
    final block = (donation['block'] as String?) ?? '';
    final addressParts = [
      if (wing.isNotEmpty) '$wing Wing',
      if (block.isNotEmpty) 'Block $block',
      if (flat.isNotEmpty) 'Flat $flat',
    ];
    final amount = (donation['amount'] as num?)?.toDouble() ?? 0;
    final mode = (donation['paymentMode'] as String?) ?? 'Cash';
    final ref = (donation['referenceId'] as String?)?.trim() ?? '';
    final category = (donation['category'] as String?) ?? 'General';
    final tier = (donation['tierName'] as String?)?.trim() ?? '';
    final inKindDesc = (donation['inKindDescription'] as String?)?.trim() ?? '';
    final note = (donation['note'] as String?)?.trim() ?? '';
    final donatedDate = (donation['donatedDate'] as String?) ?? '';
    final receiptNo =
        'TD-${docId.length >= 6 ? docId.substring(0, 6).toUpperCase() : docId.toUpperCase()}';

    final now = DateTime.now();
    final generatedStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              color: _kOrange,
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Temple Donation',
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text('Receipt',
                          style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(receiptNo,
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text('Generated: $generatedStr',
                          style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: const PdfColor(0.910, 0.961, 0.914),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(amount > 0 ? 'Amount Received' : 'In-Kind Donation',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 2),
                  pw.Text(
                      amount > 0 ? '₹${amount.toStringAsFixed(0)}' : (inKindDesc.isNotEmpty ? inKindDesc : 'Item Donation'),
                      style: pw.TextStyle(
                          fontSize: amount > 0 ? 26 : 16,
                          fontWeight: pw.FontWeight.bold,
                          color: _kGreen)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            _receiptRow('Donor', payerName),
            if (addressParts.isNotEmpty) _receiptRow('Address', addressParts.join(' • ')),
            _receiptRow('Date', donatedDate.isNotEmpty ? donatedDate : generatedStr),
            _receiptRow('Payment Mode', mode),
            if (ref.isNotEmpty) _receiptRow('Reference / Txn ID', ref),
            _receiptRow('Category', category),
            if (tier.isNotEmpty) _receiptRow('Tier', tier),
            if (mode == 'In-Kind' && inKindDesc.isNotEmpty) _receiptRow('Item Donated', inKindDesc),
            if (note.isNotEmpty) _receiptRow('Note', note),
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.Center(
              child: pw.Text('Thank you for your generous contribution!',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold, color: _kOrange)),
            ),
          ],
        ),
      ),
    );

    final bytes = Uint8List.fromList(await doc.save());
    final safeName = payerName.replaceAll(RegExp(r'[^\w\s]'), '').trim().replaceAll(' ', '_');
    final filename = 'TempleReceipt_${safeName}_$receiptNo.pdf';

    messenger.hideCurrentSnackBar();

    if (context.mounted) {
      await _showSaveDialog(context, bytes, filename, messenger);
    }
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text('Receipt generation failed: $e'),
      backgroundColor: Colors.red,
    ));
  }
}

pw.Widget _receiptRow(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(label,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );

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
                style: const TextStyle(fontSize: 13, color: Colors.grey),
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
                child: Icon(Icons.download_rounded, color: Colors.green.shade700),
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
                  color: AppTheme.accent.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.share_rounded, color: AppTheme.accent.shade700),
              ),
              title: const Text('Share / Open with…',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Share via WhatsApp, email, Drive, etc.'),
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
