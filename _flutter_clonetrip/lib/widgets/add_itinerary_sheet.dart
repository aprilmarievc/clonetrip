import 'package:flutter/material.dart';

class AddItinerarySheet extends StatefulWidget {
  const AddItinerarySheet({
    super.key,
    required this.onSubmit,
    this.isWishlist = false,
  });

  final bool isWishlist;
  final Future<void> Function({
    required String title,
    String? countryCode,
    List<String>? cities,
    String? startDateIso,
    String? endDateIso,
  })
  onSubmit;

  @override
  State<AddItinerarySheet> createState() => _AddItinerarySheetState();
}

class _AddItinerarySheetState extends State<AddItinerarySheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _citiesController = TextEditingController();
  final _countryController = TextEditingController(text: 'US');
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isWishlist ? 'Add Wishlist' : 'Add Trip',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _citiesController,
                decoration: const InputDecoration(
                  labelText: 'Cities (comma-separated)',
                  hintText: 'e.g., Tokyo, Kyoto',
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startController,
                      decoration: const InputDecoration(
                        labelText: 'Start (YYYY-MM-DD)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _endController,
                      decoration: const InputDecoration(
                        labelText: 'End (YYYY-MM-DD)',
                      ),
                    ),
                  ),
                ],
              ),
              TextFormField(
                controller: _countryController,
                decoration: const InputDecoration(
                  labelText: 'Country Code (optional, e.g., US, JP)',
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          setState(() => _saving = true);
                          try {
                            final cc = _countryController.text.trim();
                            final citiesText = _citiesController.text.trim();
                            final List<String>? cities = citiesText.isEmpty
                                ? null
                                : citiesText
                                    .split(',')
                                    .map((s) => s.trim())
                                    .where((s) => s.isNotEmpty)
                                    .toList();
                            await widget.onSubmit(
                              title: _titleController.text.trim(),
                              countryCode: cc.isEmpty ? null : cc,
                              cities: cities,
                              startDateIso: _startController.text.trim().isEmpty
                                  ? null
                                  : _startController.text.trim(),
                              endDateIso: _endController.text.trim().isEmpty
                                  ? null
                                  : _endController.text.trim(),
                            );
                            if (!mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Trip created'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to save: $e')),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                  icon: const Icon(Icons.check),
                  label: Text(_saving ? 'Saving...' : 'Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
