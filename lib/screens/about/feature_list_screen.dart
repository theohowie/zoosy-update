import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'package:flutter/material.dart';
import '../../models/reflection.dart';

class FeatureListScreen extends StatelessWidget {
  const FeatureListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.feature_list, style: const TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(context, Icons.edit_note, context.l10n.fl_section_core, [
              _Item(context.l10n.fl_crud, context.l10n.fl_crud_sub),
              _Item(context.l10n.fl_calendar, context.l10n.fl_calendar_sub),
              _Item(context.l10n.fl_all_list, context.l10n.fl_all_list_sub),
              _Item(context.l10n.fl_detail, context.l10n.fl_detail_sub),
              _Item(context.l10n.fl_search, context.l10n.fl_search_sub),
              _Item(context.l10n.fl_favorites, context.l10n.fl_favorites_sub),
            ]),
            const SizedBox(height: 16),
            _buildSection(context, Icons.analytics_outlined, context.l10n.fl_section_stats, [
              _Item(context.l10n.fl_trend, context.l10n.fl_trend_sub),
              _Item(context.l10n.fl_insight, context.l10n.fl_insight_sub),
            ]),
            const SizedBox(height: 16),
            _buildSection(context, Icons.psychology_outlined, context.l10n.fl_section_ai, [
              _Item(context.l10n.fl_ai_summary, context.l10n.fl_ai_summary_sub),
              _Item(context.l10n.fl_voice, context.l10n.fl_voice_sub),
            ]),
            const SizedBox(height: 16),
            _buildSection(context, Icons.notifications_outlined, context.l10n.fl_section_notify, [
              _Item(context.l10n.fl_daily_remind, context.l10n.fl_daily_remind_sub),
              _Item(context.l10n.fl_shortcut, context.l10n.fl_shortcut_sub),
            ]),
            const SizedBox(height: 16),
            _buildSection(context, Icons.widgets_outlined, context.l10n.fl_section_widget, [
              _Item(context.l10n.fl_widget_styles, context.l10n.fl_widget_styles_sub),
              _Item(context.l10n.fl_widget_sync, context.l10n.fl_widget_sync_sub),
            ]),
            const SizedBox(height: 16),
            _buildSection(context, Icons.person_outline, context.l10n.fl_section_user, [
              _Item(context.l10n.fl_auth, context.l10n.fl_auth_sub),
              _Item(context.l10n.fl_security, context.l10n.fl_security_sub),
              _Item(context.l10n.fl_profile, context.l10n.fl_profile_sub),
            ]),
            const SizedBox(height: 16),
            _buildSection(context, Icons.palette_outlined, context.l10n.fl_section_theme, [
              _Item(context.l10n.fl_theme_colors, context.l10n.fl_theme_colors_sub),
              _Item(context.l10n.fl_dark_mode, context.l10n.fl_dark_mode_sub),
              _Item(context.l10n.fl_i18n, context.l10n.fl_i18n_sub),
            ]),
            const SizedBox(height: 16),
            _buildSection(context, Icons.storage_outlined, context.l10n.fl_section_data, [
              _Item(context.l10n.fl_local_store, context.l10n.fl_local_store_sub),
              _Item(context.l10n.fl_backup, context.l10n.fl_backup_sub),
              _Item(context.l10n.fl_tags, context.l10n.fl_tags_sub),
            ]),
            const SizedBox(height: 16),
            _buildSection(context, Icons.construction_outlined, context.l10n.fl_section_upcoming, [
              _Item(context.l10n.fl_cloud_sync, context.l10n.fl_cloud_sync_sub),
              _Item(context.l10n.fl_opinion_push, context.l10n.fl_opinion_push_sub),
              _Item(context.l10n.fl_cool_review, context.l10n.fl_cool_review_sub),
              _Item(context.l10n.fl_monthly_report, context.l10n.fl_monthly_report_sub),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, IconData icon, String title, List<_Item> items) {
    return Card(
      color: ZoosyTheme.surfaceOf(context),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ZoosyTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: ZoosyTheme.primary),
              ),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
            ]),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 5, height: 5,
                    decoration: BoxDecoration(color: ZoosyTheme.primary, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ZoosyTheme.textDarkOf(context))),
                        Text(item.subtitle, style: TextStyle(fontSize: 11.5, color: ZoosyTheme.textMutedOf(context), height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _Item {
  final String title;
  final String subtitle;
  _Item(this.title, this.subtitle);
}
