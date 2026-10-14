# R8 rules for the release build.
#
# Flutter's own engine rules come from the Flutter Gradle plugin; these cover the
# plugins this app adds.

# flutter_secure_storage relies on Android's KeyStore reflectively in places.
-keep class androidx.security.crypto.** { *; }

# Keep annotations that plugin channel code checks at runtime.
-keepattributes *Annotation*

# Useful stack traces from a minified release build; the mapping file stays out
# of the APK, so this leaks nothing.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
