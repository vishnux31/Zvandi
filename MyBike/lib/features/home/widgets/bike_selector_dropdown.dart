import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/colors.dart';
import '../../../data/models/bike.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/maintenance_schedule_provider.dart';

class BikeSelectorDropdown extends ConsumerWidget {
  const BikeSelectorDropdown({super.key});

  String _bikeSubtitle(Bike bike) {
    return '${bike.year ?? ''} ${bike.make ?? ''} ${bike.model ?? ''}'.trim();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bikes = ref.watch(bikesProvider);
    if (bikes.isEmpty) return const SizedBox.shrink();

    final activeBike = ref.watch(garageSelectedBikeProvider);

    return PopupMenuButton<String>(
      key: const ValueKey('bike_selector_dropdown'),
      tooltip: 'Change bike',
      offset: const Offset(0, 48),
      color: AppColors.surfacePanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.outlineGray),
      ),
      onSelected: (bikeId) {
        ref.read(garageSelectedBikeIdProvider.notifier).state = bikeId;
      },
      itemBuilder: (context) {
        return bikes.map((bike) {
          final isActive = activeBike?.id == bike.id;
          final subtitle = _bikeSubtitle(bike);

          return PopupMenuItem<String>(
            value: bike.id,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        bike.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isActive ? AppColors.primaryOrange : Colors.white,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.subtextZinc,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isActive)
                  const Icon(
                    Icons.check,
                    color: AppColors.primaryOrange,
                    size: 18,
                  ),
              ],
            ),
          );
        }).toList();
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.two_wheeler,
              color: Colors.white,
              size: 22,
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: AppColors.subtextZinc,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}
