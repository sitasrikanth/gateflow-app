import 'package:flutter/material.dart';
import 'import_contributions_screen.dart';
import 'import_expenses_screen.dart';
import '../../utils/csv_export.dart';
import '../../utils/event_pdf_report.dart';
import '../../theme/app_theme.dart';

// ── Import / Export — consolidated entry point for all bulk data flows ───────
// Groups what used to be five separate items in the Event Tools menu
// (Import/Export Contributions, Import/Export Expenses, Export PDF Report)
// into one place.

class ImportExportScreen extends StatelessWidget {
  final String eventId;
  final String eventName;
  final Map<String, dynamic> eventData;
  final double collected;
  final double spent;
  final double balance;
  final double target;

  const ImportExportScreen({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.eventData,
    required this.collected,
    required this.spent,
    required this.balance,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Import / Export',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(eventName, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionLabel('Contributions'),
          _ActionTile(
            icon: Icons.upload_file_rounded,
            iconColor: Colors.teal,
            title: 'Import Contributions',
            subtitle: 'Bulk-add contributions from a CSV or Excel file',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ImportContributionsScreen(eventId: eventId, eventName: eventName),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.grid_on_rounded,
            iconColor: Colors.green,
            title: 'Export Contributions (CSV)',
            subtitle: 'Save all contributions as a CSV — open directly in Google Sheets',
            onTap: () => exportContributionsCsv(context: context, eventId: eventId, eventName: eventName),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Expenses'),
          _ActionTile(
            icon: Icons.upload_file_rounded,
            iconColor: Colors.teal,
            title: 'Import Expenses',
            subtitle: 'Bulk-add expenses from a CSV or Excel file',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ImportExpensesScreen(eventId: eventId, eventName: eventName),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.grid_on_rounded,
            iconColor: Colors.green,
            title: 'Export Expenses (CSV)',
            subtitle: 'Save all expenses as a CSV — open directly in Google Sheets',
            onTap: () => exportExpensesCsv(context: context, eventId: eventId, eventName: eventName),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Reports'),
          _ActionTile(
            icon: Icons.picture_as_pdf_rounded,
            iconColor: AppTheme.accent,
            title: 'Export PDF Report',
            subtitle: 'Full event summary — collected, spent, balance',
            onTap: () => exportEventPdfReport(
              context: context,
              eventId: eventId,
              eventData: eventData,
              collected: collected,
              spent: spent,
              balance: balance,
              target: target,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 0.6)),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ]),
        ),
      ),
    );
  }
}
