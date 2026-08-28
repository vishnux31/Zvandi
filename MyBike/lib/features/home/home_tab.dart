import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/colors.dart';
import '../../core/formatters.dart';
import '../../data/models/bike.dart';
import '../../data/models/enums.dart';
import '../../providers/settings_provider.dart';
import '../../providers/maintenance_schedule_provider.dart';
import '../../services/bike_health_service.dart';
import '../../services/reminder_service.dart';
import '../bikes/widgets/add_bike_dialog.dart';
import '../bikes/widgets/add_motorcycle_card.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBike = ref.watch(garageSelectedBikeProvider);
    final settings = ref.watch(settingsProvider);
    final unit = settings.distanceUnit;

    if (activeBike == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AddMotorcycleCard(
              subtitle:
                  'Add your first motorcycle to track health, maintenance, and alerts.',
              onTap: () => showAddBikeDialog(context),
            ),
          ),
        ),
      );
    }

    final reminders = ref.watch(remindersForBikeProvider(activeBike.id));
    final profile = ref.watch(bikeMaintenanceProfileProvider(activeBike));
    final healthPercent = overallHealthPercent(reminders, profile: profile);
    final componentScores = ref.watch(bikeComponentScoresProvider(activeBike.id));
    final nextDue = calculateEarliestNextDue(reminders, unit);
    final criticalAlerts = reminders.where((r) => r.status == ReminderStatus.overdue).toList();

    final engineScore = componentScores[BikeComponentGroup.engine] ?? 100;
    final chainScore = componentScores[BikeComponentGroup.chain] ?? 100;
    final brakesScore = componentScores[BikeComponentGroup.brakes] ?? 100;
    final tyresScore = componentScores[BikeComponentGroup.tyres] ?? 100;

    return Scaffold(
      body: ListView(
        key: const ValueKey('home_screen_lazy_column'),
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 90),
        children: [
          _BikeHeroCard(
            bike: activeBike,
            healthPercent: healthPercent,
            unit: unit,
          ),
          const SizedBox(height: 16),
          _TelemetryDashboardSection(
            healthPercent: healthPercent,
            nextDue: nextDue,
          ),
          const SizedBox(height: 24),
          _ComponentHealthSection(
            bikeId: activeBike.id,
            engineScore: engineScore,
            chainScore: chainScore,
            brakesScore: brakesScore,
            tyresScore: tyresScore,
          ),
          const SizedBox(height: 24),
          const _SmartInsightsSection(),
          const SizedBox(height: 24),
          _AttentionRequiredSection(criticalAlerts: criticalAlerts),
          const SizedBox(height: 24),
          _UpcomingExpensesSection(
            onNavigate: () => context.push('/bike/${activeBike.id}'),
          ),
          const SizedBox(height: 24),
          const _RecentActivitySection(),
        ],
      ),
    );
  }
}

class _BikeHeroCard extends StatelessWidget {
  final Bike bike;
  final int healthPercent;
  final DistanceUnit unit;

