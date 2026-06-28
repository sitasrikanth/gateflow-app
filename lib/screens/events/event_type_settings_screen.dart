import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'event_types.dart';
import 'expense_categories_screen.dart'
    show kEmojiPicker, eventTypeCategoriesRef;

// Stored at /appSettings/poojaSchedule
// { enabledTypeIds: [...], morningCapacity: 2, eveningCapacity: 2 }

class EventTypeSettingsScreen extends StatelessWidget {
  const EventTypeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        title: const Text('Event Settings',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(children: [
          _PoojaScheduleSection(),
          SizedBox(height: 12),
          _SpecialContributionSection(),
          SizedBox(height: 12),
          _ExpenseCategoriesSection(),
          SizedBox(height: 12),
          _VolunteerRolesSection(),
          SizedBox(height: 40),
        ]),
      ),
    );
  }
}

// ── Top-level Pooja Schedule collapsable ──────────────────────────────────────

class _PoojaScheduleSection extends StatefulWidget {
  const _PoojaScheduleSection();

  @override
  State<_PoojaScheduleSection> createState() => _PoojaScheduleSectionState();
}

class _PoojaScheduleSectionState extends State<_PoojaScheduleSection> {
  bool _expanded = false;

  static final DocumentReference _ref = FirebaseFirestore.instance
      .collection('appSettings')
      .doc('poojaSchedule');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() as Map<String, dynamic>? ?? {};
        final enabledIds = List<String>.from(d['enabledTypeIds'] as List? ?? []);
        final morningCap = (d['morningCapacity'] as int?) ?? 2;
        final eveningCap = (d['eveningCapacity'] as int?) ?? 2;
        final totalSelected = enabledIds.length;

        void save(List<String> ids, int morning, int evening) {
          _ref.set({'enabledTypeIds': ids, 'morningCapacity': morning, 'eveningCapacity': evening});
        }

        void toggleId(String id, bool enabled) {
          final updated = List<String>.from(enabledIds);
          enabled ? updated.add(id) : updated.remove(id);
          save(updated, morningCap, eveningCap);
        }

        final categories = EventCategory.values
            .where((cat) => kAllEventTypes.any((t) => t.category == cat))
            .toList();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Header (tap to expand/collapse) ──
            InkWell(
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(14),
                bottom: _expanded ? Radius.zero : const Radius.circular(14),
              ),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(children: [
                  const Text('🙏', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Pooja Schedule',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(
                        totalSelected == 0
                            ? 'Not enabled for any event'
                            : '$totalSelected event type${totalSelected == 1 ? '' : 's'} enabled',
                        style: TextStyle(
                          fontSize: 11,
                          color: totalSelected > 0 ? Colors.deepPurple.shade400 : Colors.grey.shade400,
                        ),
                      ),
                    ]),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade500,
                  ),
                ]),
              ),
            ),

            if (_expanded) ...[
              const Divider(height: 1),

              // ── Default Slot Capacity ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.tune, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text('Default Slot Capacity',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                            color: Colors.grey.shade700)),
                  ]),
                  const SizedBox(height: 4),
                  Text('Default slots per shift per day for all Pooja events.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400, height: 1.4)),
                  const SizedBox(height: 12),
                  _CapacityRow(
                    icon: Icons.wb_sunny_outlined,
                    color: const Color(0xFFF59E0B),
                    label: 'Morning slots',
                    value: morningCap,
                    onChanged: (v) => save(enabledIds, v, eveningCap),
                  ),
                  const SizedBox(height: 8),
                  _CapacityRow(
                    icon: Icons.nights_stay_outlined,
                    color: const Color(0xFF8B5CF6),
                    label: 'Evening slots',
                    value: eveningCap,
                    onChanged: (v) => save(enabledIds, morningCap, v),
                  ),
                ]),
              ),

              const Divider(height: 1, indent: 16, endIndent: 16),

              // ── Event type label ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Text('Enable for',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
                        color: Colors.grey.shade500, letterSpacing: 0.3)),
              ),

              // ── Per-category collapsable sections ──
              ...categories.map((cat) {
                final types = kAllEventTypes.where((t) => t.category == cat).toList();
                final selectedCount = types.where((t) => enabledIds.contains(t.id)).length;
                return _CategorySection(
                  category: cat,
                  types: types,
                  enabledIds: enabledIds,
                  selectedCount: selectedCount,
                  onToggle: toggleId,
                );
              }),

              const SizedBox(height: 8),
            ],
          ]),
        );
      },
    );
  }
}

