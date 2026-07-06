import 'package:shared_preferences/shared_preferences.dart';

class PageSettings {
  static const _tagDistributionKey = 'page_show_tag_distribution';

  /// 标签分布是否显示
  static Future<bool> showTagDistribution() async {
    return (await SharedPreferences.getInstance()).getBool(_tagDistributionKey) ?? true;
  }

  static Future<void> setShowTagDistribution(bool v) async {
    await (await SharedPreferences.getInstance()).setBool(_tagDistributionKey, v);
  }
}
