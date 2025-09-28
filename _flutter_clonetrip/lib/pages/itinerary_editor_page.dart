import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/itinerary.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

class ItineraryEditorPage extends StatefulWidget {
  const ItineraryEditorPage({
    super.key,
    required this.itineraryId,
    required this.title,
  });

  final String itineraryId;
  final String title;

  @override
  State<ItineraryEditorPage> createState() => _ItineraryEditorPageState();
}

class _ItineraryEditorPageState extends State<ItineraryEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _countryController = TextEditingController();
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final _cityController = TextEditingController();
  final _budgetController = TextEditingController();

  final _transports = <Map<String, dynamic>>[];
  final _stays = <Map<String, dynamic>>[];
  final _activities = <Map<String, dynamic>>[];
  final _notificationRules = <Map<String, dynamic>>[];
  final _cities = <String>[];
  final _photoUrls = <String>[];
  bool _weatherEnabled = false;
  String _weatherUnits = 'metric';
  DateTime? _startDate;
  DateTime? _endDate;
  int _tabIndex = 0;

  // Simple suggestion list for quick-pick horizontal options
  static const List<String> _citySuggestions = <String>[
    'New York',
    'London',
    'Paris',
    'Tokyo',
    'Seoul',
    'Sydney',
    'Los Angeles',
    'San Francisco',
    'Toronto',
    'Mexico City',
    'Rio de Janeiro',
    'Cape Town',
    'Dubai',
    'Singapore',
    'Bangkok',
    'Bali',
    'Rome',
    'Barcelona',
    'Amsterdam',
    'Berlin',
  ];

  final Map<String, bool> _sectionOpen = <String, bool>{
    'cities': true,
    'transport': true,
    'stays': true,
    'activities': true,
    'notifications': false,
    'weather': false,
    'photos': true,
  };

  bool _loading = true;
  bool _saving = false;

  late final FirestoreDataService _data = FirestoreDataService(
    FirebaseFirestore.instance,
  );
  late final StorageService _storage = StorageService(FirebaseStorage.instance);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await FirebaseFirestore.instance
        .collection('itineraries')
        .doc(widget.itineraryId)
        .get();
    final data = snap.data() ?? <String, dynamic>{};
    final model = Itinerary.fromMap(snap.id, data);
    _titleController.text = model.title;
    _countryController.text = model.countryCode;
    _startController.text = model.startDateIso ?? '';
    _endController.text = model.endDateIso ?? '';
    _startDate = _tryParseDate(model.startDateIso);
    _endDate = _tryParseDate(model.endDateIso);
    _cities
      ..clear()
      ..addAll(model.cities);
    _transports
      ..clear()
      ..addAll(model.transports);
    _stays
      ..clear()
      ..addAll(model.stays);
    _activities
      ..clear()
      ..addAll(model.activities);
    _notificationRules
      ..clear()
      ..addAll(model.notificationRules);
    _photoUrls
      ..clear()
      ..addAll(model.photoUrls);
    _budgetController.text = model.totalBudget?.toString() ?? '';
    _weatherEnabled = model.weatherEnabled;
    _weatherUnits = model.weatherUnits;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final updates = <String, dynamic>{
      'title': _titleController.text.trim(),
      'countryCode': _countryController.text.trim(),
      'cities': _cities,
      'transports': _transports,
      'stays': _stays,
      'activities': _activities,
      'notificationRules': _notificationRules,
      'photoUrls': _photoUrls,
    };
    if (_startDate != null) {
      updates['startDateIso'] = _fmtYmd(_startDate!);
    } else {
      final start = _startController.text.trim();
      updates['startDateIso'] = start.isNotEmpty ? start : null;
    }
    if (_endDate != null) {
      updates['endDateIso'] = _fmtYmd(_endDate!);
    } else {
      final end = _endController.text.trim();
      updates['endDateIso'] = end.isNotEmpty ? end : null;
    }
    final budget = double.tryParse(_budgetController.text.trim());
    updates['totalBudget'] = budget;
    updates['weatherEnabled'] = _weatherEnabled;
    updates['weatherUnits'] = _weatherUnits;
    await _data.updateItinerary(
      itineraryId: widget.itineraryId,
      updates: updates,
    );
    if (mounted) setState(() => _saving = false);
    if (mounted) Navigator.pop(context);
  }

  DateTime? _tryParseDate(String? ymd) {
    if (ymd == null || ymd.isEmpty) return null;
    try {
      return DateTime.parse(ymd);
    } catch (_) {
      return null;
    }
  }

  String _fmtMdy(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _fmtYmd(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  // Date picker handled inline in bottom sheet editor

  Future<void> _editBasics() async {
    final titleTmp = TextEditingController(text: _titleController.text);
    final countryTmp = TextEditingController(text: _countryController.text);
    final budgetTmp = TextEditingController(text: _budgetController.text);
    DateTime? startTmp = _startDate;
    DateTime? endTmp = _endDate;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(ctx).cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Trip Details',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleTmp,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: countryTmp,
                  decoration: const InputDecoration(labelText: 'Country Code'),
                ),
                TextField(
                  controller: budgetTmp,
                  decoration: const InputDecoration(
                    labelText: 'Budget (optional)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Start Date'),
                        subtitle: Text(
                          startTmp != null ? _fmtMdy(startTmp!) : 'Select date',
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: startTmp ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) startTmp = picked;
                          // ignore: use_build_context_synchronously
                          (ctx as Element).markNeedsBuild();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('End Date'),
                        subtitle: Text(
                          endTmp != null ? _fmtMdy(endTmp!) : 'Select date',
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: endTmp ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) endTmp = picked;
                          // ignore: use_build_context_synchronously
                          (ctx as Element).markNeedsBuild();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () {
                      _titleController.text = titleTmp.text.trim();
                      _countryController.text = countryTmp.text.trim();
                      _budgetController.text = budgetTmp.text.trim();
                      _startDate = startTmp;
                      _endDate = endTmp;
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete itinerary?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _data.deleteItinerary(itineraryId: widget.itineraryId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _addPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final file = File(picked.path);
    final url = await _storage.uploadItineraryPhoto(
      itineraryId: widget.itineraryId,
      fileName: picked.name,
      file: file,
    );
    setState(() => _photoUrls.add(url));
  }

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      PopupMenuButton<String>(
        icon: const Icon(Icons.add_circle_outline),
        tooltip: 'Add',
        onSelected: (v) async {
          switch (v) {
            case 'city':
              setState(() => _cities.add('New City'));
              break;
            case 'transport':
              setState(
                () => _transports.add({
                  'mode': 'flight',
                  'from': '',
                  'to': '',
                  'departIso': '',
                  'arriveIso': '',
                  'price': null,
                }),
              );
              break;
            case 'stay':
              setState(
                () => _stays.add({
                  'type': 'hotel',
                  'name': '',
                  'checkInIso': '',
                  'checkOutIso': '',
                  'price': null,
                }),
              );
              break;
            case 'activity':
              setState(
                () => _activities.add({
                  'title': '',
                  'whenIso': '',
                  'mustDo': true,
                  'price': null,
                }),
              );
              break;
            case 'notification':
              setState(
                () => _notificationRules.add({
                  'type': 'local',
                  'whenIso': '',
                  'message': '',
                }),
              );
              break;
            case 'photo':
              await _addPhoto();
              break;
          }
        },
        itemBuilder: (ctx) => const [
          PopupMenuItem(
            value: 'city',
            child: ListTile(
              leading: Icon(Icons.location_city),
              title: Text('Add City'),
            ),
          ),
          PopupMenuItem(
            value: 'transport',
            child: ListTile(
              leading: Icon(Icons.flight_takeoff),
              title: Text('Add Transport'),
            ),
          ),
          PopupMenuItem(
            value: 'stay',
            child: ListTile(
              leading: Icon(Icons.hotel),
              title: Text('Add Lodging'),
            ),
          ),
          PopupMenuItem(
            value: 'activity',
            child: ListTile(
              leading: Icon(Icons.checklist),
              title: Text('Add Activity'),
            ),
          ),
          PopupMenuItem(
            value: 'notification',
            child: ListTile(
              leading: Icon(Icons.notifications_active_outlined),
              title: Text('Add Notification'),
            ),
          ),
          PopupMenuItem(
            value: 'photo',
            child: ListTile(
              leading: Icon(Icons.add_a_photo_outlined),
              title: Text('Add Photo'),
            ),
          ),
        ],
      ),
      IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: _delete,
        tooltip: 'Delete',
      ),
      const SizedBox(width: 8),
    ];

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title), actions: actions),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 2,
      initialIndex: _tabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: actions,
          bottom: TabBar(
            onTap: (i) => setState(() => _tabIndex = i),
            tabs: const [
              Tab(text: 'Edit'),
              Tab(text: 'Timeline'),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _TitleHeader(
                      title: _titleController.text.trim(),
                      countryCode: _countryController.text.trim(),
                      start: _startDate,
                      end: _endDate,
                      onEdit: _editBasics,
                    ),
                    const SizedBox(height: 16),
                    _Collapsible(
                      title: 'Cities',
                      open: _sectionOpen['cities'] == true,
                      onToggle: (v) =>
                          setState(() => _sectionOpen['cities'] = v),
                      child: _ChipEditor(
                        label: 'Cities',
                        values: _cities,
                        controller: _cityController,
                        options: _citySuggestions,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Collapsible(
                      title: 'Transport',
                      open: _sectionOpen['transport'] == true,
                      onToggle: (v) =>
                          setState(() => _sectionOpen['transport'] = v),
                      child: _SectionList(
                        title: 'Transport',
                        items: _transports,
                        onAdd: () => setState(
                          () => _transports.add({
                            'mode': 'flight',
                            'from': '',
                            'to': '',
                            'departIso': '',
                            'arriveIso': '',
                            'price': null,
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Collapsible(
                      title: 'Lodging',
                      open: _sectionOpen['stays'] == true,
                      onToggle: (v) =>
                          setState(() => _sectionOpen['stays'] = v),
                      child: _SectionList(
                        title: 'Lodging',
                        items: _stays,
                        onAdd: () => setState(
                          () => _stays.add({
                            'type': 'hotel',
                            'name': '',
                            'checkInIso': '',
                            'checkOutIso': '',
                            'price': null,
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Collapsible(
                      title: 'Activities',
                      open: _sectionOpen['activities'] == true,
                      onToggle: (v) =>
                          setState(() => _sectionOpen['activities'] = v),
                      child: _SectionList(
                        title: 'Activities',
                        items: _activities,
                        onAdd: () => setState(
                          () => _activities.add({
                            'title': '',
                            'whenIso': '',
                            'mustDo': true,
                            'price': null,
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Collapsible(
                      title: 'Notifications',
                      open: _sectionOpen['notifications'] == true,
                      onToggle: (v) =>
                          setState(() => _sectionOpen['notifications'] = v),
                      child: _SectionList(
                        title: 'Notifications',
                        items: _notificationRules,
                        onAdd: () => setState(
                          () => _notificationRules.add({
                            'type': 'local',
                            'whenIso': '',
                            'message': '',
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Collapsible(
                      title: 'Weather',
                      open: _sectionOpen['weather'] == true,
                      onToggle: (v) =>
                          setState(() => _sectionOpen['weather'] = v),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            value: _weatherEnabled,
                            onChanged: (val) =>
                                setState(() => _weatherEnabled = val),
                            title: const Text('Enable Weather'),
                            subtitle: const Text(
                              'Show weather per city/date (API to be added)',
                            ),
                          ),
                          Row(
                            children: [
                              const Text('Units:'),
                              const SizedBox(width: 12),
                              DropdownButton<String>(
                                value: _weatherUnits,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'metric',
                                    child: Text('Metric (°C)'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'imperial',
                                    child: Text('Imperial (°F)'),
                                  ),
                                ],
                                onChanged: _weatherEnabled
                                    ? (v) => setState(
                                        () => _weatherUnits = v ?? 'metric',
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Collapsible(
                      title: 'Photos',
                      open: _sectionOpen['photos'] == true,
                      onToggle: (v) =>
                          setState(() => _sectionOpen['photos'] = v),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final url in _photoUrls)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                url,
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                              ),
                            ),
                          InkWell(
                            onTap: _addPhoto,
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.secondary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                              ),
                              child: const Icon(Icons.add_a_photo_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.check),
                        label: Text(_saving ? 'Saving...' : 'Save Changes'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: _buildTimeline(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTimeline(BuildContext context) {
    final events = <Map<String, dynamic>>[];
    void addEvent(String? iso, String title, String subtitle, IconData icon) {
      if (iso == null || iso.isEmpty) return;
      events.add({
        'iso': iso,
        'title': title,
        'subtitle': subtitle,
        'icon': icon,
      });
    }

    for (final t in _transports) {
      addEvent(
        t['departIso'] as String?,
        'Depart ${t['from'] ?? ''} → ${t['to'] ?? ''}',
        '${t['mode'] ?? 'transport'}',
        Icons.flight_takeoff,
      );
      addEvent(
        t['arriveIso'] as String?,
        'Arrive ${t['to'] ?? ''}',
        '${t['mode'] ?? 'transport'}',
        Icons.flight_land,
      );
    }
    for (final s in _stays) {
      addEvent(
        s['checkInIso'] as String?,
        'Check-in ${s['name'] ?? s['type'] ?? 'stay'}',
        '',
        Icons.login,
      );
      addEvent(
        s['checkOutIso'] as String?,
        'Check-out ${s['name'] ?? s['type'] ?? 'stay'}',
        '',
        Icons.logout,
      );
    }
    for (final a in _activities) {
      addEvent(
        a['whenIso'] as String?,
        a['title']?.toString() ?? 'Activity',
        a['mustDo'] == true ? 'Must-do' : 'Wishlist',
        Icons.event,
      );
    }
    events.sort((a, b) => (a['iso'] as String).compareTo(b['iso'] as String));
    return [
      _TitleHeader(
        title: _titleController.text.trim(),
        countryCode: _countryController.text.trim(),
        start: _startDate,
        end: _endDate,
        onEdit: _editBasics,
      ),
      const SizedBox(height: 16),
      if (events.isEmpty)
        Center(
          child: Text(
            'No timeline items yet. Add transport, lodging, or activities to see them here.',
          ),
        )
      else
        Column(
          children: [
            for (int i = 0; i < events.length; i++)
              _TimelineEntry(
                iso: events[i]['iso'] as String,
                title: events[i]['title'] as String,
                subtitle: events[i]['subtitle'] as String,
                icon: events[i]['icon'] as IconData,
                isFirst: i == 0,
                isLast: i == events.length - 1,
              ),
          ],
        ),
    ];
  }
}

class _ChipEditor extends StatefulWidget {
  const _ChipEditor({
    required this.label,
    required this.values,
    required this.controller,
    this.options = const [],
  });

  final String label;
  final List<String> values;
  final TextEditingController controller;
  final List<String> options;

  @override
  State<_ChipEditor> createState() => _ChipEditorState();
}

class _ChipEditorState extends State<_ChipEditor> {
  void _reorder(int from, int to) {
    if (from == to) return;
    setState(() {
      final item = widget.values.removeAt(from);
      if (to > from) to -= 1;
      widget.values.insert(to, item);
    });
  }

  Widget _buildDropTarget(int targetIndex) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != targetIndex,
      onAcceptWithDetails: (details) {
        _reorder(details.data, targetIndex);
      },
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: isActive ? 16 : 8,
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.secondary.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      },
    );
  }

  Widget _buildDraggableChip(int i) {
    final value = widget.values[i];
    return LongPressDraggable<int>(
      data: i,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Chip(
          label: Text(value),
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withOpacity(0.12),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Chip(
          label: Text(value),
          onDeleted: () => setState(() => widget.values.removeAt(i)),
        ),
      ),
      child: Chip(
        label: Text(value),
        onDeleted: () => setState(() => widget.values.removeAt(i)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (widget.options.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final opt in widget.options)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(opt),
                      selected: widget.values.contains(opt),
                      onSelected: (_) {
                        if (!widget.values.contains(opt)) {
                          setState(() => widget.values.add(opt));
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropTarget(0),
            for (int i = 0; i < widget.values.length; i++) ...[
              _buildDraggableChip(i),
              _buildDropTarget(i + 1),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                decoration: const InputDecoration(hintText: 'Add item'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                final t = widget.controller.text.trim();
                if (t.isEmpty) return;
                setState(() => widget.values.add(t));
                widget.controller.clear();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionList extends StatefulWidget {
  const _SectionList({
    required this.title,
    required this.items,
    required this.onAdd,
  });

  final String title;
  final List<Map<String, dynamic>> items;
  final VoidCallback onAdd;

  @override
  State<_SectionList> createState() => _SectionListState();
}

class _SectionListState extends State<_SectionList> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            IconButton(
              onPressed: widget.onAdd,
              icon: const Icon(Icons.add),
              tooltip: 'Add',
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.items.isEmpty)
          Text('No items', style: Theme.of(context).textTheme.bodySmall)
        else
          Column(
            children: [
              for (int i = 0; i < widget.items.length; i++)
                _EditableCard(
                  data: widget.items[i],
                  onDelete: () => setState(() => widget.items.removeAt(i)),
                ),
            ],
          ),
      ],
    );
  }
}

class _EditableCard extends StatefulWidget {
  const _EditableCard({required this.data, required this.onDelete});
  final Map<String, dynamic> data;
  final VoidCallback onDelete;

  @override
  State<_EditableCard> createState() => _EditableCardState();
}

class _EditableCardState extends State<_EditableCard> {
  @override
  Widget build(BuildContext context) {
    final entries = widget.data.entries.toList();
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (final e in entries)
              _EntryField(
                label: e.key,
                value: e.value?.toString() ?? '',
                onChanged: (v) => setState(() => widget.data[e.key] = v),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: widget.onDelete,
                tooltip: 'Remove',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryField extends StatelessWidget {
  const _EntryField({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        decoration: InputDecoration(labelText: label),
        controller: TextEditingController(text: value),
        onChanged: onChanged,
      ),
    );
  }
}

class _Collapsible extends StatelessWidget {
  const _Collapsible({
    required this.title,
    required this.open,
    required this.onToggle,
    required this.child,
  });

  final String title;
  final bool open;
  final ValueChanged<bool> onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => onToggle(!open),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Icon(open ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
            if (open) ...[const SizedBox(height: 8), child],
          ],
        ),
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.iso,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isFirst,
    required this.isLast,
  });

  final String iso;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(iso);
    final dateLabel = dt == null
        ? iso
        : '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              alignment: Alignment.center,
              child: Icon(icon, size: 16),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            elevation: 0,
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle.isEmpty ? dateLabel : '$subtitle · $dateLabel'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TitleHeader extends StatelessWidget {
  const _TitleHeader({
    required this.title,
    required this.countryCode,
    required this.start,
    required this.end,
    required this.onEdit,
  });

  final String title;
  final String countryCode;
  final DateTime? start;
  final DateTime? end;
  final VoidCallback onEdit;

  String _fmtMdy(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = (start != null || end != null)
        ? '${start != null ? _fmtMdy(start!) : 'TBD'} — ${end != null ? _fmtMdy(end!) : 'TBD'}'
        : 'Set dates';
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              child: Text(
                countryCode.isNotEmpty ? countryCode.toUpperCase() : 'TR',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? 'Untitled Trip' : title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
          ],
        ),
      ),
    );
  }
}