// ── Per-category collapsable section ─────────────────────────────────────────

class _CategorySection extends StatefulWidget {
  final EventCategory category;
  final List<EventTypeData> types;
  final List<String> enabledIds;
  final int selectedCount;
  final void Function(String id, bool enabled) onToggle;

  const _CategorySection({
    required this.category,
    required this.types,
    required this.enabledIds,
    required this.selectedCount,
    required this.onToggle,
  });

  @override
  State<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<_CategorySection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Category header row
      InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
          child: Row(children: [
            Text(widget.category.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.category.label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            if (widget.selectedCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${widget.selectedCount}/${widget.types.length}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                        color: Colors.deepPurple.shade600)),
              ),
            const SizedBox(width: 4),
            Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              size: 18, color: Colors.grey.shade400,
            ),
          ]),
        ),
      ),

      // Sub-events (checkboxes)
      if (_expanded) ...[
        ...widget.types.map((type) {
          final enabled = widget.enabledIds.contains(type.id);
          return InkWell(
            onTap: () => widget.onToggle(type.id, !enabled),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(38, 2, 8, 2),
              child: Row(children: [
                Text(type.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(type.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: enabled ? FontWeight.w600 : FontWeight.normal,
                        color: enabled ? Colors.grey.shade900 : Colors.grey.shade600,
                      )),
                ),
                Checkbox(
                  value: enabled,
                  activeColor: Colors.deepPurple,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (v) => widget.onToggle(type.id, v ?? false),
                ),
              ]),
            ),
          );
        }),
        const SizedBox(height: 4),
      ],

      const Divider(height: 1, indent: 16, endIndent: 16),
    ]);
  }
}

// ── Special Contribution Section ──────────────────────────────────────────────
// /appSettings/specialContribution → { enabledTypeIds: [...] }
// /eventTypeConfig/{typeId}        → { specialDescriptions: [...], specialDefaultNote: '' }

class _SpecialContributionSection extends StatefulWidget {
  const _SpecialContributionSection();
  @override
  State<_SpecialContributionSection> createState() => _SpecialContributionSectionState();
}

class _SpecialContributionSectionState extends State<_SpecialContributionSection> {
  bool _expanded = false;

  static final _ref = FirebaseFirestore.instance
      .collection('appSettings')
      .doc('specialContribution');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() as Map<String, dynamic>? ?? {};
        final enabledIds = List<String>.from(d['enabledTypeIds'] as List? ?? []);
        final totalSelected = enabledIds.length;

        void toggleId(String id, bool on) {
          final updated = List<String>.from(enabledIds);
          on ? updated.add(id) : updated.remove(id);
          _ref.set({'enabledTypeIds': updated});
        }

        final categories = EventCategory.values
            .where((cat) => kAllEventTypes.any((t) => t.category == cat))
            .toList();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            InkWell(
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(14),
                bottom: _expanded ? Radius.zero : const Radius.circular(14),
              ),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(children: [
                  const Text('⭐', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Special Contribution',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(
                        totalSelected == 0
                            ? 'Not enabled for any event'
                            : '$totalSelected event type${totalSelected == 1 ? '' : 's'} enabled',
                        style: TextStyle(fontSize: 11,
                            color: totalSelected > 0 ? Colors.purple.shade400 : Colors.grey.shade400),
                      ),
                    ]),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey.shade500),
                ]),
              ),
            ),

            if (_expanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                    'Select which events allow Special Contribution. '
                    'Configure preset descriptions and default note per event type.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400, height: 1.4),
                  )),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: Text('Enable for',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
                        color: Colors.grey.shade500, letterSpacing: 0.3)),
              ),
              ...categories.map((cat) => _SpecialCatGroup(
                    category: cat,
                    enabledIds: enabledIds,
                    onToggle: toggleId,
                  )),
              const SizedBox(height: 8),
            ],
          ]),
        );
      },
    );
  }
}

class _SpecialCatGroup extends StatefulWidget {
  final EventCategory category;
  final List<String> enabledIds;
  final void Function(String, bool) onToggle;
  const _SpecialCatGroup({required this.category, required this.enabledIds, required this.onToggle});
  @override
  State<_SpecialCatGroup> createState() => _SpecialCatGroupState();
}

