import 'dart:convert';
import '../models/reflection.dart';
import 'prefs_util.dart';

/// 回收站服务 — 管理已删除思考的暂存与恢复
class TrashService {
  static const _trashKey = 'trash_reflections';
  static const _trashDatesKey = 'trash_dates';
  static const int _retentionDays = 30;

  /// 加载所有回收站中的思考
  static Future<List<Reflection>> loadTrash() async {
    final prefs = await PrefsUtil.get();
    final jsonStr = prefs.getString(_trashKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    return jsonList
        .map((j) => Reflection.fromFirestore(j['id'] as String, Map<String, dynamic>.from(j)))
        .toList();
  }

  /// 获取删除时间戳列表（与 trash 列表顺序一致）
  static Future<List<String>> _loadTrashDates() async {
    final prefs = await PrefsUtil.get();
    return prefs.getStringList(_trashDatesKey) ?? [];
  }

  /// 过期清理：移除超过保留期的条目
  static Future<void> _cleanupExpired() async {
    final trash = await loadTrash();
    final dates = await _loadTrashDates();
    if (trash.isEmpty) return;
    final now = DateTime.now();
    final validIdx = <int>[];
    for (int i = 0; i < trash.length; i++) {
      if (i < dates.length) {
        try {
          final deletedAt = DateTime.parse(dates[i]);
          if (now.difference(deletedAt).inDays < _retentionDays) {
            validIdx.add(i);
          }
        } catch (_) {
          validIdx.add(i);
        }
      } else {
        validIdx.add(i);
      }
    }
    if (validIdx.length != trash.length) {
      final validTrash = validIdx.map((i) => trash[i]).toList();
      final validDates = validIdx.map((i) => i < dates.length ? dates[i] : DateTime.now().toIso8601String()).toList();
      await _saveTrash(validTrash, validDates);
    }
  }

  /// 将思考移入回收站
  static Future<void> moveToTrash(Reflection ref) async {
    await _cleanupExpired();
    final trash = await loadTrash();
    final dates = await _loadTrashDates();
    trash.insert(0, ref);
    dates.insert(0, DateTime.now().toIso8601String());
    await _saveTrash(trash, dates);
  }

  /// 从回收站恢复思考
  static Future<Reflection?> restoreFromTrash(String id) async {
    await _cleanupExpired();
    final trash = await loadTrash();
    final dates = await _loadTrashDates();
    final idx = trash.indexWhere((r) => r.id == id);
    if (idx < 0) return null;
    final ref = trash[idx];
    trash.removeAt(idx);
    if (idx < dates.length) dates.removeAt(idx);
    await _saveTrash(trash, dates);
    return ref;
  }

  /// 彻底删除单条
  static Future<void> permanentDelete(String id) async {
    final trash = await loadTrash();
    final dates = await _loadTrashDates();
    final idx = trash.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      trash.removeAt(idx);
      if (idx < dates.length) dates.removeAt(idx);
    }
    await _saveTrash(trash, dates);
  }

  /// 清空回收站
  static Future<void> clearAll() async {
    final prefs = await PrefsUtil.get();
    await prefs.remove(_trashKey);
    await prefs.remove(_trashDatesKey);
  }

  static Future<void> _saveTrash(List<Reflection> list, List<String> dates) async {
    final prefs = await PrefsUtil.get();
    final jsonList = list.map((r) => {'id': r.id, ...r.toFirestore()}).toList();
    await prefs.setString(_trashKey, jsonEncode(jsonList));
    await prefs.setStringList(_trashDatesKey, dates);
  }
}
