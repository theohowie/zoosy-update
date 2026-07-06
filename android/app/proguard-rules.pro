# Flutter 必备
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.engine.FlutterEngine { *; }
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.view.FlutterMain { *; }

# MMKV
-keep class com.tencent.mmkv.** { *; }

# 保留含 native 方法的类
-keepclasseswithmembernames class * { native <methods>; }

# 保留枚举
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# 保留序列化类
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# App 包
-keep class com.theohowie.zoosy.** { *; }

# flutter_local_notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# home_widget
-keep class es.antonborri.home_widget.** { *; }

# permission_handler
-keep class com.baseflow.permissionhandler.** { *; }

# image_picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# share_plus
-keep class dev.flutter.shareplus.** { *; }

# package_info_plus
-keep class dev.flutter.packageinfoplus.** { *; }

# url_launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# speech_to_text
-keep class com.csdcorp.speech_to_text.** { *; }

# path_provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# http
-keep class ** extends javax.net.ssl.SSLSocketFactory { *; }

# 忽略 Flutter 引擎引用但实际不使用的 Play Core 类
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.common.**

# 忽略缺失的类警告
-ignorewarnings
