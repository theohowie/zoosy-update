import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import '../../models/reflection.dart';
import '../../services/email_service.dart';
import '../../utils/input_sanitizer.dart';
import '../../widgets/captcha_widget.dart';
import '../../widgets/toast_util.dart';
import '../../services/secure_prefs.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailController = TextEditingController();
  final _captchaInputController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final GlobalKey<CaptchaWidgetState> _captchaKey = GlobalKey<CaptchaWidgetState>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMsg;
  String? _successMsg;

  String? _sentCode;
  int _countdown = 0;

  // 步骤：1-验证身份  2-重置密码
  int _step = 1;

  @override
  void dispose() {
    _emailController.dispose();
    _captchaInputController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    // 输入消毒
    final emailResult = InputSanitizer.sanitizeEmail(_emailController.text.trim());
    final email = emailResult.sanitized;
    if (email.isEmpty) {
      setState(() => _errorMsg = context.l10n.enter_email_first);
      return;
    }
    if (emailResult.hasWarning) {
      ToastUtil.showToast(context, message: emailResult.warning!, icon: Icons.warning_amber_rounded, color: Colors.orange);
    }

    // 检查账号是否存在
    final exists = await _accountExists(email);
    if (!exists) {
      setState(() => _errorMsg = context.l10n.account_not_found);
      return;
    }

    // 验证图形验证码
    if (!_captchaKey.currentState!.verify(_captchaInputController.text.trim())) {
      setState(() => _errorMsg = context.l10n.captcha_wrong);
      _captchaKey.currentState!.refresh();
      _captchaInputController.clear();
      return;
    }

    setState(() { _isLoading = true; _errorMsg = null; });

    final result = await EmailService.sendVerificationCode(email, purpose: 'reset');
    if (!mounted) return;

    if (result != null && result.length == 6) {
      _sentCode = result;
      setState(() {
        _isLoading = false;
        _successMsg = context.l10n.code_sent_to(email);
        _countdown = 60;
      });
      _startCountdown();
    } else {
      setState(() {
        _errorMsg = result ?? context.l10n.send_failed_short;
        _isLoading = false;
      });
    }
  }

  Future<bool> _accountExists(String email) async {
    final json = await SecurePrefs.getString('zoosy_accounts');
    if (json == null) return false;
    try {
      final accounts = jsonDecode(json) as Map<String, dynamic>;
      return accounts.containsKey(email);
    } catch (_) {
      return false;
    }
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_countdown > 0) _countdown--;
      });
      return _countdown > 0;
    });
  }

  Future<void> _resetPassword() async {
    // 输入消毒
    final emailResult = InputSanitizer.sanitizeEmail(_emailController.text.trim());
    final email = emailResult.sanitized;
    final passwordResult = InputSanitizer.sanitizePassword(_passwordController.text);
    final confirmPasswordResult = InputSanitizer.sanitizePassword(_confirmPasswordController.text);

    final password = passwordResult.sanitized;
    final confirmPassword = confirmPasswordResult.sanitized;

    if (password.length < 6) {
      setState(() => _errorMsg = context.l10n.password_min_length);
      return;
    }
    if (password != confirmPassword) {
      setState(() => _errorMsg = context.l10n.password_mismatch);
      return;
    }

    setState(() { _isLoading = true; _errorMsg = null; });

    try {
      final json = await SecurePrefs.getString('zoosy_accounts');
      if (json == null) throw Exception('账号数据不存在');

      final accounts = jsonDecode(json) as Map<String, dynamic>;
      if (!accounts.containsKey(email)) throw Exception('账号不存在');

      final account = accounts[email] as Map<String, dynamic>;
      final bytes = utf8.encode(password);
      account['passwordHash'] = sha256.convert(bytes).toString();
      accounts[email] = account;

      await SecurePrefs.setString('zoosy_accounts', jsonEncode(accounts));

      if (!mounted) return;
      setState(() {
        _successMsg = context.l10n.password_reset_success;
        _isLoading = false;
      });

      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { _errorMsg = context.l10n.reset_failed('$e'); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.reset_password, style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.email, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              enabled: _step == 1,
              decoration: InputDecoration(
                hintText: context.l10n.enter_registered_email,
                filled: true, fillColor: ZoosyTheme.surfaceOf(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.3)),
                ),
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 16),

            if (_step == 1) ...[
              Text(context.l10n.captcha, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(flex: 3, child: TextField(
                    controller: _captchaInputController,
                    decoration: InputDecoration(
                      hintText: context.l10n.enter_captcha,
                      filled: true, fillColor: ZoosyTheme.surfaceOf(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.3)),
                      ),
                    ),
                  )),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: SizedBox(height: 50, child: CaptchaWidget(key: _captchaKey))),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(flex: 3, child: TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      hintText: context.l10n.email_code,
                      filled: true, fillColor: ZoosyTheme.surfaceOf(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.3)),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  )),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: SizedBox(height: 50, child: ElevatedButton(
                    onPressed: _isLoading || _countdown > 0 ? null : _sendCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ZoosyTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text(
                      _countdown > 0 ? '${_countdown}s' : context.l10n.get_code,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ))),
                ],
              ),
              const SizedBox(height: 24),

              SizedBox(height: 52, child: ElevatedButton(
                onPressed: () {
                  if (_codeController.text.trim() != _sentCode) {
                    setState(() => _errorMsg = context.l10n.code_wrong);
                    return;
                  }
                  setState(() { _step = 2; _errorMsg = null; });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZoosyTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(context.l10n.verify_identity, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              )),
            ],

            if (_step == 2) ...[
              Text(context.l10n.new_password_label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: context.l10n.password_min_length,
                  filled: true, fillColor: ZoosyTheme.surfaceOf(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.3)),
                  ),
                  prefixIcon: const Icon(Icons.lock_outlined, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(context.l10n.confirm_password, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  hintText: context.l10n.reenter_password,
                  filled: true, fillColor: ZoosyTheme.surfaceOf(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.3)),
                  ),
                  prefixIcon: const Icon(Icons.lock_outlined, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(height: 52, child: ElevatedButton(
                onPressed: _isLoading ? null : _resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZoosyTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(context.l10n.reset_password, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              )),
            ],

            if (_errorMsg != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_errorMsg!, style: const TextStyle(fontSize: 12, color: Colors.red))),
                ]),
              ),
            ],
            if (_successMsg != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_successMsg!, style: const TextStyle(fontSize: 12, color: Colors.green))),
                ]),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
