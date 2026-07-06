import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import '../../services/translation_service.dart';
import '../../services/prefs_util.dart';
import '../../widgets/toast_util.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({Key? key}) : super(key: key);
  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  String _selectedLocale = 'zh';
  bool _isLoading = true;

  List<Map<String, String>> get _languages => [
    {'code': 'system', 'name': TranslationService.tr('system_default'), 'local': 'system'},
    {'code': 'zh', 'name': '简体中文', 'local': 'zh'},
    {'code': 'zh_TW', 'name': '繁体中文', 'local': 'zh_TW'},
    {'code': 'en', 'name': 'English', 'local': 'en'},
    {'code': 'de', 'name': 'Deutsch', 'local': 'de'},
    {'code': 'fr', 'name': 'Français', 'local': 'fr'},
    {'code': 'ja', 'name': '日本語', 'local': 'ja'},
    {'code': 'ko', 'name': '한국어', 'local': 'ko'},
    {'code': 'ru', 'name': 'Русский', 'local': 'ru'},
    {'code': 'th', 'name': 'ภาษาไทย', 'local': 'th'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _selectedLocale = await PrefsUtil.getLocale();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _onSelect(String code) async {
    await TranslationService.setLocale(code);
    if (mounted) {
      setState(() => _selectedLocale = code);
      ToastUtil.showToast(context, message: TranslationService.tr('language_saved'), icon: Icons.language);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(
      appBar: AppBar(title: Text(TranslationService.tr('language_title'), style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0),
      body: const Center(child: CircularProgressIndicator()),
    );

    return Scaffold(
      appBar: AppBar(title: Text(TranslationService.tr('language_title'), style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _languages.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, idx) {
          final lang = _languages[idx];
          final isSel = _selectedLocale == lang['code'];
          return ListTile(
            leading: Icon(isSel ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSel ? ZoosyTheme.primary : ZoosyTheme.textMutedOf(context)),
            title: Text(lang['name']!, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
              color: isSel ? ZoosyTheme.primary : ZoosyTheme.textDarkOf(context))),
            onTap: () => _onSelect(lang['code']!),
          );
        },
      ),
    );
  }
}
