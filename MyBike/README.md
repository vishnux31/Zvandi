# MyBike - Motorbike Maintenance Tracker

A cross-platform (Android + iOS) Flutter app to track personal **motorbike**
maintenance: services, wearing components, reminders, and fuel economy.

The MVP is **offline-first**: all data is stored on-device (Hive) so the app is
fully usable with no account and no internet. The data layer is abstracted
behind repositories so a cloud backend (Firebase) can be dropped in later for
sync and multi-device backup (see [Roadmap](#roadmap)).

## Features (MVP)

- Multi-bike garage with make/model/year, type, registration and odometer
- Maintenance items (engine oil, oil filter, air filter, chain & sprocket,
  tires, brake pads/fluid, coolant, spark plug, battery, valve clearance, etc.)
  with sensible default service intervals
- Wear/health bars and prioritized **reminders** driven by distance *or* time
  ("whichever comes first")
- Service history log with cost and notes; logging a service auto-resets the
  linked item's reminder
- Fuel log with automatic fuel-economy calculation (km/L, L/100km, or mpg)
- Local notifications for upcoming time-based services
- km / miles units, currency symbol, light & dark Material 3 theme

## Tech stack

- **Flutter** (Dart) - one codebase for Android + iOS
- **Riverpod** - state management
- **go_router** - navigation
- **Hive** - local offline-first storage
- **flutter_local_notifications** + **timezone** - reminders
- **fl_chart**, **intl**, **uuid**

## Project structure

```
lib/
  main.dart                 # bootstraps Hive + notifications, runs the app
  app/                      # MaterialApp, theme, router
  core/                     # units conversion, formatters
  data/
    models/                 # Bike, MaintenanceItem, ServiceRecord, FuelEntry, enums
    repositories/           # Hive-backed CRUD repositories
    local_store.dart        # Hive init + box names
  providers/                # Riverpod providers + settings
  services/                 # reminder calculation + notifications
  features/
    home/                   # garage, reminders tabs + bottom-nav shell
    bikes/                  # bike form + detail (Components/History/Fuel tabs)
    maintenance_items/      # add/edit maintenance item
    service/                # log/edit a service
    fuel/                   # add/edit a fuel-up
    settings/               # units, rider, currency
  widgets/                  # shared UI (wear indicator, status chip, empty state)
```

## Getting started

This repo includes the Flutter SDK requirement only; you need Flutter installed.

### Prerequisites

- Flutter SDK (3.44+). If it's at `C:\flutter`, add `C:\flutter\bin` to PATH.
- For Android builds: Android Studio (or the Android command-line tools) with an
  Android SDK + a JDK, then run `flutter doctor --android-licenses`.
- For iOS builds: a macOS machine with Xcode (iOS cannot be built on Windows).

### Install dependencies

```bash
flutter pub get
```

### Run

```bash
# Web (quickest preview, works on Windows today)
flutter run -d chrome

# Android device/emulator (after Android SDK is set up)
flutter run -d <device-id>     # list devices with: flutter devices
```

### Build

```bash
flutter build apk            # Android APK
flutter build appbundle      # Android App Bundle (Play Store)
flutter build web            # Web
```

## Roadmap

Planned fast-follows, in priority order:

1. **Cloud sync + accounts (Firebase)** - add `firebase_core`, `firebase_auth`
   (email + Google), `cloud_firestore` (offline persistence on),
   `firebase_storage`. Run `flutterfire configure` (requires your Firebase
   account) to generate `firebase_options.dart` and the platform config files,
   then add a Firestore-backed implementation of the existing repositories.
2. **Photo attachments** - `image_picker` + compression for bikes, components
   and service receipts (stored in Storage, URLs in the DB).
3. **Push notifications** - FCM for cross-device reminders.
4. **Charts & export** - cost over time, wear trends, CSV/PDF export.
5. **Store launch** - icons/splash, Play Console data-safety form, App Store
   privacy labels, CI/CD (GitHub Actions + Fastlane).

## Notes

- iOS notification + Firebase setup requires macOS; build those targets on a Mac
  or in CI.

## UAT changes

Remediation work tracked against `Zvandi_UAT_Plan.md`, committed incrementally on the `UAT` branch.

### Phase 1 — Navigation hygiene
- Reminders bell now switches tabs through a shared `homeTabIndexProvider`
  instead of local widget state, so notification taps / deep links can drive
  it later.
- Removed the dead in-place `_LocalAddFuelDialog` (~250 lines) from
  `bike_detail_screen.dart`. The Fuel tab's FAB and log rows now route
  through `go_router` to `FuelFormScreen` (`/bike/{id}/fuel/new` and
  `/bike/{id}/fuel/{fuelId}`), so there's one implementation of "add/edit
  fuel entry" and it's deep-linkable.
- Removed the two non-functional "Export Diagnostic Telemetry" and
  "Encryption & Keys" rows from Settings — they only showed a snackbar and
  did nothing real. Re-add once there's an actual implementation behind them.

### Phase 2 — Currency + trivial statics
- Swept hardcoded `$` cost displays to `formatCost()` / `₹` in the Fuel tab
  and the service-cost field label.
- Removed fabricated fallback values that were never derived from real data:
  the "850 km" next-service placeholder in Garage now reads "—" when there
  isn't enough reminder data; the "42.5 Km/L" fuel-economy placeholder now
  reads "—" (with a hint) until 2+ fuel-ups exist; the "Shell Station"
  default fuel-log location is gone, falling back to "—".
- Dropped the "Rossi" rider-name fallback (onboarding requires a real name
  before this screen is reachable) and the fabricated "Pro Telemetry User"
  label in Settings.

### Phase 3 — Home screen live data
- Greeting now reflects the actual time of day instead of always reading
  "Good Morning" (`greetingForHour` in `core/formatters.dart`).
- Smart Insights: the "Wear Alert" card names the real worst-scoring
  component (from `bikeComponentScoresProvider`) and its real remaining
  distance/days, and is hidden once every component is ≥ 80%. The
  "Efficiency" card shows a real this-month-vs-last-month fuel-economy
  delta from `fuelEconomyTrendProvider` (new,
  `lib/providers/home_insights_provider.dart`), derived from consecutive
  fuel-up odometer deltas; hidden until both months have data.
- Upcoming Expenses now lists the real soonest-due items with an estimated
  cost from `upcomingExpensesProvider` — the median historical
  `ServiceRecord.cost` for that service type (this bike's own history
  first, falling back to all bikes), shown in ₹. Items without any cost
  history show "—" instead of a fabricated number, and the total is
  labelled "partial" when some items are missing an estimate.
- Recent Activity now merges real `ServiceRecord` + `FuelEntry` events
  (`recentActivityProvider`), most recent first, instead of a scripted
  ride/diagnostic-scan timeline — this app has no trip-tracking or
  diagnostic-scan data source.

### Phase 4 — Fuel tab real chart
- Replaced `_SparklineChart`/`_SparklinePainter` (5 invented points) with a
  real `fl_chart` `LineChart` (`_EfficiencyTrendChart`) bound to per-fill-up
  km/L (or mpg) values derived from consecutive fuel-up odometer deltas.
  Shows an honest "log a few more fuel-ups" empty state below 2 data
  points instead of a fabricated curve.
- Dropped the "Target Peak (+4%)" label entirely (per user decision) —
  replaced the Initial-Run/Target/Now row with real First/Latest economy
  values from the same series.

### Phase 5 — Settings toggles wired
- `NotificationService.syncReminders` now actually honours the "Critical
  Alerts" / "Maintenance Reminders" toggles (previously saved to Hive but
  never read) — overdue items are gated by Critical Alerts, everything
  else by Maintenance Reminders. Toggling either resyncs notifications
  immediately.
- Removed the "Security & Movement" toggle (per user decision) — no
  GPS/telemetry hardware feature exists or is planned to back it.

### Phase 6 — Regression pass
- Updated `test/fuel_tracker_ui_test.dart`, `test/home_tab_ui_test.dart`,
  `test/home_screen_navigation_test.dart` and `test/settings_tab_ui_test.dart`
  for the UI/behavior changes above (removed dialog → real routing,
  fabricated strings → honest empty states, dropped Administrative/Security
  rows).
- Verified against the real toolchain (Flutter 3.44.0 / Dart 3.12.0):
  - `flutter analyze` — no errors in `lib/`.
  - `flutter build apk --release` — succeeds (fat APK ~58.6 MB; split
    per-ABI arm64-v8a ~22 MB).
  - `flutter test` — **13 passed / 12 failed on `UAT`**, versus
    **10 passed / 14 failed on `main`**. The improvement comes from fixing
    `test/bike_health_test_helpers.dart`, which was missing two required
    `MaintenanceItem` arguments on `main` and stopped the suite compiling.
- **Known pre-existing gap (not introduced here):** all 12 remaining
  failures are `HiveError: Box not found`. The widget tests never
  initialize Hive, so any test rendering a widget that reads
  `bikesProvider`/`settingsProvider` crashes — including screens this plan
  never touched (`learn_tab`, `garage_tab`, `service_form_screen`,
  `sign_in_screen`). Fix needs a `test/flutter_test_config.dart` (or
  `setUpAll`) that runs `Hive.init(<temp dir>)` and opens the boxes from
  `LocalStore` before the suite. Tracked as follow-up.

## Building an installable APK

No `android/key.properties` exists, so `android/app/build.gradle.kts`
falls back to the **debug** signing config. The resulting APK sideloads
fine but cannot be published to Play, and a later real-keystore build will
require uninstalling first (signature mismatch).

```
flutter build apk --release                  # single fat APK, all ABIs
flutter build apk --release --split-per-abi  # smaller per-architecture APKs
```

Output lands in `build/app/outputs/flutter-apk/`.

**Google Sign-In caveat:** `android/app/google-services.json` currently
contains only a web OAuth client (`client_type: 3`) and no Android client
with a signing-certificate hash, so Google Sign-In will fail on a
sideloaded build. To fix, register the signing certificate's SHA-1 against
`com.mybike.mybike` in the Firebase console and re-download
`google-services.json`. Email/password sign-in does not depend on SHA-1
and works as-is.
