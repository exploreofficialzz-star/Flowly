# ════════════════════════════════════════════════════════════════════════════════
#  Flowly — ProGuard / R8 rules
#  Keep this file updated whenever you add a new dependency.
# ════════════════════════════════════════════════════════════════════════════════

# ── Flutter engine ────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ── Google Mobile Ads (AdMob) ─────────────────────────────────────────────────
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.**

# ── Google Play Billing (in_app_purchase) ─────────────────────────────────────
-keep class com.android.billingclient.** { *; }
-keep class com.android.vending.billing.** { *; }
-keep class com.flutter.plugins.inapppurchase.** { *; }
-dontwarn com.android.billingclient.**

# ── Play Core (split installs / updates) ─────────────────────────────────────
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.app.FlutterPlayStoreSplitApplication

# ── Kotlin / Coroutines ───────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-keepclassmembers class kotlin.Metadata { *; }
-dontwarn kotlin.**

# ── AndroidX ─────────────────────────────────────────────────────────────────
-keep class androidx.** { *; }
-dontwarn androidx.**
-keep class android.** { *; }

# ── Connectivity Plus ─────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# ── Shared Preferences ───────────────────────────────────────────────────────
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ── General: keep annotations and signatures (needed for reflection) ──────────
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# ── Remove debug logs in release ─────────────────────────────────────────────
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
