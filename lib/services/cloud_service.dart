/// 云端服务（预留接口，后续接入自建服务器）
class CloudService {
  static Future<String?> login(String email, String password) async => null;
  static Future<String?> register(String email, String password) async => null;
  static Future<void> logout() async {}
  static Future<List<dynamic>> loadReflections() async => [];
  static Future<void> addReflection(dynamic ref) async {}
  static Future<void> toggleFavorite(String id, bool val) async {}
  static Future<void> deleteReflection(String id) async {}
  static Future<void> updateReflection(dynamic ref) async {}
}
