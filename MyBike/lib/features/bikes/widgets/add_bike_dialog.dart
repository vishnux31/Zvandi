import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/colors.dart';
import '../../../core/units.dart';
import '../../../data/models/bike.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/catalog_provider.dart';
import '../../../providers/maintenance_schedule_provider.dart';
import '../../../providers/settings_provider.dart';
import 'bike_catalog_pickers.dart';
import 'initial_service_setup_dialog.dart';

void showAddBikeDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => AddBikeDialog(
      onBikeCreated: (bike) {
        Navigator.of(dialogContext).pop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            showInitialServiceSetupDialog(context, bike);
          }
        });
      },
    ),
  );
}

class AddBikeDialog extends ConsumerStatefulWidget {
  final void Function(Bike bike)? onBikeCreated;

  const AddBikeDialog({super.key, this.onBikeCreated});

  @override
  ConsumerState<AddBikeDialog> createState() => _AddBikeDialogState();
}

class _AddBikeDialogState extends ConsumerState<AddBikeDialog> {
  final _nicknameCtrl = TextEditingController();
  final _odometerCtrl = TextEditingController();

  String? _brandId;
  String? _modelId;
  int? _modelYear;
  String _errorText = '';

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _odometerCtrl.dispose();
    super.dispose();
  }

  Future<void> _onAdd() async {
    final nickname = _nicknameCtrl.text.trim();
    final odometerStr = _odometerCtrl.text.trim();
    final odoValue = double.tryParse(odometerStr);

    if (nickname.isEmpty) {
      setState(() => _errorText = "Please enter a bike nickname");
      return;
    }
    if (_brandId == null) {
      setState(() => _errorText = "Please select a manufacturer");
      return;
    }
    if (_modelId == null) {
      setState(() => _errorText = "Please select a model");
      return;
    }
    if (_modelYear == null) {
      setState(() => _errorText = "Please select a model year");
      return;
    }
    if (odoValue == null || odoValue < 0) {
      setState(() => _errorText = "Please enter valid odometer reading");
      return;
    }

    final brands = ref.read(brandsProvider);
    final models = ref.read(modelsForBrandProvider(_brandId));
    final brand = brands.where((b) => b.id == _brandId).firstOrNull;
    final model = models.where((m) => m.id == _modelId).firstOrNull;
    if (brand == null || model == null) {
      setState(() => _errorText = "Invalid manufacturer or model selection");
      return;
    }

    final unit = ref.read(settingsProvider).distanceUnit;
    final odoKm = unit.toKm(odoValue);

    final bike = Bike(
      id: const Uuid().v4(),
      name: nickname,
      make: brand.name,
      model: model.name,
      brandId: brand.id,
      modelId: model.id,
      year: _modelYear,
      type: BikeType.sport,
      odometerKm: odoKm,
      createdAt: DateTime.now(),
    );

    await ref.read(bikesProvider.notifier).save(bike);
    ref.read(garageSelectedBikeIdProvider.notifier).state = bike.id;

    if (widget.onBikeCreated != null) {
      widget.onBikeCreated!(bike);
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Material(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.outlineGray),
        ),
        color: AppColors.surfacePanel,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Add Motorcycle",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nicknameCtrl,
                key: const ValueKey('add_dialog_nickname'),
                decoration: const InputDecoration(
                  labelText: 'Bike Nickname',
                  hintText: 'e.g. Red Dragon',
                ),
              ),
              const SizedBox(height: 16),
              BikeCatalogPickers(
                brandId: _brandId,
                modelId: _modelId,
                modelYear: _modelYear,
                brandKey: const ValueKey('add_dialog_make_select'),
                modelKey: const ValueKey('add_dialog_model'),
                modelYearKey: const ValueKey('add_dialog_year'),
                onBrandChanged: (value) => setState(() => _brandId = value),
                onModelChanged: (value) => setState(() => _modelId = value),
                onModelYearChanged: (value) => setState(() => _modelYear = value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _odometerCtrl,
                key: const ValueKey('add_dialog_odometer'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Odometer Reading (Km)',
                  hintText: 'e.g. 15000',
                ),
              ),
              if (_errorText.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText,
                  style: const TextStyle(color: AppColors.dangerRed),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.outlineGray),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text("Cancel", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('add_dialog_confirm_btn'),
                      onPressed: _onAdd,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        "Continue",
                        style: TextStyle(
                          color: AppColors.onPrimaryText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
