import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../app/colors.dart';
import '../../core/formatters.dart';
import '../../core/units.dart';
import '../../data/models/bike.dart';
import '../../data/models/enums.dart';
import '../../data/models/fuel_entry.dart';
import '../../data/models/maintenance_item.dart';
import '../../data/models/service_record.dart';
import '../../providers/app_providers.dart';
import '../../providers/settings_provider.dart';
import '../../services/reminder_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/wear_indicator.dart';
class BikeDetailScreen extends ConsumerStatefulWidget {
  final String bikeId;
  const BikeDetailScreen({super.key, required this.bikeId});

  @override
  ConsumerState<BikeDetailScreen> createState() => _BikeDetailScreenState();
}

class _BikeDetailScreenState extends ConsumerState<BikeDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _updateOdometer() async {
    final unit = ref.read(settingsProvider).distanceUnit;
    final bike = ref.read(bikeByIdProvider(widget.bikeId));
    if (bike == null) return;
    final controller = TextEditingController(
        text: unit.fromKm(bike.odometerKm).round().toString());
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update odometer'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: unit.label,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              Navigator.pop(context, v == null ? null : unit.toKm(v));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      ref
          .read(bikesProvider.notifier)
          .save(bike.copyWith(odometerKm: result));
    }
  }

  Future<void> _markItemDone(MaintenanceItem item) async {
    final bike = ref.read(bikeByIdProvider(widget.bikeId));
    if (bike == null) return;

    final now = DateTime.now();
    final record = ServiceRecord(
      id: const Uuid().v4(),
      bikeId: bike.id,
      itemId: item.id,
      type: item.type,
      date: now,
      odometerKm: bike.odometerKm,
      notes: item.name,
      createdAt: now,
    );

    await ref.read(recordsProvider.notifier).save(record);
    await ref.read(itemsProvider.notifier).save(
          item.copyWith(
            lastServiceDate: now,
            lastServiceOdometerKm: bike.odometerKm,
          ),
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} logged and reset')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bike = ref.watch(bikeByIdProvider(widget.bikeId));
    final settings = ref.watch(settingsProvider);
    if (bike == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
            icon: Icons.no_crash, title: 'This bike no longer exists'),
      );
    }
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButton: _buildFab(),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push('/bike/${bike.id}/edit'),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.primaryContainer, scheme.surface],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(56, 8, 20, 72),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(bike.type.icon,
                            size: 36, color: scheme.onPrimaryContainer),
                        const Spacer(),
                        Text(
                          bike.name,
                          style: TextStyle(
                            color: scheme.onPrimaryContainer,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          bike.displayTitle,
                          style: TextStyle(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _updateOdometer,
                          child: Row(
                            children: [
                              Icon(Icons.speed,
                                  size: 18, color: scheme.onPrimaryContainer),
                              const SizedBox(width: 6),
                              Text(
                                formatDistance(
                                    bike.odometerKm, settings.distanceUnit),
                                style: TextStyle(
                                  color: scheme.onPrimaryContainer,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.edit,
                                  size: 14, color: scheme.onPrimaryContainer),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'Components'),
                Tab(text: 'History'),
                Tab(text: 'Fuel'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _ComponentsTab(
              bikeId: bike.id,
              onMarkDone: _markItemDone,
            ),
            _HistoryTab(bikeId: bike.id),
            _FuelTab(bikeId: bike.id),
          ],
        ),
      ),
    );
  }

  Widget _buildFab() {
    switch (_tabs.index) {
      case 0:
        return FloatingActionButton.extended(
          heroTag: 'fab0',
          onPressed: () => context.push('/bike/${widget.bikeId}/item/new'),
          icon: const Icon(Icons.add),
          label: const Text('Add item'),
        );
      case 1:
        return FloatingActionButton.extended(
          heroTag: 'fab1',
          onPressed: () => context.push('/bike/${widget.bikeId}/service/new'),
          icon: const Icon(Icons.build),
          label: const Text('Log service'),
        );
      default:
        return FloatingActionButton(
          key: const ValueKey('add_fuel_log_fab'),
          heroTag: 'fab2',
          onPressed: () => context.push('/bike/${widget.bikeId}/fuel/new'),
          backgroundColor: AppColors.accentCopper,
          foregroundColor: AppColors.onPrimaryText,
          child: const Icon(Icons.local_gas_station),
        );
    }
  }
}

