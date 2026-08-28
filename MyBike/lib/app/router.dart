import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:go_router/go_router.dart';

import '../features/auth/sign_in_screen.dart';
import '../features/bikes/bike_detail_screen.dart';
import '../features/bikes/bike_form_screen.dart';
import '../features/fuel/fuel_form_screen.dart';
import '../features/home/home_screen.dart';
import '../features/maintenance_items/item_form_screen.dart';
import '../features/service/service_form_screen.dart';

/// Notifies GoRouter to re-run redirects whenever auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable:
      GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
  redirect: (context, state) {
    final loggedIn = FirebaseAuth.instance.currentUser != null;
    final atSignIn = state.matchedLocation == '/signin';
    if (!loggedIn) return atSignIn ? null : '/signin';
    if (atSignIn) return '/';
    return null;
  },
  routes: [
    GoRoute(
      path: '/signin',
      builder: (context, state) => const SignInScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/bike/new',
      builder: (context, state) => const BikeFormScreen(),
    ),
    GoRoute(
      path: '/bike/:id',
      builder: (context, state) =>
          BikeDetailScreen(bikeId: state.pathParameters['id']!),
      routes: [
        GoRoute(
          path: 'edit',
          builder: (context, state) =>
              BikeFormScreen(bikeId: state.pathParameters['id']),
        ),
        GoRoute(
          path: 'item/new',
          builder: (context, state) =>
              ItemFormScreen(bikeId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: 'item/:itemId',
          builder: (context, state) => ItemFormScreen(
            bikeId: state.pathParameters['id']!,
            itemId: state.pathParameters['itemId'],
          ),
        ),
        GoRoute(
          path: 'service/new',
          builder: (context, state) => ServiceFormScreen(
            bikeId: state.pathParameters['id']!,
            itemId: state.uri.queryParameters['itemId'],
            recordId: null,
          ),
        ),
        GoRoute(
          path: 'service/:recordId',
          builder: (context, state) => ServiceFormScreen(
            bikeId: state.pathParameters['id']!,
            recordId: state.pathParameters['recordId'],
          ),
        ),
        GoRoute(
          path: 'fuel/new',
          builder: (context, state) =>
              FuelFormScreen(bikeId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: 'fuel/:fuelId',
          builder: (context, state) => FuelFormScreen(
            bikeId: state.pathParameters['id']!,
            fuelId: state.pathParameters['fuelId'],
          ),
        ),
      ],
    ),
  ],
);
