import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../utils/input_sanitizer.dart';
import 'prefs_util.dart';

/// AI 服务
///
/// ⚠️ 安全说明：当前 API Key 存储在 SharedPreferences 中。
///    在 root 设备上，任何人可读取该值。如需更高安全性，
///    建议安装 flutter_secure_storage 替换此处的存储实现：
///       flutter pub add flutter_secure_storage
///    并配合 Android minSdk 23+ 的加密存储。
class AIService {
  static const _enabledKey = 'ai_summary_enabled';
  static const _apiKeyKey = 'ai_api_key';
  static const _apiUrlKey = 'ai_api_url';
  static const _modelKey = 'ai_model';

  /// 支持的模型列表及对应 API 地址
  static const Map<String, String> modelUrls = {
    'OpenAI': 'https://api.openai.com/v1/chat/completions',
    'DeepSeek': 'https://api.deepseek.com/v1/chat/completions',
    'Moonshot': 'https://api.moonshot.cn/v1/chat/completions',
    'Doubao': 'https://ark.cn-beijing.volces.com/api/v3/chat/completions',
    'Gemini': 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent',
    'Sonnet': 'https://api.anthropic.com/v1/messages',
    'Kimi': 'https://api.moonshot.cn/v1/chat/completions',
    'Qwen': 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
    'MiMo': 'https://api.xiaomimimo.com/v1/chat/completions',
  };

  /// 各模型对应的请求 model 名称
  static const Map<String, String> modelNames = {
    'OpenAI': 'gpt-3.5-turbo',
    'DeepSeek': 'deepseek-chat',
    'Moonshot': 'moonshot-v1-8k',
    'Doubao': 'doubao-1.5-pro-256k',
    'Gemini': 'gemini-pro',
    'Sonnet': 'claude-3-sonnet-20240229',
    'Kimi': 'moonshot-v1-8k',
    'Qwen': 'qwen-plus',
    'MiMo': 'mimo-v2.5',
  };

  static const List<String> modelList = [
    'OpenAI', 'DeepSeek', 'Moonshot', 'Doubao', 'Gemini', 'Sonnet', 'Kimi', 'Qwen', 'MiMo',
  ];

  /// AI 是否启用
  static Future<bool> isEnabled() async {
    return (await PrefsUtil.get()).getBool(_enabledKey) ?? false;
  }

  /// 设置启用/禁用
  static Future<void> setEnabled(bool v) async {
    await (await PrefsUtil.get()).setBool(_enabledKey, v);
  }

  /// 获取 API Key
  static Future<String> getApiKey() async {
    return (await PrefsUtil.get()).getString(_apiKeyKey) ?? '';
  }

  /// 保存 API Key
  static Future<void> setApiKey(String key) async {
    await (await PrefsUtil.get()).setString(_apiKeyKey, key);
  }

  /// 获取自定义 API URL
  static Future<String> getApiUrl() async {
    return (await PrefsUtil.get()).getString(_apiUrlKey) ?? 'https://api.openai.com/v1/chat/completions';
  }

  /// 保存自定义 API URL
  static Future<void> setApiUrl(String url) async {
    await (await PrefsUtil.get()).setString(_apiUrlKey, url);
  }

  /// 获取选择的模型名称
  static Future<String> getModel() async {
    return (await PrefsUtil.get()).getString(_modelKey) ?? 'OpenAI';
  }

  /// 保存选择的模型名称
  static Future<void> setModel(String model) async {
    await (await PrefsUtil.get()).setString(_modelKey, model);
  }

  /// 根据模型名称获取对应 API 地址
  static String urlForModel(String model) {
    return modelUrls[model] ?? 'https://api.openai.com/v1/chat/completions';
  }

  /// 根据模型名称获取请求用的 model 字段值
  static String requestModelFor(String model) {
    return modelNames[model] ?? 'gpt-3.5-turbo';
  }

