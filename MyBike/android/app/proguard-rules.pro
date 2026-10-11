# Keep attributes used for generics/serialization.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# flutter_local_notifications (uses Gson reflection).
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }

# Firebase + Google Play services.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**

# Google Sign-In / Credential Manager — the plugin reflects on auth result
# classes and the AndroidX credential manager APIs on Android 14+.
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.libraries.identity.** { *; }
-keep class androidx.credentials.** { *; }
-keep class androidx.credentials.exceptions.** { *; }
-dontwarn androidx.credentials.**

# App Check / Crashlytics / Messaging may rely on reflection in native shims.
-keep class com.google.firebase.appcheck.** { *; }
-keep class com.google.firebase.crashlytics.** { *; }
-keep class com.google.firebase.messaging.** { *; }

# Flutter deferred components reference Play Core, which isn't bundled here.
-dontwarn com.google.android.play.core.**
