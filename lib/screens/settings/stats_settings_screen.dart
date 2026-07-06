import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import '../../services/page_settings.dart';
import '../../services/translation_service.dart';

class StatsSettingsScreen extends StatefulWidget {
  const StatsSettingsScreen({Key? key}) : super(key: key);

  @override
  State<StatsSettingsScreen> createState() => _StatsSettingsScreenState();
}

class _StatsSettingsScreenState extends State<StatsSettingsScreen> {
  bool _showTagDist = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    _showTagDist = await PageSettings.showTagDistribution();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(TranslationService.tr('stats_settings'), style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Card(color: ZoosyTheme.surfaceOf(context), surfaceTintColor: Colors.transparent, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.2))),
            child: Column(children: [
              SwitchListTile(
                title: Text(TranslationService.tr('tag_dist_show'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: Text(TranslationService.tr('tag_dist_show_desc'), style: TextStyle(fontSize: 11)),
                value: _showTagDist, activeColor: ZoosyTheme.primary,
                onChanged: (v) async {
                  await PageSettings.setShowTagDistribution(v);
                  setState(() => _showTagDist = v);
                },
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
