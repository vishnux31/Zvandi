import 'package:flutter/material.dart';

import '../services/reminder_service.dart';
import 'status_colors.dart';

/// A horizontal bar visualising how much of a service interval is used.
class WearIndicator extends StatelessWidget {
  final double usage; // 0..>1
  final ReminderStatus status;

  const WearIndicator({super.key, required this.usage, required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = statusColor(status, scheme);
    final fraction = usage.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: 8,
        backgroundColor: scheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final ReminderStatus status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = statusColor(status, scheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
