import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'prefs_util.dart';

class SecurePrefs {
  static const _salt = 'Zoosy2026Secure!';

  static String _obfuscateKey(String original) {
    final hash = sha256.convert(utf8.encode('$_salt$original')).toString();
    return 'z_${hash.substring(0, 16)}';
  }

  static String _hmac(String key, String value) {
    final h = Hmac(sha256, utf8.encode('$_salt$key'));
    return h.convert(utf8.encode(value)).toString().substring(0, 16);
  }

  static Future<String?> getString(String key) async {
    final prefs = await PrefsUtil.get();
    return prefs.getString(_obfuscateKey(key));
  }

  static Future<void> setString(String key, String value) async {
    final prefs = await PrefsUtil.get();
    await prefs.setString(_obfuscateKey(key), value);
  }

  static Future<int?> getInt(String key) async {
    final prefs = await PrefsUtil.get();
    return prefs.getInt(_obfuscateKey(key));
  }

  static Future<void> setInt(String key, int value) async {
    final prefs = await PrefsUtil.get();
    await prefs.setInt(_obfuscateKey(key), value);
  }

  static Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final prefs = await PrefsUtil.get();
    final raw = prefs.getString(_obfuscateKey(key));
    if (raw == null || raw.length < 17) return defaultValue;
    final flag = raw.substring(0, 1);
    final sig = raw.substring(1);
    if (_hmac(key, flag) != sig) return defaultValue;
    return flag == '1';
  }

  static Future<void> setBool(String key, bool value) async {
    final prefs = await PrefsUtil.get();
    final flag = value ? '1' : '0';
    await prefs.setString(_obfuscateKey(key), '$flag${_hmac(key, flag)}');
  }

  static Future<bool> containsKey(String key) async {
    final prefs = await PrefsUtil.get();
    return prefs.containsKey(_obfuscateKey(key));
  }

  static Future<void> remove(String key) async {
    final prefs = await PrefsUtil.get();
    await prefs.remove(_obfuscateKey(key));
  }
}