class _SpecialCatGroupState extends State<_SpecialCatGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final types = kAllEventTypes.where((t) => t.category == widget.category).toList();
    final selectedCount = types.where((t) => widget.enabledIds.contains(t.id)).length;

    return Column(children: [
      InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
          child: Row(children: [
            Text(widget.category.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.category.label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            if (selectedCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$selectedCount/${types.length}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                        color: Colors.purple.shade600)),
              ),
            const SizedBox(width: 4),
            Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                size: 18, color: Colors.grey.shade400),
          ]),
        ),
      ),
      if (_expanded)
        ...types.map((type) => _SpecialTypeRow(
              eventType: type,
              enabled: widget.enabledIds.contains(type.id),
              onToggle: (on) => widget.onToggle(type.id, on),
            )),
      const Divider(height: 1, indent: 16, endIndent: 16),
    ]);
  }
}

class _SpecialTypeRow extends StatefulWidget {
  final EventTypeData eventType;
  final bool enabled;
  final void Function(bool) onToggle;
  const _SpecialTypeRow({required this.eventType, required this.enabled, required this.onToggle});
  @override
  State<_SpecialTypeRow> createState() => _SpecialTypeRowState();
}

class _SpecialTypeRowState extends State<_SpecialTypeRow> {
  bool _configExpanded = false;

  DocumentReference get _typeRef =>
      FirebaseFirestore.instance.collection('eventTypeConfig').doc(widget.eventType.id);

  Future<void> _addDescription(List<String> current) async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Preset Description'),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'e.g. Carry Forward from last year…',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (text == null || text.isEmpty) return;
    await _typeRef.set({'specialDescriptions': [...current, text]}, SetOptions(merge: true));
  }

  Future<void> _saveNote(String note) async {
    await _typeRef.set({'specialDefaultNote': note}, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _typeRef.snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() as Map<String, dynamic>? ?? {};
        final descs = List<String>.from(d['specialDescriptions'] as List? ?? []);
        final defaultNote = d['specialDefaultNote'] as String? ?? '';

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Type row: checkbox + name + config expand (if enabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
            child: Row(children: [
              const SizedBox(width: 20),
              Text(widget.eventType.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.eventType.name,
                    style: TextStyle(fontSize: 13,
                        fontWeight: widget.enabled ? FontWeight.w600 : FontWeight.normal,
                        color: widget.enabled ? Colors.grey.shade900 : Colors.grey.shade600)),
              ),
              if (widget.enabled)
                GestureDetector(
                  onTap: () => setState(() => _configExpanded = !_configExpanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Configure',
                          style: TextStyle(fontSize: 10, color: Colors.purple.shade400,
                              fontWeight: FontWeight.w600)),
                      Icon(_configExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 14, color: Colors.purple.shade400),
                    ]),
                  ),
                ),
              Checkbox(
                value: widget.enabled,
                activeColor: Colors.purple,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: (v) {
                  widget.onToggle(v ?? false);
                  if (!(v ?? false)) setState(() => _configExpanded = false);
                },
              ),
            ]),
          ),

          // Inline config (descriptions + default note)
          if (widget.enabled && _configExpanded)
            Container(
              margin: const EdgeInsets.fromLTRB(36, 0, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.purple.shade100),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Preset Descriptions
                Row(children: [
                  Icon(Icons.list_alt_outlined, size: 13, color: Colors.purple.shade600),
                  const SizedBox(width: 5),
                  Text('Preset Descriptions',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                          color: Colors.purple.shade700)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _addDescription(descs),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.add, size: 12, color: Colors.purple.shade700),
                        const SizedBox(width: 3),
                        Text('Add', style: TextStyle(fontSize: 10,
                            color: Colors.purple.shade700, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                if (descs.isEmpty)
                  Text('No presets yet. Tap + Add to create one.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400))
                else
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: descs.map((desc) => GestureDetector(
                      onTap: () {
                        final updated = List<String>.from(descs)..remove(desc);
                        _typeRef.set({'specialDescriptions': updated}, SetOptions(merge: true));
                      },
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Flexible(child: Text(desc,
                              style: TextStyle(fontSize: 11, color: Colors.purple.shade700))),
                          const SizedBox(width: 4),
                          Icon(Icons.close, size: 11, color: Colors.purple.shade300),
                        ]),
                      ),
                    )).toList(),
                  ),

                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Default Note
                Row(children: [
                  Icon(Icons.note_outlined, size: 13, color: Colors.purple.shade600),
                  const SizedBox(width: 5),
                  Text('Default Note',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                          color: Colors.purple.shade700)),
                ]),
                const SizedBox(height: 6),
                _DefaultNoteField(
                  initialValue: defaultNote,
                  onSave: _saveNote,
                ),
              ]),
            ),
        ]);
      },
    );
  }
}

