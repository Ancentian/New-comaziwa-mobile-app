## Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

## HTTP and Networking
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

## Gson
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

## Connectivity Plus
-keep class com.android.connectivity.** { *; }
## Bluetooth Printer
-keep class com.tablemi.flutter_bluetooth_printer.** { *; }
-keep class android.bluetooth.** { *; }
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

## Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }