import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike/features/home/garage_tab.dart';
import 'package:mybike/providers/app_providers.dart';
import 'package:mybike/providers/catalog_provider.dart';
import 'package:mybike/providers/maintenance_schedule_provider.dart';
import 'package:mybike/services/reminder_service.dart';
import 'package:mybike/data/models/bike.dart';
import 'package:mybike/data/models/enums.dart';

import 'test_catalog.dart';

class FakeBikesNotifier extends StateNotifier<List<Bike>> implements BikesNotifier {
  FakeBikesNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Garage tab renders list of motorcycles and handles add dialog overlay', (WidgetTester tester) async {
    final bike1 = Bike(
      id: 'bike-1-id',
      name: 'Black Dragon',
      make: 'Kawasaki',
      model: 'ZX-10R',
      year: 2023,
      type: BikeType.sport,
      odometerKm: 3200.0,
      createdAt: DateTime.now(),
    );

    final bike2 = Bike(
      id: 'bike-2-id',
      name: 'Night Rider',
      make: 'Yamaha',
      model: 'MT-09',
      year: 2021,
      type: BikeType.sport,
      odometerKm: 8500.0,
      createdAt: DateTime.now(),
    );

    // Build the widget tree with provider overrides.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogProvider.overrideWith((ref) async => testBikeCatalog()),
          bikesProvider.overrideWith((ref) => FakeBikesNotifier([bike1, bike2])),
          garageSelectedBikeIdProvider.overrideWith((ref) => 'bike-1-id'),
          remindersForBikeProvider('bike-1-id').overrideWithValue([]),
          remindersForBikeProvider('bike-2-id').overrideWithValue([]),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: GarageTab(),
          ),
        ),
      ),
    );

    // Verify both bike cards exist in the garage list
    expect(find.text('Black Dragon'), findsOneWidget);
    expect(find.text('Night Rider'), findsOneWidget);

    // Verify health percentages (defaults to 100% since no reminders exist)
    expect(find.text('100% Health'), findsNWidgets(2));

    // Tap on the FAB to open the Add Bike dialog
    final fab = find.byKey(const ValueKey('add_bike_fab'));
    expect(fab, findsOneWidget);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    // Verify the Add Motorcycle overlay dialog has opened
    expect(find.text('Add Motorcycle'), findsOneWidget);
    expect(find.byKey(const ValueKey('add_dialog_nickname')), findsOneWidget);
    expect(find.byKey(const ValueKey('add_dialog_make_select')), findsOneWidget);
    expect(find.byKey(const ValueKey('add_dialog_model')), findsOneWidget);
    expect(find.byKey(const ValueKey('add_dialog_year')), findsOneWidget);
    expect(find.byKey(const ValueKey('add_dialog_odometer')), findsOneWidget);

    // Tap the dialog cancel button
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Verify dialog is successfully closed
    expect(find.text('Add Motorcycle'), findsNothing);
  });
}
