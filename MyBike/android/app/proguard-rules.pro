# Keep attributes used for generics/serialization.
-keepattributes Signature
-keepattributes *Annotation*

# flutter_local_notifications (uses Gson reflection).
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }

# Firebase + Google Play services.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Google Sign-In / Credential Manager.
-keep class com.google.android.libraries.identity.** { *; }

# Flutter deferred components reference Play Core, which isn't bundled here.
-dontwarn com.google.android.play.core.**
