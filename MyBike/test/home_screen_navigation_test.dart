import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike/features/home/home_screen.dart';
import 'package:mybike/providers/settings_provider.dart';
import 'package:mybike/providers/app_providers.dart';
import 'package:mybike/providers/home_insights_provider.dart';
import 'package:mybike/providers/maintenance_schedule_provider.dart';
import 'package:mybike/services/reminder_service.dart';
import 'package:mybike/data/models/bike.dart';
import 'package:mybike/data/models/enums.dart';

class FakeBikesNotifier extends StateNotifier<List<Bike>> implements BikesNotifier {
  FakeBikesNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('HomeScreen renders global TopAppBar and handles navigation transitions', (WidgetTester tester) async {
    final testBike = Bike(
      id: 'active-bike-id',
      name: 'Black Shadow',
      make: 'Yamaha',
      model: 'MT-07',
      year: 2022,
      type: BikeType.sport,
      odometerKm: 4200.0,
      createdAt: DateTime.now(),
    );

    // Build the widget tree with provider overrides.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          riderProfileCompleteProvider.overrideWithValue(true),
          bikesProvider.overrideWith((ref) => FakeBikesNotifier([testBike])),
          garageSelectedBikeIdProvider.overrideWith((ref) => 'active-bike-id'),
          bikeByIdProvider('active-bike-id').overrideWithValue(testBike),
          remindersForBikeProvider('active-bike-id').overrideWithValue([]),
          // HomeTab (built eagerly inside the bottom-nav IndexedStack) now
          // reads these — see home_tab_ui_test.dart.
          fuelEconomyTrendProvider('active-bike-id').overrideWithValue(null),
          upcomingExpensesProvider('active-bike-id').overrideWithValue([]),
          recentActivityProvider('active-bike-id').overrideWithValue([]),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    // Verify global TopAppBar displays name and avatar. The greeting is now
    // time-of-day-dependent (UAT Phase 3) instead of always "Good Morning".
    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.text('Rider'), findsOneWidget); // Default rider profile name (no "Rossi" fallback)
    expect(find.byKey(const ValueKey('bike_selector_dropdown')), findsOneWidget);
    expect(find.byKey(const ValueKey('bell_notification_icon')), findsOneWidget);

    // Verify bottom navigation items are present by key
    expect(find.byKey(const ValueKey('home_tab')), findsOneWidget);
    expect(find.byKey(const ValueKey('garage_tab')), findsOneWidget);
    expect(find.byKey(const ValueKey('alerts_tab')), findsOneWidget);
    expect(find.byKey(const ValueKey('learn_tab')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile_tab')), findsOneWidget);

    // Click the notification bell icon to switch to Alerts tab
    await tester.tap(find.byKey(const ValueKey('bell_notification_icon')));
    await tester.pumpAndSettle();

    // Verify we are now on the Alerts tab (Reminders tab)
    expect(find.text('Alerts Center'), findsOneWidget);

    // Tap on the Garage tab to switch back
    await tester.tap(find.byKey(const ValueKey('garage_tab')));
    await tester.pumpAndSettle();

    // Verify we are on the Garage tab list
    expect(find.text('My Garage'), findsNothing); // Redundant AppBar removed, but we should see the bike list!
    expect(find.text('Black Shadow'), findsOneWidget);
  });

  testWidgets('Bike selector dropdown switches active bike on home screen', (WidgetTester tester) async {
    final bikeOne = Bike(
      id: 'bike-one',
      name: 'Black Shadow',
      make: 'Yamaha',
      model: 'MT-07',
      year: 2022,
      type: BikeType.sport,
      odometerKm: 4200.0,
      createdAt: DateTime.now(),
    );
    final bikeTwo = Bike(
      id: 'bike-two',
      name: 'Green Hornet',
      make: 'Kawasaki',
      model: 'Ninja 400',
      year: 2023,
      type: BikeType.sport,
      odometerKm: 5000.0,
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          riderProfileCompleteProvider.overrideWithValue(true),
          bikesProvider.overrideWith((ref) => FakeBikesNotifier([bikeOne, bikeTwo])),
          garageSelectedBikeIdProvider.overrideWith((ref) => 'bike-one'),
          bikeByIdProvider('bike-one').overrideWithValue(bikeOne),
          bikeByIdProvider('bike-two').overrideWithValue(bikeTwo),
          remindersForBikeProvider('bike-one').overrideWithValue([]),
          remindersForBikeProvider('bike-two').overrideWithValue([]),
          fuelEconomyTrendProvider('bike-one').overrideWithValue(null),
          fuelEconomyTrendProvider('bike-two').overrideWithValue(null),
          upcomingExpensesProvider('bike-one').overrideWithValue([]),
          upcomingExpensesProvider('bike-two').overrideWithValue([]),
          recentActivityProvider('bike-one').overrideWithValue([]),
          recentActivityProvider('bike-two').overrideWithValue([]),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Black Shadow'), findsOneWidget);
    expect(find.text('Green Hornet'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('bike_selector_dropdown')));
    await tester.pumpAndSettle();

    expect(find.text('Green Hornet'), findsOneWidget);

    await tester.tap(find.text('Green Hornet').last);
    await tester.pumpAndSettle();

    expect(find.text('Green Hornet'), findsWidgets);
    expect(find.text('2023 Kawasaki Ninja 400'), findsOneWidget);
  });
}
