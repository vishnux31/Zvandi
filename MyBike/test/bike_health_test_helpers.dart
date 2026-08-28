import 'package:mybike/data/models/bike.dart';
import 'package:mybike/data/models/enums.dart';
import 'package:mybike/data/models/maintenance_item.dart';
import 'package:mybike/services/reminder_service.dart';

ReminderInfo reminder({
  required ServiceType type,
  required double usage,
}) {
  final bike = Bike(
    id: 'bike-1',
    name: 'Test Bike',
    createdAt: DateTime(2024),
  );
  final item = MaintenanceItem(
    id: 'item-${type.name}',
    bikeId: bike.id,
    name: type.label,
    type: type,
    createdAt: DateTime(2024),
  );

  ReminderStatus status;
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
    remainingKm: null,
    remainingDays: null,
    status: status,
  );
}
