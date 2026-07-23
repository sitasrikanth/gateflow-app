import 'package:flutter/material.dart';
import 'temple_settings_screen.dart';
import 'temple_donations_tab.dart';
import 'temple_routine_tab.dart';
import 'temple_assets_tab.dart';
import 'temple_anniversaries_tab.dart';
import 'temple_reports_tab.dart';

// ── Temple Module — Home ──────────────────────────────────────────────────────
// New top-level module (separate from Events, which are time-boxed), covering
// all 7 requested Temple features across 5 sub-tabs: Donations (contribution
// tiers, receipts, history), Routine (daily schedule, priests, festivals,
// ritual checklist), Assets (inventory + maintenance log), Anniversaries
// (recurring pooja reminders), and Reports (transparency/audit trail,
// including temple expenses). Admin gets full CRUD + settings; residents get
// view + contribute/confirm actions.

class TempleHomeScreen extends StatelessWidget {
  final bool isAdmin;
  const TempleHomeScreen({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Temple'),
        backgroundColor: Colors.deepOrange.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Temple Settings',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TempleSettingsScreen()),
              ),
            ),
        ],
      ),
      body: TempleHomeBody(isAdmin: isAdmin),
    );
  }
}

class TempleHomeBody extends StatefulWidget {
  final bool isAdmin;
  const TempleHomeBody({super.key, required this.isAdmin});

  @override
  State<TempleHomeBody> createState() => _TempleHomeBodyState();
}

class _TempleHomeBodyState extends State<TempleHomeBody> with SingleTickerProviderStateMixin {
  late TabController _innerTab;

  @override
  void initState() {
    super.initState();
    _innerTab = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _innerTab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.deepOrange.shade50,
          child: TabBar(
            controller: _innerTab,
            isScrollable: true,
            labelColor: Colors.deepOrange.shade800,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.deepOrange.shade700,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: const [
              Tab(text: 'Donations'),
              Tab(text: 'Routine'),
              Tab(text: 'Assets'),
              Tab(text: 'Anniversaries'),
              Tab(text: 'Reports'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _innerTab,
            children: [
              TempleDonationsTab(isAdmin: widget.isAdmin),
              TempleRoutineTab(isAdmin: widget.isAdmin),
              TempleAssetsTab(isAdmin: widget.isAdmin),
              TempleAnniversariesTab(isAdmin: widget.isAdmin),
              TempleReportsTab(isAdmin: widget.isAdmin),
            ],
          ),
        ),
      ],
    );
  }
}
