import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/colors.dart';
import '../../data/models/maintenance_schedule.dart';
import '../../providers/maintenance_schedule_provider.dart';
import '../../services/bike_health_service.dart';

class LearnTab extends ConsumerWidget {
  const LearnTab({super.key});

  static const _emptyMessage = 'We will add the maintenance tips soon.';

  static const _components = [
    _ComponentSection(
      group: BikeComponentGroup.engine,
      title: 'Engine',
      icon: Icons.settings_outlined,
    ),
    _ComponentSection(
      group: BikeComponentGroup.chain,
      title: 'Chain',
      icon: Icons.link,
    ),
    _ComponentSection(
      group: BikeComponentGroup.brakes,
      title: 'Brakes',
      icon: Icons.radio_button_checked,
    ),
    _ComponentSection(
      group: BikeComponentGroup.tyres,
      title: 'Tyres',
      icon: Icons.trip_origin,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBike = ref.watch(garageSelectedBikeProvider);
    final profile = activeBike != null
        ? ref.watch(bikeMaintenanceProfileProvider(activeBike))
        : null;
    final scheduleTasks = profile?.model.maintenance ?? const [];
    final hasSchedule = profile != null && scheduleTasks.isNotEmpty;

    return Scaffold(
      body: ListView(
        key: const ValueKey('learn_screen_lazy_column'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const Text(
            'Maintenance Tips',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          if (activeBike != null) ...[
            Text(
              'Tips for ${activeBike.name}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              activeBike.displayTitle,
              style: TextStyle(color: AppColors.primaryOrange, fontSize: 14),
            ),
            if (profile?.model.notes.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              _ModelNotesCard(notes: profile!.model.notes),
            ],
          ] else
            Text(
              'Select a bike on Home to see model-specific maintenance tips.',
              style: TextStyle(color: AppColors.subtextZinc, fontSize: 14),
            ),
          const SizedBox(height: 16),
          Text(
            hasSchedule
                ? 'OEM guidance for your selected model, grouped by component.'
                : 'Model-specific tips will appear here once available.',
            style: TextStyle(color: AppColors.subtextZinc, fontSize: 14),
          ),
          const SizedBox(height: 16),
          for (final section in _components)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ComponentTipCard(
                key: ValueKey('learn_component_${section.group.name}'),
                section: section,
                tasks: hasSchedule
                    ? maintenanceTasksForGroup(scheduleTasks, section.group)
                    : const [],
                emptyMessage: _emptyMessage,
              ),
            ),
        ],
      ),
    );
  }
}

class _ModelNotesCard extends StatelessWidget {
  final String notes;

  const _ModelNotesCard({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.outlineGray),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: AppColors.accentCopper, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                notes,
                style: const TextStyle(color: Colors.white, height: 1.5, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComponentTipCard extends StatefulWidget {
  final _ComponentSection section;
  final List<ScheduledMaintenanceTask> tasks;
  final String emptyMessage;

  const _ComponentTipCard({
    super.key,
    required this.section,
    required this.tasks,
    required this.emptyMessage,
  });

  @override
  State<_ComponentTipCard> createState() => _ComponentTipCardState();
}

class _ComponentTipCardState extends State<_ComponentTipCard> {
  bool _readMoreExpanded = false;

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasks;
    final hasTips = tasks.isNotEmpty;

    return Card(
      color: AppColors.surfacePanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.outlineGray),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.surfaceLight,
                  radius: 18,
                  child: Icon(
                    widget.section.icon,
                    color: AppColors.accentCopper,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.section.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasTips)
              Text(
                widget.emptyMessage,
                style: TextStyle(color: AppColors.subtextZinc, fontSize: 14),
              )
            else ...[
              ...tasks
                  .take(_readMoreExpanded ? tasks.length : 3)
                  .map(_taskRow),
              if (tasks.length > 3) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => setState(() => _readMoreExpanded = !_readMoreExpanded),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          _readMoreExpanded ? 'Show less' : 'Read more',
                          style: TextStyle(
                            color: AppColors.primaryOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _readMoreExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: AppColors.primaryOrange,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _taskRow(ScheduledMaintenanceTask task) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            task.category.icon,
            size: 16,
            color: AppColors.primaryOrange,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.task,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  task.interval,
                  style: TextStyle(
                    color: AppColors.subtextZinc,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          _PriorityChip(priority: task.priority),
        ],
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final MaintenancePriority priority;

  const _PriorityChip({required this.priority});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (priority) {
      MaintenancePriority.high => ('High', AppColors.dangerRed),
      MaintenancePriority.medium => ('Med', AppColors.warningAmber),
      MaintenancePriority.low => ('Low', AppColors.subtextZinc),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ComponentSection {
  final BikeComponentGroup group;
  final String title;
  final IconData icon;

  const _ComponentSection({
    required this.group,
    required this.title,
    required this.icon,
  });
}
