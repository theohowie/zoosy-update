import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'prefs_util.dart';

/// 多语言管理服务
///
/// 负责语言偏好（locale code）的读取/保存与系统语言解析。
/// UI 文案翻译已迁移至 gen-l10n（AppLocalizations / context.l10n），
/// 本服务仅保留语言状态管理与切换通知。
class TranslationService {
  static String _currentLocale = 'system';

  /// 语言切换通知：setLocale 后触发，值为切换后的 locale code（如 'zh'/'en'/'system'）。
  /// 供 App 根组件监听并更新 MaterialApp.locale，实现全 App 即时生效。
  static final ValueNotifier<String> localeNotifier = ValueNotifier<String>('');

  static Future<void> init() async {
    _currentLocale = await PrefsUtil.getLocale();
  }

  static String get currentLocale {
    if (_currentLocale == 'system') {
      try {
        final lang = Platform.localeName;
        if (lang.startsWith('zh')) {
          if (lang.contains('TW') || lang.contains('HK') || lang.contains('MO')) return 'zh_TW';
          return 'zh';
        }
        if (lang.startsWith('en')) return 'en';
        if (lang.startsWith('de')) return 'de';
        if (lang.startsWith('fr')) return 'fr';
        if (lang.startsWith('ja')) return 'ja';
        if (lang.startsWith('ko')) return 'ko';
        if (lang.startsWith('ru')) return 'ru';
        if (lang.startsWith('th')) return 'th';
      } catch (_) {}
      return 'zh';
    }
    return _currentLocale;
  }

  static Future<void> setLocale(String code) async {
    _currentLocale = code;
    localeNotifier.value = code;
    await PrefsUtil.setLocale(code);
  }
}
