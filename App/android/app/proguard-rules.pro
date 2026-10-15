# flutter_local_notifications deserializes cached scheduled notifications with Gson.
# R8 must retain generic signatures and the TypeToken implementation used at runtime.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
