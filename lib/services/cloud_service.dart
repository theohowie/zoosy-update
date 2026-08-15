import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/reflection.dart';
import 'prefs_util.dart';

/// WebDAV 云同步服务
class CloudService {
  static const _serverKey = 'webdav_server';
  static const _usernameKey = 'webdav_username';
  static const _passwordKey = 'webdav_password';
  static const _autoSyncKey = 'webdav_auto_sync_interval';
  static const _backupFile = 'zoosy_reflections.json';

  static Timer? _autoSyncTimer;
  static Function(List<Reflection>)? _onAutoSync;
  static List<Reflection> Function()? _getReflections;

  // ==================== 配置 ====================

  static Future<Map<String, String>> getConfig() async {
    final prefs = await PrefsUtil.get();
    return {
      'server': prefs.getString(_serverKey) ?? '',
      'username': prefs.getString(_usernameKey) ?? '',
      'password': prefs.getString(_passwordKey) ?? '',
    };
  }

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

  static Future<bool> isConfigured() async {
    final config = await getConfig();
    return config['server']!.isNotEmpty &&
        config['username']!.isNotEmpty &&
        config['password']!.isNotEmpty;
  }

  // ==================== 自动同步 ====================

  static Future<int> getAutoSyncInterval() async {
    final prefs = await PrefsUtil.get();
    return prefs.getInt(_autoSyncKey) ?? 0;
  }

  static Future<void> setAutoSyncInterval(int minutes) async {
    final prefs = await PrefsUtil.get();
    await prefs.setInt(_autoSyncKey, minutes);
  }

  static void startAutoSync({
    required List<Reflection> Function() getReflections,
    required Function(List<Reflection>) onSynced,
  }) async {
    await stopAutoSync();

    final interval = await getAutoSyncInterval();
    if (interval <= 0) return;

    final configured = await isConfigured();
    if (!configured) return;

    _getReflections = getReflections;
    _onAutoSync = onSynced;

    _autoSyncTimer = Timer.periodic(Duration(minutes: interval), (_) async {
      try {
        final reflections = _getReflections?.call() ?? [];
        final result = await sync(reflections);
        if (result.hasUpdate) {
          _onAutoSync?.call(result.reflections);
          debugPrint('[AutoSync] 同步完成，${result.reflections.length} 条');
        }
      } catch (e) {
        debugPrint('[AutoSync] 同步失败: $e');
      }
    });

    debugPrint('[AutoSync] 已启动，间隔 $interval 分钟');
  }

  static Future<void> stopAutoSync() async {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    _onAutoSync = null;
    _getReflections = null;
  }

  // ==================== HTTP 工具 ====================

  static IOClient _createClient() {
    final ioClient = HttpClient()
      ..badCertificateCallback = (_, __, ___) => true;
    ioClient.connectionTimeout = const Duration(seconds: 30);
    return IOClient(ioClient);
  }

  static String _basicAuth(String username, String password) {
    final bytes = utf8.encode('$username:$password');
    return 'Basic ${base64Encode(bytes)}';
  }

  static String _serverUrl(String server) {
    return server.endsWith('/') ? server : '$server/';
  }

  // ==================== 测试连接 ====================

  static Future<String?> testConnection() async {
    try {
      final config = await getConfig();
      if (config['server']!.isEmpty) return appL10n().cl_not_configured;

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
      return appL10n().cl_conn_failed('${response.statusCode}');
    } catch (e) {
      return appL10n().cl_conn_failed('$e');
    }
  }

  // ==================== 上传 ====================

  static Future<String?> upload(List<Reflection> reflections) async {
    try {
      final config = await getConfig();
      if (config['server']!.isEmpty) return appL10n().cl_not_configured;

      final data = {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'reflections': reflections.map((r) => {
          'id': r.id,
          ...r.toFirestore(),
        }).toList(),
      };

      final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
      final client = _createClient();
      final url = Uri.parse('${_serverUrl(config['server']!)}$_backupFile');

      final response = await client.send(http.Request('PUT', url)
        ..headers['Authorization'] = _basicAuth(config['username']!, config['password']!)
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..bodyBytes = bytes)
        .timeout(const Duration(seconds: 30));

      client.close();

      if (response.statusCode == 201 || response.statusCode == 204 || response.statusCode == 200) {
        return null;
      }
      if (response.statusCode == 404) {
        return await _uploadWithMkcol(config, bytes);
      }
      return appL10n().cl_upload_failed('${response.statusCode}');
    } catch (e) {
      return appL10n().cl_upload_failed('$e');
    }
  }

