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
