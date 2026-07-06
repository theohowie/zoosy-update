import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

/// 屏幕使用时长提醒服务
/// 每5分钟检查一次今日屏幕时长，超过阈值 + 非静默时段 → 发送通知
class ScreenTimeService {
  static const _channel = MethodChannel('zoosy/screen_time');
  static FlutterLocalNotificationsPlugin? _notifications;

  // 阈值
  static const int _threshold1 = 300; // 5 小时 = 300 分钟
  static const int _threshold2 = 660; // 11 小时 = 660 分钟

  // 静默时段 00:00 - 05:30
  static const int _quietEndHour = 5;
  static const int _quietEndMin = 30; // 5:30

  // 标记已发送通知的 SP key
  static const _notified1Key = 'screen_time_notified_1';
  static const _notified2Key = 'screen_time_notified_2';
  static const _notifiedDateKey = 'screen_time_notified_date';
  static const _enabledKey = 'screen_time_enabled';

  static Timer? _timer;

  /// 初始化：注入 notifications 实例
  static void init(FlutterLocalNotificationsPlugin notifications) {
    _notifications = notifications;
  }

  /// 是否启用（默认开启）
  static Future<bool> isEnabled() async {
    return (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? true;
  }

  static Future<void> setEnabled(bool v) async {
    await (await SharedPreferences.getInstance()).setBool(_enabledKey, v);
    if (v) {
      start();
    } else {
      stop();
    }
  }

  /// 获取今日分钟数
  static Future<int> getTodayMinutes() async {
    try {
      final result = await _channel.invokeMethod<num>('getTodayMinutes');
      return result?.toInt() ?? 0;
    } catch (e) {
      debugPrint('[ScreenTime] 获取失败: $e');
      return 0;
    }
  }

  /// 是否有 UsageStats 权限
  static Future<bool> hasPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 打开系统设置授权
  static Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestPermission');
    } catch (_) {}
  }

  /// 启动定时检查（每5分钟）
  static void start() {
    _timer?.cancel();
    _checkAndNotify(); // 立即检查一次
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _checkAndNotify());
  }

  /// 停止定时检查
  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// 核心：检查阈值并发送通知
  static Future<void> _checkAndNotify() async {
    if (_notifications == null) {
      debugPrint('[ScreenTime] notifications 实例为空，跳过');
      return;
    }

    // 静默时段检查
    final now = DateTime.now();
    final hour = now.hour;
    final min = now.minute;
    if (_isQuietTime(hour, min)) {
      debugPrint('[ScreenTime] 静默时段 (${hour}:${min.toString().padLeft(2, '0')})，跳过');
      return;
    }

    // 跨天重置标记
    await _dailyReset();

    final minutes = await getTodayMinutes();
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    debugPrint('[ScreenTime] 今日屏幕时长: ${hours}小时${mins}分钟 ($minutes min)');

    // 检查阈值
    final notified1 = (await SharedPreferences.getInstance()).getBool(_notified1Key) ?? false;
    final notified2 = (await SharedPreferences.getInstance()).getBool(_notified2Key) ?? false;
    debugPrint('[ScreenTime] 阈值检查: 5h已通知=$notified1, 11h已通知=$notified2');

    if (minutes >= _threshold2 && !notified2) {
      debugPrint('[ScreenTime] 达到11小时阈值，发送通知');
      await _sendNotification(
        2,
        '使用手机时间有点长啦 📱',
        '你今天已经使用手机 ${_fmt(minutes)} 了，已经超过 11 小时，注意休息眼睛哦～',
      );
      await (await SharedPreferences.getInstance()).setBool(_notified2Key, true);
    } else if (minutes >= _threshold1 && !notified1) {
      debugPrint('[ScreenTime] 达到5小时阈值，发送通知');
      await _sendNotification(
        1,
        '已经使用手机 ${_fmt(minutes)} 了 💭',
        '是时候记录一下今天的思考了，有什么想写下来的吗？',
      );
      await (await SharedPreferences.getInstance()).setBool(_notified1Key, true);
    } else {
      debugPrint('[ScreenTime] 未达到阈值，继续等待');
    }
  }

  /// 判断是否在静默时段 (00:00-05:30)
  static bool _isQuietTime(int hour, int min) {
    if (hour < _quietEndHour) return true;
    if (hour == _quietEndHour && min <= _quietEndMin) return true;
    return false;
  }

  /// 跨天重置通知标记
  static Future<void> _dailyReset() async {
    final prefs = await SharedPreferences.getInstance();
    final today = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
    final saved = prefs.getString(_notifiedDateKey) ?? '';
    if (saved != today) {
      await prefs.setBool(_notified1Key, false);
      await prefs.setBool(_notified2Key, false);
      await prefs.setString(_notifiedDateKey, today);
    }
  }

  /// 触发屏幕时长提醒通知
  static Future<void> _sendNotification(int id, String title, String body) async {
    // 直接使用预设文案发送
    String notifTitle;
    String notifBody;
    if (id == 2) {
      notifTitle = '今天使用手机时间较长 📱';
      notifBody = body; // 包含实际时长
    } else {
      notifTitle = '使用手机时间有点长啦 💭';
      notifBody = body; // 包含实际时长
    }
    debugPrint('[ScreenTime] >>> 发送屏幕时长通知: $notifTitle - $notifBody');
    await NotificationService.notifications.show(
      100 + id, // 使用不同 ID 避免和每日提醒冲突
      notifTitle,
      notifBody,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'zoosy_reminder', 'Zoosy 思考提醒',
          channelDescription: '屏幕使用时长提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
    debugPrint('[ScreenTime] >>> 屏幕时长通知发送成功');
  }

  /// 格式化分钟为小时+分钟
  static String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '${h}小时${m}分钟';
    return '${m}分钟';
  }
}
