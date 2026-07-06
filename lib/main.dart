import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/reflection.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'services/translation_service.dart';
import 'services/notification_service.dart';
import 'screens/home/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/main_navigation.dart';
import 'screens/thoughts/new_reflection_screen.dart';
import 'services/shortcut_service.dart';
import 'services/prefs_util.dart';
import 'services/screen_time_service.dart';
import 'services/trash_service.dart';
import 'package:home_widget/home_widget.dart';

final MethodChannel _zoosyWidgetChannel = MethodChannel('zoosy/widget_update');

/// 全局导航键，用于通知点击等需要在任意位置导航的场景
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 通知触发的添加思考回调（由 App 启动时设置）
Function(Reflection)? onNotifAddReflection;

/// 更新小组件数据 — 在第一个 await 前冻结 reflections 副本，避免异步竞争
Future<void> updateWidgetData(List<Reflection> srcReflections) async {
  // ★ 在第一个 await 之前就冻结数据
  final reflections = List<Reflection>.from(srcReflections);
  final count = reflections.length;
  try {
  final themeColor = '#${ZoosyTheme.primary.value.toRadixString(16).padLeft(8, '0').substring(2)}';

  // 读取用户已保存的样式偏好
  String savedStyle;
  String savedLabel;
  try {
    savedStyle = (await HomeWidget.getWidgetData<String>('style')) ?? 'style3';
    savedLabel = (await HomeWidget.getWidgetData<String>('widget_label')) ?? '总共思考';
  } catch (_) {
    savedStyle = 'style3';
    savedLabel = '总共思考';
  }

  // 计算今日条数 + 连续记录天数
  int todayCount = 0;
  int streak = 0;
  if (reflections.isNotEmpty) {
    final sorted = List<Reflection>.from(reflections)..sort((a, b) => '${b.date} ${b.time}'.compareTo('${a.date} ${a.time}'));
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';
    todayCount = sorted.where((r) => r.date == todayStr).length;
    var check = todayStr;
    for (final r in sorted) {
      if (r.date == check) { streak++; check = _prevDate(check); } else break;
    }
  }

  debugPrint('[Widget] updateWidgetData: count=$count today=$todayCount streak=$streak');

  // ★ 全部通过 HomeWidget.saveWidgetData 写入 SP
  await HomeWidget.saveWidgetData('cnt', count.toString());
  await HomeWidget.saveWidgetData('today_cnt', todayCount.toString());
  await HomeWidget.saveWidgetData('current_streak', streak.toString());
  await HomeWidget.saveWidgetData('style', savedStyle);
  await HomeWidget.saveWidgetData('widget_label', savedLabel);
  await HomeWidget.saveWidgetData('theme_color', themeColor);
  await HomeWidget.saveWidgetData('tc', themeColor);
  // 保存主题对应的 logo 索引（0=默认，1~7=logo1~logo7）
  await HomeWidget.saveWidgetData('logo_index', ThemeService.iconIndexForColor(ZoosyTheme.primary).toString());

  if (reflections.isNotEmpty) {
    final sorted = List<Reflection>.from(reflections)..sort((a, b) => '${b.date} ${b.time}'.compareTo('${a.date} ${a.time}'));
    final first = sorted.first;
    await HomeWidget.saveWidgetData('rt', first.title);
    var content = first.content;
    if (content.length > 72) content = '${content.substring(0, 72)}...';
    await HomeWidget.saveWidgetData('rc', content);
    await HomeWidget.saveWidgetData('rd', _formatWidgetDate(first.date, first.time));
    final recentList = sorted.take(5).map((r) => {
      'title': r.title,
      'content': r.content.length > 72 ? '${r.content.substring(0, 72)}...' : r.content,
      'date': _formatWidgetDate(r.date, r.time),
    }).toList();
    await HomeWidget.saveWidgetData('recent_list_json', jsonEncode(recentList));
    debugPrint('[Widget] saved recent: title=${first.title}');
  } else {
    await HomeWidget.saveWidgetData('rt', '');
    await HomeWidget.saveWidgetData('rc', '开始记录你的第一个思考吧～');
    await HomeWidget.saveWidgetData('rd', '');
    await HomeWidget.saveWidgetData('recent_list_json', '[]');
  }

  // 触发小组件刷新
  try {
    await HomeWidget.updateWidget(androidName: 'ZoosyWidgetProvider');
    debugPrint('[Widget] HomeWidget.updateWidget 成功');
  } catch (e) {
    debugPrint('[Widget] HomeWidget.updateWidget 失败: $e');
  }

  // 直通通道强刷
  try {
    await _zoosyWidgetChannel.invokeMethod('updateWidget', {
      'cnt': count.toString(),
      'today_cnt': todayCount.toString(),
      'current_streak': streak.toString(),
      'style': savedStyle,
      'widget_label': savedLabel,
      'tc': themeColor,
      'logo_index': ThemeService.iconIndexForColor(ZoosyTheme.primary).toString(),
      'rt': reflections.isNotEmpty ? firstTitle(reflections) : '',
      'rc': reflections.isNotEmpty ? firstContent(reflections) : '',
      'rd': reflections.isNotEmpty ? firstDate(reflections) : '',
      'last_updated': DateTime.now().millisecondsSinceEpoch.toString(),
    });
    debugPrint('[Widget] 直通通道成功');
  } catch (e) {
    debugPrint('[Widget] 直通通道失败: $e');
  }
  } catch (e, stack) {
    debugPrint('[Widget] updateWidgetData 异常: $e\n$stack');
  }
}

