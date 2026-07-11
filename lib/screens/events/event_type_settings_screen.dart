import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'event_types.dart';
import 'expense_categories_screen.dart'
    show kEmojiPicker, eventTypeCategoriesRef;
import '../../theme/app_theme.dart';

// Firestore layout — all sections use the same opt-in pattern: an event type
// is OFF for a feature unless its id is in enabledTypeIds.
// /appSettings/poojaSchedule       { enabledTypeIds: [...], morningCapacity, afternoonCapacity, eveningCapacity }
// /appSettings/payments            { enabledTypeIds: [...] }
// /appSettings/collectionStatusByBlock { enabledTypeIds: [...] }
// /appSettings/specialContribution { enabledTypeIds: [...] }
// /appSettings/expenseCategories   { enabledTypeIds: [...] }
// /appSettings/volunteerRoles      { enabledTypeIds: [...] }
// /appSettings/deleteEvents        { enabledTypeIds: [...] }
// /eventTypeConfig/{typeId}        { specialDescriptions, specialDefaultNote, expenseCategories, volunteerRoles }

const List<String> _kDefaultVolRoles = [
  'Coordinator', 'Decoration', 'Food & Catering', 'Security',
  'Music & Sound', 'Collection', 'Photography', 'Transport', 'Other',
];

class EventTypeSettingsScreen extends StatefulWidget {
  const EventTypeSettingsScreen({super.key});

  @override
  State<EventTypeSettingsScreen> createState() => _EventTypeSettingsScreenState();
}

class _EventTypeSettingsScreenState extends State<EventTypeSettingsScreen> {
  static final DocumentReference _allowedCategoriesRef = FirebaseFirestore
      .instance
      .collection('appSettings')
      .doc('allowedCategories');

  final Set<String> _collapsedGroups = {
    'Money & Contributions',
    'Visibility & Recognition',
    'Scheduling & Volunteers',
    'Admin Controls',
  };

  Widget _group(String label, List<Widget> children) {
    final collapsed = _collapsedGroups.contains(label);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() {
            collapsed ? _collapsedGroups.remove(label) : _collapsedGroups.add(label);
          }),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(children: [
              Expanded(
                child: Text(label.toUpperCase(),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.6,
                        color: Colors.grey.shade500)),
              ),
              Icon(collapsed ? Icons.expand_more : Icons.expand_less,
                  size: 18, color: Colors.grey.shade500),
            ]),
          ),
        ),
        if (!collapsed) ...children,
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        title: const Text('Event Settings',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _allowedCategoriesRef.snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() as Map<String, dynamic>?;
          final rawList = data?['enabledCategories'] as List?;
          // Unset/no doc yet => every category is allowed (keeps existing
          // behavior for communities that haven't touched this setting).
          final Set<EventCategory> allowedCategories = rawList == null
              ? EventCategory.values.toSet()
              : EventCategory.values
                  .where((c) => rawList.contains(c.name))
                  .toSet();

          final rawTypeIds = data?['enabledEventTypeIds'] as List?;
          // Unset/no doc yet => every event type is allowed (same
          // backward-compatible default as the category filter above).
          final Set<String> allowedEventTypeIds = rawTypeIds == null
              ? kAllEventTypes.map((t) => t.id).toSet()
              : rawTypeIds.cast<String>().toSet();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _AllowedCategoriesSection(
                allowedCategories: allowedCategories,
                allowedEventTypeIds: allowedEventTypeIds,
              ),
              const SizedBox(height: 20),

              _group('Money & Contributions', [
                _PaymentsSection(
                    allowedCategories: allowedCategories,
                    allowedEventTypeIds: allowedEventTypeIds),
                const SizedBox(height: 12),
                _SpecialContributionSection(
                    allowedCategories: allowedCategories,
                    allowedEventTypeIds: allowedEventTypeIds),
                const SizedBox(height: 12),
                _CollectionStatusByBlockSection(
                    allowedCategories: allowedCategories,
                    allowedEventTypeIds: allowedEventTypeIds),
                const SizedBox(height: 12),
                _ExpenseCategoriesSection(
                    allowedCategories: allowedCategories,
                    allowedEventTypeIds: allowedEventTypeIds),
              ]),

              _group('Visibility & Recognition', [
                _OverviewStatsSection(
                    allowedCategories: allowedCategories,
                    allowedEventTypeIds: allowedEventTypeIds),
                const SizedBox(height: 12),
                _LeaderboardSection(
                    allowedCategories: allowedCategories,
                    allowedEventTypeIds: allowedEventTypeIds),
                const SizedBox(height: 12),
                _SponsorPackagesSection(
                    allowedCategories: allowedCategories,
                    allowedEventTypeIds: allowedEventTypeIds),
              ]),

              _group('Scheduling & Volunteers', [
                _PoojaScheduleSection(
                    allowedCategories: allowedCategories,
                    allowedEventTypeIds: allowedEventTypeIds),
                const SizedBox(height: 12),
                _VolunteerRolesSection(
                    allowedCategories: allowedCategories,
                    allowedEventTypeIds: allowedEventTypeIds),
              ]),

              _group('Admin Controls', [
                _DeleteEventsSection(
                    allowedCategories: allowedCategories,
                    allowedEventTypeIds: allowedEventTypeIds),
              ]),
              const SizedBox(height: 20),
            ]),
          );
        },
      ),
    );
  }
}

// ── Allowed Event Categories — master filter for the whole screen ───────────
// Lets an admin restrict which EventCategory values this community actually
// uses (e.g. only Festive), so every section below only shows event types
// from the categories selected here instead of all 8 by default.

class _AllowedCategoriesSection extends StatefulWidget {
  final Set<EventCategory> allowedCategories;
  final Set<String> allowedEventTypeIds;
  const _AllowedCategoriesSection({
    required this.allowedCategories,
    required this.allowedEventTypeIds,
  });

  @override
  State<_AllowedCategoriesSection> createState() => _AllowedCategoriesSectionState();
}

class _AllowedCategoriesSectionState extends State<_AllowedCategoriesSection> {
  final Set<EventCategory> _expandedCats = {};
  bool _headerExpanded = false;

  static final DocumentReference _ref = FirebaseFirestore.instance
      .collection('appSettings')
      .doc('allowedCategories');

  Future<void> _setAllowedCategories(Set<EventCategory> cats) =>
      _ref.set({'enabledCategories': cats.map((c) => c.name).toList()},
          SetOptions(merge: true));

