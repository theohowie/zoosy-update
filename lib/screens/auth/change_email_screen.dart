import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/email_service.dart';
import '../../services/translation_service.dart';
import '../../utils/input_sanitizer.dart';
import '../../widgets/captcha_widget.dart';
import '../../widgets/toast_util.dart';

class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({Key? key}) : super(key: key);

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _oldEmailController = TextEditingController();
  final _newEmailController = TextEditingController();
  final _captchaController = TextEditingController();
  final _codeController = TextEditingController();
  final GlobalKey<CaptchaWidgetState> _captchaKey = GlobalKey<CaptchaWidgetState>();
  bool _isLoading = false;
  String? _sentCode;
  int _countdown = 0;
  String? _errorMsg, _successMsg;

  @override
  void initState() {
    super.initState();
    _loadCurrentEmail();
  }

  Future<void> _loadCurrentEmail() async {
    final email = await ProfileService.getEmail();
    _oldEmailController.text = email;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _oldEmailController.dispose();
    _newEmailController.dispose();
    _captchaController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    // 输入消毒
    final emailResult = InputSanitizer.sanitizeEmail(_newEmailController.text.trim());
    final email = emailResult.sanitized;
    if (email.isEmpty) { setState(() => _errorMsg = TranslationService.tr('enter_email_first')); return; }
    if (emailResult.hasWarning) {
      ToastUtil.showToast(context, message: emailResult.warning!, icon: Icons.warning_amber_rounded, color: Colors.orange);
    }

    if (!_captchaKey.currentState!.verify(_captchaController.text.trim())) {
      setState(() => _errorMsg = TranslationService.tr('captcha_wrong'));
      _captchaKey.currentState!.refresh();
      _captchaController.clear();
      return;
    }

    setState(() { _isLoading = true; _errorMsg = null; });
    final result = await EmailService.sendVerificationCode(email);
    if (!mounted) return;

    if (result != null && result.length == 6) {
      _sentCode = result;
      setState(() { _isLoading = false; _successMsg = TranslationService.tr('code_sent_to', params: {'email': email}); _countdown = 60; });
      _startCountdown();
    } else {
      setState(() { _errorMsg = result ?? TranslationService.tr('send_failed_short'); _isLoading = false; });
    }
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() { if (_countdown > 0) _countdown--; });
      return _countdown > 0;
    });
  }

  Future<void> _save() async {
    // 输入消毒
    final emailResult = InputSanitizer.sanitizeEmail(_newEmailController.text.trim());
    final newEmail = emailResult.sanitized;
    final code = _codeController.text.trim();

    if (code != _sentCode) { setState(() => _errorMsg = TranslationService.tr('code_wrong')); return; }
    if (newEmail.isEmpty) { setState(() => _errorMsg = TranslationService.tr('enter_email_first')); return; }

    setState(() { _isLoading = true; _errorMsg = null; });

    // 获取旧邮箱用于换绑
    final oldEmail = await ProfileService.getEmail();
    // 更新账号存储中的邮箱（换绑）
    await AuthService.updateEmail(oldEmail, newEmail);
    // 更新显示邮箱
    await ProfileService.setEmail(newEmail);
    // 同步更新登录邮箱
    await AuthService.saveLoginState(newEmail);

    setState(() { _successMsg = TranslationService.tr('email_changed'); _isLoading = false; });
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(TranslationService.tr('change_email'), style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 8),
          Text(TranslationService.tr('current_email'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: ZoosyTheme.containerLowOf(context), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(Icons.email_outlined, size: 20, color: ZoosyTheme.textMutedOf(context)),
              const SizedBox(width: 10), Text(_oldEmailController.text, style: TextStyle(fontSize: 14, color: ZoosyTheme.textMutedOf(context))),
            ]),
          ),
          const SizedBox(height: 24),

          Text(TranslationService.tr('new_email'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
          const SizedBox(height: 8),
          TextField(controller: _newEmailController, keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(hintText: TranslationService.tr('enter_new_email'), filled: true, fillColor: ZoosyTheme.surfaceOf(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.3))),
              prefixIcon: const Icon(Icons.email_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 16),

          Text(TranslationService.tr('captcha'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(flex: 3, child: TextField(controller: _captchaController,
              decoration: InputDecoration(hintText: TranslationService.tr('enter_captcha'), filled: true, fillColor: ZoosyTheme.surfaceOf(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.3))),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: SizedBox(height: 50, child: CaptchaWidget(key: _captchaKey))),
          ]),
          const SizedBox(height: 20),

          Row(children: [
            Expanded(flex: 3, child: TextField(controller: _codeController,
              decoration: InputDecoration(hintText: TranslationService.tr('email_code'), filled: true, fillColor: ZoosyTheme.surfaceOf(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.3))),
              ), keyboardType: TextInputType.number,
            )),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: SizedBox(height: 50, child: ElevatedButton(
              onPressed: _isLoading || _countdown > 0 ? null : _sendCode,
              style: ElevatedButton.styleFrom(backgroundColor: ZoosyTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
              child: Text(_countdown > 0 ? '${_countdown}s' : TranslationService.tr('get_code'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            ))),
          ]),
          const SizedBox(height: 32),

          if (_errorMsg != null) _buildMsg(_errorMsg!, Colors.red),
          if (_successMsg != null) _buildMsg(_successMsg!, Colors.green),
          const SizedBox(height: 12),

          SizedBox(height: 52, child: ElevatedButton(
            onPressed: _isLoading ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: ZoosyTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
            child: _isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text(TranslationService.tr('save'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          )),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _buildMsg(String msg, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(color == Colors.red ? Icons.error_outline : Icons.check_circle_outline, color: color, size: 16),
        const SizedBox(width: 8), Expanded(child: Text(msg, style: TextStyle(fontSize: 12, color: color))),
      ]),
    );
  }
}
