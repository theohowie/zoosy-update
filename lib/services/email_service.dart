/// QQ邮箱验证码发送服务
///
/// 使用说明（开发者配置）：
/// 通过 --dart-define 传入 QQ 邮箱 SMTP 配置：
///   flutter run --dart-define=QQ_EMAIL=your_email@qq.com --dart-define=QQ_AUTH_CODE=your_code
/// 或参考 lib/config.example.dart 配置 config.dart
///
/// QQ 邮箱 SMTP 设置说明：
/// 1. 登录 https://mail.qq.com → 设置 → 账户 → POP3/SMTP服务 → 开启
/// 2. 生成授权码（16位，代替登录密码）

import 'dart:math';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../config.dart';
import '../utils/input_sanitizer.dart';

class EmailService {
  /// 发送6位验证码到指定邮箱
  /// [purpose] 用途：'register'（注册）或 'reset'（重置密码）
  /// 返回验证码字符串（成功）或错误消息（失败）
  static Future<String?> sendVerificationCode(String toEmail, {String purpose = 'register'}) async {
    // 输入消毒
    final sanitizedEmail = InputSanitizer.sanitizeEmail(toEmail).sanitized;
    if (sanitizedEmail.isEmpty) {
      return '邮箱地址无效';
    }

    // 检查是否已配置发件邮箱（需在构建时通过 --dart-define 注入 QQ_EMAIL / QQ_AUTH_CODE）
    if (AppConfig.qqEmail.isEmpty || AppConfig.qqAuthCode.isEmpty) {
      return '发件邮箱未配置，请通过 --dart-define 传入 QQ_EMAIL 和 QQ_AUTH_CODE';
    }

    final code = _generateCode();
    try {
      final smtpServer = SmtpServer(
        'smtp.qq.com',
        port: 465,
        ssl: true,
        username: AppConfig.qqEmail,
        password: AppConfig.qqAuthCode,
      );

      final subject = purpose == 'reset' ? 'Zoosy 密码重置验证码' : 'Zoosy 邮箱验证码';
      final bodyText = purpose == 'reset'
          ? '您正在进行重置密码操作，请使用以下验证码完成验证：'
          : '您正在注册 Zoosy 账号，请使用以下验证码完成验证：';

      final message = Message()
        ..from = Address(AppConfig.qqEmail, 'Zoosy')
        ..recipients.add(sanitizedEmail)
        ..subject = subject
        ..text = '您的 Zoosy 验证码为：$code（有效期 5 分钟，请勿泄露）'
        ..html = '''
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family: 'Plus Jakarta Sans', sans-serif; background: #FEF7FF; padding: 40px;">
<div style="max-width: 480px; margin: 0 auto; background: white; border-radius: 24px; padding: 32px; box-shadow: 0 2px 12px rgba(72,40,200,0.08);">
<div style="text-align: center; margin-bottom: 24px;">
<span style="font-size: 24px; font-weight: 800; color: #4828C8;">Zoosy</span>
</div>
<h2 style="font-size: 16px; color: #1D1B20; margin-bottom: 16px;">邮箱验证</h2>
<p style="font-size: 14px; color: #484555; margin-bottom: 20px;">$bodyText</p>
<div style="text-align: center; padding: 20px; background: #F5F0FF; border-radius: 16px; margin-bottom: 20px;">
<span style="font-size: 36px; font-weight: 800; color: #4828C8; letter-spacing: 8px;">$code</span>
</div>
<p style="font-size: 12px; color: #787586;">验证码有效期 5 分钟，请勿泄露给他人。</p>
<hr style="border: none; border-top: 1px solid #E5DEFF; margin: 20px 0;">
<p style="font-size: 12px; color: #787586; text-align: center;">—— Zoosy 团队</p>
</div>
</body>
</html>
''';

      await send(message, smtpServer);
      return code;
    } on MailerException catch (e) {
      return '发送失败：${e.message}';
    } catch (e) {
      return '发送失败：$e';
    }
  }

  /// 生成6位随机验证码
  static String _generateCode() {
    final rng = Random();
    String code = '';
    for (int i = 0; i < 6; i++) {
      code += '${rng.nextInt(10)}';
    }
    return code;
  }
}
