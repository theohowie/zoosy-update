import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/reflection.dart';
import '../../services/screen_time_service.dart';
import '../../services/translation_service.dart';

class PermissionSettingsScreen extends StatefulWidget {
  const PermissionSettingsScreen({Key? key}) : super(key: key);
  @override
  State<PermissionSettingsScreen> createState() => _PermissionSettingsScreenState();
}

class _PermissionSettingsScreenState extends State<PermissionSettingsScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(TranslationService.tr('permission_settings'), style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPermissionTile(context, Icons.notifications_outlined, TranslationService.tr('notification_perm'), TranslationService.tr('notification_perm_desc'), Permission.notification),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildPermissionTile(context, Icons.photo_library_outlined, TranslationService.tr('photo_perm'), TranslationService.tr('photo_perm_desc'), Permission.photos),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildPermissionTile(context, Icons.mic_outlined, TranslationService.tr('microphone_perm'), TranslationService.tr('microphone_perm_desc'), Permission.microphone),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildPermissionTile(context, Icons.location_on_outlined, TranslationService.tr('location_perm'), TranslationService.tr('location_perm_desc'), Permission.location),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildScreenTimeTile(context),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildShortcutTile(context),
        ],
      ),
    );
  }

  Widget _buildPermissionTile(BuildContext context, IconData icon, String title, String desc, Permission permission) {
    return FutureBuilder<PermissionStatus>(
      future: permission.status,
      builder: (context, snapshot) {
        final isGranted = snapshot.data?.isGranted ?? false;
        return ListTile(
          leading: Icon(icon, color: ZoosyTheme.primaryOf(context)),
          title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
          subtitle: Text(desc, style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context))),
          trailing: GestureDetector(
            onTap: isGranted ? null : () => openAppSettings(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isGranted ? Colors.green.withOpacity(0.1) : ZoosyTheme.primaryOf(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isGranted ? TranslationService.tr('granted') : TranslationService.tr('not_granted'),
                style: TextStyle(fontSize: 11, color: isGranted ? Colors.green : ZoosyTheme.primaryOf(context), fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScreenTimeTile(BuildContext context) {
    return FutureBuilder<bool>(
      future: ScreenTimeService.hasPermission(),
      builder: (context, snapshot) {
        final isGranted = snapshot.data ?? false;
        return ListTile(
          leading: Icon(Icons.timer_outlined, color: ZoosyTheme.primaryOf(context)),
          title: Text(TranslationService.tr('usage_perm'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
          subtitle: Text(TranslationService.tr('usage_perm_desc'), style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context))),
          trailing: GestureDetector(
            onTap: isGranted ? null : () => ScreenTimeService.requestPermission(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isGranted ? Colors.green.withOpacity(0.1) : ZoosyTheme.primaryOf(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isGranted ? TranslationService.tr('granted') : TranslationService.tr('not_granted'),
                style: TextStyle(fontSize: 11, color: isGranted ? Colors.green : ZoosyTheme.primaryOf(context), fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShortcutTile(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.add_box_outlined, color: ZoosyTheme.primaryOf(context)),
      title: Text(TranslationService.tr('shortcut_perm'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
      subtitle: Text(TranslationService.tr('shortcut_perm_desc'), style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context))),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          TranslationService.tr('granted'),
          style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
