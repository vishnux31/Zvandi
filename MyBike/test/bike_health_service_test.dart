import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybike/data/models/enums.dart';
import 'package:mybike/data/models/maintenance_schedule.dart';
import 'package:mybike/services/bike_health_service.dart';

import 'bike_health_test_helpers.dart';

void main() {
  group('overallHealthPercent', () {
    test('uses weighted component groups instead of a single item average', () {
      final reminders = [
        reminder(type: ServiceType.engineOil, usage: 0.71),
      ];

      final health = overallHealthPercent(reminders);

      // Engine group is 29%, but chain/brakes/tyres default to 100%.
      // Equal weights => (29 + 100 + 100 + 100) / 4 = 82.
      expect(health, 82);
    });

    test('applies brand/model schedule weights when profile is available', () {
      final profile = BikeMaintenanceProfile(
        brand: ScheduleBrand(
          id: 'hero',
          name: 'Hero',
          origin: 'India',
          color: const Color(0xFFD62728),
          models: const [],
        ),
        model: ScheduleModelSpec(
          name: 'Splendor Plus',
          cc: 97.2,
          type: 'Commuter',
          cooling: 'Air',
          chain: true,
          notes: '',
          maintenance: [
            ScheduledMaintenanceTask(
              task: 'Engine oil change',
              interval: '3,000 km',
              category: MaintenanceCategory.oil,
              priority: MaintenancePriority.high,
            ),
            ScheduledMaintenanceTask(
              task: 'Chain lube',
              interval: '2,000 km',
              category: MaintenanceCategory.chain,
              priority: MaintenancePriority.high,
            ),
            ScheduledMaintenanceTask(
              task: 'Brake pad inspect',
              interval: '3,000 km',
              category: MaintenanceCategory.brake,
              priority: MaintenancePriority.high,
            ),
            ScheduledMaintenanceTask(
              task: 'Throttle check',
              interval: 'Every service',
              category: MaintenanceCategory.engine,
              priority: MaintenancePriority.low,
            ),
          ],
        ),
        exactModelMatch: true,
      );

      final reminders = [
        reminder(type: ServiceType.engineOil, usage: 0.71),
      ];

      final health = overallHealthPercent(reminders, profile: profile);

      // Engine weight = (3 + 1) / (3 + 3 + 3 + 1) = 0.4 => score 29
      // Chain weight = 0.3 => score 100
      // Brakes weight = 0.3 => score 100
      // Tyres weight = 0.0 => score 100
      // Overall = 29*0.4 + 100*0.3 + 100*0.3 = 71.6 => 72
      expect(health, 72);
    });

    test('returns 100 when no reminders exist', () {
      expect(overallHealthPercent(const []), 100);
    });
  });
}
