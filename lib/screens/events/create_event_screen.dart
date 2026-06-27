import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'event_types.dart';

final _eventTypeImagesRef = FirebaseFirestore.instance
    .collection('event_config')
    .doc('event_type_images');

class CreateEventScreen extends StatefulWidget {
  final String? existingEventId;
  final Map<String, dynamic>? existingData;
  final bool isAdmin;

  const CreateEventScreen({
    super.key,
    this.existingEventId,
    this.existingData,
    this.isAdmin = false,
  });

  bool get isEdit => existingEventId != null;

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen>
    with TickerProviderStateMixin {
  // ── Step control ─────────────────────────────────────────────────────────
  late final PageController _pageCtrl;
  int _step = 0; // 0 = type picker, 1 = details form

  // ── Type selection ───────────────────────────────────────────────────────
  EventTypeData? _selectedType;
  EventCategory _activeCategory = EventCategory.festive;
  late final TabController _tabCtrl;

  // ── Details form ─────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  String _startDate = '';
  String _endDate = '';
  bool _saving = false;
  bool _loading = false;
  String _error = '';
  File? _bannerFile;
  String? _existingBannerUrl;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _tabCtrl = TabController(
        length: EventCategory.values.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() =>
            _activeCategory = EventCategory.values[_tabCtrl.index]);
      }
    });

    if (widget.isEdit) {
      _step = 1; // skip picker in edit mode
      final d = widget.existingData ?? {};
      _prefill(d);
      final typeId = d['eventTypeId'] as String?;
      _selectedType = eventTypeById(typeId);
      if (d['name'] == null || (d['name'] as String).isEmpty) {
        _fetchAndPrefill();
      }
      // Jump page controller to step 1 after layout
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageCtrl.jumpToPage(1);
      });
    }
  }

  void _prefill(Map<String, dynamic> d) {
    _nameCtrl.text = (d['name'] as String?) ?? '';
    _descCtrl.text = (d['description'] as String?) ?? '';
    final target = (d['targetAmount'] as num?)?.toDouble() ?? 0;
    _targetCtrl.text = target > 0 ? target.toStringAsFixed(0) : '';
    _startDate = (d['startDate'] as String?) ?? '';
    _endDate = (d['endDate'] as String?) ?? '';
    _existingBannerUrl = d['bannerUrl'] as String?;
  }

  Future<void> _fetchAndPrefill() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.existingEventId)
          .get();
      if (snap.exists && mounted) {
        setState(() {
          _prefill(snap.data()!);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _tabCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _selectType(EventTypeData type) {
    setState(() {
      _selectedType = type;
      // Pre-fill name & description from type
      if (_nameCtrl.text.isEmpty) _nameCtrl.text = type.name;
      if (_descCtrl.text.isEmpty) _descCtrl.text = type.suggestedDescription;
    });
    _pageCtrl.animateToPage(1,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut);
    setState(() => _step = 1);
  }

  void _goBack() {
    if (_step == 1 && !widget.isEdit) {
      _pageCtrl.animateToPage(0,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOut);
      setState(() => _step = 0);
    } else {
      Navigator.pop(context);
    }
  }

  // ── Date picker ───────────────────────────────────────────────────────────

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: _selectedType != null
                ? _selectedType!.gradient.first
                : Colors.deepPurple,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        final f = '${picked.day}/${picked.month}/${picked.year}';
        if (isStart) { _startDate = f; } else { _endDate = f; }
      });
    }
  }

  // ── Banner image picker ───────────────────────────────────────────────────

  Future<void> _pickBanner() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1400,
    );
    if (picked != null && mounted) {
      setState(() => _bannerFile = File(picked.path));
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter event name');
      return;
    }
    setState(() { _saving = true; _error = ''; });

    final target = double.tryParse(_targetCtrl.text) ?? 0;

    try {
      final fs = FirebaseFirestore.instance;

      // Upload banner if selected
      String? bannerUrl = _existingBannerUrl;
      if (_bannerFile != null) {
        final eventId = widget.existingEventId ??
            fs.collection('events').doc().id;
        final ref = FirebaseStorage.instance
            .ref('event_banners/$eventId/banner.jpg');
        await ref.putFile(_bannerFile!);
        bannerUrl = await ref.getDownloadURL();
      }

      final payload = {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'targetAmount': target,
        'startDate': _startDate,
        'endDate': _endDate,
        'bannerUrl': bannerUrl ?? '',
        if (_selectedType != null) ...{
          'eventTypeId': _selectedType!.id,
          'eventTypeName': _selectedType!.name,
          'eventTypeEmoji': _selectedType!.emoji,
          'eventTypeGradient': _selectedType!.gradient
              .map((c) => c.toARGB32())
              .toList(),
          'eventCategory': _selectedType!.category.name,
        },
      };

      if (widget.isEdit) {
        await fs.collection('events').doc(widget.existingEventId).update(payload);
      } else {
        await fs.collection('events').add({
          ...payload,
          'totalCollected': 0,
          'totalSpent': 0,
          'status': 'active',
          'createdAt': DateTime.now().toIso8601String(),
          'createdBy': FirebaseAuth.instance.currentUser?.uid ?? '',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.isEdit ? 'Event updated ✅' : 'Event created ✅'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = 'Failed: $e'; });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accentColor = _selectedType?.gradient.first ?? Colors.deepPurple;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        title: Text(
          widget.isEdit
              ? 'Edit Event'
              : _step == 0
                  ? 'Choose Event Type'
                  : 'Event Details',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)),
            ),
        ],
        bottom: _step == 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: _buildTabBar(),
              )
            : null,
      ),
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildTypePicker(),
          _buildDetailsForm(accentColor),
        ],
      ),
    );
  }

  // ── Tab Bar (step 0) ─────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: (_selectedType?.gradient.first ?? Colors.deepPurple),
      child: TabBar(
        controller: _tabCtrl,
        isScrollable: true,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabAlignment: TabAlignment.start,
        tabs: EventCategory.values
            .map((c) => Tab(text: '${c.emoji} ${c.label}'))
            .toList(),
      ),
    );
  }

  // ── Step 0: Type Picker ──────────────────────────────────────────────────

  Widget _buildTypePicker() {
    final types = eventTypesByCategory(_activeCategory);

    return StreamBuilder<DocumentSnapshot>(
      stream: _eventTypeImagesRef.snapshots(),
      builder: (context, snap) {
        final customImages =
            (snap.data?.data() as Map<String, dynamic>?) ?? {};

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.82,
          ),
          itemCount: types.length,
          itemBuilder: (ctx, i) => _EventTypeCard(
            type: types[i],
            selected: _selectedType?.id == types[i].id,
            customImageUrl: customImages[types[i].id] as String?,
            isAdmin: widget.isAdmin,
            onTap: () => _selectType(types[i]),
            onUploadImage: () => _uploadCustomImage(types[i]),
          ),
        );
      },
    );
  }

  Future<void> _uploadCustomImage(EventTypeData type) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked == null || !mounted) return;

    // Show uploading snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
          SizedBox(width: 12),
          Text('Uploading image…'),
        ]),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      final ref = FirebaseStorage.instance
          .ref('event_type_images/${type.id}.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();
      await _eventTypeImagesRef.set({type.id: url}, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Image updated for ${type.name} ✅'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ── Step 1: Details Form ─────────────────────────────────────────────────

  Widget _buildDetailsForm(Color accent) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected type badge
          if (_selectedType != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: _selectedType!.gradient,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(_selectedType!.emoji,
                      style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedType!.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        Text(_selectedType!.tagline,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                  if (!widget.isEdit)
                    GestureDetector(
                      onTap: () {
                        _pageCtrl.animateToPage(0,
                            duration: const Duration(milliseconds: 380),
                            curve: Curves.easeInOut);
                        setState(() => _step = 0);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Change',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Banner image picker
          _label('Event Banner Image'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickBanner,
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: accent.withValues(alpha: 0.35), width: 1.5),
                color: accent.withValues(alpha: 0.04),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: _bannerFile != null
                    ? Stack(fit: StackFit.expand, children: [
                        Image.file(_bannerFile!, fit: BoxFit.cover),
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: Container(
                            color: Colors.black54,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit, color: Colors.white, size: 14),
                                SizedBox(width: 6),
                                Text('Tap to change',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ])
                    : _existingBannerUrl != null
                        ? Stack(fit: StackFit.expand, children: [
                            CachedNetworkImage(
                                imageUrl: _existingBannerUrl!,
                                fit: BoxFit.cover),
                            Positioned(
                              bottom: 0, left: 0, right: 0,
                              child: Container(
                                color: Colors.black54,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.edit,
                                        color: Colors.white, size: 14),
                                    SizedBox(width: 6),
                                    Text('Tap to change',
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ])
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  size: 40,
                                  color: accent.withValues(alpha: 0.5)),
                              const SizedBox(height: 8),
                              Text('Tap to add banner image',
                                  style: TextStyle(
                                      color: accent.withValues(alpha: 0.6),
                                      fontSize: 13)),
                              const SizedBox(height: 4),
                              Text('Optional — shown on the event card',
                                  style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 11)),
                            ],
                          ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Event Name
          _label('Event Name *'),
          const SizedBox(height: 8),
          _field(
            controller: _nameCtrl,
            hint: 'e.g. Ganesh Chaturthi 2026',
            icon: Icons.celebration_outlined,
            accent: accent,
            caps: TextCapitalization.words,
          ),
          const SizedBox(height: 18),

          // Description
          _label('Description'),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: _dec(
                'What is this event about?',
                Icons.description_outlined,
                accent),
          ),
          const SizedBox(height: 18),

          // Target amount
          _label('Collection Target (₹)'),
          Text('Optional — set a goal amount for contributions',
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 8),
          _field(
            controller: _targetCtrl,
            hint: 'e.g. 50000',
            icon: Icons.track_changes_outlined,
            accent: accent,
            keyboard: TextInputType.number,
            formatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 18),

          // Date range
          _label('Event Dates'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _datePicker(true, accent)),
              const SizedBox(width: 12),
              Expanded(child: _datePicker(false, accent)),
            ],
          ),

          // Expense categories hint
          if (_selectedType != null &&
              _selectedType!.id != 'other') ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: accent.withValues(alpha: 0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline,
                      color: accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_selectedType!.expenseCategories.length} expense categories '
                      'are pre-configured for ${_selectedType!.name} events. '
                      'You can manage them under Event Categories.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_error.isNotEmpty) ...[
            const SizedBox(height: 14),
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
                      color: Colors.red.shade600, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_error,
                          style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 13))),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _saving
                    ? (widget.isEdit ? 'Saving…' : 'Creating…')
                    : (widget.isEdit ? 'Save Changes' : 'Create Event'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Shared form helpers ──────────────────────────────────────────────────

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14));

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color accent,
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter> formatters = const [],
    TextCapitalization caps = TextCapitalization.none,
  }) =>
      TextField(
        controller: controller,
        keyboardType: keyboard,
        inputFormatters: formatters,
        textCapitalization: caps,
        decoration: _dec(hint, icon, accent),
      );

  InputDecoration _dec(String hint, IconData icon, Color accent) =>
      InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey.shade500),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      );

  Widget _datePicker(bool isStart, Color accent) => GestureDetector(
        onTap: () => _pickDate(isStart),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today,
                  size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isStart
                      ? (_startDate.isEmpty ? 'Start Date' : _startDate)
                      : (_endDate.isEmpty ? 'End Date' : _endDate),
                  style: TextStyle(
                      color: (isStart ? _startDate : _endDate).isEmpty
                          ? Colors.grey.shade400
                          : Colors.black87,
                      fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Event Type Card ───────────────────────────────────────────────────────────

class _EventTypeCard extends StatelessWidget {
  final EventTypeData type;
  final bool selected;
  final String? customImageUrl;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback? onUploadImage;

  const _EventTypeCard({
    required this.type,
    required this.selected,
    required this.onTap,
    this.customImageUrl,
    this.isAdmin = false,
    this.onUploadImage,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: type.gradient.first,
          boxShadow: [
            BoxShadow(
              color: type.gradient.first.withValues(alpha: selected ? 0.50 : 0.25),
              blurRadius: selected ? 20 : 8,
              offset: const Offset(0, 5),
            ),
          ],
          border: selected
              ? Border.all(color: Colors.white, width: 3)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(selected ? 15 : 18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // HD background image (custom takes priority over default)
              CachedNetworkImage(
                imageUrl: customImageUrl ?? type.imageUrl,
                key: ValueKey(customImageUrl ?? type.imageUrl),
                fit: BoxFit.cover,
                placeholder: (ctx, url) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: type.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                errorWidget: (ctx, url, err) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: type.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),

              // Dark gradient overlay for text legibility
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.62),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

              // Tinted gradient from event color (top-left corner glow)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 80,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        type.gradient.first.withValues(alpha: 0.55),
                        Colors.transparent,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.only(
                  left: 12, right: 12, top: 12, bottom: 38,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emoji pill
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1),
                      ),
                      child: Text(type.emoji,
                          style: const TextStyle(fontSize: 26)),
                    ),
                    const Spacer(),
                    Text(
                      type.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        height: 1.2,
                        shadows: [
                          Shadow(blurRadius: 4, color: Colors.black54)
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      type.tagline,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        shadows: [
                          Shadow(blurRadius: 3, color: Colors.black45)
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Upload Photo bar at bottom
              if (onUploadImage != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: onUploadImage,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt,
                              color: Colors.white, size: 13),
                          const SizedBox(width: 5),
                          Text(
                            customImageUrl != null
                                ? 'Change Photo'
                                : 'Upload Photo',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Selected check badge
              if (selected)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: Icon(Icons.check_circle,
                        color: type.gradient.first, size: 20),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

