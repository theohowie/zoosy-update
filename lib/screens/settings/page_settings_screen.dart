import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import '../thoughts/thought_detail_settings_screen.dart';
import 'stats_settings_screen.dart';
import 'nav_bar_settings_screen.dart';

class PageSettingsScreen extends StatefulWidget {
  const PageSettingsScreen({Key? key}) : super(key: key);

  @override
  State<PageSettingsScreen> createState() => _PageSettingsScreenState();
}

class _PageSettingsScreenState extends State<PageSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.page_settings, style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Card(color: ZoosyTheme.surfaceOf(context), surfaceTintColor: Colors.transparent, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.2))),
            child: Column(children: [
              ListTile(
                leading: Icon(Icons.view_carousel_outlined, color: ZoosyTheme.textMutedOf(context)),
                title: Text(context.l10n.nav_bar_settings, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                subtitle: Text(context.l10n.nav_bar_settings_sub, style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () async {
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const NavBarSettingsScreen()));
                  if (result == true && mounted) setState(() {});
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.description_outlined, color: ZoosyTheme.textMutedOf(context)),
                title: Text(context.l10n.thought_detail, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                subtitle: Text(context.l10n.thought_detail_sub, style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThoughtDetailSettingsScreen())),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.bar_chart_outlined, color: ZoosyTheme.textMutedOf(context)),
                title: Text(context.l10n.stats_label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                subtitle: Text(context.l10n.stats_sub, style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsSettingsScreen())),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
