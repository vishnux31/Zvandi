import 'package:hive/hive.dart';

import '../local_store.dart';
import '../models/bike.dart';
import '../models/fuel_entry.dart';
import '../models/maintenance_item.dart';
import '../models/service_record.dart';
import 'base_repository.dart';

class BikeRepository extends BaseRepository<Bike> {
  BikeRepository() : super(Hive.box<String>(Boxes.bikes));

  @override
  String idOf(Bike e) => e.id;
  @override
  Map<String, dynamic> toMap(Bike e) => e.toMap();
  @override
  Bike fromMap(Map<String, dynamic> map) => Bike.fromMap(map);
}

class MaintenanceItemRepository extends BaseRepository<MaintenanceItem> {
  MaintenanceItemRepository() : super(Hive.box<String>(Boxes.items));

  @override
  String idOf(MaintenanceItem e) => e.id;
  @override
  Map<String, dynamic> toMap(MaintenanceItem e) => e.toMap();
  @override
  MaintenanceItem fromMap(Map<String, dynamic> map) =>
      MaintenanceItem.fromMap(map);

  List<MaintenanceItem> forBike(String bikeId) =>
      getAll().where((e) => e.bikeId == bikeId).toList();
}

class ServiceRecordRepository extends BaseRepository<ServiceRecord> {
  ServiceRecordRepository() : super(Hive.box<String>(Boxes.records));

  @override
  String idOf(ServiceRecord e) => e.id;
  @override
  Map<String, dynamic> toMap(ServiceRecord e) => e.toMap();
  @override
  ServiceRecord fromMap(Map<String, dynamic> map) => ServiceRecord.fromMap(map);

  List<ServiceRecord> forBike(String bikeId) =>
      getAll().where((e) => e.bikeId == bikeId).toList();
}

class FuelRepository extends BaseRepository<FuelEntry> {
  FuelRepository() : super(Hive.box<String>(Boxes.fuel));

  @override
  String idOf(FuelEntry e) => e.id;
  @override
  Map<String, dynamic> toMap(FuelEntry e) => e.toMap();
  @override
  FuelEntry fromMap(Map<String, dynamic> map) => FuelEntry.fromMap(map);

  List<FuelEntry> forBike(String bikeId) =>
      getAll().where((e) => e.bikeId == bikeId).toList();
}
