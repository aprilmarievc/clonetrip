import 'dart:io';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
 
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/itinerary.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/flight_status_service.dart';

// HH:mm typing formatter (24-hour)
class _HmTimeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    String text;
    if (digits.length <= 2) {
      text = digits;
    } else {
      final hh = digits.substring(0, 2);
      final mm = digits.substring(2, digits.length.clamp(2, 4));
      text = '$hh:${mm.padRight(2, '0').substring(0, mm.length.clamp(0, 2))}';
    }
    final offset = text.length;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

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
  final _documents = <Map<String, dynamic>>[];
  final _tripExpenses = <Map<String, dynamic>>[];
  final Map<String, List<String>> _timelineOrder = <String, List<String>>{};
  bool _weatherEnabled = false;
  String _weatherUnits = 'metric';
  bool _isCurrent = false;
  DateTime? _startDate;
  DateTime? _endDate;
  int _tabIndex = 0;
  bool _isEditing = false;
  String _selectedCategory = 'Cities';

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
    if (_startDate != null &&
        _endDate != null &&
        _endDate!.isBefore(_startDate!)) {
      final DateTime tmp = _startDate!;
      _startDate = _endDate;
      _endDate = tmp;
    }
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
    _documents
      ..clear()
      ..addAll(model.documents);
    _tripExpenses
      ..clear()
      ..addAll(model.tripExpenses);
    // Load manual timeline order if present
    final to = (data['timelineOrder'] as Map?)?.cast<String, dynamic>() ?? {};
    _timelineOrder
      ..clear()
      ..addAll(
        to.map((k, v) => MapEntry(k, (v as List).map((e) => e.toString()).toList())),
      );
    _budgetController.text = model.totalBudget?.toString() ?? '';
    _weatherEnabled = model.weatherEnabled;
    _weatherUnits = model.weatherUnits;
    _isCurrent = model.isCurrent;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save({bool closeAfter = true}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate != null &&
        _endDate != null &&
        _endDate!.isBefore(_startDate!)) {
      final DateTime tmp = _startDate!;
      _startDate = _endDate;
      _endDate = tmp;
    }
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
      'documents': _documents,
      'tripExpenses': _tripExpenses,
      'isCurrent': _isCurrent,
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
    if (_timelineOrder.isNotEmpty) {
      updates['timelineOrder'] = _timelineOrder;
    }

    // Auto-generate expenses from items with prices, default currency USD
    final List<Map<String, dynamic>> preservedExpenses = _tripExpenses
        .where((e) => (e['source'] as String?) == null)
        .toList();

    String dayOf(String? iso) => (iso == null || iso.isEmpty)
        ? ''
        : (iso.length >= 10 ? iso.substring(0, 10) : iso);

    final List<Map<String, dynamic>> lodgingExpenses = _stays
        .map(
          (s) => (s['price'] as num?)?.toDouble() != null
              ? {
                  'amount': (s['price'] as num).toDouble(),
                  'currency': 'USD',
                  'description': (s['name'] as String?)?.isNotEmpty == true
                      ? 'Lodging - ${s['name']}'
                      : 'Lodging',
                  'source': 'lodging',
                  'whenIso': s['checkInIso'] as String? ?? '',
                }
              : null,
        )
        .whereType<Map<String, dynamic>>()
        .toList();

    final List<Map<String, dynamic>> transportExpenses = _transports
        .map(
          (t) => (t['price'] as num?)?.toDouble() != null
              ? {
                  'amount': (t['price'] as num).toDouble(),
                  'currency': 'USD',
                  'description':
                      '${(t['mode'] as String?) ?? 'Transport'}'
                              ' ${(t['from'] as String?) ?? ''}'
                              ' → '
                              ' ${(t['to'] as String?) ?? ''}'
                          .trim(),
                  'source': 'transport',
                  'whenIso':
                      (t['departIso'] as String?) ??
                      (t['arriveIso'] as String?) ??
                      '',
                }
              : null,
        )
        .whereType<Map<String, dynamic>>()
        .toList();

    final List<Map<String, dynamic>> activityExpenses = _activities
        .map(
          (a) => (a['price'] as num?)?.toDouble() != null
              ? {
                  'amount': (a['price'] as num).toDouble(),
                  'currency': 'USD',
                  'description': (a['title'] as String?)?.isNotEmpty == true
                      ? (a['title'] as String)
                      : 'Activity',
                  'source': 'activity',
                  'whenIso': a['whenIso'] as String? ?? '',
                }
              : null,
        )
        .whereType<Map<String, dynamic>>()
        .toList();

    _tripExpenses
      ..clear()
      ..addAll(preservedExpenses)
      ..addAll(lodgingExpenses)
      ..addAll(transportExpenses)
      ..addAll(activityExpenses);

    updates['tripExpenses'] = _tripExpenses;
    await _data.updateItinerary(
      itineraryId: widget.itineraryId,
      updates: updates,
    );
    if (mounted) setState(() => _saving = false);
    // Stay on the same page after saving
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
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$mm/$dd/${d.year}';
  }

  String _fmtYmd(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  String _fmtHm(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String? _durationLabelStr(String? departIso, String? arriveIso) {
    if (departIso == null || arriveIso == null) return null;
    final DateTime? d = DateTime.tryParse(departIso);
    final DateTime? a = DateTime.tryParse(arriveIso);
    if (d == null || a == null) return null;
    final diff = a.difference(d);
    if (diff.inMinutes <= 0) return null;
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  

  TimeOfDay? _parseTimeOfDay(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    // Only treat strings with an explicit time component as having time
    final hasTime = iso.contains('T') && RegExp(r'T\d{2}:\d{2}').hasMatch(iso);
    if (!hasTime) return null;
    try {
      final dt = DateTime.parse(iso);
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    } catch (_) {
      return null;
    }
  }

  String _mergeDayAndTime(String dayYmd, TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '${dayYmd}T$hh:$mm:00';
  }

  Widget _activityCardForDay(
    BuildContext context,
    Map<String, dynamic> a,
    String dayKey,
  ) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 8, top: 8, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (a['kind'] == 'city')
                  const Icon(Icons.location_city, size: 16)
                else
                  const Icon(Icons.event, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(
                      text: (a['title']?.toString() ?? ''),
                    ),
                    enabled: _isEditing,
                    decoration: InputDecoration(
                      labelText: a['kind'] == 'city' ? 'City' : 'Activity',
                    ),
                    onChanged: (v) => a['title'] = v,
                  ),
                ),
                if (_isEditing && a['kind'] == 'city') ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    tooltip: 'Move up',
                    onPressed: () {
                      final local = _cityIndicesForDay(
                        dayKey,
                      ).indexWhere((idx) => _activities[idx] == a);
                      if (local != -1) _moveCityStopUp(dayKey, local);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward, size: 18),
                    tooltip: 'Move down',
                    onPressed: () {
                      final local = _cityIndicesForDay(
                        dayKey,
                      ).indexWhere((idx) => _activities[idx] == a);
                      if (local != -1) _moveCityStopDown(dayKey, local);
                    },
                  ),
                ],
                if (_isEditing)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove',
                    onPressed: () => setState(() => _activities.remove(a)),
                  ),
              ],
            ),
            if (a['kind'] != 'city')
              Row(
                children: [
                  Builder(
                    builder: (ctx2) {
                      final t = _parseTimeOfDay(a['whenIso'] as String?);
                      return TextButton.icon(
                        onPressed: !_isEditing
                            ? null
                            : () async {
                                final picked = await showTimePicker(
                                  context: ctx2,
                                  initialTime:
                                      t ?? const TimeOfDay(hour: 10, minute: 0),
                                );
                                if (picked != null) {
                                  setState(
                                    () => a['whenIso'] = _mergeDayAndTime(
                                      dayKey,
                                      picked,
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.schedule, size: 16),
                        label: Text('Time ${t != null ? _fmtHm(t) : '--:--'}'),
                      );
                    },
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: TextEditingController(
                        text: (a['price']?.toString() ?? ''),
                      ),
                      enabled: _isEditing,
                      decoration: const InputDecoration(labelText: 'Price'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (v) => a['price'] = double.tryParse(v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Must-do'),
                      Switch(
                        value: a['mustDo'] == true,
                        onChanged: !_isEditing
                            ? null
                            : (v) => setState(() => a['mustDo'] = v),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Date picker handled inline in bottom sheet editor

  Future<void> _editBasics() async {
    final titleTmp = TextEditingController(text: _titleController.text);
    final countryTmp = TextEditingController(text: _countryController.text);
    final budgetTmp = TextEditingController(text: _budgetController.text);
    DateTime? startTmp = _startDate;
    DateTime? endTmp = _endDate;
    if (startTmp != null && endTmp != null && endTmp.isBefore(startTmp)) {
      final DateTime tmp = startTmp;
      startTmp = endTmp;
      endTmp = tmp;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: null,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(color: Theme.of(ctx).cardColor),
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Trip Dates'),
                  subtitle: Text(
                    startTmp != null && endTmp != null
                        ? '${_fmtMdy(startTmp!)} — ${_fmtMdy(endTmp!)}'
                        : 'Select range',
                  ),
                  onTap: () async {
                    final range = await showDateRangePicker(
                      context: ctx,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDateRange: (startTmp != null && endTmp != null)
                          ? DateTimeRange(start: startTmp!, end: endTmp!)
                          : null,
                      helpText: 'Select trip dates',
                    );
                    if (range != null) {
                      startTmp = range.start;
                      endTmp = range.end;
                      // ignore: use_build_context_synchronously
                      (ctx as Element).markNeedsBuild();
                    }
                  },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () async {
                      _titleController.text = titleTmp.text.trim();
                      _countryController.text = countryTmp.text.trim();
                      _budgetController.text = budgetTmp.text.trim();
                      _startDate = startTmp;
                      _endDate = endTmp;
                      await _save(closeAfter: false);
                      // ignore: use_build_context_synchronously
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

  List<DateTime> _enumerateTripDays() {
    if (_startDate == null || _endDate == null) return const <DateTime>[];
    final List<DateTime> days = <DateTime>[];
    DateTime d = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
    final DateTime end = DateTime(
      _endDate!.year,
      _endDate!.month,
      _endDate!.day,
    );
    while (!d.isAfter(end)) {
      days.add(d);
      d = d.add(const Duration(days: 1));
    }
    return days;
  }

  // Simple text prompt helper for quick-add flows
  Future<String?> _promptText({
    required BuildContext context,
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (res == null || res.isEmpty) return null;
    return res;
  }

  // Utilities for per-day city stops using activities with kind == 'city'
  List<int> _cityIndicesForDay(String dayKey) {
    String isoDay(String? iso) => (iso == null || iso.isEmpty)
        ? ''
        : (iso.length >= 10 ? iso.substring(0, 10) : iso);
    final indices = <int>[];
    for (int i = 0; i < _activities.length; i++) {
      final m = _activities[i];
      if ((m['kind'] == 'city') && isoDay(m['whenIso'] as String?) == dayKey) {
        indices.add(i);
      }
    }
    return indices;
  }

  void _renumberCityStopTimes(String dayKey) {
    final indices = _cityIndicesForDay(dayKey);
    for (int i = 0; i < indices.length; i++) {
      final idx = indices[i];
      final mm = i.toString().padLeft(2, '0');
      _activities[idx]['whenIso'] = '${dayKey}T00:$mm:00';
    }
  }

  void _addCityStop(String dayKey, String title) {
    final position = _cityIndicesForDay(dayKey).length;
    final mm = position.toString().padLeft(2, '0');
    _activities.add({
      'title': title,
      'whenIso': '${dayKey}T00:$mm:00',
      'kind': 'city',
      'mustDo': true,
    });
  }

  void _moveCityStopUp(String dayKey, int localIndex) {
    final indices = _cityIndicesForDay(dayKey);
    if (localIndex <= 0 || localIndex >= indices.length) return;
    final from = indices[localIndex];
    final to = indices[localIndex - 1];
    final item = _activities.removeAt(from);
    // from > to in move up
    _activities.insert(to, item);
    _renumberCityStopTimes(dayKey);
    setState(() {});
  }

  void _moveCityStopDown(String dayKey, int localIndex) {
    final indices = _cityIndicesForDay(dayKey);
    if (localIndex < 0 || localIndex >= indices.length - 1) return;
    final from = indices[localIndex];
    final to = indices[localIndex + 1];
    final item = _activities.removeAt(from);
    // from < to in move down; after removal, target index decreases by 1
    _activities.insert(to - 1, item);
    _renumberCityStopTimes(dayKey);
    setState(() {});
  }

  // replaced by _buildDaySections

  // Generic activity reordering within a day (applies to all kinds)
  List<int> _activityIndicesForDay(String dayKey) {
    String isoDay(String? iso) => (iso == null || iso.isEmpty)
        ? ''
        : (iso.length >= 10 ? iso.substring(0, 10) : iso);
    final indices = <int>[];
    for (int i = 0; i < _activities.length; i++) {
      final m = _activities[i];
      if (isoDay(m['whenIso'] as String?) == dayKey) indices.add(i);
    }
    return indices;
  }

  void _moveActivityUp(String dayKey, int globalIndex) {
    final dayIdxs = _activityIndicesForDay(dayKey);
    final local = dayIdxs.indexOf(globalIndex);
    if (local <= 0) return;
    final from = globalIndex;
    final toGlobal = dayIdxs[local - 1];
    final item = _activities.removeAt(from);
    final insertIndex = from < toGlobal ? toGlobal - 1 : toGlobal;
    _activities.insert(insertIndex, item);
    setState(() {});
  }

  void _moveActivityDown(String dayKey, int globalIndex) {
    final dayIdxs = _activityIndicesForDay(dayKey);
    final local = dayIdxs.indexOf(globalIndex);
    if (local == -1 || local >= dayIdxs.length - 1) return;
    final from = globalIndex;
    final toGlobal = dayIdxs[local + 1];
    final item = _activities.removeAt(from);
    final insertIndex = from < toGlobal ? toGlobal - 1 : toGlobal + 1;
    _activities.insert(insertIndex, item);
    setState(() {});
  }

  Future<String?> _pickDayIso(BuildContext context) async {
    final days = _enumerateTripDays();
    if (days.isEmpty) return null;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Pick a day'),
          content: SizedBox(
            width: 360,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: days.length,
              itemBuilder: (c, i) {
                final d = days[i];
                return ListTile(
                  title: Text('Day ${i + 1} — ${_fmtMdy(d)}'),
                  onTap: () => Navigator.pop(ctx, _fmtYmd(d)),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
    return result;
  }

  Widget _buildDaySections(BuildContext context) {
    final days = _enumerateTripDays();
    if (days.isEmpty) return const SizedBox.shrink();

    String dayKey(DateTime d) => _fmtYmd(d);
    String isoDay(String? iso) => (iso == null || iso.isEmpty)
        ? ''
        : (iso.length >= 10 ? iso.substring(0, 10) : iso);

    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < days.length; i++) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.today, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Day ${i + 1} — ${_fmtMdy(days[i])}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              if (_isEditing)
                Padding(
                  padding: const EdgeInsets.only(left: 24, bottom: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.location_city, size: 18),
                        label: const Text('City'),
                        onPressed: () async {
                          final name = await _promptText(
                            context: context,
                            title: 'Add City',
                            hint: 'City name',
                          );
                          if (name == null) return;
                          setState(() {
                            _addCityStop(dayKey(days[i]), name);
                          });
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.flight_takeoff, size: 18),
                        label: const Text('Transport'),
                        onPressed: () {
                          setState(() {
                            _transports.add({
                              'mode': 'flight',
                              'from': '',
                              'to': '',
                              'departIso': dayKey(days[i]),
                              'arriveIso': dayKey(days[i]),
                              'price': null,
                            });
                          });
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.hotel, size: 18),
                        label: const Text('Lodging'),
                        onPressed: () {
                          setState(() {
                            _stays.add({
                              'type': 'hotel',
                              'name': '',
                              // prefill day only for grouping; time will be added if enabled
                              'checkInIso': dayKey(days[i]),
                              'checkOutIso': '',
                              'checkInEnabled': false,
                              'checkOutEnabled': false,
                              'price': null,
                            });
                          });
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.checklist, size: 18),
                        label: const Text('Activity'),
                        onPressed: () async {
                          final title = await _promptText(
                            context: context,
                            title: 'Add Activity',
                            hint: 'Activity title',
                          );
                          if (title == null) return;
                          setState(() {
                            _activities.add({
                              'title': title,
                              'whenIso': dayKey(days[i]),
                              'mustDo': true,
                              'price': null,
                            });
                          });
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(
                          Icons.notifications_active_outlined,
                          size: 18,
                        ),
                        label: const Text('Notify'),
                        onPressed: () async {
                          final msg = await _promptText(
                            context: context,
                            title: 'Add Notification',
                            hint: 'Reminder text',
                          );
                          if (msg == null) return;
                          setState(() {
                            _notificationRules.add({
                              'type': 'local',
                              'whenIso': dayKey(days[i]),
                              'message': msg,
                            });
                          });
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.wb_cloudy_outlined, size: 18),
                        label: const Text('Weather'),
                        onPressed: () {
                          setState(() {
                            _weatherEnabled = true;
                            _weatherUnits = _weatherUnits;
                          });
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 18,
                        ),
                        label: const Text('Photo'),
                        onPressed: _addPhoto,
                      ),
                    ],
                  ),
                ),
              // Transports for this day (inline editable)
              ..._transports
                  .where((t) {
                    final di = isoDay(t['departIso'] as String?);
                    final ai = isoDay(t['arriveIso'] as String?);
                    final k = dayKey(days[i]);
                    return di == k || ai == k;
                  })
                  .map(
                    (t) => Card(
                      elevation: 0,
                      color: Theme.of(context).cardColor,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 12,
                          right: 8,
                          top: 8,
                          bottom: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.flight_takeoff, size: 16),
                                const SizedBox(width: 8),
                                DropdownButton<String>(
                                  value: (t['mode'] as String?) ?? 'flight',
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'flight',
                                      child: Text('Flight'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'train',
                                      child: Text('Train'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'bus',
                                      child: Text('Bus'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'car',
                                      child: Text('Car'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'boat',
                                      child: Text('Boat'),
                                    ),
                                  ],
                                  onChanged: !_isEditing
                                      ? null
                                      : (v) => setState(() => t['mode'] = v),
                                ),
                                const Spacer(),
                                if (_isEditing)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Remove',
                                    onPressed: () =>
                                        setState(() => _transports.remove(t)),
                                  ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: TextEditingController(
                                      text: (t['from'] as String?) ?? '',
                                    ),
                                    enabled: _isEditing,
                                    decoration: const InputDecoration(
                                      labelText: 'From airport',
                                    ),
                                    onChanged: (v) => t['from'] = v,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: TextEditingController(
                                      text: (t['to'] as String?) ?? '',
                                    ),
                                    enabled: _isEditing,
                                    decoration: const InputDecoration(
                                      labelText: 'To airport',
                                    ),
                                    onChanged: (v) => t['to'] = v,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                SizedBox(
                                  width: 160,
                                  child: TextField(
                                    controller: TextEditingController(
                                      text: (t['flightNumber'] as String?) ?? '',
                                    ),
                                    enabled: _isEditing,
                                    decoration: const InputDecoration(
                                      labelText: 'Flight number',
                                      hintText: 'e.g., AA100',
                                    ),
                                    onChanged: (v) => t['flightNumber'] = v.trim().toUpperCase(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: !_isEditing || (t['flightNumber'] as String?) == null || (t['flightNumber'] as String).isEmpty
                                      ? null
                                      : () async {
                                          final k = dayKey(days[i]);
                                          final status = await FlightStatusService.fetch(
                                            flightNumber: (t['flightNumber'] as String).trim(),
                                            dateYmd: k,
                                          );
                                          if (status != null) {
                                            setState(() {
                                              if (status.departIso != null) t['departIso'] = status.departIso;
                                              if (status.arriveIso != null) t['arriveIso'] = status.arriveIso;
                                              if (status.status != null) t['status'] = status.status;
                                            });
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Flight ${t['flightNumber']} ${status.status ?? 'updated'}')),
                                              );
                                            }
                                          } else {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Unable to fetch flight status')), 
                                              );
                                            }
                                          }
                                        },
                                  icon: const Icon(Icons.sync)
                                  ,
                                  label: const Text('Update'),
                                ),
                                const SizedBox(width: 8),
                                if ((t['status'] as String?) != null && (t['status'] as String).isNotEmpty)
                                  Text('Status: ${t['status']}', style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                            Row(
                              children: [
                                SizedBox(
                                  width: 120,
                                  child: TextFormField(
                                    initialValue: () {
                                      final td = _parseTimeOfDay(
                                        t['departIso'] as String?,
                                      );
                                      return td != null ? _fmtHm(td) : '';
                                    }(),
                                    enabled: _isEditing,
                                    decoration: const InputDecoration(
                                      labelText: 'Depart (HH:MM)',
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      _HmTimeFormatter(),
                                    ],
                                    onChanged: (v) {
                                      if (!_isEditing) return;
                                      final text = v.trim();
                                      if (text.isEmpty) {
                                        setState(() {
                                          t['departIso'] = dayKey(days[i]);
                                        });
                                        return;
                                      }
                                      final parts = text.split(':');
                                      if (parts.length == 2) {
                                        final h = int.tryParse(parts[0]);
                                        final m = int.tryParse(parts[1]);
                                        if (h != null &&
                                            m != null &&
                                            h >= 0 &&
                                            h < 24 &&
                                            m >= 0 &&
                                            m < 60) {
                                          setState(() {
                                            t['departIso'] = _mergeDayAndTime(
                                              dayKey(days[i]),
                                              TimeOfDay(hour: h, minute: m),
                                            );
                                          });
                                        }
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 120,
                                  child: TextFormField(
                                    initialValue: () {
                                      final ta = _parseTimeOfDay(
                                        t['arriveIso'] as String?,
                                      );
                                      return ta != null ? _fmtHm(ta) : '';
                                    }(),
                                    enabled: _isEditing,
                                    decoration: const InputDecoration(
                                      labelText: 'Arrive (HH:MM)',
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      _HmTimeFormatter(),
                                    ],
                                    onChanged: (v) {
                                      if (!_isEditing) return;
                                      final text = v.trim();
                                      if (text.isEmpty) {
                                        setState(() {
                                          t['arriveIso'] = dayKey(days[i]);
                                        });
                                        return;
                                      }
                                      final parts = text.split(':');
                                      if (parts.length == 2) {
                                        final h = int.tryParse(parts[0]);
                                        final m = int.tryParse(parts[1]);
                                        if (h != null &&
                                            m != null &&
                                            h >= 0 &&
                                            h < 24 &&
                                            m >= 0 &&
                                            m < 60) {
                                          setState(() {
                                            t['arriveIso'] = _mergeDayAndTime(
                                              dayKey(days[i]),
                                              TimeOfDay(hour: h, minute: m),
                                            );
                                          });
                                        }
                                      }
                                    },
                                  ),
                                ),
                                const Spacer(),
                                Builder(
                                  builder: (ctx) {
                                    final label = _durationLabelStr(
                                      t['departIso'] as String?,
                                      t['arriveIso'] as String?,
                                    );
                                    return label == null
                                        ? const SizedBox.shrink()
                                        : Text('Duration: $label');
                                  },
                                ),
                                SizedBox(
                                  width: 120,
                                  child: TextField(
                                    controller: TextEditingController(
                                      text: (t['price']?.toString() ?? ''),
                                    ),
                                    enabled: _isEditing,
                                    decoration: const InputDecoration(
                                      labelText: 'Price',
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    onChanged: (v) =>
                                        t['price'] = double.tryParse(v),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              // Stays for this day (inline editable)
              ..._stays
                  .where((s) {
                    final ci = isoDay(s['checkInIso'] as String?);
                    final co = isoDay(s['checkOutIso'] as String?);
                    final k = dayKey(days[i]);
                    return ci == k || co == k;
                  })
                  .map(
                    (s) => Card(
                      elevation: 0,
                      color: Theme.of(context).cardColor,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 12,
                          right: 8,
                          top: 8,
                          bottom: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.hotel, size: 16),
                                const SizedBox(width: 8),
                                DropdownButton<String>(
                                  value: (s['type'] as String?) ?? 'hotel',
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'hotel',
                                      child: Text('Hotel'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'airbnb',
                                      child: Text('Airbnb'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'hostel',
                                      child: Text('Hostel'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'family',
                                      child: Text('Family'),
                                    ),
                                  ],
                                  onChanged: !_isEditing
                                      ? null
                                      : (v) => setState(() => s['type'] = v),
                                ),
                                const Spacer(),
                                if (_isEditing)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Remove',
                                    onPressed: () =>
                                        setState(() => _stays.remove(s)),
                                  ),
                              ],
                            ),
                            TextField(
                              controller: TextEditingController(
                                text: (s['name'] as String?) ?? '',
                              ),
                              enabled: _isEditing,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                              ),
                              onChanged: (v) => s['name'] = v,
                            ),
                            Row(
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Checkbox(
                                      value:
                                          (s['checkInEnabled'] as bool?) ??
                                          false,
                                      onChanged: !_isEditing
                                          ? null
                                          : (v) => setState(
                                              () => s['checkInEnabled'] =
                                                  v ?? false,
                                            ),
                                    ),
                                    const Text('Check-in'),
                                  ],
                                ),
                                Builder(
                                  builder: (ctx2) {
                                    final ti = _parseTimeOfDay(
                                      s['checkInIso'] as String?,
                                    );
                                    return SizedBox(
                                      width: 140,
                                      child: TextFormField(
                                        initialValue:
                                            ti != null ? _fmtHm(ti) : '',
                                        enabled: _isEditing,
                                        decoration: const InputDecoration(
                                          labelText: 'Check-in (HH:MM)',
                                        ),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          _HmTimeFormatter(),
                                        ],
                                        onChanged: (v) {
                                          if (!_isEditing ||
                                              s['checkInEnabled'] != true) {
                                            return;
                                          }
                                          final text = v.trim();
                                          if (text.isEmpty) {
                                            setState(() {
                                              s['checkInIso'] = dayKey(days[i]);
                                            });
                                            return;
                                          }
                                          final parts = text.split(':');
                                          if (parts.length == 2) {
                                            final h = int.tryParse(parts[0]);
                                            final m = int.tryParse(parts[1]);
                                            if (h != null &&
                                                m != null &&
                                                h >= 0 &&
                                                h < 24 &&
                                                m >= 0 &&
                                                m < 60) {
                                              setState(() {
                                                s['checkInIso'] =
                                                    _mergeDayAndTime(
                                                      dayKey(days[i]),
                                                      TimeOfDay(
                                                        hour: h,
                                                        minute: m,
                                                      ),
                                                    );
                                              });
                                            }
                                          }
                                        },
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Checkbox(
                                      value:
                                          (s['checkOutEnabled'] as bool?) ??
                                          false,
                                      onChanged: !_isEditing
                                          ? null
                                          : (v) => setState(
                                              () => s['checkOutEnabled'] =
                                                  v ?? false,
                                            ),
                                    ),
                                    const Text('Check-out'),
                                  ],
                                ),
                                Builder(
                                  builder: (ctx2) {
                                    final to = _parseTimeOfDay(
                                      s['checkOutIso'] as String?,
                                    );
                                    return SizedBox(
                                      width: 140,
                                      child: TextFormField(
                                        initialValue:
                                            to != null ? _fmtHm(to) : '',
                                        enabled: _isEditing,
                                        decoration: const InputDecoration(
                                          labelText: 'Check-out (HH:MM)',
                                        ),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          _HmTimeFormatter(),
                                        ],
                                        onChanged: (v) {
                                          if (!_isEditing ||
                                              s['checkOutEnabled'] != true) {
                                            return;
                                          }
                                          final text = v.trim();
                                          if (text.isEmpty) {
                                            setState(() {
                                              s['checkOutIso'] = dayKey(days[i]);
                                            });
                                            return;
                                          }
                                          final parts = text.split(':');
                                          if (parts.length == 2) {
                                            final h = int.tryParse(parts[0]);
                                            final m = int.tryParse(parts[1]);
                                            if (h != null &&
                                                m != null &&
                                                h >= 0 &&
                                                h < 24 &&
                                                m >= 0 &&
                                                m < 60) {
                                              setState(() {
                                                s['checkOutIso'] =
                                                    _mergeDayAndTime(
                                                      dayKey(days[i]),
                                                      TimeOfDay(
                                                        hour: h,
                                                        minute: m,
                                                      ),
                                                    );
                                              });
                                            }
                                          }
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                SizedBox(
                                  width: 120,
                                  child: TextField(
                                    controller: TextEditingController(
                                      text: (s['price']?.toString() ?? ''),
                                    ),
                                    enabled: _isEditing,
                                    decoration: const InputDecoration(
                                      labelText: 'Price',
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    onChanged: (v) =>
                                        s['price'] = double.tryParse(v),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              // Activities for this day (inline editable)
              ..._activities
                  .where((a) {
                    final w = isoDay(a['whenIso'] as String?);
                    final k = dayKey(days[i]);
                    return w == k;
                  })
                  .map(
                    (a) => Card(
                      elevation: 0,
                      color: Theme.of(context).cardColor,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 12,
                          right: 8,
                          top: 8,
                          bottom: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (a['kind'] == 'city')
                                  const Icon(Icons.location_city, size: 16)
                                else
                                  const Icon(Icons.event, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: TextEditingController(
                                      text: (a['title']?.toString() ?? ''),
                                    ),
                                    enabled: _isEditing,
                                    decoration: InputDecoration(
                                      labelText: a['kind'] == 'city'
                                          ? 'City'
                                          : 'Activity',
                                    ),
                                    onChanged: (v) => a['title'] = v,
                                  ),
                                ),
                                if (_isEditing && a['kind'] == 'city') ...[
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_upward,
                                      size: 18,
                                    ),
                                    tooltip: 'Move up',
                                    onPressed: () {
                                      final k = dayKey(days[i]);
                                      final local = _cityIndicesForDay(k)
                                          .indexWhere(
                                            (idx) => _activities[idx] == a,
                                          );
                                      if (local != -1)
                                        _moveCityStopUp(k, local);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_downward,
                                      size: 18,
                                    ),
                                    tooltip: 'Move down',
                                    onPressed: () {
                                      final k = dayKey(days[i]);
                                      final local = _cityIndicesForDay(k)
                                          .indexWhere(
                                            (idx) => _activities[idx] == a,
                                          );
                                      if (local != -1)
                                        _moveCityStopDown(k, local);
                                    },
                                  ),
                                ],
                                if (_isEditing)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Remove',
                                    onPressed: () =>
                                        setState(() => _activities.remove(a)),
                                  ),
                              ],
                            ),
                            if (a['kind'] != 'city')
                              Row(
                                children: [
                                  SizedBox(
                                    width: 120,
                                    child: TextFormField(
                                      initialValue: () {
                                        final t = _parseTimeOfDay(
                                          a['whenIso'] as String?,
                                        );
                                        return t != null ? _fmtHm(t) : '';
                                      }(),
                                      enabled: _isEditing,
                                      decoration: const InputDecoration(
                                        labelText: 'Time (HH:MM)',
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        _HmTimeFormatter(),
                                      ],
                                      onChanged: (v) {
                                        if (!_isEditing) return;
                                        final text = v.trim();
                                        if (text.isEmpty) {
                                          setState(() {
                                            a['whenIso'] = dayKey(days[i]);
                                          });
                                          return;
                                        }
                                        final parts = text.split(':');
                                        if (parts.length == 2) {
                                          final h = int.tryParse(parts[0]);
                                          final m = int.tryParse(parts[1]);
                                          if (h != null &&
                                              m != null &&
                                              h >= 0 &&
                                              h < 24 &&
                                              m >= 0 &&
                                              m < 60) {
                                            setState(() {
                                              a['whenIso'] = _mergeDayAndTime(
                                                dayKey(days[i]),
                                                TimeOfDay(hour: h, minute: m),
                                              );
                                            });
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                  const Spacer(),
                                  // Manual re-order within the day for activities
                                  if (_isEditing) ...[
                                    IconButton(
                                      icon: const Icon(Icons.arrow_upward, size: 18),
                                      tooltip: 'Move up',
                                      onPressed: () {
                                        final k = dayKey(days[i]);
                                        final idx = _activities.indexOf(a);
                                        if (idx != -1) _moveActivityUp(k, idx);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.arrow_downward, size: 18),
                                      tooltip: 'Move down',
                                      onPressed: () {
                                        final k = dayKey(days[i]);
                                        final idx = _activities.indexOf(a);
                                        if (idx != -1) _moveActivityDown(k, idx);
                                      },
                                    ),
                                  ],
                                  SizedBox(
                                    width: 120,
                                    child: TextField(
                                      controller: TextEditingController(
                                        text: (a['price']?.toString() ?? ''),
                                      ),
                                      enabled: _isEditing,
                                      decoration: const InputDecoration(
                                        labelText: 'Price',
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      onChanged: (v) =>
                                          a['price'] = double.tryParse(v),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('Must-do'),
                                      Switch(
                                        value: a['mustDo'] == true,
                                        onChanged: !_isEditing
                                            ? null
                                            : (v) => setState(
                                                () => a['mustDo'] = v,
                                              ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector(BuildContext context) {
    final List<Map<String, dynamic>> cats = [
      {'label': 'Cities', 'icon': Icons.location_city},
      {'label': 'Transport', 'icon': Icons.flight_takeoff},
      {'label': 'Lodging', 'icon': Icons.hotel},
      {'label': 'Activities', 'icon': Icons.checklist},
      {'label': 'Notifications', 'icon': Icons.notifications_active_outlined},
      {'label': 'Weather', 'icon': Icons.wb_cloudy_outlined},
      {'label': 'Photos', 'icon': Icons.photo_library_outlined},
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final c in cats)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _selectedCategory == (c['label'] as String)
                  ? FilledButton.tonal(
                      onPressed: () {},
                      child: Row(
                        children: [
                          Icon(c['icon'] as IconData),
                          const SizedBox(width: 6),
                          Text(c['label'] as String),
                        ],
                      ),
                    )
                  : OutlinedButton(
                      onPressed: () => setState(
                        () => _selectedCategory = c['label'] as String,
                      ),
                      child: Row(
                        children: [
                          Icon(c['icon'] as IconData),
                          const SizedBox(width: 6),
                          Text(c['label'] as String),
                        ],
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedCategoryEditor(BuildContext context) {
    switch (_selectedCategory) {
      case 'Cities':
        return _ChipEditor(
          values: _cities,
          controller: _cityController,
          options: const <String>[],
          hintText: 'Add city',
          addButtonLabel: 'Add City',
          readonly: !_isEditing,
        );
      case 'Transport':
        return _SectionList(
          title: 'Transport',
          showTitle: false,
          items: _transports,
          readonly: !_isEditing,
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
        );
      case 'Lodging':
        return _SectionList(
          title: 'Lodging',
          showTitle: false,
          items: _stays,
          readonly: !_isEditing,
          onAdd: () => setState(
            () => _stays.add({
              'type': 'hotel',
              'name': '',
              'checkInIso': '',
              'checkOutIso': '',
              'price': null,
            }),
          ),
        );
      case 'Activities':
        return _SectionList(
          title: 'Activities',
          showTitle: false,
          items: _activities,
          readonly: !_isEditing,
          onAdd: () => setState(
            () => _activities.add({
              'title': '',
              'whenIso': '',
              'mustDo': true,
              'price': null,
            }),
          ),
        );
      case 'Notifications':
        return _SectionList(
          title: 'Notifications',
          showTitle: false,
          items: _notificationRules,
          readonly: !_isEditing,
          onAdd: () => setState(
            () => _notificationRules.add({
              'type': 'local',
              'whenIso': '',
              'message': '',
            }),
          ),
        );
      case 'Weather':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              value: _weatherEnabled,
              onChanged: _isEditing
                  ? (val) => setState(() => _weatherEnabled = val)
                  : null,
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
                  onChanged: _isEditing && _weatherEnabled
                      ? (v) => setState(() => _weatherUnits = v ?? 'metric')
                      : null,
                ),
              ],
            ),
          ],
        );
      case 'Photos':
        return Wrap(
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
            if (_isEditing)
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
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  child: const Icon(Icons.add_a_photo_outlined),
                ),
              ),
          ],
        );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title), actions: actions),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 4,
      initialIndex: _tabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: actions,
          bottom: TabBar(
            onTap: (i) => setState(() => _tabIndex = i),
            tabs: const [
              Tab(text: 'Itinerary'),
              Tab(text: 'Map'),
              Tab(text: 'Docs'),
              Tab(text: 'Expenses'),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            SafeArea(
              child: _isEditing
                  ? Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _TitleHeader(
                            title: _titleController.text.trim(),
                            countryCode: _countryController.text.trim(),
                            start: _startDate,
                            end: _endDate,
                            onEdit: () => setState(() => _isEditing = true),
                            onDelete: _delete,
                          ),
                          const SizedBox(height: 16),
                          if (_isEditing) ...[
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Title',
                              ),
                            ),
                            TextFormField(
                              controller: _countryController,
                              decoration: const InputDecoration(
                                labelText: 'Country Code (e.g., US)',
                              ),
                            ),
                            TextFormField(
                              controller: _budgetController,
                              decoration: const InputDecoration(
                                labelText: 'Budget (optional)',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Trip Dates'),
                              subtitle: Text(
                                (_startDate != null || _endDate != null)
                                    ? '${_startDate != null ? _fmtMdy(_startDate!) : 'TBD'} — ${_endDate != null ? _fmtMdy(_endDate!) : 'TBD'}'
                                    : 'Select range',
                              ),
                              onTap: () async {
                                final range = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                  initialDateRange:
                                      (_startDate != null && _endDate != null)
                                      ? DateTimeRange(
                                          start: _startDate!,
                                          end: _endDate!,
                                        )
                                      : null,
                                  helpText: 'Select trip dates',
                                );
                                if (range != null) {
                                  setState(() {
                                    _startDate = range.start;
                                    _endDate = range.end;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                          SwitchListTile(
                            value: _isCurrent,
                            onChanged: (v) => setState(() => _isCurrent = v),
                            title: const Text('Current trip'),
                            subtitle: const Text('Show quick add on home'),
                          ),
                          const SizedBox(height: 8),
                          _buildDaySections(context),
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () async {
                                      await _save(closeAfter: false);
                                      if (mounted) {
                                        setState(() {
                                          _isEditing = false;
                                        });
                                      }
                                    },
                              icon: const Icon(Icons.check),
                              label: Text(
                                _saving ? 'Saving...' : 'Save Changes',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        16 + MediaQuery.of(context).viewPadding.bottom,
                      ),
                      children: _buildTimeline(context),
                    ),
            ),
            // Map tab embedded (no Scaffold)
            const _EmbeddedMap(),
            // Documents tab
            _DocumentsTab(
              documents: _documents,
              onAdd: (doc) => setState(() => _documents.add(doc)),
              onDelete: (i) => setState(() => _documents.removeAt(i)),
            ),
            // Expenses tab (simple per-trip)
            _TripExpensesTab(
              expenses: _tripExpenses,
              onAdd: (e) => setState(() => _tripExpenses.add(e)),
              onDelete: (i) => setState(() => _tripExpenses.removeAt(i)),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTimeline(BuildContext context) {
    final events = <Map<String, dynamic>>[];
    void addEvent(
      String? iso,
      String title,
      String subtitle,
      IconData icon, {
      String kind = '',
    }) {
      if (iso == null || iso.isEmpty) return;
      events.add({
        'iso': iso,
        'title': title,
        'subtitle': subtitle,
        'icon': icon,
        'kind': kind,
      });
    }

    for (int ti = 0; ti < _transports.length; ti++) {
      final t = _transports[ti];
      final flightNo = (t['flightNumber'] as String?)?.trim();
      final modeLabel = (t['mode'] ?? 'flight').toString();
      final durationLabel = _durationLabelStr(
        t['departIso'] as String?,
        t['arriveIso'] as String?,
      );
      addEvent(
        t['departIso'] as String?,
        'Depart from ${t['from'] ?? ''}${flightNo != null && flightNo.isNotEmpty ? ' ($flightNo)' : ''}',
        modeLabel,
        Icons.flight_takeoff,
        kind: 'transport_depart',
      );
      events.last['idx'] = ti;
      addEvent(
        t['arriveIso'] as String?,
        'Arrive to ${t['to'] ?? ''}${flightNo != null && flightNo.isNotEmpty ? ' ($flightNo)' : ''}',
        durationLabel != null ? '$modeLabel • $durationLabel' : modeLabel,
        Icons.flight_land,
        kind: 'transport_arrive',
      );
      events.last['idx'] = ti;
    }
    for (int si = 0; si < _stays.length; si++) {
      final s = _stays[si];
      addEvent(
        s['checkInIso'] as String?,
        'Check-in ${s['name'] ?? s['type'] ?? 'stay'}',
        '',
        Icons.login,
        kind: 'stay_checkin',
      );
      events.last['idx'] = si;
      addEvent(
        s['checkOutIso'] as String?,
        'Check-out ${s['name'] ?? s['type'] ?? 'stay'}',
        '',
        Icons.logout,
        kind: 'stay_checkout',
      );
      events.last['idx'] = si;
    }
    for (int ai = 0; ai < _activities.length; ai++) {
      final a = _activities[ai];
      addEvent(
        a['whenIso'] as String?,
        a['title']?.toString() ?? 'Activity',
        a['mustDo'] == true ? 'Must-do' : 'Wishlist',
        Icons.event,
        kind: 'activity',
      );
      events.last['idx'] = ai;
    }
    // Earliest first, tie-break by kind (depart before arrive, transport before others)
    int rank(String? k) {
      switch (k) {
        case 'transport_depart':
          return 0;
        case 'transport_arrive':
          return 1;
        case 'stay_checkin':
          return 2;
        case 'stay_checkout':
          return 3;
        case 'activity':
          return 4;
        default:
          return 99;
      }
    }
    int cmp(Map<String, dynamic> a, Map<String, dynamic> b) {
      final c = (a['iso'] as String).compareTo(b['iso'] as String);
      if (c != 0) return c;
      final r = rank(a['kind'] as String?) - rank(b['kind'] as String?);
      if (r != 0) return r;
      // Fallback to original list index to preserve manual reordering within category
      final ia = (a['idx'] as int?) ?? 0;
      final ib = (b['idx'] as int?) ?? 0;
      return ia.compareTo(ib);
    }
    events.sort(cmp);

    // Group by day (YYYY-MM-DD)
    final Map<String, List<Map<String, dynamic>>> byDay =
        <String, List<Map<String, dynamic>>>{};
    String dayKey(String iso) => iso.length >= 10 ? iso.substring(0, 10) : iso;
    for (final e in events) {
      final k = dayKey(e['iso'] as String);
      (byDay[k] ??= <Map<String, dynamic>>[]).add(e);
    }

    String monthLabel(String ym) {
      // ym like 2025-06
      if (ym.length < 7) return ym;
      final y = ym.substring(0, 4);
      final m = int.tryParse(ym.substring(5, 7)) ?? 1;
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
      return '${months[m - 1]} $y';
    }

    final grouped = <Widget>[
      _TitleHeader(
        title: _titleController.text.trim(),
        countryCode: _countryController.text.trim(),
        start: _startDate,
        end: _endDate,
        onEdit: () => setState(() => _isEditing = true),
        onDelete: _delete,
      ),
      const SizedBox(height: 16),
    ];

    if (events.isEmpty) {
      grouped.add(
        Center(
          child: Text(
            'No timeline items yet. Add transport, lodging, or activities to see them here.',
          ),
        ),
      );
    } else {
      // Iterate days earliest first
      final days = byDay.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      String fmtDmy(String ymd) {
        if (ymd.length < 10) return ymd;
        final y = ymd.substring(0, 4);
        final m = ymd.substring(5, 7);
        final d = ymd.substring(8, 10);
        return '$m-$d-$y';
      }

      for (final day in days) {
        grouped.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.today, size: 16),
                const SizedBox(width: 8),
                Text(
                  fmtDmy(day.key),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        );
        final dayEvents = day.value..sort((a, b) {
            final c = (a['iso'] as String).compareTo(b['iso'] as String);
            if (c != 0) return c;
            int rank(String? k) {
              switch (k) {
                case 'transport_depart':
                  return 0;
                case 'transport_arrive':
                  return 1;
                case 'stay_checkin':
                  return 2;
                case 'stay_checkout':
                  return 3;
                case 'activity':
                  return 4;
                default:
                  return 99;
              }
            }
            return rank(a['kind'] as String?) - rank(b['kind'] as String?);
          });
        // Compute stable tokens for manual ordering and apply manual order if present
        String tokenOf(Map<String, dynamic> e) {
          final kind = (e['kind'] as String?) ?? '';
          final idx = (e['idx'] as int?) ?? -1;
          switch (kind) {
            case 'transport_depart':
              return 'td-$idx';
            case 'transport_arrive':
              return 'ta-$idx';
            case 'stay_checkin':
              return 'si-$idx';
            case 'stay_checkout':
              return 'so-$idx';
            case 'activity':
              return 'a-$idx';
            default:
              return 'x-$idx';
          }
        }
        for (final e in dayEvents) {
          e['token'] = tokenOf(e);
        }
        final manual = _timelineOrder[day.key];
        if (manual != null && manual.isNotEmpty) {
          final pos = <String, int>{};
          for (int i = 0; i < manual.length; i++) pos[manual[i]] = i;
          dayEvents.sort((a, b) {
            final at = pos[a['token'] as String];
            final bt = pos[b['token'] as String];
            if (at != null && bt != null) return at.compareTo(bt);
            if (at != null) return -1;
            if (bt != null) return 1;
            return 0;
          });
        }
        grouped.add(
          ReorderableListView.builder(
            key: ValueKey('rlv-${day.key}'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex -= 1;
              final tokens = dayEvents.map((e) => e['token'] as String).toList();
              final item = tokens.removeAt(oldIndex);
              tokens.insert(newIndex, item);
              setState(() {
                _timelineOrder[day.key] = tokens;
              });
              // Persist manual order
              await _data.updateItinerary(
                itineraryId: widget.itineraryId,
                updates: {'timelineOrder': _timelineOrder},
              );
            },
            itemCount: dayEvents.length,
            itemBuilder: (context, i) {
              final e = dayEvents[i];
              return Container(
                key: ValueKey(e['token'] as String),
                margin: const EdgeInsets.only(bottom: 8),
                child: _TimelineEntry(
                  iso: e['iso'] as String,
                  title: e['title'] as String,
                  subtitle: e['subtitle'] as String,
                  icon: e['icon'] as IconData,
                  isFirst: i == 0,
                  isLast: i == dayEvents.length - 1,
                ),
              );
            },
          ),
        );
        grouped.add(const SizedBox(height: 12));
      }
    }

    return grouped;
  }
}

class _ChipEditor extends StatefulWidget {
  const _ChipEditor({
    required this.values,
    required this.controller,
    this.options = const [],
    this.hintText = 'Add item',
    this.addButtonLabel = 'Add',
    this.readonly = false,
  });

  final List<String> values;
  final TextEditingController controller;
  final List<String> options;
  final String hintText;
  final String addButtonLabel;
  final bool readonly;

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
    if (widget.readonly) {
      return Chip(label: Text(value));
    }
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
        if (!widget.readonly && widget.options.isNotEmpty) ...[
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
        if (!widget.readonly) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  decoration: InputDecoration(hintText: widget.hintText),
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
                child: Text(widget.addButtonLabel),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SectionList extends StatefulWidget {
  const _SectionList({
    required this.items,
    required this.onAdd,
    this.title,
    this.showTitle = false,
    this.readonly = false,
  });

  final String? title;
  final List<Map<String, dynamic>> items;
  final VoidCallback onAdd;
  final bool showTitle;
  final bool readonly;

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
            if (widget.showTitle && widget.title != null)
              Text(
                widget.title!,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            if (widget.showTitle && widget.title != null) const Spacer(),
            if (!widget.readonly)
              IconButton(
                onPressed: widget.onAdd,
                icon: const Icon(Icons.add),
                tooltip: 'Add',
              ),
          ],
        ),
        if (widget.showTitle && widget.title != null) const SizedBox(height: 8),
        if (widget.items.isEmpty)
          Text('No items', style: Theme.of(context).textTheme.bodySmall)
        else
          Column(
            children: [
              for (int i = 0; i < widget.items.length; i++)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _EditableCard(
                        data: widget.items[i],
                        onDelete: widget.readonly
                            ? null
                            : () => setState(() => widget.items.removeAt(i)),
                        readonly: widget.readonly,
                      ),
                    ),
                    if (!widget.readonly)
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_upward, size: 18),
                            tooltip: 'Move up',
                            onPressed: i == 0
                                ? null
                                : () => setState(() {
                                      final item = widget.items.removeAt(i);
                                      widget.items.insert(i - 1, item);
                                    }),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_downward, size: 18),
                            tooltip: 'Move down',
                            onPressed: i >= widget.items.length - 1
                                ? null
                                : () => setState(() {
                                      final item = widget.items.removeAt(i);
                                      widget.items.insert(i + 1, item);
                                    }),
                          ),
                        ],
                      ),
                  ],
                ),
            ],
          ),
      ],
    );
  }
}

class _EditableCard extends StatefulWidget {
  const _EditableCard({
    required this.data,
    required this.onDelete,
    this.readonly = false,
  });
  final Map<String, dynamic> data;
  final VoidCallback? onDelete;
  final bool readonly;

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
                onChanged: widget.readonly
                    ? null
                    : (v) => setState(() => widget.data[e.key] = v),
                readonly: widget.readonly,
              ),
            if (!widget.readonly)
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
    this.readonly = false,
  });
  final String label;
  final String value;
  final ValueChanged<String>? onChanged;
  final bool readonly;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        initialValue: value,
        enabled: !readonly,
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      ),
    );
  }
}

// Collapsible removed in favor of horizontal category selector

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
    required this.onDelete,
  });

  final String title;
  final String countryCode;
  final DateTime? start;
  final DateTime? end;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
            // Remove country code tile per request
            const SizedBox(width: 0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? 'Untitled Trip' : title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmbeddedMap extends StatefulWidget {
  const _EmbeddedMap();

  @override
  State<_EmbeddedMap> createState() => _EmbeddedMapState();
}

class _EmbeddedMapState extends State<_EmbeddedMap> {
  final Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> _markers = <Marker>{};
  final List<String> _filters = const ['☕', '🍜', '🏛️', '🌊'];
  String? _activeFilter;

  @override
  void initState() {
    super.initState();
    _seedMockMarkers();
  }

  void _seedMockMarkers() {
    const base = LatLng(35.6762, 139.6503); // Tokyo
    final mock = <(String, LatLng, String)>[
      ('☕', LatLng(base.latitude + 0.01, base.longitude + 0.01), 'Blue Bottle'),
      ('🍜', LatLng(base.latitude - 0.008, base.longitude + 0.002), 'Ichiran'),
      ('🏛️', LatLng(base.latitude + 0.004, base.longitude - 0.01), 'Museum'),
      ('🌊', LatLng(base.latitude - 0.012, base.longitude - 0.006), 'Odaiba'),
    ];
    _markers
      ..clear()
      ..addAll(
        mock
            .where((m) => _activeFilter == null || _activeFilter == m.$1)
            .map(
              (m) => Marker(
                markerId: MarkerId('${m.$1}-${m.$3}'),
                position: m.$2,
                infoWindow: InfoWindow(title: '${m.$1} ${m.$3}'),
              ),
            ),
      );
    if (mounted) setState(() {});
  }

  void _toggleFilter(String? emoji) {
    _activeFilter = _activeFilter == emoji ? null : emoji;
    _seedMockMarkers();
  }

  @override
  Widget build(BuildContext context) {
    const camera = CameraPosition(target: LatLng(35.6762, 139.6503), zoom: 12);
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: camera,
          markers: _markers,
          onMapCreated: (c) => _controller.complete(c),
          myLocationButtonEnabled: false,
          compassEnabled: false,
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Card(
            color: Theme.of(context).cardColor,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Text('Filter:'),
                  const SizedBox(width: 8),
                  Wrap(
                    spacing: 8,
                    children: _filters
                        .map(
                          (e) => FilterChip(
                            label: Text(
                              e,
                              style: const TextStyle(fontSize: 18),
                            ),
                            selected: _activeFilter == e,
                            onSelected: (_) => _toggleFilter(e),
                          ),
                        )
                        .toList(),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.layers_outlined),
                    onPressed: () {},
                    tooltip: 'Layers',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DocumentsTab extends StatelessWidget {
  const _DocumentsTab({
    required this.documents,
    required this.onAdd,
    required this.onDelete,
  });

  final List<Map<String, dynamic>> documents;
  final void Function(Map<String, dynamic>) onAdd;
  final void Function(int index) onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text('Documents', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              IconButton(
                onPressed: () => onAdd({
                  'type': 'booking',
                  'name': 'New Document',
                  'note': '',
                }),
                icon: const Icon(Icons.add),
                tooltip: 'Add Document',
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (documents.isEmpty)
            Text('No documents', style: Theme.of(context).textTheme.bodySmall)
          else
            Column(
              children: [
                for (int i = 0; i < documents.length; i++)
                  Card(
                    elevation: 0,
                    color: Theme.of(context).cardColor,
                    child: ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(
                        documents[i]['name']?.toString() ?? 'Document',
                      ),
                      subtitle: Text(documents[i]['type']?.toString() ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => onDelete(i),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TripExpensesTab extends StatelessWidget {
  const _TripExpensesTab({
    required this.expenses,
    required this.onAdd,
    required this.onDelete,
  });

  final List<Map<String, dynamic>> expenses;
  final void Function(Map<String, dynamic>) onAdd;
  final void Function(int index) onDelete;

  @override
  Widget build(BuildContext context) {
    final total = expenses.fold<double>(
      0.0,
      (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0),
    );
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text(
                'Trip Expenses',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                onPressed: () => onAdd({
                  'amount': 0.0,
                  'currency': 'USD',
                  'description': 'New expense',
                }),
                icon: const Icon(Icons.add),
                tooltip: 'Add Expense',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: Theme.of(context).cardColor,
            child: ListTile(
              leading: const Icon(Icons.summarize_outlined),
              title: const Text('Total'),
              trailing: Text(total.toStringAsFixed(2)),
            ),
          ),
          const SizedBox(height: 8),
          if (expenses.isEmpty)
            Text('No expenses', style: Theme.of(context).textTheme.bodySmall)
          else
            Column(
              children: [
                for (int i = 0; i < expenses.length; i++)
                  Card(
                    elevation: 0,
                    color: Theme.of(context).cardColor,
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: Text(
                        expenses[i]['description']?.toString() ?? 'Expense',
                      ),
                      subtitle: Text(
                        '${expenses[i]['currency'] ?? 'USD'} ${(expenses[i]['amount'] ?? 0).toString()}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => onDelete(i),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
