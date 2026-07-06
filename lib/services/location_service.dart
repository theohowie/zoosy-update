import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'translation_service.dart';

/// 位置服务 — 原生 GPS 定位 + 逆地理编码 + 天气
/// 使用 Android 原生 LocationManager，不依赖 Google Play Services
/// 国产手机（OPPO/小米/vivo 等）全部可用
class LocationService {
  static const _channel = MethodChannel('zoosy/location');

  static Future<LocationResult> getCurrentLocationResult() async {
    // 优先 GPS 定位
    final gpsResult = await _getByGps();
    if (gpsResult != null) return gpsResult;

    // 降级 IP 定位
    return _getByIp();
  }

  // ==================== 原生 GPS 定位 ====================

  static Future<LocationResult?> _getByGps() async {
    try {
      // 调用 Android 原生 LocationManager
      final result = await _channel.invokeMethod('getLocation');
      if (result == null) return null;

      final lat = (result['latitude'] as num).toDouble();
      final lon = (result['longitude'] as num).toDouble();

      // 并行请求逆地理编码 + 天气
      final results = await Future.wait([
        _reverseGeocodeAll(lat, lon),
        _getWeather(lat, lon),
      ]);

      final address = results[0] as String?;
      final weather = results[1] as String?;

      final locationText = _buildLocationText(address, weather);
      if (locationText != null && locationText.isNotEmpty) {
        return LocationResult(
          type: LocationResultType.success,
          location: LocationInfo(
            latitude: lat,
            longitude: lon,
            address: locationText,
            weather: weather,
          ),
        );
      }

      // 至少返回坐标
      return LocationResult(
        type: LocationResultType.success,
        location: LocationInfo(
          latitude: lat,
          longitude: lon,
          address: '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}',
          weather: weather,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('[LocationService] GPS 定位失败: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[LocationService] GPS 定位异常: $e');
      return null;
    }
  }

  // ==================== 逆地理编码（多源降级） ====================

  static Future<String?> _reverseGeocodeAll(double lat, double lon) async {
    final nominatim = await _reverseGeocodeNominatim(lat, lon);
    if (nominatim != null) return nominatim;

    final bigData = await _reverseGeocodeBigDataCloud(lat, lon);
    if (bigData != null) return bigData;

    return null;
  }

  /// Nominatim（OpenStreetMap）— 中文支持最好
  static Future<String?> _reverseGeocodeNominatim(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&accept-language=zh-CN&zoom=14&addressdetails=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'Zoosy/1.0 (https://github.com/zoosy-app)',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final displayName = data['display_name']?.toString() ?? '';
        final address = data['address'] ?? {};

        final parts = <String>[];
        final city = address['city']?.toString() ??
            address['town']?.toString() ??
            address['village']?.toString() ??
            address['county']?.toString() ??
            '';
        final district = address['suburb']?.toString() ??
            address['neighbourhood']?.toString() ??
            address['quarter']?.toString() ??
            '';

        if (city.isNotEmpty) parts.add(city);
        if (district.isNotEmpty && district != city) parts.add(district);

        if (parts.isEmpty && displayName.isNotEmpty) {
          final segs = displayName.split(',').take(2).map((s) => s.trim());
          parts.addAll(segs);
        }

        return parts.isNotEmpty ? parts.join(' · ') : null;
      }
    } catch (_) {}
    return null;
  }