class _DefaultNoteField extends StatefulWidget {
  final String initialValue;
  final Future<void> Function(String) onSave;
  const _DefaultNoteField({required this.initialValue, required this.onSave});
  @override
  State<_DefaultNoteField> createState() => _DefaultNoteFieldState();
}

class _DefaultNoteFieldState extends State<_DefaultNoteField> {
  late final TextEditingController _ctrl;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
    _ctrl.addListener(() => setState(() => _dirty = _ctrl.text != widget.initialValue));
  }

  @override
  void didUpdateWidget(_DefaultNoteField old) {
    super.didUpdateWidget(old);
    if (old.initialValue != widget.initialValue && !_dirty) {
      _ctrl.text = widget.initialValue;
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(
      child: TextField(
        controller: _ctrl,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: 'e.g. Thank you for your contribution!',
          hintStyle: const TextStyle(fontSize: 11),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.purple.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.purple.shade400)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    ),
    if (_dirty) ...[
      const SizedBox(width: 6),
      GestureDetector(
        onTap: _saving ? null : () async {
          setState(() => _saving = true);
          await widget.onSave(_ctrl.text.trim());
          if (mounted) setState(() { _saving = false; _dirty = false; });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.purple,
            borderRadius: BorderRadius.circular(8),
          ),
          child: _saving
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save', style: TextStyle(fontSize: 11, color: Colors.white,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    ],
  ]);
}

// ── Expense Categories Section ────────────────────────────────────────────────

class _ExpenseCategoriesSection extends StatefulWidget {
  const _ExpenseCategoriesSection();
  @override
  State<_ExpenseCategoriesSection> createState() => _ExpenseCategoriesSectionState();
}

class _ExpenseCategoriesSectionState extends State<_ExpenseCategoriesSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final categories = EventCategory.values
        .where((cat) => kAllEventTypes.any((t) => t.category == cat))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        InkWell(
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(14),
            bottom: _expanded ? Radius.zero : const Radius.circular(14),
          ),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(children: [
              const Text('📋', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Expense Categories',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text('Default categories & sub-categories per event type',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
              ),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey.shade500),
            ]),
          ),
        ),

        if (_expanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(children: [
              Icon(Icons.info_outline, size: 13, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Expanded(child: Text(
                'Each event type has its own category list. Changes here appear when adding expenses for that event.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400, height: 1.4),
              )),
            ]),
          ),
          ...categories.map((cat) => _ExpCategoryGroup(category: cat)),
          const SizedBox(height: 8),
        ],
      ]),
    );
  }
}

// ── Per-category group ────────────────────────────────────────────────────────

class _ExpCategoryGroup extends StatefulWidget {
  final EventCategory category;
  const _ExpCategoryGroup({required this.category});
  @override
  State<_ExpCategoryGroup> createState() => _ExpCategoryGroupState();
}

class _ExpCategoryGroupState extends State<_ExpCategoryGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final types = kAllEventTypes.where((t) => t.category == widget.category).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          child: Row(children: [
            Text(widget.category.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.category.label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                size: 18, color: Colors.grey.shade400),
          ]),
        ),
      ),
      if (_expanded) ...[
        ...types.map((type) => _ExpTypeEditor(eventType: type)),
      ],
      const Divider(height: 1, indent: 16, endIndent: 16),
    ]);
  }
}

// ── Per-event-type category editor ───────────────────────────────────────────

class _ExpTypeEditor extends StatefulWidget {
  final EventTypeData eventType;
  const _ExpTypeEditor({required this.eventType});
  @override
  State<_ExpTypeEditor> createState() => _ExpTypeEditorState();
}

class _ExpTypeEditorState extends State<_ExpTypeEditor> {
  bool _expanded = false;
  bool _seeding = false;

  DocumentReference get _ref => eventTypeCategoriesRef(widget.eventType.id);

