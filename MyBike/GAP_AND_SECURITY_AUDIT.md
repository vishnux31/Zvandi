# MyBike / Z-Vandi — Gap, Broken-Link & Security Audit

**Repository:** `C:\Projects\Zvandi\MyBike`
**Branch audited:** `UAT`
**App id:** `com.mybike.mybike` · Firebase project `mybike-865b8`
**Audit date:** 2026-10-11
**Audience:** Engineering, QA, Security, Product

This document is the follow-on to `TECHNICAL_DOCUMENTATION.md`. It inventories every
gap, broken link, half-finished feature, and security/privacy threat found during a
full-tree read, with concrete resolution steps and a prioritised fix order.

---

## 0. TL;DR — What is actually true today

| Area | Claim in README / docs | Reality on `UAT` |
|---|---|---|
| "Offline-first, no account" | README still says this | **False** — `router.dart:36` forces every route behind `/signin`; app does not boot without Firebase |
| Multi-bike garage | Yes | Works, but **no "delete bike" UI** exists anywhere |
| Dark + light theme | pubspec claims M3 light + dark | `AppTheme.light()` and `AppTheme.dark()` return the **same dark build** — light mode is dead code |
| Service history | Logs edit/add fine | **No delete** on history rows (tap edits only); orphaned records when bike removed |
| Fuel log | Full-tank flag captured | `fullTank` is **never read** in the economy calc — flag is cosmetic |
| Reminders | "Dismiss" button on Reminders tab | **Deletes the entire MaintenanceItem** — irreversible data loss, not a dismiss |
| Notifications | "Honours Critical / Reminder toggles" | Works, but Android 13+ `POST_NOTIFICATIONS` permission is **not declared in `AndroidManifest.xml`** — the request silently no-ops on fresh installs |
| Google Sign-In | Advertised on sign-in screen | Fails on sideloaded builds because `google-services.json` has **no Android OAuth client / SHA-1** (README already notes this) |
| Cloud sync | Multi-device backup | Sign-in triggers an **unconditional `_pushAllLocal()` batch** that can overwrite newer remote data (last-write-wins; no `updatedAt`) |
| Tests | 13 passing | 12 failing — Hive not initialised in widget-test harness |
| Release signing | `flutter build apk` | Falls back to **debug keystore** silently when `key.properties` missing — un-publishable to Play |

---

## 1. Dead code / orphaned modules to delete or wire up

| File | State | Action |
|---|---|---|
| `lib/features/home/maintenance_dashboard.dart` (619 lines) | Imported nowhere in the running UI (grep confirms only `TECHNICAL_DOCUMENTATION.md` mentions it). Superseded by `home_tab.dart` sections. | **Delete** or re-wire into Learn/Garage. Keeping orphan ships ~15 KB of dead Dart into every APK. |
| `lib/app/theme.dart` — `AppTheme.light()` | Returns `_build()` which hard-codes `Brightness.dark`. `MaterialApp` passes it as `theme:` but `themeMode: ThemeMode.system` has no effect. | Either (a) implement a real light scheme, or (b) remove `AppTheme.light()` and set `themeMode: ThemeMode.dark`. |
| `pubspec.yaml` → `shared_preferences: ^2.3.3` | Zero references in `lib/`. Hive is the sole key-value store. | Remove dependency. Shrinks APK by ~70 KB and one native plugin init. |
| `pubspec.yaml` → `fl_chart` | **Used** in `bike_detail_screen.dart` (Fuel tab chart). Keep. | None. |
| `pubspec.yaml` → `firebase_storage` claim in README | README roadmap mentions it; `storage.rules` deployed; **no `firebase_storage` dependency and no upload code**. | Either add dependency + photo flow, or remove rules + README promise so the roadmap matches shipping scope. |
| `tempUnit` setting in `settings_tab.dart:33` | Written to Hive but **not read anywhere**. No temperature is ever displayed in the app. | Remove the toggle, or wire it to a real surface. |
| `lib/data/models/bike.dart` → `photoPath`, `notes`, `yearOfPurchase` | Fields exist in the model, serialised, but **no UI exposes `photoPath`** (`notes` is captured in form; `yearOfPurchase` is in bike form only). | Either add photo picker + yearOfPurchase surfaces or drop the fields to keep the schema honest. |
| `removeForBike(...)` on `ItemsNotifier` / `RecordsNotifier` / `FuelNotifier` | Defined, never called — because there is no delete-bike entry point. | Add delete flow (see §3) and call these to purge child entities. |
| `/bike/new` route in `router.dart:52` | Defined, but **nothing in the UI pushes it** — every "Add bike" entry opens `showAddBikeDialog()` inline. | Either remove the route or replace the inline dialog with `context.push('/bike/new')` to have one add flow. |
| Rider onboarding "Step N of 3" chip + 3 progress stripes | Only two steps exist. | Fix label to "Step N of 2" and drop the third stripe, or add the missing step. |

