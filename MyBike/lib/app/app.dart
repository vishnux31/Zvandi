import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import 'router.dart';
import 'theme.dart';

class MyBikeApp extends ConsumerWidget {
  const MyBikeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Start/stop cloud sync as the user signs in and out.
    ref.listen(authStateProvider, (previous, next) {
      final user = next.value;
      final sync = ref.read(cloudSyncProvider);
      if (user == null) {
        sync.stop();
      } else {
        sync.start(user.uid);
      }
    });

    return MaterialApp.router(
      title: 'MyBike',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
