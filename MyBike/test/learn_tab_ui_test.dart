import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybike/data/models/bike.dart';
import 'package:mybike/data/models/enums.dart';
import 'package:mybike/features/home/learn_tab.dart';
import 'package:mybike/providers/app_providers.dart';
import 'package:mybike/providers/maintenance_schedule_provider.dart';

void main() {
  testWidgets('LearnTab shows coming soon when no schedule is available', (WidgetTester tester) async {
    final bike = Bike(
      id: 'bike-1',
      name: 'Unknown Bike',
      make: 'Unknown',
      model: 'Unknown Model',
      createdAt: DateTime(2024),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          garageSelectedBikeIdProvider.overrideWith((ref) => 'bike-1'),
          bikeByIdProvider('bike-1').overrideWithValue(bike),
        ],
        child: const MaterialApp(home: LearnTab()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maintenance Tips'), findsOneWidget);
    expect(find.text('Tips for Unknown Bike'), findsOneWidget);
    expect(
      find.text('We will add the maintenance tips soon.'),
      findsNWidgets(4),
    );
    expect(find.textContaining('10,000 km'), findsNothing);
  });

  testWidgets('LearnTab shows dynamic OEM tips for a known model', (WidgetTester tester) async {
    final bike = Bike(
      id: 'bike-1',
      name: 'Splendor',
      make: 'Hero MotoCorp',
      model: 'Splendor Plus',
      brandId: 'hero',
      type: BikeType.commuter,
      createdAt: DateTime(2024),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          garageSelectedBikeIdProvider.overrideWith((ref) => 'bike-1'),
          bikeByIdProvider('bike-1').overrideWithValue(bike),
        ],
        child: const MaterialApp(home: LearnTab()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Engine oil change'), findsOneWidget);
    expect(find.textContaining('3,000 km or 3 months'), findsOneWidget);
    expect(find.text('We will add the maintenance tips soon.'), findsNothing);
    expect(find.textContaining('10,000 km'), findsNothing);
  });
}
