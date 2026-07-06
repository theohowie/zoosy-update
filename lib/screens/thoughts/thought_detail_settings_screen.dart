import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import '../../services/translation_service.dart';
import '../../services/prefs_util.dart';
import '../../widgets/toast_util.dart';
import '../settings/ai_settings_screen.dart';

class ThoughtDetailSettingsScreen extends StatefulWidget {
  const ThoughtDetailSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ThoughtDetailSettingsScreen> createState() => _ThoughtDetailSettingsScreenState();
}

class _ThoughtDetailSettingsScreenState extends State<ThoughtDetailSettingsScreen> {
  bool _locationEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _locationEnabled = await PrefsUtil.isLocationEnabled();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _toggleLocation(bool value) async {
    setState(() => _locationEnabled = value);
    await PrefsUtil.setLocationEnabled(value);

    if (mounted) {
      ToastUtil.showToast(
        context,
        message: value ? TranslationService.tr('location_granted') : TranslationService.tr('location_disabled'),
        icon: value ? Icons.location_on : Icons.location_off,
        color: value ? Colors.green : Colors.grey,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(
      appBar: AppBar(title: Text(TranslationService.tr('thought_detail_settings'), style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0),
      body: const Center(child: CircularProgressIndicator()),
    );

    return Scaffold(
      appBar: AppBar(title: Text(TranslationService.tr('thought_detail_settings'), style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Card(color: ZoosyTheme.surfaceOf(context), surfaceTintColor: Colors.transparent, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.2))),
            child: Column(children: [
              ListTile(
                leading: Icon(Icons.psychology_outlined, color: ZoosyTheme.textMutedOf(context)),
                title: Text(TranslationService.tr('ai_settings'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                subtitle: Text(TranslationService.tr('ai_settings_sub'), style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AISettingsScreen())),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                secondary: Icon(Icons.location_on_outlined, color: ZoosyTheme.textMutedOf(context)),
                title: Text(TranslationService.tr('thought_location'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                subtitle: Text(TranslationService.tr('thought_location_sub'), style: TextStyle(fontSize: 11)),
                value: _locationEnabled, activeColor: ZoosyTheme.primary,
                onChanged: _toggleLocation,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
