package com.theohowie.zoosy

import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import com.tencent.mmkv.MMKV
import java.util.Calendar

/**
 * 屏幕使用时长服务。
 * 主方案：UsageStatsManager 查询今日所有应用前台总时长。
 * 降级方案：PowerManager.isInteractive() 每30秒轮询累计（应用存活期间）。
 */
class ScreenTimeService(private val context: Context) {

    private val mmkv = MMKV.defaultMMKV()
    private val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
    private val handler = Handler(Looper.getMainLooper())
    private var polling = false
    private val pollRunnable = Runnable { pollOnce() }

    companion object {
        private const val KEY_TODAY_MINUTES = "screen_minutes_today"
        private const val KEY_TODAY_DATE = "screen_minutes_date"
        private const val KEY_VERSION = "screen_time_version"
        private const val CURRENT_VERSION = 2 // 每次修改算法时递增，触发缓存清除
        private const val TAG = "[ScreenTime]"
    }

    /** 是否有 UsageStats 权限（通过 AppOpsManager 检测） */
    fun hasUsageStatsPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) return false
        return try {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
            val mode = appOps.checkOpNoThrow(
                android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName
            )
            mode == android.app.AppOpsManager.MODE_ALLOWED
        } catch (_: Exception) {
            false
        }
    }

    /** 打开系统设置引导用户授权 */
    fun openPermissionSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }

    /** 获取今日总屏幕使用分钟数（只统计用户安装的应用） */
    fun getTodayScreenMinutes(): Long {
        // 版本检查：算法更新时清除旧缓存
        val savedVersion = mmkv.decodeInt(KEY_VERSION, 0)
        if (savedVersion < CURRENT_VERSION) {
            mmkv.encode(KEY_TODAY_MINUTES, 0L)
            mmkv.encode(KEY_TODAY_DATE, "")
            mmkv.encode(KEY_VERSION, CURRENT_VERSION)
            Log.d(TAG, "版本更新，清除旧缓存")
        }

        checkDailyReset()
        val polled = getPollingMinutes()

        if (!hasUsageStatsPermission() || Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return polled
        }

        return try {
            val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val cal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            }
            val todayStart = cal.timeInMillis
            val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_BEST, todayStart, System.currentTimeMillis())
            if (stats.isNullOrEmpty()) return polled

            var totalMs = 0L
            var userAppCount = 0
            var systemAppCount = 0
            for (stat in stats) {
                // 只统计用户安装的应用（非系统应用）
                if (isUserApp(stat.packageName)) {
                    totalMs += stat.totalTimeInForeground
                    userAppCount++
                } else {
                    systemAppCount++
                }
            }
            val fromUsageStats = totalMs / 60000
            Log.d(TAG, "UsageStats: 用户应用=${userAppCount}个, 系统应用=${systemAppCount}个, 用户应用总时长=$fromUsageStats min, 轮询=$polled min")

            val result = maxOf(fromUsageStats, polled)
            mmkv.encode(KEY_TODAY_MINUTES, result)
            result
        } catch (e: Exception) {
            Log.e(TAG, "UsageStats error: ${e.message}")
            polled
        }
    }

    /** 判断是否为用户安装的应用（非系统应用） */
    private fun isUserApp(packageName: String): Boolean {
        return try {
            val pm = context.packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            val isSystem = (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0
            val isUpdatedSystem = (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
            !isSystem || isUpdatedSystem
        } catch (_: Exception) {
            // MIUI 等系统可能限制访问某些应用信息，出错时按包名前缀判断
            // 以 com.android. / com.miui. / com.google.android. / com.qualcomm. 开头的视为系统应用
            val systemPrefixes = listOf("com.android.", "com.miui.", "com.google.android.", "com.qualcomm.", "com.xiaomi.")
            val isLikelySystem = systemPrefixes.any { packageName.startsWith(it) }
            !isLikelySystem
        }
    }

    /** 启动轮询（每30秒检测屏幕状态） */
    fun startPolling() {
        if (polling) return
        polling = true
        handler.post(pollRunnable)
    }

    /** 停止轮询 */
    fun stopPolling() {
        polling = false
        handler.removeCallbacks(pollRunnable)
    }

    private fun pollOnce() {
        if (!polling) return
        try {
            checkDailyReset()
            if (powerManager.isInteractive) {
                val prev = mmkv.decodeLong(KEY_TODAY_MINUTES, 0)
                // 每 60 秒轮询一次，亮屏一次加 1 分钟（原 30 秒导致翻倍）
                val newVal = prev + 1
                mmkv.encode(KEY_TODAY_MINUTES, newVal)
                Log.d(TAG, "Screen ON → +1 min, total=$newVal")
            }
        } catch (_: Exception) {}
        handler.postDelayed(pollRunnable, 60_000)
    }

    private fun getPollingMinutes(): Long {
        checkDailyReset()
        return mmkv.decodeLong(KEY_TODAY_MINUTES, 0)
    }

    private fun checkDailyReset() {
        val today = dateStr()
        val saved = mmkv.decodeString(KEY_TODAY_DATE, "")
        if (saved != today) {
            mmkv.encode(KEY_TODAY_MINUTES, 0L)
            mmkv.encode(KEY_TODAY_DATE, today)
            Log.d(TAG, "Daily reset for $today")
        }
    }

    private fun dateStr(): String {
        val cal = Calendar.getInstance()
        return "${cal.get(Calendar.YEAR)}-${cal.get(Calendar.MONTH) + 1}-${cal.get(Calendar.DAY_OF_MONTH)}"
    }
}
