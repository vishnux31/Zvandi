import 'package:flutter_test/flutter_test.dart';
import 'package:mybike/data/models/bike.dart';
import 'package:mybike/data/models/enums.dart';
import 'package:mybike/data/models/maintenance_schedule.dart';
import 'package:mybike/services/maintenance_schedule_mapper.dart';
import 'package:mybike/services/reminder_service.dart';

void main() {
  group('parseMaintenanceInterval', () {
    test('parses km and year from combined interval', () {
      final parsed = parseMaintenanceInterval('7,500 km or 1 year');
      expect(parsed.intervalKm, 7500);
      expect(parsed.intervalMonths, 12);
    });

    test('parses months only', () {
      final parsed = parseMaintenanceInterval('Every 6 months');
      expect(parsed.intervalKm, isNull);
      expect(parsed.intervalMonths, 6);
    });

    test('uses smallest km when multiple values exist', () {
      final parsed = parseMaintenanceInterval('Every 500 km or 3,000 km');
      expect(parsed.intervalKm, 500);
    });
  });

  group('serviceTypeForTask', () {
    test('maps oil category to engine oil', () {
      const task = ScheduledMaintenanceTask(
        task: 'Engine oil + filter change',
        interval: '7,500 km',
        category: MaintenanceCategory.oil,
        priority: MaintenancePriority.high,
      );
      expect(serviceTypeForTask(task), ServiceType.engineOil);
    });

    test('maps chain sprocket task correctly', () {
      const task = ScheduledMaintenanceTask(
        task: 'Chain & sprocket replace',
        interval: '15,000 km',
        category: MaintenanceCategory.chain,
        priority: MaintenancePriority.medium,
      );
      expect(serviceTypeForTask(task), ServiceType.chainSprocket);
    });
  });

  group('parseOdometerInput', () {
    test('parses comma grouped values', () {
      expect(parseOdometerInput('12,597'), 12597);
    });
  });

  group('buildMaintenanceItemFromTask', () {
    test('uses last service baseline for remaining km', () {
      const task = ScheduledMaintenanceTask(
        task: 'Chain lube & adjust',
        interval: '500 km',
        category: MaintenanceCategory.chain,
        priority: MaintenancePriority.high,
      );

      final item = buildMaintenanceItemFromTask(
        task: task,
        bikeId: 'bike-1',
        lastServiceOdometerKm: 12597,
        lastServiceDate: DateTime(2026, 7, 2),
      );

      final bike = Bike(
        id: 'bike-1',
        name: 'Test',
        make: 'Honda',
        model: 'Dio',
        year: 2025,
        type: BikeType.scooter,
        odometerKm: 12597,
        createdAt: DateTime(2026, 1, 1),
      );

      final reminder = ReminderInfo.from(item, bike, DateTime(2026, 7, 2));
      expect(reminder.remainingKm, 500);
      expect(reminder.status, ReminderStatus.ok);
    });
  });
}
