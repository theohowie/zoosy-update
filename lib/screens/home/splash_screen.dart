import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import '../../services/theme_service.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onSplashCompleted;
  const SplashScreen({Key? key, required this.onSplashCompleted}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _bounceAnimation = Tween<double>(begin: 0, end: -10).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    Timer(const Duration(milliseconds: 2200), () => widget.onSplashCompleted());
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Spacer(flex: 2),
          // Zoosy 标题
          Text('Zoosy', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 34, fontWeight: FontWeight.w800, color: ZoosyTheme.primary, letterSpacing: -1.0)),
          const SizedBox(height: 8),
          Text(context.l10n.slogan, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: ZoosyTheme.textMutedOf(context).withOpacity(0.8))),
          const Spacer(flex: 1),
          // 中间 Logo 卡片（弹性动画）
          AnimatedBuilder(animation: _bounceAnimation, builder: (context, child) {
            return Transform.translate(offset: Offset(0, _bounceAnimation.value),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ZoosyTheme.surfaceOf(context),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [BoxShadow(color: ZoosyTheme.primary.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 15))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(ThemeService.currentLogoAsset, width: 120, height: 120, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(width: 120, height: 120,
                      decoration: BoxDecoration(color: ZoosyTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(24)),
                      child: Icon(Icons.psychology, size: 60, color: ZoosyTheme.primary),
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(flex: 1),
          // 底部标语 + 进度条
          Column(children: [
            Text(context.l10n.splash_line1, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ZoosyTheme.textMutedOf(context))),
            Text(context.l10n.splash_line2, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ZoosyTheme.textMutedOf(context))),
            const SizedBox(height: 24),
            SizedBox(width: 120, height: 5,
              child: ClipRRect(borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(ZoosyTheme.primary), backgroundColor: const Color(0xFFE5DEFF)),
              ),
            ),
          ]),
          const Spacer(flex: 2),
        ]),
      ),
    );
  }
}
