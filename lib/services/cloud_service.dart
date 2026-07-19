import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/reflection.dart';
import 'prefs_util.dart';

/// WebDAV 云同步服务
///
/// 支持坚果云、NextCloud、自建 WebDAV 服务器等。
class CloudService {
  static const _serverKey = 'webdav_server';
  static const _usernameKey = 'webdav_username';
  static const _passwordKey = 'webdav_password';
  static const _backupFile = 'zoosy_reflections.json';

  /// 获取 WebDAV 配置
  static Future<Map<String, String>> getConfig() async {
    final prefs = await PrefsUtil.get();
    return {
      'server': prefs.getString(_serverKey) ?? '',
      'username': prefs.getString(_usernameKey) ?? '',
      'password': prefs.getString(_passwordKey) ?? '',
    };
  }

  /// 保存 WebDAV 配置
  static Future<void> saveConfig({
    required String server,
    required String username,
    required String password,
  }) async {
    final prefs = await PrefsUtil.get();
    await prefs.setString(_serverKey, server);
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_passwordKey, password);
  }

  /// 创建自定义 HttpClient（跳过 SSL 验证）
  static IOClient _createClient() {
    final ioClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    ioClient.connectionTimeout = const Duration(seconds: 30);
    return IOClient(ioClient);
  }

  /// 生成 Basic Auth 头
  static Map<String, String> _authHeaders() {
    return {}; // 在各方法中单独构建
  }

  /// 测试连接
  static Future<String?> testConnection() async {
    try {
      final config = await getConfig();
      if (config['server']!.isEmpty) return '未配置服务器';

      final client = _createClient();
      final url = Uri.parse(config['server']!);

      final response = await client.send(http.Request('PROPFIND', url)
        ..headers['Authorization'] = _basicAuth(config['username']!, config['password']!)
        ..headers['Depth'] = '0')
        .timeout(const Duration(seconds: 30));

      client.close();

      if (response.statusCode == 207 || response.statusCode == 200) {
        return null;
      }
      return '连接失败: ${response.statusCode}';
    } catch (e) {
      return '连接失败: $e';
    }
  }

  /// 上传备份到云端
  static Future<String?> upload(List<Reflection> reflections) async {
    try {
      final config = await getConfig();
      if (config['server']!.isEmpty) return '未配置服务器';

      final data = {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'reflections': reflections.map((r) => {
          'id': r.id,
          ...r.toFirestore(),
        }).toList(),
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final bytes = utf8.encode(jsonStr);

      final client = _createClient();
      final serverUrl = config['server']!.endsWith('/') ? config['server']! : '${config['server']!}/';
      final url = Uri.parse('${serverUrl}$_backupFile');

      final request = http.Request('PUT', url)
        ..headers['Authorization'] = _basicAuth(config['username']!, config['password']!)
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..headers['Content-Length'] = bytes.length.toString()
        ..bodyBytes = bytes;

      final response = await client.send(request).timeout(const Duration(seconds: 30));
      client.close();

      if (response.statusCode == 201 || response.statusCode == 204 || response.statusCode == 200) {
        return null;
      }
      // 如果 404，可能是目录不存在，尝试创建后重试
      if (response.statusCode == 404) {
        return await _uploadWithMkcol(config, bytes);
      }
      return '上传失败: ${response.statusCode}';
    } catch (e) {
      return '上传失败: $e';
    }
  }

  /// 从云端下载备份
  static Future<List<Reflection>?> download() async {
    try {
      final config = await getConfig();
      if (config['server']!.isEmpty) return null;

      final client = _createClient();
      final serverUrl = config['server']!.endsWith('/') ? config['server']! : '${config['server']!}/';
      final url = Uri.parse('${serverUrl}$_backupFile');

      final request = http.Request('GET', url)
        ..headers['Authorization'] = _basicAuth(config['username']!, config['password']!);

      final response = await client.send(request).timeout(const Duration(seconds: 30));
      client.close();

      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final list = data['reflections'] as List<dynamic>? ?? [];

        return list.map((j) {
          final map = Map<String, dynamic>.from(j);
          final id = map.remove('id') as String? ?? '';
          return Reflection.fromFirestore(id, map);
        }).toList();
      }
      // 如果 404，尝试从 Zoosy 目录下载
      if (response.statusCode == 404) {
        return await _downloadFromZoosyDir(config);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 同步（合并本地和云端数据）
  static Future<SyncResult> sync(List<Reflection> localReflections) async {
    try {
      final config = await getConfig();
      if (config['server']!.isEmpty) {
        return SyncResult(
          reflections: localReflections,
          message: '未配置服务器',
          hasUpdate: false,
        );
      }

      List<Reflection>? cloudReflections;
      try {
        cloudReflections = await download();
      } catch (_) {}

      if (cloudReflections == null || cloudReflections.isEmpty) {
        await upload(localReflections);
        return SyncResult(
          reflections: localReflections,
          message: '首次同步完成',
          hasUpdate: false,
        );
      }

      final merged = _mergeReflections(localReflections, cloudReflections);
      await upload(merged);

      return SyncResult(
        reflections: merged,
        message: '同步完成',
        hasUpdate: merged.length != localReflections.length,
      );
    } catch (e) {
      return SyncResult(
        reflections: localReflections,
        message: '同步失败: $e',
        hasUpdate: false,
      );
    }
  }

  /// 404 时尝试 MKCOL 创建目录后重试上传
  static Future<String?> _uploadWithMkcol(Map<String, String> config, List<int> bytes) async {
    try {
      final client = _createClient();
      final serverUrl = config['server']!.endsWith('/') ? config['server']! : '${config['server']!}/';

      // 尝试创建 Zoosy 目录
      final mkcolUrl = Uri.parse('${serverUrl}Zoosy/');
      final mkcolRequest = http.Request('MKCOL', mkcolUrl)
        ..headers['Authorization'] = _basicAuth(config['username']!, config['password']!);
      await client.send(mkcolRequest).timeout(const Duration(seconds: 15));

      // 重试上传到 Zoosy 目录
      final uploadUrl = Uri.parse('${serverUrl}Zoosy/$_backupFile');
      final request = http.Request('PUT', uploadUrl)
        ..headers['Authorization'] = _basicAuth(config['username']!, config['password']!)
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..bodyBytes = bytes;

      final response = await client.send(request).timeout(const Duration(seconds: 30));
      client.close();

      if (response.statusCode == 201 || response.statusCode == 204 || response.statusCode == 200) {
        return null;
      }
      return '上传失败: ${response.statusCode}';
    } catch (e) {
      return '上传失败: $e';
    }
  }

  /// 从 Zoosy 目录下载
  static Future<List<Reflection>?> _downloadFromZoosyDir(Map<String, String> config) async {
    try {
      final client = _createClient();
      final serverUrl = config['server']!.endsWith('/') ? config['server']! : '${config['server']!}/';
      final url = Uri.parse('${serverUrl}Zoosy/$_backupFile');

      final request = http.Request('GET', url)
        ..headers['Authorization'] = _basicAuth(config['username']!, config['password']!);

      final response = await client.send(request).timeout(const Duration(seconds: 30));
      client.close();

      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final list = data['reflections'] as List<dynamic>? ?? [];

        return list.map((j) {
          final map = Map<String, dynamic>.from(j);
          final id = map.remove('id') as String? ?? '';
          return Reflection.fromFirestore(id, map);
        }).toList();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 合并两组思考记录（去重）
  static List<Reflection> _mergeReflections(
    List<Reflection> local,
    List<Reflection> cloud,
  ) {
    final map = <String, Reflection>{};
    for (final r in cloud) {
      map[r.id] = r;
    }
    for (final r in local) {
      map[r.id] = r;
    }
    return map.values.toList();
  }

  /// 生成 Basic Auth 头值
  static String _basicAuth(String username, String password) {
    final credentials = '$username:$password';
    final bytes = utf8.encode(credentials);
    return 'Basic ${base64Encode(bytes)}';
  }
}

/// 同步结果
class SyncResult {
  final List<Reflection> reflections;
  final String message;
  final bool hasUpdate;

  const SyncResult({
    required this.reflections,
    required this.message,
    required this.hasUpdate,
  });
}
