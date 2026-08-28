import 'package:flutter_test/flutter_test.dart';

import 'package:mybike/core/units.dart';
import 'package:mybike/data/models/bike.dart';
import 'package:mybike/data/models/enums.dart';
import 'package:mybike/data/models/maintenance_item.dart';

void main() {
  test('distance conversion round-trips between km and miles', () {
    const km = DistanceUnit.km;
    const mi = DistanceUnit.mi;
    expect(km.toKm(100), closeTo(100, 0.001));
    expect(mi.fromKm(mi.toKm(50)), closeTo(50, 0.001));
  });

  test('bike serialization round-trips', () {
    final bike = Bike(
      id: 'b1',
      name: 'Daily',
      type: BikeType.sport,
      odometerKm: 1234,
      createdAt: DateTime(2024, 1, 1),
    );
    final restored = Bike.fromMap(bike.toMap());
    expect(restored.name, 'Daily');
    expect(restored.type, BikeType.sport);
    expect(restored.odometerKm, 1234);
  });

  test('maintenance item reports overdue usage', () {
    final item = MaintenanceItem(
      id: 'i1',
      bikeId: 'b1',
      name: 'Engine Oil',
      type: ServiceType.engineOil,
      intervalKm: 3000,
      lastServiceOdometerKm: 1000,
      lastServiceDate: DateTime(2024, 1, 1),
      createdAt: DateTime(2024, 1, 1),
    );
    // 4500 - 1000 = 3500 used out of 3000 -> overdue (>1.0)
    final usage = item.usageFraction(4500, DateTime(2024, 6, 1));
    expect(usage, greaterThan(1.0));
  });
}
