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

# ============================================================================
#  Room / WorkManager
#
#  崩溃原因（v1.16.0 开启 R8 后必现，真机启动即闪退）：
#    java.lang.RuntimeException: Failed to create an instance of
#    androidx.work.impl.WorkDatabase
#      at androidx.room.RoomDatabase.<init>
#
#  androidx.room.RoomDatabase 是用反射创建实现类的：
#      Class.forName(getClass().getCanonicalName() + "_Impl")
#  R8 会把 androidx.work.impl.WorkDatabase_Impl 重命名（或裁掉），
#  反射按原类名就找不到这个类，于是进程在 Application 启动阶段直接崩溃。
#
#  WorkManager/Room 由 home_widget 插件间接引入（应用本身没有直接使用）。
#  Room 官方要求保留 *RoomDatabase 的子类及其 _Impl 实现类。
# ============================================================================

# Room 生成的数据库实现类（必须保留原名，反射按名字查找）
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class **.*_Impl { *; }
-keep class * extends androidx.room.RoomDatabase
-keep class androidx.room.RoomDatabase { *; }

# Room 运行时
-keep class androidx.room.** { *; }
-keep class androidx.sqlite.** { *; }
-dontwarn androidx.room.**
-dontwarn androidx.sqlite.**

# WorkManager（由 home_widget 间接引入）
-keep class androidx.work.** { *; }
-keep class androidx.work.impl.** { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-dontwarn androidx.work.**

# androidx.startup 初始化入口（WorkManagerInitializer 通过它被反射调用）
-keep class androidx.startup.** { *; }
-keep class * implements androidx.startup.Initializer { *; }
-dontwarn androidx.startup.**