  Future<List<Map<String, dynamic>>> _seed() async {
    setState(() => _seeding = true);
    final snap = await _ref.get();
    final data = snap.data() as Map<String, dynamic>? ?? {};
    if (data['expenseCategories'] == null) {
      final defaults = widget.eventType.expenseCategories
          .map((e) => Map<String, dynamic>.from(e)).toList();
      await _ref.set({'expenseCategories': defaults});
    }
    if (mounted) setState(() => _seeding = false);
    return [];
  }

  Future<void> _write(List<Map<String, dynamic>> cats) =>
      _ref.set({'expenseCategories': cats});

  Future<void> _addCategory(List<Map<String, dynamic>> current) async {
    String emoji = '📦';
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
        title: const Text('Add Category'),
        content: Row(children: [
          GestureDetector(
            onTap: () async {
              final p = await _pickEmoji(ctx, emoji);
              if (p != null) set(() => emoji = p);
            },
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepPurple.shade200)),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: TextField(
            controller: ctrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Category name…'),
          )),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
              child: const Text('Add', style: TextStyle(color: Colors.white))),
        ],
      )),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    final name = ctrl.text.trim();
    if (ok != true || name.isEmpty) return;
    await _write([...current, {'name': name, 'icon': emoji, 'subCategories': <String>[]}]);
  }

  Future<void> _deleteCategory(List<Map<String, dynamic>> current, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: const Text('Sub-categories will also be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (ok == true) await _write(current.where((c) => c['name'] != name).toList());
  }

  Future<void> _addSub(List<Map<String, dynamic>> current, Map<String, dynamic> cat) async {
    final ctrl = TextEditingController();
    final sub = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add to "${cat['name']}"'),
        content: TextField(controller: ctrl, textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Sub-category name…')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (sub == null || sub.isEmpty) return;
    final subs = List<String>.from(cat['subCategories'] as List? ?? [])..add(sub);
    await _write(current.map((c) => c['name'] == cat['name'] ? {...c, 'subCategories': subs} : c).toList());
  }

  Future<void> _deleteSub(List<Map<String, dynamic>> current, Map<String, dynamic> cat, String sub) async {
    final subs = List<String>.from(cat['subCategories'] as List? ?? [])..remove(sub);
    await _write(current.map((c) => c['name'] == cat['name'] ? {...c, 'subCategories': subs} : c).toList());
  }

  Future<void> _resetDefaults(List<Map<String, dynamic>> current) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset to Defaults?'),
        content: const Text('This will replace current categories with the built-in defaults for this event type.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Reset', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (ok != true) return;
    final defaults = widget.eventType.expenseCategories
        .map((e) => Map<String, dynamic>.from(e)).toList();
    await _write(defaults);
  }

  Future<String?> _pickEmoji(BuildContext ctx, String current) =>
      showDialog<String>(
        context: ctx,
        builder: (dlg) => AlertDialog(
          title: const Text('Pick an Icon'),
          content: SizedBox(
            width: 280,
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: kEmojiPicker.map((e) => GestureDetector(
                onTap: () => Navigator.pop(dlg, e),
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: current == e ? Colors.deepPurple.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: current == e ? Colors.deepPurple.shade300 : Colors.transparent),
                  ),
                  child: Center(child: Text(e, style: const TextStyle(fontSize: 20))),
                ),
              )).toList(),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() as Map<String, dynamic>? ?? {};
        final rawCats = d['expenseCategories'];
        final cats = rawCats != null
            ? List<Map<String, dynamic>>.from((rawCats as List).map((e) => Map<String, dynamic>.from(e as Map)))
            : <Map<String, dynamic>>[];
        final notSeeded = rawCats == null;

        // Auto-seed on first open
        if (notSeeded && _expanded && !_seeding) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _seed());
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Event type header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 6, 12, 6),
              child: Row(children: [
                Text(widget.eventType.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.eventType.name,
                    style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700))),
                Text(
                  '${notSeeded ? widget.eventType.expenseCategories.length : cats.length} categories',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                ),
                const SizedBox(width: 4),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16, color: Colors.grey.shade400),
              ]),
            ),
          ),

          if (_expanded) ...[
            if (_seeding)
              const Padding(
                padding: EdgeInsets.fromLTRB(32, 8, 16, 8),
                child: Center(child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else ...[
              // Category list
              ...cats.map((cat) {
                final subs = List<String>.from(cat['subCategories'] as List? ?? []);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 12, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(cat['icon'] as String? ?? '📦',
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(cat['name'] as String? ?? '',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade300),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _deleteCategory(cats, cat['name'] as String),
                      ),
                    ]),
                    if (subs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 20, bottom: 4),
                        child: Wrap(
                          spacing: 4, runSpacing: 4,
                          children: subs.map((s) => GestureDetector(
                            onTap: () => _deleteSub(cats, cat, s),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Text(s, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                                const SizedBox(width: 3),
                                Icon(Icons.close, size: 10, color: Colors.grey.shade400),
                              ]),
                            ),
                          )).toList(),
                        ),
                      ),
                    GestureDetector(
                      onTap: () => _addSub(cats, cat),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20, bottom: 6),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add, size: 12, color: Colors.deepPurple.shade300),
                          const SizedBox(width: 3),
                          Text('Add sub-category',
                              style: TextStyle(fontSize: 10, color: Colors.deepPurple.shade300)),
                        ]),
                      ),
                    ),
                  ]),
                );
              }),

              // Bottom actions
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 4, 12, 8),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => _addCategory(cats),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.add, size: 13, color: Colors.deepPurple.shade600),
                        const SizedBox(width: 4),
                        Text('Add category',
                            style: TextStyle(fontSize: 11, color: Colors.deepPurple.shade600,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _resetDefaults(cats),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.refresh, size: 13, color: Colors.orange.shade700),
                        const SizedBox(width: 4),
                        Text('Reset defaults',
                            style: TextStyle(fontSize: 11, color: Colors.orange.shade700,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ]),
              ),
            ],
          ],
        ]);
      },
    );
  }
}

