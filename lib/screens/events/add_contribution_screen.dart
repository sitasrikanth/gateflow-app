import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'event_types.dart' show kSuggestedContributionAmounts;

// Contribution types
const String kTypeRegular = 'Regular Contribution';
const String kTypeSpecial = 'Special Contribution';
const String kTypeSponsor = 'Sponsorship';
const String kTypeExternal = 'External Donation';
// kTypeCarryForward is used by the Carry Forward Balance screen
// (carry_forward_screen.dart) to tag amounts brought in from another event.
const String kTypeCarryForward = 'Carry Forward (Previous Year)';
// Legacy type (kept for backward-compat read; no longer shown in UI)
const String kTypeGaneshLaddu = 'Ganesh Laddu (Previous Year)';

class AddContributionScreen extends StatefulWidget {
  final String eventId;
  final String eventTypeId;
  final String? existingDocId;
  final Map<String, dynamic>? existingData;
  final String? prefillFlat;
  final String? prefillWing;
  final String? prefillBlock;

  const AddContributionScreen({
    super.key,
    required this.eventId,
    this.eventTypeId = '',
    this.existingDocId,
    this.existingData,
    this.prefillFlat,
    this.prefillWing,
    this.prefillBlock,
  });

  @override
  State<AddContributionScreen> createState() =>
      _AddContributionScreenState();
}

class _AddContributionScreenState extends State<AddContributionScreen> {
  final _flatController = TextEditingController();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _noteController = TextEditingController();
  final _specialDescController = TextEditingController();
  final _sponsorItemController = TextEditingController();

  String _wing = '';
  String _block = '';
  String _contributionType = kTypeRegular;
  bool _amountReceived = true;
  String _paymentMode = 'Cash';
  DateTime _paidDate = DateTime.now();
  bool _isAnonymous = false;
  bool _saving = false;
  String _error = '';
  String _externalDonationHint = 'e.g. ACT Broadband';
  StreamSubscription<DocumentSnapshot>? _settingsSub;
  List<String> _paymentModes = ['Cash', 'UPI', 'Bank Transfer', 'Cheque'];

  double _expectedPerFlat = 0;
  double _paidSoFarForFlat = 0;
  String _balanceFlat = '';
  String _sponsorPackageName = '';

  bool get _isEditing => widget.existingDocId != null;
  bool get _isSpecialType => _contributionType == kTypeSpecial;
  // External donors (broadband company, builder, store, etc.) have no flat —
  // wing/block/flat selection is skipped entirely for this type.
  bool get _isExternalType => _contributionType == kTypeExternal;
  double get _remainingBalance =>
      (_expectedPerFlat - _paidSoFarForFlat).clamp(0, double.infinity);

  static const _kDefaultPaymentModes = ['Cash', 'UPI', 'PhonePe', 'Google Pay', 'Bank Transfer', 'NEFT / RTGS', 'Cheque', 'Other'];
  final Set<String> _requiresReference = {'UPI', 'PhonePe', 'Google Pay', 'Bank Transfer', 'NEFT / RTGS', 'Cheque'};
  bool get _needsReference => _requiresReference.contains(_paymentMode);

