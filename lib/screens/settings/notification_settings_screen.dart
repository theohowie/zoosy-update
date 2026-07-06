import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import '../../services/notification_service.dart';
import '../../services/translation_service.dart';
import '../edit_field_screen.dart';
import '../../widgets/toast_util.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _enabled = true;
  String _title = '';
  String _content = '';
  int _hour = 21;
  int _minute = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _enabled = await NotificationService.isEnabled();
    _title = await NotificationService.getTitle();
    _content = await NotificationService.getContent();
    _hour = await NotificationService.getHour();
    _minute = await NotificationService.getMinute();
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    await NotificationService.setTitle(_title);
    await NotificationService.setContent(_content);
    await NotificationService.setTime(_hour, _minute);
    // 重置今日触发标记，允许新时间生效
    await NotificationService.onTimeChanged();
    if (!mounted) return;
    ToastUtil.showToast(context, message: TranslationService.tr('notification_saved'), icon: Icons.check, color: Colors.green);
    Navigator.pop(context);
  }

  void _editTitle() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EditFieldScreen(
      title: TranslationService.tr('notif_title_label'),
      initialValue: _title,
      hintText: NotificationService.defaultTitle,
      maxLength: 16,
      onSave: (v) => setState(() => _title = v),
    )));
  }

  void _editContent() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EditFieldScreen(
      title: TranslationService.tr('notif_content_label'),
      initialValue: _content,
      hintText: NotificationService.defaultContent,
      maxLength: 30,
      onSave: (v) => setState(() => _content = v),
    )));
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: ZoosyTheme.surfaceOf(context),
              hourMinuteColor: ZoosyTheme.containerLowOf(context),
              hourMinuteTextColor: ZoosyTheme.textDarkOf(context),
              dialHandColor: ZoosyTheme.primary,
              dialBackgroundColor: ZoosyTheme.containerLowOf(context),
              entryModeIconColor: ZoosyTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _hour = picked.hour;
        _minute = picked.minute;
      });
      // 保存时间并重置触发标记
      await NotificationService.setTime(_hour, _minute);
      await NotificationService.onTimeChanged();
    }
  }

  String _formatTime() {
    return '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(TranslationService.tr('notification_settings'), style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0,
        actions: [TextButton(onPressed: _save, child: Text(TranslationService.tr('save'), style: TextStyle(color: ZoosyTheme.primary, fontWeight: FontWeight.bold, fontSize: 15)))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Card(color: ZoosyTheme.surfaceOf(context), surfaceTintColor: Colors.transparent, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.2))),
            child: Column(children: [
              SwitchListTile(
                title: Text(TranslationService.tr('daily_reminder'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: Text(TranslationService.tr('daily_reminder_desc'), style: TextStyle(fontSize: 11)),
                value: _enabled, activeColor: ZoosyTheme.primary,
                onChanged: (v) {
                  setState(() => _enabled = v);
                  NotificationService.toggleEnabled(v);
                },
              ),
            ]),
          ),

          if (_enabled) ...[
            const SizedBox(height: 20),

            // 时间设置
            Text(TranslationService.tr('notif_time_label'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
            const SizedBox(height: 12),
            Card(color: ZoosyTheme.surfaceOf(context), surfaceTintColor: Colors.transparent, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.2))),
              child: ListTile(
                leading: Icon(Icons.access_time, color: ZoosyTheme.textMutedOf(context)),
                title: Text(TranslationService.tr('notif_time'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  TranslationService.tr('notif_time_desc', params: {'time': _formatTime()}),
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ZoosyTheme.primary),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: ZoosyTheme.textMutedOf(context), size: 20),
                  ],
                ),
                onTap: _selectTime,
              ),
            ),

            const SizedBox(height: 20),

            // 通知内容
            Text(TranslationService.tr('notification_style'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
            const SizedBox(height: 12),
            Card(color: ZoosyTheme.surfaceOf(context), surfaceTintColor: Colors.transparent, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.2))),
              child: Column(children: [
                ListTile(
                  leading: Icon(Icons.title, color: ZoosyTheme.textMutedOf(context)),
                  title: Text(TranslationService.tr('notif_title_label'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                  subtitle: Text(_title, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: _editTitle,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.article_outlined, color: ZoosyTheme.textMutedOf(context)),
                  title: Text(TranslationService.tr('notif_content_label'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                  subtitle: Text(_content, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: _editContent,
                ),
              ]),
            ),

            const SizedBox(height: 16),

            // 测试通知
            SizedBox(height: 48, child: OutlinedButton.icon(
              onPressed: () async {
                await NotificationService.setTitle(_title);
                await NotificationService.setContent(_content);
                await NotificationService.showTestNotification();
              },
              icon: const Icon(Icons.notifications_active_outlined, size: 20),
              label: Text(TranslationService.tr('send_test_notif')),
              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            )),
          ],
        ]),
      ),
    );
  }
}