  Future<void> _setAllowedEventTypeIds(Set<String> ids) =>
      _ref.set({'enabledEventTypeIds': ids.toList()}, SetOptions(merge: true));

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accent.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _headerExpanded = !_headerExpanded),
            child: Row(children: [
              const Text('🗂️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Allowed Event Categories',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(
                    _headerExpanded
                        ? 'Enable a category, then expand it to pick exactly which '
                            'events show up in every setting below.'
                        : '${widget.allowedCategories.length}/${EventCategory.values.length} categories · '
                            '${widget.allowedEventTypeIds.length}/${kAllEventTypes.length} events enabled',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ]),
              ),
              Icon(_headerExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey.shade500),
            ]),
          ),
          if (_headerExpanded) ...[
          const SizedBox(height: 12),
          Row(children: [
            TextButton(
              onPressed: () => _setAllowedCategories(EventCategory.values.toSet()),
              child: const Text('Select All'),
            ),
            TextButton(
              onPressed: () => _setAllowedCategories(<EventCategory>{}),
              child: const Text('Clear All'),
            ),
          ]),
          ...EventCategory.values.map((cat) {
            final categoryTypes =
                kAllEventTypes.where((t) => t.category == cat).toList();
            if (categoryTypes.isEmpty) return const SizedBox.shrink();
            final catEnabled = widget.allowedCategories.contains(cat);
            final selectedCount = categoryTypes
                .where((t) => widget.allowedEventTypeIds.contains(t.id))
                .length;
            final expanded = _expandedCats.contains(cat);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: catEnabled
                      ? () => setState(() {
                            expanded ? _expandedCats.remove(cat) : _expandedCats.add(cat);
                          })
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Checkbox(
                        value: catEnabled,
                        activeColor: AppTheme.accent,
                        onChanged: (v) {
                          final updated = Set<EventCategory>.from(widget.allowedCategories);
                          (v ?? false) ? updated.add(cat) : updated.remove(cat);
                          _setAllowedCategories(updated);
                        },
                      ),
                      Text(cat.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(cat.label,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: catEnabled ? null : Colors.grey.shade400)),
                      ),
                      if (catEnabled) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('$selectedCount/${categoryTypes.length}',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.accent.shade600)),
                        ),
                        const SizedBox(width: 4),
                        Icon(expanded ? Icons.expand_less : Icons.expand_more,
                            size: 18, color: Colors.grey.shade400),
                      ],
                    ]),
                  ),
                ),
                if (catEnabled && expanded) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(38, 0, 8, 4),
                    child: Row(children: [
                      TextButton(
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 28),
                            visualDensity: VisualDensity.compact),
                        onPressed: () {
                          final updated = Set<String>.from(widget.allowedEventTypeIds)
                            ..addAll(categoryTypes.map((t) => t.id));
                          _setAllowedEventTypeIds(updated);
                        },
                        child: const Text('Enable All', style: TextStyle(fontSize: 11)),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 28),
                            visualDensity: VisualDensity.compact),
                        onPressed: () {
                          final updated = Set<String>.from(widget.allowedEventTypeIds)
                            ..removeAll(categoryTypes.map((t) => t.id));
                          _setAllowedEventTypeIds(updated);
                        },
                        child: const Text('Disable All', style: TextStyle(fontSize: 11)),
                      ),
                    ]),
                  ),
                  ...categoryTypes.map((type) {
                    final typeEnabled = widget.allowedEventTypeIds.contains(type.id);
                    return InkWell(
                      onTap: () {
                        final updated = Set<String>.from(widget.allowedEventTypeIds);
                        typeEnabled ? updated.remove(type.id) : updated.add(type.id);
                        _setAllowedEventTypeIds(updated);
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(38, 2, 8, 2),
                        child: Row(children: [
                          Text(type.emoji, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(type.name,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight:
                                          typeEnabled ? FontWeight.w600 : FontWeight.normal,
                                      color: typeEnabled
                                          ? null
                                          : Colors.grey.shade400))),
                          Checkbox(
                            value: typeEnabled,
                            activeColor: AppTheme.accent,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            onChanged: (v) {
                              final updated = Set<String>.from(widget.allowedEventTypeIds);
                              (v ?? false) ? updated.add(type.id) : updated.remove(type.id);
                              _setAllowedEventTypeIds(updated);
                            },
                          ),
                        ]),
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                ],
                const Divider(height: 1),
              ],
            );
          }),
          ],
        ],
      ),
    );
  }
}

// ── Top-level Pooja Schedule collapsable ──────────────────────────────────────

class _PoojaScheduleSection extends StatefulWidget {
  final Set<EventCategory> allowedCategories;
  final Set<String> allowedEventTypeIds;
  const _PoojaScheduleSection({required this.allowedCategories, required this.allowedEventTypeIds});

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
        final afternoonCap = (d['afternoonCapacity'] as int?) ?? 2;
        final eveningCap = (d['eveningCapacity'] as int?) ?? 2;
        final totalSelected = enabledIds.length;

        void save(List<String> ids, int morning, int afternoon, int evening) {
          _ref.set({
            'enabledTypeIds': ids,
            'morningCapacity': morning,
            'afternoonCapacity': afternoon,
            'eveningCapacity': evening,
          });
        }

        void toggleId(String id, bool enabled) {
          final updated = List<String>.from(enabledIds);
          enabled ? updated.add(id) : updated.remove(id);
          save(updated, morningCap, afternoonCap, eveningCap);
        }

        void toggleAllIds(List<String> ids, bool enabled) {
          final updated = Set<String>.from(enabledIds);
          enabled ? updated.addAll(ids) : updated.removeAll(ids);
          save(updated.toList(), morningCap, afternoonCap, eveningCap);
        }

