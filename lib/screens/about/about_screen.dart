import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../models/reflection.dart';
import '../../services/theme_service.dart';
import 'feature_list_screen.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.about_zoosy, style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Logo
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: ZoosyTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(ThemeService.currentLogoAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(Icons.psychology, color: ZoosyTheme.primary, size: 40),
              ),
            ),
            const SizedBox(height: 16),
            Text('Zoosy', style: TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontSize: 28,
              fontWeight: FontWeight.w800, color: ZoosyTheme.primary,
              letterSpacing: -0.5,
            )),
            const SizedBox(height: 4),
            Text(context.l10n.slogan, style: TextStyle(fontSize: 14, color: ZoosyTheme.textMutedOf(context))),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: ZoosyTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('v$_version', style: TextStyle(fontSize: 12, color: ZoosyTheme.primary, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 32),

            // 功能列表
            Card(
              color: ZoosyTheme.surfaceOf(context),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.2)),
              ),
              child: Column(children: [
                _buildFeatureTile(context, Icons.edit_note, context.l10n.feature_daily_reflection, context.l10n.feature_daily_reflection_sub),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildFeatureTile(context, Icons.analytics, context.l10n.feature_stats, context.l10n.feature_stats_sub),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildFeatureTile(context, Icons.psychology, context.l10n.feature_ai, context.l10n.feature_ai_sub),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildFeatureTile(context, Icons.widgets, context.l10n.feature_widget, context.l10n.feature_widget_sub),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildFeatureTile(context, Icons.palette, context.l10n.feature_theme, context.l10n.feature_theme_sub),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildFeatureTile(context, Icons.cloud_sync, context.l10n.feature_cloud, context.l10n.feature_cloud_sub),
              ]),
            ),
            const SizedBox(height: 24),

            // 功能清单入口
            Card(
              color: ZoosyTheme.surfaceOf(context),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.2)),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: ZoosyTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.checklist, size: 20, color: ZoosyTheme.primary),
                ),
                title: Text(context.l10n.feature_list, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
                subtitle: Text(context.l10n.about_subtitle, style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context))),
                trailing: Icon(Icons.chevron_right, size: 20, color: ZoosyTheme.textMutedOf(context)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeatureListScreen())),
              ),
            ),
            const SizedBox(height: 24),

            // 描述
            Text(
              context.l10n.about_description,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: ZoosyTheme.textMutedOf(context), height: 1.6),
            ),
            const SizedBox(height: 40),

            // 底部版权
            Text(
              '© 2026 Zoosy. All rights reserved.',
              style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context).withOpacity(0.6)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTile(BuildContext context, IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: ZoosyTheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: ZoosyTheme.primary),
      ),
      title: Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context))),
    );
  }
}
