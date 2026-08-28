import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike/features/service/service_form_screen.dart';
import 'package:mybike/providers/app_providers.dart';
import 'package:mybike/data/models/bike.dart';
import 'package:mybike/data/models/enums.dart';

void main() {
  testWidgets('ServiceFormScreen renders form fields and checkboxes, validates invalid input', (WidgetTester tester) async {
    final testBike = Bike(
      id: 'test-bike-id',
      name: 'Black Pearl',
      make: 'Suzuki',
      model: 'Hayabusa',
      year: 2020,
      type: BikeType.sport,
      odometerKm: 12000.0,
      createdAt: DateTime.now(),
    );

    // Build the widget tree with provider overrides.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bikeByIdProvider('test-bike-id').overrideWithValue(testBike),
          itemsForBikeProvider('test-bike-id').overrideWithValue([]),
        ],
        child: const MaterialApp(
          home: ServiceFormScreen(bikeId: 'test-bike-id'),
        ),
      ),
    );

    // Verify all fields are present on the form card.
    expect(find.text('Log Service'), findsOneWidget);
    expect(find.byKey(const ValueKey('service_date_input')), findsOneWidget);
    expect(find.byKey(const ValueKey('service_odo_input')), findsOneWidget);
    expect(find.byKey(const ValueKey('service_provider_input')), findsOneWidget);
    expect(find.byKey(const ValueKey('service_cost_input')), findsOneWidget);
    expect(find.byKey(const ValueKey('service_notes_input')), findsOneWidget);

    // Verify tasks checkboxes exist
    expect(find.byKey(const ValueKey('checkbox_oil_&_filter_change')), findsOneWidget);
    expect(find.byKey(const ValueKey('checkbox_chain_lube_&_tension_adjust')), findsOneWidget);
    expect(find.byKey(const ValueKey('checkbox_tire_replacement')), findsOneWidget);
    expect(find.byKey(const ValueKey('checkbox_brake_pad_replacement')), findsOneWidget);
    expect(find.byKey(const ValueKey('checkbox_fluid_flush_&_bleed')), findsOneWidget);
    expect(find.byKey(const ValueKey('checkbox_general_machine_inspection')), findsOneWidget);

    // Verify default value of provider text box is 'DIY / Self'
    expect(find.text('DIY / Self'), findsOneWidget);

    // Input invalid cost letters
    await tester.enterText(find.byKey(const ValueKey('service_cost_input')), 'invalid-cost');
    
    // Tap Save
    await tester.tap(find.byKey(const ValueKey('save_service_record_btn')));
    await tester.pumpAndSettle();

    // Verify that the validation error message displays
    expect(find.text('Please specify a valid numeric cost'), findsOneWidget);
  });
}