        final categories = EventCategory.values
            .where((cat) =>
                widget.allowedCategories.contains(cat) &&
                kAllEventTypes.any((t) => t.category == cat))
            .toList();

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
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
                          color: totalSelected > 0 ? AppTheme.accent.shade400 : Colors.grey.shade400,
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
                    onChanged: (v) => save(enabledIds, v, afternoonCap, eveningCap),
                  ),
                  const SizedBox(height: 8),
                  _CapacityRow(
                    icon: Icons.light_mode_outlined,
                    color: const Color(0xFFFB923C),
                    label: 'Afternoon slots',
                    value: afternoonCap,
                    onChanged: (v) => save(enabledIds, morningCap, v, eveningCap),
                  ),
                  const SizedBox(height: 8),
                  _CapacityRow(
                    icon: Icons.nights_stay_outlined,
                    color: const Color(0xFF8B5CF6),
                    label: 'Evening slots',
                    value: eveningCap,
                    onChanged: (v) => save(enabledIds, morningCap, afternoonCap, v),
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
                final types = kAllEventTypes
                    .where((t) => t.category == cat && widget.allowedEventTypeIds.contains(t.id))
                    .toList();
                final selectedCount = types.where((t) => enabledIds.contains(t.id)).length;
                return _CategorySection(
                  category: cat,
                  types: types,
                  enabledIds: enabledIds,
                  selectedCount: selectedCount,
                  onToggle: toggleId,
                  onToggleAll: toggleAllIds,
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

// ── Top-level Payments / Contributions collapsable ────────────────────────────

class _PaymentsSection extends StatefulWidget {
  final Set<EventCategory> allowedCategories;
  final Set<String> allowedEventTypeIds;
  const _PaymentsSection({required this.allowedCategories, required this.allowedEventTypeIds});
  @override
  State<_PaymentsSection> createState() => _PaymentsSectionState();
}

class _PaymentsSectionState extends State<_PaymentsSection> {
  bool _expanded = false;

  static final DocumentReference _ref = FirebaseFirestore.instance
      .collection('appSettings')
      .doc('payments');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() as Map<String, dynamic>? ?? {};
        final enabledIds = List<String>.from(d['enabledTypeIds'] as List? ?? []);
        final totalSelected = enabledIds.length;

        void toggleId(String id, bool enabled) {
          final updated = List<String>.from(enabledIds);
          enabled ? updated.add(id) : updated.remove(id);
          _ref.set({'enabledTypeIds': updated});
        }

        void toggleAllIds(List<String> ids, bool enabled) {
          final updated = Set<String>.from(enabledIds);
          enabled ? updated.addAll(ids) : updated.removeAll(ids);
          _ref.set({'enabledTypeIds': updated.toList()});
        }

        final categories = EventCategory.values
            .where((cat) =>
                widget.allowedCategories.contains(cat) &&
                kAllEventTypes.any((t) => t.category == cat))
            .toList();

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
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
                  const Text('💰', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Payments / Contributions',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(
                        totalSelected == 0
                            ? 'Not enabled for any event'
                            : '$totalSelected event type${totalSelected == 1 ? '' : 's'} require payment',
                        style: TextStyle(fontSize: 11,
                            color: totalSelected > 0 ? Colors.green.shade600 : Colors.grey.shade400),
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

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Text(
                  'Tick an event type to show "Add Contribution" / "I\'ve Paid" for it — '
                  'useful for events where residents need to pay.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400, height: 1.4),
                ),
              ),
              const SizedBox(height: 4),

              // ── Per-category collapsable sections ──
              ...categories.map((cat) {
                final types = kAllEventTypes
                    .where((t) => t.category == cat && widget.allowedEventTypeIds.contains(t.id))
                    .toList();
                final selectedCount = types.where((t) => enabledIds.contains(t.id)).length;
                return _CategorySection(
                  category: cat,
                  types: types,
                  enabledIds: enabledIds,
                  selectedCount: selectedCount,
                  onToggle: toggleId,
                  onToggleAll: toggleAllIds,
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

// ── Top-level Collection Status by Block collapsable ──────────────────────────

class _CollectionStatusByBlockSection extends StatefulWidget {
  final Set<EventCategory> allowedCategories;
  final Set<String> allowedEventTypeIds;
  const _CollectionStatusByBlockSection({required this.allowedCategories, required this.allowedEventTypeIds});
  @override
  State<_CollectionStatusByBlockSection> createState() => _CollectionStatusByBlockSectionState();
}

class _CollectionStatusByBlockSectionState extends State<_CollectionStatusByBlockSection> {
  bool _expanded = false;

  static final DocumentReference _ref = FirebaseFirestore.instance
      .collection('appSettings')
      .doc('collectionStatusByBlock');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() as Map<String, dynamic>? ?? {};
        final enabledIds = List<String>.from(d['enabledTypeIds'] as List? ?? []);
        final totalSelected = enabledIds.length;

        void toggleId(String id, bool enabled) {
          final updated = List<String>.from(enabledIds);
          enabled ? updated.add(id) : updated.remove(id);
          _ref.set({'enabledTypeIds': updated});
        }

        void toggleAllIds(List<String> ids, bool enabled) {
          final updated = Set<String>.from(enabledIds);
          enabled ? updated.addAll(ids) : updated.removeAll(ids);
          _ref.set({'enabledTypeIds': updated.toList()});
        }

        final categories = EventCategory.values
            .where((cat) =>
                widget.allowedCategories.contains(cat) &&
                kAllEventTypes.any((t) => t.category == cat))
            .toList();

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(14),
                bottom: _expanded ? Radius.zero : const Radius.circular(14),
              ),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(children: [
                  const Text('🏘️', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Collection Status by Block',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(
                        totalSelected == 0
                            ? 'Not enabled for any event'
                            : '$totalSelected event type${totalSelected == 1 ? '' : 's'} enabled',
                        style: TextStyle(fontSize: 11,
                            color: totalSelected > 0 ? Colors.blue.shade600 : Colors.grey.shade400),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Text(
                  'Shows the "Diamond A: 12/15 paid" block-wise breakdown in the Overview tab. '
                  'Leave off for events like Markets or Workshops with no block-wise collection.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400, height: 1.4),
                ),
              ),
              const SizedBox(height: 4),
              ...categories.map((cat) {
                final types = kAllEventTypes
                    .where((t) => t.category == cat && widget.allowedEventTypeIds.contains(t.id))
                    .toList();
                final selectedCount = types.where((t) => enabledIds.contains(t.id)).length;
                return _CategorySection(
                  category: cat,
                  types: types,
                  enabledIds: enabledIds,
                  selectedCount: selectedCount,
                  onToggle: toggleId,
                  onToggleAll: toggleAllIds,
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

// ── Top-level Overview Stats collapsable ──────────────────────────────────────
// Lets admins choose which stat chips (Cash / Online / Collected / Spent /
// Expected / Balance / Anonymous) show in the Overview tab, per event type.
// Stored on eventTypeConfig/{typeId}.overviewChips — unset means "all shown"
// so existing events keep their current behavior until explicitly changed.

const List<(String, String)> kOverviewChipDefs = [
  ('cash', 'Cash'),
  ('online', 'Online'),
  ('collected', 'Collected / Total'),
  ('spent', 'Spent'),
  ('expected', 'Expected (Target)'),
  ('balance', 'Balance'),
  ('anonymous', 'Anonymous'),
  ('external', 'External Donations'),
];

List<String> defaultOverviewChips() => kOverviewChipDefs.map((c) => c.$1).toList();

class _OverviewStatsSection extends StatefulWidget {
  final Set<EventCategory> allowedCategories;
  final Set<String> allowedEventTypeIds;
  const _OverviewStatsSection({required this.allowedCategories, required this.allowedEventTypeIds});
  @override
  State<_OverviewStatsSection> createState() => _OverviewStatsSectionState();
}

class _OverviewStatsSectionState extends State<_OverviewStatsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final categories = EventCategory.values
        .where((cat) =>
            widget.allowedCategories.contains(cat) &&
            kAllEventTypes.any((t) => t.category == cat))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(14),
            bottom: _expanded ? Radius.zero : const Radius.circular(14),
          ),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(children: [
              const Text('📊', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Overview Stats',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text('Choose which stat chips show, per event type',
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text(
              'Controls the Cash/Online/Collected/Spent/Expected/Balance/Anonymous '
              'chips in the Overview tab. All chips show by default until customized here.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400, height: 1.4),
            ),
          ),
          const SizedBox(height: 4),
          ...categories.map((cat) => _OverviewStatsCategoryGroup(
              category: cat, allowedEventTypeIds: widget.allowedEventTypeIds)),
          const SizedBox(height: 8),
        ],
      ]),
    );
  }
}

class _OverviewStatsCategoryGroup extends StatefulWidget {
  final EventCategory category;
  final Set<String> allowedEventTypeIds;
  const _OverviewStatsCategoryGroup({required this.category, required this.allowedEventTypeIds});
  @override
  State<_OverviewStatsCategoryGroup> createState() => _OverviewStatsCategoryGroupState();
}

class _OverviewStatsCategoryGroupState extends State<_OverviewStatsCategoryGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final types = kAllEventTypes
        .where((t) => t.category == widget.category && widget.allowedEventTypeIds.contains(t.id))
        .toList();
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
      if (_expanded)
        ...types.map((type) => _OverviewStatsTypeEditor(eventType: type)),
      const Divider(height: 1, indent: 16, endIndent: 16),
    ]);
  }
}

class _OverviewStatsTypeEditor extends StatefulWidget {
  final EventTypeData eventType;
  const _OverviewStatsTypeEditor({required this.eventType});
  @override
  State<_OverviewStatsTypeEditor> createState() => _OverviewStatsTypeEditorState();
}

class _OverviewStatsTypeEditorState extends State<_OverviewStatsTypeEditor> {
  bool _configExpanded = false;

  DocumentReference get _ref =>
      FirebaseFirestore.instance.collection('eventTypeConfig').doc(widget.eventType.id);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() as Map<String, dynamic>? ?? {};
        final raw = d['overviewChips'];
        final enabledChips = raw != null
            ? List<String>.from(raw as List)
            : defaultOverviewChips();

        Future<void> toggle(String key, bool on) async {
          final updated = List<String>.from(enabledChips);
          if (on) {
            if (!updated.contains(key)) updated.add(key);
          } else {
            updated.remove(key);
          }
          await _ref.set({'overviewChips': updated}, SetOptions(merge: true));
        }

        final selectedCount = enabledChips.length;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 6, 12, 6),
            child: Row(children: [
              Text(widget.eventType.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.eventType.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accent.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$selectedCount/${kOverviewChipDefs.length}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                        color: AppTheme.accent.shade600)),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() => _configExpanded = !_configExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Configure',
                        style: TextStyle(fontSize: 10, color: AppTheme.accent.shade400,
                            fontWeight: FontWeight.w600)),
                    Icon(_configExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 14, color: AppTheme.accent.shade400),
                  ]),
                ),
              ),
            ]),
          ),
          if (_configExpanded)
            Container(
              margin: const EdgeInsets.fromLTRB(32, 0, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accent.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.accent.shade100),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kOverviewChipDefs.map((chip) {
                  final key = chip.$1;
                  final label = chip.$2;
                  final on = enabledChips.contains(key);
                  return GestureDetector(
                    onTap: () => toggle(key, !on),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: on ? AppTheme.accent.shade600 : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: on ? AppTheme.accent.shade600 : Colors.grey.shade300),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (on) ...[
                          const Icon(Icons.check, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                        ],
                        Text(label,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: on ? Colors.white : Colors.grey.shade700)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
        ]);
      },
    );
  }
}

