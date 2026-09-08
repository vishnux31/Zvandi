import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/enums.dart';
import '../data/models/fuel_entry.dart';
import '../data/models/service_record.dart';
import '../services/reminder_service.dart';
import 'app_providers.dart';

/// Real (never fabricated) data feeding the Home screen's "Smart Insights",
/// "Upcoming Expenses" and "Recent Activity" sections. Every provider here
/// returns null / empty when there isn't enough logged data to support a
/// number, rather than inventing one.

/// This-month vs last-month fuel economy, derived from consecutive fuel-up
/// odometer deltas. Null unless both calendar months have at least one
/// completed distance segment.
class FuelEconomyTrend {
  final double currentKmPerL;
  final double deltaPercent; // positive = improving vs. last month

  const FuelEconomyTrend({
    required this.currentKmPerL,
    required this.deltaPercent,
  });
}

FuelEconomyTrend? _fuelEconomyTrend(List<FuelEntry> entries, DateTime now) {
  if (entries.length < 2) return null;
  final sorted = List<FuelEntry>.from(entries)
    ..sort((a, b) => a.odometerKm.compareTo(b.odometerKm));

  final thisMonthKey = DateTime(now.year, now.month);
  final lastMonthKey = DateTime(now.year, now.month - 1);

  final thisMonthSamples = <double>[];
  final lastMonthSamples = <double>[];

  for (var i = 1; i < sorted.length; i++) {
    final prev = sorted[i - 1];
    final cur = sorted[i];
    final deltaKm = cur.odometerKm - prev.odometerKm;
    if (deltaKm <= 0 || cur.liters <= 0) continue;

    final key = DateTime(cur.date.year, cur.date.month);
    final economy = deltaKm / cur.liters;
    if (key == thisMonthKey) {
      thisMonthSamples.add(economy);
    } else if (key == lastMonthKey) {
      lastMonthSamples.add(economy);
    }
  }

  if (thisMonthSamples.isEmpty || lastMonthSamples.isEmpty) return null;

  double avg(List<double> v) => v.reduce((a, b) => a + b) / v.length;
  final currentAvg = avg(thisMonthSamples);
  final previousAvg = avg(lastMonthSamples);
  if (previousAvg <= 0) return null;

  return FuelEconomyTrend(
    currentKmPerL: currentAvg,
    deltaPercent: ((currentAvg - previousAvg) / previousAvg) * 100,
  );
}

final fuelEconomyTrendProvider =
    Provider.family<FuelEconomyTrend?, String>((ref, bikeId) {
  final entries = ref.watch(fuelForBikeProvider(bikeId));
  return _fuelEconomyTrend(entries, DateTime.now());
});

/// One due-soon item for the "Upcoming Expenses" card, with an estimated
/// cost sourced from real service history (median cost for that service
/// type — this bike's own history first, falling back to all bikes).
/// [estimatedCost] is null when there's no cost history to estimate from.
class UpcomingExpenseItem {
  final String itemName;
  final ServiceType type;
  final double? estimatedCost;

  const UpcomingExpenseItem({
    required this.itemName,
    required this.type,
    required this.estimatedCost,
  });
}

double? _medianCost(Iterable<double> costs) {
  final sorted = costs.toList()..sort();
  if (sorted.isEmpty) return null;
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

/// Up to 3 soonest-due maintenance items for this bike, most urgent first.
final upcomingExpensesProvider =
    Provider.family<List<UpcomingExpenseItem>, String>((ref, bikeId) {
  final dueSoon = ref
      .watch(remindersForBikeProvider(bikeId))
      .where((r) => r.status != ReminderStatus.ok)
      .toList()
    ..sort((a, b) => b.usage.compareTo(a.usage));

  final bikeRecords = ref.watch(recordsForBikeProvider(bikeId));
  final allRecords = ref.watch(recordsProvider);

  double? estimateFor(ServiceType type) {
    final bikeCosts = bikeRecords
        .where((r) => r.type == type && r.cost != null)
        .map((r) => r.cost!);
    final fromThisBike = _medianCost(bikeCosts);
    if (fromThisBike != null) return fromThisBike;

    final allCosts = allRecords
        .where((r) => r.type == type && r.cost != null)
        .map((r) => r.cost!);
    return _medianCost(allCosts);
  }

  return dueSoon
      .take(3)
      .map((r) => UpcomingExpenseItem(
            itemName: r.item.name,
            type: r.item.type,
            estimatedCost: estimateFor(r.item.type),
          ))
      .toList();
});

/// A single row in the "Recent Activity" timeline — either a logged service
/// or a fuel-up, merged and sorted by date. There is no trip-tracking or
/// diagnostic-scan data in this app, so those categories aren't included.
sealed class ActivityEntry {
  final DateTime date;
  const ActivityEntry(this.date);
}

class ServiceActivity extends ActivityEntry {
  final ServiceRecord record;
  ServiceActivity(this.record) : super(record.date);
}

class FuelActivity extends ActivityEntry {
  final FuelEntry entry;
  FuelActivity(this.entry) : super(entry.date);
}

/// The most recent handful of real events (service + fuel) for this bike.
final recentActivityProvider =
    Provider.family<List<ActivityEntry>, String>((ref, bikeId) {
  final records = ref.watch(recordsForBikeProvider(bikeId));
  final fuel = ref.watch(fuelForBikeProvider(bikeId));
  final combined = <ActivityEntry>[
    ...records.map(ServiceActivity.new),
    ...fuel.map(FuelActivity.new),
  ]..sort((a, b) => b.date.compareTo(a.date));
  return combined.take(5).toList();
});
