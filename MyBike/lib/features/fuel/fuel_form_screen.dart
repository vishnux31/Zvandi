import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/formatters.dart';
import '../../core/units.dart';
import '../../data/models/fuel_entry.dart';
import '../../providers/app_providers.dart';
import '../../providers/settings_provider.dart';

class FuelFormScreen extends ConsumerStatefulWidget {
  final String bikeId;
  final String? fuelId;
  const FuelFormScreen({super.key, required this.bikeId, this.fuelId});

  @override
  ConsumerState<FuelFormScreen> createState() => _FuelFormScreenState();
}

class _FuelFormScreenState extends ConsumerState<FuelFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _odometer = TextEditingController();
  final _liters = TextEditingController();
  final _cost = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();
  bool _fullTank = true;

  FuelEntry? _existing;
  bool _loaded = false;

  bool get _isEditing => widget.fuelId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final unit = ref.read(settingsProvider).distanceUnit;
    final bike = ref.read(bikeByIdProvider(widget.bikeId));

    if (_isEditing) {
      final entry = ref
          .read(fuelProvider)
          .where((e) => e.id == widget.fuelId)
          .firstOrNull;
      if (entry != null) {
        _existing = entry;
        _date = entry.date;
        _fullTank = entry.fullTank;
        _odometer.text = unit.fromKm(entry.odometerKm).round().toString();
        _liters.text = entry.liters.toString();
        _cost.text = entry.cost?.toString() ?? '';
        _notes.text = entry.notes ?? '';
        return;
      }
    }
    _odometer.text = unit.fromKm(bike?.odometerKm ?? 0).round().toString();
  }

  @override
  void dispose() {
    _odometer.dispose();
    _liters.dispose();
    _cost.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final unit = ref.read(settingsProvider).distanceUnit;
    final odoKm = unit.toKm(double.tryParse(_odometer.text.trim()) ?? 0);

    final entry = (_existing ??
            FuelEntry(
              id: const Uuid().v4(),
              bikeId: widget.bikeId,
              date: DateTime.now(),
              odometerKm: 0,
              liters: 0,
              createdAt: DateTime.now(),
            ))
        .copyWith(
      date: _date,
      odometerKm: odoKm,
      liters: double.tryParse(_liters.text.trim()) ?? 0,
      cost: double.tryParse(_cost.text.trim()),
      clearCost: _cost.text.trim().isEmpty,
      fullTank: _fullTank,
      notes: _notes.text.trim(),
    );

    ref.read(fuelProvider.notifier).save(entry);

    final bike = ref.read(bikeByIdProvider(widget.bikeId));
    if (bike != null && odoKm > bike.odometerKm) {
      ref.read(bikesProvider.notifier).save(bike.copyWith(odometerKm: odoKm));
    }

    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(settingsProvider).distanceUnit;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit fuel-up' : 'Add fuel-up')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
              leading: const Icon(Icons.event),
              title: const Text('Date'),
              subtitle: Text(formatDate(_date)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _odometer,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Odometer (${unit.label}) *',
                prefixIcon: const Icon(Icons.speed),
              ),
              validator: (v) =>
                  double.tryParse((v ?? '').trim()) == null ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _liters,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Litres *',
                prefixIcon: Icon(Icons.local_gas_station),
              ),
              validator: (v) {
                final value = double.tryParse((v ?? '').trim());
                if (value == null || value <= 0) return 'Required';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _cost,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Cost',
                prefixText: '$kCurrencySymbol ',
              ),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              value: _fullTank,
              onChanged: (v) => setState(() => _fullTank = v),
              title: const Text('Filled the tank completely'),
              subtitle: const Text('Needed for accurate mileage calculation'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(_isEditing ? 'Save changes' : 'Add fuel-up'),
            ),
          ],
        ),
      ),
    );
  }
}