  const _BikeHeroCard({
    required this.bike,
    required this.healthPercent,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outlineGray),
      ),
      color: AppColors.surfacePanel,
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _HeroBackgroundPainter(
                  gridColor: AppColors.primaryOrange.withValues(alpha: 0.08),
                  arcColor: AppColors.primaryOrange.withValues(alpha: 0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.safeGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.safeGreen.withValues(alpha: 0.3),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.safeGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "$healthPercent% Health",
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.safeGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    bike.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${bike.year ?? ''} ${bike.make ?? ''} ${bike.model ?? ''}".trim(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatDistance(bike.odometerKm, unit),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBackgroundPainter extends CustomPainter {
  final Color gridColor;
  final Color arcColor;

  _HeroBackgroundPainter({required this.gridColor, required this.arcColor});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 2.0;

    for (int i = 0; i <= 10; i++) {
      canvas.drawLine(
        Offset((i * 45).toDouble() - 30.0, 0.0),
        Offset((i * 45).toDouble() + 120.0, size.height),
        gridPaint,
      );
    }

    final arcPaint = Paint()
      ..color = arcColor
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTWH(size.width - 200, size.height - 150, 300, 300);
    canvas.drawArc(rect, -45 * 3.14159 / 180, 180 * 3.14159 / 180, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TelemetryDashboardSection extends StatelessWidget {
  final int healthPercent;
  final EarliestNextDue nextDue;

  const _TelemetryDashboardSection({
    required this.healthPercent,
    required this.nextDue,
  });

  @override
  Widget build(BuildContext context) {
    final healthColor = healthPercent >= 80
        ? AppColors.safeGreen
        : (healthPercent >= 60 ? AppColors.warningAmber : AppColors.dangerRed);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.outlineGray),
            ),
            color: AppColors.surfacePanel,
            child: SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(100, 100),
                    painter: _GaugePainter(
                      progress: healthPercent / 100.0,
                      progressColor: healthColor,
                      trackColor: AppColors.surfaceLight,
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "$healthPercent%",
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "HEALTH",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.subtextZinc,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        title: "Status",
                        value: healthPercent >= 75 ? "Healthy" : "Troubled",
                        color: healthPercent >= 75 ? AppColors.safeGreen : AppColors.warningAmber,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatTile(
                        title: "Readiness",
                        value: healthPercent >= 70 ? "Safe Ride" : "Inspect",
                        color: healthPercent >= 70 ? AppColors.safeGreen : AppColors.dangerRed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _StatTile(
                  title: "Next Due",
                  value: nextDue.displayText,
                  color: nextDue.isOverdue ? AppColors.dangerRed : AppColors.primaryOrange,
                  valueMaxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color trackColor;

  _GaugePainter({
    required this.progress,
    required this.progressColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 10.0
      ..style = PaintingStyle.stroke;

    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = 10.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -90 * 3.14159 / 180,
      progress * 360 * 3.14159 / 180,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  final Color? color;
  final int valueMaxLines;

  const _StatTile({
    required this.title,
    required this.value,
    this.color,
    this.valueMaxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final hasPill = color == AppColors.safeGreen || color == AppColors.dangerRed;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.outlineGray),
      ),
      color: AppColors.surfacePanel,
      child: Container(
        constraints: BoxConstraints(minHeight: valueMaxLines > 1 ? 84 : 70),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.subtextZinc,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                if (hasPill) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color ?? Colors.white,
                    ),
                    maxLines: valueMaxLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ComponentHealthSection extends StatelessWidget {
  final String bikeId;
  final int engineScore;
  final int chainScore;
  final int brakesScore;
  final int tyresScore;

  const _ComponentHealthSection({
    required this.bikeId,
    required this.engineScore,
    required this.chainScore,
    required this.brakesScore,
    required this.tyresScore,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Component Health",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              InkWell(
                key: const ValueKey('view_all_components_link'),
                onTap: () => context.push('/bike/$bikeId'),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    "View All",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.outlineGray),
            ),
            color: AppColors.surfacePanel,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _ComponentRow(name: "Engine", score: engineScore, icon: Icons.settings),
                  const SizedBox(height: 16),
                  _ComponentRow(name: "Chain", score: chainScore, icon: Icons.link),
                  const SizedBox(height: 16),
                  _ComponentRow(name: "Brakes", score: brakesScore, icon: Icons.radio_button_checked),
                  const SizedBox(height: 16),
                  _ComponentRow(name: "Tyres", score: tyresScore, icon: Icons.tire_repair),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  final String name;
  final int score;
  final IconData icon;

  const _ComponentRow({
    required this.name,
    required this.score,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = score >= 80
        ? AppColors.safeGreen
        : (score >= 50 ? AppColors.warningAmber : AppColors.dangerRed);

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.surfaceLight,
          radius: 18,
          child: Icon(icon, color: progressColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "$score%",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: progressColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: score / 100.0,
                  color: progressColor,
                  backgroundColor: AppColors.darkBlack,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SmartInsightsSection extends StatelessWidget {
  const _SmartInsightsSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Smart Insights",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.outlineGray),
                  ),
                  color: AppColors.surfacePanel,
                  child: Container(
                    height: 180,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.trending_up, color: AppColors.primaryOrange, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  "Wear Alert",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryOrange,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              Icons.lightbulb,
                              color: AppColors.primaryOrange.withValues(alpha: 0.5),
                              size: 20,
                            ),
                          ],
                        ),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: 12.0),
                            child: Text(
                              "Your chain is wearing faster than expected based on your recent aggressive acceleration patterns.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                height: 1.45,
                              ),
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.outlineGray),
                  ),
                  color: AppColors.surfacePanel,
                  child: Container(
                    height: 180,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle, color: AppColors.safeGreen, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  "Efficiency",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.safeGreen,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              Icons.eco,
                              color: AppColors.safeGreen.withValues(alpha: 0.5),
                              size: 20,
                            ),
                          ],
                        ),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: 12.0),
                            child: Text(
                              "Fuel economy is up 4% this month. Maintaining steady RPMs during city commutes is paying off.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                height: 1.45,
                              ),
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttentionRequiredSection extends StatelessWidget {
  final List<ReminderInfo> criticalAlerts;

  const _AttentionRequiredSection({required this.criticalAlerts});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                "Attention Required",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.dangerRed.withValues(alpha: 0.15),
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.3)),
                ),
                child: Text(
                  "${criticalAlerts.length}",
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.dangerRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.outlineGray),
            ),
            color: AppColors.surfacePanel,
            child: Column(
              children: [
                if (criticalAlerts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        "All systems healthy. No action required.",
                        style: TextStyle(color: AppColors.subtextZinc),
                      ),
                    ),
                  )
                else
                  ...criticalAlerts.map((alert) {
                    return Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.surfaceLight,
                            radius: 20,
                            child: Icon(
                              Icons.warning,
                              color: AppColors.dangerRed,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            alert.item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              "Component requires service checklist inspections.",
                              style: TextStyle(color: AppColors.subtextZinc, fontSize: 13),
                            ),
                          ),
                        ),
                        if (alert != criticalAlerts.last)
                          const Divider(color: AppColors.outlineGray, height: 1),
                      ],
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingExpensesSection extends StatelessWidget {
  final VoidCallback onNavigate;

  const _UpcomingExpensesSection({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Upcoming Expenses",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.account_balance_wallet, color: AppColors.subtextZinc),
                onPressed: onNavigate,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.outlineGray),
            ),
            color: AppColors.surfacePanel,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.surfaceLight,
                            radius: 16,
                            child: Icon(ServiceType.engineOil.icon, color: AppColors.labelZinc, size: 16),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Oil Filter & Synthetic Oil",
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                      const Text(
                        "\$85",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.surfaceLight,
                            radius: 16,
                            child: Icon(ServiceType.frontTire.icon, color: AppColors.labelZinc, size: 16),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Rear Tyre Replacement",
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                      const Text(
                        "\$220",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(color: AppColors.outlineGray),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Estimated Total (Next 30 days)",
                        style: TextStyle(color: AppColors.subtextZinc, fontSize: 13),
                      ),
                      const Text(
                        "\$305",
                        style: TextStyle(
                          color: AppColors.primaryOrange,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection();

  @override
  Widget build(BuildContext context) {
    final activities = [
      ("Today, 10:30 AM", "Completed Morning Ride", "Distance: 45km • Avg Speed: 62km/h"),
      ("Yesterday, 4:15 PM", "Tire Pressure Adjusted", "Front: 36 PSI • Rear: 42 PSI"),
      ("Oct 12, 09:00 AM", "Diagnostic Scan Performed", "No fault codes found")
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Recent Activity",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.outlineGray),
            ),
            color: AppColors.surfacePanel,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: List.generate(activities.length, (index) {
                  final act = activities[index];
                  final isDiagnostic = act.$2.contains("Diagnostic");

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: index == 0 ? AppColors.primaryOrange : AppColors.surfaceLight,
                              shape: BoxShape.circle,
                            ),
                          ),
                          if (index < activities.length - 1)
                            Container(
                              width: 2,
                              height: 50,
                              color: AppColors.outlineGray,
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: index < activities.length - 1 ? 16.0 : 0.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                act.$1,
                                style: const TextStyle(color: AppColors.subtextZinc, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                act.$2,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              if (isDiagnostic)
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: AppColors.safeGreen, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      act.$3,
                                      style: const TextStyle(color: AppColors.safeGreen, fontSize: 13),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  act.$3,
                                  style: const TextStyle(color: AppColors.subtextZinc, fontSize: 13),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