  static Future<String?> _uploadWithMkcol(Map<String, String> config, List<int> bytes) async {
    try {
      final client = _createClient();
      final base = _serverUrl(config['server']!);
      final auth = _basicAuth(config['username']!, config['password']!);

      await client.send(http.Request('MKCOL', Uri.parse('${base}Zoosy/'))
        ..headers['Authorization'] = auth)
        .timeout(const Duration(seconds: 15));

      final response = await client.send(http.Request('PUT', Uri.parse('${base}Zoosy/$_backupFile'))
        ..headers['Authorization'] = auth
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..bodyBytes = bytes)
        .timeout(const Duration(seconds: 30));

      client.close();

      if (response.statusCode == 201 || response.statusCode == 204 || response.statusCode == 200) {
        return null;
      }
      return appL10n().cl_upload_failed('${response.statusCode}');
    } catch (e) {
      return appL10n().cl_upload_failed('$e');
    }
  }

  // ==================== 下载 ====================

  static Future<List<Reflection>?> download() async {
    try {
      final config = await getConfig();
      if (config['server']!.isEmpty) return null;

      final client = _createClient();
      final url = Uri.parse('${_serverUrl(config['server']!)}$_backupFile');

      final response = await client.send(http.Request('GET', url)
        ..headers['Authorization'] = _basicAuth(config['username']!, config['password']!))
        .timeout(const Duration(seconds: 30));

      client.close();

      if (response.statusCode == 200) {
        return _parseReflections(await response.stream.bytesToString());
      }
      if (response.statusCode == 404) {
        return await _downloadFromZoosyDir(config);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<List<Reflection>?> _downloadFromZoosyDir(Map<String, String> config) async {
    try {
      final client = _createClient();
      final url = Uri.parse('${_serverUrl(config['server']!)}Zoosy/$_backupFile');

      final response = await client.send(http.Request('GET', url)
        ..headers['Authorization'] = _basicAuth(config['username']!, config['password']!))
        .timeout(const Duration(seconds: 30));

      client.close();

      if (response.statusCode == 200) {
        return _parseReflections(await response.stream.bytesToString());
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static List<Reflection> _parseReflections(String jsonStr) {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final list = data['reflections'] as List<dynamic>? ?? [];
    return list.map((j) {
      final map = Map<String, dynamic>.from(j);
      final id = map.remove('id') as String? ?? '';
      return Reflection.fromFirestore(id, map);
    }).toList();
  }

  // ==================== 同步 ====================

  static Future<SyncResult> sync(List<Reflection> localReflections) async {
    try {
      final config = await getConfig();
      if (config['server']!.isEmpty) {
        return SyncResult(reflections: localReflections, message: appL10n().cl_not_configured, hasUpdate: false);
      }

      List<Reflection>? cloudReflections;
      try {
        cloudReflections = await download();
      } catch (_) {}

      if (cloudReflections == null || cloudReflections.isEmpty) {
        await upload(localReflections);
        return SyncResult(reflections: localReflections, message: appL10n().cl_first_sync_done, hasUpdate: false);
      }

      final merged = _mergeReflections(localReflections, cloudReflections);
      await upload(merged);

      return SyncResult(reflections: merged, message: appL10n().cl_sync_done, hasUpdate: merged.length != localReflections.length);
    } catch (e) {
      return SyncResult(reflections: localReflections, message: appL10n().cl_sync_failed('$e'), hasUpdate: false);
    }
  }

  static List<Reflection> _mergeReflections(List<Reflection> local, List<Reflection> cloud) {
    final map = <String, Reflection>{};
    for (final r in cloud) { map[r.id] = r; }
    for (final r in local) { map[r.id] = r; }
    return map.values.toList();
  }
}

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
