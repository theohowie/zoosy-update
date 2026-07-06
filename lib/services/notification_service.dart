import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'prefs_util.dart';
import '../models/reflection.dart';
import 'screen_time_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
  static const _enabledKey = 'notif_enabled';
  static const _hourKey = 'notif_hour';
  static const _minuteKey = 'notif_minute';
  static const _payloadNewThought = 'new_thought';
  static const _titleKey = 'notif_title';
  static const _contentKey = 'notif_content';

  static const String defaultTitle = '在干嘛？有没有好的想法记录一下？';
  static const String defaultContent = '点击此处可以快速记录哦~';

  static VoidCallback? onNotificationTap;

  static const _channelId = 'zoosy_reminder';
  static const _channelName = 'Zoosy 思考提醒';
  static const _dailyReminderId = 1;
  static const _testNotificationId = 0;
  static const _scheduledKey = 'notif_fired_today';

  static const AndroidNotificationDetails _androidDetails = AndroidNotificationDetails(
    _channelId, _channelName,
    channelDescription: '点击通知快速记录想法',
    importance: Importance.high, priority: Priority.high,
    enableVibration: true, enableLights: true,
  );
  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: _androidDetails, iOS: DarwinNotificationDetails(),
  );

  /// App 内部定时器，每分钟检查一次是否该发通知
  static Timer? _timer;
  static bool _firedToday = false;

  static Future<void> init() async {
    tz.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await notifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onTap,
    );
    const channel = AndroidNotificationChannel(_channelId, _channelName,
      description: '点击通知快速记录想法', importance: Importance.high);
    await notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 检查今天是否已发送过
    final prefs = await PrefsUtil.get();
    final today = DateTime.now().toString().substring(0, 10);
    final firedDate = prefs.getString(_scheduledKey);
    _firedToday = (firedDate == today);

    // 启动 App 内部定时检查
    _startTimer();
  }

  /// App 内部定时器：每 30 秒检查一次
  static void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _checkAndFire());
    debugPrint('[Notification] App 内部定时器已启动（每30秒检查一次）');
  }

  /// 核心检查逻辑
  static Future<void> _checkAndFire() async {
    if (!await isEnabled()) return;

    // 跨天重置：如果日期变了，重置今日标记
    final prefs = await PrefsUtil.get();
    final today = DateTime.now().toString().substring(0, 10);
    final firedDate = prefs.getString(_scheduledKey);
    if (firedDate != today) {
      _firedToday = false;
      debugPrint('[Notification] 新的一天 ($today)，重置触发标记');
    }

    if (_firedToday) return;

    final hour = await getHour();
    final minute = await getMinute();
    final now = DateTime.now();

    // 当前时间 >= 设定时间，且在5分钟窗口内
    final targetMinutes = hour * 60 + minute;
    final nowMinutes = now.hour * 60 + now.minute;
    final diff = nowMinutes - targetMinutes;

    if (diff >= 0 && diff <= 5) {
      debugPrint('[Notification] App 内部定时器触发！当前 ${now.hour}:${now.minute.toString().padLeft(2, '0')}, 目标 ${hour}:${minute.toString().padLeft(2, '0')}');
      await _fireReminder();
    }
  }

  /// 实际发送通知
  static Future<void> _fireReminder() async {
    if (_firedToday) return;

    final title = await getTitle();
    final content = await getContent();

    debugPrint('[Notification] >>> 正在发送通知: $title - $content');
    await notifications.show(
      _dailyReminderId, title, content, _notificationDetails,
      payload: _payloadNewThought,
    );

    // 标记今天已发送
    _firedToday = true;
    final prefs = await PrefsUtil.get();
    final today = DateTime.now().toString().substring(0, 10);
    await prefs.setString(_scheduledKey, today);
    debugPrint('[Notification] >>> 通知发送成功！已标记今日已发送');
  }

  static void _onTap(NotificationResponse response) {
    if (response.payload == _payloadNewThought) {
      onNotificationTap?.call();
    }
  }

  // ==================== Prefs 读写 ====================

  static Future<bool> isEnabled() async {
    return (await PrefsUtil.get()).getBool(_enabledKey) ?? true;
  }

  static Future<void> setEnabled(bool v) async {
    await (await PrefsUtil.get()).setBool(_enabledKey, v);
  }

  static Future<int> getHour() async {
    return (await PrefsUtil.get()).getInt(_hourKey) ?? 21;
  }

  static Future<int> getMinute() async {
    return (await PrefsUtil.get()).getInt(_minuteKey) ?? 0;
  }

  static Future<void> setTime(int hour, int minute) async {
    final prefs = await PrefsUtil.get();
    await prefs.setInt(_hourKey, hour);
    await prefs.setInt(_minuteKey, minute);
  }

  static Future<String> getTitle() async {
    return (await PrefsUtil.get()).getString(_titleKey) ?? defaultTitle;
  }

  static Future<String> getContent() async {
    return (await PrefsUtil.get()).getString(_contentKey) ?? defaultContent;
  }

  static Future<void> setTitle(String v) async {
    await (await PrefsUtil.get()).setString(_titleKey, v);
  }

  static Future<void> setContent(String v) async {
    await (await PrefsUtil.get()).setString(_contentKey, v);
  }

  // ==================== 权限 ====================

  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  static Future<bool> requestPhotoPermission() async {
    final status = await Permission.photos.request();
    if (status.isGranted) return true;
    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  static Future<void> requestUsageStatsPermission() async {
    await ScreenTimeService.requestPermission();
  }

  static Future<void> requestAllPermissions() async {
    await requestNotificationPermission();
    await requestPhotoPermission();
    await requestUsageStatsPermission();
  }

  // ==================== 记录今日已记录 ====================

  /// 记录今天已创建新思考（在保存思考时调用）
  static Future<void> markRecordedToday() async {
    final prefs = await PrefsUtil.get();
    final today = DateTime.now().toString().substring(0, 10);
    await prefs.setString('last_record_date', today);
  }

  /// 检查今天是否已记录新思考
  static Future<bool> hasRecordedToday() async {
    final prefs = await PrefsUtil.get();
    final today = DateTime.now().toString().substring(0, 10);
    final lastRecordDate = prefs.getString('last_record_date');
    return lastRecordDate == today;
  }

  /// 发送测试通知
  static Future<void> showTestNotification() async {
    final title = await getTitle();
    final content = await getContent();
    debugPrint('[Notification] 手动发送测试通知: $title');
    await notifications.show(
      _testNotificationId, title, content, _notificationDetails,
      payload: _payloadNewThought,
    );
    debugPrint('[Notification] 测试通知已发送');
  }

  /// 通知开关切换
  static Future<void> toggleEnabled(bool v) async {
    await setEnabled(v);
    debugPrint('[Notification] 通知开关: ${v ? "开启" : "关闭"}');
    if (!v) {
      _firedToday = true; // 关闭后不再触发
    } else {
      // 重新开启时，重置今日标记，允许再次触发
      _firedToday = false;
      final prefs = await PrefsUtil.get();
      await prefs.remove(_scheduledKey);
    }
  }

  /// 保存时间后重置今日标记
  static Future<void> onTimeChanged() async {
    _firedToday = false;
    final prefs = await PrefsUtil.get();
    await prefs.remove(_scheduledKey);
    debugPrint('[Notification] 时间已更改，重置今日触发标记');
  }

  /// 屏幕时长通知
  static Future<void> showScreenTimeNotification(int hours) async {
    String title;
    String body;
    if (hours >= 11) {
      title = '今天使用手机时间较长';
      body = '是时候记录一下今天的思考了，让思考更有价值~';
    } else {
      title = '使用手机时间有点长啦';
      body = '不如停下来，记录一个今天的想法？';
    }
    debugPrint('[Notification] 屏幕时长通知: $title');
    await notifications.show(
      hours, title, body, _notificationDetails, payload: _payloadNewThought,
    );
  }

  /// 停止定时器
  static void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  /// 检查待处理的定时通知（调试用）
  static Future<void> checkPendingNotifications() async {
    final pending = await notifications.pendingNotificationRequests();
    debugPrint('[Notification] 待处理通知数量: ${pending.length}');
    for (final p in pending) {
      debugPrint('[Notification] - ID: ${p.id}, 标题: ${p.title}');
    }
  }

  /// 发送指定标题和内容的通知
  static Future<void> _showNotification(int id, String title, String body) async {
    await notifications.show(
      id,
      title,
      body,
      _notificationDetails,
      payload: _payloadNewThought,
    );
  }

  // ==================== 调度逻辑 ====================

  /// 使用 zonedSchedule 进行精确调度
  static Future<void> scheduleDailyReminder() async {
    final enabled = await isEnabled();
    if (!enabled) {
      await notifications.cancelAll();
      debugPrint('[Notification] 通知已禁用，取消所有通知');
      return;
    }

    final title = await getTitle();
    final content = await getContent();
    final hour = await getHour();
    final minute = await getMinute();

    debugPrint('[Notification] 开始调度: 时间=${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}, 标题=$title');

    // 先取消旧的定时通知
    await notifications.cancel(_dailyReminderId);
    await notifications.cancel(2); // 也取消备用 ID
    debugPrint('[Notification] 已取消旧通知');

    // 计算目标时间点
    final now = tz.TZDateTime.now(tz.local);
    var target = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // 如果目标时间已过，推迟到明天
    if (target.isBefore(now) || target.isAtSameMomentAs(now)) {
      target = target.add(const Duration(days: 1));
      debugPrint('[Notification] 目标时间已过，推迟到明天: ${target.toLocal()}');
    } else {
      debugPrint('[Notification] 目标时间: ${target.toLocal()}');
    }

    // 方案1: 尝试精确调度
    bool success = false;
    try {
      await notifications.zonedSchedule(
        _dailyReminderId,
        title,
        content,
        target,
        _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: _payloadNewThought,
      );
      success = true;
      debugPrint('[Notification] zonedSchedule(exact) 调用成功');
    } catch (e) {
      debugPrint('[Notification] zonedSchedule(exact) 失败: $e');
    }

    // 方案2: 如果精确调度失败，使用 periodicallyShow 作为备用
    if (!success) {
      try {
        debugPrint('[Notification] 尝试 periodicallyShow 备用方案...');
        await notifications.periodicallyShow(
          2,
          title,
          content,
          RepeatInterval.daily,
          _notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: _payloadNewThought,
        );
        debugPrint('[Notification] periodicallyShow 调用成功（备用方案）');
      } catch (e) {
        debugPrint('[Notification] periodicallyShow 也失败: $e');
      }
    }
  }

}