---

## 2. Broken / misleading links & UX bugs

### 2.1 Reminders tab "Dismiss" is destructive
**File:** `lib/features/home/reminders_tab.dart:464–496`
`_onDeleteAlert` calls `ref.read(itemsProvider.notifier).remove(reminder.item.id)` — i.e. permanently deletes the tracked `MaintenanceItem` from Hive **and** Firestore. The button is labelled "Dismiss" with a dialog titled "Dismiss Alert?". Users will dismiss an alert expecting it to re-surface at the next interval and lose their entire tracked item.

**Fix:**
- Rename "Dismiss" → "Delete item" and the confirmation to "Delete this maintenance item?"
- OR introduce real dismiss semantics: add a `dismissedUntil: DateTime?` field to `MaintenanceItem`, filter reminders where `dismissedUntil > now`, keep the record.

### 2.2 `_ComponentStatusDropdown` resets to "To do" after Done
**File:** `lib/features/bikes/bike_detail_screen.dart:362–411`
State is local-only (`_ComponentStatus _status = _ComponentStatus.todo;`). After `onDone()` completes the dropdown is forced back to "To do" — a user looking at the same row still sees "To do" even though a service was just logged. Confusing and causes double-logging.

**Fix:** Replace the dropdown with a single `IconButton(Icons.check_circle_outline)` that performs the mark-done action, or bind state to the derived reminder status.

### 2.3 Component Health shows 100% for untracked groups
**File:** `lib/services/bike_health_service.dart:106–113`
`componentGroupScore` returns `100` when a group has zero tracked items. Users with no `MaintenanceItem`s see "Engine 100%, Chain 100%, Brakes 100%, Tyres 100%" immediately after onboarding — the app is lying about parts it has never measured.

**Fix:** Return `null` (and show `—` in UI) when a group has no items; weight-exclude it from the overall health roll-up.

### 2.4 Garage "Next Svc" misreports Overdue
**File:** `lib/features/home/garage_tab.dart:26–45`
`_calculateNextService` returns `"Overdue"` whenever `healthPercent < 70`, even if no individual item is overdue (health can be low from a single due-soon item). Overdue should mean an item is actually past its interval.

**Fix:** Return `"Overdue"` only when `reminders.any((r) => r.status == ReminderStatus.overdue)`; otherwise show the soonest `remainingKm` or `—`.

### 2.5 Fuel economy ignores the `fullTank` flag it collects
**File:** `lib/features/bikes/bike_detail_screen.dart:481–520`
`entries.fold(... + e.liters)` sums every litre; the sorted-by-odometer delta is taken across all entries. The `fullTank: true` guard that the TECHNICAL_DOCUMENTATION §11.3 claims is required — isn't enforced. Partial fills over-report consumption.

**Fix:** Filter `entries.where((e) => e.fullTank).toList()` before deriving the series. Alternatively, compute per-segment economy only for segments bounded by two consecutive `fullTank` entries. The home-insights provider (`home_insights_provider.dart:27–64`) has the same bug.

### 2.6 Service form loses cost on multi-task entries
**File:** `lib/features/service/service_form_screen.dart:188–204`
Loop writes one `ServiceRecord` per checked task but assigns `cost: i == 0 ? costValue : 0.0`. If a user ticks "Oil & Filter + Tire Replacement" and enters ₹5000, only the first type captures the cost; subsequent records are stored with `cost: 0.0`, polluting the median-cost estimator in `upcomingExpensesProvider`.

**Fix (minimum):** Split the entered cost evenly across the ticks, or store it only once on a parent record and link children.
**Fix (ideal):** Make `ServiceRecord` support multiple `types: List<ServiceType>` (migration required) so one entry = one cost = many tasks.

### 2.7 Service form provider overloads the notes field
**File:** `lib/features/service/service_form_screen.dart:163`
Writes `"Provider: X\n{notes}"` into the `notes` column and parses it back on edit with a string prefix. Fragile: any user who types `Provider:` at the start of the notes corrupts the editor.

