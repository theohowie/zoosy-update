import 'package:flutter/material.dart';

class Reflection {
  final String id;
  final String title;
  final String content;
  final String date; // YYYY-MM-DD
  final String time; // HH:MM
  final List<String> tags;
  bool isFavorite;
  final String? imageUrl;
  final String? aiSummary;
  final List<String> emotions;
  final String? location; // 位置信息（地址）

  Reflection({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.time,
    required this.tags,
    this.isFavorite = false,
    this.imageUrl,
    this.aiSummary,
    this.emotions = const [],
    this.location,
  });

  Reflection copyWith({
    String? id,
    String? title,
    String? content,
    String? date,
    String? time,
    List<String>? tags,
    bool? isFavorite,
    String? imageUrl,
    String? aiSummary,
    List<String>? emotions,
    String? location,
  }) {
    return Reflection(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      date: date ?? this.date,
      time: time ?? this.time,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      imageUrl: imageUrl ?? this.imageUrl,
      aiSummary: aiSummary ?? this.aiSummary,
      emotions: emotions ?? this.emotions,
      location: location ?? this.location,
    );
  }

  /// 转为 Firestore 文档数据
  Map<String, dynamic> toFirestore() => {
    'title': title,
    'content': content,
    'date': date,
    'time': time,
    'tags': tags,
    'isFavorite': isFavorite,
    'imageUrl': imageUrl,
    'aiSummary': aiSummary,
    'emotions': emotions,
    'location': location,
  };

  /// 从 Firestore 文档创建
  factory Reflection.fromFirestore(String id, Map<String, dynamic> data) => Reflection(
    id: id,
    title: data['title'] as String? ?? '',
    content: data['content'] as String? ?? '',
    date: data['date'] as String? ?? '',
    time: data['time'] as String? ?? '',
    tags: (data['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    isFavorite: data['isFavorite'] as bool? ?? false,
    imageUrl: data['imageUrl'] as String?,
    aiSummary: data['aiSummary'] as String?,
    emotions: (data['emotions'] as List<dynamic>?)?.cast<String>() ?? [],
    location: data['location'] as String?,
  );
}

class NotificationItem {
  final String id;
  final String title;
  final String content;
  final String time;
  final String type; // general, reminder, milestone
  final IconData icon;

  NotificationItem({
    required this.id,
    required this.title,
    required this.content,
    required this.time,
    required this.type,
    required this.icon,
  });
}

// Global Theme colors aligning with the Lavender "Ethereal Growth" palette
class ZoosyTheme {
  static Color _primary = const Color(0xFF4828C8);

  /// 当前主题主色（可动态变更）
  static Color get primary => _primary;

  /// 更新主题主色（由主题设置页面调用）
  static void setPrimary(Color color) {
    _primary = color;
  }

  static const Color onPrimary = Colors.white;
  static const Color bgLight = Color(0xFFFEF7FF);
  static const Color containerLow = Color(0xFFF2ECF3);
  static const Color textDark = Color(0xFF1D1B20);
  static const Color textMuted = Color(0xFF484555);
  static const Color outline = Color(0xFFC9C4D7);

  /// 获取当前主题的主色（跟随用户设置，从 Theme 读取）
  static Color primaryOf(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  // ==========================================================
  //  深色模式感知的颜色 getter（传入 BuildContext，自动适配亮度）
  // ==========================================================

  /// 卡片/输入框背景色 — 浅色模式白，深色模式深灰
  static Color surfaceOf(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF2D2D3F) : Colors.white;
  }

  /// 页面背景色 — 浅色模式浅紫白，深色模式深紫黑
  static Color bgOf(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF1E1E2C) : const Color(0xFFFEF7FF);
  }

  /// 主要文字颜色 — 浅色模式近黑，深色模式近白
  static Color textDarkOf(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFFE6E1E5) : const Color(0xFF1D1B20);
  }

  /// 次要/辅助文字颜色 — 深色模式降低不透明度保证可读性
  static Color textMutedOf(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFFCAC4D0) : const Color(0xFF484555);
  }

  /// 边框颜色
  static Color outlineOf(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF938F99) : const Color(0xFFC9C4D7);
  }

  /// 低对比度容器背景（如标签灰底、分段选择器）
  static Color containerLowOf(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF2B2930) : const Color(0xFFF2ECF3);
  }
}
