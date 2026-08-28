import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/colors.dart';
import '../../core/formatters.dart';
import '../../data/models/bike.dart';
import '../../data/models/enums.dart';
import '../../providers/app_providers.dart';
import '../../providers/maintenance_schedule_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/reminder_service.dart';

// Styling colors matching Compose
const Color _darkBlack = AppColors.darkBlack;
const Color _accentCopper = AppColors.accentCopper;
const Color _onPrimaryText = AppColors.onPrimaryText;
const Color _subtextZinc = AppColors.subtextZinc;
const Color _surfaceLight = AppColors.surfaceLight;
const Color _surfacePanel = AppColors.surfacePanel;
const Color _primaryOrange = AppColors.primaryOrange;
const Color _outlineGray = AppColors.outlineGray;
const Color _dangerRed = AppColors.dangerRed;
const Color _warningAmber = AppColors.warningAmber;
const Color _safeGreen = AppColors.safeGreen;

class AlertItem {
  final String id;
  final String title;
  final String description;
  final String status; // "Critical", "Upcoming", "Completed"
  final String iconType; // "build", "visibility", "notifications", "warning"
  final String dateStr;
  final dynamic originalObject; // ReminderInfo or ServiceRecord

  AlertItem({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.iconType,
    required this.dateStr,
    required this.originalObject,
  });
}

class RemindersTab extends ConsumerStatefulWidget {
  const RemindersTab({super.key});

  @override
  ConsumerState<RemindersTab> createState() => _RemindersTabState();
}

class _RemindersTabState extends ConsumerState<RemindersTab> {
  String _selectedFilter = 'All';

  String _getIconType(ServiceType type) {
    switch (type) {
      case ServiceType.generalService:
      case ServiceType.chainSprocket:
      case ServiceType.valveClearance:
      case ServiceType.other:
        return 'build';
      case ServiceType.engineOil:
      case ServiceType.oilFilter:
      case ServiceType.airFilter:
      case ServiceType.battery:
        return 'notifications';
      case ServiceType.frontTire:
      case ServiceType.rearTire:
      case ServiceType.brakePadsFront:
      case ServiceType.brakePadsRear:
      case ServiceType.brakeFluid:
      case ServiceType.coolant:
      case ServiceType.sparkPlug:
        return 'visibility';
      default:
        return 'warning';
    }
  }