**Fix:** Add `provider: String?` to `ServiceRecord`, migrate stored data (one-shot splitter in `fromMap`), remove the string hack.

### 2.8 Service form `_isEditing` branch drops multi-task selections
**File:** `lib/features/service/service_form_screen.dart:177–186`
On edit it rewrites one record with `checkedTypes.first` and silently discards the other checkboxes. The user sees other boxes ticked but only one survives.

**Fix:** Deal with the data model split in 2.6 first, then on edit either show which single type the record is or support real multi-type.

### 2.9 History and Fuel rows have no delete / long-press
Tap-to-edit is the only interaction. There is no swipe-to-delete or `⋮` menu on a `ServiceRecord` or a `FuelEntry` row. Users cannot correct a bad entry except by zeroing it inside the form, which still leaves a row in history.

**Fix:** Add a dismissible `Slidable` (or `Dismissible`) with "Delete" action calling `recordsProvider.notifier.remove(id)` / `fuelProvider.notifier.remove(id)`.

### 2.10 No way to delete a bike
Confirmed by grep: nothing calls `bikesProvider.notifier.remove(id)` from any widget. Combined with 2.9, a user who adds a wrong bike is stuck with it forever and its Firestore footprint keeps growing.

**Fix:** Add a "Delete bike" destructive action in `BikeDetailScreen`'s app-bar `PopupMenuButton`. On confirm:
1. `itemsProvider.notifier.removeForBike(id)`
2. `recordsProvider.notifier.removeForBike(id)`
3. `fuelProvider.notifier.removeForBike(id)`
4. `bikesProvider.notifier.remove(id)`
5. Clear `garageSelectedBikeIdProvider` if it pointed at this id.

### 2.11 Sign-out message is misleading
`settings_tab.dart:287` reads *"Your data stays safely in the cloud and will be restored when you sign back in."* But `MyBikeApp.ref.listen(authStateProvider)` calls `sync.stop()` with **default `keepLocal: false`** (`cloud_sync_service.dart:91`), which **wipes every Hive box** on sign-out. The copy and the behaviour disagree.

**Fix:** Either (a) pass `keepLocal: true` on normal sign-out and only clear on an explicit "delete account" flow, or (b) rewrite the dialog to admit local data is cleared and will re-download.

### 2.12 Rider onboarding uses an orphaned `TextEditingController` for DOB
`rider_onboarding_screen.dart:350` builds a new `TextEditingController(text: ...)` on every rebuild. Not disposed. Minor leak in isolation, but repeat renders during date picking will accumulate controllers for the life of the screen.

**Fix:** Build the controller in `initState` or hold DOB as a `Text` + tap target rather than a `TextFormField`.

### 2.13 `redirect` races Firebase cold-start
`router.dart:36` reads `FirebaseAuth.instance.currentUser` synchronously. On a cold start Firebase has initialised (via `main.dart`) but `currentUser` can briefly be `null` before the stored token is restored, flashing `/signin` for the first frame.

**Fix:** Gate the first redirect on `authStateProvider.hasValue`, or show a splash screen until `authStateChanges()` emits.

### 2.14 Bike selector only visible on Home AppBar
The dropdown lives only in `HomeScreen`'s AppBar, but Garage/Reminders/Settings all honour `garageSelectedBikeProvider`. Users have to pop back to Home to switch bikes before using Reminders/Settings. Move the selector into the tab shell or add it to every scope that depends on it.

---

## 3. Unfinished features (visible to the user but incomplete)

| Feature | Where | What's missing |
|---|---|---|
| Delete bike / service / fuel | all over | §2.9 / §2.10 |
| Email verification | sign-in flow | No `sendEmailVerification` call, no gate on unverified mail |
| Password change | Settings | None — must use "Forgot password" instead |
| Account deletion (GDPR / Play Policy) | Settings | None — required by Google Play Developer Policy for apps that offer account creation |
| Photo / receipt attachments | `Bike.photoPath` field | No picker, no upload, no viewer |
| CSV / PDF export | README roadmap | Not started |
| Push notifications (FCM) | README roadmap | Not started — only `flutter_local_notifications` |
| Light theme | advertised in docs | §1 — not implemented |
| Learn tab for unknown models | `learn_tab.dart:12` | Shows literal "We will add the maintenance tips soon." stub |
| Rider onboarding step counter | §1 | 3 pips, 2 steps |
| Deep-link / notification-tap handling | `homeTabIndexProvider` exists for this | No `onDidReceiveNotificationResponse` wired, no app-link routes |
| Pin-code lookup offline fallback | `pincode_service.dart` | Network-only, hard-fails without connectivity; no cache |

---

## 4. Data layer / correctness gaps

### 4.1 Last-write-wins sync will drop user data
`cloud_sync_service.start(uid)` ⇒ `_pushAllLocal()` runs an unconditional `batch.set(...)` for **every local Hive doc** on sign-in. If a user installs on a second device while the first has fresher data not yet synced down, the second device pushes stale local data over the remote.

**Fix (minimum):** Only push docs that don't exist remotely. **Fix (correct):** add `updatedAt` (FieldValue.serverTimestamp()) to every entity, compare before overwriting; prefer the newer side. Also chunk the batch — Firestore caps batches at 500 writes and this code will throw on larger users.

### 4.2 Snapshot listener thrash
`_listen` calls `reload()` for every batch of `docChanges`. That rebuilds the entire StateNotifier list, which triggers every dependent `remindersProvider`, `homeInsightsProvider`, etc. Flutter rebuilds the entire tree. For users with many entries this spikes CPU on sign-in and on remote edits.

**Fix:** Apply changes incrementally — maintain the Notifier state as a `Map<String, T>` and mutate only affected rows.

### 4.3 Hive box scans on every provider rebuild
`BaseRepository<T>.getAll()` decodes every row from JSON on each call; filtered providers like `fuelForBikeProvider` run `.where((e) => e.bikeId == bikeId)` across all bikes' rows. Fine today (dozens of rows). Becomes a problem at the hundreds-of-fuel-ups scale per user.

**Fix:** Replace the generic `Hive.box<String>(name)` + JSON blob design with a lazy map `Map<String, T>` in-memory, invalidated by writes. Or switch to Hive type adapters (eliminates JSON encode/decode per read).

### 4.4 `nextDueDate` edge cases
`MaintenanceItem.nextDueDate` computes `DateTime(year, month, day)` with no time component — anything near local midnight DST transitions will skew by an hour. `relativeDays` compares to `DateTime.now()` wall-clock in device TZ. Users crossing time zones get flaky "due in Nd" labels.

**Fix:** Store and compare in UTC; use the `timezone` package (already a dep) to localise for display only.

### 4.5 `fuelForBikeProvider` sort by odometer, not date
`app_providers.dart:174` sorts fuel entries by `odometerKm` descending. Correct for charting but wrong for the list view and insights that reason about "this month vs last month" when the user back-dates an entry. A user who logs an older fuel-up with a lower odometer appears "first" by date yet "last" by odometer.

**Fix:** Expose two sorted views and consume the right one in each place.

### 4.6 Orphaned child records
With no delete-bike flow (§2.10) and `removeForBike` never called, every orphaned `MaintenanceItem` / `ServiceRecord` / `FuelEntry` whose `bikeId` points to a deleted bike will still be synced, counted in medians, and shown in global `activeRemindersProvider` (which falls through if its `bikeMap[item.bikeId] == null`, line `reminder_service.dart:75` — OK for reminders, but history/fuel listings silently include them).

**Fix:** Implement cascade delete in §2.10, plus a one-time migration that purges orphans on next sign-in.

### 4.7 `RiderProfile.toMap()` only writes non-null fields; merge keeps stale ghosts
`rider_profile.dart:76` builds a map that omits null fields. The RiderProfileService writes with `SetOptions(merge: true)`. If a user clears their phone/profession, the old value stays in Firestore because the field isn't present in the merge payload.

**Fix:** Use `FieldValue.delete()` for intentionally-cleared fields, or write the full document with `SetOptions(merge: false)`.

### 4.8 Odometer rounding loses sub-km precision
Every form pre-fills odometer with `unit.fromKm(...).round().toString()`. When the user re-saves without editing, 12,345.6 km becomes 12,346 km. Over many edits odometer drifts.

**Fix:** Preserve full decimal; only round for the hint-only display, store the real value.

---

## 5. Security & privacy threats

### 5.1 Firestore rules allow writing arbitrary data under own uid
```
match /users/{userId}/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```
No field-level validation, no size limits, no shape check. A hostile client can write arbitrarily large payloads to inflate Firestore cost and poison their own doc graph. More importantly, a leaked token lets an attacker fill the owner's quota.

