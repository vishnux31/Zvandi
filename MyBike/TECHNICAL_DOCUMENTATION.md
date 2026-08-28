# MyBike — Technical Documentation

**Version:** 1.0.0+1  
**Package:** `com.mybike.mybike`  
**Last updated:** June 2026  
**Audience:** Engineers, QA, product, and technical stakeholders

---

## Table of Contents

1. [Product Overview](#1-product-overview)
2. [Technology Stack](#2-technology-stack)
3. [System Architecture](#3-system-architecture)
4. [Application Bootstrap Flow](#4-application-bootstrap-flow)
5. [Navigation & Routing](#5-navigation--routing)
6. [End-to-End User Flows](#6-end-to-end-user-flows)
7. [Screen Wireframes & UI Inventory](#7-screen-wireframes--ui-inventory)
8. [Buttons, Actions & Side Effects](#8-buttons-actions--side-effects)
9. [Data Layer](#9-data-layer)
10. [State Management](#10-state-management)
11. [Business Logic](#11-business-logic)
12. [Backend & Cloud Sync](#12-backend--cloud-sync)
13. [Notifications](#13-notifications)
14. [External Integrations](#14-external-integrations)
15. [Design System & Theming](#15-design-system--theming)
16. [Security Model](#16-security-model)
17. [Design Decisions & Rationale](#17-design-decisions--rationale)
18. [Known Gaps & Future Work](#18-known-gaps--future-work)
19. [Build & Deployment](#19-build--deployment)
20. [File Map](#20-file-map)

---

## 1. Product Overview

**MyBike** is a cross-platform Flutter application for tracking motorbike maintenance. It targets Indian riders and combines:

- **Personal maintenance tracking** — recurring items (oil, chain, tires, etc.) with distance and/or time intervals
- **OEM maintenance schedules** — reference data from official owner manuals for Indian bike brands/models
- **Service history** — logged repairs with cost, odometer, and notes
- **Fuel economy** — fill-up logs with km/L or mpg calculation
- **Cloud sync** — Firebase Auth + Firestore for multi-device backup
- **Local notifications** — scheduled reminders for time-based due dates

The app is **auth-gated**: users must sign in before accessing any feature. There is no guest/offline-only mode.

---

## 2. Technology Stack

| Layer | Technology | Version (pubspec) | Purpose |
|-------|------------|-------------------|---------|
| Language | Dart | SDK ^3.12.0 | Application logic |
| UI Framework | Flutter | SDK | Cross-platform UI (Android, iOS, Web) |
| UI Kit | Material 3 | — | Components, theming |
| State | flutter_riverpod | ^2.6.1 | DI, reactive state |
| Routing | go_router | ^14.6.2 | Declarative navigation + auth guards |
| Local DB | Hive / hive_flutter | ^2.2.3 / ^1.1.0 | Offline-first JSON-in-box storage |
| Auth | firebase_auth | ^6.5.1 | Email/password + Google |
| Cloud DB | cloud_firestore | ^6.4.1 | User data sync |
| Google OAuth | google_sign_in | ^7.2.0 | Android Google sign-in |
| Notifications | flutter_local_notifications | ^18.0.1 | Local maintenance alerts |
| Timezone | timezone | ^0.10.0 | Notification scheduling |
| IDs | uuid | ^4.5.1 | Entity primary keys |
| Formatting | intl | ^0.20.2 | Dates, numbers |
| Charts | fl_chart | ^0.69.2 | **Declared, not used** |
| Prefs | shared_preferences | ^2.3.3 | **Declared, not used** |

**Platforms:** Android (Gradle Kotlin DSL), iOS (Xcode), Web (PWA manifest)

**Firebase project:** `mybike-865b8`

---

## 3. System Architecture

### 3.1 Layer Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  UI Layer (features/ + widgets/)                            │
│  Screens, tabs, dialogs, FABs, forms                        │
└──────────────────────────┬──────────────────────────────────┘
                           │ watch / read / listen
┌──────────────────────────▼──────────────────────────────────┐
│  Provider Layer (providers/)                                │
│  StateNotifiers, computed Providers, FutureProviders        │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│  Service Layer (services/)                                  │
│  Auth, CloudSync, Reminders, Notifications, PIN lookup      │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│  Repository Layer (data/repositories/)                        │
│  BaseRepository<T> → Hive CRUD                              │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│  Local Store (Hive boxes)  ←──sync──→  Firestore            │
│  Offline-first source of truth for UI                       │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Architectural Patterns

| Pattern | Implementation | Reason |
|---------|----------------|--------|
| Feature-first folders | `lib/features/{auth,home,bikes,...}` | Co-locate screens with domain |
| Repository pattern | `BaseRepository<T>` + concrete repos | Abstract storage; Hive today, swappable |
| Offline-first | Hive writes are synchronous; Firestore is async mirror | App works without network latency on reads |
| Unidirectional flow | UI → Notifier → Repository → Hive → (async) Firestore | Predictable data mutations |
| Computed view models | `ReminderInfo` derived from items + bikes | Single source for wear/status UI |
| Manual JSON serialization | `toMap()` / `fromMap()` on models | Portable to Firestore without codegen |
| Auth-gated routing | `go_router` redirect on `authStateChanges()` | Protect all routes |

### 3.3 Directory Structure

```
lib/
├── main.dart                    # Bootstrap
├── firebase_options.dart        # FlutterFire config
├── app/
│   ├── app.dart                 # MaterialApp.router + sync listener
│   ├── router.dart              # All routes + auth redirect
│   └── theme.dart               # Material 3 theme
├── core/
│   ├── formatters.dart          # Dates, currency (₹), Indian digits
│   ├── input_formatters.dart    # Indian digit grouping on input
│   └── units.dart               # km ↔ mi conversion
├── data/
│   ├── local_store.dart         # Hive init + box names
│   ├── models/                  # Domain entities
│   └── repositories/            # CRUD layer
├── providers/
│   ├── app_providers.dart       # Entity StateNotifiers
│   ├── settings_provider.dart   # Rider profile + units
│   ├── catalog_provider.dart    # Brand/model catalog
│   └── maintenance_schedule_provider.dart
├── services/
│   ├── auth_service.dart
│   ├── cloud_sync_service.dart
│   ├── reminder_service.dart
│   ├── notification_service.dart
│   ├── rider_profile_service.dart
│   └── pincode_service.dart
├── features/                    # One folder per feature/screen group
└── widgets/                     # Shared UI components
```

---

## 4. Application Bootstrap Flow

```
App Launch
    │
    ▼
WidgetsFlutterBinding.ensureInitialized()
    │
    ▼
Firebase.initializeApp(firebase_options)
    │
    ▼
Firestore persistence enabled
    │
    ▼
LocalStore.init()          → Open Hive boxes
    │
    ▼
NotificationService.init() → Platform notification channel (skipped on Web)
    │
    ▼
runApp(ProviderScope → MyBikeApp)
    │
    ▼
MaterialApp.router
    │
    ├── ref.listen(authStateProvider)
    │       signed in  → cloudSyncService.start(uid)
    │       signed out → cloudSyncService.stop()
    │
    └── GoRouter redirect
            not logged in → /signin
            logged in at /signin → /
```

**Entry file:** `lib/main.dart`  
**App shell:** `lib/app/app.dart`  
**Router:** `lib/app/router.dart`

---

## 5. Navigation & Routing

### 5.1 Route Table

| Route | Screen | Parameters | Purpose |
|-------|--------|------------|---------|
| `/signin` | `SignInScreen` | — | Authentication |
| `/` | `HomeScreen` | — | Bottom-nav shell (3 tabs) |
| `/bike/new` | `BikeFormScreen` | — | Add bike |
| `/bike/:id` | `BikeDetailScreen` | `id` | Bike detail (3 tabs) |
| `/bike/:id/edit` | `BikeFormScreen` | `id` | Edit bike |
| `/bike/:id/item/new` | `ItemFormScreen` | `id` | Add maintenance item |
| `/bike/:id/item/:itemId` | `ItemFormScreen` | `id`, `itemId` | Edit maintenance item |
| `/bike/:id/service/new` | `ServiceFormScreen` | `id`, `?itemId` | Log service |
| `/bike/:id/service/:recordId` | `ServiceFormScreen` | `id`, `recordId` | Edit service |
| `/bike/:id/fuel/new` | `FuelFormScreen` | `id` | Add fuel entry |
| `/bike/:id/fuel/:fuelId` | `FuelFormScreen` | `id`, `fuelId` | Edit fuel entry |

### 5.2 Auth Guard Logic

```dart
// router.dart
if (!loggedIn) return atSignIn ? null : '/signin';
if (atSignIn) return '/';
return null;
```

`GoRouterRefreshStream` listens to `FirebaseAuth.instance.authStateChanges()` and triggers redirect re-evaluation on every auth state change.

### 5.3 Non-Routed UI (Overlays / Conditional Screens)

| UI | Trigger | Type |
|----|---------|------|
| `RiderOnboardingScreen` | `riderProfileCompleteProvider == false` | Full-screen replacement of HomeScreen |
| `_RiderEditDialog` | Settings → Edit | Modal dialog |
| Odometer update dialog | Bike detail → tap odometer | AlertDialog |
| Sign-out confirmation | Settings → Sign out | AlertDialog |
| Date pickers | Various forms | `showDatePicker` |

### 5.4 Navigation Map (ASCII)

```
/signin
    │ (auth success)
    ▼
/  ─────────────────────────────────────────────
    │ HomeScreen (IndexedStack)
    │
    ├── Tab 0: GarageTab
    │       ├── Empty → /bike/new
    │       ├── MaintenanceDashboard
    │       │       └── tap header → /bike/:id
    │       └── FAB → /bike/new
    │
    ├── Tab 1: RemindersTab
    │       └── tap card → /bike/:id/service/new?itemId=...
    │
    └── Tab 2: SettingsTab
            ├── Edit profile → dialog
            └── Sign out → /signin

/bike/:id  ────────────────────────────────────
    ├── Edit (app bar) → /bike/:id/edit
    ├── Tab: Components
    │       ├── FAB → /bike/:id/item/new
    │       ├── ⋮ menu → edit / log / delete
    │       └── Done dropdown → quick service log
    ├── Tab: History
    │       ├── FAB → /bike/:id/service/new
    │       └── tap row → /bike/:id/service/:recordId
    └── Tab: Fuel
            ├── FAB → /bike/:id/fuel/new
            └── tap row → /bike/:id/fuel/:fuelId
```

---

## 6. End-to-End User Flows

### 6.1 First Launch (New User)

```
1. Open app
2. Redirected to /signin
3. User signs in (email or Google) OR creates account
4. Router redirects to /
5. HomeScreen loads rider profile from Firestore
6. If name/gender/DOB missing → RiderOnboardingScreen (cannot back out)
7. User fills onboarding → saveRiderBasics() → Firestore + local
8. HomeScreen shows Garage tab
9. Cloud sync starts (push local Hive → Firestore, attach listeners)
10. Notification permissions requested
```

### 6.2 Add First Bike

```
1. Garage tab shows EmptyState
2. Tap "Add your first bike" → /bike/new
3. Fill nickname (required), make, model, year, type, odometer
4. Save → bikesProvider.save() → Hive + Firestore push
5. Pop back to Garage
6. garageSelectedBikeIdProvider auto-selects first bike
7. MaintenanceDashboard loads OEM schedule for make/model
```

### 6.3 Track Maintenance Item

```
1. Open bike detail → Components tab
2. FAB "Add item" → /bike/:id/item/new
3. Select type (pre-fills name + default intervals)
4. Set distance and/or time interval
5. Set last service odometer + date
6. Save → itemsProvider.save()
7. remindersForBikeProvider recomputes
8. WearIndicator + StatusChip update
9. If time-based due date exists → NotificationService schedules alert
```

### 6.4 Log Service (Reset Reminder)

```
1. From Reminders tab OR Components tab OR History FAB
2. Navigate to /bike/:id/service/new(?itemId=...)
3. Optionally link to maintenance item
4. Enter date, odometer, cost, notes
5. Save:
   a. recordsProvider.save(record)
   b. If linked item → update lastServiceOdometerKm + lastServiceDate
   c. If odometer > bike.odometerKm → update bike odometer
6. Reminder usage resets; notifications re-synced
```

### 6.5 Quick "Mark Done" (Components Tab)

```
1. User selects "Done" in _ComponentStatusDropdown
2. _markItemDone():
   a. Create ServiceRecord (type, date=now, odometer=bike.odometerKm)
   b. Update item lastServiceDate + lastServiceOdometerKm
3. SnackBar: "{name} logged and reset"
4. Dropdown resets to "To do" (local UI state only)
```

### 6.6 Sign Out

```
1. Settings → Sign out
2. Confirm dialog
3. authService.signOut()
4. cloudSyncService.stop() (keeps local data by default on sign-out in app.dart)
5. Router redirects to /signin
```

---

## 7. Screen Wireframes & UI Inventory

Wireframes use ASCII layout notation. `[Btn]` = button, `[___]` = input, `(chip)` = badge/chip.

---

### 7.1 SignInScreen (`/signin`)

**File:** `lib/features/auth/sign_in_screen.dart`  
**Purpose:** Gate all app access behind Firebase Auth.

```
┌─────────────────────────────────────┐
│                                     │
│            🏍 (72px icon)           │
│              MyBike                 │
│   Track your motorbike maintenance  │
│                                     │
│  [___ Email ___________________]    │
│  [___ Password _________________]    │
│              [Forgot password?]     │  ← hidden in register mode
│                                     │
│  ┌─ error container (if error) ─┐  │
│  └───────────────────────────────┘  │
│                                     │
│  [    Sign in / Create account   ]  │  FilledButton
│  [  🔑 Continue with Google      ]  │  OutlinedButton
│                                     │
│  Don't have an account? Create one  │  TextButton (toggles mode)
│                                     │
└─────────────────────────────────────┘
```

| Element | Type | Behavior |
|---------|------|----------|
| Email field | TextFormField | Required, must contain `@` |
| Password field | TextFormField | Min 6 chars |
| Forgot password? | TextButton | Sends reset email; requires email filled |
| Sign in / Create account | FilledButton | Toggles via `_isRegister` flag |
| Continue with Google | OutlinedButton | Web: popup; Android: Google Sign-In |
| Mode toggle | TextButton | Switches sign-in ↔ register |

**Post-action:** Router auto-redirects to `/` on auth success. No manual navigation.

---

### 7.2 RiderOnboardingScreen (conditional, not routed)

**File:** `lib/features/auth/rider_onboarding_screen.dart`  
**Purpose:** Collect mandatory rider profile before main app.  
**Back navigation:** Blocked (`PopScope(canPop: false)`).

```
┌─────────────────────────────────────┐
│            🏍 (56px)                │
│       Welcome to MyBike             │
│  Tell us a bit about yourself...    │
│                                     │
│  [___ Rider name * _____________]   │
│                                     │
│  Gender *                           │
│  [ Male | Female ]                  │  SegmentedButton
│                                     │
│  [ Date of birth *  📅 ]           │  Tap → date picker
│                                     │
│  [         Continue              ]  │  FilledButton
└─────────────────────────────────────┘
```

| Validation | Rule |
|------------|------|
| Name | Required, 2+ chars, letters/spaces/`.'-` only |
| Gender | Required (Male or Female) |
| DOB | Required, age 16–100, not in future |

---

### 7.3 HomeScreen (`/`)

**File:** `lib/features/home/home_screen.dart`  
**Purpose:** Shell with bottom navigation. Preserves tab state via `IndexedStack`.

```
┌─────────────────────────────────────┐
│  (active tab content)               │
│                                     │
│                                     │
├─────────────────────────────────────┤
│  [Garage]  [Reminders (badge)]  [Settings] │
└─────────────────────────────────────┘
```

| Tab | Index | Icon | Badge |
|-----|-------|------|-------|
| Garage | 0 | `garage` / `garage_outlined` | — |
| Reminders | 1 | `notifications` | Count of active reminders (soon/due/overdue) |
| Settings | 2 | `settings` | — |

**Loading states:**
- Auth loading OR profile loading → full-screen `CircularProgressIndicator`
- Profile incomplete → `RiderOnboardingScreen` replaces entire scaffold

**Side effects on init:**
- `NotificationService.requestPermissions()`
- `NotificationService.syncReminders(remindersProvider)`
- `ref.listen(remindersProvider)` keeps notifications in sync

---

### 7.4 GarageTab (Home Tab 0)

**File:** `lib/features/home/garage_tab.dart`

#### Empty State (no bikes)

```
┌─────────────────────────────────────┐
│ AppBar: My Garage                   │
├─────────────────────────────────────┤
│                                     │
│         🏍 (empty icon)             │
│         No bikes yet                │
│   Add your motorbike to see its     │
│   official maintenance schedule.    │
│                                     │
│  [ + Add your first bike ]          │
│                                     │
└─────────────────────────────────────┘
```

#### With Bikes

```
┌─────────────────────────────────────┐
│ AppBar: My Garage                   │
│         Welcome back, {name}        │
│                    [Bike ▼ selector]│
├─────────────────────────────────────┤
│  MaintenanceDashboard (scroll)      │
│                                     │
│                              [+ Add bike] FAB
└─────────────────────────────────────┘
```

**Bike selector (`_BikeSelector`):** `PopupMenuButton` in app bar. Shows checkmark on selected bike. Updates `garageSelectedBikeIdProvider`.

---

### 7.5 MaintenanceDashboard (embedded in GarageTab)

**File:** `lib/features/home/maintenance_dashboard.dart`  
**Purpose:** Display OEM maintenance schedule for selected bike's make/model.

```
┌─────────────────────────────────────┐
│ ⚠ N tracked items need attention    │  _OverdueBanner (if overdue > 0)
├─────────────────────────────────────┤
│ ┌ Bike Header Card (tappable) ────┐ │
│ │ 🏍 Name / Make Model        >   │ │
│ │ (EV) (350cc) (liquid) (chain)   │ │  spec chips
│ │ 🏁 12,450 km        Brand name  │ │
│ └─────────────────────────────────┘ │
├─────────────────────────────────────┤
│ [Total tasks] [High priority] [Cats]│  _StatsRow
├─────────────────────────────────────┤
│ Note from brand                     │  _NotesCard
│ {OEM notes text}                    │
├─────────────────────────────────────┤
│ [🔍 Search tasks…] [All categories ▼]│  _FilterBar
├─────────────────────────────────────┤
│ ┌ Task tile ──────────────────────┐ │
│ │ 🔧 Task name          [Priority]│ │
│ │    ⏱ interval text    [Category]│ │
│ └─────────────────────────────────┘ │
│ ... more tasks ...                  │
├─────────────────────────────────────┤
│ Disclaimer (owner manual source)    │
└─────────────────────────────────────┘
```

**No-schedule fallback (`_NoScheduleCard`):** Shown when make/model not found in `india_bike_maintenance.json`. Offers `[Open bike details]` button.

**Data source priority:**
1. Bundled asset `assets/data/india_bike_maintenance.json`
2. Brand/model match via `bikeMaintenanceProfileProvider`

**Filter logic:** Search matches task name or interval text. Category dropdown filters by `MaintenanceCategory`.

---

### 7.6 RemindersTab (Home Tab 1)

**File:** `lib/features/home/reminders_tab.dart`

```
┌─────────────────────────────────────┐
│ AppBar: Reminders                   │
├─────────────────────────────────────┤
│ ┌ Reminder Card (tappable) ───────┐ │
│ │ 🔧 Item name          (Due soon)│ │
│ │    Bike name                    │ │
│ │ ████████░░░░ Wear bar           │ │
│ │ 500 km left  •  in 12 days      │ │
│ └─────────────────────────────────┘ │
│ ... sorted by urgency (usage desc)  │
└─────────────────────────────────────┘
```

**Empty state:** Icon + "No reminders" + helper text.

**Card tap:** Navigates to `/bike/:id/service/new?itemId=:itemId` to log service for that item.

---

### 7.7 SettingsTab (Home Tab 2)

**File:** `lib/features/settings/settings_tab.dart`

```
┌─────────────────────────────────────┐
│ AppBar: Settings                    │
├─────────────────────────────────────┤
│ ACCOUNT                             │
│ 👤 user@email.com                   │
│    Synced to the cloud              │
├─────────────────────────────────────┤
│ RIDER                    [✏ Edit]   │
│ ┌ Card ───────────────────────────┐ │
│ │ Rider name    Rahul Sharma      │ │
│ │ Gender        Male              │ │
│ │ Date of birth 15 Jan 1995       │ │
│ │ Phone number  Not set           │ │
│ │ Profession    Not set           │ │
│ │ PIN code      Not set           │ │
│ │ State         Not set           │ │
│ │ City          Not set           │ │
│ └─────────────────────────────────┘ │
├─────────────────────────────────────┤
│ UNITS                               │
│ Distance unit    [ km | mi ]        │  SegmentedButton
├─────────────────────────────────────┤
│ ABOUT                               │
│ MyBike • v1.0.0                     │
├─────────────────────────────────────┤
│ 🚪 Sign out (red)                   │
└─────────────────────────────────────┘
```

#### Rider Edit Dialog (`_RiderEditDialog`)

```
┌─────────────────────────────────────┐
│ Edit rider profile            [✕]   │
├─────────────────────────────────────┤
│ [___ Rider name * ___]              │
│ Gender: [ Male | Female ]           │
│ [ Date of birth  📅 ]               │
│ [___ Phone (10 digits) ___]         │
│ [___ Profession ___]                │
│ [___ PIN code ___] [Verify]         │
│ State: (auto-filled after verify)   │
│ City:  (auto-filled after verify)   │
├─────────────────────────────────────┤
│ [ Discard ]        [ Save ]         │
└─────────────────────────────────────┘
```

---

### 7.8 BikeDetailScreen (`/bike/:id`)

**File:** `lib/features/bikes/bike_detail_screen.dart`

```
┌─────────────────────────────────────┐
│ ←                          [Edit]   │  SliverAppBar (pinned, 220px)
│ ┌ gradient header ────────────────┐ │
│ │ 🏍                               │ │
│ │ Bike Nickname                    │ │
│ │ Make Model Year                  │ │
│ │ 🏁 12,450 km ✏ (tappable)       │ │
│ └─────────────────────────────────┘ │
│ [ Components | History | Fuel ]     │  TabBar
├─────────────────────────────────────┤
│ (tab content)                       │
│                                     │
│                         [context FAB]│
└─────────────────────────────────────┘
```

**Context-sensitive FAB:**

| Tab | FAB Label | Route |
|-----|-----------|-------|
| Components (0) | Add item | `/bike/:id/item/new` |
| History (1) | Log service | `/bike/:id/service/new` |
| Fuel (2) | Add fuel | `/bike/:id/fuel/new` |

#### Components Tab

Each card shows:
- Service type icon + name
- `_ComponentStatusDropdown` (To do / Done)
- `⋮` popup menu: Log service, Edit, Delete
- `WearIndicator` progress bar
- Subtitle: distance remaining + relative days

#### History Tab

- List of `ServiceRecord` cards (newest first implied by provider order)
- Tap row → edit service
- Shows type, date, odometer, cost (₹)

#### Fuel Tab

- **Average economy card** at top (requires 2+ full-tank entries)
- Fuel entry list: liters, date, odometer, cost
- Full-tank icon vs partial fill icon

---

### 7.9 BikeFormScreen (`/bike/new`, `/bike/:id/edit`)

**File:** `lib/features/bikes/bike_form_screen.dart`

| Field | Required | Notes |
|-------|----------|-------|
| Nickname | Yes | Free text |
| Make | No | Searchable `DropdownMenu<Brand>` from catalog |
| Model | No | Enabled after brand; `DropdownMenu<BikeModel>` |
| Year | No | 1980–current |
| Year of purchase | No | Must be ≥ model year |
| Type | No | Default: Commuter |
| Reg. number | No | Uppercase |
| Current odometer | No | Indian digit grouping; stored as km |

**Save button:** `FilledButton` — creates UUID for new bike or updates existing.

**Catalog resolution:** Legacy bikes without `brandId` get brand matched by name on first catalog load.

---

### 7.10 ItemFormScreen (`/bike/:id/item/...`)

**File:** `lib/features/maintenance_items/item_form_screen.dart`

| Field | Required | Notes |
|-------|----------|-------|
| Type | No | 16 `ServiceType` values; changes pre-fill defaults |
| Name | Yes | Auto-filled from type label on new items |
| Every (km/mi) | One of two | Distance interval |
| Every (months) | One of two | Time interval |
| Last serviced at | No | Defaults to bike odometer |
| Last serviced on | No | Date picker; default today |
| Notes | No | Multi-line |

**Validation:** At least one interval (distance OR time) required.

---

### 7.11 ServiceFormScreen (`/bike/:id/service/...`)

**File:** `lib/features/service/service_form_screen.dart`

| Field | Required | Notes |
|-------|----------|-------|
| Linked maintenance item | No | Resets that item's reminder on save |
| Service type | No | Auto-set from linked item |
| Date | No | Date picker |
| Odometer | Yes | May bump bike odometer if higher |
| Cost | No | ₹ prefix |
| Notes | No | Workshop, parts, etc. |

**Query param `?itemId=`:** Pre-selects linked item (used from Reminders tab tap).

---

### 7.12 FuelFormScreen (`/bike/:id/fuel/...`)

**File:** `lib/features/fuel/fuel_form_screen.dart`

| Field | Required | Notes |
|-------|----------|-------|
| Date | No | Date picker |
| Odometer | Yes | May bump bike odometer |
| Litres | Yes | Must be > 0 |
| Cost | No | ₹ prefix |
| Filled tank completely | No | Switch; default ON; needed for economy |
| Notes | No | — |

---

## 8. Buttons, Actions & Side Effects

### 8.1 Master Action Table

| Location | Control | Action | Data Effect | Navigation |
|----------|---------|--------|-------------|------------|
| SignIn | Sign in | `auth.signInWithEmail` | Firebase session | Auto → `/` |
| SignIn | Create account | `auth.registerWithEmail` | Firebase session | Auto → `/` |
| SignIn | Google | `auth.signInWithGoogle` | Firebase session | Auto → `/` |
| SignIn | Forgot password | `auth.sendPasswordReset` | Email sent | SnackBar |
| Onboarding | Continue | `saveRiderBasics` | Firestore profile | → HomeScreen |
| Garage | Add bike (empty/FAB) | — | — | → `/bike/new` |
| Garage | Bike selector | Set `garageSelectedBikeIdProvider` | UI state only | — |
| Dashboard | Header card tap | — | — | → `/bike/:id` |
| Dashboard | Open bike details | — | — | → `/bike/:id` |
| Reminders | Card tap | — | — | → `/bike/:id/service/new?itemId=` |
| Settings | Edit | Open dialog | — | Modal |
| Settings | km/mi toggle | `setDistanceUnit` | Hive settings | UI refresh |
| Settings | Sign out | `auth.signOut` | Stop sync | → `/signin` |
| Rider dialog | Verify PIN | `PincodeService.lookup` | State/city fill | — |
| Rider dialog | Save | `saveRiderProfile` | Firestore + Hive | Close dialog |
| Rider dialog | Discard | — | — | Close dialog |
| Bike detail | Edit (app bar) | — | — | → `/bike/:id/edit` |
| Bike detail | Odometer tap | Dialog → save bike | `bikesProvider.save` | — |
| Bike detail | FAB (tab 0) | — | — | → item/new |
| Bike detail | FAB (tab 1) | — | — | → service/new |
| Bike detail | FAB (tab 2) | — | — | → fuel/new |
| Components | Done dropdown | `_markItemDone` | Record + item update | SnackBar |
| Components | ⋮ Log service | — | — | → service/new?itemId |
| Components | ⋮ Edit | — | — | → item/:itemId |
| Components | ⋮ Delete | `itemsProvider.remove` | Hive + Firestore delete | — |
| History | Row tap | — | — | → service/:recordId |
| Fuel | Row tap | — | — | → fuel/:fuelId |
| All forms | Save | Entity-specific save | Hive + Firestore push | `context.pop()` |

### 8.2 Save Pipeline (All Entities)

```
User taps Save
    → Form validation
    → StateNotifier.save(entity)
        → Repository.save() → Hive box.put(id, json)
        → cloudSyncService.push(collection, id, toMap())
    → Provider state updates
    → Dependent providers recompute (reminders, etc.)
    → ref.listen triggers notification sync
```

---

## 9. Data Layer

### 9.1 Hive Boxes

| Box constant | Storage key | Entity |
|--------------|-------------|--------|
| `Boxes.bikes` | `bikes` | `Bike` |
| `Boxes.items` | `maintenance_items` | `MaintenanceItem` |
| `Boxes.records` | `service_records` | `ServiceRecord` |
| `Boxes.fuel` | `fuel_entries` | `FuelEntry` |
| `Boxes.settings` | `settings` | Distance unit + legacy rider fields |
| `Boxes.catalog` | `catalog` | Cached brand/model lists |

**Format:** Each value is a JSON-encoded string of `toMap()` output.

### 9.2 Entity Schemas

#### Bike

| Field | Type | Notes |
|-------|------|-------|
| id | String (UUID) | Primary key |
| name | String | User nickname |
| make, model | String? | Display strings |
| brandId, modelId | String? | Catalog references |
| year | int? | Model year |
| yearOfPurchase | int? | Purchase year |
| type | BikeType | Enum |
| odometerKm | double | **Always stored in km** |
| registration | String? | Plate number |
| notes | String? | — |
| createdAt | DateTime | — |

**Computed:** `displayTitle` → "{make} {model} {year}"

#### MaintenanceItem

| Field | Type | Notes |
|-------|------|-------|
| intervalKm | double? | Distance interval (km) |
| intervalMonths | int? | Time interval |
| lastServiceOdometerKm | double | Baseline for wear calc |
| lastServiceDate | DateTime | Baseline for time calc |

**Computed properties:**
- `nextDueOdometerKm` = lastService + intervalKm
- `nextDueDate` = lastServiceDate + intervalMonths (calendar-aware)
- `usageFraction(odometer, now)` = max(distanceUsage, timeUsage)

#### ServiceRecord

| Field | Type | Notes |
|-------|------|-------|
| bikeId | String | FK |
| itemId | String? | Optional link to MaintenanceItem |
| type | ServiceType | — |
| date | DateTime | — |
| odometerKm | double | — |
| cost | double? | INR |
| notes | String? | — |

#### FuelEntry

| Field | Type | Notes |
|-------|------|-------|
| liters | double | — |
| fullTank | bool | Default true |
| cost | double? | INR |

#### RiderProfile (Firestore `users/{uid}/profile/rider`)

| Field | Type | Onboarding required |
|-------|------|---------------------|
| riderName | String | Yes |
| riderGender | RiderGender | Yes |
| riderDateOfBirth | DateTime | Yes |
| riderPhone | String? | No (Settings) |
| riderProfession | String? | No |
| riderPincode | String? | No |
| riderState, riderCity | String? | Auto from PIN API |

### 9.3 Enums Reference

**BikeType:** commuter, sport, cruiser, adventure, touring, offRoad, scooter, other

**ServiceType (16):** engineOil, oilFilter, airFilter, chainLube, chainSprocket, frontTire, rearTire, brakePadsFront, brakePadsRear, brakeFluid, coolant, sparkPlug, battery, valveClearance, generalService, other

Each `ServiceType` has `defaultIntervalKm`, `defaultIntervalMonths`, `label`, and `icon`.

**DistanceUnit:** km (internal canonical), mi (display conversion only)

**RiderGender:** male, female

### 9.4 Reference Data Assets

| Asset | Purpose |
|-------|---------|
| `assets/data/bike_catalog.json` | Offline brand/model catalog fallback |
| `assets/data/india_bike_maintenance.json` | OEM maintenance schedules for Indian bikes |

---

## 10. State Management

### 10.1 Provider Inventory

| Provider | Type | Responsibility |
|----------|------|----------------|
| `bikesProvider` | StateNotifier | CRUD bikes + cloud push |
| `itemsProvider` | StateNotifier | CRUD maintenance items |
| `recordsProvider` | StateNotifier | CRUD service records |
| `fuelProvider` | StateNotifier | CRUD fuel entries |
| `bikeByIdProvider` | family | Single bike lookup |
| `itemsForBikeProvider` | family | Items filtered by bikeId |
| `recordsForBikeProvider` | family | Records filtered by bikeId |
| `fuelForBikeProvider` | family | Fuel filtered by bikeId |
| `settingsProvider` | StateNotifier | Units + rider profile |
| `riderProfileCompleteProvider` | computed | name + gender + DOB present |
| `riderProfileLoadingProvider` | computed | Firestore profile fetch state |
| `remindersProvider` | computed | All ReminderInfo, sorted by usage |
| `remindersForBikeProvider` | family | Per-bike reminders |
| `activeRemindersProvider` | computed | Non-OK status only |
| `catalogProvider` | FutureProvider | Firestore → Hive → asset fallback |
| `brandsProvider` | computed | Brand list |
| `modelsForBrandProvider` | family | Models for brandId |
| `maintenanceScheduleDbProvider` | FutureProvider | Load JSON asset |
| `bikeMaintenanceProfileProvider` | computed | Match bike to OEM schedule |
| `garageSelectedBikeIdProvider` | StateProvider | Active bike in garage |
| `authStateProvider` | StreamProvider | Firebase User stream |
| `cloudSyncProvider` | Provider | Singleton sync service |

### 10.2 Side-Effect Listeners

| Listener location | Trigger | Effect |
|-------------------|---------|--------|
| `MyBikeApp` | authStateProvider | start/stop CloudSyncService |
| `HomeScreen` | remindersProvider | sync local notifications |
| `GarageTab` | bikesProvider | auto-select valid bike ID |

---

## 11. Business Logic

### 11.1 Reminder Status Calculation

**Source:** `lib/services/reminder_service.dart`

```
usage = item.usageFraction(bike.odometerKm, now)

if usage >= 1.0  → overdue
if usage >= 0.9  → due
if usage >= 0.75 → soon
else             → ok
```

**Usage formula** (`MaintenanceItem.usageFraction`):
- **Distance:** `(currentOdometer - lastServiceOdometer) / intervalKm`
- **Time:** `daysSinceLastService / totalDaysInInterval`
- **Result:** `max(distanceUsage, timeUsage)` — whichever is more urgent wins

**Sorting:** All reminder lists sorted by `usage` descending (most urgent first).

### 11.2 Wear Indicator Display

- Progress bar value = `usage.clamp(0.0, 1.0)` (caps visual at 100% even if overdue)
- Color mapping:

| Status | Color | Label |
|--------|-------|-------|
| OK | `#2E9E5B` green | OK |
| Soon | `#EFA800` amber | Due soon |
| Due | `#E6521F` orange (brand) | Due now |
| Overdue | `scheme.error` red | Overdue |

### 11.3 Fuel Economy Calculation

**Requires:** 2+ entries with `fullTank == true`, sorted by odometer ascending.

```
distance = lastFullTank.odometer - firstFullTank.odometer
liters   = sum of liters for full tanks (excluding first)
kmPerL   = distance / liters

Display (km mode):  "{kmPerL} km/L  •  {100/kmPerL} L/100km"
Display (mi mode):  "{mpg} mpg"  (converted)
```

### 11.4 Odometer Auto-Update

When saving a **service record** or **fuel entry**, if entered odometer > `bike.odometerKm`, the bike's odometer is automatically updated. This keeps wear calculations accurate without forcing a separate odometer update.

### 11.5 OEM Schedule Matching

`bikeMaintenanceProfileProvider` matches bike `make` + `model` (+ `brandId`/`modelId` when available) against `india_bike_maintenance.json`. Supports fuzzy/fallback matching with `exactModelMatch` flag shown in UI when schedule is from a similar model.

---

## 12. Backend & Cloud Sync

### 12.1 Firestore Structure

```
users/{uid}/
  ├── bikes/{id}
  ├── maintenance_items/{id}
  ├── service_records/{id}
  ├── fuel_entries/{id}
  └── profile/
      └── rider

brands/{id}     ← read-only, server-seeded
models/{id}     ← read-only, server-seeded
```

### 12.2 Sync Protocol

**On sign-in (`CloudSyncService.start`):**
1. Cancel existing listeners
2. Set `_uid`
3. `_pushAllLocal()` — batch upload all Hive boxes to Firestore
4. Attach `snapshots()` listeners per collection
5. On remote change → write to Hive → reload StateNotifier

**On local save (via StateNotifier):**
- Immediate Hive write (synchronous UI update)
- Async `cloudSyncService.push(collection, id, data)`

**On local delete:**
- Hive delete + `cloudSyncService.remove(collection, id)`

**On sign-out:**
- Cancel listeners
- Local data retained (`stop()` without `keepLocal: false` in current app.dart)

### 12.3 Design Rationale

Hive is the **synchronous source of truth** so the UI never waits on network. Firestore provides backup and multi-device sync. This matches the offline-first product goal while requiring auth for data ownership.

---

## 13. Notifications

**Service:** `lib/services/notification_service.dart`  
**Channel:** `service_reminders` / "Service Reminders"  
**Platform:** Android + iOS only (skipped on Web)

**Behavior:**
- On HomeScreen init: request permissions
- On every `remindersProvider` change: `cancelAll()` then reschedule
- Only **time-based** due dates (`item.nextDueDate`) get scheduled notifications
- Distance-only reminders appear in-app only
- All operations wrapped in try/catch — notification failure never crashes app

---

## 14. External Integrations

| Integration | Endpoint / SDK | Used for |
|-------------|----------------|----------|
| Firebase Auth | SDK | Email, Google sign-in, password reset |
| Cloud Firestore | SDK | User data sync, rider profile |
| Google Sign-In | SDK | Android OAuth (Web client ID configured) |
| Postal PIN API | `https://api.postalpincode.in/pincode/{code}` | Indian PIN → state/city |
| Firebase Storage | Rules only | Not used in app code yet |

**Currency:** Fixed `₹` (INR) via `kCurrencySymbol` in `formatters.dart`. No user setting.

**Number formatting:** Indian digit grouping (e.g., `12,34,567`) for odometer display.

---

## 15. Design System & Theming

### 15.1 Brand Colors

| Token | Value | Usage |
|-------|-------|-------|
| Seed color | `#E6521F` | Primary brand orange |
| Theme mode | System | Light + dark via `ThemeMode.system` |
| Material | M3 | `useMaterial3: true` |

### 15.2 Component Tokens

| Component | Spec |
|-----------|------|
| Card radius | 18px, elevation 0, outline border |
| Input radius | 14px, filled background |
| Button height | 52px minimum (FilledButton) |
| FAB | Extended with icon + label |
| AppBar | Left-aligned title, scrolledUnderElevation: 1 |

### 15.3 Shared Widgets

| Widget | File | Purpose |
|--------|------|---------|
| `WearIndicator` | `widgets/wear_indicator.dart` | Linear progress for interval usage |
| `StatusChip` | `widgets/wear_indicator.dart` | Colored status badge |
| `EmptyState` | `widgets/empty_state.dart` | Icon + title + message + optional CTA |
| `statusColor()` / `statusLabel()` | `widgets/status_colors.dart` | Status → color/label mapping |

---

## 16. Security Model

### 16.1 Firestore Rules

```
users/{userId}/**  → read/write if auth.uid == userId
brands/**          → read if authenticated; write denied
models/**          → read if authenticated; write denied
```

### 16.2 Storage Rules

User-scoped paths under `users/{uid}/**` (defined but unused in app).

### 16.3 Client-Side

- No secrets in source (Firebase config is public by design)
- Android signing via `android/key.properties` (gitignored)
- Google OAuth Web client ID embedded for Android token audience

---

## 17. Design Decisions & Rationale

| Decision | Rationale |
|----------|-----------|
| **Auth required** | Enables cloud sync, per-user data isolation, and Firestore security rules |
| **Hive over shared_preferences** | Structured entity storage with box-per-collection; better for sync mirroring |
| **km internal, mi display** | Single canonical unit avoids conversion bugs in calculations |
| **Dual interval (km + months)** | Real maintenance is triggered by whichever comes first |
| **max(distance, time) usage** | Conservative urgency — alerts on the sooner trigger |
| **OEM schedule is read-only reference** | Dashboard informs; user must manually add tracked items |
| **Quick "Done" dropdown** | Fast path to log service without navigating to form |
| **Indian PIN API** | Auto-fill state/city reduces profile friction for Indian users |
| **Manual JSON serialization** | No build_runner dependency; maps directly to Firestore documents |
| **IndexedStack for tabs** | Preserves scroll position and form state when switching tabs |
| **Notifications as nice-to-have** | Wrapped defensively; in-app reminders are primary |
| **Fixed ₹ currency** | India-first product; simplifies formatting |
| **Bundled maintenance JSON** | Works offline; no network needed for OEM schedules |
| **PopScope on onboarding** | Ensures minimum profile before using app features |

---

## 18. Known Gaps & Future Work

| Item | Status |
|------|--------|
| `fl_chart` dependency | Declared, no charts implemented |
| `shared_preferences` | Declared, unused (Hive used instead) |
| Firebase Storage | Rules exist, no upload code |
| Guest / offline-only mode | Not supported (README may describe older MVP) |
| Widget/integration tests | Only 3 unit tests in `test/widget_test.dart` |
| Currency setting | Fixed ₹ only |
| Delete bike UI | No delete bike flow in current screens |
| iOS Google Sign-In | Uses same flow; may need additional plist config |
| Web notifications | Skipped (`kIsWeb` guard) |

---

## 19. Build & Deployment

### 19.1 Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome          # Web
flutter run -d <device>        # Mobile
flutter build apk              # Android APK
flutter build appbundle        # Play Store
flutter build web              # Web deploy
```

### 19.2 Configuration Files

| File | Purpose |
|------|---------|
| `pubspec.yaml` | Dependencies, assets, version |
| `firebase.json` | Firebase project + rules paths |
| `lib/firebase_options.dart` | Platform Firebase config |
| `firestore.rules` | Database security |
| `storage.rules` | Storage security |
| `android/app/build.gradle.kts` | Android build + ProGuard |
| `android/app/google-services.json` | Firebase Android |
| `analysis_options.yaml` | Lint rules (flutter_lints) |

### 19.3 App Identity

- **Name:** MyBike
- **Package:** com.mybike.mybike
- **Version:** 1.0.0+1

---

## 20. File Map

### Screens (12 routed + 1 conditional)

| Screen | File |
|--------|------|
| SignInScreen | `lib/features/auth/sign_in_screen.dart` |
| RiderOnboardingScreen | `lib/features/auth/rider_onboarding_screen.dart` |
| HomeScreen | `lib/features/home/home_screen.dart` |
| GarageTab | `lib/features/home/garage_tab.dart` |
| MaintenanceDashboard | `lib/features/home/maintenance_dashboard.dart` |
| RemindersTab | `lib/features/home/reminders_tab.dart` |
| SettingsTab | `lib/features/settings/settings_tab.dart` |
| BikeDetailScreen | `lib/features/bikes/bike_detail_screen.dart` |
| BikeFormScreen | `lib/features/bikes/bike_form_screen.dart` |
| ItemFormScreen | `lib/features/maintenance_items/item_form_screen.dart` |
| ServiceFormScreen | `lib/features/service/service_form_screen.dart` |
| FuelFormScreen | `lib/features/fuel/fuel_form_screen.dart` |

### Core Services

| Service | File |
|---------|------|
| Auth | `lib/services/auth_service.dart` |
| Cloud sync | `lib/services/cloud_sync_service.dart` |
| Reminders | `lib/services/reminder_service.dart` |
| Notifications | `lib/services/notification_service.dart` |
| Rider profile | `lib/services/rider_profile_service.dart` |
| PIN lookup | `lib/services/pincode_service.dart` |

### Data Models

| Model | File |
|-------|------|
| Bike | `lib/data/models/bike.dart` |
| MaintenanceItem | `lib/data/models/maintenance_item.dart` |
| ServiceRecord | `lib/data/models/service_record.dart` |
| FuelEntry | `lib/data/models/fuel_entry.dart` |
| RiderProfile | `lib/data/models/rider_profile.dart` |
| Catalog | `lib/data/models/catalog.dart` |
| MaintenanceSchedule | `lib/data/models/maintenance_schedule.dart` |
| Enums | `lib/data/models/enums.dart` |

---

*This document reflects the codebase as of MyBike v1.0.0+1. For setup instructions, see `README.md`.*
