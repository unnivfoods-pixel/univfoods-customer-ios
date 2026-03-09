# Keep Flutter classes
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# Keep Supabase
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# Keep Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Keep Google Maps
-keep class com.google.android.gms.maps.** { *; }
-dontwarn com.google.android.gms.**

# Remove logging in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Optimize
-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-verbose

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
