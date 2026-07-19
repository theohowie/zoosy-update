/// 输入消毒工具 — 防止指令注入、XSS、SQL注入等攻击
class InputSanitizer {
  // 最大输入长度限制
  static const int maxTitleLength = 200;
  static const int maxContentLength = 10000;
  static const int maxEmailLength = 254;
  static const int maxPasswordLength = 128;
  static const int maxNameLength = 50;
  static const int maxUrlLength = 2048;

  // 危险的指令注入模式
  static final List<RegExp> _injectionPatterns = [
    // 系统命令注入
    RegExp(r'[;&|`$]'),
    RegExp(r'\$\('),
    RegExp(r'`[^`]*`'),
    // SQL 注入关键字
    RegExp(r'(\b(union|select|insert|update|delete|drop|alter|create|exec|execute)\b)', caseSensitive: false),
    // 脚本注入
    RegExp(r'<\s*script', caseSensitive: false),
    RegExp(r'javascript\s*:', caseSensitive: false),
    RegExp(r'on\w+\s*=', caseSensitive: false),
    // Prompt 注入尝试
    RegExp(r'ignore\s+(previous|above|all)\s+(instructions?|prompts?)', caseSensitive: false),
    RegExp(r'you\s+are\s+now', caseSensitive: false),
    RegExp(r'system\s*:\s*', caseSensitive: false),
    RegExp(r'assistant\s*:\s*', caseSensitive: false),
    RegExp(r'human\s*:\s*', caseSensitive: false),
    RegExp(r'\[INST\]', caseSensitive: false),
    RegExp(r'\[/INST\]', caseSensitive: false),
    RegExp(r'<<SYS>>', caseSensitive: false),
    RegExp(r'<</SYS>>', caseSensitive: false),
  ];

  /// 消毒文本内容（用于思考标题、内容等）
  static String sanitizeText(String input, {int? maxLength}) {
    if (input.isEmpty) return input;

    String sanitized = input;

    // 1. 移除零宽字符和不可见字符
    sanitized = sanitized.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF\u00AD]'), '');

    // 2. 移除控制字符（保留换行和制表符）
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    // 3. 修剪空白
    sanitized = sanitized.trim();

    // 4. 限制长度
    final limit = maxLength ?? maxContentLength;
    if (sanitized.length > limit) {
      sanitized = sanitized.substring(0, limit);
    }

    return sanitized;
  }

  /// 消毒并验证文本，返回消毒后的文本和警告信息
  static SanitizeResult sanitizeAndValidate(String input, {int? maxLength, String fieldName = '输入'}) {
    if (input.isEmpty) {
      return SanitizeResult(input, null);
    }

    // 检测注入尝试
    for (final pattern in _injectionPatterns) {
      if (pattern.hasMatch(input)) {
        return SanitizeResult(
          sanitizeText(input, maxLength: maxLength),
          '$fieldName 包含不允许的特殊字符，已自动清理',
        );
      }
    }

    final sanitized = sanitizeText(input, maxLength: maxLength);
    final wasModified = sanitized != input.trim();

    return SanitizeResult(
      sanitized,
      wasModified ? '$fieldName 已自动清理特殊字符' : null,
    );
  }

  /// 消毒标题
  static SanitizeResult sanitizeTitle(String input) {
    return sanitizeAndValidate(input, maxLength: maxTitleLength, fieldName: '标题');
  }

  /// 消毒内容
  static SanitizeResult sanitizeContent(String input) {
    return sanitizeAndValidate(input, maxLength: maxContentLength, fieldName: '内容');
  }

  /// 验证并消毒邮箱
  static SanitizeResult sanitizeEmail(String input) {
    if (input.isEmpty) {
      return SanitizeResult(input, null);
    }

    String sanitized = input.trim().toLowerCase();

    // 长度检查
    if (sanitized.length > maxEmailLength) {
      sanitized = sanitized.substring(0, maxEmailLength);
      return SanitizeResult(sanitized, '邮箱地址过长，已截断');
    }

    // 基本格式验证
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(sanitized)) {
      return SanitizeResult(sanitized, '邮箱格式不正确');
    }

    // 检查注入
    if (sanitized.contains(RegExp(r'[;&|`$<>]'))) {
      return SanitizeResult(sanitized.replaceAll(RegExp(r'[;&|`$<>]'), ''), '邮箱包含不允许的字符');
    }

    return SanitizeResult(sanitized, null);
  }

  /// 消毒密码（保留原始字符，只检查长度）
  static SanitizeResult sanitizePassword(String input) {
    if (input.isEmpty) {
      return SanitizeResult(input, null);
    }

    if (input.length > maxPasswordLength) {
      return SanitizeResult(input.substring(0, maxPasswordLength), '密码过长，已截断');
    }

    return SanitizeResult(input, null);
  }

  /// 消毒昵称/名称
  static SanitizeResult sanitizeName(String input) {
    return sanitizeAndValidate(input, maxLength: maxNameLength, fieldName: '名称');
  }

  /// 消毒 URL
  static SanitizeResult sanitizeUrl(String input) {
    if (input.isEmpty) {
      return SanitizeResult(input, null);
    }

    String sanitized = input.trim();

    // 长度检查
    if (sanitized.length > maxUrlLength) {
      return SanitizeResult(sanitized.substring(0, maxUrlLength), 'URL 过长，已截断');
    }

    // 协议白名单
    final uri = Uri.tryParse(sanitized);
    if (uri != null && uri.hasScheme) {
      final allowedSchemes = ['http', 'https', 'ftp'];
      if (!allowedSchemes.contains(uri.scheme.toLowerCase())) {
        return SanitizeResult(sanitized, 'URL 协议不安全，仅支持 http/https/ftp');
      }
    }

    // 移除危险字符
    if (sanitized.contains(RegExp(r'[;&|`$]'))) {
      sanitized = sanitized.replaceAll(RegExp(r'[;&|`$]'), '');
      return SanitizeResult(sanitized, 'URL 包含不允许的字符，已清理');
    }

    return SanitizeResult(sanitized, null);
  }

  /// 消毒标签
  static SanitizeResult sanitizeTag(String input) {
    if (input.isEmpty) {
      return SanitizeResult(input, null);
    }

    String sanitized = input.trim();

    // 标签长度限制
    if (sanitized.length > 30) {
      sanitized = sanitized.substring(0, 30);
      return SanitizeResult(sanitized, '标签过长，已截断');
    }

    // 移除特殊字符，只保留中文、字母、数字、下划线、连字符
    final allowedPattern = RegExp(r'^[\u4e00-\u9fa5a-zA-Z0-9_\-]+$');
    if (!allowedPattern.hasMatch(sanitized)) {
      sanitized = sanitized.replaceAll(RegExp(r'[^\u4e00-\u9fa5a-zA-Z0-9_\-]'), '');
      return SanitizeResult(sanitized, '标签包含不允许的字符，已清理');
    }

    return SanitizeResult(sanitized, null);
  }

  /// 为 AI 服务准备内容（额外的安全处理）
  static String prepareForAI(String content) {
    String sanitized = sanitizeText(content);

    // 移除可能的 prompt 注入标记（Dart RegExp 不支持 (?i)，用 caseSensitive: false）
    sanitized = sanitized.replaceAll(RegExp(r'ignore\s+(previous|above|all)\s+(instructions?|prompts?)', caseSensitive: false), '');
    sanitized = sanitized.replaceAll(RegExp(r'you\s+are\s+now', caseSensitive: false), '');
    sanitized = sanitized.replaceAll(RegExp(r'system\s*:', caseSensitive: false), '');
    sanitized = sanitized.replaceAll(RegExp(r'assistant\s*:', caseSensitive: false), '');
    sanitized = sanitized.replaceAll(RegExp(r'human\s*:', caseSensitive: false), '');
    sanitized = sanitized.replaceAll(RegExp(r'\[INST\]', caseSensitive: false), '');
    sanitized = sanitized.replaceAll(RegExp(r'\[/INST\]', caseSensitive: false), '');
    sanitized = sanitized.replaceAll(RegExp(r'<<SYS>>', caseSensitive: false), '');
    sanitized = sanitized.replaceAll(RegExp(r'<</SYS>>', caseSensitive: false), '');

    // 移除多余的空白行
    sanitized = sanitized.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return sanitized.trim();
  }

  /// 检查是否包含潜在危险内容
  static bool containsDangerousContent(String input) {
    for (final pattern in _injectionPatterns) {
      if (pattern.hasMatch(input)) {
        return true;
      }
    }
    return false;
  }
}

/// 消毒结果
class SanitizeResult {
  final String sanitized;
  final String? warning;

  SanitizeResult(this.sanitized, this.warning);

  bool get hasWarning => warning != null;
}