// ── Top-level Leaderboard collapsable ─────────────────────────────────────────

class _LeaderboardSection extends StatefulWidget {
  final Set<EventCategory> allowedCategories;
  final Set<String> allowedEventTypeIds;
  const _LeaderboardSection({required this.allowedCategories, required this.allowedEventTypeIds});
  @override
  State<_LeaderboardSection> createState() => _LeaderboardSectionState();
}

class _LeaderboardSectionState extends State<_LeaderboardSection> {
  bool _expanded = false;

  static final DocumentReference _ref = FirebaseFirestore.instance
      .collection('appSettings')
      .doc('leaderboard');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() as Map<String, dynamic>? ?? {};
        final enabledIds = List<String>.from(d['enabledTypeIds'] as List? ?? []);
        final totalSelected = enabledIds.length;

        void toggleId(String id, bool enabled) {
          final updated = List<String>.from(enabledIds);
          enabled ? updated.add(id) : updated.remove(id);
          _ref.set({'enabledTypeIds': updated});
        }

        void toggleAllIds(List<String> ids, bool enabled) {
          final updated = Set<String>.from(enabledIds);
          enabled ? updated.addAll(ids) : updated.removeAll(ids);
          _ref.set({'enabledTypeIds': updated.toList()});
        }

        final categories = EventCategory.values
            .where((cat) =>
                widget.allowedCategories.contains(cat) &&
                kAllEventTypes.any((t) => t.category == cat))
            .toList();

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(14),
                bottom: _expanded ? Radius.zero : const Radius.circular(14),
              ),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(children: [
                  const Text('🏆', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Leaderboard',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(
                        totalSelected == 0
                            ? 'Not enabled for any event'
                            : '$totalSelected event type${totalSelected == 1 ? '' : 's'} enabled',
                        style: TextStyle(fontSize: 11,
                            color: totalSelected > 0 ? Colors.amber.shade700 : Colors.grey.shade400),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Text(
                  'Shows a "Top Contributors" ranking in the Overview tab. Anonymous '
                  'contributions are summed separately and never shown in the ranked list.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400, height: 1.4),
                ),
              ),
              const SizedBox(height: 4),
              ...categories.map((cat) {
                final types = kAllEventTypes
                    .where((t) => t.category == cat && widget.allowedEventTypeIds.contains(t.id))
                    .toList();
                final selectedCount = types.where((t) => enabledIds.contains(t.id)).length;
                return _CategorySection(
                  category: cat,
                  types: types,
                  enabledIds: enabledIds,
                  selectedCount: selectedCount,
                  onToggle: toggleId,
                  onToggleAll: toggleAllIds,
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

// ── Top-level Sponsor Packages collapsable ────────────────────────────────────

class _SponsorPackagesSection extends StatefulWidget {
  final Set<EventCategory> allowedCategories;
  final Set<String> allowedEventTypeIds;
  const _SponsorPackagesSection({required this.allowedCategories, required this.allowedEventTypeIds});
  @override
  State<_SponsorPackagesSection> createState() => _SponsorPackagesSectionState();
}

class _SponsorPackagesSectionState extends State<_SponsorPackagesSection> {
  bool _expanded = false;

  static final DocumentReference _ref = FirebaseFirestore.instance
      .collection('appSettings')
      .doc('sponsorPackages');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() as Map<String, dynamic>? ?? {};
        final enabledIds = List<String>.from(d['enabledTypeIds'] as List? ?? []);
        final totalSelected = enabledIds.length;

        void toggleId(String id, bool enabled) {
          final updated = List<String>.from(enabledIds);
          enabled ? updated.add(id) : updated.remove(id);
          _ref.set({'enabledTypeIds': updated});
        }

        void toggleAllIds(List<String> ids, bool enabled) {
          final updated = Set<String>.from(enabledIds);
          enabled ? updated.addAll(ids) : updated.removeAll(ids);
          _ref.set({'enabledTypeIds': updated.toList()});
        }

        final categories = EventCategory.values
            .where((cat) =>
                widget.allowedCategories.contains(cat) &&
                kAllEventTypes.any((t) => t.category == cat))
            .toList();

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(14),
                bottom: _expanded ? Radius.zero : const Radius.circular(14),
              ),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(children: [
                  const Text('🎖️', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Sponsor Packages',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(
                        totalSelected == 0
                            ? 'Not enabled for any event'
                            : '$totalSelected event type${totalSelected == 1 ? '' : 's'} enabled',
                        style: TextStyle(fontSize: 11,
                            color: totalSelected > 0 ? Colors.amber.shade800 : Colors.grey.shade400),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Text(
                  'Lets admins define sponsorship tiers (e.g. Gold/Silver/Bronze) per '
                  'event and shows a "Our Sponsors" recognition wall. Manage tiers from '
                  'the Event Tools menu inside an eligible event.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400, height: 1.4),
                ),
              ),
              const SizedBox(height: 4),
              ...categories.map((cat) {
                final types = kAllEventTypes
                    .where((t) => t.category == cat && widget.allowedEventTypeIds.contains(t.id))
                    .toList();
                final selectedCount = types.where((t) => enabledIds.contains(t.id)).length;
                return _CategorySection(
                  category: cat,
                  types: types,
                  enabledIds: enabledIds,
                  selectedCount: selectedCount,
                  onToggle: toggleId,
                  onToggleAll: toggleAllIds,
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

// ── Top-level Delete Events collapsable ────────────────────────────────────────

class _DeleteEventsSection extends StatefulWidget {
  final Set<EventCategory> allowedCategories;
  final Set<String> allowedEventTypeIds;
  const _DeleteEventsSection({required this.allowedCategories, required this.allowedEventTypeIds});
  @override
  State<_DeleteEventsSection> createState() => _DeleteEventsSectionState();
}

class _DeleteEventsSectionState extends State<_DeleteEventsSection> {
  bool _expanded = false;

  static final DocumentReference _ref = FirebaseFirestore.instance
      .collection('appSettings')
      .doc('deleteEvents');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data() as Map<String, dynamic>? ?? {};
        final enabledIds = List<String>.from(d['enabledTypeIds'] as List? ?? []);
        final totalSelected = enabledIds.length;

        void toggleId(String id, bool enabled) {
          final updated = List<String>.from(enabledIds);
          enabled ? updated.add(id) : updated.remove(id);
          _ref.set({'enabledTypeIds': updated});
        }

        void toggleAllIds(List<String> ids, bool enabled) {
          final updated = Set<String>.from(enabledIds);
          enabled ? updated.addAll(ids) : updated.removeAll(ids);
          _ref.set({'enabledTypeIds': updated.toList()});
        }

        final categories = EventCategory.values
            .where((cat) =>
                widget.allowedCategories.contains(cat) &&
                kAllEventTypes.any((t) => t.category == cat))
            .toList();

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(14),
                bottom: _expanded ? Radius.zero : const Radius.circular(14),
              ),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(children: [
                  const Text('🗑️', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Delete Events (admin)',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(
                        totalSelected == 0
                            ? 'Not enabled for any event'
                            : '$totalSelected event type${totalSelected == 1 ? '' : 's'} enabled',
                        style: TextStyle(fontSize: 11,
                            color: totalSelected > 0 ? Colors.red.shade600 : Colors.grey.shade400),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Text(
                  'Shows "Delete Event" in the admin Event Tools menu for these event types. '
                  'Keep off for recurring festivals; enable for one-off or test event types.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400, height: 1.4),
                ),
              ),
              const SizedBox(height: 4),
              ...categories.map((cat) {
                final types = kAllEventTypes
                    .where((t) => t.category == cat && widget.allowedEventTypeIds.contains(t.id))
                    .toList();
                final selectedCount = types.where((t) => enabledIds.contains(t.id)).length;
                return _CategorySection(
                  category: cat,
                  types: types,
                  enabledIds: enabledIds,
                  selectedCount: selectedCount,
                  onToggle: toggleId,
                  onToggleAll: toggleAllIds,
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

// ── Per-category collapsable section (simple checkbox-only sections) ──────────

class _CategorySection extends StatefulWidget {
  final EventCategory category;
  final List<EventTypeData> types;
  final List<String> enabledIds;
  final int selectedCount;
  final void Function(String id, bool enabled) onToggle;
  final void Function(List<String> typeIds, bool enabled) onToggleAll;

  const _CategorySection({
    required this.category,
    required this.types,
    required this.enabledIds,
    required this.selectedCount,
    required this.onToggle,
    required this.onToggleAll,
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
                  color: AppTheme.accent.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${widget.selectedCount}/${widget.types.length}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                        color: AppTheme.accent.shade600)),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(38, 0, 8, 4),
          child: Row(children: [
            TextButton(
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                  visualDensity: VisualDensity.compact),
              onPressed: () => widget.onToggleAll(
                  widget.types.map((t) => t.id).toList(), true),
              child: const Text('Enable All', style: TextStyle(fontSize: 11)),
            ),
            TextButton(
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                  visualDensity: VisualDensity.compact),
              onPressed: () => widget.onToggleAll(
                  widget.types.map((t) => t.id).toList(), false),
              child: const Text('Disable All', style: TextStyle(fontSize: 11)),
            ),
          ]),
        ),
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
                        color: enabled ? null : Colors.grey.shade600,
                      )),
                ),
                Checkbox(
                  value: enabled,
                  activeColor: AppTheme.accent,
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
  final Set<EventCategory> allowedCategories;
  final Set<String> allowedEventTypeIds;
  const _SpecialContributionSection({required this.allowedCategories, required this.allowedEventTypeIds});
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

        void toggleAllIds(List<String> ids, bool on) {
          final updated = Set<String>.from(enabledIds);
          on ? updated.addAll(ids) : updated.removeAll(ids);
          _ref.set({'enabledTypeIds': updated.toList()});
        }

        final categories = EventCategory.values
            .where((cat) =>
                widget.allowedCategories.contains(cat) &&
                kAllEventTypes.any((t) => t.category == cat))
            .toList();

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
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
                    onToggleAll: toggleAllIds,
                    allowedEventTypeIds: widget.allowedEventTypeIds,
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
  final void Function(List<String>, bool) onToggleAll;
  final Set<String> allowedEventTypeIds;
  const _SpecialCatGroup({
    required this.category,
    required this.enabledIds,
    required this.onToggle,
    required this.onToggleAll,
    required this.allowedEventTypeIds,
  });
  @override
  State<_SpecialCatGroup> createState() => _SpecialCatGroupState();
}

class _SpecialCatGroupState extends State<_SpecialCatGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final types = kAllEventTypes
        .where((t) => t.category == widget.category && widget.allowedEventTypeIds.contains(t.id))
        .toList();
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
      if (_expanded) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(38, 0, 8, 4),
          child: Row(children: [
            TextButton(
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                  visualDensity: VisualDensity.compact),
              onPressed: () =>
                  widget.onToggleAll(types.map((t) => t.id).toList(), true),
              child: const Text('Enable All', style: TextStyle(fontSize: 11)),
            ),
            TextButton(
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                  visualDensity: VisualDensity.compact),
              onPressed: () =>
                  widget.onToggleAll(types.map((t) => t.id).toList(), false),
              child: const Text('Disable All', style: TextStyle(fontSize: 11)),
            ),
          ]),
        ),
        ...types.map((type) => _SpecialTypeRow(
              eventType: type,
              enabled: widget.enabledIds.contains(type.id),
              onToggle: (on) => widget.onToggle(type.id, on),
            )),
      ],
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
                        color: widget.enabled ? null : Colors.grey.shade600)),
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
                          color: Theme.of(context).cardColor,
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
          fillColor: Theme.of(context).cardColor,
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
// /appSettings/expenseCategories → { enabledTypeIds: [...] }
// /eventTypeConfig/{typeId}      → { expenseCategories: [...] }

class _ExpenseCategoriesSection extends StatefulWidget {
  final Set<EventCategory> allowedCategories;
  final Set<String> allowedEventTypeIds;
  const _ExpenseCategoriesSection({required this.allowedCategories, required this.allowedEventTypeIds});
  @override
  State<_ExpenseCategoriesSection> createState() => _ExpenseCategoriesSectionState();
}

class _ExpenseCategoriesSectionState extends State<_ExpenseCategoriesSection> {
  bool _expanded = false;

  static final _ref = FirebaseFirestore.instance
      .collection('appSettings')
      .doc('expenseCategories');

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

        void toggleAllIds(List<String> ids, bool on) {
          final updated = Set<String>.from(enabledIds);
          on ? updated.addAll(ids) : updated.removeAll(ids);
          _ref.set({'enabledTypeIds': updated.toList()});
        }

        final categories = EventCategory.values
            .where((cat) =>
                widget.allowedCategories.contains(cat) &&
                kAllEventTypes.any((t) => t.category == cat))
            .toList();

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
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
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Expense Categories',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(
                        totalSelected == 0
                            ? 'Not enabled for any event'
                            : '$totalSelected event type${totalSelected == 1 ? '' : 's'} enabled',
                        style: TextStyle(fontSize: 11,
                            color: totalSelected > 0 ? AppTheme.accent.shade400 : Colors.grey.shade400),
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
                    'Select which events track expenses. Each enabled event type has its own '
                    'category list — changes appear when adding expenses for that event.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400, height: 1.4),
                  )),
                ]),
              ),
              ...categories.map((cat) => _ExpCategoryGroup(
                    category: cat,
                    enabledIds: enabledIds,
                    onToggle: toggleId,
                    onToggleAll: toggleAllIds,
                    allowedEventTypeIds: widget.allowedEventTypeIds,
                  )),
              const SizedBox(height: 8),
            ],
          ]),
        );
      },
    );
  }
}