/// 权限引导弹窗（通知、相册、使用情况、文件、快捷方式）
Future<void> showPermissionDialog(BuildContext context) async {
  final notifGranted = await Permission.notification.status.isGranted;
  final photoGranted = await Permission.photos.status.isGranted ||
      await Permission.storage.status.isGranted;

  if (notifGranted && photoGranted) return;

  if (!context.mounted) return;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: ZoosyTheme.surfaceOf(ctx), surfaceTintColor: Colors.transparent,
      title: Text('权限申请', style: TextStyle(color: ZoosyTheme.textDarkOf(ctx))),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('为了提供完整的使用体验，Zoosy 需要以下权限：', style: TextStyle(fontSize: 13, color: ZoosyTheme.textMutedOf(ctx))),
        const SizedBox(height: 16),
        if (!notifGranted) const _PermissionItem(Icons.notifications_outlined, '通知', '用于每日思考提醒'),
        if (!photoGranted) const _PermissionItem(Icons.photo_library_outlined, '相册', '用于更换头像'),
        const _PermissionItem(Icons.timer_outlined, '应用使用情况', '用于屏幕使用时长提醒'),
        const _PermissionItem(Icons.description_outlined, '读写文件', '用于导出和备份数据'),
        const _PermissionItem(Icons.add_box_outlined, '桌面快捷方式', '用于快速记录想法'),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('稍后')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await NotificationService.requestAllPermissions();
          },
          style: ElevatedButton.styleFrom(backgroundColor: ZoosyTheme.primary),
          child: const Text('允许', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  if (!await ScreenTimeService.hasPermission()) {
    ScreenTimeService.requestPermission();
  }
}

class _PermissionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _PermissionItem(this.icon, this.title, this.desc);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, size: 22, color: ZoosyTheme.primary),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          Text(desc, style: const TextStyle(fontSize: 11, color: ZoosyTheme.textMuted)),
        ]),
      ]),
    );
  }
}
