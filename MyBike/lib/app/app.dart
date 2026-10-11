import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/push_service.dart';
import 'router.dart';
import 'theme.dart';

class MyBikeApp extends ConsumerWidget {
  const MyBikeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Start/stop cloud sync + push registration as the user signs in and
    // out. Both are idempotent for the same uid.
    ref.listen(authStateProvider, (previous, next) {
      final user = next.value;
      final sync = ref.read(cloudSyncProvider);
      final push = ref.read(pushServiceProvider);
      if (user == null) {
        sync.stop();
        push.stop();
      } else {
        sync.start(user.uid);
        push.start(user.uid);
      }
    });

    return MaterialApp.router(
      title: 'MyBike',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      // The whole UI is intentionally dark-only — no light variant exists.
      // Forcing ThemeMode.dark avoids the previous footgun where theme ==
      // darkTheme and ThemeMode.system had no observable effect.
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
    );
  }
}
