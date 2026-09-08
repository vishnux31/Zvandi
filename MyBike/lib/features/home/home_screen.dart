import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/colors.dart';
import '../../providers/app_providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/maintenance_schedule_provider.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/reminder_service.dart';
import '../auth/rider_onboarding_screen.dart';
import '../settings/settings_tab.dart';
import 'garage_tab.dart';
import 'home_tab.dart';
import 'learn_tab.dart';
import 'reminders_tab.dart';
import 'widgets/bike_selector_dropdown.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.requestPermissions();
      NotificationService.instance
          .syncReminders(ref.read(remindersProvider));
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final profileLoading = ref.watch(riderProfileLoadingProvider);
    final profileComplete = ref.watch(riderProfileCompleteProvider);

    if (auth.isLoading || profileLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!profileComplete) {
      return const RiderOnboardingScreen();
    }

    // Keep scheduled notifications in sync with current reminder state.
    ref.listen(remindersProvider, (_, next) {
      NotificationService.instance.syncReminders(next);
    });

    final settings = ref.watch(settingsProvider);
    final bikes = ref.watch(bikesProvider);

    if (bikes.isNotEmpty && ref.read(garageSelectedBikeIdProvider) == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(garageSelectedBikeIdProvider.notifier).state = bikes.first.id;
      });
    }

    final activeBike = ref.watch(garageSelectedBikeProvider);
    final activeBikeAlerts = activeBike != null
        ? ref.watch(remindersForBikeProvider(activeBike.id))
        : <ReminderInfo>[];
    final activeCriticalCount = activeBikeAlerts.where((r) => r.status == ReminderStatus.overdue).length;

    const tabs = [HomeTab(), GarageTab(), RemindersTab(), LearnTab(), SettingsTab()];
    final active = ref.watch(activeRemindersProvider).length;
    final index = ref.watch(homeTabIndexProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBlack,
      appBar: AppBar(
        backgroundColor: AppColors.darkBlack,
        elevation: 0,
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.surfaceLight,
              radius: 18,
              child: Icon(
                Icons.person,
                color: AppColors.accentCopper,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Good Morning",
                  style: TextStyle(fontSize: 10, color: AppColors.subtextZinc, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Text(
                      settings.riderName ?? "Rider",
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.subtextZinc,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          const BikeSelectorDropdown(),
          IconButton(
            key: const ValueKey('bell_notification_icon'),
            onPressed: () {
              // Switch to RemindersTab (index 2) via the shared provider so
              // notification taps / deep links can drive this too.
              ref.read(homeTabIndexProvider.notifier).state = 2;
            },
            icon: Stack(
              alignment: Alignment.topRight,
              children: [
                Icon(
                  Icons.notifications,
                  color: activeCriticalCount > 0 ? AppColors.dangerRed : Colors.white,
                ),
                if (activeCriticalCount > 0)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.dangerRed,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: index, children: tabs),
      bottomNavigationBar: NavigationBar(
        key: const ValueKey('bottom_nav_bar'),
        selectedIndex: index,
        onDestinationSelected: (i) =>
            ref.read(homeTabIndexProvider.notifier).state = i,
        destinations: [
          const NavigationDestination(
            key: ValueKey('home_tab'),
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const NavigationDestination(
            key: ValueKey('garage_tab'),
            icon: Icon(Icons.garage_outlined),
            selectedIcon: Icon(Icons.garage),
            label: 'Garage',
          ),
          NavigationDestination(
            key: const ValueKey('alerts_tab'),
            icon: Badge(
              isLabelVisible: active > 0,
              label: Text('$active'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: const Icon(Icons.notifications),
            label: 'Reminders',
          ),
          const NavigationDestination(
            key: ValueKey('learn_tab'),
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Learn',
          ),
          const NavigationDestination(
            key: ValueKey('profile_tab'),
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
