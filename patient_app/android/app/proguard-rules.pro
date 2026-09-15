# Flutter and Plugin keep rules
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**

# ML Kit and Vision rules (suppress optional unused classes)
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**
-dontwarn org.tensorflow.lite.**
