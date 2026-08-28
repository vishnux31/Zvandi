import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike/features/home/home_tab.dart';
import 'package:mybike/providers/app_providers.dart';
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

    // Verify smart insights cards
    expect(find.text('Smart Insights'), findsOneWidget);
    expect(find.text('Wear Alert'), findsOneWidget);
    expect(find.text('Efficiency'), findsOneWidget);

    // Verify attention required badge
    expect(find.text('Attention Required'), findsOneWidget);
    expect(find.text('All systems healthy. No action required.'), findsOneWidget);

    // Verify upcoming expenses sections
    expect(find.text('Upcoming Expenses'), findsOneWidget);
    expect(find.text('Estimated Total (Next 30 days)'), findsOneWidget);

    // Verify recent activity timeline items
    expect(find.text('Recent Activity'), findsOneWidget);
    expect(find.text('Completed Morning Ride'), findsOneWidget);
    expect(find.text('Diagnostic Scan Performed'), findsOneWidget);
  });
}
