# Règles de conservation pour ObjectBox utilisé par FMTC
-keep class io.objectbox.** { *; }
-dontwarn io.objectbox.**
-keep class class_ss.** { *; }

# Protéger ton propre package (avec le "e")
-keep class com.example.rando_alert.** { *; }

# Protéger flutter_map et http
-keep class io.flutter.embedding.** { *; }
-keep class com.google.** { *; }
-keep class androidx.** { *; }

# Protéger les librairies réseau
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class org.conscrypt.** { *; }

# Protéger les dépendances critiques
-keep class com.squareup.** { *; }
-dontwarn com.squareup.**

# Garder les classes réfléchies
-keepclasseswithmembernames class * {
    native <methods>;
}

# Conserver les structures de données natives
-keep class example.rando_alert.MyObjectBox { *; }
-keep class * extends io.objectbox.relation.ToOne { *; }
-keep class * extends io.objectbox.relation.ToMany { *; }
# Conserver les classes de Flutter et l'architecture de base
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Conserver les modèles de données de ton application pour éviter le "NullPointerException" au décodage
-keep class com.example.rando_alert.** { *; }
-keep class com.example.randoalert.** { *; }
-keep class com.example.RandoAlert.** { *; }

# Si tu utilises Supabase / PostgREST / GoRouter (Gson, Jackson ou requêtes HTTP)
-keepattributes Signature,*Annotation*,EnclosingMethod
-dontwarn okhttp3.**
-dontwarn okio.**
# Ignorer les classes manquantes de Google Play Core (indispensable pour F-Droid)
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**