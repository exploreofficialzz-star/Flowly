-keep class io.flutter.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn io.flutter.embedding.**

# Fix R8 missing class error
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-dontwarn io.flutter.app.FlutterPlayStoreSplitApplication
