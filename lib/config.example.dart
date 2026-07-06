/// 应用配置模板
///
/// 使用方式（二选一）：
///
/// 方式一：通过 --dart-define 传入（推荐，不提交到 git）
///   flutter run --dart-define=QQ_EMAIL=your_email@qq.com --dart-define=QQ_AUTH_CODE=your_code
///
/// 方式二：复制此文件为 config.dart，填入真实值
///   cp lib/config.example.dart lib/config.dart
///
/// QQ 邮箱 SMTP 设置说明：
/// 1. 登录 https://mail.qq.com → 设置 → 账户 → POP3/SMTP服务 → 开启
/// 2. 生成授权码（16位，代替登录密码）
class AppConfig {
  // ==========================================
  //  👇 QQ 邮箱 SMTP 配置
  //    优先从 --dart-define 读取，回退到下方静态常量
  // ==========================================

  /// QQ 邮箱地址
  static const String qqEmail = String.fromEnvironment('QQ_EMAIL', defaultValue: 'your_email@qq.com');

  /// QQ 邮箱 SMTP 授权码
  static const String qqAuthCode = String.fromEnvironment('QQ_AUTH_CODE', defaultValue: 'your_smtp_auth_code');

  // ==========================================
}
