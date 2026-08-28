import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike/features/bikes/bike_detail_screen.dart';
import 'package:mybike/providers/app_providers.dart';
import 'package:mybike/data/models/bike.dart';
import 'package:mybike/data/models/enums.dart';

void main() {
  testWidgets('Fuel tab renders telemetry summary, sparkline, empty state, and opens dialog', (WidgetTester tester) async {
    final testBike = Bike(
      id: 'test-bike-id',
      name: 'Test Kawasaki Ninja',
      make: 'Kawasaki',
      model: 'Ninja 400',
      year: 2022,
      type: BikeType.sport,
      odometerKm: 5000.0,
      createdAt: DateTime.now(),
    );

    // Build the widget tree with mocked provider states.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bikeByIdProvider('test-bike-id').overrideWithValue(testBike),
          fuelForBikeProvider('test-bike-id').overrideWithValue([]),
        ],
        child: const MaterialApp(
          home: BikeDetailScreen(bikeId: 'test-bike-id'),
        ),
      ),
    );

    // Initially loading the screen defaults to the first tab (Components).
    // Tap on the third tab: Fuel.
    await tester.tap(find.text('Fuel'));
    await tester.pumpAndSettle();

    // Verify stats tiles exist on the tab.
    expect(find.text('Fuel Performance Telemetry'), findsOneWidget);
    expect(find.text('Avg Fuel Economy'), findsOneWidget);
    expect(find.text('Total Cost'), findsOneWidget);
    expect(find.text('Total Fuel'), findsOneWidget);

    // Verify Sparkline index title is present.
    expect(find.text('Efficiency Trend Index'), findsOneWidget);

    // Verify history logs layout and empty message.
    expect(find.text('Fuel Logs History'), findsOneWidget);
    expect(find.text('No fuel tracking logs registered for this machine yet.'), findsOneWidget);

    // Find the FAB with key 'add_fuel_log_fab' and click it.
    final fab = find.byKey(const ValueKey('add_fuel_log_fab'));
    expect(fab, findsOneWidget);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    // Verify the refuel overlay dialog has opened.
    expect(find.text('Refuel Log Entry'), findsOneWidget);
    expect(find.byKey(const ValueKey('fuel_dialog_date')), findsOneWidget);
    expect(find.byKey(const ValueKey('fuel_dialog_odo')), findsOneWidget);
    expect(find.byKey(const ValueKey('fuel_dialog_liters')), findsOneWidget);
    expect(find.byKey(const ValueKey('fuel_dialog_cost')), findsOneWidget);
    expect(find.byKey(const ValueKey('fuel_dialog_location')), findsOneWidget);

    // Click 'Cancel' button to dismiss the dialog.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Assert that the dialog is closed.
    expect(find.text('Refuel Log Entry'), findsNothing);
  });
}
