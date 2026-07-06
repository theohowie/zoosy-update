import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'auth_service.dart';
import 'secure_prefs.dart';

class VoiceService {
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static bool _isInitialized = false;
  static const int _freeMonthlyLimit = 3;
  static const String _usagePrefix = 'voice_usage_';
  static const String _vipKey = 'voice_vip';

  static Future<bool> _isVip() async {
    if (await AuthService.isAdmin()) return true;
    return await SecurePrefs.getBool(_vipKey);
  }

  static Future<bool> isGuest() async {
    final email = await AuthService.getLoggedInEmail();
    return email == null;
  }

  static Future<int> getRemainingUses() async {
    if (await _isVip()) return -1;
    if (await isGuest()) return 0;
    final used = await _getMonthUsage();
    return (_freeMonthlyLimit - used).clamp(0, _freeMonthlyLimit);
  }

  static Future<int> _getMonthUsage() async {
    return await SecurePrefs.getInt(_usageKey()) ?? 0;
  }

  static String _usageKey() {
    final now = DateTime.now();
    return '$_usagePrefix${now.year}${now.month.toString().padLeft(2, '0')}';
  }

  static Future<void> _incrementUsage() async {
    final key = _usageKey();
    final current = await SecurePrefs.getInt(key) ?? 0;
    await SecurePrefs.setInt(key, current + 1);
  }

  static Future<String?> startListening({
    required Function(String) onResult,
    required Function() onListeningComplete,
    required Function(String) onError,
  }) async {
    if (await isGuest()) {
      onError('guest_blocked');
      return null;
    }

    if (!await _isVip()) {
      final remaining = await getRemainingUses();
      if (remaining <= 0) {
        onError('limit_reached');
        return null;
      }
    }

    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      onError('mic_denied');
      return null;
    }

    if (!_isInitialized) {
      try {
        final available = await _speech.initialize(
          onError: (error) {
            _isInitialized = false;
            onError(_mapSpeechError(error.errorMsg));
          },
          onStatus: (status) {
            if (status == 'done' || status == 'notListening') {
              onListeningComplete();
            }
          },
        );
        if (!available) {
          _isInitialized = false;
          onError('not_available');
          return null;
        }
        _isInitialized = true;
      } catch (e) {
        _isInitialized = false;
        onError('not_available');
        return null;
      }
    }

    if (_speech.isListening) {
      await _speech.stop();
      return null;
    }

    String recognizedText = '';

    await _speech.listen(
      onResult: (result) {
        recognizedText = result.recognizedWords;
        onResult(recognizedText);
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: 'zh_CN',
        listenMode: stt.ListenMode.dictation,
        cancelOnError: true,
      ),
    );

    if (!await _isVip()) {
      await _incrementUsage();
    }

    return recognizedText;
  }

  static Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  static bool get isListening => _speech.isListening;

  static String _mapSpeechError(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('client') || lower.contains('connect')) return 'not_available';
    if (lower.contains('network') || lower.contains('internet')) return 'not_available';
    if (lower.contains('no match') || lower.contains('speech')) return 'not_available';
    return 'not_available';
  }
}
