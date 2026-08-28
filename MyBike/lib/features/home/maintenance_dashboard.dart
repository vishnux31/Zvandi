import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../data/models/bike.dart';
import '../../data/models/maintenance_schedule.dart';
import '../../providers/maintenance_schedule_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/reminder_service.dart';

class MaintenanceDashboard extends ConsumerStatefulWidget {
  final Bike bike;
  const MaintenanceDashboard({super.key, required this.bike});

  @override
  ConsumerState<MaintenanceDashboard> createState() =>
      _MaintenanceDashboardState();
}

class _MaintenanceDashboardState extends ConsumerState<MaintenanceDashboard> {
  String _search = '';
  MaintenanceCategory? _filterCategory;

  @override
  Widget build(BuildContext context) {
    final dbAsync = ref.watch(maintenanceScheduleDbProvider);
    final profile = ref.watch(bikeMaintenanceProfileProvider(widget.bike));
    final settings = ref.watch(settingsProvider);
    final reminders = ref.watch(remindersForBikeProvider(widget.bike.id));
    final overdue = reminders.where((r) => r.status != ReminderStatus.ok).length;

    return dbAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _NoScheduleCard(
        bike: widget.bike,
        message: 'Could not load maintenance data.',
      ),
      data: (db) {
        if (profile == null) {
          return _NoScheduleCard(
            bike: widget.bike,
            message:
                'No official schedule found for ${widget.bike.make ?? 'this brand'} '
                '${widget.bike.model ?? ''}. Add maintenance items manually from the bike detail screen.',
          );
        }

        final brandColor = profile.accentColor;
        final tasks = _filteredTasks(profile.model.maintenance);
        final categories = profile.model.maintenance
            .map((t) => t.category)
            .toSet()
            .toList()
          ..sort((a, b) => a.label.compareTo(b.label));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            if (overdue > 0) _OverdueBanner(count: overdue),
            _BikeHeaderCard(
              bike: widget.bike,
              profile: profile,
              brandColor: brandColor,
              unitLabel: settings.distanceUnit,
              onOpenDetail: () => context.push('/bike/${widget.bike.id}'),
            ),
            const SizedBox(height: 12),
            _StatsRow(profile: profile),
            const SizedBox(height: 12),
            _NotesCard(notes: profile.model.notes, brandColor: brandColor),
            const SizedBox(height: 12),
            _FilterBar(
              search: _search,
              filter: _filterCategory,
              categories: categories,
              onSearchChanged: (v) => setState(() => _search = v),
              onFilterChanged: (v) => setState(() => _filterCategory = v),
            ),
            const SizedBox(height: 12),
            if (tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('No tasks match this filter.')),
              )
            else
              ...tasks.map(
                (task) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TaskTile(
                    task: task,
                    db: db,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            _Disclaimer(),
          ],
        );
      },
    );
  }

  List<ScheduledMaintenanceTask> _filteredTasks(
    List<ScheduledMaintenanceTask> tasks,
  ) {
    final q = _search.trim().toLowerCase();
    return tasks.where((t) {
      final typeOk =
          _filterCategory == null || t.category == _filterCategory;
      final searchOk = q.isEmpty ||
          t.task.toLowerCase().contains(q) ||
          t.interval.toLowerCase().contains(q);
      return typeOk && searchOk;
    }).toList();
  }
}

class _OverdueBanner extends StatelessWidget {
  final int count;
  const _OverdueBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count tracked ${count == 1 ? 'item needs' : 'items need'} attention',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _BikeHeaderCard extends StatelessWidget {
  final Bike bike;
  final BikeMaintenanceProfile profile;
  final Color brandColor;
  final dynamic unitLabel;
  final VoidCallback onOpenDetail;

  const _BikeHeaderCard({
    required this.bike,
    required this.profile,
    required this.brandColor,
    required this.unitLabel,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final model = profile.model;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenDetail,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: brandColor, width: 4)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: brandColor.withValues(alpha: 0.15),
                    child: Icon(bike.type.icon, color: brandColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bike.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          bike.displayTitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (!profile.exactModelMatch)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Schedule: ${model.name}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: scheme.outline),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: scheme.outline),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (profile.isElectricModel)
                    _EvChip(color: brandColor)
                  else
                    _SpecChip(
                      label:
                          '${model.cc.toStringAsFixed(model.cc % 1 == 0 ? 0 : 1)} cc',
                    ),
                  _SpecChip(label: '${model.cooling}-cooled'),
                  _SpecChip(label: model.type),
                  if (model.chain) const _SpecChip(label: 'Chain drive'),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.speed, size: 16, color: scheme.outline),
                  const SizedBox(width: 4),
                  Text(formatDistance(bike.odometerKm, unitLabel)),
                  const Spacer(),
                  Text(
                    profile.brand.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: brandColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EvChip extends StatelessWidget {
  final Color color;
  const _EvChip({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'EV',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  final String label;
  const _SpecChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final BikeMaintenanceProfile profile;
  const _StatsRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stats = [
      ('Total tasks', '${profile.model.maintenance.length}'),
      ('High priority', '${profile.highPriorityCount}'),
      ('Categories', '${profile.categoryCount}'),
    ];

    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    stats[i].$2,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stats[i].$1,
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _NotesCard extends StatelessWidget {
  final String notes;
  final Color brandColor;
  const _NotesCard({required this.notes, required this.brandColor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: brandColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Note from brand',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(notes, style: const TextStyle(height: 1.5)),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String search;
  final MaintenanceCategory? filter;
  final List<MaintenanceCategory> categories;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<MaintenanceCategory?> onFilterChanged;

  const _FilterBar({
    required this.search,
    required this.filter,
    required this.categories,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search tasks…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: onSearchChanged,
          ),
        ),
        const SizedBox(width: 8),
        DropdownButton<MaintenanceCategory?>(
          value: filter,
          hint: const Text('All'),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('All categories'),
            ),
            for (final c in categories)
              DropdownMenuItem(value: c, child: Text(c.label)),
          ],
          onChanged: onFilterChanged,
        ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  final ScheduledMaintenanceTask task;
  final MaintenanceScheduleDatabase db;

  const _TaskTile({
    required this.task,
    required this.db,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = db.colorFor(task.category);
    final priority = db.styleFor(task.priority);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(task.category.icon, color: typeColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.task,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.schedule, size: 14, color: scheme.outline),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        task.interval,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Badge(
                label: priority.label,
                background: priority.background,
                foreground: priority.foreground,
              ),
              const SizedBox(height: 4),
              _Badge(
                label: task.category.label,
                background: typeColor.withValues(alpha: 0.12),
                foreground: typeColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

class _NoScheduleCard extends StatelessWidget {
  final Bike bike;
  final String message;
  const _NoScheduleCard({required this.bike, required this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(Icons.info_outline,
                    size: 40, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Text(
                  bike.displayTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => context.push('/bike/${bike.id}'),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open bike details'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Disclaimer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Intervals are sourced from official owner manuals and brand service '
        'documentation. Increase frequency for extreme heat, dusty roads, or '
        'off-road use.',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.5),
      ),
    );
  }
}
