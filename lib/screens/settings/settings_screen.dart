import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/reflection.dart';
import '../../services/theme_service.dart';
import '../../services/profile_service.dart';
import '../../services/translation_service.dart';
import '../../services/update_service.dart';
import '../profile/edit_profile_screen.dart';
import '../thoughts/favorites_screen.dart';
import '../profile/account_settings_screen.dart';
import '../../widgets/toast_util.dart';
import 'page_settings_screen.dart';
import 'tag_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'widget_settings_screen.dart';
import 'theme_settings_screen.dart';
import '../about/about_screen.dart';
import 'language_settings_screen.dart';
import 'permission_settings_screen.dart';
import '../profile/device_management_screen.dart';
import '../thoughts/trash_screen.dart';
import '../thoughts/drafts_screen.dart';
import 'cloud_sync_screen.dart';

class SettingsScreen extends StatefulWidget {
  final int reflectionsCount;
  final List<Reflection> reflections;
  final Function(String) onToggleFavorite;
  final Function(String) onDeleteReflection;
  final Function(Reflection) onUpdateReflection;
  final Function(Reflection) onRestoreFromTrash;
  final VoidCallback onLogout;
  final VoidCallback onThemeChanged;
  final VoidCallback? onNavBarChanged;

  const SettingsScreen({Key? key, required this.reflectionsCount, required this.reflections, required this.onToggleFavorite, required this.onDeleteReflection, required this.onUpdateReflection, required this.onRestoreFromTrash, required this.onLogout, required this.onThemeChanged, this.onNavBarChanged}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _nickname = 'Alex';
  String _avatarUrl = ProfileService.defaultAvatar;
  String _email = 'alex@zoosy.io';
  int _currentStreak = 0;
  bool _checkingUpdate = false;
  dynamic _updateResult; // null=未检查, true=已是最新, UpdateInfo=有新版本

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _checkUpdate() async {
    if (_checkingUpdate) return;
    setState(() {
      _checkingUpdate = true;
      _updateResult = null;
    });

    final info = await UpdateService.checkUpdate();

    if (!mounted) return;
    setState(() {
      _checkingUpdate = false;
      _updateResult = info ?? true;
    });
  }

  void _openDownload() {
    if (_updateResult is UpdateInfo) {
      final uri = Uri.parse(_updateResult.downloadUrl);
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildUpdateTrailing() {
    if (_checkingUpdate) {
      return SizedBox(
        width: 20, height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: ZoosyTheme.primary),
      );
    }
    if (_updateResult == true) {
      return Text('已是最新版', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold));
    }
    if (_updateResult is UpdateInfo) {
      return GestureDetector(
        onTap: _openDownload,
        child: Text('去更新', style: TextStyle(fontSize: 12, color: ZoosyTheme.primary, fontWeight: FontWeight.bold)),
      );
    }
    return Icon(Icons.chevron_right, size: 20, color: ZoosyTheme.textMutedOf(context));
  }

  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _currentStreak = _calcStreak(widget.reflections);
  }

  int _calcStreak(List<Reflection> reflections) {
    final dates = reflections.map((r) => r.date).toSet().toList()..sort();
    int streak = 0;
    var checkDate = DateTime.now();
    while (true) {
      final dStr = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      if (dates.contains(dStr)) { streak++; checkDate = checkDate.subtract(const Duration(days: 1)); }
      else break;
    }
    return streak;
  }

  Future<void> _loadProfile() async {
    final name = await ProfileService.getNickname();
    final avatar = await ProfileService.getAvatarUrl();
    final email = await ProfileService.getEmail();
    if (mounted) setState(() { _nickname = name; _avatarUrl = avatar; _email = email; _currentStreak = _calcStreak(widget.reflections); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(TranslationService.tr('profile_title'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
          const SizedBox(height: 20),

          Center(child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen(onSaved: _loadProfile))),
            child: Column(children: [
              Stack(children: [
                ClipOval(
                  child: Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ZoosyTheme.primary, width: 2.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _avatarUrl.startsWith('/') || _avatarUrl.startsWith('file://')
                        ? Image.file(File(_avatarUrl.replaceFirst('file://', '')), fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: ZoosyTheme.containerLowOf(context),
                              child: Icon(Icons.person, size: 40, color: ZoosyTheme.textMutedOf(context))))
                        : Image.network(_avatarUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: ZoosyTheme.containerLowOf(context),
                              child: Icon(Icons.person, size: 40, color: ZoosyTheme.textMutedOf(context)))),
                  ),
                ),
                Positioned(bottom: 0, right: 0,
                  child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: ZoosyTheme.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.edit, color: Colors.white, size: 14),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Text(_nickname, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ZoosyTheme.textDarkOf(context))),
              const SizedBox(height: 2),
              Text(_email, style: TextStyle(fontSize: 12, color: ZoosyTheme.textMutedOf(context), fontWeight: FontWeight.bold)),
            ]),
          )),
          const SizedBox(height: 28),

