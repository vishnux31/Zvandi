import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/input_formatters.dart';
import '../../core/units.dart';
import '../../data/models/bike.dart';
import '../../data/models/catalog.dart';
import '../../data/models/enums.dart';
import '../../providers/app_providers.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/settings_provider.dart';

class BikeFormScreen extends ConsumerStatefulWidget {
  final String? bikeId;
  const BikeFormScreen({super.key, this.bikeId});

  @override
  ConsumerState<BikeFormScreen> createState() => _BikeFormScreenState();
}

class _BikeFormScreenState extends ConsumerState<BikeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _registration = TextEditingController();
  final _odometer = TextEditingController();

  String? _brandId;
  String? _modelId;
  int? _modelYear;
  int? _purchaseYear;
  BikeType _type = BikeType.commuter;

  Bike? _existing;
  bool _loaded = false;
  bool _catalogResolved = false;

  bool get _isEditing => widget.bikeId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    if (_isEditing) {
      final bike = ref.read(bikeByIdProvider(widget.bikeId!));
      if (bike != null) {
        _existing = bike;
        final unit = ref.read(settingsProvider).distanceUnit;
        _name.text = bike.name;
        _brandCtrl.text = bike.make ?? '';
        _modelCtrl.text = bike.model ?? '';
        _brandId = bike.brandId;
        _modelId = bike.modelId;
        _modelYear = bike.year;
        _purchaseYear = bike.yearOfPurchase;
        _registration.text = bike.registration ?? '';
        final odo = unit.fromKm(bike.odometerKm).round();
        _odometer.text = odo > 0 ? formatIndianInt(odo) : '';
        _type = bike.type;
      }
    }
  }

  /// For bikes saved before the catalog existed, resolve the brand id from the
  /// stored make so the model dropdown can populate. Runs once after the
  /// catalog has loaded.
  void _resolveBrandFromName(List<Brand> brands) {
    if (_catalogResolved || brands.isEmpty) return;
    _catalogResolved = true;
    if (_brandId == null && _brandCtrl.text.trim().isNotEmpty) {
      final match = brands.where(
        (b) => b.name.toLowerCase() == _brandCtrl.text.trim().toLowerCase(),
      );
      if (match.isNotEmpty) _brandId = match.first.id;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _registration.dispose();
    _odometer.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final unit = ref.read(settingsProvider).distanceUnit;
    final odoValue = parseGroupedInt(_odometer.text).toDouble();
    final odoKm = unit.toKm(odoValue);

    final bike = (_existing ??
            Bike(
              id: const Uuid().v4(),
              name: '',
              createdAt: DateTime.now(),
            ))
        .copyWith(
      name: _name.text.trim(),
      make: _brandCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      brandId: _brandId,
      modelId: _modelId,
      year: _modelYear,
      yearOfPurchase: _purchaseYear,
      registration: _registration.text.trim(),
      type: _type,
      odometerKm: odoKm,
    );

    ref.read(bikesProvider.notifier).save(bike);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(settingsProvider).distanceUnit;
    final brands = ref.watch(brandsProvider);
    _resolveBrandFromName(brands);
    final models = ref.watch(modelsForBrandProvider(_brandId));
    final currentYear = DateTime.now().year;
    final years = [for (var y = currentYear; y >= 1980; y--) y];

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit bike' : 'Add bike')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nickname *',
                hintText: 'e.g. Daily rider',
                prefixIcon: Icon(Icons.two_wheeler),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            DropdownMenu<Brand>(
              controller: _brandCtrl,
              enableFilter: true,
              requestFocusOnTap: true,
              expandedInsets: EdgeInsets.zero,
              label: const Text('Make'),
              leadingIcon: const Icon(Icons.factory_outlined),
              hintText: 'Select or type a brand',
              menuHeight: 320,
              initialSelection:
                  brands.where((b) => b.id == _brandId).firstOrNull,
              dropdownMenuEntries: [
                for (final b in brands)
                  DropdownMenuEntry(value: b, label: b.name),
              ],
              onSelected: (brand) {
                setState(() {
                  _brandId = brand?.id;
                  // Reset the model whenever the brand changes.
                  _modelId = null;
                  _modelCtrl.clear();
                });
              },
            ),
            const SizedBox(height: 14),
            DropdownMenu<BikeModel>(
              controller: _modelCtrl,
              enabled: _brandId != null,
              enableFilter: true,
              requestFocusOnTap: true,
              expandedInsets: EdgeInsets.zero,
              label: const Text('Model'),
              leadingIcon: const Icon(Icons.motorcycle_outlined),
              hintText: _brandId == null
                  ? 'Choose a brand first'
                  : 'Select or type a model',
              menuHeight: 320,
              initialSelection:
                  models.where((m) => m.id == _modelId).firstOrNull,
              dropdownMenuEntries: [
                for (final m in models)
                  DropdownMenuEntry(value: m, label: m.name),
              ],
              onSelected: (model) {
                setState(() => _modelId = model?.id);
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _modelYear,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                    items: [
                      for (final y in years)
                        DropdownMenuItem(value: y, child: Text('$y')),
                    ],
                    onChanged: (v) => setState(() => _modelYear = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _purchaseYear,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Year of purchase',
                      prefixIcon: Icon(Icons.shopping_bag_outlined),
                    ),
                    items: [
                      for (final y in years)
                        DropdownMenuItem(value: y, child: Text('$y')),
                    ],
                    validator: (v) {
                      if (v != null &&
                          _modelYear != null &&
                          v < _modelYear!) {
                        return 'Before model year';
                      }
                      return null;
                    },
                    onChanged: (v) => setState(() => _purchaseYear = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<BikeType>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Type',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: [
                for (final t in BikeType.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (v) => setState(() => _type = v ?? BikeType.commuter),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _registration,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Reg. number',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _odometer,
              keyboardType: TextInputType.number,
              inputFormatters: [IndianDigitsInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Current odometer (${unit.label})',
                prefixIcon: const Icon(Icons.speed),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(_isEditing ? 'Save changes' : 'Add bike'),
            ),
          ],
        ),
      ),
    );
  }
}
