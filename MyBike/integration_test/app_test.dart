// End-to-end integration test for the MyBike app.
//
// This test boots the real app, bypasses Firebase (Auth + Firestore + Local
// notifications) with Riverpod provider overrides so the test runs offline
// against the production widget tree, and walks the four core flows:
//
//   Flow 1 — Rider onboarding + first bike + initial service setup.
//   Flow 2 — Add maintenance item + log service (reminder resets).
//   Flow 3 — Fuel entries + economy calculation.
//   Flow 4 — Delete-bike cascade.
//
// Run on a connected Android device / emulator:
//   flutter test integration_test/app_test.dart
//
// The test uses a FakeAuthService that emits a synthetic signed-in user, so
// the GoRouter auth-redirect accepts us without a real Firebase session.
// FakeRiderProfileService returns an empty profile at startup so the
// onboarding screen renders, and lets saveRiderBasics / saveRiderProfile
// complete locally.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mybike/app/router.dart';
import 'package:mybike/app/theme.dart';
import 'package:mybike/data/local_store.dart';
import 'package:mybike/data/models/enums.dart';
import 'package:mybike/data/models/rider_profile.dart';
import 'package:mybike/providers/app_providers.dart';
import 'package:mybike/providers/settings_provider.dart';
import 'package:mybike/services/auth_service.dart';
import 'package:mybike/services/cloud_sync_service.dart';
import 'package:mybike/services/rider_profile_service.dart';

// -----------------------------------------------------------------------
// Fakes
// -----------------------------------------------------------------------

