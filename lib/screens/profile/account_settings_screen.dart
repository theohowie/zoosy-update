import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import '../../services/profile_service.dart';
import '../auth/change_password_screen.dart';
import '../auth/change_email_screen.dart';
import '../auth/change_phone_screen.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({Key? key}) : super(key: key);

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  String _email = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final email = await ProfileService.getEmail();
    if (mounted) setState(() => _email = email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.account_settings, style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Card(color: ZoosyTheme.surfaceOf(context), surfaceTintColor: Colors.transparent, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.2))),
            child: Column(children: [
              ListTile(leading: Icon(Icons.lock_outline, color: ZoosyTheme.textMutedOf(context)),
                title: Text(context.l10n.change_password, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                subtitle: Text(context.l10n.change_password_sub, style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(leading: Icon(Icons.email_outlined, color: ZoosyTheme.textMutedOf(context)),
                title: Text(context.l10n.change_email, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                subtitle: Text(context.l10n.change_email_sub(_email), style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangeEmailScreen())),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(leading: Icon(Icons.phone_outlined, color: ZoosyTheme.textMutedOf(context)),
                title: Text(context.l10n.bind_phone, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                subtitle: Text(context.l10n.not_bound, style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePhoneScreen())),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
