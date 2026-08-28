import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/bike.dart';
import '../data/models/enums.dart';
import '../data/models/maintenance_item.dart';
import '../providers/app_providers.dart';
import '../core/formatters.dart';

enum ReminderStatus { ok, soon, due, overdue }

/// A computed, UI-ready view of how urgent a [MaintenanceItem] is.
class ReminderInfo {
  final MaintenanceItem item;
  final Bike bike;
  final double usage; // 0..>1
  final double? remainingKm;
  final int? remainingDays;
  final ReminderStatus status;

  const ReminderInfo({
    required this.item,
    required this.bike,
    required this.usage,
    required this.remainingKm,
    required this.remainingDays,
    required this.status,
  });

  static ReminderInfo from(MaintenanceItem item, Bike bike, DateTime now) {
    final usage = item.usageFraction(bike.odometerKm, now);

    double? remainingKm;
    if (item.nextDueOdometerKm != null) {
      remainingKm = item.nextDueOdometerKm! - bike.odometerKm;
    }
    int? remainingDays;
    if (item.nextDueDate != null) {
      remainingDays = item.nextDueDate!
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;
    }

    final ReminderStatus status;
    if (usage >= 1.0) {
      status = ReminderStatus.overdue;
    } else if (usage >= 0.9) {
      status = ReminderStatus.due;
    } else if (usage >= 0.75) {
      status = ReminderStatus.soon;
    } else {
      status = ReminderStatus.ok;
    }

    return ReminderInfo(
      item: item,
      bike: bike,
      usage: usage,
      remainingKm: remainingKm,
      remainingDays: remainingDays,
      status: status,
    );
  }
}

/// All reminders across every bike, most urgent first.
final remindersProvider = Provider<List<ReminderInfo>>((ref) {
  final bikes = ref.watch(bikesProvider);
  final items = ref.watch(itemsProvider);
  final now = DateTime.now();
  final bikeMap = {for (final b in bikes) b.id: b};

  final result = <ReminderInfo>[];
  for (final item in items) {
    final bike = bikeMap[item.bikeId];
    if (bike == null) continue;
    result.add(ReminderInfo.from(item, bike, now));
  }
  result.sort((a, b) => b.usage.compareTo(a.usage));
  return result;
});

/// Reminders for a single bike, most urgent first.
final remindersForBikeProvider =
    Provider.family<List<ReminderInfo>, String>((ref, bikeId) {
  return ref
      .watch(remindersProvider)
      .where((r) => r.bike.id == bikeId)
      .toList();
});

/// Reminders that need attention (soon / due / overdue), most urgent first.
final activeRemindersProvider = Provider<List<ReminderInfo>>((ref) {
  return ref
      .watch(remindersProvider)
      .where((r) => r.status != ReminderStatus.ok)
      .toList();
});

/// Summary for the home-screen "Next Due" tile.
class EarliestNextDue {
  final String displayText;
  final bool isOverdue;

  const EarliestNextDue({
    required this.displayText,
    required this.isOverdue,
  });

  static const empty = EarliestNextDue(displayText: '—', isOverdue: false);
  static const overdue = EarliestNextDue(displayText: 'Overdue', isOverdue: true);
}

/// Finds the soonest upcoming service across all tracked components.
ReminderInfo? findEarliestDueReminder(List<ReminderInfo> reminders) {
  if (reminders.isEmpty) return null;

  final overdue = reminders.where((r) => r.status == ReminderStatus.overdue);
  if (overdue.isNotEmpty) {
    return overdue.reduce((a, b) => a.usage >= b.usage ? a : b);
  }

  ReminderInfo? bestByKm;
  double? minKm;
  ReminderInfo? bestByDays;
  int? minDays;

  for (final reminder in reminders) {
    final km = reminder.remainingKm;
    if (km != null && km >= 0 && (minKm == null || km < minKm)) {
      minKm = km;
      bestByKm = reminder;
    }

    final days = reminder.remainingDays;
    if (days != null && days >= 0 && (minDays == null || days < minDays)) {
      minDays = days;
      bestByDays = reminder;
    }
  }

  return bestByKm ?? bestByDays;
}

EarliestNextDue calculateEarliestNextDue(
  List<ReminderInfo> reminders,
  DistanceUnit unit,
) {
  if (reminders.isEmpty) return EarliestNextDue.empty;

  final earliest = findEarliestDueReminder(reminders);
  if (earliest == null) return EarliestNextDue.empty;
  if (earliest.status == ReminderStatus.overdue ||
      (earliest.remainingKm != null && earliest.remainingKm! < 0)) {
    return EarliestNextDue.overdue;
  }

  final item = earliest.item;
  final parts = <String>[];

  if (item.nextDueOdometerKm != null) {
    parts.add(formatDistance(item.nextDueOdometerKm!, unit));
  }

  if (earliest.remainingKm != null && earliest.remainingKm! > 0) {
    parts.add(formatDistance(earliest.remainingKm!, unit));
  }

  final nextDueDate = item.nextDueDate;
  if (nextDueDate != null) {
    final lastDate = DateTime(
      item.lastServiceDate.year,
      item.lastServiceDate.month,
      item.lastServiceDate.day,
    );
    final dueDate = DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);
    final intervalDays = dueDate.difference(lastDate).inDays;
    if (intervalDays > 0) {
      parts.add('$intervalDays days');
    }
  } else if (earliest.remainingDays != null && earliest.remainingDays! >= 0) {
    parts.add('${earliest.remainingDays} days');
  }

  if (parts.isEmpty) return EarliestNextDue.empty;
  return EarliestNextDue(displayText: parts.join(' • '), isOverdue: false);
}
