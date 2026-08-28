import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/colors.dart';
import '../../../core/formatters.dart';
import '../../../core/units.dart';
import '../../../data/models/bike.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/maintenance_schedule.dart';
import '../../../data/models/service_record.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/maintenance_schedule_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/maintenance_schedule_mapper.dart';

void showInitialServiceSetupDialog(BuildContext context, Bike bike) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => InitialServiceSetupDialog(bikeId: bike.id),
  );
}

class InitialServiceSetupDialog extends ConsumerStatefulWidget {
  final String bikeId;

  const InitialServiceSetupDialog({super.key, required this.bikeId});

  @override
  ConsumerState<InitialServiceSetupDialog> createState() =>
      _InitialServiceSetupDialogState();
}

class _InitialServiceSetupDialogState
    extends ConsumerState<InitialServiceSetupDialog> {
  final _lastServiceOdoCtrl = TextEditingController();
  DateTime _lastServiceDate = DateTime.now();
  final Map<String, bool> _selectedTasks = {};
  List<ScheduledMaintenanceTask> _displayedTasks = const [];
  String _errorText = '';
  bool _tasksInitialized = false;
  bool _odometerPrefilled = false;

  @override
  void dispose() {
    _lastServiceOdoCtrl.dispose();
    super.dispose();
  }

  Bike? get _bike => ref.read(bikeByIdProvider(widget.bikeId));

  void _prefillOdometer(DistanceUnit unit) {
    if (_odometerPrefilled) return;
    final bike = _bike;
    if (bike == null) return;
    _odometerPrefilled = true;
    _lastServiceOdoCtrl.text =
        unit.fromKm(bike.odometerKm).round().toString();
  }

  void _initTasks(List<ScheduledMaintenanceTask> tasks) {
    if (_tasksInitialized &&
        _displayedTasks.length == tasks.length &&
        _displayedTasks.every((task) => tasks.any((t) => t.task == task.task))) {
      return;
    }
    _tasksInitialized = true;
    _displayedTasks = List.of(tasks);
    for (final task in tasks) {
      _selectedTasks.putIfAbsent(task.task, () => false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastServiceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Last service date',
    );
    if (picked != null) {
      setState(() => _lastServiceDate = picked);
    }
  }

  Future<void> _save() async {
    final bike = _bike;
    if (bike == null) return;

    final unit = ref.read(settingsProvider).distanceUnit;
    final odoDisplay = parseOdometerInput(_lastServiceOdoCtrl.text);
    if (odoDisplay == null || odoDisplay < 0) {
      setState(() => _errorText = 'Enter a valid last service odometer');
      return;
    }
    final lastServiceOdometerKm = unit.toKm(odoDisplay);

    final selectedEntries = _selectedTasks.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
    if (selectedEntries.isEmpty) {
      setState(() => _errorText = 'Select at least one serviced component');
      return;
    }

    final taskByName = {for (final task in _displayedTasks) task.task: task};
    final itemsNotifier = ref.read(itemsProvider.notifier);
    final recordsNotifier = ref.read(recordsProvider.notifier);
    final existingItems = ref.read(itemsForBikeProvider(widget.bikeId));
    final checkedTypes = <ServiceType>[];

    for (final taskName in selectedEntries) {
      final task = taskByName[taskName];
      if (task == null) continue;

      checkedTypes.add(serviceTypeForTask(task));

      final existing = existingItems
          .where((item) => item.bikeId == bike.id && item.name == task.task)
          .firstOrNull;

      final item = buildMaintenanceItemFromTask(
        task: task,
        bikeId: bike.id,
        lastServiceOdometerKm: lastServiceOdometerKm,
        lastServiceDate: _lastServiceDate,
        id: existing?.id,
        createdAt: existing?.createdAt,
      );

      await itemsNotifier.save(item);
    }

    if (checkedTypes.isNotEmpty) {
      await recordsNotifier.save(
        ServiceRecord(
          id: const Uuid().v4(),
          bikeId: bike.id,
          type: checkedTypes.first,
          date: _lastServiceDate,
          odometerKm: lastServiceOdometerKm,
          notes: 'Initial setup: ${selectedEntries.join(', ')}',
          createdAt: DateTime.now(),
        ),
      );
    }

    if (lastServiceOdometerKm > bike.odometerKm) {
      await ref.read(bikesProvider.notifier).save(
            bike.copyWith(odometerKm: lastServiceOdometerKm),
          );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(settingsProvider).distanceUnit;
    final dbAsync = ref.watch(maintenanceScheduleDbProvider);
    final bike = ref.watch(bikeByIdProvider(widget.bikeId));

    if (bike == null) {
      return Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'This bike is no longer available.',
            style: TextStyle(color: AppColors.subtextZinc),
          ),
        ),
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Material(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.outlineGray),
        ),
        color: AppColors.surfacePanel,
        child: dbAsync.when(
          loading: () => const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) {
            _initTasks(fallbackSetupTasks());
            _prefillOdometer(unit);
            return _buildContent(hasManual: false, unit: unit, bike: bike);
          },
          data: (_) {
            final profile = ref.watch(bikeMaintenanceProfileProvider(bike));
            _initTasks(profile?.model.maintenance ?? fallbackSetupTasks());
            _prefillOdometer(unit);
            return _buildContent(
              hasManual: profile != null,
              unit: unit,
              bike: bike,
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent({
    required bool hasManual,
    required DistanceUnit unit,
    required Bike bike,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Last Service Details',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasManual
                ? 'Select components serviced for ${bike.name} based on the OEM manual.'
                : 'No OEM manual found. Select the components you serviced recently.',
            style: TextStyle(color: AppColors.subtextZinc, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            'Current odometer: ${formatDistance(bike.odometerKm, unit)}',
            style: TextStyle(color: AppColors.subtextZinc, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ListTile(
            key: const ValueKey('initial_service_date'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.outlineGray),
            ),
            leading: const Icon(Icons.event, color: AppColors.accentCopper),
            title: const Text('Last service date'),
            subtitle: Text(formatDate(_lastServiceDate)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('initial_service_odometer'),
            controller: _lastServiceOdoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Last service odometer (${unit.label})',
              hintText: unit == DistanceUnit.km ? 'e.g. 25000' : 'e.g. 15500',
              helperText:
                  'Countdown starts from this reading for selected components',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Components changed at last service',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ..._displayedTasks.map((task) {
            return CheckboxListTile(
              key: ValueKey('initial_service_task_${task.task}'),
              value: _selectedTasks[task.task] ?? false,
              onChanged: (checked) {
                setState(() => _selectedTasks[task.task] = checked ?? false);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                task.task,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              subtitle: Text(
                task.interval,
                style: TextStyle(color: AppColors.subtextZinc, fontSize: 12),
              ),
              secondary: Icon(
                task.category.icon,
                color: AppColors.primaryOrange,
                size: 20,
              ),
            );
          }),
          if (_errorText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _errorText,
              style: const TextStyle(color: AppColors.dangerRed),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('initial_service_skip_btn'),
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.outlineGray),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Skip', style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('initial_service_save_btn'),
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Save',
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
    );
  }
}