class _ComponentsTab extends ConsumerWidget {
  final String bikeId;
  final Future<void> Function(MaintenanceItem item) onMarkDone;

  const _ComponentsTab({
    required this.bikeId,
    required this.onMarkDone,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(remindersForBikeProvider(bikeId));
    final settings = ref.watch(settingsProvider);

    if (reminders.isEmpty) {
      return EmptyState(
        icon: Icons.build_circle_outlined,
        title: 'No maintenance items',
        message:
            'Add items like engine oil, chain or tires to track wear and get reminders.',
        action: FilledButton.icon(
          onPressed: () => context.push('/bike/$bikeId/item/new'),
          icon: const Icon(Icons.add),
          label: const Text('Add item'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: reminders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final r = reminders[i];
        final subtitle = <String>[];
        if (r.remainingKm != null) {
          final km = r.remainingKm!;
          subtitle.add(km < 0
              ? '${formatDistance(-km, settings.distanceUnit)} over'
              : '${formatDistance(km, settings.distanceUnit)} left');
        }
        if (r.item.nextDueDate != null) {
          subtitle.add(relativeDays(r.item.nextDueDate!, DateTime.now()));
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(r.item.type.icon,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(r.item.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    _ComponentStatusDropdown(
                      onDone: () => onMarkDone(r.item),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') {
                          context.push('/bike/$bikeId/item/${r.item.id}');
                        } else if (v == 'log') {
                          context.push(
                              '/bike/$bikeId/service/new?itemId=${r.item.id}');
                        } else if (v == 'delete') {
                          ref.read(itemsProvider.notifier).remove(r.item.id);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'log', child: Text('Log service')),
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                WearIndicator(usage: r.usage, status: r.status),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(subtitle.join('  •  '),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _ComponentStatus { todo, done }

class _ComponentStatusDropdown extends StatefulWidget {
  final Future<void> Function() onDone;
  const _ComponentStatusDropdown({required this.onDone});

  @override
  State<_ComponentStatusDropdown> createState() =>
      _ComponentStatusDropdownState();
}

class _ComponentStatusDropdownState extends State<_ComponentStatusDropdown> {
  _ComponentStatus _status = _ComponentStatus.todo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDone = _status == _ComponentStatus.done;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDone
            ? scheme.primaryContainer.withValues(alpha: 0.5)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_ComponentStatus>(
          value: _status,
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          items: const [
            DropdownMenuItem(
              value: _ComponentStatus.todo,
              child: Text('To do'),
            ),
            DropdownMenuItem(
              value: _ComponentStatus.done,
              child: Text('Done'),
            ),
          ],
          onChanged: (value) async {
            if (value == _ComponentStatus.done) {
              await widget.onDone();
              if (mounted) setState(() => _status = _ComponentStatus.todo);
            } else if (value != null) {
              setState(() => _status = value);
            }
          },
        ),
      ),
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  final String bikeId;
  const _HistoryTab({required this.bikeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(recordsForBikeProvider(bikeId));
    final settings = ref.watch(settingsProvider);

    if (records.isEmpty) {
      return EmptyState(
        icon: Icons.history,
        title: 'No service history',
        message: 'Log your first service to start building a history.',
        action: FilledButton.icon(
          onPressed: () => context.push('/bike/$bikeId/service/new'),
          icon: const Icon(Icons.build),
          label: const Text('Log service'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: records.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final r = records[i];
        final title =
            (r.notes != null && r.notes!.isNotEmpty) ? r.notes! : r.type.label;
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.secondaryContainer,
              child: Icon(r.type.icon,
                  color: Theme.of(context).colorScheme.onSecondaryContainer),
            ),
            title: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${r.type.label} • ${formatDate(r.date)} • ${formatDistance(r.odometerKm, settings.distanceUnit)}',
            ),
            trailing: r.cost == null
                ? null
                : Text(
                    formatCost(r.cost!),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
            onTap: () => context.push('/bike/$bikeId/service/${r.id}'),
          ),
        );
      },
    );
  }
}

class _FuelTab extends ConsumerWidget {
  final String bikeId;

  const _FuelTab({required this.bikeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(fuelForBikeProvider(bikeId));
    final settings = ref.watch(settingsProvider);
    final unit = settings.distanceUnit;

    final totalCost = entries.fold<double>(0, (sum, e) => sum + (e.cost ?? 0));
    final totalLiters = entries.fold<double>(0, (sum, e) => sum + e.liters);

    // Compute average economy using odometer delta divided by total liters
    final sorted = List<FuelEntry>.from(entries)
      ..sort((a, b) => a.odometerKm.compareTo(b.odometerKm));

    // Real economy requires at least two fuel-ups to derive a distance
    // delta — never fabricate a number when there isn't enough data yet.
    String? fuelEconomy;
    if (totalLiters > 0 && sorted.length >= 2) {
      final delta = sorted.last.odometerKm - sorted.first.odometerKm;
      if (delta > 0) {
        if (unit == DistanceUnit.km) {
          fuelEconomy = (delta / totalLiters).toStringAsFixed(1);
        } else {
          final miles = delta / 1.609344;
          final gallons = totalLiters / 3.785411784;
          fuelEconomy = (miles / gallons).toStringAsFixed(1);
        }
      }
    }

    final economyUnitLabel = unit == DistanceUnit.km ? 'Km/L' : 'mpg';

    return ListView(
      key: const ValueKey('fuel_tracker_lazy_column'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            "Fuel Performance Telemetry",
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.subtextZinc,
                ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                title: "Avg Fuel Economy",
                value: fuelEconomy == null
                    ? "—"
                    : "$fuelEconomy $economyUnitLabel",
                valueColor: AppColors.safeGreen,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                title: "Total Cost",
                value: formatCost(totalCost),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                title: "Total Fuel",
                value: "${totalLiters.toStringAsFixed(1)} L",
              ),
            ),
          ],
        ),
        if (fuelEconomy == null) ...[
          const SizedBox(height: 6),
          Text(
            "Add 2+ fuel-ups to calculate economy.",
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.subtextZinc,
                ),
          ),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Efficiency Trend Index",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.subtextZinc,
                      ),
                ),
                const SizedBox(height: 12),
                const _SparklineChart(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Initial Run",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.subtextZinc,
                          ),
                    ),
                    Text(
                      "Target Peak (+4%)",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.safeGreen,
                          ),
                    ),
                    Text(
                      "Now",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.subtextZinc,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(
            "Fuel Logs History",
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.subtextZinc,
                ),
          ),
        ),
        if (entries.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
              child: Center(
                child: Text(
                  "No fuel tracking logs registered for this machine yet.",
                  style: TextStyle(color: AppColors.subtextZinc),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          ...entries.map((log) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const CircleAvatar(
                  backgroundColor: AppColors.surfaceLight,
                  radius: 20,
                  child: Icon(
                    Icons.local_gas_station,
                    color: AppColors.accentCopper,
                    size: 20,
                  ),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      (log.notes != null && log.notes!.isNotEmpty)
                          ? log.notes!
                          : '—',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      formatCost(log.cost ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${formatDate(log.date)} • ${log.liters.toStringAsFixed(1)} Liters",
                        style: const TextStyle(color: AppColors.subtextZinc),
                      ),
                      Text(
                        formatDistance(log.odometerKm, unit),
                        style: const TextStyle(color: AppColors.subtextZinc),
                      ),
                    ],
                  ),
                ),
                onTap: () => context.push('/bike/$bikeId/fuel/${log.id}'),
              ),
            );
          }),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  final Color? valueColor;

  const _StatTile({
    required this.title,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.subtextZinc,
                    fontSize: 10,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SparklineChart extends StatelessWidget {
  const _SparklineChart();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: CustomPaint(
        painter: _SparklinePainter(
          lineColor: AppColors.safeGreen,
          guideColor: AppColors.outlineGray.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final Color lineColor;
  final Color guideColor;

  _SparklinePainter({required this.lineColor, required this.guideColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final guidePaint = Paint()
      ..color = guideColor
      ..strokeWidth = 1;

    // Draw horizontal guides
    canvas.drawLine(const Offset(0, 10), Offset(size.width, 10), guidePaint);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), guidePaint);
    canvas.drawLine(Offset(0, size.height - 10), Offset(size.width, size.height - 10), guidePaint);

    // Spark point coordinates representing economy index
    final points = [
      Offset(20, size.height - 15),
      Offset(size.width * 0.25, size.height - 25),
      Offset(size.width * 0.5, size.height - 20),
      Offset(size.width * 0.75, 12),
      Offset(size.width - 20, 18),
    ];

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    for (final pt in points) {
      canvas.drawCircle(pt, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

