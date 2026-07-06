import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 快捷键服务：监听硬件按键组合快速打开新建思考
class ShortcutService {
  static const _channel = MethodChannel('zoosy/shortcut');
  static const _eventChannel = EventChannel('zoosy/shortcut_events');
  static const _enabledKey = 'shortcut_enabled';
  static const _modeKey = 'shortcut_mode'; // 'volume' or 'power'

  /// 快捷键模式
  static const String modeVolume = 'volume';
  static const String modePower = 'power';

  /// 当前激活的模式
  static String? _activeMode;

  /// 初始化并恢复上次设置
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? false;
    final mode = prefs.getString(_modeKey);

    if (enabled && mode != null) {
      await start(mode);
    }
  }

  /// 启动快捷键监听
  static Future<bool> start(String mode) async {
    try {
      await _channel.invokeMethod('startShortcut', {'mode': mode});
      _activeMode = mode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, true);
      await prefs.setString(_modeKey, mode);
      return true;
    } catch (e) {
      debugPrint('[Shortcut] 启动失败: $e');
      return false;
    }
  }

  /// 停止快捷键监听
  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopShortcut');
    } catch (_) {}
    _activeMode = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
  }

  /// 是否已启用
  static bool get isRunning => _activeMode != null;

  /// 当前模式
  static String? get activeMode => _activeMode;

  /// 获取上次设置
  static Future<String?> getSavedMode() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? false;
    if (!enabled) return null;
    return prefs.getString(_modeKey);
  }

  /// 监听快捷键触发的流（由 Native 端发送事件）
  static final shortcutTriggered = _eventChannel
      .receiveBroadcastStream()
      .map((_) {}); // 收到事件即触发
}
