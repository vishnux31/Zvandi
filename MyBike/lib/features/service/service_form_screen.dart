import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../app/colors.dart';
import '../../core/formatters.dart';
import '../../core/units.dart';
import '../../data/models/enums.dart';
import '../../data/models/service_record.dart';
import '../../providers/app_providers.dart';
import '../../providers/settings_provider.dart';

class ServiceFormScreen extends ConsumerStatefulWidget {
  final String bikeId;
  final String? itemId;
  final String? recordId;
  const ServiceFormScreen({
    super.key,
    required this.bikeId,
    this.itemId,
    this.recordId,
  });

  @override
  ConsumerState<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends ConsumerState<ServiceFormScreen> {
  final _odometer = TextEditingController();
  final _provider = TextEditingController(text: 'DIY / Self');
  final _cost = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();

  // Checkboxes
  bool _oilFilterChange = false;
  bool _chainLubeAdjust = false;
  bool _tireReplacement = false;
  bool _brakePadReplacement = false;
  bool _fluidFlush = false;
  bool _generalInspection = false;

  String _errorText = '';
  ServiceRecord? _existing;
  bool _loaded = false;

  bool get _isEditing => widget.recordId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final unit = ref.read(settingsProvider).distanceUnit;
    final bike = ref.read(bikeByIdProvider(widget.bikeId));

    if (_isEditing) {
      final rec = ref
          .read(recordsProvider)
          .where((e) => e.id == widget.recordId)
          .firstOrNull;
      if (rec != null) {
        _existing = rec;
        _date = rec.date;
        _odometer.text = unit.fromKm(rec.odometerKm).round().toString();
        _cost.text = rec.cost?.toString() ?? '';
        
        final notesText = rec.notes ?? '';
        if (notesText.startsWith('Provider: ')) {
          final lines = notesText.split('\n');
          _provider.text = lines.first.replaceFirst('Provider: ', '');
          _notes.text = lines.skip(1).join('\n');
        } else {
          _notes.text = notesText;
        }

        _setCheckboxForType(rec.type);
        return;
      }
    }

    if (widget.itemId != null) {
      final item = ref
          .read(itemsProvider)
          .where((e) => e.id == widget.itemId)
          .firstOrNull;
      if (item != null) {
        _setCheckboxForType(item.type);
      }
    }

    _odometer.text = unit.fromKm(bike?.odometerKm ?? 0).round().toString();
  }

