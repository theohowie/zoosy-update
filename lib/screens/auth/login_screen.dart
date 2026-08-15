import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/secure_prefs.dart';
import '../../services/theme_service.dart';
import 'register_screen.dart';
import 'reset_password_screen.dart';
import '../about/user_agreement_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final bool useCloud;

  const LoginScreen({Key? key, required this.onLoginSuccess, this.useCloud = false}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _agreeTerms = false;
  bool _rememberPassword = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMsg;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _loadSavedState();
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

  Future<void> _loadSavedState() async {
    final email = await AuthService.getLoggedInEmail();
    if (email != null) {
      _emailController.text = email;
    }
    final savedEmail = await SecurePrefs.getString('login_remember_email');
    final savedPassword = await SecurePrefs.getString('login_remember_password');
    if (savedEmail != null && savedPassword != null) {
      _emailController.text = savedEmail;
      _passwordController.text = savedPassword;
      _rememberPassword = true;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerAgreeShake() {
    _shakeController.forward(from: 0.0);
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMsg = context.l10n.enter_email_password);
      return;
    }
    if (!_agreeTerms) {
      _triggerAgreeShake();
      return;
    }

    setState(() { _isLoading = true; _errorMsg = null; });

    String? err;
    final success = await AuthService.login(email, password);
    err = success ? null : context.l10n.email_password_error;
    if (!mounted) return;

    if (err == null) {
      await AuthService.saveLoginState(email);
      if (_rememberPassword) {
        await SecurePrefs.setString('login_remember_email', email);
        await SecurePrefs.setString('login_remember_password', password);
      } else {
        await SecurePrefs.remove('login_remember_email');
        await SecurePrefs.remove('login_remember_password');
      }
      // 同步资料
      final savedName = await ProfileService.getNickname();
      if (savedName == 'Alex') {
        await ProfileService.setNickname(email.split('@').first);
      }
      await ProfileService.setEmail(email);
      widget.onLoginSuccess();
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 跳过按钮
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () async {
                    final proceed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: ZoosyTheme.surfaceOf(ctx),
                        surfaceTintColor: Colors.transparent,
                        title: Text(ctx.l10n.guest_login, style: TextStyle(color: ZoosyTheme.textDarkOf(ctx))),
                        content: Text(
                          ctx.l10n.guest_login_desc,
                          style: TextStyle(fontSize: 13, color: ZoosyTheme.textMutedOf(ctx), height: 1.5),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(ctx.l10n.cancel, style: TextStyle(color: ZoosyTheme.textMutedOf(ctx))),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: ZoosyTheme.primary),
                            child: Text(ctx.l10n.confirm, style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (proceed == true && context.mounted) {
                      // 游客登录持久化：重启 App 后无需重新游客登录
                      await AuthService.saveLoginState(AuthService.guestEmail);
                      if (context.mounted) widget.onLoginSuccess();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(context.l10n.guest_login, style: TextStyle(fontSize: 13, color: ZoosyTheme.primary, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(ThemeService.currentLogoAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.psychology, color: ZoosyTheme.primary, size: 32),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Zoosy',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: ZoosyTheme.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                      Text(
                      context.l10n.slogan,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: ZoosyTheme.textMutedOf(context), letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              Text(context.l10n.email, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'your@email.com',
                  filled: true,
                  fillColor: ZoosyTheme.surfaceOf(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.3)),
                  ),
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 18),

              Text(context.l10n.password, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: context.l10n.enter_password,
                  filled: true,
                  fillColor: ZoosyTheme.surfaceOf(context),
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
              const SizedBox(height: 12),

              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _rememberPassword = !_rememberPassword),
                    child: Row(children: [
                      SizedBox(
                        height: 20, width: 20,
                        child: Checkbox(
                          value: _rememberPassword,
                          activeColor: ZoosyTheme.primary,
                          onChanged: (v) => setState(() => _rememberPassword = v!),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(context.l10n.remember_password, style: TextStyle(fontSize: 12, color: ZoosyTheme.textMutedOf(context))),
                    ]),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
                      );
                    },
                    child: Text(
                      context.l10n.forgot_password,
                      style: TextStyle(fontSize: 12, color: ZoosyTheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

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

              if (_errorMsg != null) ...[
                const SizedBox(height: 12),
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
              ],

              const SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZoosyTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text(context.l10n.login, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),

              const SizedBox(height: 20),

              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RegisterScreen(
                        onRegisterSuccess: widget.onLoginSuccess, useCloud: widget.useCloud,
                      )),
                    );
                  },
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 13, color: ZoosyTheme.textMutedOf(context)),
                      text: context.l10n.no_account,
                      children: [
                        TextSpan(
                          text: ' ${context.l10n.register_now}',
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
      ),
    );
  }
}
