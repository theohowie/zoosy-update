/// 应用配置模板
///
/// ⚠️ 安全说明：真实密钥一律通过 --dart-define 在构建时注入，
/// 切勿把真实密钥写进代码默认值——否则会随 APK 一起泄露（反编译即可提取）。
///
/// 构建时注入：
///   flutter run  --dart-define=QQ_EMAIL=your_email@qq.com --dart-define=QQ_AUTH_CODE=your_code
///   flutter build apk --dart-define=QQ_EMAIL=your_email@qq.com --dart-define=QQ_AUTH_CODE=your_code
///
/// QQ 邮箱 SMTP 设置说明：
/// 1. 登录 https://mail.qq.com → 设置 → 账户 → POP3/SMTP服务 → 开启
/// 2. 生成授权码（16位，代替登录密码）
class AppConfig {
  // ==========================================
  //  👇 QQ 邮箱 SMTP 配置
  //    一律通过 --dart-define 在构建时注入
  // ==========================================

  /// QQ 邮箱地址
  static const String qqEmail = String.fromEnvironment('QQ_EMAIL', defaultValue: '');

  /// QQ 邮箱 SMTP 授权码
  static const String qqAuthCode = String.fromEnvironment('QQ_AUTH_CODE', defaultValue: '');

  // ==========================================
}