**Fix:** Add explicit `allow create/update: if request.resource.data.keys().hasOnly([...]) && request.resource.data.name is string && request.resource.data.name.size() < 128 && ...` for each collection. Deny unknown collections under `users/{uid}`. Consider cost-cap Cloud Functions.

### 5.2 Storage rules allow unlimited file size & type
```
match /users/{userId}/{allPaths=**} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```
No content-type check, no size cap. An attacker (or an unlocked physical device) can store multi-GB files on your bill.

**Fix:** Require `request.resource.size < 5 * 1024 * 1024` and `request.resource.contentType.matches('image/.*')` when the photo feature lands.

### 5.3 No Firebase App Check
Nothing in `main.dart` initialises App Check (Play Integrity / DeviceCheck / reCAPTCHA). Without it, anyone with your public Firebase config (which is embedded in every APK, as it must be) can speak to your Auth, Firestore and Storage from a self-written client, bypassing the app entirely.

**Fix:** `FirebaseAppCheck.instance.activate(...)` with Play Integrity on Android and DeviceCheck/App Attest on iOS; enforce in Firebase console once rolled out.

### 5.4 `POST_NOTIFICATIONS` permission missing on Android 13+
`AndroidManifest.xml` only declares `android.permission.INTERNET`. Android 13+ requires `android.permission.POST_NOTIFICATIONS` to be in the manifest **and** granted at runtime via `flutter_local_notifications`' permission call. On fresh installs on Android 13+ the runtime request will throw a `SecurityException` or no-op, so no notification ever fires.

