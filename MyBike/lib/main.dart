import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'data/local_store.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  // Catch everything from the Flutter framework, the Dart isolate, and
  // async errors and route them through Crashlytics. The guarded zone must
  // wrap the entire app so uncaught Future errors are also captured.
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // App Check: Play Integrity on Android, DeviceCheck on iOS. In debug
    // builds we use the debug providers so the local build still works.
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleDeviceCheckProvider(),
      );
    } catch (e, s) {
      // App Check must never block app boot. Report but continue.
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: s));
    }

    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: true);

    // Crashlytics plumbing.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    // Toggle on in release only to avoid noisy debug reports.
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);

    await LocalStore.init();
    await NotificationService.instance.init();

    runApp(const ProviderScope(child: MyBikeApp()));
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}