// ── Volunteer Roles Section ───────────────────────────────────────────────────

class _VolunteerRolesSection extends StatefulWidget {
  const _VolunteerRolesSection();
  @override
  State<_VolunteerRolesSection> createState() => _VolunteerRolesSectionState();
}

class _VolunteerRolesSectionState extends State<_VolunteerRolesSection> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final categories = EventCategory.values;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.group_outlined, size: 18, color: Colors.teal.shade600),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Volunteer Roles',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text('Default roles per event type',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ])),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey.shade400),
            ]),
          ),
        ),
        if (_expanded) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Roles here are the defaults when volunteers sign up for each event type.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400, height: 1.4),
            ),
          ),
          ...categories.map((cat) => _VolRoleCatGroup(category: cat)),
          const SizedBox(height: 8),
        ],
      ]),
    );
  }
}

class _VolRoleCatGroup extends StatefulWidget {
  final EventCategory category;
  const _VolRoleCatGroup({required this.category});
  @override
  State<_VolRoleCatGroup> createState() => _VolRoleCatGroupState();
}

class _VolRoleCatGroupState extends State<_VolRoleCatGroup> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final types = kAllEventTypes.where((t) => t.category == widget.category).toList();
    final label = widget.category.name[0].toUpperCase() + widget.category.name.substring(1);
    return Column(children: [
      InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          child: Row(children: [
            Icon(Icons.folder_outlined, size: 16, color: Colors.teal.shade300),
            const SizedBox(width: 8),
            Expanded(child: Text(label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
            Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                size: 18, color: Colors.grey.shade400),
          ]),
        ),
      ),
      if (_expanded) ...[
        ...types.map((type) => _VolRoleTypeEditor(eventType: type)),
      ],
      const Divider(height: 1, indent: 16, endIndent: 16),
    ]);
  }
}

class _VolRoleTypeEditor extends StatefulWidget {
  final EventTypeData eventType;
  const _VolRoleTypeEditor({required this.eventType});
  @override
  State<_VolRoleTypeEditor> createState() => _VolRoleTypeEditorState();
}

const List<String> _kDefaultVolRoles = [
  'Coordinator', 'Decoration', 'Food & Catering', 'Security',
  'Music & Sound', 'Collection', 'Photography', 'Transport', 'Other',
];

class _VolRoleTypeEditorState extends State<_VolRoleTypeEditor> {
  bool _expanded = false;

  DocumentReference get _ref => FirebaseFirestore.instance
      .collection('eventTypeConfig').doc(widget.eventType.id);

  Future<List<String>> _getOrSeedRoles() async {
    final snap = await _ref.get();
    final d = snap.data() as Map<String, dynamic>? ?? {};
    if (d['volunteerRoles'] != null) {
      return List<String>.from(d['volunteerRoles'] as List);
    }
    await _ref.set({'volunteerRoles': _kDefaultVolRoles}, SetOptions(merge: true));
    return List<String>.from(_kDefaultVolRoles);
  }

