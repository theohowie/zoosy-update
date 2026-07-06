import '../utils/input_sanitizer.dart';
import 'secure_prefs.dart';

class ProfileService {
  static const _nicknameKey = 'profile_nickname';
  static const _avatarKey = 'profile_avatar';
  static const _emailKey = 'profile_email';
  static const _genderKey = 'profile_gender';
  static const _signatureKey = 'profile_signature';
  static const _bioKey = 'profile_bio';
  static const _birthdayKey = 'profile_birthday';
  static const _occupationKey = 'profile_occupation';

  static const String defaultAvatar = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=256';

  static Future<String> getNickname() async {
    return await SecurePrefs.getString(_nicknameKey) ?? 'Alex';
  }
  static Future<void> setNickname(String v) async {
    final sanitized = InputSanitizer.sanitizeName(v).sanitized;
    await SecurePrefs.setString(_nicknameKey, sanitized);
  }

  static Future<String> getAvatarUrl() async {
    return await SecurePrefs.getString(_avatarKey) ?? defaultAvatar;
  }
  static Future<void> setAvatarUrl(String v) async {
    final sanitized = InputSanitizer.sanitizeUrl(v).sanitized;
    await SecurePrefs.setString(_avatarKey, sanitized);
  }

  static Future<String> getEmail() async {
    return await SecurePrefs.getString(_emailKey) ?? 'alex@zoosy.io';
  }
  static Future<void> setEmail(String v) async {
    final sanitized = InputSanitizer.sanitizeEmail(v).sanitized;
    await SecurePrefs.setString(_emailKey, sanitized);
  }

  static Future<String> getGender() async {
    return await SecurePrefs.getString(_genderKey) ?? '未设置';
  }
  static Future<void> setGender(String v) async {
    final sanitized = InputSanitizer.sanitizeText(v, maxLength: 10);
    await SecurePrefs.setString(_genderKey, sanitized);
  }

  static Future<String> getSignature() async {
    return await SecurePrefs.getString(_signatureKey) ?? '';
  }
  static Future<void> setSignature(String v) async {
    final sanitized = InputSanitizer.sanitizeText(v, maxLength: 100);
    await SecurePrefs.setString(_signatureKey, sanitized);
  }

  static Future<String> getBio() async {
    return await SecurePrefs.getString(_bioKey) ?? '';
  }
  static Future<void> setBio(String v) async {
    final sanitized = InputSanitizer.sanitizeText(v, maxLength: 500);
    await SecurePrefs.setString(_bioKey, sanitized);
  }

  static Future<String> getBirthday() async {
    return await SecurePrefs.getString(_birthdayKey) ?? '未设置';
  }
  static Future<void> setBirthday(String v) async {
    final sanitized = InputSanitizer.sanitizeText(v, maxLength: 20);
    await SecurePrefs.setString(_birthdayKey, sanitized);
  }

  static Future<String> getOccupation() async {
    return await SecurePrefs.getString(_occupationKey) ?? '未设置';
  }
  static Future<void> setOccupation(String v) async {
    final sanitized = InputSanitizer.sanitizeText(v, maxLength: 50);
    await SecurePrefs.setString(_occupationKey, sanitized);
  }
}
