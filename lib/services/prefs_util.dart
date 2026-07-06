import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences 实例缓存
///
/// 避免全工程大量重复调用 SharedPreferences.getInstance()。
/// 在各 Service 的类初始化/首次调用时确保已初始化即可。
class PrefsUtil {
  static SharedPreferences? _instance;

  /// 获取缓存的实例，若未初始化则自动初始化
  static Future<SharedPreferences> get() async {
    _instance ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  /// 强制刷新实例（数据变更后如需立即读取最新值时可调用）
  static Future<void> reload() async {
    _instance = await SharedPreferences.getInstance();
  }

  /// 清空缓存（通常不需要手动调用）
  static void reset() {
    _instance = null;
  }

  // ==========================================================
  //  多语言
  // ==========================================================
  static const _localeKey = 'app_locale';

  static Future<String> getLocale() async {
    final prefs = await get();
    return prefs.getString(_localeKey) ?? 'system';
  }

  static Future<void> setLocale(String code) async {
    final prefs = await get();
    await prefs.setString(_localeKey, code);
  }

  // ==========================================================
  //  搜索历史
  // ==========================================================
  static const _searchHistoryKey = 'search_history';

  /// 加载搜索历史（最多 10 条，最新在前）
  static Future<List<String>> loadSearchHistory() async {
    final prefs = await get();
    final list = prefs.getStringList(_searchHistoryKey);
    return list ?? [];
  }

  /// 添加一条搜索记录（去重，最新在前，上限 10 条）
  static Future<void> addSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await get();
    final list = prefs.getStringList(_searchHistoryKey) ?? [];
    list.remove(query); // 去重
    list.insert(0, query);
    if (list.length > 10) list.removeLast();
    await prefs.setStringList(_searchHistoryKey, list);
  }

  /// 删除单条搜索记录
  static Future<void> removeSearchHistory(String query) async {
    final prefs = await get();
    final list = prefs.getStringList(_searchHistoryKey) ?? [];
    list.remove(query);
    await prefs.setStringList(_searchHistoryKey, list);
  }

  /// 清空全部搜索历史
  static Future<void> clearSearchHistory() async {
    final prefs = await get();
    await prefs.remove(_searchHistoryKey);
  }

  // ==========================================================
  //  自定义标签
  // ==========================================================
  static const _customTagsKey = 'custom_tags';
  static const _defaultTags = ['工作', '生活', '成长', '反思', '思考', '健康'];

  /// 加载自定义标签（无数据时返回默认列表）
  static Future<List<String>> loadCustomTags() async {
    final prefs = await get();
    final list = prefs.getStringList(_customTagsKey);
    if (list == null || list.isEmpty) return List.from(_defaultTags);
    return list;
  }

  /// 保存自定义标签
  static Future<void> saveCustomTags(List<String> tags) async {
    final prefs = await get();
    await prefs.setStringList(_customTagsKey, tags);
  }

  // ==========================================================
  //  思考定位设置
  // ==========================================================
  static const _locationEnabledKey = 'thought_location_enabled';

  /// 获取是否启用思考定位
  static Future<bool> isLocationEnabled() async {
    final prefs = await get();
    return prefs.getBool(_locationEnabledKey) ?? true; // 默认开启
  }

  /// 设置是否启用思考定位
  static Future<void> setLocationEnabled(bool enabled) async {
    final prefs = await get();
    await prefs.setBool(_locationEnabledKey, enabled);
  }

  // ==========================================================
  //  导航栏样式
  // ==========================================================
  static const _navBarStyleKey = 'nav_bar_style';

  /// 获取导航栏样式：'default' 或 'floating'
  static Future<String> getNavBarStyle() async {
    final prefs = await get();
    return prefs.getString(_navBarStyleKey) ?? 'default';
  }

  /// 设置导航栏样式
  static Future<void> setNavBarStyle(String style) async {
    final prefs = await get();
    await prefs.setString(_navBarStyleKey, style);
  }
}
