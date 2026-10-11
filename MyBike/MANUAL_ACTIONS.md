# Manual actions required outside the codebase

Everything below lives in third-party dashboards (Firebase Console, Google Play
Console, Google Cloud) and can't be committed to this repo. These are the
one-time setup steps you must complete after merging the remediation work.

Firebase project: **`mybike-865b8`**
App id: **`com.mybike.mybike`**

---

## 1. Register Android signing SHA fingerprints (unblocks Google Sign-In)

Google Sign-In fails on any installed APK today because the Android app's
`client_type: 1` OAuth client is missing. Register both the debug and
release signing certificates.

### Get the fingerprints

**Debug keystore** (used by `flutter run`):

```bash
keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android
```

**Release keystore** (once `android/key.properties` exists):

```bash
keytool -list -v -alias <your-alias> -keystore <path/to/your.jks>
```

Copy both the **SHA-1** and **SHA-256** values.

### Register them in Firebase

1. https://console.firebase.google.com/project/mybike-865b8/settings/general
2. Scroll to **Your apps → Android app (com.mybike.mybike)**.
3. Click **Add fingerprint**, paste each SHA-1 and SHA-256 (one at a time).
4. Repeat for the Play App Signing fingerprint — found in Google Play Console
   → **Setup → App integrity → App signing**.
5. **Download the new `google-services.json`** and replace
   `android/app/google-services.json`.
6. Confirm the file now contains a `client_type: 1` block with the matching
   `certificate_hash`.

---

## 2. Enable Firebase App Check

The client code already calls `FirebaseAppCheck.instance.activate(...)` in
`lib/main.dart` with Play Integrity on Android and DeviceCheck on iOS. You
must enable enforcement in the console or App Check only runs in
report-only mode.

1. https://console.firebase.google.com/project/mybike-865b8/appcheck
2. Register the Android app with **Play Integrity** as the provider.
3. Register the iOS app with **DeviceCheck**.
4. Under **APIs**, flip these to **Enforce**:
   - Cloud Firestore
   - Firebase Authentication
   - Cloud Storage
   - Firebase Cloud Messaging
5. (Dev builds only) Add the debug tokens that appear in your `flutter run`
   logs on first launch as **Debug providers** so local builds keep working.

---

## 3. Enable email verification requirements

The app sends a verification email on sign-up and shows a non-blocking banner
until the user verifies. Firebase itself still accepts unverified users; if
you want to additionally gate server-side features on verification:

1. https://console.firebase.google.com/project/mybike-865b8/authentication/providers
2. **Email/Password → Email link (passwordless sign-in)** — optional.
3. Firestore rules can be tightened per-collection with
   `request.auth.token.email_verified == true` once a verified-only cohort is
   needed. (Not applied yet — the current rules admit any signed-in user.)

---

## 4. Deploy the updated security rules

The repo's `firestore.rules` and `storage.rules` were tightened to validate
every field on write. Push them to Firebase:

```bash
firebase deploy --only firestore:rules,storage:rules
```

Rules take effect immediately on deployment. Verify in the Firebase console
Rules Playground that:

- A write to `users/{otherUid}/...` from `auth.uid == me` is **denied**.
- A write to `users/{me}/bikes/x` with `odometerKm: "not a number"` is
  **denied**.
- A write with a 100 KB payload to the same path is **denied** (reasonable
  size cap).

---

## 5. Enable Firestore cost alerts

Even with App Check and tight rules, a bug or scrape can run up a bill.

1. https://console.cloud.google.com/billing (pick the billing account
   backing `mybike-865b8`).
2. **Budgets & alerts → Create budget** scoped to the project.
3. Set a conservative monthly cap (e.g. $20) and 50/90/100% email alerts.

---

## 6. Play Console: account deletion policy declaration

Starting May 31 2024, Google Play requires an in-app account deletion flow
AND a web deletion URL for apps that support account creation.

- The in-app flow now lives at **Settings → Delete account**.
- Create a public page (anywhere — your website, a GitHub Pages site)
  explaining how to request deletion for users who no longer have the app
  installed. Then declare it in Play Console → **App content → Account
  deletion**.

---

## 7. Enable FCM

The client registers tokens under `users/{uid}/devices/{token}`. To actually
send push messages:

1. https://console.firebase.google.com/project/mybike-865b8/notification
2. For scheduled/triggered pushes, write a Cloud Function that reads the
   `devices` sub-collection and sends via the Admin SDK. Not shipped — the
   client is just registered to receive.

---

## 8. Rotate the Firebase Web API key if it was ever pasted anywhere

The web/iOS/Android API keys in `lib/firebase_options.dart` are **public by
design** — they identify the project, not grant access. Access is controlled
by Firebase Auth rules and App Check. You do not need to rotate them.

However, if any **service account JSON** (`*-firebase-adminsdk-*.json`) is
ever committed or shared externally, revoke it immediately at:

https://console.cloud.google.com/iam-admin/serviceaccounts?project=mybike-865b8

---

## 9. Quarterly audit

- [ ] Review Firestore usage dashboard for unexpected spikes.
- [ ] Review Crashlytics for new unhandled exceptions.
- [ ] Review Firebase Auth active user count vs. legitimate installs
      (early signal of credential-stuffing attempts).
- [ ] Rotate the Play upload key per Play Console recommendations.