          Container(padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(color: ZoosyTheme.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              Column(children: [
                Text('${widget.reflectionsCount}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ZoosyTheme.primary)),
                const SizedBox(height: 2),
                Text(TranslationService.tr('total_count'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ZoosyTheme.textMutedOf(context))),
              ]),
              Container(width: 1, height: 40, color: ZoosyTheme.primary.withOpacity(0.2)),
              Column(children: [
                Text('$_currentStreak ${TranslationService.tr('unit_day')}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ZoosyTheme.primary)),
                const SizedBox(height: 2),
                Text(TranslationService.tr('current_streak'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ZoosyTheme.textMutedOf(context))),
              ]),
            ]),
          ),
          const SizedBox(height: 28),

          // 关于 Zoosy
          Card(color: ZoosyTheme.surfaceOf(context), surfaceTintColor: Colors.transparent, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.2))),
            child: ListTile(
              leading: Icon(Icons.info_outline, color: ZoosyTheme.primary),
              title: Text(TranslationService.tr('about_zoosy'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
              subtitle: Text(TranslationService.tr('about_subtitle'), style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context))),
              trailing: Icon(Icons.chevron_right, size: 20, color: ZoosyTheme.textMutedOf(context)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
            ),
          ),

          Card(color: ZoosyTheme.surfaceOf(context), surfaceTintColor: Colors.transparent, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.2))),
            child: Column(children: [
              ListTile(leading: Icon(Icons.favorite_outline, color: ZoosyTheme.textMutedOf(context)),
                title: Text(TranslationService.tr('my_favorites'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FavoritesScreen(
                  reflections: widget.reflections, onToggleFavorite: widget.onToggleFavorite, onDeleteReflection: widget.onDeleteReflection, onUpdateReflection: widget.onUpdateReflection,
                ))),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(leading: Icon(Icons.article_outlined, color: ZoosyTheme.textMutedOf(context)),
                title: Text(TranslationService.tr('drafts_title'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DraftsScreen(
                  onPublish: (ref) {
                    widget.onUpdateReflection(ref);
                  },
                ))),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(leading: Icon(Icons.delete_outline, color: ZoosyTheme.textMutedOf(context)),
                title: Text(TranslationService.tr('trash_title'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrashScreen(
                  onRestore: (ref) {
                    widget.onRestoreFromTrash(ref);
                  },
                ))),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(leading: Icon(Icons.settings_outlined, color: ZoosyTheme.textMutedOf(context)),
                title: Text(TranslationService.tr('settings_title'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _SettingsDetailScreen(onThemeChanged: widget.onThemeChanged, onProfileSaved: _loadProfile, reflectionsCount: widget.reflectionsCount, currentStreak: _currentStreak, reflections: widget.reflections, onNavBarChanged: widget.onNavBarChanged))),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(leading: Icon(Icons.system_update_outlined, color: ZoosyTheme.textMutedOf(context)),
                title: Text(TranslationService.tr('check_update'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                trailing: _buildUpdateTrailing(),
                onTap: _checkUpdate,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(leading: Icon(Icons.backup_outlined, color: ZoosyTheme.textMutedOf(context)),
                title: Text(TranslationService.tr('data_backup'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _exportBackup(context),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(leading: Icon(Icons.restore_outlined, color: ZoosyTheme.textMutedOf(context)),
                title: Text(TranslationService.tr('restore_data'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _restoreData(context),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(leading: Icon(Icons.cloud_outlined, color: ZoosyTheme.textMutedOf(context)),
                title: Text(TranslationService.tr('cloud_sync'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                subtitle: Text('WebDAV 同步到坚果云等', style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context))),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CloudSyncScreen(
                  reflections: widget.reflections,
                  onSyncCompleted: (refs) {
                    for (final ref in refs) {
                      widget.onUpdateReflection(ref);
                    }
                  },
                ))),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(leading: Icon(Icons.share_outlined, color: ZoosyTheme.textMutedOf(context)),
                title: Text(TranslationService.tr('export_markdown'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _exportMarkdown(context),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
            ]),
          ),

          const SizedBox(height: 28),
          SizedBox(width: double.infinity, height: 50,
            child: OutlinedButton.icon(
              onPressed: () {
                showDialog(context: context, builder: (ctx) => AlertDialog(
                  backgroundColor: ZoosyTheme.surfaceOf(ctx), surfaceTintColor: Colors.transparent,
                  title: Text(TranslationService.tr('logout'), style: TextStyle(color: ZoosyTheme.textDarkOf(ctx))), content: Text(TranslationService.tr('logout_confirm'), style: TextStyle(color: ZoosyTheme.textMutedOf(ctx))),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text(TranslationService.tr('cancel'))),
                    TextButton(onPressed: () { Navigator.pop(ctx); widget.onLogout(); }, child: Text(TranslationService.tr('logout_action'), style: TextStyle(color: Colors.red))),
                  ],
                ));
              },
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: Text(TranslationService.tr('logout'), style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.red.withOpacity(0.3)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            ),
          ),
          const SizedBox(height: 48),
        ]),
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final jsonList = widget.reflections.map((r) => <String, dynamic>{
        'id': r.id, 'title': r.title, 'content': r.content, 'date': r.date, 'time': r.time,
        'tags': r.tags, 'isFavorite': r.isFavorite, 'imageUrl': r.imageUrl,
        'aiSummary': r.aiSummary, 'emotions': r.emotions,
      }).toList();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(jsonList);

      // 保存到 Download/zoosy/backup/
      final dir = Directory('/storage/emulated/0/Download/zoosy/backup');
      if (!await dir.exists()) await dir.create(recursive: true);
      final now = DateTime.now();
      final file = File('${dir.path}/zoosy_backup_${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}.json');
      await file.writeAsString(jsonStr);
      if (context.mounted) {
        ToastUtil.showToast(context, message: '备份已保存到 Download/zoosy/backup/', icon: Icons.backup, color: Colors.green);
      }
    } catch (e) {
      if (context.mounted) ToastUtil.showToast(context, message: '导出失败: $e', icon: Icons.error_outline, color: Colors.red);
    }
  }

  Future<void> _exportMarkdown(BuildContext context) async {
    try {
      final buf = StringBuffer();
      buf.writeln('# Zoosy 思考记录\n');
      buf.writeln('导出时间: ${DateTime.now().year}年${DateTime.now().month}月${DateTime.now().day}日\n---\n');
      for (final r in widget.reflections) {
        buf.writeln('## ${r.title}\n');
        buf.writeln('**日期**: ${r.date} ${r.time}');
        if (r.tags.isNotEmpty) buf.writeln('**标签**: ${r.tags.join(", ")}');
        buf.writeln('\n${r.content}\n\n---\n');
      }

      // 保存到 Download/zoosy/download/
      final dir = Directory('/storage/emulated/0/Download/zoosy/download');
      if (!await dir.exists()) await dir.create(recursive: true);
      final now = DateTime.now();
      final file = File('${dir.path}/zoosy_${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}.md');
      await file.writeAsString(buf.toString());
      if (context.mounted) {
        ToastUtil.showToast(context, message: '已保存到 Download/zoosy/download/', icon: Icons.check, color: Colors.green);
      }
    } catch (e) {
      if (context.mounted) ToastUtil.showToast(context, message: '导出失败: $e', icon: Icons.error_outline, color: Colors.red);
    }
  }

  static const _filePickerChannel = MethodChannel('zoosy/file_picker');

  Future<void> _restoreData(BuildContext context) async {
    try {
      final jsonStr = await _filePickerChannel.invokeMethod<String?>('pickJsonFile');
      if (jsonStr == null) return;

      final List<dynamic> data = jsonDecode(jsonStr) as List<dynamic>;

      for (final item in data) {
        final map = item as Map<String, dynamic>;
        final rawId = map['id'] as String?;
        final stableId = rawId ?? sha256.convert(utf8.encode('${map['title']}${map['content']}${map['date']}')).toString().substring(0, 16);
        final ref = Reflection(
          id: stableId,
          title: map['title'] as String? ?? '',
          content: map['content'] as String? ?? '',
          date: map['date'] as String? ?? '',
          time: map['time'] as String? ?? '',
          tags: (map['tags'] as List<dynamic>?)?.cast<String>() ?? [],
          isFavorite: map['isFavorite'] as bool? ?? false,
          imageUrl: map['imageUrl'] as String?,
          aiSummary: map['aiSummary'] as String?,
          emotions: (map['emotions'] as List<dynamic>?)?.cast<String>() ?? [],
        );
        widget.onUpdateReflection(ref);
      }
      if (context.mounted) ToastUtil.showToast(context, message: '已恢复 ${data.length} 条记录', icon: Icons.restore, color: Colors.green);
    } catch (e) {
      if (context.mounted) ToastUtil.showToast(context, message: '恢复失败: $e', icon: Icons.error_outline, color: Colors.red);
    }
  }
}

class _SettingsDetailScreen extends StatefulWidget {
  final VoidCallback onThemeChanged;
  final VoidCallback onProfileSaved;
  final int reflectionsCount;
  final int currentStreak;
  final List<Reflection> reflections;
  final VoidCallback? onNavBarChanged;
  const _SettingsDetailScreen({required this.onThemeChanged, required this.onProfileSaved, required this.reflectionsCount, required this.currentStreak, required this.reflections, this.onNavBarChanged});

  @override
  State<_SettingsDetailScreen> createState() => _SettingsDetailScreenState();
}

class _SettingsDetailScreenState extends State<_SettingsDetailScreen> {

  Future<void> _openThemeSettings() async {
    final color = await ThemeService.getColor();
    final mode = await ThemeService.getMode();
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ThemeSettingsScreen(currentColor: color, currentMode: mode, onChanged: widget.onThemeChanged)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(TranslationService.tr('settings_title'), style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Card(color: ZoosyTheme.surfaceOf(context), surfaceTintColor: Colors.transparent, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.2))),
            child: Column(children: [
              ListTile(leading: Icon(Icons.person_outline, color: ZoosyTheme.textMutedOf(context)),
                title: Text(TranslationService.tr('edit_profile'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                subtitle: Text(TranslationService.tr('edit_profile_sub'), style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen(onSaved: widget.onProfileSaved))),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(leading: Icon(Icons.security_outlined, color: ZoosyTheme.textMutedOf(context)),
                title: Text(TranslationService.tr('account_settings'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                subtitle: Text(TranslationService.tr('account_settings_sub'), style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSettingsScreen())),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(leading: Icon(Icons.pages_outlined, color: ZoosyTheme.textMutedOf(context)),
                title: Text(TranslationService.tr('page_settings'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                subtitle: Text(TranslationService.tr('page_settings_sub'), style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () async {
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const PageSettingsScreen()));
                  if (result == true && widget.onNavBarChanged != null) {
                    widget.onNavBarChanged!();
                  }
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(leading: Icon(Icons.label_outline, color: ZoosyTheme.textMutedOf(context)),
                title: Text(TranslationService.tr('tag_settings'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                subtitle: Text(TranslationService.tr('tag_settings_sub'), style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TagSettingsScreen())),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(leading: Icon(Icons.language, color: ZoosyTheme.textMutedOf(context)),
                title: Text(TranslationService.tr('language_settings'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                subtitle: Text(TranslationService.tr('language_sub'), style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageSettingsScreen())),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(leading: Icon(Icons.palette_outlined, color: ZoosyTheme.textMutedOf(context)),
                title: Text(TranslationService.tr('theme_settings'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                subtitle: Text(TranslationService.tr('theme_settings_sub'), style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, size: 20), onTap: _openThemeSettings),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(leading: Icon(Icons.widgets_outlined, color: ZoosyTheme.textMutedOf(context)),
                title: Text(TranslationService.tr('widget_settings'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                subtitle: Text(TranslationService.tr('widget_settings_sub'), style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WidgetSettingsScreen(reflectionCount: widget.reflectionsCount, currentStreak: widget.currentStreak, reflections: widget.reflections))),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(leading: Icon(Icons.notifications_outlined, color: ZoosyTheme.textMutedOf(context)),
                title: Text(TranslationService.tr('notification_settings'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                subtitle: Text(TranslationService.tr('notification_settings_sub'), style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(leading: Icon(Icons.security, color: ZoosyTheme.textMutedOf(context)),
                title: Text(TranslationService.tr('permission_settings'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                subtitle: Text(TranslationService.tr('permission_sub'), style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PermissionSettingsScreen())),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(leading: Icon(Icons.devices, color: ZoosyTheme.textMutedOf(context)),
                title: Text(TranslationService.tr('device_management'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                subtitle: Text(TranslationService.tr('device_sub'), style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeviceManagementScreen())),
              ),

            ]),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}

/// 公开包装器，供顶部齿轮图标直接跳转到设置页
/// 备注：当前未被任何路由引用，保留以供后续扩展使用
class SettingsDetailScreenWrapper extends StatefulWidget {
  /// 主题变更回调
  final VoidCallback? onThemeChanged;

  const SettingsDetailScreenWrapper({Key? key, this.onThemeChanged}) : super(key: key);

  @override
  State<SettingsDetailScreenWrapper> createState() => _SettingsDetailScreenWrapperState();
}

class _SettingsDetailScreenWrapperState extends State<SettingsDetailScreenWrapper> {
  @override
  Widget build(BuildContext context) {
    return _SettingsDetailScreen(
      onThemeChanged: widget.onThemeChanged ?? () {
        // 无回调时尝试向上查找 ZoosyApp 触发重建
        final appState = context.findAncestorStateOfType<State>();
        if (appState != null && appState.mounted) {
          try {
            // 通过 dynamic 调用私有方法，无安全风险——无匹配时静默失败
            (appState as dynamic)._onThemeChanged();
          } catch (_) {}
        }
        setState(() {});
      },
      onProfileSaved: () {},
      reflectionsCount: 0,
      currentStreak: 0,
      reflections: const [],
    );
  }
}
