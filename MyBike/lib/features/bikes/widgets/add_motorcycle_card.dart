import 'package:flutter/material.dart';

import '../../../app/colors.dart';

class AddMotorcycleCard extends StatelessWidget {
  const AddMotorcycleCard({
    super.key,
    required this.onTap,
    this.subtitle = 'Connect another bike to track health, maintenance, and alerts.',
  });

  final VoidCallback onTap;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('add_vehicle_helper_card'),
      color: AppColors.surfacePanel.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outlineGray),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: AppColors.primaryOrange,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Add New Motorcycle",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.subtextZinc,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
