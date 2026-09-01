# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Google Sign In
-keep class com.google.android.gms.auth.** { *; }

# Keep Package Certificate Signatures for Firebase Auth / Google Auth
-keep class android.content.pm.Signature { *; }
-keep class android.content.pm.SigningInfo { *; }
-keep class android.content.pm.PackageInfo { *; }

# Keep model classes (jika ada)
-keepattributes Signature
-keepattributes *Annotation*

# Prevent stripping of methods/fields annotated with @Keep
-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

# ── Fix R8 Missing Classes (Google Play Core) ─────────────────────────
# Flutter menggunakan Play Core API secara opsional (deferred components).
# Karena fitur ini tidak digunakan, kita abaikan saja warning-nya.
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
# ──────────────────────────────────────────────────────────────────────
