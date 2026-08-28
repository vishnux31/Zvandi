import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/colors.dart';
import '../../../data/models/catalog.dart';
import '../../../providers/catalog_provider.dart';

List<int> modelYearOptions() {
  final currentYear = DateTime.now().year;
  return [for (var y = currentYear; y >= 1980; y--) y];
}

/// Manufacturer, model, and model year fields backed by the Firebase catalog.
/// Uses the same [DropdownMenu] pattern as [BikeFormScreen].
class BikeCatalogPickers extends ConsumerStatefulWidget {
  const BikeCatalogPickers({
    super.key,
    required this.brandId,
    required this.modelId,
    required this.modelYear,
    required this.onBrandChanged,
    required this.onModelChanged,
    required this.onModelYearChanged,
    this.brandKey = const ValueKey('bike_catalog_brand'),
    this.modelKey = const ValueKey('bike_catalog_model'),
    this.modelYearKey = const ValueKey('bike_catalog_model_year'),
  });

  final String? brandId;
  final String? modelId;
  final int? modelYear;
  final ValueChanged<String?> onBrandChanged;
  final ValueChanged<String?> onModelChanged;
  final ValueChanged<int?> onModelYearChanged;
  final Key brandKey;
  final Key modelKey;
  final Key modelYearKey;

  @override
  ConsumerState<BikeCatalogPickers> createState() => _BikeCatalogPickersState();
}

class _BikeCatalogPickersState extends ConsumerState<BikeCatalogPickers> {
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  bool _labelsSynced = false;

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  void _syncLabels(List<Brand> brands, List<BikeModel> models) {
    if (_labelsSynced || brands.isEmpty) return;

    if (widget.brandId != null) {
      final brand = brands.where((b) => b.id == widget.brandId).firstOrNull;
      if (brand != null) _brandCtrl.text = brand.name;
    }
    if (widget.modelId != null) {
      final model = models.where((m) => m.id == widget.modelId).firstOrNull;
      if (model != null) _modelCtrl.text = model.name;
    }
    _labelsSynced = true;
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(catalogProvider);

    return catalogAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Text(
        'Could not load manufacturers. Check your connection.',
        style: TextStyle(color: AppColors.dangerRed),
      ),
      data: (_) {
        final brands = ref.watch(brandsProvider);
        final models = ref.watch(modelsForBrandProvider(widget.brandId));
        final years = modelYearOptions();
        _syncLabels(brands, models);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownMenu<Brand>(
              key: widget.brandKey,
              controller: _brandCtrl,
              enableFilter: true,
              requestFocusOnTap: true,
              expandedInsets: EdgeInsets.zero,
              label: const Text('Manufacturer'),
              leadingIcon: const Icon(Icons.factory_outlined),
              hintText: 'Select or type a manufacturer',
              menuHeight: 320,
              initialSelection:
                  brands.where((b) => b.id == widget.brandId).firstOrNull,
              dropdownMenuEntries: [
                for (final brand in brands)
                  DropdownMenuEntry(value: brand, label: brand.name),
              ],
              onSelected: (brand) {
                widget.onBrandChanged(brand?.id);
                widget.onModelChanged(null);
                _modelCtrl.clear();
                if (brand != null) _brandCtrl.text = brand.name;
              },
            ),
            const SizedBox(height: 16),
            DropdownMenu<BikeModel>(
              key: widget.modelKey,
              controller: _modelCtrl,
              enabled: widget.brandId != null,
              enableFilter: true,
              requestFocusOnTap: true,
              expandedInsets: EdgeInsets.zero,
              label: const Text('Model'),
              leadingIcon: const Icon(Icons.motorcycle_outlined),
              hintText: widget.brandId == null
                  ? 'Choose a manufacturer first'
                  : 'Select or type a model',
              menuHeight: 320,
              initialSelection:
                  models.where((m) => m.id == widget.modelId).firstOrNull,
              dropdownMenuEntries: [
                for (final model in models)
                  DropdownMenuEntry(value: model, label: model.name),
              ],
              onSelected: (model) {
                widget.onModelChanged(model?.id);
                if (model != null) _modelCtrl.text = model.name;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: widget.modelYearKey,
              value: widget.modelYear,
              isExpanded: true,
              dropdownColor: AppColors.surfaceLight,
              decoration: const InputDecoration(
                labelText: 'Model Year',
                prefixIcon: Icon(Icons.event_outlined),
              ),
              hint: const Text('Select model year'),
              items: [
                for (final year in years)
                  DropdownMenuItem(
                    value: year,
                    child: Text(
                      '$year',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
              ],
              onChanged: widget.onModelYearChanged,
            ),
          ],
        );
      },
    );
  }
}
