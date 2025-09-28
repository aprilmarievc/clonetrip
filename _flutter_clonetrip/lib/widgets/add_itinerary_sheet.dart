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
    required String countryCode,
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
                controller: _countryController,
                decoration: const InputDecoration(
                  labelText: 'Country Code (e.g., US, JP)',
                ),
                validator: (v) =>
                    v == null || v.length != 2 ? '2-letter code' : null,
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
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          setState(() => _saving = true);
                          await widget.onSubmit(
                            title: _titleController.text.trim(),
                            countryCode: _countryController.text.trim(),
                            startDateIso: _startController.text.trim().isEmpty
                                ? null
                                : _startController.text.trim(),
                            endDateIso: _endController.text.trim().isEmpty
                                ? null
                                : _endController.text.trim(),
                          );
                          if (mounted) Navigator.pop(context);
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
