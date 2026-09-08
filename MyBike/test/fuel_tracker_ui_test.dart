import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike/features/bikes/bike_detail_screen.dart';
import 'package:mybike/features/fuel/fuel_form_screen.dart';
import 'package:mybike/providers/app_providers.dart';
import 'package:mybike/data/models/bike.dart';
import 'package:mybike/data/models/enums.dart';

void main() {
  testWidgets(
      'Fuel tab renders telemetry summary and empty states, and the FAB routes to FuelFormScreen',
      (WidgetTester tester) async {
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

    // The Fuel tab's FAB and log rows now navigate via go_router (UAT
    // Phase 1: the old in-place `_LocalAddFuelDialog` was removed), so the
    // test needs a real router shell instead of a bare MaterialApp.
    final router = GoRouter(
      initialLocation: '/bike/test-bike-id',
      routes: [
        GoRoute(
          path: '/bike/:id',
          builder: (context, state) =>
              BikeDetailScreen(bikeId: state.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'fuel/new',
              builder: (context, state) =>
                  FuelFormScreen(bikeId: state.pathParameters['id']!),
            ),
          ],
        ),
      ],
    );

    // Build the widget tree with mocked provider states.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bikeByIdProvider('test-bike-id').overrideWithValue(testBike),
          fuelForBikeProvider('test-bike-id').overrideWithValue([]),
        ],
        child: MaterialApp.router(routerConfig: router),
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

    // No fuel-ups logged: an honest empty state, not an invented "42.5".
    expect(find.text('—'), findsOneWidget);

    // Efficiency chart empty state (real fl_chart trend, not a fabricated
    // sparkline — UAT Phase 4).
    expect(find.text('Efficiency Trend'), findsOneWidget);
    expect(
      find.text('Log a few more fuel-ups to see your efficiency trend.'),
      findsOneWidget,
    );

    // Verify history logs layout and empty message.
    expect(find.text('Fuel Logs History'), findsOneWidget);
    expect(find.text('No fuel tracking logs registered for this machine yet.'),
        findsOneWidget);

    // Find the FAB with key 'add_fuel_log_fab' and click it.
    final fab = find.byKey(const ValueKey('add_fuel_log_fab'));
    expect(fab, findsOneWidget);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    // The FAB now routes to the real FuelFormScreen (one implementation of
    // "add fuel entry", deep-linkable) instead of opening an in-place
    // dialog.
    expect(find.byType(FuelFormScreen), findsOneWidget);
    expect(find.text('Add fuel-up'), findsOneWidget);
  });
}
