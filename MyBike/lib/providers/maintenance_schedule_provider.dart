import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/bike.dart';
import '../data/models/maintenance_schedule.dart';
import 'app_providers.dart';

const _assetPath = 'assets/data/india_bike_maintenance.json';

final maintenanceScheduleDbProvider =
    FutureProvider<MaintenanceScheduleDatabase>((ref) async {
  final raw = await rootBundle.loadString(_assetPath);
  final map = json.decode(raw) as Map<String, dynamic>;
  return MaintenanceScheduleDatabase.fromMap(map);
});

final bikeMaintenanceProfileProvider =
    Provider.family<BikeMaintenanceProfile?, Bike>((ref, bike) {
  final db = ref.watch(maintenanceScheduleDbProvider).valueOrNull;
  if (db == null) return null;
  return resolveMaintenanceProfile(db, bike.brandId, bike.make, bike.model);
});

/// Currently selected bike on the Garage maintenance dashboard.
final garageSelectedBikeIdProvider = StateProvider<String?>((ref) => null);

final garageSelectedBikeProvider = Provider<Bike?>((ref) {
  final bikes = ref.watch(bikesProvider);
  if (bikes.isEmpty) return null;
  final selectedId = ref.watch(garageSelectedBikeIdProvider);
  if (selectedId != null) {
    final match = bikes.where((b) => b.id == selectedId);
    if (match.isNotEmpty) return match.first;
  }
  return bikes.first;
});
