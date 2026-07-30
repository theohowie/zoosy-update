import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 屏幕使用时长服务（仅保留权限检查功能）
class ScreenTimeService {
  static const _channel = MethodChannel('zoosy/screen_time');

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
}
