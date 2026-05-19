# ============================================================
# FLUTTER — reglas base
# ============================================================
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ============================================================
# FIREBASE — necesario para que no se rompa en release
# ============================================================
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Firestore — modelos de datos deben mantenerse
-keepclassmembers class com.google.firebase.firestore.** { *; }
-keep class com.google.firebase.firestore.** { *; }

# Firebase Auth
-keep class com.google.firebase.auth.** { *; }

# Firebase Messaging (FCM)
-keep class com.google.firebase.messaging.** { *; }

# ============================================================
# KOTLIN — reflection y coroutines
# ============================================================
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings { <fields>; }
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}

# ============================================================
# GSON / JSON — si usas serialización de objetos
# ============================================================
-keepattributes EnclosingMethod
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.** { *; }

# ============================================================
# MODELOS DE TU APP — evita que ProGuard los rompa
# Cambia "com.eventsci.eventos" por tu paquete si es diferente
# ============================================================
-keep class com.eventsci.eventos.** { *; }
-keepclassmembers class com.eventsci.eventos.** { *; }

# ============================================================
# MISCELÁNEOS
# ============================================================
# Evita warnings de librerias que usan reflection internamente
-dontwarn com.google.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# Mantener nombres de excepciones para Crashlytics
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception