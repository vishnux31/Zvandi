import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/formatters.dart';
import '../../core/units.dart';
import '../../data/models/enums.dart';
import '../../data/models/maintenance_item.dart';
import '../../providers/app_providers.dart';
import '../../providers/settings_provider.dart';

class ItemFormScreen extends ConsumerStatefulWidget {
  final String bikeId;
  final String? itemId;
  const ItemFormScreen({super.key, required this.bikeId, this.itemId});

  @override
  ConsumerState<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends ConsumerState<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _intervalKm = TextEditingController();
  final _intervalMonths = TextEditingController();
  final _lastOdo = TextEditingController();
  final _notes = TextEditingController();
  ServiceType _type = ServiceType.engineOil;
  DateTime _lastDate = DateTime.now();

  MaintenanceItem? _existing;
  bool _loaded = false;

  bool get _isEditing => widget.itemId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final unit = ref.read(settingsProvider).distanceUnit;

    if (_isEditing) {
      final item = ref
          .read(itemsProvider)
          .where((e) => e.id == widget.itemId)
          .firstOrNull;
      if (item != null) {
        _existing = item;
        _name.text = item.name;
        _type = item.type;
        _intervalKm.text =
            item.intervalKm == null ? '' : unit.fromKm(item.intervalKm!).round().toString();
        _intervalMonths.text = item.intervalMonths?.toString() ?? '';
        _lastOdo.text = unit.fromKm(item.lastServiceOdometerKm).round().toString();
        _lastDate = item.lastServiceDate;
        _notes.text = item.notes ?? '';
        return;
      }
    }
    // Defaults for a new item.
    _applyTypeDefaults(_type, unit);
    final bike = ref.read(bikeByIdProvider(widget.bikeId));
    _lastOdo.text =
        unit.fromKm(bike?.odometerKm ?? 0).round().toString();
  }

  void _applyTypeDefaults(ServiceType type, DistanceUnit unit) {
    _name.text = type.label;
    _intervalKm.text = type.defaultIntervalKm == null
        ? ''
        : unit.fromKm(type.defaultIntervalKm!).round().toString();
    _intervalMonths.text = type.defaultIntervalMonths?.toString() ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _intervalKm.dispose();
    _intervalMonths.dispose();
    _lastOdo.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final unit = ref.read(settingsProvider).distanceUnit;
    final intervalKmVal = double.tryParse(_intervalKm.text.trim());
    final intervalMonthsVal = int.tryParse(_intervalMonths.text.trim());

    if (intervalKmVal == null && intervalMonthsVal == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Set a distance interval, a time interval, or both.'),
      ));
      return;
    }

    final item = (_existing ??
            MaintenanceItem(
              id: const Uuid().v4(),
              bikeId: widget.bikeId,
              name: '',
              type: _type,
              lastServiceOdometerKm: 0,
              lastServiceDate: DateTime.now(),
              createdAt: DateTime.now(),
            ))
        .copyWith(
      name: _name.text.trim(),
      type: _type,
      intervalKm: intervalKmVal == null ? null : unit.toKm(intervalKmVal),
      clearIntervalKm: intervalKmVal == null,
      intervalMonths: intervalMonthsVal,
      clearIntervalMonths: intervalMonthsVal == null,
      lastServiceOdometerKm:
          unit.toKm(double.tryParse(_lastOdo.text.trim()) ?? 0),
      lastServiceDate: _lastDate,
      notes: _notes.text.trim(),
    );

    ref.read(itemsProvider.notifier).save(item);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(settingsProvider).distanceUnit;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit item' : 'Add maintenance item'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<ServiceType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [
                for (final t in ServiceType.values)
                  DropdownMenuItem(
                    value: t,
                    child: Row(
                      children: [
                        Icon(t.icon, size: 18),
                        const SizedBox(width: 8),
                        Text(t.label),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  final isDefaultName = _name.text.isEmpty ||
                      _name.text == _type.label;
                  _type = v;
                  if (!_isEditing && isDefaultName) {
                    _applyTypeDefaults(v, unit);
                  }
                });
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _intervalKm,
                    keyboardType: const TextInputType.numberWithOptions(),
                    decoration: InputDecoration(
                      labelText: 'Every (${unit.label})',
                      hintText: 'distance',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _intervalMonths,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Every (months)',
                      hintText: 'time',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Fill distance, time, or both. Whichever comes first triggers the reminder.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _lastOdo,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Last serviced at (${unit.label})',
                prefixIcon: const Icon(Icons.speed),
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
              leading: const Icon(Icons.event),
              title: const Text('Last serviced on'),
              subtitle: Text(formatDate(_lastDate)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _lastDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _lastDate = picked);
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(_isEditing ? 'Save changes' : 'Add item'),
            ),
          ],
        ),
      ),
    );
  }
}