  /// 构建 OpenAI 兼容的请求体
  static Map<String, dynamic> _buildOpenAIBody(String requestModel, String systemPrompt, String userContent, {int maxTokens = 100}) {
    return {
      'model': requestModel,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userContent},
      ],
      'max_tokens': maxTokens,
      'temperature': 0.7,
    };
  }

  /// 验证 API Key 是否可用（发送测试请求）
  static Future<String?> validateApiKey(String apiKey, String apiUrl, {String? model}) async {
    try {
      final selectedModel = model ?? await getModel();
      final requestModel = requestModelFor(selectedModel);

      Map<String, dynamic> body;
      Map<String, String> headers = {
        'Content-Type': 'application/json',
      };

      if (selectedModel == 'Sonnet') {
        // Anthropic 格式
        headers['x-api-key'] = apiKey;
        headers['anthropic-version'] = '2023-06-01';
        body = {
          'model': requestModel,
          'max_tokens': 5,
          'messages': [{'role': 'user', 'content': 'Hi'}],
        };
      } else {
        headers['Authorization'] = 'Bearer $apiKey';
        // 验证时发送简单消息，不带 system prompt
        body = {
          'model': requestModel,
          'messages': [
            {'role': 'user', 'content': 'Hi'},
          ],
          'max_tokens': 5,
        };
      }

      // 使用 IOClient 跳过 SSL 验证
      final ioClient = HttpClient()
        ..badCertificateCallback = (_, __, ___) => true;
      final client = IOClient(ioClient);

      final response = await client.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      client.close();

      if (response.statusCode == 200) {
        return null; // 验证通过
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return 'API Key 无效，请检查后重试';
      } else {
        // 尝试解析错误信息
        String detail = '';
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody['error'] != null) {
            detail = ': ${errorBody['error']['message'] ?? errorBody['error']}';
          }
        } catch (_) {}
        return 'API 返回错误 (${response.statusCode})$detail';
      }
    } catch (e) {
      return '连接失败，请检查网络或 API 地址';
    }
  }

  /// 生成 AI 摘要
  static Future<String?> generateSummary(String content, String title) async {
    final enabled = await isEnabled();
    if (!enabled) return null;

    final apiKey = await getApiKey();
    if (apiKey.isEmpty) {
      return 'AI 摘要：未配置 API Key，请在设置中配置。';
    }

    final apiUrl = await getApiUrl();
    final model = await getModel();
    final requestModel = requestModelFor(model);

    try {
      Map<String, dynamic> body;
      Map<String, String> headers = {
        'Content-Type': 'application/json',
      };

      final systemPrompt = '你是一个思考总结助手。用一句简短的 50 字以内的话总结用户的思考内容，用中文回复。';
      // 防止指令注入：消毒用户内容
      final sanitizedTitle = InputSanitizer.prepareForAI(title);
      final sanitizedContent = InputSanitizer.prepareForAI(content);
      final userContent = '标题：$sanitizedTitle\n内容：$sanitizedContent';

      if (model == 'Sonnet') {
        // Anthropic 格式
        headers['x-api-key'] = apiKey;
        headers['anthropic-version'] = '2023-06-01';
        body = {
          'model': requestModel,
          'max_tokens': 100,
          'messages': [{'role': 'user', 'content': '$systemPrompt\n\n$userContent'}],
        };
      } else {
        headers['Authorization'] = 'Bearer $apiKey';
        // MiMo 等部分模型不支持 system 角色，将 system prompt 合并到 user 消息中
        if (model == 'MiMo') {
          body = {
            'model': requestModel,
            'messages': [
              {'role': 'user', 'content': '$systemPrompt\n\n$userContent'},
            ],
            'max_tokens': 1024,
            'temperature': 0.7,
          };
        } else {
          body = _buildOpenAIBody(requestModel, systemPrompt, userContent);
        }
      }

      // 使用 IOClient 跳过 SSL 验证
      final ioClient = HttpClient()
        ..badCertificateCallback = (_, __, ___) => true;
      final client = IOClient(ioClient);

      final response = await client.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      client.close();

      debugPrint('[AI] Status: ${response.statusCode}');
      debugPrint('[AI] Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[AI] Response keys: ${data.keys.toList()}');
        debugPrint('[AI] Response: ${response.body}');

        // 兼容不同响应格式
        String? text;
        if (data['choices'] != null && (data['choices'] as List).isNotEmpty) {
          final msg = data['choices']?[0]?['message'];
          text = msg?['content'] as String?;
          // MiMo 等推理模型：content 为空时读 reasoning_content
          if ((text == null || text.isEmpty) && msg?['reasoning_content'] != null) {
            text = msg['reasoning_content'] as String?;
          }
        }
        if (text == null || text.isEmpty) {
          if (data['content'] != null) {
            text = data['content'] as String?;
          }
        }
        if (text == null || text.isEmpty) {
          if (data['data'] != null && data['data']['text'] != null) {
            text = data['data']['text'] as String?;
          }
        }
        if (text != null && text.isNotEmpty) return 'AI 摘要：$text';
        return 'AI 摘要生成失败，请重试。';
      } else {
        return 'AI 摘要：API 返回错误 (${response.statusCode})';
      }
    } catch (e, stack) {
      debugPrint('[AI] Exception: $e');
      debugPrint('[AI] Stack: $stack');
      return 'AI 摘要：连接失败 - $e';
    }
  }
}