// ── Per-category group ────────────────────────────────────────────────────────

class _ExpCategoryGroup extends StatefulWidget {
  final EventCategory category;
  final List<String> enabledIds;
  final void Function(String, bool) onToggle;
  final void Function(List<String>, bool) onToggleAll;
  final Set<String> allowedEventTypeIds;
  const _ExpCategoryGroup({
    required this.category,
    required this.enabledIds,
    required this.onToggle,
    required this.onToggleAll,
    required this.allowedEventTypeIds,
  });
  @override
  State<_ExpCategoryGroup> createState() => _ExpCategoryGroupState();
}

class _ExpCategoryGroupState extends State<_ExpCategoryGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final types = kAllEventTypes
        .where((t) => t.category == widget.category && widget.allowedEventTypeIds.contains(t.id))
        .toList();
    final selectedCount = types.where((t) => widget.enabledIds.contains(t.id)).length;
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
            if (selectedCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accent.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$selectedCount/${types.length}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                        color: AppTheme.accent.shade600)),
              ),
            const SizedBox(width: 4),
            Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                size: 18, color: Colors.grey.shade400),
          ]),
        ),
      ),
      if (_expanded) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(38, 0, 8, 4),
          child: Row(children: [
            TextButton(
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                  visualDensity: VisualDensity.compact),
              onPressed: () =>
                  widget.onToggleAll(types.map((t) => t.id).toList(), true),
              child: const Text('Enable All', style: TextStyle(fontSize: 11)),
            ),
            TextButton(
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                  visualDensity: VisualDensity.compact),
              onPressed: () =>
                  widget.onToggleAll(types.map((t) => t.id).toList(), false),
              child: const Text('Disable All', style: TextStyle(fontSize: 11)),
            ),
          ]),
        ),
        ...types.map((type) => _ExpTypeEditor(
              eventType: type,
              enabled: widget.enabledIds.contains(type.id),
              onToggle: (on) => widget.onToggle(type.id, on),
            )),
      ],
      const Divider(height: 1, indent: 16, endIndent: 16),
    ]);
  }
}

