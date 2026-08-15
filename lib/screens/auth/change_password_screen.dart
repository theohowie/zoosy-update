import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import '../../models/reflection.dart';
import '../../services/auth_service.dart';
import '../../services/secure_prefs.dart';
import '../../utils/input_sanitizer.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldPwController = TextEditingController();
  final _newPwController = TextEditingController();
  final _confirmPwController = TextEditingController();
  bool _obscureOld = true, _obscureNew = true, _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMsg, _successMsg;

  @override
  void dispose() {
    _oldPwController.dispose();
    _newPwController.dispose();
    _confirmPwController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // 输入消毒
    final oldPwResult = InputSanitizer.sanitizePassword(_oldPwController.text);
    final newPwResult = InputSanitizer.sanitizePassword(_newPwController.text);
    final confirmPwResult = InputSanitizer.sanitizePassword(_confirmPwController.text);

    final oldPw = oldPwResult.sanitized;
    final newPw = newPwResult.sanitized;
    final confirmPw = confirmPwResult.sanitized;

    if (oldPw.isEmpty || newPw.isEmpty) {
      setState(() => _errorMsg = context.l10n.fill_all_fields);
      return;
    }
    if (newPw.length < 6) {
      setState(() => _errorMsg = context.l10n.new_password_min);
      return;
    }
    if (newPw != confirmPw) {
      setState(() => _errorMsg = context.l10n.password_mismatch);
      return;
    }

    setState(() { _isLoading = true; _errorMsg = null; });

    final email = await AuthService.getLoggedInEmail();
    if (email == null) {
      setState(() { _errorMsg = context.l10n.please_login_first; _isLoading = false; });
      return;
    }

    final valid = await AuthService.login(email, oldPw);
    if (!valid) {
      setState(() { _errorMsg = context.l10n.current_password_wrong; _isLoading = false; });
      return;
    }

    // 更新密码
    final accountsJson = await SecurePrefs.getString('zoosy_accounts');
    if (accountsJson != null) {
      final accounts = jsonDecode(accountsJson) as Map<String, dynamic>;
      if (accounts.containsKey(email)) {
        final account = accounts[email] as Map<String, dynamic>;
        final bytes = utf8.encode(newPw);
        account['passwordHash'] = sha256.convert(bytes).toString();
        accounts[email] = account;
        await SecurePrefs.setString('zoosy_accounts', jsonEncode(accounts));
      }
    }

    setState(() { _successMsg = context.l10n.password_changed; _isLoading = false; });
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.change_password, style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 8),
          _buildField(context.l10n.current_password, _oldPwController, _obscureOld, (v) => setState(() => _obscureOld = v), context.l10n.enter_current_password),
          const SizedBox(height: 20),
          _buildField(context.l10n.new_password_label, _newPwController, _obscureNew, (v) => setState(() => _obscureNew = v), context.l10n.password_min_length),
          const SizedBox(height: 20),
          _buildField(context.l10n.confirm_new_password, _confirmPwController, _obscureConfirm, (v) => setState(() => _obscureConfirm = v), context.l10n.reenter_new_password),
          const SizedBox(height: 32),
          _buildMessage(),
          SizedBox(height: 52, child: ElevatedButton(
            onPressed: _isLoading ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: ZoosyTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
            child: _isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text(context.l10n.save, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          )),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, bool obscure, ValueChanged<bool> onToggle, String hint) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
      const SizedBox(height: 8),
      TextField(controller: ctrl, obscureText: obscure,
        decoration: InputDecoration(hintText: hint, filled: true, fillColor: ZoosyTheme.surfaceOf(context),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.3))),
          prefixIcon: const Icon(Icons.lock_outlined, size: 20),
          suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20), onPressed: () => onToggle(!obscure)),
        ),
      ),
    ]);
  }

  Widget _buildMessage() {
    if (_errorMsg != null) return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.red.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [const Icon(Icons.error_outline, color: Colors.red, size: 16), const SizedBox(width: 8), Expanded(child: Text(_errorMsg!, style: const TextStyle(fontSize: 12, color: Colors.red)))]),
    );
    if (_successMsg != null) return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.green.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [const Icon(Icons.check_circle_outline, color: Colors.green, size: 16), const SizedBox(width: 8), Expanded(child: Text(_successMsg!, style: const TextStyle(fontSize: 12, color: Colors.green)))]),
    );
    return const SizedBox.shrink();
  }
}
