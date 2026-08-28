import 'package:uuid/uuid.dart';

import '../data/models/enums.dart';
import '../data/models/maintenance_item.dart';
import '../data/models/maintenance_schedule.dart';

/// Parses user-entered odometer text (supports comma grouping).
double? parseOdometerInput(String text) {
  final cleaned = text.trim().replaceAll(',', '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

class ParsedMaintenanceInterval {
  final double? intervalKm;
  final int? intervalMonths;

  const ParsedMaintenanceInterval({this.intervalKm, this.intervalMonths});
}

/// Parses OEM interval strings like "7,500 km or 1 year".
ParsedMaintenanceInterval parseMaintenanceInterval(String interval) {
  double? intervalKm;
  int? intervalMonths;

  final kmMatches = RegExp(r'([\d,]+)\s*km', caseSensitive: false)
      .allMatches(interval);
  for (final match in kmMatches) {
    final value = double.tryParse(match.group(1)!.replaceAll(',', ''));
    if (value != null && (intervalKm == null || value < intervalKm)) {
      intervalKm = value;
    }
  }

  final yearMatch =
      RegExp(r'(\d+)\s*years?', caseSensitive: false).firstMatch(interval);
  if (yearMatch != null) {
    intervalMonths = int.parse(yearMatch.group(1)!) * 12;
  }

  final monthMatch =
      RegExp(r'(\d+)\s*months?', caseSensitive: false).firstMatch(interval);
  if (monthMatch != null) {
    intervalMonths = int.parse(monthMatch.group(1)!);
  }

  return ParsedMaintenanceInterval(
    intervalKm: intervalKm,
    intervalMonths: intervalMonths,
  );
}

ServiceType serviceTypeForTask(ScheduledMaintenanceTask task) {
  final name = task.task.toLowerCase();

  switch (task.category) {
    case MaintenanceCategory.oil:
      return ServiceType.engineOil;
    case MaintenanceCategory.filter:
      return name.contains('air') ? ServiceType.airFilter : ServiceType.oilFilter;
    case MaintenanceCategory.chain:
      return name.contains('sprocket')
          ? ServiceType.chainSprocket
          : ServiceType.chainLube;
    case MaintenanceCategory.brake:
      if (name.contains('fluid')) return ServiceType.brakeFluid;
      return name.contains('rear')
          ? ServiceType.brakePadsRear
          : ServiceType.brakePadsFront;
    case MaintenanceCategory.tyres:
      return name.contains('front') ? ServiceType.frontTire : ServiceType.rearTire;
    case MaintenanceCategory.cooling:
      return ServiceType.coolant;
    case MaintenanceCategory.ignition:
      return ServiceType.sparkPlug;
    case MaintenanceCategory.battery:
      return ServiceType.battery;
    case MaintenanceCategory.engine:
      if (name.contains('valve')) return ServiceType.valveClearance;
      return ServiceType.generalService;
    case MaintenanceCategory.suspension:
    case MaintenanceCategory.fuel:
    case MaintenanceCategory.electrical:
    case MaintenanceCategory.motor:
    case MaintenanceCategory.software:
    case MaintenanceCategory.timing:
    case MaintenanceCategory.other:
      return ServiceType.other;
  }
}

/// Builds a tracked component with intervals from the OEM task and the user's
/// last-service baseline (odometer in km, date).
MaintenanceItem buildMaintenanceItemFromTask({
  required ScheduledMaintenanceTask task,
  required String bikeId,
  required double lastServiceOdometerKm,
  required DateTime lastServiceDate,
  String? id,
  DateTime? createdAt,
}) {
  final parsed = parseMaintenanceInterval(task.interval);
  final type = serviceTypeForTask(task);
  return MaintenanceItem(
    id: id ?? const Uuid().v4(),
    bikeId: bikeId,
    name: task.task,
    type: type,
    intervalKm: parsed.intervalKm ?? type.defaultIntervalKm,
    intervalMonths: parsed.intervalMonths ?? type.defaultIntervalMonths,
    lastServiceOdometerKm: lastServiceOdometerKm,
    lastServiceDate: lastServiceDate,
    createdAt: createdAt ?? DateTime.now(),
  );
}

/// Fallback checklist when no OEM schedule is found for the bike.
List<ScheduledMaintenanceTask> fallbackSetupTasks() {
  return const [
    ScheduledMaintenanceTask(
      task: 'Engine oil change',
      interval: '3,000 km or 6 months',
      category: MaintenanceCategory.oil,
      priority: MaintenancePriority.high,
    ),
    ScheduledMaintenanceTask(
      task: 'Chain lube & adjust',
      interval: '500 km',
      category: MaintenanceCategory.chain,
      priority: MaintenancePriority.high,
    ),
    ScheduledMaintenanceTask(
      task: 'Brake pad inspect',
      interval: 'Every 3,000 km',
      category: MaintenanceCategory.brake,
      priority: MaintenancePriority.high,
    ),
    ScheduledMaintenanceTask(
      task: 'Air filter replace',
      interval: 'Every 6,000 km',
      category: MaintenanceCategory.filter,
      priority: MaintenancePriority.medium,
    ),
  ];
}
