import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike/features/home/home_tab.dart';
import 'package:mybike/providers/app_providers.dart';
import 'package:mybike/providers/home_insights_provider.dart';
import 'package:mybike/providers/maintenance_schedule_provider.dart';
import 'package:mybike/services/reminder_service.dart';
import 'package:mybike/data/models/bike.dart';
import 'package:mybike/data/models/enums.dart';

void main() {
  testWidgets('HomeTab renders empty state when no bike is selected', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        overrides: [],
        child: MaterialApp(
          home: HomeTab(),
        ),
      ),
    );

    expect(find.text('Add New Motorcycle'), findsOneWidget);
    expect(
      find.text(
        'Add your first motorcycle to track health, maintenance, and alerts.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('HomeTab renders cockpit dashboard sections when active bike is selected', (WidgetTester tester) async {
    final testBike = Bike(
      id: 'active-bike-id',
      name: 'Green Hornet',
      make: 'Kawasaki',
      model: 'Ninja 400',
      year: 2022,
      type: BikeType.sport,
      odometerKm: 5000.0,
      createdAt: DateTime.now(),
    );

    // Build the widget tree with provider overrides.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          garageSelectedBikeIdProvider.overrideWith((ref) => 'active-bike-id'),
          bikeByIdProvider('active-bike-id').overrideWithValue(testBike),
          remindersForBikeProvider('active-bike-id').overrideWithValue([]),
          // UAT Phase 3 introduced these — override so the widget doesn't
          // fall through to the real (Hive-backed) records/fuel providers.
          fuelEconomyTrendProvider('active-bike-id').overrideWithValue(null),
          upcomingExpensesProvider('active-bike-id').overrideWithValue([]),
          recentActivityProvider('active-bike-id').overrideWithValue([]),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: HomeTab(),
          ),
        ),
      ),
    );

    // Verify visual elements on the active bike cockpit dashboard.
    expect(find.text('Green Hornet'), findsOneWidget);
    expect(find.text('2022 Kawasaki Ninja 400'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('HEALTH'), findsOneWidget);

    // Verify component health sections are rendered
    expect(find.text('Component Health'), findsOneWidget);
    expect(find.text('Engine'), findsOneWidget);
    expect(find.text('Chain'), findsOneWidget);
    expect(find.text('Brakes'), findsOneWidget);
    expect(find.text('Tyres'), findsOneWidget);

    // Verify smart insights section: with no reminders and no fuel history,
    // there's nothing real to report, so it shows an honest "All Clear"
    // placeholder rather than a fabricated wear/efficiency story.
    expect(find.text('Smart Insights'), findsOneWidget);
    expect(find.text('All Clear'), findsOneWidget);
    expect(find.text('Wear Alert'), findsNothing);
    expect(find.text('Efficiency'), findsNothing);

    // Verify attention required badge
    expect(find.text('Attention Required'), findsOneWidget);
    expect(find.text('All systems healthy. No action required.'), findsOneWidget);

    // Verify upcoming expenses section's honest empty state (no reminders).
    expect(find.text('Upcoming Expenses'), findsOneWidget);
    expect(find.text('Nothing due soon.'), findsOneWidget);

    // Verify recent activity's honest empty state (no logged events).
    expect(find.text('Recent Activity'), findsOneWidget);
    expect(find.text('No service or fuel logs yet.'), findsOneWidget);
  });
}