// ── Per-event-type category editor ───────────────────────────────────────────

class _ExpTypeEditor extends StatefulWidget {
  final EventTypeData eventType;
  final bool enabled;
  final void Function(bool) onToggle;
  const _ExpTypeEditor({required this.eventType, required this.enabled, required this.onToggle});
  @override
  State<_ExpTypeEditor> createState() => _ExpTypeEditorState();
}

class _ExpTypeEditorState extends State<_ExpTypeEditor> {
  bool _configExpanded = false;
  bool _seeding = false;

  DocumentReference get _ref => eventTypeCategoriesRef(widget.eventType.id);

  Future<void> _seed() async {
    setState(() => _seeding = true);
    final snap = await _ref.get();
    final data = snap.data() as Map<String, dynamic>? ?? {};
    if (data['expenseCategories'] == null) {
      final defaults = widget.eventType.expenseCategories
          .map((e) => Map<String, dynamic>.from(e)).toList();
      await _ref.set({'expenseCategories': defaults});
    }
    if (mounted) setState(() => _seeding = false);
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
              decoration: BoxDecoration(color: AppTheme.accent.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accent.shade200)),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
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

  // Adds back any missing built-in default categories/sub-categories without
  // touching custom ones the admin already added.
  Future<void> _resetDefaults(List<Map<String, dynamic>> current) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Defaults?'),
        content: const Text('This adds back any missing default categories and sub-categories. Your custom categories are kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Restore', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (ok != true) return;
    final defaults = widget.eventType.expenseCategories
        .map((e) => Map<String, dynamic>.from(e)).toList();
    final merged = List<Map<String, dynamic>>.from(current.map((c) => Map<String, dynamic>.from(c)));
    for (final def in defaults) {
      final defName = def['name'] as String;
      final idx = merged.indexWhere((c) => c['name'] == defName);
      if (idx == -1) {
        merged.add(Map<String, dynamic>.from(def));
      } else {
        final existingSubs = List<String>.from(merged[idx]['subCategories'] as List? ?? []);
        final defSubs = List<String>.from(def['subCategories'] as List? ?? []);
        final mergedSubs = List<String>.from(existingSubs);
        for (final s in defSubs) {
          if (!mergedSubs.contains(s)) mergedSubs.add(s);
        }
        merged[idx] = {...merged[idx], 'subCategories': mergedSubs};
      }
    }
    await _write(merged);
  }