**Fix:** Add
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```
Also consider `android.permission.SCHEDULE_EXACT_ALARM` — currently irrelevant because `AndroidScheduleMode.inexactAllowWhileIdle` is used; leave it off unless exact timing is required.

### 5.5 Google Sign-In disabled on real builds
Covered in README. `android/app/google-services.json` has only `client_type: 3` (web). On any sideloaded or Play-signed APK, `GoogleSignIn.initialize(serverClientId: ...)` succeeds but `authenticate()` throws because Firebase can't match the signing cert. Registering the SHA-1 for the debug keystore AND the Play upload key is mandatory.

**Fix:** Add SHA-1/SHA-256 of both the debug keystore (for dev) and the Play upload key (for release) to Firebase console; redownload `google-services.json`; verify there's a `client_type: 1` block.

### 5.6 Firebase error messages leak account-enumeration info
`sign_in_screen.dart:49–51` surfaces `FirebaseAuthException.message` verbatim. Firebase returns distinct messages for "There is no user record corresponding to this identifier" vs. "The password is invalid". That tells an attacker whether an email exists in your user base.

**Fix:** Map all auth errors to one generic string ("Email or password is incorrect"); log the real `code` to telemetry (once added — see §6).

### 5.7 Weak password policy
`sign_in_screen.dart:400` only enforces `password.length >= 6`. Firebase's own default is 6. This is below NIST / OWASP guidance. Combined with no email verification (5.9), it is cheap to pop accounts.

**Fix:** Require ≥10 chars, zxcvbn-style strength check client-side; enable Firebase Authentication's new Identity Platform tier for server-side password policy if the budget allows.

### 5.8 No rate limiting on sign-in attempts
Firebase Auth throttles sign-in attempts but only after many failures. No client-side cooldown. Combined with 5.7 this is a credential-stuffing target.

**Fix:** Enable App Check (5.3) — it is Firebase's canonical anti-abuse layer. Optionally add a short client-side back-off after N failures and show a captcha-like interstitial on the web build.

### 5.9 Email verification not required
`FirebaseAuthService.registerWithEmail` creates and signs in the user in one call. Nothing checks `user.emailVerified`. An attacker can register with a victim's email, use it to perform account recovery flows elsewhere, or spam the real owner by triggering password-reset mail.

**Fix:** After `registerWithEmail`, call `currentUser.sendEmailVerification()`, keep the user signed in but gate write operations until verified; add a "Resend verification" screen.

### 5.10 Rider PII is in Firestore in plaintext
`RiderProfile` includes full name, DOB, gender, phone, profession, pincode, state, city. Firestore rules protect it per-uid, but there is no encryption at rest beyond Google's defaults, no field-level sealing. Phone + DOB + PIN is enough to attempt SIM-swap / KYC fraud at Indian institutions.

**Fix (minimum):** Document the retention policy, add a "Delete my account" flow, add Firebase App Check (5.3). **Fix (ideal):** encrypt sensitive fields client-side with a key derived from the user's password; drop fields the product does not actually use.

### 5.11 India Post PIN API: no timeout, no retries, no cert pinning
`pincode_service.dart` uses `dart:io HttpClient` with no `client.connectionTimeout` and no `badCertificateCallback`. If the API hangs, the UI's `_verifyPincode` button spins forever. If the service's TLS is downgraded on a hostile network, the client silently trusts it.

**Fix:** `client.connectionTimeout = const Duration(seconds: 10);` + wrap the `.getUrl` in `.timeout(const Duration(seconds: 15))`. Switch to the `http` package which uses the same cert validation Dart ships with (same effect; cleaner code).

### 5.12 No crash / error telemetry
No Crashlytics, Sentry, or logging pipeline. Every `catch (_)` in `notification_service.dart`, `pincode_service.dart`, `cloud_sync_service.dart`, `settings_provider.dart` swallows the error with only `debugPrint`. In production you have no idea when sync is dropping writes or notifications are failing.

**Fix:** Add `firebase_crashlytics` (free, same project) and route all top-level `catch` logs to it. Wire `FlutterError.onError` and `PlatformDispatcher.instance.onError`.

### 5.13 Local Hive data unencrypted
Bikes / items / records / fuel are stored as JSON strings in `~/data/user/0/com.mybike.mybike/app_flutter/*.hive`. On a rooted device or via `adb backup` (if `android:allowBackup` defaults to true, which it does since the manifest doesn't set it), that is readable.

**Fix:** Set `android:allowBackup="false"` and `android:fullBackupContent="false"` on `<application>`. For high-value deployments switch to `Hive.openBox(name, encryptionCipher: HiveAesCipher(key))` with the key stored in platform keychain via `flutter_secure_storage`.

### 5.14 Release build drops to debug signing silently
`android/app/build.gradle.kts:52–58` — when `key.properties` is missing it uses `signingConfigs.getByName("debug")` without warning. CI or an engineer can ship a "release" APK that is effectively debug-signed and cannot be upgraded to a real release build later without reinstall (signature mismatch).

**Fix:** Fail the release build hard when `key.properties` is missing, e.g.
```kotlin
if (!keystorePropertiesFile.exists()) {
  throw GradleException("key.properties missing; cannot build release")
}
```
Keep the current debug-fallback only behind an explicit `-PallowDebugSigning` flag.

### 5.15 ProGuard rules are incomplete
`proguard-rules.pro` keeps `flutter_local_notifications`, `firebase`, `gms` — but **not** `google_sign_in` nor the `identity.credentialmanager` classes it reflects on in Android 14. Expect `ClassNotFoundException` in release.

**Fix:** Add
```
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class androidx.credentials.** { *; }
```
and build a release APK to validate.

### 5.16 Cleartext network traffic allowed by default
No `android:usesCleartextTraffic="false"` on `<application>`, no `networkSecurityConfig`. Pincode service is HTTPS so this is latent, but any future HTTP endpoint will slip through.

**Fix:** Add
```xml
<application
    android:usesCleartextTraffic="false"
    ... >
```
in `AndroidManifest.xml`.

### 5.17 No `Permission-Policy` / `Content-Security-Policy` for web build
Web build is produced by `flutter build web`. There's no custom `web/index.html` CSP, no referrer policy, no `X-Frame-Options`. If the web app is ever served, it is trivially iframe-embeddable (clickjacking) and can load arbitrary third-party scripts.

**Fix:** Add CSP meta/http headers at the hosting layer (Firebase Hosting `firebase.json` → `headers`).

### 5.18 Email reset flow leaks "forgot password" errors
`sign_in_screen.dart:75–89` surfaces Firebase errors from `sendPasswordReset` directly. "There is no user record" leaks enumeration again.

**Fix:** Always show "If an account exists for that email, we've sent a reset link." regardless of outcome.

---

## 6. Observability / release engineering

| Gap | Fix |
|---|---|
| No crash reporting | `firebase_crashlytics` + wire `FlutterError.onError` |
| No analytics | `firebase_analytics` with explicit opt-in screen (DPDPA 2023 compliance for India) |
| No CI | Add GitHub Actions: `flutter analyze`, `flutter test`, `flutter build apk --release` on PR |
| Widget tests crash (`HiveError: Box not found`) | Add `test/flutter_test_config.dart` that `Hive.init(tempDir)`s and opens all `Boxes.*` before the suite |
| No pinned Flutter / Dart SDK | Add `.fvmrc` or `fvm.config.json` pinning Flutter 3.44.0 so CI and devs match |
| No release notes / version bump automation | `cider` or a bump-version GitHub Action |
| `applicationId` identical for dev/prod | Add `com.mybike.mybike.dev` via a product flavour so testers can keep both installed |

---

## 7. Compliance checklist (India + Play)

- **DPDPA 2023 (India Digital Personal Data Protection Act):**
  - [ ] Explicit, specific, informed consent screen on first launch (name, DOB, phone, pincode qualify as personal data).
  - [ ] Right to withdraw consent + data deletion flow (ties to 5.10, §3 account deletion).
  - [ ] Named Data Fiduciary / Grievance Officer contact in-app.
- **Google Play Data Safety form:**
  - [ ] Declare collection of email, name, DOB, gender, phone, approximate location (via pincode), app activity.
  - [ ] Declare third-party sharing with Firebase.
- **Google Play Account Deletion Policy:**
  - [ ] In-app and web deletion flow for any app allowing account creation.
- **COPPA:** onboarding gates age ≥16, OK.

---

## 8. Prioritised remediation plan

### P0 — ship-blockers (do before any Play publish)
1. Register SHA-1/SHA-256 of debug + Play upload keys in Firebase, redownload `google-services.json` (§5.5).
2. Add `POST_NOTIFICATIONS` permission (§5.4).
3. Rename "Dismiss" to "Delete item" OR implement real dismiss (§2.1).
4. Fail release build when `key.properties` is missing (§5.14).
5. Account deletion flow + delete-bike flow with cascading child deletes (§2.10, §4.6, §7).
6. Enable `firebase_crashlytics` so we actually see production failures (§5.12).
7. Correct onboarding step indicator and sign-out dialog copy (§1, §2.11).

### P1 — correctness / data integrity
8. `updatedAt` on every entity + non-destructive sync merge (§4.1).
9. Fix fuel economy to honour `fullTank` and segment correctly (§2.5).
10. Fix service form multi-task cost + provider as a real column (§2.6, §2.7).
11. Component Health: return `—` for unmeasured groups (§2.3).
12. Garage "Next Svc" overdue logic (§2.4).
13. Odometer precision (§4.8).
14. `RiderProfile` clearing fields with `FieldValue.delete()` (§4.7).

### P2 — security hardening
15. Firebase App Check (§5.3) — the single biggest abuse mitigation.
16. Field-level Firestore rules + size caps (§5.1).
17. Generic auth error strings (§5.6, §5.18).
18. Email verification + password policy (§5.7, §5.9).
19. `android:allowBackup="false"` + `usesCleartextTraffic="false"` (§5.13, §5.16).
20. Complete ProGuard rules; build release APK and validate Google Sign-In flow end-to-end (§5.15).

### P3 — housekeeping / dead code
21. Remove `maintenance_dashboard.dart`, `AppTheme.light()`, `shared_preferences`, unused `tempUnit` setting, `/bike/new` route (§1).
22. Add delete gestures to history + fuel rows (§2.9).
23. Replace `_ComponentStatusDropdown` with a one-shot action button (§2.2).
24. Reconcile `TECHNICAL_DOCUMENTATION.md` and `README.md` with reality (auth required, no light theme, no Storage code, Firebase dependency).

### P4 — product features already promised
25. Push notifications via FCM; wire deep-link handling to `homeTabIndexProvider` and routes.
26. Photo attachments (`image_picker` + compressed upload to Storage).
27. CSV/PDF export of history and fuel.
28. Real "Learn" model content for brand/model combos lacking schedules.

---

## 9. One-line summary for stakeholders

> MyBike's core maintenance tracking is solid, but a destructive "Dismiss" button, missing delete flows, Android 13 notifications silently failing, Google Sign-In broken on real builds, debug-signed "release" APKs, no App Check, no crash reporting, and a sync that can overwrite remote data make it **not safe to publish on Google Play today**. The fix list above, ordered P0→P4, is ≈ 3 engineer-weeks of focused work to reach a defensible 1.0.0 release.

---

*Document maintained alongside `TECHNICAL_DOCUMENTATION.md`. Update when a listed gap is closed; mark fixed items with ✅ and the PR link.*
