import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/reflection.dart';
import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'prefs_util.dart';

class ThemeService {
  static const _colorKey = 'theme_color';
  static const _modeKey = 'theme_mode';

  // 预设主题色
  static const List<Color> presetColors = [
    Color(0xFF4828C8), // 紫色（默认）
    Color(0xFFE91E63), // 粉色
    Color(0xFF4CAF50), // 绿色
    Color(0xFFFF9800), // 橙色
    Color(0xFF2196F3), // 蓝色
    Color(0xFF9C27B0), // 紫罗兰
    Color(0xFF00BCD4), // 青色
    Color(0xFFF44336), // 红色
  ];

  static const List<String> presetNames = [
    '思考紫', '心动粉', '宁静绿', '温暖橙',
    '忧郁蓝', '梦幻紫', '清新青', '热情红',
  ];

  static Future<Color> getColor() async {
    final prefs = await PrefsUtil.get();
    final value = prefs.getInt(_colorKey);
    if (value != null) return Color(value);
    return const Color(0xFF4828C8); // 默认紫色
  }

  static Future<void> setColor(Color color) async {
    final prefs = await PrefsUtil.get();
    await prefs.setInt(_colorKey, color.value);
  }

  static Future<ThemeMode> getMode() async {
    final prefs = await PrefsUtil.get();
    final value = prefs.getString(_modeKey);
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static Future<void> setMode(ThemeMode mode) async {
    final prefs = await PrefsUtil.get();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    await prefs.setString(_modeKey, value);
  }

  static String modeName(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => appL10n().light_mode,
      ThemeMode.dark => appL10n().dark_mode,
      ThemeMode.system => appL10n().system_default,
    };
  }

  /// 根据主题色返回对应的 Logo 资源路径
  static String logoAssetForColor(Color color) {
    const map = <int, String>{
      0xFF4828C8: 'assets/images/logo.png',   // 思考紫 → 默认（PNG）
      0xFFE91E63: 'assets/images/logo1.jpg',   // 心动粉
      0xFF4CAF50: 'assets/images/logo2.jpg',   // 宁静绿
      0xFFFF9800: 'assets/images/logo3.jpg',   // 温暖橙
      0xFF2196F3: 'assets/images/logo4.jpg',   // 忧郁蓝
      0xFF9C27B0: 'assets/images/logo5.jpg',   // 梦幻紫
      0xFF00BCD4: 'assets/images/logo6.jpg',   // 清新青
      0xFFF44336: 'assets/images/logo7.jpg',   // 热情红
    };
    return map[color.value] ?? 'assets/images/logo.png';
  }

  /// 当前主题色对应的 Logo 资源路径（便捷方法）
  static String get currentLogoAsset => logoAssetForColor(ZoosyTheme.primary);

  /// 获取主题色对应的桌面图标索引（0=默认，1~7=logo1~logo7）
  static int iconIndexForColor(Color color) {
    const map = <int, int>{
      0xFF4828C8: 0,  // 思考紫 → 默认
      0xFFE91E63: 1,  // 心动粉 → logo1
      0xFF4CAF50: 2,  // 宁静绿 → logo2
      0xFFFF9800: 3,  // 温暖橙 → logo3
      0xFF2196F3: 4,  // 忧郁蓝 → logo4
      0xFF9C27B0: 5,  // 梦幻紫 → logo5
      0xFF00BCD4: 6,  // 清新青 → logo6
      0xFFF44336: 7,  // 热情红 → logo7
    };
    return map[color.value] ?? 0;
  }

  /// 通过 MethodChannel 切换 Android 桌面图标
  static Future<void> setAppIcon(Color color) async {
    try {
      const channel = MethodChannel('zoosy/app_icon');
      final index = iconIndexForColor(color);
      await channel.invokeMethod('setIcon', index);
    } catch (e) {
      debugPrint('[ThemeService] 切换桌面图标失败: $e');
    }
  }
}