  // Removes ALL custom categories/sub-categories, keeping only the built-in
  // defaults for this event type. Destructive — used to fully start over.
  Future<void> _resetToFactoryDefaults(List<Map<String, dynamic>> current) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset to Factory Defaults?'),
        content: const Text('This removes ALL custom categories and sub-categories, keeping only the built-in defaults for this event type. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
                    color: current == e ? AppTheme.accent.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: current == e ? AppTheme.accent.shade300 : Colors.transparent),
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
        if (widget.enabled && notSeeded && _configExpanded && !_seeding) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _seed());
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Event type header: checkbox + name + config expand (if enabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 6, 12, 6),
            child: Row(children: [
              Text(widget.eventType.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.eventType.name,
                  style: TextStyle(fontSize: 13,
                      fontWeight: widget.enabled ? FontWeight.w600 : FontWeight.normal,
                      color: widget.enabled ? null : Colors.grey.shade700))),
              if (widget.enabled)
                GestureDetector(
                  onTap: () => setState(() => _configExpanded = !_configExpanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Configure',
                          style: TextStyle(fontSize: 10, color: AppTheme.accent.shade400,
                              fontWeight: FontWeight.w600)),
                      Icon(_configExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 14, color: AppTheme.accent.shade400),
                    ]),
                  ),
                ),
              Checkbox(
                value: widget.enabled,
                activeColor: AppTheme.accent,
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

          if (widget.enabled && _configExpanded) ...[
            if (_seeding)
              const Padding(
                padding: EdgeInsets.fromLTRB(32, 8, 16, 8),
                child: Center(child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accent.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accent.shade100),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ...cats.map((cat) {
                    final subs = List<String>.from(cat['subCategories'] as List? ?? []);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
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
                                    color: Theme.of(context).cardColor,
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
                            padding: const EdgeInsets.only(left: 20),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.add, size: 12, color: AppTheme.accent.shade300),
                              const SizedBox(width: 3),
                              Text('Add sub-category',
                                  style: TextStyle(fontSize: 10, color: AppTheme.accent.shade300)),
                            ]),
                          ),
                        ),
                      ]),
                    );
                  }),
                  const SizedBox(height: 4),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    GestureDetector(
                      onTap: () => _addCategory(cats),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add, size: 13, color: AppTheme.accent.shade600),
                          const SizedBox(width: 4),
                          Text('Add category',
                              style: TextStyle(fontSize: 11, color: AppTheme.accent.shade600,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
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
                    GestureDetector(
                      onTap: () => _resetToFactoryDefaults(cats),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.restart_alt, size: 13, color: Colors.red.shade700),
                          const SizedBox(width: 4),
                          Text('Factory Reset',
                              style: TextStyle(fontSize: 11, color: Colors.red.shade700,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ]),
                ]),
              ),
          ],
          const Divider(height: 1, indent: 32, endIndent: 16),
        ]);
      },
    );
  }
}

