import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/enums.dart';
import '../data/models/maintenance_schedule.dart';
import '../providers/app_providers.dart';
import '../providers/maintenance_schedule_provider.dart';
import 'reminder_service.dart';

/// The four dashboard component groups shown on the home screen.
enum BikeComponentGroup {
  engine,
  chain,
  brakes,
  tyres,
}

/// Maintenance item types tracked under each component group.
const componentGroupServiceTypes = {
  BikeComponentGroup.engine: [
    ServiceType.engineOil,
    ServiceType.oilFilter,
    ServiceType.airFilter,
    ServiceType.coolant,
    ServiceType.sparkPlug,
    ServiceType.valveClearance,
    ServiceType.battery,
    ServiceType.generalService,
    ServiceType.other,
  ],
  BikeComponentGroup.chain: [
    ServiceType.chainLube,
    ServiceType.chainSprocket,
  ],
  BikeComponentGroup.brakes: [
    ServiceType.brakePadsFront,
    ServiceType.brakePadsRear,
    ServiceType.brakeFluid,
  ],
  BikeComponentGroup.tyres: [
    ServiceType.frontTire,
    ServiceType.rearTire,
  ],
};

double _priorityWeight(MaintenancePriority priority) => switch (priority) {
      MaintenancePriority.high => 3.0,
      MaintenancePriority.medium => 2.0,
      MaintenancePriority.low => 1.0,
    };

BikeComponentGroup componentGroupForCategory(MaintenanceCategory category) =>
    switch (category) {
      MaintenanceCategory.chain => BikeComponentGroup.chain,
      MaintenanceCategory.brake => BikeComponentGroup.brakes,
      MaintenanceCategory.tyres => BikeComponentGroup.tyres,
      _ => BikeComponentGroup.engine,
    };

/// OEM maintenance tasks for a dashboard component group.
List<ScheduledMaintenanceTask> maintenanceTasksForGroup(
  List<ScheduledMaintenanceTask> tasks,
  BikeComponentGroup group,
) {
  return tasks
      .where((task) => componentGroupForCategory(task.category) == group)
      .toList();
}

/// Equal weights when no brand/model schedule is available.
Map<BikeComponentGroup, double> defaultComponentWeights() => {
      for (final group in BikeComponentGroup.values) group: 0.25,
    };

/// Derives component weight fractions from the OEM schedule for this bike's
/// brand and model. Higher-priority tasks contribute more to their group.
Map<BikeComponentGroup, double> componentWeightsFromProfile(
  BikeMaintenanceProfile profile,
) {
  final raw = {
    for (final group in BikeComponentGroup.values) group: 0.0,
  };

  for (final task in profile.model.maintenance) {
    final group = componentGroupForCategory(task.category);
    raw[group] = raw[group]! + _priorityWeight(task.priority);
  }

  final total = raw.values.fold(0.0, (sum, value) => sum + value);
  if (total <= 0) return defaultComponentWeights();

  return {
    for (final entry in raw.entries) entry.key: entry.value / total,
  };
}

/// Score for one component group (0–100), or `null` when the user has not
/// tracked any item in that group yet — in which case we must not show "100%
/// Healthy" because we have no data to back that claim.
int? componentGroupScore(
  List<ReminderInfo> reminders,
  BikeComponentGroup group,
) {
  final types = componentGroupServiceTypes[group]!;
  final matches =
      reminders.where((r) => types.contains(r.item.type)).toList();
  if (matches.isEmpty) return null;

  var maxWear = 0.0;
  for (final reminder in matches) {
    if (reminder.usage > maxWear) maxWear = reminder.usage;
  }
  return (100 - (maxWear * 100).clamp(0, 100)).round();
}

/// Overall bike health as a weighted average of the tracked component
/// groups. Groups with no tracked items are excluded entirely so the
/// headline figure reflects only measured data; returns `null` when the
/// rider hasn't tracked anything yet.
int? overallHealthPercent(
  List<ReminderInfo> reminders, {
  BikeMaintenanceProfile? profile,
}) {
  if (reminders.isEmpty) return null;

  final weights = profile != null
      ? componentWeightsFromProfile(profile)
      : defaultComponentWeights();

  var weightedSum = 0.0;
  var totalWeight = 0.0;

  for (final group in BikeComponentGroup.values) {
    final score = componentGroupScore(reminders, group);
    if (score == null) continue;
    final weight = weights[group] ?? 0.25;
    weightedSum += score * weight;
    totalWeight += weight;
  }

  if (totalWeight <= 0) return null;
  return (weightedSum / totalWeight).round();
}

final bikeOverallHealthProvider = Provider.family<int?, String>((ref, bikeId) {
  final bike = ref.watch(bikeByIdProvider(bikeId));
  final reminders = ref.watch(remindersForBikeProvider(bikeId));
  final profile = bike != null
      ? ref.watch(bikeMaintenanceProfileProvider(bike))
      : null;
  return overallHealthPercent(reminders, profile: profile);
});

final bikeComponentScoresProvider =
    Provider.family<Map<BikeComponentGroup, int?>, String>((ref, bikeId) {
  final reminders = ref.watch(remindersForBikeProvider(bikeId));
  return {
    for (final group in BikeComponentGroup.values)
      group: componentGroupScore(reminders, group),
  };
});
