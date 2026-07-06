package com.theohowie.zoosy

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.ColorStateList
import android.graphics.Color
import android.util.Log
import android.widget.RemoteViews
import com.tencent.mmkv.MMKV

class ZoosyWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        try {
            // 确保 MMKV 已初始化（MainActivity 已初始化，此处为兜底）
            MMKV.initialize(context)
            val prefs: SharedPreferences = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            Log.d("[ZoosyWidget]", "onUpdate: ids=${appWidgetIds.contentToString()}")

            for (appWidgetId in appWidgetIds) {
                val views = buildRemoteViews(context, prefs)
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        } catch (e: Exception) {
            Log.e("[ZoosyWidget]", "onUpdate error: ${e.message}")
        }
    }

    companion object {
        /** 从 MMKV 读取，若不存在或 MMKV 未初始化则降级到 SP */
        private fun getString(kv: MMKV?, prefs: SharedPreferences, key: String, defaultVal: String): String {
            if (kv != null) {
                try {
                    val v = kv.decodeString(key)
                    if (!v.isNullOrEmpty()) return v
                } catch (_: Exception) {}
            }
            return prefs.getString(key, defaultVal) ?: defaultVal
        }

        /**
         * 根据 MMKV（优先）或 SharedPreferences 中的数据构建 RemoteViews。
         * 可被 ZoosyWidgetProvider.onUpdate 和 MainActivity 直通通道共用。
         */
        fun buildRemoteViews(context: Context, prefs: SharedPreferences): RemoteViews {
            // MMKV 优先读取（数据由 MainActivity 直通通道写入）
            val kv = try { MMKV.defaultMMKV() } catch (_: Exception) { null }

            // 优先用 cnt key（不被覆盖），降级到 reflection_count
            var count = getString(kv, prefs, "cnt", "")
            if (count.isEmpty()) count = getString(kv, prefs, "reflection_count", "0")
            val todayCnt = getString(kv, prefs, "today_cnt", "0")
            val streak = getString(kv, prefs, "current_streak", "0")
            val labelType = getString(kv, prefs, "widget_label", "总共思考")
            var recentTitle = getString(kv, prefs, "rt", "")
            if (recentTitle.isEmpty()) recentTitle = getString(kv, prefs, "recent_title", "最近思考")
            var recentContent = getString(kv, prefs, "rc", "")
            if (recentContent.isEmpty()) recentContent = getString(kv, prefs, "recent_content", "")
            var recentDate = getString(kv, prefs, "rd", "")
            if (recentDate.isEmpty()) recentDate = getString(kv, prefs, "recent_date", "")
            val style = getString(kv, prefs, "style", "style3")
            var themeColorStr = getString(kv, prefs, "tc", "")
            if (themeColorStr.isEmpty()) themeColorStr = getString(kv, prefs, "theme_color", "#4828C8")
            val themeColor = try { Color.parseColor(themeColorStr) } catch (_: Exception) { Color.parseColor("#4828C8") }
            val logoIndex = getString(kv, prefs, "logo_index", "0")

            Log.d("[ZoosyWidget]", "buildViews: style=$style count=$count title=$recentTitle")

            // 根据 logo 索引选择对应桌面图标资源（0=默认 ic_launcher，1~7=ic_logo1~7）
            val logoResId = when (logoIndex.toIntOrNull()) {
                1 -> R.mipmap.ic_logo1
                2 -> R.mipmap.ic_logo2
                3 -> R.mipmap.ic_logo3
                4 -> R.mipmap.ic_logo4
                5 -> R.mipmap.ic_logo5
                6 -> R.mipmap.ic_logo6
                7 -> R.mipmap.ic_logo7
                else -> R.mipmap.ic_launcher
            }

            // PendingIntent: 打开 App
            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
            val openPending = PendingIntent.getActivity(context, 0, openIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

            // PendingIntent: 新建思考
            val newIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                putExtra("open_new_thought", true)
            }
            val newPending = PendingIntent.getActivity(context, 1, newIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

            val layoutRes = when (style) {
                "style2" -> R.layout.widget_style2
                "style3" -> R.layout.widget_style3
                else -> R.layout.widget_style1
            }
            val views = RemoteViews(context.packageName, layoutRes)

            when (style) {
                "style1" -> {
                    views.setTextViewText(R.id.widget_title, "Zoosy")
                    views.setTextViewText(R.id.widget_label, labelType)
                    // 根据标签类型显示对应数据
                    val displayVal = when (labelType) {
                        "今日思考" -> "${todayCnt}条"
                        "连续记录" -> "${streak}天"
                        else -> "${count}条"
                    }
                    views.setTextViewText(R.id.widget_count, displayVal)
                    try { views.setImageViewResource(R.id.widget_logo, logoResId) } catch (_: Exception) {}
                    views.setTextColor(R.id.widget_title, themeColor)
                    views.setTextColor(R.id.widget_count, themeColor)
                    views.setOnClickPendingIntent(R.id.widget_title, openPending)
                    views.setOnClickPendingIntent(R.id.widget_label, openPending)
                    views.setOnClickPendingIntent(R.id.widget_count, openPending)
                }
                "style2" -> {
                    views.setTextViewText(R.id.widget_title, "Zoosy")
                    views.setTextViewText(R.id.widget_label, "新建思考")
                    views.setTextViewText(R.id.widget_plus, "+")
                    views.setTextColor(R.id.widget_title, themeColor)
                    views.setTextColor(R.id.widget_label, themeColor)
                    views.setTextColor(R.id.widget_plus, Color.WHITE)
                    // 圆形按钮背景跟随主题色
                    try {
                        val csl = ColorStateList.valueOf(themeColor)
                        if (android.os.Build.VERSION.SDK_INT >= 29) {
                            views.setColorStateList(R.id.widget_plus, "setBackgroundTintList", csl)
                        } else {
                            @Suppress("DiscouragedPrivateApi")
                            views.setInt(R.id.widget_plus, "setBackgroundTintList", csl.hashCode())
                        }
                    } catch (_: Exception) {}
                    try { views.setImageViewResource(R.id.widget_logo, logoResId) } catch (_: Exception) {}
                    views.setOnClickPendingIntent(R.id.widget_count, newPending)
                    views.setOnClickPendingIntent(R.id.widget_label, newPending)
                    views.setOnClickPendingIntent(R.id.widget_plus, newPending)
                    views.setOnClickPendingIntent(R.id.widget_title, openPending)
                }
                "style3" -> {
                    views.setTextViewText(R.id.widget_title, "最近思考")
                    val hasRealData = recentTitle != "最近思考" && recentTitle != "暂无思考"
                    val thoughtTitle = if (hasRealData) recentTitle else ""
                    views.setTextViewText(R.id.widget_thought_title, thoughtTitle)
                    views.setTextViewText(R.id.widget_content, recentContent)
                    views.setTextViewText(R.id.widget_date, recentDate)
                    views.setTextColor(R.id.widget_title, themeColor)
                    if (hasRealData) views.setTextColor(R.id.widget_thought_title, themeColor)
                    views.setTextColor(R.id.widget_content, themeColor)
                    views.setTextColor(R.id.widget_date, themeColor)
                    views.setViewVisibility(R.id.widget_thought_title, if (hasRealData) android.view.View.VISIBLE else android.view.View.GONE)
                    try { views.setImageViewResource(R.id.widget_logo, logoResId) } catch (_: Exception) {}
                    views.setOnClickPendingIntent(R.id.widget_title, openPending)
                    views.setOnClickPendingIntent(R.id.widget_content, openPending)
                    views.setOnClickPendingIntent(R.id.widget_thought_title, openPending)
                    views.setTextViewText(R.id.widget_title, "最近思考")
                    views.setTextViewText(R.id.widget_date, recentDate)
                }
            }
            return views
        }
    }
}