  String get _referenceLabel {
    if (_paymentMode == 'Cheque') return 'Cheque Number (Optional)';
    if (_paymentMode == 'Cash' || _paymentMode == 'Other') return 'Reference ID (Optional)';
    return '$_paymentMode Reference / Transaction ID (Optional)';
  }

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
    final d = widget.existingData;
    if (d != null) {
      _wing = d['wing'] ?? '';
      _block = d['block'] ?? '';
      _flatController.text = d['flatNumber'] ?? '';
    } else {
      _wing = widget.prefillWing ?? '';
      _block = widget.prefillBlock ?? '';
      _flatController.text = widget.prefillFlat ?? '';
    }
    if (d != null) {
      _nameController.text = d['residentName'] ?? '';
      _amountController.text = (d['amount'] ?? 0).toStringAsFixed(0);
      // Normalize legacy types
      final rawType = d['contributionType'] as String? ?? kTypeRegular;
      if (rawType == 'Regular') {
        _contributionType = kTypeRegular;
      } else if (rawType == kTypeCarryForward || rawType == kTypeGaneshLaddu) {
        _contributionType = kTypeSpecial;
      } else {
        _contributionType = rawType;
      }
      _amountReceived = d['amountReceived'] ?? true;
      _paymentMode = d['paymentMode'] ?? 'Cash';
      _isAnonymous = d['isAnonymous'] == true;
      _sponsorPackageName = d['sponsorPackageName'] ?? '';
      _sponsorItemController.text = d['sponsorItem'] ?? '';
      _referenceController.text = d['referenceId'] ?? '';
      _noteController.text = d['note'] ?? '';
      _specialDescController.text = d['specialDescription'] ?? '';
      if ((d['paidAt'] ?? '').isNotEmpty) {
        _paidDate = DateTime.tryParse(d['paidAt']) ?? DateTime.now();
      }
    }
    _settingsSub = FirebaseFirestore.instance
        .collection('community_settings')
        .doc('address')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final d = snap.data() as Map<String, dynamic>? ?? {};
      final modes = d['paymentModes'] is List
          ? List<String>.from(d['paymentModes'] as List)
          : List<String>.from(_kDefaultPaymentModes);
      setState(() {
        _paymentModes = modes;
        if (!modes.contains(_paymentMode)) _paymentMode = modes.first;
        _externalDonationHint =
            d['externalDonationHint'] as String? ?? 'e.g. ACT Broadband';
      });
    });
    // Load per-event-type config (default note + special descriptions)
    if (widget.eventTypeId.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('eventTypeConfig')
          .doc(widget.eventTypeId)
          .get()
          .then((snap) {
        if (!mounted) return;
        final d = snap.data() as Map<String, dynamic>? ?? {};
        final note = d['specialDefaultNote'] as String? ?? '';
        if (widget.existingData == null && note.isNotEmpty && _noteController.text.isEmpty) {
          setState(() => _noteController.text = note);
        }
      });
    }
    // Remaining-balance tracking (new entries only — editing shouldn't nudge
    // toward a "remaining" amount computed against itself).
    if (!_isEditing) {
      _flatController.addListener(_onFlatChanged);
      FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .get()
          .then((snap) {
        if (!mounted) return;
        final expected = (snap.data()?['expectedAmountPerFlat'] as num?)?.toDouble() ?? 0;
        if (expected > 0) {
          setState(() => _expectedPerFlat = expected);
          _onFlatChanged();
        }
      });
    }
  }

  void _onFlatChanged() {
    final flat = _flatController.text.trim();
    if (_expectedPerFlat <= 0 || flat.isEmpty || flat == _balanceFlat) return;
    _balanceFlat = flat;
    FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .collection('contributions')
        .where('flatNumber', isEqualTo: flat)
        .get()
        .then((snap) {
      if (!mounted || _flatController.text.trim() != flat) return;
      final paid = snap.docs
          .where((d) => d.data()['amountReceived'] == true && d.data()['status'] != 'deleted')
          .fold<double>(0, (total, d) => total + ((d.data()['amount'] as num?)?.toDouble() ?? 0));
      setState(() => _paidSoFarForFlat = paid);
    });
  }

  @override
  void dispose() {
    _flatController.removeListener(_onFlatChanged);
    _amountController.removeListener(_onAmountChanged);
    _settingsSub?.cancel();
    _flatController.dispose();
    _nameController.dispose();
    _amountController.dispose();
    _referenceController.dispose();
    _noteController.dispose();
    _specialDescController.dispose();
    _sponsorItemController.dispose();
    super.dispose();
  }

  void _onAmountChanged() => setState(() {});

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.green)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _paidDate = picked);
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.day == now.day && d.month == now.month && d.year == now.year;
  }

  Future<void> _save() async {
    if (_isExternalType) {
      if (_nameController.text.trim().isEmpty) {
        setState(() => _error = 'Please enter donor / organization name');
        return;
      }
    } else if (_contributionType == kTypeSponsor) {
      // Wing/Block/Flat are fully optional for sponsors — a sponsor may be
      // an outside business with no address at all, or a resident who
      // wants only some of it recorded (e.g. just their flat, no wing).
    } else {
      if (_wing.isEmpty) {
        setState(() => _error = 'Please select a Wing');
        return;
      }
      if (_block.isEmpty) {
        setState(() => _error = 'Please select a Block');
        return;
      }
      if (_flatController.text.trim().isEmpty) {
        setState(() => _error = 'Please enter flat number');
        return;
      }
    }
    if (_amountController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter amount');
      return;
    }
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid amount');
      return;
    }

    setState(() { _saving = true; _error = ''; });

    try {
      final firestore = FirebaseFirestore.instance;
      final flat = _isExternalType ? '' : _flatController.text.trim();
      final fullAddress = _isExternalType
          ? 'External Donation'
          : '$_wing Wing - $_block Block - Flat $flat';

      final payload = {
        'wing': _isExternalType ? '' : _wing,
        'block': _isExternalType ? '' : _block,
        'flatNumber': flat,
        'fullAddress': fullAddress,
        'residentName': _nameController.text.trim(),
        'amount': amount,
        'contributionType': _contributionType,
        // For carry forward / Ganesh Laddu: track if the amount was received
        'amountReceived': _isSpecialType ? _amountReceived : true,
        'paymentMode': _isSpecialType && !_amountReceived ? 'Pending' : _paymentMode,
        // Identity (flat/name) is still recorded for accounting & block-wise
        // tracking; isAnonymous only hides the name in resident-facing views
        // like the future Leaderboard and admin's contribution list badge.
        'isAnonymous': _isAnonymous,
        'sponsorPackageName':
            _contributionType == kTypeSponsor ? _sponsorPackageName : '',
        'sponsorItem': _contributionType == kTypeSponsor
            ? _sponsorItemController.text.trim()
            : '',
        'referenceId': _referenceController.text.trim(),
        'note': _noteController.text.trim(),
        'specialDescription': _isSpecialType ? _specialDescController.text.trim() : '',
        'paidAt': _paidDate.toIso8601String(),
        'paidDate': _formatDate(_paidDate),
      };

      final eventRef = firestore.collection('events').doc(widget.eventId);

      if (_isEditing) {
        final oldAmount = (widget.existingData!['amount'] ?? 0).toDouble();
        final oldReceived = widget.existingData!['amountReceived'] ?? true;
        final batch = firestore.batch();
        batch.update(
          eventRef.collection('contributions').doc(widget.existingDocId),
          payload,
        );
        // Only adjust totalCollected if the received status or amount changed
        final wasCountedBefore = !_isSpecialType || oldReceived;
        final isCountedNow = !_isSpecialType || _amountReceived;
        double diff = 0;
        if (wasCountedBefore && isCountedNow) diff = amount - oldAmount;
        else if (wasCountedBefore && !isCountedNow) diff = -oldAmount;
        else if (!wasCountedBefore && isCountedNow) diff = amount;
        if (diff != 0) {
          batch.update(eventRef, {'totalCollected': FieldValue.increment(diff)});
        }
        await batch.commit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Contribution updated ✅'),
            backgroundColor: Colors.green,
          ));
          Navigator.pop(context);
        }
      } else {
        final batch = firestore.batch();
        // Real add-time, distinct from paidAt (a date-only field the admin
        // picks) — lets Activity show an accurate time instead of 00:00.
        payload['createdAt'] = DateTime.now().toIso8601String();
        batch.set(eventRef.collection('contributions').doc(), payload);
        // Only add to totalCollected if received (or regular contribution)
        if (!_isSpecialType || _amountReceived) {
          batch.update(eventRef, {'totalCollected': FieldValue.increment(amount)});
        }
        await batch.commit();
        if (mounted) {
          final status = _isSpecialType
              ? (_amountReceived ? 'Received ✅' : 'Pending ⏳')
              : '✅';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('₹${amount.toStringAsFixed(0)} — $fullAddress $status'),
            backgroundColor: Colors.green,
          ));
          _flatController.clear();
          _nameController.clear();
          _amountController.clear();
          _referenceController.clear();
          _noteController.clear();
          setState(() {
            _wing = '';
            _block = '';
            _contributionType = kTypeRegular;
            _amountReceived = true;
            _paymentMode = 'Cash';
            _paidDate = DateTime.now();
            _saving = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = 'Failed: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Contribution' : 'Record Contribution',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: widget.eventTypeId.isNotEmpty
            ? FirebaseFirestore.instance
                .collection('appSettings')
                .doc('specialContribution')
                .snapshots()
            : const Stream.empty(),
        builder: (context, specialSnap) {
          final specialData = specialSnap.data?.data() as Map<String, dynamic>? ?? {};
          final specialEnabledIds = List<String>.from(specialData['enabledTypeIds'] as List? ?? []);
          // If no config yet (stream empty / loading), default to showing special for all
          final specialAvailable = widget.eventTypeId.isEmpty ||
              specialSnap.connectionState == ConnectionState.waiting ||
              specialEnabledIds.contains(widget.eventTypeId);

          return StreamBuilder<DocumentSnapshot>(
        stream: widget.eventTypeId.isNotEmpty
            ? FirebaseFirestore.instance
                .collection('appSettings')
                .doc('sponsorPackages')
                .snapshots()
            : const Stream.empty(),
        builder: (context, sponsorSettingsSnap) {
          final sponsorSettingsData =
              sponsorSettingsSnap.data?.data() as Map<String, dynamic>? ?? {};
          final sponsorEnabledIds =
              List<String>.from(sponsorSettingsData['enabledTypeIds'] as List? ?? []);
          final sponsorTypeAvailable = sponsorEnabledIds.contains(widget.eventTypeId);

          return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('events').doc(widget.eventId).snapshots(),
        builder: (context, eventSnap) {
          final eventRaw = (eventSnap.data?.data() as Map<String, dynamic>?)?['sponsorPackages'];
          final sponsorPackages = eventRaw != null
              ? List<Map<String, dynamic>>.from(
                  (eventRaw as List).map((e) => Map<String, dynamic>.from(e as Map)))
              : <Map<String, dynamic>>[];
          final sponsorAvailable = sponsorTypeAvailable && sponsorPackages.isNotEmpty;

          return StreamBuilder<DocumentSnapshot>(
        stream: widget.eventTypeId.isNotEmpty
            ? FirebaseFirestore.instance
                .collection('eventTypeConfig')
                .doc(widget.eventTypeId)
                .snapshots()
            : const Stream.empty(),
        builder: (context, typeSnap) {
          final typeData = typeSnap.data?.data() as Map<String, dynamic>? ?? {};
          final presetDescs = List<String>.from(typeData['specialDescriptions'] as List? ?? []);

          return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('community_settings')
            .doc('address')
            .snapshots(),
        builder: (context, snap) {
          final settings = snap.data?.data() as Map<String, dynamic>? ?? {};
          final wings = List<String>.from(settings['wings'] ?? []);
          final wingBlocksMap =
              Map<String, dynamic>.from(settings['wingBlocks'] ?? {});

          // Extract block names — wingBlocks[wing] is now Map<block, List<flat>>
          List<String> _blocksFor(String wing) {
            if (wing.isEmpty) return [];
            final raw = wingBlocksMap[wing];
            if (raw is Map) return (raw.keys.cast<String>().toList())..sort();
            if (raw is List) return List<String>.from(raw)..sort(); // legacy
            return [];
          }

          // Extract flat numbers for the selected block
          List<String> _flatsFor(String wing, String block) {
            if (wing.isEmpty || block.isEmpty) return [];
            final raw = wingBlocksMap[wing];
            if (raw is Map) {
              final blockData = raw[block];
              if (blockData is List)
                return List<String>.from(blockData)..sort();
            }
            return [];
          }

          final blocksForWing = _blocksFor(_wing);
          final flatsForBlock = _flatsFor(_wing, _block);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Contribution Type ────────────────────────────
                // Always shown now — External Donation is always available
                // to admin regardless of the Special/Sponsor settings.
                _label('Contribution Type *'),
                const SizedBox(height: 8),
                _typeSelector(sponsorAvailable: sponsorAvailable, specialAvailable: specialAvailable),
                const SizedBox(height: 16),

                // ── Sponsor tier picker ────────────────────────────
                if (_contributionType == kTypeSponsor && sponsorAvailable) ...[
                  _label('Sponsor Item *'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sponsorPackages.map((p) {
                      final name = p['name'] as String? ?? '';
                      final pAmount = (p['amount'] as num?)?.toDouble() ?? 0;
                      final sel = _sponsorPackageName == name;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _sponsorPackageName = name;
                          // Only auto-fill if the item has a preset amount —
                          // items without one (e.g. a donated idol) leave the
                          // actual amount for the admin to enter themselves.
                          if (pAmount > 0) {
                            _amountController.text = pAmount.toStringAsFixed(0);
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: sel ? Colors.amber.shade600 : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: sel ? Colors.amber.shade600 : Colors.amber.shade200),
                          ),
                          child: Text(
                              pAmount > 0 ? '$name · ₹${pAmount.toStringAsFixed(0)}' : name,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : Colors.amber.shade800)),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_sponsorPackageName.isNotEmpty)
                    Builder(builder: (_) {
                      final perks = sponsorPackages.firstWhere(
                          (p) => p['name'] == _sponsorPackageName,
                          orElse: () => {})['perks'] as String? ?? '';
                      if (perks.isEmpty) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Perks: $perks',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      );
                    }),
                  const SizedBox(height: 16),
                  _label('What are they sponsoring? (Optional)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _sponsorItemController,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        _dec('e.g. Idol, Flowers, Decorations', Icons.redeem_outlined),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Special type status (received / pending) ─────
                if (_isSpecialType && specialAvailable) ...[
                  _specialStatusCard(),
                  const SizedBox(height: 16),
                  _label('Special Contribution Description *'),
                  const SizedBox(height: 8),
                  // Preset description chips
                  if (presetDescs.isNotEmpty) ...[
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: presetDescs.map((desc) => GestureDetector(
                        onTap: () => setState(() => _specialDescController.text = desc),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _specialDescController.text == desc
                                ? Colors.purple.shade100 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _specialDescController.text == desc
                                  ? Colors.purple.shade400 : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(desc,
                              style: TextStyle(fontSize: 12,
                                  color: _specialDescController.text == desc
                                      ? Colors.purple.shade800 : Colors.grey.shade700,
                                  fontWeight: _specialDescController.text == desc
                                      ? FontWeight.w600 : FontWeight.normal)),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: _specialDescController,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: presetDescs.isEmpty
                          ? 'e.g. Carry Forward from last year, Ganesh Laddu donation…'
                          : 'Or type a custom description…',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.purple, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (!_isExternalType) ...[
                // ── Wing ─────────────────────────────────────────
                _label(_contributionType == kTypeSponsor ? 'Wing (Optional)' : 'Wing *'),
                const SizedBox(height: 8),
                wings.isEmpty
                    ? _hint('No wings configured — go to Admin → Settings')
                    : _chips(
                        items: wings,
                        selected: _wing,
                        activeColor: Colors.blue.shade600,
                        onTap: (w) => setState(() {
                          _wing = w;
                          _block = '';
                          _flatController.clear();
                        }),
                      ),
                const SizedBox(height: 20),

                // ── Block (only for selected wing) ───────────────
                _label(_contributionType == kTypeSponsor ? 'Block (Optional)' : 'Block *'),
                const SizedBox(height: 8),
                _wing.isEmpty
                    ? _hint('Select a wing first to see its blocks')
                    : blocksForWing.isEmpty
                        ? _hint('No blocks for $_wing Wing — add in Settings')
                        : _chips(
                            items: blocksForWing,
                            selected: _block,
                            activeColor: Colors.purple.shade600,
                            onTap: (b) => setState(() {
                              _block = b;
                              _flatController.clear();
                            }),
                          ),
                const SizedBox(height: 20),

                // ── Flat number ───────────────────────────────────
                _label(_contributionType == kTypeSponsor
                    ? 'Flat Number (Optional)'
                    : 'Flat Number *'),
                const SizedBox(height: 8),
                if (_isEditing)
                  // Read-only when editing — flat cannot be changed
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.teal.shade400, width: 2),
                    ),
                    child: Row(children: [
                      Icon(Icons.home_outlined,
                          color: Colors.teal.shade600, size: 18),
                      const SizedBox(width: 8),
                      Text(_flatController.text,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade700,
                              fontSize: 14)),
                      const Spacer(),
                      Text('(locked)',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                    ]),
                  )
                else if (_block.isEmpty)
                  _hint('Select a block first to see its flats')
                else if (flatsForBlock.isEmpty)
                  // No flats configured — fall back to free text
                  TextField(
                    controller: _flatController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _dec('e.g. 101', Icons.home_outlined),
                  )
                else
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('community_settings')
                        .doc('address')
                        .snapshots(),
                    builder: (ctx, snap) {
                      final sd = snap.data?.data()
                              as Map<String, dynamic>? ??
                          {};
                      final rowsRaw = sd['flatGridRows'] is Map
                          ? sd['flatGridRows'] as Map<String, dynamic>
                          : <String, dynamic>{};
                      final rows = ((rowsRaw['${_wing}_${_block}']
                                  as num?)
                              ?.toInt() ??
                          1).clamp(1, 3);
                      return _flatGrid(
                        flats: flatsForBlock,
                        selected: _flatController.text,
                        rowsPerFloor: rows,
                        onTap: (flat) =>
                            setState(() => _flatController.text = flat),
                      );
                    },
                  ),
                if (_expectedPerFlat > 0 && _flatController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _remainingBalance > 0
                          ? Colors.blue.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _remainingBalance > 0
                              ? Colors.blue.shade100
                              : Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _remainingBalance > 0
                              ? Icons.account_balance_wallet_outlined
                              : Icons.check_circle_outline,
                          size: 18,
                          color: _remainingBalance > 0
                              ? Colors.blue.shade700
                              : Colors.green.shade700,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _remainingBalance > 0
                                ? 'Flat ${_flatController.text.trim()}: ₹${_paidSoFarForFlat.toStringAsFixed(0)} of ₹${_expectedPerFlat.toStringAsFixed(0)} paid · ₹${_remainingBalance.toStringAsFixed(0)} remaining'
                                : 'Flat ${_flatController.text.trim()} has fully paid the suggested ₹${_expectedPerFlat.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _remainingBalance > 0
                                    ? Colors.blue.shade800
                                    : Colors.green.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ], // end !_isExternalType

                // ── Resident / sponsor / donor name ────────────────
                _label(_contributionType == kTypeSponsor
                    ? 'Sponsor / Business Name'
                    : _isExternalType
                        ? 'Donor / Organization Name *'
                        : 'Resident Name (Optional)'),
                if (_isExternalType) ...[
                  const SizedBox(height: 4),
                  Text('e.g. Broadband provider, builder, store operator',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _dec(
                      _contributionType == kTypeSponsor
                          ? 'e.g. Sharma Electronics'
                          : _isExternalType
                              ? _externalDonationHint
                              : 'Optional',
                      Icons.person_outlined),
                ),
                const SizedBox(height: 12),
                _anonymousToggle(),
                const SizedBox(height: 20),

                // ── Amount ────────────────────────────────────────
                _label('Amount (₹) *'),
                const SizedBox(height: 4),
                if (!_isSpecialType)
                  Text('Enter the exact amount given by the resident',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'))
                  ],
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '0',
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Colors.green, width: 2),
                    ),
                  ),
                ),
                if (!_isSpecialType && _contributionType != kTypeSponsor) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_remainingBalance > 0)
                        _amountChip(
                          label: 'Pay Remaining (₹${_remainingBalance.toStringAsFixed(0)})',
                          value: _remainingBalance.toStringAsFixed(0),
                          color: Colors.blue,
                        ),
                      ...kSuggestedContributionAmounts.map((amt) => _amountChip(
                            label: '₹$amt',
                            value: '$amt',
                            color: Colors.green,
                          )),
                    ],
                  ),
                ],
                const SizedBox(height: 20),

                // ── Payment mode (only when received) ────────────
                if (!_isSpecialType || _amountReceived) ...[
                  _label('Payment Mode *'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _paymentModes.map((mode) {
                      final sel = _paymentMode == mode;
                      return ChoiceChip(
                        label: Text(mode),
                        selected: sel,
                        selectedColor: Colors.green.shade100,
                        labelStyle: TextStyle(
                          color: sel
                              ? Colors.green.shade800
                              : Colors.grey.shade700,
                          fontWeight:
                              sel ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (_) => setState(() {
                          _paymentMode = mode;
                          _referenceController.clear();
                        }),
                      );
                    }).toList(),
                  ),

                  if (_needsReference) ...[
                    const SizedBox(height: 20),
                    _label(_referenceLabel),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _referenceController,
                      decoration: _dec(
                          'e.g. UTR number, cheque no.', Icons.tag_outlined),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],

                // ── Date ─────────────────────────────────────────
                _label('Date *'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 20, color: Colors.green.shade600),
                        const SizedBox(width: 12),
                        Text(_formatDate(_paidDate),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Text(
                          _isToday(_paidDate) ? 'Today' : 'Tap to change',
                          style: TextStyle(
                              color: Colors.green.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Note ─────────────────────────────────────────
                _label('Note (Optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  decoration: _dec(
                      'e.g. Will pay on Chaturthi day', Icons.note_outlined),
                ),

                // ── Error ─────────────────────────────────────────
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade600, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error,
                              style: TextStyle(
                                  color: Colors.red.shade700, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSpecialType && !_amountReceived
                          ? Colors.orange
                          : Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Icon(_isSpecialType && !_amountReceived
                            ? Icons.hourglass_empty
                            : Icons.check),
                    label: Text(_saving
                        ? 'Saving...'
                        : _isEditing
                            ? 'Update Contribution'
                            : _isSpecialType && !_amountReceived
                                ? 'Save as Pending'
                                : 'Record Contribution'),
                  ),
                ),
                if (!_isEditing) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Form clears after save — add multiple entries',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ); // closes community_settings StreamBuilder
        },
      ); // closes eventTypeConfig StreamBuilder
        },
      ); // closes event(sponsorPackages list) StreamBuilder
        },
      ); // closes sponsorPackages settings StreamBuilder
        },
      ), // closes specialContribution StreamBuilder
    );
  }

  // ── Type selector ──────────────────────────────────────────────────────────

  Widget _typeSelector({bool sponsorAvailable = false, bool specialAvailable = true}) {
    final types = [
      {'type': kTypeRegular, 'icon': Icons.payments_outlined, 'color': Colors.green,
       'desc': 'Standard contribution for this event'},
      if (specialAvailable)
        {'type': kTypeSpecial, 'icon': Icons.star_outline, 'color': Colors.purple,
         'desc': 'Ganesh Laddu or other special amount'},
      if (sponsorAvailable)
        {'type': kTypeSponsor, 'icon': Icons.workspace_premium_outlined, 'color': Colors.amber.shade800,
         'desc': 'Business or individual sponsor at a defined tier'},
      {'type': kTypeExternal, 'icon': Icons.corporate_fare_outlined, 'color': Colors.teal.shade700,
       'desc': 'Broadband company, builder, store, or other external donor'},
    ];
    // The previously-selected type may not be in this list (e.g. sponsor
    // stopped being available), so fall back to the first entry.
    final selected = types.firstWhere(
        (t) => t['type'] == _contributionType,
        orElse: () => types.first);
    final selColor = selected['color'] as Color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: selected['type'] as String,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: selColor, width: 2)),
          ),
          items: types.map((t) {
            final type = t['type'] as String;
            final icon = t['icon'] as IconData;
            final color = t['color'] as Color;
            return DropdownMenuItem<String>(
              value: type,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(type,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (type) {
            if (type == null) return;
            setState(() {
              _contributionType = type;
              // Special contributions (carry forward, Ganesh Laddu, etc.)
              // default to Pending since they're usually recorded before
              // the amount is actually confirmed received.
              _amountReceived = type != kTypeSpecial;
            });
          },
        ),
        const SizedBox(height: 6),
        Text(selected['desc'] as String,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }

  // ── Special type received/pending status card ──────────────────────────────

  Widget _specialStatusCard() {
    const label = 'Special Contribution Status';
    const desc = 'Has this flat already paid this special amount?';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _amountReceived
            ? Colors.green.shade50
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _amountReceived
                ? Colors.green.shade200
                : Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(desc,
              style:
                  TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _amountReceived = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _amountReceived
                          ? Colors.green
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _amountReceived
                              ? Colors.green
                              : Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle,
                            color: _amountReceived
                                ? Colors.white
                                : Colors.grey,
                            size: 18),
                        const SizedBox(width: 6),
                        Text('Received',
                            style: TextStyle(
                                color: _amountReceived
                                    ? Colors.white
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _amountReceived = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !_amountReceived
                          ? Colors.orange
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: !_amountReceived
                              ? Colors.orange
                              : Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.hourglass_empty,
                            color: !_amountReceived
                                ? Colors.white
                                : Colors.grey,
                            size: 18),
                        const SizedBox(width: 6),
                        Text('Pending',
                            style: TextStyle(
                                color: !_amountReceived
                                    ? Colors.white
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amountChip({
    required String label,
    required String value,
    required MaterialColor color,
  }) {
    final sel = _amountController.text.trim() == value;
    return GestureDetector(
      onTap: () => setState(() => _amountController.text = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? color.shade600 : color.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? color.shade600 : color.shade200),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : color.shade700)),
      ),
    );
  }

  Widget _anonymousToggle() {
    return GestureDetector(
      onTap: () => setState(() => _isAnonymous = !_isAnonymous),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _isAnonymous ? Colors.indigo.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: _isAnonymous ? Colors.indigo.shade200 : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.visibility_off_outlined,
                size: 18,
                color: _isAnonymous ? Colors.indigo.shade600 : Colors.grey.shade500),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Anonymous Contribution',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isAnonymous
                              ? Colors.indigo.shade700
                              : Colors.grey.shade700)),
                  Text('Name hidden from other residents; admins can still see it',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Switch(
              value: _isAnonymous,
              activeThumbColor: Colors.indigo,
              onChanged: (v) => setState(() => _isAnonymous = v),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Widget _label(String text) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.w600));

  Widget _hint(String msg) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(msg,
            style:
                TextStyle(color: Colors.orange.shade700, fontSize: 12)),
      );

  Widget _flatGrid({
    required List<String> flats,
    required String selected,
    required int rowsPerFloor,
    required void Function(String) onTap,
  }) {
    final color = Colors.teal.shade600;

    // Group flats by floor (hundreds digit: 101-112 → floor 1)
    final Map<int, List<String>> byFloor = {};
    for (final flat in flats) {
      final n = int.tryParse(flat.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final floor = n > 0 ? n ~/ 100 : 0;
      byFloor.putIfAbsent(floor, () => []).add(flat);
    }
    final floors = byFloor.keys.toList()..sort();

    Widget flatTile(String flat) {
      final isSel = selected == flat;
      return GestureDetector(
        onTap: () => onTap(flat),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSel ? color : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isSel ? color : Colors.grey.shade300),
          ),
          child: Text(
            flat,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: isSel ? Colors.white : Colors.grey.shade800,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: floors.map((floor) {
        final floorFlats = byFloor[floor]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Text(
                    'Floor $floor',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Divider(color: Colors.teal.shade100, height: 1)),
              ]),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              // Fixed small tile size — stays constant no matter how many
              // flats are on a floor or how the block rows are configured.
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 52,
                mainAxisExtent: 34,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: floorFlats.length,
              itemBuilder: (_, i) => flatTile(floorFlats[i]),
            ),
            const SizedBox(height: 4),
          ],
        );
      }).toList(),
    );
  }

  Widget _chips({
    required List<String> items,
    required String selected,
    required Color activeColor,
    required void Function(String) onTap,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final isSel = selected == item;
        return GestureDetector(
          onTap: () => onTap(item),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSel ? activeColor : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isSel ? activeColor : Colors.grey.shade300),
            ),
            child: Text(item,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSel ? Colors.white : Colors.grey.shade700,
                    fontSize: 14)),
          ),
        );
      }).toList(),
    );
  }

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.green, width: 2),
        ),
      );
}
