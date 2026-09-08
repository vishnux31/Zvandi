import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_store.dart';
import '../data/models/bike.dart';
import '../data/models/fuel_entry.dart';
import '../data/models/maintenance_item.dart';
import '../data/models/service_record.dart';
import '../data/repositories/repositories.dart';
import '../services/cloud_sync_service.dart';

/// Which bottom-nav tab is active on [HomeScreen]. Exposed as a provider
/// (rather than local widget state) so external entry points — the
/// reminders bell, a push-notification tap, a future deep link — can
/// select a tab without routing through the widget tree.
final homeTabIndexProvider = StateProvider<int>((ref) => 0);

final bikeRepositoryProvider = Provider((ref) => BikeRepository());
final itemRepositoryProvider = Provider((ref) => MaintenanceItemRepository());
final recordRepositoryProvider = Provider((ref) => ServiceRecordRepository());
final fuelRepositoryProvider = Provider((ref) => FuelRepository());

class BikesNotifier extends StateNotifier<List<Bike>> {
  BikesNotifier(this._ref, this._repo) : super(_repo.getAll());
  final Ref _ref;
  final BikeRepository _repo;

  void reload() => state = _repo.getAll();

  Future<void> save(Bike bike) async {
    await _repo.put(bike);
    state = _repo.getAll();
    await _ref.read(cloudSyncProvider).push(Boxes.bikes, bike.id, bike.toMap());
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    state = _repo.getAll();
    await _ref.read(cloudSyncProvider).remove(Boxes.bikes, id);
  }
}

final bikesProvider = StateNotifierProvider<BikesNotifier, List<Bike>>((ref) {
  return BikesNotifier(ref, ref.watch(bikeRepositoryProvider));
});

final bikeByIdProvider = Provider.family<Bike?, String>((ref, id) {
  return ref.watch(bikesProvider).where((b) => b.id == id).firstOrNull;
});

class ItemsNotifier extends StateNotifier<List<MaintenanceItem>> {
  ItemsNotifier(this._ref, this._repo) : super(_repo.getAll());
  final Ref _ref;
  final MaintenanceItemRepository _repo;

  void reload() => state = _repo.getAll();

  Future<void> save(MaintenanceItem item) async {
    await _repo.put(item);
    state = _repo.getAll();
    await _ref
        .read(cloudSyncProvider)
        .push(Boxes.items, item.id, item.toMap());
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    state = _repo.getAll();
    await _ref.read(cloudSyncProvider).remove(Boxes.items, id);
  }

  Future<void> removeForBike(String bikeId) async {
    final ids = _repo.forBike(bikeId).map((e) => e.id).toList();
    await _repo.deleteWhere((e) => e.bikeId == bikeId);
    state = _repo.getAll();
    final sync = _ref.read(cloudSyncProvider);
    for (final id in ids) {
      await sync.remove(Boxes.items, id);
    }
  }
}

final itemsProvider =
    StateNotifierProvider<ItemsNotifier, List<MaintenanceItem>>((ref) {
  return ItemsNotifier(ref, ref.watch(itemRepositoryProvider));
});

final itemsForBikeProvider =
    Provider.family<List<MaintenanceItem>, String>((ref, bikeId) {
  return ref.watch(itemsProvider).where((e) => e.bikeId == bikeId).toList();
});

class RecordsNotifier extends StateNotifier<List<ServiceRecord>> {
  RecordsNotifier(this._ref, this._repo) : super(_repo.getAll());
  final Ref _ref;
  final ServiceRecordRepository _repo;

  void reload() => state = _repo.getAll();

  Future<void> save(ServiceRecord record) async {
    await _repo.put(record);
    state = _repo.getAll();
    await _ref
        .read(cloudSyncProvider)
        .push(Boxes.records, record.id, record.toMap());
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    state = _repo.getAll();
    await _ref.read(cloudSyncProvider).remove(Boxes.records, id);
  }

  Future<void> removeForBike(String bikeId) async {
    final ids = _repo.forBike(bikeId).map((e) => e.id).toList();
    await _repo.deleteWhere((e) => e.bikeId == bikeId);
    state = _repo.getAll();
    final sync = _ref.read(cloudSyncProvider);
    for (final id in ids) {
      await sync.remove(Boxes.records, id);
    }
  }
}

final recordsProvider =
    StateNotifierProvider<RecordsNotifier, List<ServiceRecord>>((ref) {
  return RecordsNotifier(ref, ref.watch(recordRepositoryProvider));
});

final recordsForBikeProvider =
    Provider.family<List<ServiceRecord>, String>((ref, bikeId) {
  final list =
      ref.watch(recordsProvider).where((e) => e.bikeId == bikeId).toList();
  list.sort((a, b) => b.date.compareTo(a.date));
  return list;
});

class FuelNotifier extends StateNotifier<List<FuelEntry>> {
  FuelNotifier(this._ref, this._repo) : super(_repo.getAll());
  final Ref _ref;
  final FuelRepository _repo;

  void reload() => state = _repo.getAll();

  Future<void> save(FuelEntry entry) async {
    await _repo.put(entry);
    state = _repo.getAll();
    await _ref.read(cloudSyncProvider).push(Boxes.fuel, entry.id, entry.toMap());
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    state = _repo.getAll();
    await _ref.read(cloudSyncProvider).remove(Boxes.fuel, id);
  }

  Future<void> removeForBike(String bikeId) async {
    final ids = _repo.forBike(bikeId).map((e) => e.id).toList();
    await _repo.deleteWhere((e) => e.bikeId == bikeId);
    state = _repo.getAll();
    final sync = _ref.read(cloudSyncProvider);
    for (final id in ids) {
      await sync.remove(Boxes.fuel, id);
    }
  }
}

final fuelProvider =
    StateNotifierProvider<FuelNotifier, List<FuelEntry>>((ref) {
  return FuelNotifier(ref, ref.watch(fuelRepositoryProvider));
});

final fuelForBikeProvider =
    Provider.family<List<FuelEntry>, String>((ref, bikeId) {
  final list = ref.watch(fuelProvider).where((e) => e.bikeId == bikeId).toList();
  list.sort((a, b) => b.odometerKm.compareTo(a.odometerKm));
  return list;
});
