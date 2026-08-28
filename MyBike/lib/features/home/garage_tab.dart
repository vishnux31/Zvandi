import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/colors.dart';
import '../../core/formatters.dart';
import '../../providers/app_providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/maintenance_schedule_provider.dart';
import '../../services/bike_health_service.dart';
import '../../services/reminder_service.dart';
import '../bikes/widgets/add_bike_dialog.dart';
import '../bikes/widgets/add_motorcycle_card.dart';

class GarageTab extends ConsumerStatefulWidget {
  const GarageTab({super.key});

  @override
  ConsumerState<GarageTab> createState() => _GarageTabState();
}

class _GarageTabState extends ConsumerState<GarageTab> {
  String _calculateNextService(WidgetRef ref, String bikeId, int healthPercent) {
    final reminders = ref.read(remindersForBikeProvider(bikeId));
    final hasOverdue = reminders.any((r) => r.status == ReminderStatus.overdue);
    if (hasOverdue || healthPercent < 70) {
      return "Overdue";
    }

    double? minRemainingKm;
    for (final r in reminders) {
      if (r.remainingKm != null) {
        if (minRemainingKm == null || r.remainingKm! < minRemainingKm) {
          minRemainingKm = r.remainingKm;
        }
      }
    }

    final unit = ref.read(settingsProvider).distanceUnit;
    if (minRemainingKm != null && minRemainingKm > 0) {
      return formatDistance(minRemainingKm, unit);
    }

    return "850 ${unit.label}";
  }

  void _showAddDialog() => showAddBikeDialog(context);

  @override
  Widget build(BuildContext context) {
    final bikes = ref.watch(bikesProvider);
    final activeBike = ref.watch(garageSelectedBikeProvider);
    final settings = ref.watch(settingsProvider);
    final unit = settings.distanceUnit;

    // Ensure a default selection on first build.
    if (bikes.isNotEmpty && ref.read(garageSelectedBikeIdProvider) == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(garageSelectedBikeIdProvider.notifier).state = bikes.first.id;
      });
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('add_bike_fab'),
        onPressed: _showAddDialog,
        backgroundColor: AppColors.accentCopper,
        foregroundColor: AppColors.onPrimaryText,
        child: const Icon(Icons.add),
      ),
      body: ListView(
        key: const ValueKey('garage_screen_lazy_column'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              "Tap on any motorcycle to make it active.",
              style: TextStyle(color: AppColors.subtextZinc, fontSize: 14),
            ),
          ),
          ...bikes.map((bike) {
            final isActive = activeBike?.id == bike.id;
            final healthPercent = ref.watch(bikeOverallHealthProvider(bike.id));
            final nextService = _calculateNextService(ref, bike.id, healthPercent);

            final healthColor = healthPercent >= 80
                ? AppColors.safeGreen
                : (healthPercent >= 60 ? AppColors.warningAmber : AppColors.dangerRed);

            return Card(
              key: ValueKey('bike_card_${bike.id}'),
              color: isActive ? AppColors.surfaceLight : AppColors.surfacePanel,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  width: isActive ? 1.5 : 1.0,
                  color: isActive ? AppColors.primaryOrange : AppColors.outlineGray,
                ),
              ),
              child: InkWell(
                onTap: () {
                  ref.read(garageSelectedBikeIdProvider.notifier).state = bike.id;
                  context.push('/bike/${bike.id}');
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bike.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${bike.year ?? ''} ${bike.make ?? ''} ${bike.model ?? ''}",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.subtextZinc,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: healthColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: healthColor.withValues(alpha: 0.3),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  healthPercent >= 80 ? Icons.check_circle : Icons.warning,
                                  color: healthColor,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "$healthPercent% Health",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: healthColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.darkBlack,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.speed, color: AppColors.subtextZinc, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Odom",
                                        style: TextStyle(color: AppColors.subtextZinc, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatDistance(bike.odometerKm, unit),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.darkBlack,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.build, color: AppColors.subtextZinc, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Next Svc",
                                        style: TextStyle(color: AppColors.subtextZinc, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    nextService,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: nextService == "Overdue"
                                          ? AppColors.dangerRed
                                          : AppColors.primaryOrange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          AddMotorcycleCard(onTap: _showAddDialog),
        ],
      ),
    );
  }
}