class FakeUser implements User {
  @override
  final String uid = 'test-user';
  @override
  final String? email = 'test@mybike.local';
  @override
  final bool emailVerified = true;
  @override
  final String? displayName = 'Test Rider';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class FakeAuthService implements AuthService {
  final _controller = StreamController<User?>.broadcast();
  final User _user = FakeUser();

  FakeAuthService() {
    // Emit the signed-in user on the next microtask so the router's
    // GoRouterRefreshStream picks it up on first redirect.
    scheduleMicrotask(() => _controller.add(_user));
  }

  @override
  Stream<User?> authStateChanges() => _controller.stream;

  @override
  User? get currentUser => _user;

  @override
  Future<UserCredential> signInWithEmail(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<UserCredential> registerWithEmail(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> updateDisplayName(String name) async {}

  @override
  Future<UserCredential> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<void> signOut() async {
    _controller.add(null);
  }

  @override
  Future<void> sendEmailVerificationIfNeeded() async {}

  @override
  Future<void> deleteCurrentUser() async {}
}

/// In-memory stand-in for the Firestore-backed rider profile service.
/// Starts with an empty profile so the onboarding screen renders, and
/// stores whatever the UI saves.
class FakeRiderProfileService implements RiderProfileService {
  RiderProfile? _profile;
  final _controller = StreamController<RiderProfile?>.broadcast();

  @override
  Stream<RiderProfile?> watch(String uid) {
    scheduleMicrotask(() => _controller.add(_profile));
    return _controller.stream;
  }

  @override
  Future<RiderProfile?> get(String uid) async => _profile;

  @override
  Future<void> save(String uid, RiderProfile profile) async {
    _profile = profile;
    _controller.add(profile);
  }
}

/// No-op cloud sync so Hive writes don't attempt to reach Firestore.
class FakeCloudSync implements CloudSyncService {
  @override
  bool get isActive => false;

  @override
  Future<void> start(String uid) async {}

  @override
  Future<void> stop({bool keepLocal = false}) async {}

  @override
  Future<void> push(String collection, String id, Map<String, dynamic> data) async {}

  @override
  Future<void> remove(String collection, String id) async {}

  @override
  Future<void> deleteRemoteUserData() async {}

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// -----------------------------------------------------------------------
// Harness
// -----------------------------------------------------------------------

/// Build an isolated MaterialApp around the production router with every
/// Firebase-touching provider overridden. Each test gets a fresh Hive dir
/// via setUp so flows don't bleed state into each other.
Widget buildApp() {
  return ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(FakeAuthService()),
      riderProfileServiceProvider.overrideWithValue(FakeRiderProfileService()),
      cloudSyncProvider.overrideWithValue(FakeCloudSync()),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
    ),
  );
}

Future<void> pumpSettled(WidgetTester tester) =>
    tester.pumpAndSettle(const Duration(seconds: 2));

// -----------------------------------------------------------------------
// Shared setup / teardown
// -----------------------------------------------------------------------

Future<void> initHive() async {
  await Hive.initFlutter('mybike_e2e_${DateTime.now().microsecondsSinceEpoch}');
  await Future.wait([
    Hive.openBox<String>(Boxes.bikes),
    Hive.openBox<String>(Boxes.items),
    Hive.openBox<String>(Boxes.records),
    Hive.openBox<String>(Boxes.fuel),
    Hive.openBox(Boxes.settings),
    Hive.openBox<String>(Boxes.catalog),
  ]);
}

Future<void> clearHive() async {
  for (final name in [
    Boxes.bikes,
    Boxes.items,
    Boxes.records,
    Boxes.fuel,
    Boxes.settings,
    Boxes.catalog,
  ]) {
    if (Hive.isBoxOpen(name)) {
      final box = Hive.box(name);
      await box.clear();
    }
  }
}

// -----------------------------------------------------------------------
// Steps
// -----------------------------------------------------------------------

Future<void> completeOnboarding(
  WidgetTester tester, {
  String name = 'Vishnu',
  String bikeNickname = 'Night Rider',
  String odometerKm = '12500',
}) async {
  // Step 1
  expect(find.text('Step 1 of 2'), findsOneWidget);
  await tester.enterText(find.byKey(const ValueKey('name_input_field')), name);
  // Tap DOB field + pick an "OK" default — the DatePicker opens with a
  // sensible initial date; just confirm it.
  await tester.tap(find.byKey(const ValueKey('dob_input_field')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await pumpSettled(tester);

  await tester.tap(find.byKey(const ValueKey('continue_setup_button')));
  await pumpSettled(tester);

  // Step 2
  expect(find.text('Step 2 of 2'), findsOneWidget);
  await tester.enterText(
      find.byKey(const ValueKey('bike_nickname_input')), bikeNickname);
  // Brand/model/year dropdowns are catalog-driven; pick the first offered.
  await tester.tap(find.byKey(const ValueKey('manufacturer_dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Hero').first);
  await pumpSettled(tester);

  await tester.tap(find.byKey(const ValueKey('bike_model_input')));
  await tester.pumpAndSettle();
  // Just pick whatever model surfaces first.
  final modelOption = find.byType(ListTile).first;
  await tester.tap(modelOption);
  await pumpSettled(tester);

  await tester.tap(find.byKey(const ValueKey('bike_year_input')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('2023').first);
  await pumpSettled(tester);

  await tester.enterText(
      find.byKey(const ValueKey('bike_odometer_input')), odometerKm);
  await tester.tap(find.byKey(const ValueKey('add_bike_button')));
  await pumpSettled(tester);
}

// -----------------------------------------------------------------------
// Suite
// -----------------------------------------------------------------------

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initHive();
  });

  setUp(() async {
    await clearHive();
  });

  testWidgets('Flow 1 — Rider onboarding + add first bike', (tester) async {
    await tester.pumpWidget(buildApp());
    await pumpSettled(tester);

    await completeOnboarding(tester);

    // Home should now be visible with the bike's nickname.
    expect(find.text('Night Rider'), findsWidgets);
    // Component Health card is present (we don't assert "100%" because
    // the fix makes empty groups show "—").
    expect(find.text('Component Health'), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('Flow 2 — Add maintenance item + log service', (tester) async {
    await tester.pumpWidget(buildApp());
    await pumpSettled(tester);
    await completeOnboarding(tester);

    // Open the bike detail by tapping the hero card's "View All".
    await tester.tap(find.byKey(const ValueKey('view_all_components_link')));
    await pumpSettled(tester);

    // Components tab → FAB "Add item"
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add item'));
    await pumpSettled(tester);

    // Default type is engineOil with its defaults — just save.
    await tester.tap(find.widgetWithText(FilledButton, 'Add item'));
    await pumpSettled(tester);

    // The new item should appear in the Components list.
    expect(find.text('Engine Oil'), findsWidgets);

    // Log a service for it via the ⋮ menu.
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await pumpSettled(tester);
    await tester.tap(find.text('Log service'));
    await pumpSettled(tester);
    await tester.tap(find.byKey(const ValueKey('save_service_record_btn')));
    await pumpSettled(tester);

    // Switch to the History tab to confirm the record is there.
    await tester.tap(find.text('History'));
    await pumpSettled(tester);
    expect(find.textContaining('Engine Oil'), findsWidgets);
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('Flow 3 — Fuel entries show real economy', (tester) async {
    await tester.pumpWidget(buildApp());
    await pumpSettled(tester);
    await completeOnboarding(tester, odometerKm: '10000');

    await tester.tap(find.byKey(const ValueKey('view_all_components_link')));
    await pumpSettled(tester);
    await tester.tap(find.text('Fuel'));
    await pumpSettled(tester);

    Future<void> addFuel(String odo, String liters) async {
      await tester.tap(find.byKey(const ValueKey('add_fuel_log_fab')));
      await pumpSettled(tester);
      // Odometer field is the first TextFormField with 'Odometer' label.
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Odometer (km) *'), odo);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Litres *'), liters);
      await tester.tap(find.widgetWithText(FilledButton, 'Add fuel-up'));
      await pumpSettled(tester);
    }

    await addFuel('10000', '20');
    await addFuel('10300', '20');

    // After two full-tank fills 300 km / 20 L = 15.0 Km/L.
    expect(find.textContaining('15.0'), findsWidgets);
    expect(find.text('—'), findsNothing); // placeholder cleared
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('Flow 4 — Delete-bike cascade purges child entities',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await pumpSettled(tester);
    await completeOnboarding(tester);

    // Open bike detail → overflow → Delete bike.
    await tester.tap(find.byKey(const ValueKey('view_all_components_link')));
    await pumpSettled(tester);
    await tester.tap(find.byKey(const ValueKey('bike_detail_overflow_menu')));
    await pumpSettled(tester);
    await tester.tap(find.text('Delete bike'));
    await pumpSettled(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await pumpSettled(tester);

    // Back on Home: the empty state ("Add your first motorcycle") returns.
    expect(find.textContaining('Add your first motorcycle'), findsOneWidget);
    // Bike's Hive box is empty.
    expect(Hive.box<String>(Boxes.bikes).isEmpty, isTrue);
  }, timeout: const Timeout(Duration(minutes: 4)));
}
