import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybike/data/models/enums.dart';
import 'package:mybike/data/models/maintenance_schedule.dart';
import 'package:mybike/services/bike_health_service.dart';

import 'bike_health_test_helpers.dart';

void main() {
  group('overallHealthPercent', () {
    test(
        'only averages across tracked groups so untracked ones do not inflate '
        'the score to a fake 100%', () {
      final reminders = [
        reminder(type: ServiceType.engineOil, usage: 0.71),
      ];

      final health = overallHealthPercent(reminders);

      // Only the engine group has data. Untracked chain/brakes/tyres are
      // excluded entirely rather than contributing a bogus 100%.
      expect(health, 29);
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

      // Only the engine group is tracked here; chain/brakes/tyres groups
      // have no items and are intentionally excluded from the roll-up so
      // we don't invent "100% healthy" numbers for things we never
      // measured.
      expect(health, 29);
    });

    test('returns null when nothing has been tracked yet', () {
      expect(overallHealthPercent(const []), isNull);
    });
  });
}
