import 'package:hive_flutter/hive_flutter.dart';

/// Names of the Hive boxes used as the local (offline-first) data store.
class Boxes {
  static const bikes = 'bikes';
  static const items = 'maintenance_items';
  static const records = 'service_records';
  static const fuel = 'fuel_entries';
  static const settings = 'settings';

  /// Cached, read-only bike brand/model reference data (mirrors Firestore).
  static const catalog = 'catalog';
}

/// Initializes Hive and opens every box the app needs.
///
/// Each box stores entities as JSON strings keyed by their id, which keeps the
/// data layer free of generated Hive adapters and trivial to mirror to a cloud
/// backend (e.g. Firestore) later.
class LocalStore {
  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<String>(Boxes.bikes),
      Hive.openBox<String>(Boxes.items),
      Hive.openBox<String>(Boxes.records),
      Hive.openBox<String>(Boxes.fuel),
      Hive.openBox(Boxes.settings),
      Hive.openBox<String>(Boxes.catalog),
    ]);
  }
}