// 辅助函数：取最近思考的标题
String firstTitle(List<Reflection> list) {
  final sorted = List<Reflection>.from(list)..sort((a, b) => '${b.date} ${b.time}'.compareTo('${a.date} ${a.time}'));
  return sorted.first.title;
}

// 辅助函数：取最近思考的内容（截断）
String firstContent(List<Reflection> list) {
  final sorted = List<Reflection>.from(list)..sort((a, b) => '${b.date} ${b.time}'.compareTo('${a.date} ${a.time}'));
  var c = sorted.first.content;
  if (c.length > 72) c = '${c.substring(0, 72)}...';
  return c;
}

// 辅助函数：取最近思考的日期
String firstDate(List<Reflection> list) {
  final sorted = List<Reflection>.from(list)..sort((a, b) => '${b.date} ${b.time}'.compareTo('${a.date} ${a.time}'));
  return _formatWidgetDate(sorted.first.date, sorted.first.time);
}

String _prevDate(String d) {
  final dt = DateTime.parse(d).subtract(const Duration(days: 1));
  return '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
}

/// 将日期时间格式化为小组件友好显示：例如 "2026年6月16日 10:30"
String _formatWidgetDate(String date, String time) {
  try {
    final parts = date.split('-');
    if (parts.length == 3) {
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final d = int.parse(parts[2]);
      return '$y年${m}月${d}日 $time';
    }
  } catch (_) {}
  return '$date $time';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化通知（捕获异常防止热重启时崩溃）
  try {
    await NotificationService.init();
    // 初始化屏幕使用时长提醒（注入 notifications 实例）
    ScreenTimeService.init(NotificationService.notifications);
    if (await ScreenTimeService.isEnabled()) {
      ScreenTimeService.start();
    }
  } catch (e) {
    debugPrint('[App] 通知初始化失败: $e');
  }

  runApp(const ZoosyApp());

  // 通知点击回调：打开新建思考页
  NotificationService.onNotificationTap = () {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => NewReflectionScreen(onSave: (ref) async {
        // 标记今天已记录，避免重复通知
        await NotificationService.markRecordedToday();
        onNotifAddReflection?.call(ref);
      })),
    );
  };

  // 小组件快捷按钮点击回调
  ShortcutService.shortcutTriggered.listen((_) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => NewReflectionScreen(onSave: (ref) {
        onNotifAddReflection?.call(ref);
      })),
    );
  });
}