  /// BigDataCloud — 免费无需 Key
  static Future<String?> _reverseGeocodeBigDataCloud(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lon&localityLanguage=zh',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final city = data['city']?.toString() ?? '';
        final locality = data['locality']?.toString() ?? '';
        final principalSubdivision = data['principalSubdivision']?.toString() ?? '';

        final parts = <String>[];
        if (locality.isNotEmpty && locality != city) {
          parts.add(city);
          parts.add(locality);
        } else if (city.isNotEmpty) {
          parts.add(city);
        }
        if (parts.isEmpty && principalSubdivision.isNotEmpty) {
          parts.add(principalSubdivision);
        }

        return parts.isNotEmpty ? parts.join(' · ') : null;
      }
    } catch (_) {}
    return null;
  }

  // ==================== 天气 ====================

  static Future<String?> _getWeather(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code&timezone=auto',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current'];
        if (current != null) {
          final temp = current['temperature_2m'];
          final code = current['weather_code'];
          if (temp != null && code != null) {
            final desc = _weatherCodeToDesc(code as int);
            return '$desc ${temp.round()}°C';
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static String _weatherCodeToDesc(int code) {
    const descriptions = {
      0: '晴', 1: '大部晴', 2: '多云', 3: '阴天',
      45: '雾', 48: '雾凇', 51: '小毛毛雨', 53: '毛毛雨', 55: '大毛毛雨',
      61: '小雨', 63: '中雨', 65: '大雨',
      71: '小雪', 73: '中雪', 75: '大雪',
      80: '阵雨', 81: '中阵雨', 82: '大阵雨',
      85: '小阵雪', 86: '大阵雪',
      95: '雷暴', 96: '雷暴+小冰雹', 99: '雷暴+大冰雹',
    };
    return descriptions[code] ?? '未知';
  }

  // ==================== IP 定位降级 ====================

  static Future<LocationResult> _getByIp() async {
    try {
      final address = await _getAddressByIp();
      if (address != null && address.isNotEmpty) {
        return LocationResult(
          type: LocationResultType.success,
          location: LocationInfo(
            latitude: 0,
            longitude: 0,
            address: address,
          ),
        );
      }
    } catch (_) {}

    return LocationResult(
      type: LocationResultType.error,
      errorMessage: '获取位置失败，请稍后重试',
    );
  }

  static Future<String?> _getAddressByIp() async {
    final apis = [_getFromIpApi, _getFromIpapiCo, _getFromIpwho];
    for (final api in apis) {
      try {
        final address = await api();
        if (address != null && address.isNotEmpty) return address;
      } catch (_) {}
    }
    return null;
  }

  static Future<String?> _getFromIpApi() async {
    try {
      final response = await http.get(
        Uri.parse('http://ip-api.com/json/?lang=zh-CN&fields=status,country,regionName,city'),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final parts = <String>[];
          final city = _translateLocation(data['city']?.toString() ?? '');
          final regionName = _translateLocation(data['regionName']?.toString() ?? '');
          if (city.isNotEmpty) parts.add(city);
          if (regionName.isNotEmpty && regionName != city) parts.add(regionName);
          if (parts.isNotEmpty) return parts.join(' · ');
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> _getFromIpapiCo() async {
    try {
      final response = await http.get(
        Uri.parse('https://ipapi.co/json/?lang=zh'),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final parts = <String>[];
        final city = _translateLocation(data['city']?.toString() ?? '');
        final region = _translateLocation(data['region']?.toString() ?? '');
        if (city.isNotEmpty) parts.add(city);
        if (region.isNotEmpty && region != city) parts.add(region);
        if (parts.isNotEmpty) return parts.join(' · ');
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> _getFromIpwho() async {
    try {
      final response = await http.get(
        Uri.parse('https://ipwho.is/?lang=zh'),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final parts = <String>[];
          final city = _translateLocation(data['city']?.toString() ?? '');
          final region = _translateLocation(data['region']?.toString() ?? '');
          if (city.isNotEmpty) parts.add(city);
          if (region.isNotEmpty && region != city) parts.add(region);
          if (parts.isNotEmpty) return parts.join(' · ');
        }
      }
    } catch (_) {}
    return null;
  }

  // ==================== 拼音 → 中文翻译 ====================

  static String _translateLocation(String name) {
    if (TranslationService.currentLocale == 'zh' || TranslationService.currentLocale == 'zh_TW') {
      if (_cityTranslations.containsKey(name)) return _cityTranslations[name]!;
      if (_provinceTranslations.containsKey(name)) return _provinceTranslations[name]!;
    }
    return name;
  }

  static const _provinceTranslations = {
    'Anhui': '安徽', 'Beijing': '北京', 'Chongqing': '重庆',
    'Fujian': '福建', 'Gansu': '甘肃', 'Guangdong': '广东',
    'Guangxi': '广西', 'Guizhou': '贵州', 'Hainan': '海南',
    'Hebei': '河北', 'Heilongjiang': '黑龙江', 'Henan': '河南',
    'Hubei': '湖北', 'Hunan': '湖南', 'Jiangsu': '江苏',
    'Jiangxi': '江西', 'Jilin': '吉林', 'Liaoning': '辽宁',
    'Neimenggu': '内蒙古', 'Ningxia': '宁夏', 'Qinghai': '青海',
    'Shaanxi': '陕西', 'Shandong': '山东', 'Shanxi': '山西',
    'Sichuan': '四川', 'Taiwan': '台湾', 'Tianjin': '天津',
    'Xinjiang': '新疆', 'Xizang': '西藏', 'Yunnan': '云南',
    'Zhejiang': '浙江', 'Shanghai': '上海',
  };

  static const _cityTranslations = {
    'Shenzhen': '深圳', 'Guangzhou': '广州', 'Beijing': '北京', 'Shanghai': '上海',
    'Hangzhou': '杭州', 'Nanjing': '南京', 'Chengdu': '成都', 'Wuhan': '武汉',
    "Xi'an": '西安', 'Chongqing': '重庆', 'Tianjin': '天津',
    'Suzhou': '苏州', 'Zhengzhou': '郑州', 'Changsha': '长沙', 'Dongguan': '东莞',
    'Shenyang': '沈阳', 'Qingdao': '青岛', 'Dalian': '大连', 'Xiamen': '厦门',
    'Fuzhou': '福州', 'Jinan': '济南', 'Ningbo': '宁波', 'Wenzhou': '温州',
    'Hefei': '合肥', 'Kunming': '昆明', 'Foshan': '佛山', 'Wuxi': '无锡',
    'Changchun': '长春', 'Harbin': '哈尔滨', 'Nanning': '南宁', 'Guiyang': '贵阳',
    'Hong Kong': '香港', 'Macau': '澳门', 'Taipei': '台北',
    'Tokyo': '东京', 'Osaka': '大阪', 'Seoul': '首尔',
    'Singapore': '新加坡', 'Bangkok': '曼谷',
    'New York': '纽约', 'Los Angeles': '洛杉矶', 'London': '伦敦', 'Paris': '巴黎',
    'Jiujiang': '九江', "Ji'an": '吉安', 'Nanchang': '南昌',
    'Ganzhou': '赣州', 'Yichun': '宜春', 'Shangrao': '上饶',
    'Jingdezhen': '景德镇', 'Pingxiang': '萍乡', 'Xinyu': '新余',
  };

  // ==================== 工具方法 ====================

  static String? _buildLocationText(String? address, String? weather) {
    if (address == null && weather == null) return null;
    final parts = <String>[];
    if (address != null) parts.add(address);
    if (weather != null) parts.add(weather);
    return parts.join(' · ');
  }

  static Future<LocationInfo?> getCurrentLocation() async {
    final result = await getCurrentLocationResult();
    return result.location;
  }
}

enum LocationResultType { success, permissionDenied, error }

class LocationResult {
  final LocationResultType type;
  final LocationInfo? location;
  final String? errorMessage;

  LocationResult({required this.type, this.location, this.errorMessage});
  bool get isSuccess => type == LocationResultType.success;
}

class LocationInfo {
  final double latitude;
  final double longitude;
  final String address;
  final String? weather;

  LocationInfo({required this.latitude, required this.longitude, required this.address, this.weather});

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    if (weather != null) 'weather': weather,
  };

  factory LocationInfo.fromJson(Map<String, dynamic> json) => LocationInfo(
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    address: json['address'] as String? ?? '',
    weather: json['weather'] as String?,
  );
}
