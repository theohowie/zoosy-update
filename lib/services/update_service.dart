import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// 版本信息
class UpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  final String changelog;

  const UpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    this.changelog = '',
  });
}

/// 检查更新服务
///
/// 版本信息托管在 GitHub 仓库的 version.json 文件中：
/// https://raw.githubusercontent.com/<user>/<repo>/main/version.json
///
/// 文件格式：
/// {
///   "version": "1.11.0",
///   "url": "https://github.com/xxx/zoosy/releases/download/v1.11.0/app-release.apk",
///   "changelog": "更新内容..."
/// }
class UpdateService {
  // ====== 配置：修改为你的 GitHub 仓库地址 ======
  static const String _versionFileUrl =
      'https://raw.githubusercontent.com/hwt3202958058-arch/zoosy/main/version.json';

  /// 检查是否有新版本
  /// 返回 null 表示已是最新，否则返回更新信息
  static Future<UpdateInfo?> checkUpdate() async {
    try {
      final response = await http.get(
        Uri.parse(_versionFileUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final latestVersion = json['version'] as String? ?? '';
      final downloadUrl = json['url'] as String? ?? '';
      final changelog = json['changelog'] as String? ?? '';

      if (latestVersion.isEmpty || downloadUrl.isEmpty) return null;

      final currentVersion = await _getCurrentVersion();

      if (_isNewer(latestVersion, currentVersion)) {
        return UpdateInfo(
          latestVersion: latestVersion,
          downloadUrl: downloadUrl,
          changelog: changelog,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 获取当前 App 版本号
  static Future<String> _getCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// 比较版本号：返回 latest 是否比 current 新
  /// 支持 x.y.z 格式，例如 "1.11.0" > "1.10.6"
  static bool _isNewer(String latest, String current) {
    final latestParts = latest.split('.').map(int.tryParse).whereType<int>().toList();
    final currentParts = current.split('.').map(int.tryParse).whereType<int>().toList();

    for (var i = 0; i < 3; i++) {
      final l = i < latestParts.length ? latestParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }
}