  Future<void> _addRole(List<String> current) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Role'),
        content: TextField(controller: ctrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Role name…')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('Add', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    final name = ctrl.text.trim();
    if (ok != true || name.isEmpty) return;
    await _ref.set({'volunteerRoles': [...current, name]}, SetOptions(merge: true));
  }

  Future<void> _renameRole(List<String> current, String old) async {
    final ctrl = TextEditingController(text: old);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Role'),
        content: TextField(controller: ctrl,
            textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('Save', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    final name = ctrl.text.trim();
    if (ok != true || name.isEmpty || name == old) return;
    await _ref.set({'volunteerRoles': current.map((r) => r == old ? name : r).toList()},
        SetOptions(merge: true));
  }

  Future<void> _deleteRole(List<String> current, String role) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "$role"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (ok == true) {
      await _ref.set({'volunteerRoles': current.where((r) => r != role).toList()},
          SetOptions(merge: true));
    }
  }

  Future<void> _resetDefaults(List<String> current) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset to Defaults?'),
        content: const Text('Replace current roles with the built-in defaults.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Reset', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (ok == true) {
      await _ref.set({'volunteerRoles': List<String>.from(_kDefaultVolRoles)},
          SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() as Map<String, dynamic>? ?? {};
        final rawRoles = d['volunteerRoles'];
        final roles = rawRoles != null
            ? List<String>.from(rawRoles as List)
            : <String>[];
        final notSeeded = rawRoles == null;

        if (notSeeded && _expanded) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _getOrSeedRoles());
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 6, 12, 6),
              child: Row(children: [
                Text(widget.eventType.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.eventType.name,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700))),
                Text(
                  '${notSeeded ? _kDefaultVolRoles.length : roles.length} roles',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                ),
                const SizedBox(width: 4),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16, color: Colors.grey.shade400),
              ]),
            ),
          ),
          if (_expanded) ...[
            if (snap.connectionState == ConnectionState.waiting && notSeeded)
              const Padding(
                padding: EdgeInsets.fromLTRB(32, 8, 16, 8),
                child: Center(child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else ...[
              // Role chips (tap to rename, long-press to delete)
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 4, 12, 4),
                child: Wrap(
                  spacing: 6, runSpacing: 6,
                  children: (notSeeded ? _kDefaultVolRoles : roles).map((role) {
                    return GestureDetector(
                      onTap: () => _renameRole(notSeeded ? List<String>.from(_kDefaultVolRoles) : roles, role),
                      onLongPress: () => _deleteRole(notSeeded ? List<String>.from(_kDefaultVolRoles) : roles, role),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.drag_indicator, size: 12, color: Colors.teal.shade300),
                          const SizedBox(width: 4),
                          Text(role, style: TextStyle(fontSize: 11,
                              color: Colors.teal.shade800, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 4),
                          Icon(Icons.edit, size: 10, color: Colors.teal.shade300),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 4, 12, 8),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => _addRole(notSeeded ? List<String>.from(_kDefaultVolRoles) : roles),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.add, size: 13, color: Colors.teal.shade600),
                        const SizedBox(width: 4),
                        Text('Add role',
                            style: TextStyle(fontSize: 11, color: Colors.teal.shade600,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _resetDefaults(notSeeded ? List<String>.from(_kDefaultVolRoles) : roles),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.refresh, size: 13, color: Colors.orange.shade700),
                        const SizedBox(width: 4),
                        Text('Reset defaults',
                            style: TextStyle(fontSize: 11, color: Colors.orange.shade700,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 12, 8),
                child: Text('Tap to rename · Long press to delete',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              ),
            ],
          ],
          const Divider(height: 1, indent: 32, endIndent: 16),
        ]);
      },
    );
  }
}

// ── Capacity stepper row ──────────────────────────────────────────────────────

class _CapacityRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int value;
  final void Function(int) onChanged;

  const _CapacityRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      GestureDetector(
        onTap: value > 1 ? () => onChanged(value - 1) : null,
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: value > 1 ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.remove, size: 16,
              color: value > 1 ? color : Colors.grey.shade400),
        ),
      ),
      SizedBox(
        width: 40,
        child: Text('$value', textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      GestureDetector(
        onTap: () => onChanged(value + 1),
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.add, size: 16, color: color),
        ),
      ),
    ]);
  }
}
