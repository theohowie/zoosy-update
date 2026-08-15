import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'package:flutter/material.dart';
import '../../models/reflection.dart';

class VipCenterScreen extends StatelessWidget {
  const VipCenterScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.vip_center, style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 20),
          Center(child: Icon(Icons.workspace_premium, size: 80, color: ZoosyTheme.primary.withOpacity(0.3))),
          const SizedBox(height: 16),
          Center(child: Text(context.l10n.zoosy_member, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context)))),
          const SizedBox(height: 8),
          Center(child: Text(context.l10n.more_features_coming, style: TextStyle(fontSize: 13, color: ZoosyTheme.textMutedOf(context)))),
          const SizedBox(height: 40),
          Card(color: ZoosyTheme.surfaceOf(context), surfaceTintColor: Colors.transparent, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.2))),
            child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _VipFeature(Icons.cloud_sync, context.l10n.cloud_sync_feature, context.l10n.multi_device_sync),
              const Divider(height: 20),
              _VipFeature(Icons.auto_awesome, context.l10n.ai_advanced_analysis, context.l10n.deep_insight_report),
              const Divider(height: 20),
              _VipFeature(Icons.palette_outlined, context.l10n.more_themes, context.l10n.unlock_themes),
            ])),
          ),
        ]),
      ),
    );
  }
}

class _VipFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _VipFeature(this.icon, this.title, this.desc);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ZoosyTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: ZoosyTheme.primary, size: 22)),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
        Text(desc, style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context))),
      ]),
    ]);
  }
}
