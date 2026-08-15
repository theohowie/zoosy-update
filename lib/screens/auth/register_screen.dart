import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import '../../services/auth_service.dart';
import '../../services/email_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/captcha_widget.dart';
import '../about/user_agreement_screen.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onRegisterSuccess;
  final bool useCloud;

  const RegisterScreen({Key? key, required this.onRegisterSuccess, this.useCloud = false}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _captchaInputController = TextEditingController();
  final _codeController = TextEditingController();

  final GlobalKey<CaptchaWidgetState> _captchaKey = GlobalKey<CaptchaWidgetState>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreeTerms = false;
  String? _errorMsg;
  String? _successMsg;

  String? _sentCode;

  bool _codeSent = false;
  int _countdown = 0;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);
  }

  void _triggerAgreeShake() {
    _shakeController.forward(from: 0.0);
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMsg = context.l10n.enter_email_first);
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

    final result = await EmailService.sendVerificationCode(email);
    if (!mounted) return;

    if (result != null && result.length == 6) {
      _sentCode = result;
      debugPrint('[Register] 验证码已存储: $_sentCode');
      setState(() {
        _codeSent = true;
        _isLoading = false;
        _successMsg = context.l10n.code_sent_to(email);
        _countdown = 60;
      });
      _startCountdown();
    } else {
      setState(() {
        _errorMsg = result ?? context.l10n.send_failed;
        _isLoading = false;
      });
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

  @override
  void dispose() {
    _shakeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nicknameController.dispose();
    _captchaInputController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final code = _codeController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMsg = context.l10n.fill_complete_info);
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMsg = context.l10n.password_min_length);
      return;
    }
    if (password != confirmPassword) {
      setState(() => _errorMsg = context.l10n.password_mismatch);
      return;
    }
    if (!_agreeTerms) {
      _triggerAgreeShake();
      return;
    }
    if (!_codeSent) {
      setState(() => _errorMsg = context.l10n.get_code_first);
      return;
    }
    if (code != _sentCode) {
      debugPrint('[Register] 验证码比对失败: 输入="$code" 期望="$_sentCode"');
      setState(() => _errorMsg = context.l10n.code_wrong);
      return;
    }

    setState(() { _isLoading = true; _errorMsg = null; });

    String? err;
    final success = await AuthService.register(email, password, nickname: _nicknameController.text.trim());
    err = success ? null : context.l10n.email_registered;
    if (!mounted) return;

    if (err == null) {
      await AuthService.saveLoginState(email);
      await ProfileService.setNickname(_nicknameController.text.trim());
      await ProfileService.setEmail(email);
      setState(() {
        _successMsg = context.l10n.register_success;
        _isLoading = false;
      });
      await Future.delayed(const Duration(seconds: 2));
      // 先 pop 返回登录页，再触发登录成功
      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        widget.onRegisterSuccess();
      }
    } else {
      setState(() {
        _errorMsg = err;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.register_title, style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 昵称
            Text(context.l10n.nickname, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
            const SizedBox(height: 8),
            TextField(
              controller: _nicknameController,
              decoration: InputDecoration(
                hintText: context.l10n.nickname_hint,
                filled: true, fillColor: ZoosyTheme.surfaceOf(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.3)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 邮箱
            Text(context.l10n.email, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'your@email.com',
                filled: true, fillColor: ZoosyTheme.surfaceOf(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.3)),
                ),
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 16),

            // 图形验证码
            Text(context.l10n.captcha, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _captchaInputController,
                    decoration: InputDecoration(
                      hintText: context.l10n.enter_captcha,
                      filled: true, fillColor: ZoosyTheme.surfaceOf(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.3)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: CaptchaWidget(key: _captchaKey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 发送验证码
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
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
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
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
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 密码
            Text(context.l10n.password, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
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

            // 确认密码
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
            const SizedBox(height: 16),

            // 用户协议
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                );
              },
              child: Row(
              children: [
                SizedBox(
                  height: 24, width: 24,
                  child: Checkbox(
                    value: _agreeTerms,
                    activeColor: ZoosyTheme.primary,
                    onChanged: (v) => setState(() => _agreeTerms = v!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _agreeTerms = !_agreeTerms),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 12, color: ZoosyTheme.textMutedOf(context)),
                          text: context.l10n.agree_prefix,
                        children: [
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserAgreementPage())),
                              child: Text(context.l10n.user_agreement, style: TextStyle(color: ZoosyTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                          TextSpan(text: context.l10n.and),
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyPage())),
                              child: Text(context.l10n.privacy_policy, style: TextStyle(color: ZoosyTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ),

            const SizedBox(height: 12),

            // 消息提示
            if (_errorMsg != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMsg!, style: const TextStyle(fontSize: 12, color: Colors.red))),
                  ],
                ),
              ),
            if (_successMsg != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_successMsg!, style: const TextStyle(fontSize: 12, color: Colors.green))),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // 注册按钮
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZoosyTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(context.l10n.register, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),

            const SizedBox(height: 24),

            // 登录链接
            Center(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 13, color: ZoosyTheme.textMutedOf(context)),
                    text: context.l10n.have_account,
                    children: [
                      TextSpan(
                        text: ' ${context.l10n.login_now}',
                        style: TextStyle(color: ZoosyTheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
