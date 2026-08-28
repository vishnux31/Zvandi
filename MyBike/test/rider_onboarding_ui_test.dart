import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike/features/auth/rider_onboarding_screen.dart';
import 'package:mybike/providers/catalog_provider.dart';

import 'test_catalog.dart';

void main() {
  testWidgets('RiderOnboardingScreen step 1 validation and step 2 rendering', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogProvider.overrideWith((ref) async => testBikeCatalog()),
        ],
        child: MaterialApp(
          home: RiderOnboardingScreen(),
        ),
      ),
    );

    // Verify we are at Step 1 initially
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.text('Rider Profile Setup'), findsOneWidget);
    expect(find.byKey(const ValueKey('name_input_field')), findsOneWidget);
    expect(find.byKey(const ValueKey('dob_input_field')), findsOneWidget);

    // Click continue without typing a name - validation error should show up
    await tester.tap(find.byKey(const ValueKey('continue_setup_button')));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your full name'), findsOneWidget);

    // Enter a valid name
    await tester.enterText(find.byKey(const ValueKey('name_input_field')), 'Valentino Rossi');
    
    // Tap to enter a date of birth
    // To simulate entering DOB without popping the real native date picker, we will set state directly or simulate selection.
    // Let's tap the Date of Birth field to open DatePicker
    await tester.tap(find.byKey(const ValueKey('dob_input_field')));
    await tester.pumpAndSettle();
    
    // Select OK on date picker (default date will be valid)
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Tap continue to go to Step 2
    await tester.tap(find.byKey(const ValueKey('continue_setup_button')));
    await tester.pumpAndSettle();

    // Verify that we transitioned to Step 2
    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.text('Add First Bike'), findsOneWidget);

    // Verify bike fields are visible
    expect(find.byKey(const ValueKey('bike_nickname_input')), findsOneWidget);
    expect(find.byKey(const ValueKey('manufacturer_dropdown')), findsOneWidget);
    expect(find.byKey(const ValueKey('bike_model_input')), findsOneWidget);
    expect(find.byKey(const ValueKey('bike_year_input')), findsOneWidget);
    expect(find.byKey(const ValueKey('bike_type_dropdown')), findsOneWidget);
    expect(find.byKey(const ValueKey('bike_odometer_input')), findsOneWidget);
  });
}