class ZoosyApp extends StatefulWidget {
  const ZoosyApp({Key? key}) : super(key: key);

  @override
  State<ZoosyApp> createState() => _ZoosyAppState();
}

class _ZoosyAppState extends State<ZoosyApp> {
  bool _isLoggedIn = false;
  bool _splashDone = false;
  bool _loadingData = true;
  Color _themeColor = const Color(0xFF4828C8);
  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;

  List<Reflection> reflections = [];
  static const _reflectionsKey = 'local_reflections';

  /// 将思考列表持久化到本地 SharedPreferences
  Future<void> _saveReflectionsLocally() async {
    try {
      final prefs = await PrefsUtil.get();
      final jsonList = reflections.map((r) => {'id': r.id, ...r.toFirestore()}).toList();
      await prefs.setString(_reflectionsKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[LocalStore] 保存思考失败: $e');
    }
  }

  /// 从本地 SharedPreferences 加载思考列表
  Future<List<Reflection>> _loadReflectionsLocally() async {
    try {
      final prefs = await PrefsUtil.get();
      final jsonStr = prefs.getString(_reflectionsKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.map((j) => Reflection.fromFirestore(j['id'] as String, Map<String, dynamic>.from(j))).toList();
    } catch (e) {
      debugPrint('[LocalStore] 加载思考失败: $e');
      return [];
    }
  }

  // Mock 示例数据（仅首次无本地数据时使用）
  static List<Reflection> _mockReflections = [
    Reflection(id: 'ref-1', title: '工作汇报后的反思', content: '今天完成了工作总结。整体来说还算顺利，但有些细节处理得不够好。同事们给了我一些建设性反馈，反而让我解开了一些困惑。下次需要准备得更充分！', date: '2026-06-16', time: '10:30', tags: ['工作', '反思'], isFavorite: true, aiSummary: '你在协作中找到了清晰的方向。即使有小挫折，你对改进的关注和接受反馈的态度正在加速你的职业成长。', emotions: ['工作', '专注', '成长', '洞察']),
    Reflection(id: 'ref-2', title: '和朋友的午餐时光', content: '和高中老朋友在市中心吃了一顿愉快的午餐。我们尝试了一家热门意大利餐厅，回忆往事笑得停不下来。这次聚会给我的社交电池充满电，也让我更加珍惜这些长久的友谊。', date: '2026-06-15', time: '12:20', tags: ['生活', '家庭'], isFavorite: false, aiSummary: '与信任的圈子建立联系能带来深层的情感滋养。珍惜关系和共同回忆为你的日常生活增添了宝贵的快乐。', emotions: ['社交', '生活', '洞察']),
    Reflection(id: 'ref-3', title: '晚上散步的时间', content: '晚上九点左右在附近的公园安静地走了半小时。空气凉爽清新，没有听播客也没有听音乐，只是让思绪自由飘荡，看着路灯。之后感觉非常踏实和平静。', date: '2026-06-14', time: '21:45', tags: ['生活', '健康'], isFavorite: false, aiSummary: '有意识地在自然中独处是一种强大的感官重置。断开外界输入让你的潜意识得以沉淀，恢复重要的情感储备。', emotions: ['平静', '安静', '洞察']),
    Reflection(id: 'ref-4', title: '周末的旅行计划', content: '研究了一些沿海小镇，准备下个月来一次周末公路旅行。挑选了三家不错的民宿并规划了一条风景优美的路线。其实规划旅行本身带来的快乐几乎和旅行一样多！', date: '2026-06-14', time: '22:10', tags: ['生活', '思考'], isFavorite: false, aiSummary: '期待中的快乐是一种强大的情感驱动力。想象积极的未来里程碑能培养乐观心态，拓展你的心理视野。', emotions: ['创意', '生活']),
    Reflection(id: 'ref-5', title: '关于设计系统的深思', content: '审查了我们团队的 UI 组件系统，发现间距和排版上存在一些不一致。起草了一份简短的建议，主张使用超椭圆或圆角矩形约束来给布局带来有机的、以人为本的视觉节奏。', date: '2026-06-13', time: '09:00', tags: ['工作', '思考'], isFavorite: false, aiSummary: '审美秩序为用户创造情感上的舒适。你使用生物圆角而非工业直角的直觉，将技术工艺与纯粹心理学完美结合。', emotions: ['工作', '专注', '思考']),
  ];

  List<NotificationItem> notifications = [
    NotificationItem(id: 'notif-1', title: 'Zoosy', content: '思考时间到啦! 现在有什么想法想要记录下来吗?', time: '刚刚', type: 'general', icon: Icons.smart_toy_outlined),
    NotificationItem(id: 'notif-2', title: '回顾时刻', content: '你错过了昨天的记录。现在来补上吧!', time: '1小时前', type: 'reminder', icon: Icons.chevron_right),
    NotificationItem(id: 'notif-3', title: '持续里程碑', content: '你已经连续坚持思考 7 天了! 太棒了!', time: '昨天', type: 'milestone', icon: Icons.celebration_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _loadLocale();
    TranslationService.init();
    _checkAuth();
    // 初始化状态栏样式
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSystemUIOverlay(_themeMode);
    });

    onNotifAddReflection = addReflection;

    // 初始化时刷新小组件数据（传快照防止异步竞争）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (reflections.isNotEmpty) {
        updateWidgetData(List<Reflection>.from(reflections));
      }
    });
  }

  Future<void> _loadTheme() async {
    final color = await ThemeService.getColor();
    final mode = await ThemeService.getMode();
    ZoosyTheme.setPrimary(color);
    if (mounted) setState(() { _themeColor = color; _themeMode = mode; });
    _updateSystemUIOverlay(mode);
  }

  /// 根据主题模式设置状态栏图标颜色
  void _updateSystemUIOverlay(ThemeMode mode) {
    final brightness = (mode == ThemeMode.dark)
        ? Brightness.dark
        : (mode == ThemeMode.light ? Brightness.light : WidgetsBinding.instance.platformDispatcher.platformBrightness);
    final isDark = brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    ));
  }

  Future<void> _loadLocale() async {
    final code = await PrefsUtil.getLocale();
    if (code == 'system') {
      if (mounted) setState(() => _locale = null);
      return;
    }
    final parts = code.split('_');
    if (mounted) {
      setState(() {
        _locale = parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
      });
    }
  }

  void _onThemeChanged() async {
    _loadTheme();
    final mode = await ThemeService.getMode();
    _updateSystemUIOverlay(mode);
    // 主题色变更后同步更新桌面小组件
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (reflections.isNotEmpty) {
        updateWidgetData(List<Reflection>.from(reflections));
      }
    });
  }

  Future<void> _checkAuth() async {
    // 本地模式：检查 SharedPreferences
    final email = await AuthService.getLoggedInEmail();
    if (email != null) {
      // 优先从本地持久化加载真实数据
      final localData = await _loadReflectionsLocally();
      if (localData.isNotEmpty) {
        reflections = localData;
      } else {
        // 首次使用：用 Mock 数据作为示例
        reflections = List.from(_mockReflections);
      }
    }
    if (mounted) setState(() { _isLoggedIn = email != null; _loadingData = false; });
    // 数据就绪后立即刷新小组件
    if (reflections.isNotEmpty) {
      final snapshot = List<Reflection>.from(reflections);
      await HomeWidget.saveWidgetData('cnt', snapshot.length.toString());
      await updateWidgetData(snapshot);
    }
    debugPrint('[Auth] pre-updateWidgetData reflections.length=${reflections.length}');
  }

  Future<void> addReflection(Reflection ref) async {
    setState(() => reflections.insert(0, ref));
    await _saveReflectionsLocally();
    await updateWidgetData(List<Reflection>.from(reflections));
  }

  Future<void> toggleFavorite(String id) async {
    setState(() {
      for (var r in reflections) {
        if (r.id == id) { r.isFavorite = !r.isFavorite; }
      }
    });
    await _saveReflectionsLocally();
  }

  Future<void> deleteReflection(String id) async {
    final ref = reflections.firstWhere((r) => r.id == id, orElse: () => Reflection(id: '', title: '', content: '', date: '', time: '', tags: []));
    if (ref.id.isNotEmpty) {
      await TrashService.moveToTrash(ref);
    }
    setState(() => reflections.removeWhere((r) => r.id == id));
    await _saveReflectionsLocally();
    await updateWidgetData(List<Reflection>.from(reflections));
  }

  Future<void> deleteReflections(List<String> ids) async {
    for (final id in ids) {
      final ref = reflections.firstWhere((r) => r.id == id, orElse: () => Reflection(id: '', title: '', content: '', date: '', time: '', tags: []));
      if (ref.id.isNotEmpty) {
        await TrashService.moveToTrash(ref);
      }
    }
    setState(() => reflections.removeWhere((r) => ids.contains(r.id)));
    await _saveReflectionsLocally();
    await updateWidgetData(List<Reflection>.from(reflections));
  }

  Future<void> restoreFromTrash(Reflection ref) async {
    setState(() => reflections.insert(0, ref));
    await _saveReflectionsLocally();
    await updateWidgetData(List<Reflection>.from(reflections));
  }

  Future<void> updateReflection(Reflection updated) async {
    setState(() {
      final idx = reflections.indexWhere((r) => r.id == updated.id);
      if (idx >= 0) {
        reflections[idx] = updated;
      } else {
        reflections.insert(0, updated);
      }
    });
    await _saveReflectionsLocally();
    await updateWidgetData(List<Reflection>.from(reflections));
  }

  void _onSplashCompleted() async {
    // 启动结束，显示主界面
    if (mounted) setState(() => _splashDone = true);
  }

  void _onLoginSuccess() async {
    // 重新加载本地持久化的思考数据
    final localData = await _loadReflectionsLocally();
    if (mounted) {
      setState(() {
        _isLoggedIn = true;
        if (localData.isNotEmpty) reflections = localData;
      });
    }
    // 登录后弹出权限申请
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) showPermissionDialog(ctx);
    });
  }

  void _onLogout() async {
    AuthService.logout();
    // 登出时保留本地持久化的思考数据，下次登录可继续使用
    if (mounted) setState(() => _isLoggedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = _themeColor;
    final isDark = _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    );
    return MaterialApp(
      title: 'Zoosy',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      locale: _locale,
      supportedLocales: const [Locale('zh'), Locale('zh', 'TW'), Locale('en'), Locale('de'), Locale('fr'), Locale('ja'), Locale('ko'), Locale('ru'), Locale('th')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: _themeMode,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFEF7FF),
        colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary, surface: const Color(0xFFFEF7FF)),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
      ),
      darkTheme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF1E1E2C),
        colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary, brightness: Brightness.dark, surface: const Color(0xFF1E1E2C)),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
      ),
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: child!,
        );
      },
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_loadingData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_splashDone) return SplashScreen(onSplashCompleted: _onSplashCompleted);
    if (!_isLoggedIn) return LoginScreen(onLoginSuccess: _onLoginSuccess, useCloud: false);
    return MainNavigation(
      reflections: reflections, notifications: notifications,
      onAddReflection: addReflection, onToggleFavorite: toggleFavorite,
      onDeleteReflection: deleteReflection, onDeleteReflections: deleteReflections,
      onUpdateReflection: updateReflection,
      onRestoreFromTrash: restoreFromTrash, onLogout: _onLogout, onThemeChanged: _onThemeChanged,
    );
  }
}
