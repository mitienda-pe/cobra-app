# Keep annotations that R8 needs
-keep class javax.annotation.** { *; }
-keep class com.google.errorprone.annotations.** { *; }

# Keep Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Keep JWT Decoder
-keep class io.jsonwebtoken.** { *; }

# Keep Dio
-keep class io.flutter.plugins.** { *; }

# Keep Crypto Tink
-keep class com.google.crypto.tink.** { *; }

# Keep general rules
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