  IconData _getIconData(String iconType) {
    switch (iconType) {
      case 'build':
        return Icons.construction;
      case 'visibility':
        return Icons.visibility;
      case 'notifications':
        return Icons.notifications;
      default:
        return Icons.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeBike = ref.watch(garageSelectedBikeProvider);
    final settings = ref.watch(settingsProvider);
    final unit = settings.distanceUnit;

    final List<AlertItem> alerts = [];

    if (activeBike != null) {
      // 1. Get active reminders (soon, due, overdue)
      final reminders = ref
          .watch(remindersForBikeProvider(activeBike.id))
          .where((r) => r.status != ReminderStatus.ok)
          .toList();

      for (final r in reminders) {
        final subtitleParts = <String>[];
        if (r.remainingKm != null) {
          final km = r.remainingKm!;
          subtitleParts.add(km < 0
              ? '${formatDistance(-km, unit)} over'
              : '${formatDistance(km, unit)} left');
        }
        if (r.item.nextDueDate != null) {
          subtitleParts.add(relativeDays(r.item.nextDueDate!, DateTime.now()));
        }

        alerts.add(AlertItem(
          id: r.item.id,
          title: r.item.name,
          description: '${activeBike.name} • ${subtitleParts.join(" • ")}',
          status: r.status == ReminderStatus.overdue ? 'Critical' : 'Upcoming',
          iconType: _getIconType(r.item.type),
          dateStr: r.item.nextDueDate != null
              ? 'Due: ${formatDate(r.item.nextDueDate!)}'
              : 'Odometer Interval',
          originalObject: r,
        ));
      }

      // 2. Get service history for Completed list
      final records = ref.watch(recordsForBikeProvider(activeBike.id));
      for (final rec in records) {
        alerts.add(AlertItem(
          id: rec.id,
          title: 'Service Completed: ${rec.type.label}',
          description: '${activeBike.name} • Odometer: ${formatDistance(rec.odometerKm, unit)}'
              '${rec.cost != null ? " • Cost: ${formatCost(rec.cost!)}" : ""}'
              '${rec.notes != null && rec.notes!.isNotEmpty ? " • ${rec.notes}" : ""}',
          status: 'Completed',
          iconType: _getIconType(rec.type),
          dateStr: formatDate(rec.date),
          originalObject: rec,
        ));
      }
    }

    final filteredAlerts = alerts.where((alert) {
      if (_selectedFilter == 'All') return true;
      return alert.status == _selectedFilter;
    }).toList();

    return Scaffold(
      backgroundColor: _darkBlack,
      body: SafeArea(
        child: Column(
          children: [
            // Header List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Alerts Center',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      ElevatedButton(
                        key: const ValueKey('log_service_button_top'),
                        onPressed: activeBike != null
                            ? () => context.push('/bike/${activeBike.id}/service/new')
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentCopper,
                          disabledBackgroundColor: _accentCopper.withValues(alpha: 0.5),
                          foregroundColor: _onPrimaryText,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.construction,
                              size: 14,
                              color: _onPrimaryText,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Log Svc',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _onPrimaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'System diagnostics and pending machine checks.',
                    style: TextStyle(
                      fontSize: 14,
                      color: _subtextZinc,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Custom filtering tabs
                  Row(
                    children: ['All', 'Critical', 'Upcoming', 'Completed']
                        .map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: () => setState(() => _selectedFilter = filter),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: isSelected ? _surfaceLight : _surfacePanel,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? _primaryOrange : _outlineGray,
                                  width: 1.0,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                filter,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? _primaryOrange : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // Alerts list mapping
            Expanded(
              child: ListView.separated(
                key: const ValueKey('alerts_list_lazy_column'),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                itemCount: filteredAlerts.isEmpty ? 1 : filteredAlerts.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (filteredAlerts.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _surfacePanel,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _outlineGray, width: 1.0),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No diagnostics logs found for this system state.',
                            style: TextStyle(
                              fontSize: 14,
                              color: _subtextZinc,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  }

                  final alert = filteredAlerts[index];
                  final statusColor = alert.status == 'Critical'
                      ? _dangerRed
                      : (alert.status == 'Upcoming' ? _warningAmber : _safeGreen);

                  return Container(
                    key: ValueKey('alert_card_${alert.id}'),
                    decoration: BoxDecoration(
                      color: _surfacePanel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _outlineGray, width: 1.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: _surfaceLight,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              _getIconData(alert.iconType),
                              color: statusColor,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        alert.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        alert.status,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  alert.dateStr,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _subtextZinc,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  alert.description,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: _subtextZinc,
                                  ),
                                ),
                                if (alert.status != 'Completed') ...[
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () => _onDeleteAlert(alert, activeBike),
                                        style: TextButton.styleFrom(
                                          foregroundColor: _subtextZinc,
                                        ),
                                        child: const Text(
                                          'Dismiss',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        key: ValueKey('solve_alert_btn_${alert.id}'),
                                        onTap: () => _onSolveAlert(alert),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: statusColor.withValues(alpha: 0.4),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check,
                                                color: statusColor,
                                                size: 12,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Mark Resolved',
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onSolveAlert(AlertItem alert) {
    final originalReminder = alert.originalObject as ReminderInfo;
    context.push(
      '/bike/${originalReminder.bike.id}/service/new?itemId=${originalReminder.item.id}',
    );
  }

  void _onDeleteAlert(AlertItem alert, Bike? activeBike) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dismiss Alert?'),
        content: Text(
          'This will delete the maintenance item "${alert.title}" from ${activeBike?.name ?? 'your bike'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final originalReminder = alert.originalObject as ReminderInfo;
              await ref.read(itemsProvider.notifier).remove(originalReminder.item.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Dismissed: ${alert.title}')),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