// ── Volunteer Roles Section ───────────────────────────────────────────────────
// /appSettings/volunteerRoles → { enabledTypeIds: [...] }
// /eventTypeConfig/{typeId}   → { volunteerRoles: [...] }

class _VolunteerRolesSection extends StatefulWidget {
  final Set<EventCategory> allowedCategories;
  final Set<String> allowedEventTypeIds;
  const _VolunteerRolesSection({required this.allowedCategories, required this.allowedEventTypeIds});
  @override
  State<_VolunteerRolesSection> createState() => _VolunteerRolesSectionState();
}

class _VolunteerRolesSectionState extends State<_VolunteerRolesSection> {
  bool _expanded = false;

  static final _ref = FirebaseFirestore.instance
      .collection('appSettings')
      .doc('volunteerRoles');

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

        void toggleAllIds(List<String> ids, bool on) {
          final updated = Set<String>.from(enabledIds);
          on ? updated.addAll(ids) : updated.removeAll(ids);
          _ref.set({'enabledTypeIds': updated.toList()});
        }

        final categories = EventCategory.values
            .where((cat) => widget.allowedCategories.contains(cat))
            .toList();

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
                    Text(
                      totalSelected == 0
                          ? 'Not enabled for any event'
                          : '$totalSelected event type${totalSelected == 1 ? '' : 's'} enabled',
                      style: TextStyle(fontSize: 11,
                          color: totalSelected > 0 ? Colors.teal.shade600 : Colors.grey.shade500),
                    ),
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
                  'Select which events allow volunteer sign-ups. Roles are the defaults offered '
                  'when volunteers sign up for each enabled event type.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400, height: 1.4),
                ),
              ),
              ...categories.map((cat) => _VolRoleCatGroup(
                    category: cat,
                    enabledIds: enabledIds,
                    onToggle: toggleId,
                    onToggleAll: toggleAllIds,
                    allowedEventTypeIds: widget.allowedEventTypeIds,
                  )),
              const SizedBox(height: 8),
            ],
          ]),
        );
      },
    );
  }
}

class _VolRoleCatGroup extends StatefulWidget {
  final EventCategory category;
  final List<String> enabledIds;
  final void Function(String, bool) onToggle;
  final void Function(List<String>, bool) onToggleAll;
  final Set<String> allowedEventTypeIds;
  const _VolRoleCatGroup({
    required this.category,
    required this.enabledIds,
    required this.onToggle,
    required this.onToggleAll,
    required this.allowedEventTypeIds,
  });
  @override
  State<_VolRoleCatGroup> createState() => _VolRoleCatGroupState();
}

class _VolRoleCatGroupState extends State<_VolRoleCatGroup> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final types = kAllEventTypes
        .where((t) => t.category == widget.category && widget.allowedEventTypeIds.contains(t.id))
        .toList();
    if (types.isEmpty) return const SizedBox.shrink();
    final selectedCount = types.where((t) => widget.enabledIds.contains(t.id)).length;
    final label = widget.category.label;
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
            if (selectedCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$selectedCount/${types.length}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                        color: Colors.teal.shade700)),
              ),
            const SizedBox(width: 4),
            Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                size: 18, color: Colors.grey.shade400),
          ]),
        ),
      ),
      if (_expanded) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(38, 0, 8, 4),
          child: Row(children: [
            TextButton(
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                  visualDensity: VisualDensity.compact),
              onPressed: () =>
                  widget.onToggleAll(types.map((t) => t.id).toList(), true),
              child: const Text('Enable All', style: TextStyle(fontSize: 11)),
            ),
            TextButton(
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                  visualDensity: VisualDensity.compact),
              onPressed: () =>
                  widget.onToggleAll(types.map((t) => t.id).toList(), false),
              child: const Text('Disable All', style: TextStyle(fontSize: 11)),
            ),
          ]),
        ),
        ...types.map((type) => _VolRoleTypeEditor(
              eventType: type,
              enabled: widget.enabledIds.contains(type.id),
              onToggle: (on) => widget.onToggle(type.id, on),
            )),
      ],
      const Divider(height: 1, indent: 16, endIndent: 16),
    ]);
  }
}

class _VolRoleTypeEditor extends StatefulWidget {
  final EventTypeData eventType;
  final bool enabled;
  final void Function(bool) onToggle;
  const _VolRoleTypeEditor({required this.eventType, required this.enabled, required this.onToggle});
  @override
  State<_VolRoleTypeEditor> createState() => _VolRoleTypeEditorState();
}

class _VolRoleTypeEditorState extends State<_VolRoleTypeEditor> {
  bool _configExpanded = false;

  DocumentReference get _ref => FirebaseFirestore.instance
      .collection('eventTypeConfig').doc(widget.eventType.id);

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
        final displayRoles = notSeeded ? _kDefaultVolRoles : roles;

        if (widget.enabled && notSeeded && _configExpanded) {
          WidgetsBinding.instance.addPostFrameCallback((_) =>
              _ref.set({'volunteerRoles': _kDefaultVolRoles}, SetOptions(merge: true)));
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 6, 12, 6),
            child: Row(children: [
              Text(widget.eventType.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.eventType.name,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700))),
              if (widget.enabled)
                GestureDetector(
                  onTap: () => setState(() => _configExpanded = !_configExpanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Configure',
                          style: TextStyle(fontSize: 10, color: Colors.teal.shade600,
                              fontWeight: FontWeight.w600)),
                      Icon(_configExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 14, color: Colors.teal.shade600),
                    ]),
                  ),
                ),
              Checkbox(
                value: widget.enabled,
                activeColor: Colors.teal,
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
          if (widget.enabled && _configExpanded) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.shade100),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: displayRoles.map((role) {
                    return GestureDetector(
                      onTap: () => _renameRole(List<String>.from(displayRoles), role),
                      onLongPress: () => _deleteRole(List<String>.from(displayRoles), role),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(role, style: TextStyle(fontSize: 11,
                              color: Colors.teal.shade800, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 4),
                          Icon(Icons.edit, size: 10, color: Colors.teal.shade300),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  GestureDetector(
                    onTap: () => _addRole(List<String>.from(displayRoles)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
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
                    onTap: () => _resetDefaults(List<String>.from(displayRoles)),
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
                const SizedBox(height: 4),
                Text('Tap to rename · Long press to delete',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              ]),
            ),
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
