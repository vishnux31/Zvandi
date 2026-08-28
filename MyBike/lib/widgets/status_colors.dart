import 'package:flutter/material.dart';

import '../services/reminder_service.dart';

Color statusColor(ReminderStatus status, ColorScheme scheme) {
  switch (status) {
    case ReminderStatus.overdue:
      return scheme.error;
    case ReminderStatus.due:
      return const Color(0xFFE6521F);
    case ReminderStatus.soon:
      return const Color(0xFFEFA800);
    case ReminderStatus.ok:
      return const Color(0xFF2E9E5B);
  }
}

String statusLabel(ReminderStatus status) {
  switch (status) {
    case ReminderStatus.overdue:
      return 'Overdue';
    case ReminderStatus.due:
      return 'Due now';
    case ReminderStatus.soon:
      return 'Due soon';
    case ReminderStatus.ok:
      return 'OK';
  }
}
