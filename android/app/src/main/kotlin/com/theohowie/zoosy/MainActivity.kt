package com.theohowie.zoosy

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.util.Log
import com.tencent.mmkv.MMKV
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val shortcutChannel = "zoosy/shortcut"
    private val eventChannel = "zoosy/shortcut_events"
    private val widgetChannel = "zoosy/widget_update"
    private lateinit var mmkv: MMKV
    private lateinit var screenTime: ScreenTimeService
    private var _eventSink: EventChannel.EventSink? = null
    private var _filePickerResult: MethodChannel.Result? = null
    private companion object {
        const val PICK_JSON_FILE = 1001
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MMKV.initialize(applicationContext)
        mmkv = MMKV.defaultMMKV()

        screenTime = ScreenTimeService(applicationContext)
        screenTime.startPolling()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zoosy/file_picker")
            .setMethodCallHandler { call, result ->
                if (call.method == "pickJsonFile") {
                    _filePickerResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/json"
                        putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain"))
                    }
                    startActivityForResult(intent, PICK_JSON_FILE)
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shortcutChannel)
            .setMethodCallHandler { call, _ ->
                when (call.method) { "startShortcut" -> { } "stopShortcut" -> { } }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    _eventSink = events
                    checkWidgetLaunchIntent(intent)
                }
                override fun onCancel(arguments: Any?) {
                    _eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, widgetChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "updateWidget") {
                    try {
                        val args = call.arguments as HashMap<*, *>
                        val prefs: SharedPreferences = applicationContext.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                        prefs.edit().apply {
                            for ((key, value) in args) {
                                putString(key.toString(), value?.toString() ?: "")
                            }
                            commit()
                        }
                        for ((key, value) in args) {
                            mmkv.encode(key.toString(), value?.toString() ?: "")
                        }
                        val ctx = applicationContext
                        val appWidgetManager = AppWidgetManager.getInstance(ctx)
                        val component = ComponentName(ctx, ZoosyWidgetProvider::class.java)
                        val ids = appWidgetManager.getAppWidgetIds(component)
                        for (widgetId in ids) {
                            val views = ZoosyWidgetProvider.buildRemoteViews(ctx, prefs)
                            appWidgetManager.updateAppWidget(widgetId, views)
                        }
                        try {
                            val intent = Intent(ctx, ZoosyWidgetProvider::class.java).apply {
                                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                            }
                            ctx.sendBroadcast(intent)
                        } catch (_: Exception) {}
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WIDGET_UPDATE_ERROR", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        // ========== 屏幕使用时长通道 ==========
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zoosy/screen_time")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getTodayMinutes" -> result.success(screenTime.getTodayScreenMinutes())
                    "hasPermission" -> result.success(screenTime.hasUsageStatsPermission())
                    "requestPermission" -> { screenTime.openPermissionSettings(); result.success(true) }
                    else -> result.notImplemented()
                }
            }

        // ========== 动态桌面图标切换通道 ==========
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zoosy/app_icon")
            .setMethodCallHandler { call, result ->
                if (call.method == "setIcon") {
                    try {
                        val iconIndex = (call.arguments as? Number)?.toInt() ?: 0
                        Log.d("[ZoosyIcon]", "setIcon called with index=$iconIndex")
                        setLauncherIcon(iconIndex)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("[ZoosyIcon]", "setIcon failed", e)
                        result.error("ICON_ERROR", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        // ========== 原生 GPS 定位通道（不依赖 Google Play Services）==========
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zoosy/location")
            .setMethodCallHandler { call, result ->
                if (call.method == "getLocation") {
                    getCurrentLocation(result)
                } else {
                    result.notImplemented()
                }
            }
    }

    // ========== 原生 GPS 定位（不依赖 Google Play Services）==========
    private fun getCurrentLocation(result: MethodChannel.Result) {
        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager

        // 检查权限
        if (checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
            checkSelfPermission(android.Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "定位权限未授予", null)
            return
        }

        // 先尝试获取最近一次缓存的位置（快速返回）
        val cachedLocation = getLastKnownLocation(locationManager)
        if (cachedLocation != null) {
            val map = hashMapOf<String, Any>(
                "latitude" to cachedLocation.latitude,
                "longitude" to cachedLocation.longitude,
                "accuracy" to cachedLocation.accuracy.toDouble(),
            )
            result.success(map)
            return
        }

        // 没有缓存，请求实时定位
        var delivered = false
        val timeoutHandler = android.os.Handler(mainLooper)
        val timeoutRunnable = Runnable {
            if (!delivered) {
                delivered = true
                result.error("TIMEOUT", "定位超时", null)
            }
        }
        timeoutHandler.postDelayed(timeoutRunnable, 10000) // 10秒超时

        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                if (!delivered) {
                    delivered = true
                    timeoutHandler.removeCallbacks(timeoutRunnable)
                    locationManager.removeUpdates(this)
                    val map = hashMapOf<String, Any>(
                        "latitude" to location.latitude,
                        "longitude" to location.longitude,
                        "accuracy" to location.accuracy.toDouble(),
                    )
                    result.success(map)
                }
            }
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
            override fun onProviderEnabled(provider: String) {}
            override fun onProviderDisabled(provider: String) {
                if (!delivered) {
                    delivered = true
                    timeoutHandler.removeCallbacks(timeoutRunnable)
                    result.error("PROVIDER_DISABLED", "定位服务未开启", null)
                }
            }
        }

        // 优先用 GPS，其次网络定位
        val gpsAvailable = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)
        val networkAvailable = locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)

        when {
            gpsAvailable -> locationManager.requestLocationUpdates(
                LocationManager.GPS_PROVIDER, 0L, 0f, listener, mainLooper)
            networkAvailable -> locationManager.requestLocationUpdates(
                LocationManager.NETWORK_PROVIDER, 0L, 0f, listener, mainLooper)
            else -> {
                timeoutHandler.removeCallbacks(timeoutRunnable)
                result.error("NO_PROVIDER", "请开启定位服务", null)
            }
        }
    }

    private fun getLastKnownLocation(locationManager: LocationManager): Location? {
        val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
        var bestLocation: Location? = null
        for (provider in providers) {
            try {
                if (checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
                    checkSelfPermission(android.Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                    val location = locationManager.getLastKnownLocation(provider)
                    if (location != null) {
                        if (bestLocation == null || location.accuracy < bestLocation.accuracy) {
                            bestLocation = location
                        }
                    }
                }
            } catch (_: SecurityException) {}
        }
        return bestLocation
    }

    private fun setLauncherIcon(index: Int) {
        val pm = packageManager
        val mainActivity = "$packageName.MainActivity"
        val logoAliases = listOf(
            "$packageName.MainActivity_logo1",
            "$packageName.MainActivity_logo2",
            "$packageName.MainActivity_logo3",
            "$packageName.MainActivity_logo4",
            "$packageName.MainActivity_logo5",
            "$packageName.MainActivity_logo6",
            "$packageName.MainActivity_logo7"
        )

        if (index == 0) {
            // 默认主题：启用 MainActivity，禁用所有 logo alias
            pm.setComponentEnabledSetting(
                ComponentName(this, mainActivity),
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            logoAliases.forEach { alias ->
                pm.setComponentEnabledSetting(
                    ComponentName(this, alias),
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
            }
            Log.d("[ZoosyIcon]", "Switch to default icon (enabled MainActivity)")
        } else if (index in 1..7) {
            // 禁用 MainActivity（alias 接管）
            pm.setComponentEnabledSetting(
                ComponentName(this, mainActivity),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
            // 启用对应 alias，禁用其余
            logoAliases.forEachIndexed { i, alias ->
                val state = if (i + 1 == index) {
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                } else {
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                }
                pm.setComponentEnabledSetting(
                    ComponentName(this, alias),
                    state,
                    PackageManager.DONT_KILL_APP
                )
                if (i + 1 == index) {
                    Log.d("[ZoosyIcon]", "Enabled alias: $alias (index=${i + 1})")
                }
            }
        }
        // 通知 launcher 刷新图标缓存
        refreshLauncher()
        // 延迟 500ms 后杀死自己，让 launcher 有足够时间读取更新后的组件状态
        // 进程重启后桌面图标即更新为当前主题样式
        android.os.Handler(mainLooper).postDelayed({
            try {
                android.os.Process.killProcess(android.os.Process.myPid())
            } catch (_: Exception) {}
        }, 500)
    }

    private fun refreshLauncher() {
        try {
            // 方式1：尝试广播（部分系统允许）
            sendBroadcast(Intent(Intent.ACTION_PROVIDER_CHANGED).apply {
                data = android.net.Uri.parse("package:$packageName")
            })
        } catch (_: SecurityException) {}
        try {
            // 方式2：重启 launcher 进程
            val am = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
            val homeIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
            val pkg = packageManager.resolveActivity(homeIntent, 0)?.activityInfo?.packageName
            if (pkg != null) am.killBackgroundProcesses(pkg)
        } catch (_: Exception) {}
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_JSON_FILE) {
            if (resultCode == RESULT_OK && data?.data != null) {
                val uri = data.data!!
                try {
                    val content = contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
                    if (content != null) {
                        _filePickerResult?.success(content)
                    } else {
                        _filePickerResult?.error("READ_FAILED", "无法读取文件内容", null)
                    }
                } catch (e: Exception) {
                    _filePickerResult?.error("READ_ERROR", e.message, null)
                }
            } else {
                _filePickerResult?.success(null)
            }
            _filePickerResult = null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        checkWidgetLaunchIntent(intent)
    }

    private fun checkWidgetLaunchIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("open_new_thought", false) == true) {
            Log.d("[ZoosyWidget]", "Widget new-thought button clicked, notifying Flutter")
            _eventSink?.success(true)
        }
    }
}