  void _setCheckboxForType(ServiceType type) {
    switch (type) {
      case ServiceType.engineOil:
      case ServiceType.oilFilter:
      case ServiceType.airFilter:
        _oilFilterChange = true;
        break;
      case ServiceType.chainLube:
      case ServiceType.chainSprocket:
        _chainLubeAdjust = true;
        break;
      case ServiceType.frontTire:
      case ServiceType.rearTire:
        _tireReplacement = true;
        break;
      case ServiceType.brakePadsFront:
      case ServiceType.brakePadsRear:
        _brakePadReplacement = true;
        break;
      case ServiceType.brakeFluid:
      case ServiceType.coolant:
        _fluidFlush = true;
        break;
      case ServiceType.generalService:
        _generalInspection = true;
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _odometer.dispose();
    _provider.dispose();
    _cost.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _resetMaintenanceItemsForType(ServiceType type, double odoKm, DateTime date) {
    final items = ref.read(itemsForBikeProvider(widget.bikeId));
    final matchingItems = items.where((item) => item.type == type);
    for (final item in matchingItems) {
      ref.read(itemsProvider.notifier).save(item.copyWith(
            lastServiceOdometerKm: odoKm,
            lastServiceDate: date,
          ));
    }
  }

  void _save() {
    final odoValue = double.tryParse(_odometer.text.trim());
    final costValue = _cost.text.trim().isEmpty ? 0.0 : double.tryParse(_cost.text.trim());

    if (odoValue == null || odoValue < 0) {
      setState(() => _errorText = "Please specify a valid odometer reading");
      return;
    }
    if (costValue == null || costValue < 0) {
      setState(() => _errorText = "Please specify a valid numeric cost");
      return;
    }

    final unit = ref.read(settingsProvider).distanceUnit;
    final odoKm = unit.toKm(odoValue);

    final fullNotes = "Provider: ${_provider.text.trim()}\n${_notes.text.trim()}";

    final checkedTypes = <ServiceType>[];
    if (_oilFilterChange) checkedTypes.add(ServiceType.engineOil);
    if (_chainLubeAdjust) checkedTypes.add(ServiceType.chainLube);
    if (_tireReplacement) checkedTypes.add(ServiceType.rearTire);
    if (_brakePadReplacement) checkedTypes.add(ServiceType.brakePadsFront);
    if (_fluidFlush) checkedTypes.add(ServiceType.brakeFluid);
    if (_generalInspection) checkedTypes.add(ServiceType.generalService);

    if (checkedTypes.isEmpty) {
      checkedTypes.add(ServiceType.other);
    }

    if (_isEditing && _existing != null) {
      final record = _existing!.copyWith(
        type: checkedTypes.first,
        date: _date,
        odometerKm: odoKm,
        cost: costValue,
        notes: fullNotes,
      );
      ref.read(recordsProvider.notifier).save(record);
      _resetMaintenanceItemsForType(checkedTypes.first, odoKm, _date);
    } else {
      for (int i = 0; i < checkedTypes.length; i++) {
        final type = checkedTypes[i];
        final record = ServiceRecord(
          id: const Uuid().v4(),
          bikeId: widget.bikeId,
          itemId: widget.itemId,
          type: type,
          date: _date,
          odometerKm: odoKm,
          cost: i == 0 ? costValue : 0.0,
          notes: fullNotes,
          createdAt: DateTime.now(),
        );
        ref.read(recordsProvider.notifier).save(record);
        _resetMaintenanceItemsForType(type, odoKm, _date);
      }
    }

    final bike = ref.read(bikeByIdProvider(widget.bikeId));
    if (bike != null && odoKm > bike.odometerKm) {
      ref.read(bikesProvider.notifier).save(bike.copyWith(odometerKm: odoKm));
    }

    context.pop();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primaryOrange,
                  onPrimary: AppColors.onPrimaryText,
                  surface: AppColors.surfacePanel,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bike = ref.watch(bikeByIdProvider(widget.bikeId));

    if (bike == null) {
      return const Scaffold(
        backgroundColor: AppColors.darkBlack,
        body: Center(
          child: Text(
            "Please register or select a motorcycle in the Garage first.",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.darkBlack,
      appBar: AppBar(
        backgroundColor: AppColors.darkBlack,
        title: Text(
          _isEditing ? "Edit Service" : "Log Service",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Log machine maintenance service record.",
              style: TextStyle(color: AppColors.subtextZinc, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            Card(
              color: AppColors.surfacePanel,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.outlineGray),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    TextFormField(
                      key: const ValueKey('service_date_input'),
                      readOnly: true,
                      onTap: _pickDate,
                      decoration: const InputDecoration(
                        labelText: 'Service Date',
                        suffixIcon: Icon(Icons.calendar_today, color: AppColors.accentCopper),
                      ),
                      controller: TextEditingController(text: formatDate(_date)),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _odometer,
                      key: const ValueKey('service_odo_input'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Odometer Reading (Km)',
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _provider,
                      key: const ValueKey('service_provider_input'),
                      decoration: const InputDecoration(
                        labelText: 'Service Provider',
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _cost,
                      key: const ValueKey('service_cost_input'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Total Cost ($kCurrencySymbol)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              "TASKS PERFORMED",
              style: TextStyle(color: AppColors.subtextZinc, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Card(
              color: AppColors.surfacePanel,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.outlineGray),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _TaskCheckboxRow(
                      label: "Oil & Filter Change",
                      checked: _oilFilterChange,
                      onChanged: (val) => setState(() => _oilFilterChange = val),
                    ),
                    _TaskCheckboxRow(
                      label: "Chain Lube & Tension Adjust",
                      checked: _chainLubeAdjust,
                      onChanged: (val) => setState(() => _chainLubeAdjust = val),
                    ),
                    _TaskCheckboxRow(
                      label: "Tire Replacement",
                      checked: _tireReplacement,
                      onChanged: (val) => setState(() => _tireReplacement = val),
                    ),
                    _TaskCheckboxRow(
                      label: "Brake Pad Replacement",
                      checked: _brakePadReplacement,
                      onChanged: (val) => setState(() => _brakePadReplacement = val),
                    ),
                    _TaskCheckboxRow(
                      label: "Fluid Flush & Bleed",
                      checked: _fluidFlush,
                      onChanged: (val) => setState(() => _fluidFlush = val),
                    ),
                    _TaskCheckboxRow(
                      label: "General Machine Inspection",
                      checked: _generalInspection,
                      onChanged: (val) => setState(() => _generalInspection = val),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              "SERVICE NOTES",
              style: TextStyle(color: AppColors.subtextZinc, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            TextFormField(
              controller: _notes,
              key: const ValueKey('service_notes_input'),
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: "Enter detail records or replacement specifications...",
              ),
            ),
            const SizedBox(height: 12),

            if (_errorText.isNotEmpty) ...[
              Text(
                _errorText,
                style: const TextStyle(color: AppColors.dangerRed),
              ),
              const SizedBox(height: 16),
            ],

            FilledButton(
              key: const ValueKey('save_service_record_btn'),
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                "Save Record",
                style: TextStyle(
                  color: AppColors.onPrimaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _TaskCheckboxRow extends StatelessWidget {
  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;

  const _TaskCheckboxRow({
    required this.label,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cleanLabel = label.replaceAll(" ", "_").toLowerCase();

    return InkWell(
      onTap: () => onChanged(!checked),
      child: Row(
        children: [
          Checkbox(
            key: ValueKey('checkbox_$cleanLabel'),
            value: checked,
            onChanged: (val) {
              if (val != null) onChanged(val);
            },
            activeColor: AppColors.primaryOrange,
            checkColor: AppColors.onPrimaryText,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
