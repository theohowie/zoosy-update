import 'dart:convert';
import '../models/reflection.dart';
import '../utils/input_sanitizer.dart';
import 'prefs_util.dart';

/// 草稿箱服务 — 管理未保存思考的暂存
class DraftService {
  static const _draftsKey = 'draft_reflections';

  /// 加载所有草稿
  static Future<List<Reflection>> loadDrafts() async {
    final prefs = await PrefsUtil.get();
    final jsonStr = prefs.getString(_draftsKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    return jsonList
        .map((j) => Reflection.fromFirestore(j['id'] as String, Map<String, dynamic>.from(j)))
        .toList();
  }

  /// 保存草稿（如果 id 已存在则覆盖，否则新增）
  static Future<void> saveDraft(Reflection draft) async {
    // 输入消毒
    final sanitizedTitle = InputSanitizer.sanitizeTitle(draft.title).sanitized;
    final sanitizedContent = InputSanitizer.sanitizeContent(draft.content).sanitized;
    final sanitizedTags = draft.tags
        .map((tag) => InputSanitizer.sanitizeTag(tag).sanitized)
        .where((tag) => tag.isNotEmpty)
        .toList();

    final sanitizedDraft = draft.copyWith(
      title: sanitizedTitle,
      content: sanitizedContent,
      tags: sanitizedTags,
    );

    final drafts = await loadDrafts();
    final idx = drafts.indexWhere((r) => r.id == sanitizedDraft.id);
    if (idx >= 0) {
      drafts[idx] = sanitizedDraft;
    } else {
      drafts.insert(0, sanitizedDraft);
    }
    await _saveDrafts(drafts);
  }

  /// 删除单条草稿
  static Future<void> deleteDraft(String id) async {
    final drafts = await loadDrafts();
    drafts.removeWhere((r) => r.id == id);
    await _saveDrafts(drafts);
  }

  /// 清空所有草稿
  static Future<void> clearAll() async {
    final prefs = await PrefsUtil.get();
    await prefs.remove(_draftsKey);
  }

  static Future<void> _saveDrafts(List<Reflection> list) async {
    final prefs = await PrefsUtil.get();
    final jsonList = list.map((r) => {'id': r.id, ...r.toFirestore()}).toList();
    await prefs.setString(_draftsKey, jsonEncode(jsonList));
  }
}
