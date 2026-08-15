import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../utils/input_sanitizer.dart';
import 'secure_prefs.dart';

class UserAccount {
  final String email;
  final String passwordHash;
  final String nickname;

  UserAccount({
    required this.email,
    required this.passwordHash,
    this.nickname = '思考者',
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'passwordHash': passwordHash,
        'nickname': nickname,
      };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
        email: json['email'] as String,
        passwordHash: json['passwordHash'] as String,
        nickname: json['nickname'] as String? ?? '思考者',
      );
}

class AuthService {
  static const _accountsKey = 'zoosy_accounts';
  static const _loggedInEmailKey = 'zoosy_logged_in_email';
  static const adminEmail = 'admin@zoosy.com';
  static const _adminPassword = 'zoosy_admin';
  static const adminNickname = 'Zoosy Admin';

  /// 游客登录使用的占位邮箱，持久化后重启 App 无需重新游客登录
  static const guestEmail = 'guest@zoosy.local';

  // 支持的哈希算法列表（兼容旧版数据）
  static const _hashAlgorithms = ['sha256', 'md5', 'sha1'];

  // 用指定算法生成密码哈希
  static String _hashPasswordWith(String password, String algorithm) {
    final bytes = utf8.encode(password);
    switch (algorithm) {
      case 'md5':
        return md5.convert(bytes).toString();
      case 'sha1':
        return sha1.convert(bytes).toString();
      case 'sha256':
      default:
        return sha256.convert(bytes).toString();
    }
  }

  // 生成密码哈希（新注册使用 SHA256）
  static String _hashPassword(String password) {
    return _hashPasswordWith(password, 'sha256');
  }

  // 注册新账号
  static Future<bool> register(String email, String password, {String nickname = '思考者'}) async {
    // 输入消毒
    final sanitizedEmail = InputSanitizer.sanitizeEmail(email).sanitized;
    final sanitizedPassword = InputSanitizer.sanitizePassword(password).sanitized;
    final sanitizedNickname = InputSanitizer.sanitizeName(nickname).sanitized;

    if (sanitizedEmail.isEmpty || sanitizedPassword.isEmpty) {
      return false;
    }

    final accountsJson = await SecurePrefs.getString(_accountsKey);
    final accounts = <String, dynamic>{};

    if (accountsJson != null) {
      final decoded = jsonDecode(accountsJson) as Map<String, dynamic>;
      if (decoded.containsKey(sanitizedEmail)) {
        return false;
      }
      accounts.addAll(decoded);
    }

    accounts[sanitizedEmail] = UserAccount(
      email: sanitizedEmail,
      passwordHash: _hashPassword(sanitizedPassword),
      nickname: sanitizedNickname,
    ).toJson();

    await SecurePrefs.setString(_accountsKey, jsonEncode(accounts));
    return true;
  }

  // 登录验证（兼容多种哈希算法）
  static Future<bool> login(String email, String password) async {
    // 输入消毒
    final sanitizedEmail = InputSanitizer.sanitizeEmail(email).sanitized;
    final sanitizedPassword = InputSanitizer.sanitizePassword(password).sanitized;

    if (sanitizedEmail.isEmpty || sanitizedPassword.isEmpty) {
      return false;
    }

    // 内置管理员账号
    if (sanitizedEmail == adminEmail && sanitizedPassword == _adminPassword) {
      await SecurePrefs.setBool('voice_vip', true);
      return true;
    }

    final accountsJson = await SecurePrefs.getString(_accountsKey);
    if (accountsJson == null) return false;

    final accounts = jsonDecode(accountsJson) as Map<String, dynamic>;
    if (!accounts.containsKey(sanitizedEmail)) return false;

    final account = UserAccount.fromJson(accounts[sanitizedEmail] as Map<String, dynamic>);

    for (final algo in _hashAlgorithms) {
      if (account.passwordHash == _hashPasswordWith(sanitizedPassword, algo)) {
        if (algo != 'sha256') {
          accounts[sanitizedEmail] = UserAccount(
            email: account.email,
            passwordHash: _hashPassword(sanitizedPassword),
            nickname: account.nickname,
          ).toJson();
          await SecurePrefs.setString(_accountsKey, jsonEncode(accounts));
        }
        return true;
      }
    }

    return false;
  }

  // 保存登录状态
  static Future<void> saveLoginState(String email) async {
    await SecurePrefs.setString(_loggedInEmailKey, email);
  }

  // 获取登录状态
  static Future<bool> isLoggedIn() async {
    return await SecurePrefs.containsKey(_loggedInEmailKey);
  }

  // 获取当前登录邮箱
  static Future<String?> getLoggedInEmail() async {
    return await SecurePrefs.getString(_loggedInEmailKey);
  }

  // 是否为管理员账号
  static Future<bool> isAdmin() async {
    final email = await getLoggedInEmail();
    return email == adminEmail;
  }

  // 退出登录
  static Future<void> logout() async {
    await SecurePrefs.remove(_loggedInEmailKey);
  }

  // 更新邮箱（换绑）
  static Future<void> updateEmail(String oldEmail, String newEmail) async {
    final sanitizedOld = InputSanitizer.sanitizeEmail(oldEmail).sanitized;
    final sanitizedNew = InputSanitizer.sanitizeEmail(newEmail).sanitized;
    if (sanitizedOld.isEmpty || sanitizedNew.isEmpty) return;

    final accountsJson = await SecurePrefs.getString(_accountsKey);
    if (accountsJson == null) return;

    final accounts = jsonDecode(accountsJson) as Map<String, dynamic>;
    if (!accounts.containsKey(sanitizedOld)) return;

    // 取出旧账号信息
    final oldAccount = accounts[sanitizedOld];
    // 以新邮箱为 key 创建记录
    accounts[sanitizedNew] = oldAccount;
    // 删除旧邮箱记录
    accounts.remove(sanitizedOld);

    await SecurePrefs.setString(_accountsKey, jsonEncode(accounts));
  }
}
