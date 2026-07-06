import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import '../../services/theme_service.dart';
import '../../services/translation_service.dart';
import 'reflection_detail_screen.dart';
import 'new_reflection_screen.dart';

/// 保存成功反馈页面（带庆祝动效）
class SaveSuccessScreen extends StatefulWidget {
  final Reflection reflection;
  final Function(Reflection) onSave;

  const SaveSuccessScreen({Key? key, required this.reflection, required this.onSave}) : super(key: key);

  @override
  State<SaveSuccessScreen> createState() => _SaveSuccessScreenState();
}

class _SaveSuccessScreenState extends State<SaveSuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _confettiController;
  late Animation<double> _confettiAnimation;
  final _confettiParticles = <_ConfettiParticle>[];
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _generateParticles();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..forward();
    _confettiAnimation = CurvedAnimation(parent: _confettiController, curve: Curves.easeOut);
    _confettiController.addListener(() => setState(() {}));
  }

  void _generateParticles() {
    final colors = [
      ZoosyTheme.primary,
      Colors.pink,
      Colors.orange,
      Colors.cyan,
      Colors.amber,
      Colors.green,
      Colors.purple,
    ];
    for (int i = 0; i < 60; i++) {
      _confettiParticles.add(_ConfettiParticle(
        x: _random.nextDouble(),
        speedX: (_random.nextDouble() - 0.5) * 0.02,
        speedY: _random.nextDouble() * 0.03 + 0.01,
        rotation: _random.nextDouble() * 6.28,
        rotationSpeed: (_random.nextDouble() - 0.5) * 0.1,
        size: _random.nextDouble() * 10 + 4,
        color: colors[_random.nextInt(colors.length)],
        delay: _random.nextDouble() * 1.5,
      ));
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _viewRecord() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ReflectionDetailScreen(
        reflection: widget.reflection,
        onToggleFavorite: (id) {},
        onDeleteReflection: (id) { Navigator.of(context).pop(); },
        onUpdateReflection: (ref) {},
      )),
    );
  }

  void _writeAnother() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => NewReflectionScreen(onSave: widget.onSave)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZoosyTheme.bgOf(context),
      body: Stack(
        children: [
          // 彩屑动效层
          if (_confettiAnimation.value < 1.0)
            Positioned.fill(
              child: CustomPaint(
                painter: _ConfettiPainter(
                  particles: _confettiParticles,
                  progress: _confettiAnimation.value,
                ),
              ),
            ),
          // 主内容
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 20),
                    // LOGO 卡片
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: ZoosyTheme.primary.withOpacity(0.12),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                ThemeService.currentLogoAsset,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(Icons.psychology, size: 48, color: ZoosyTheme.primary),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Zoosy',
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: ZoosyTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // 主标题
                    Text(
                      TranslationService.tr('record_success'),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: ZoosyTheme.textDarkOf(context),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 副标题
                    Text(
                      TranslationService.tr('record_success_sub'),
                      style: TextStyle(
                        fontSize: 14,
                        color: ZoosyTheme.textMutedOf(context),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // 查看记录按钮
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _viewRecord,
                        icon: const Icon(Icons.visibility_outlined, color: Colors.white, size: 20),
                        label: Text(TranslationService.tr('view_record'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ZoosyTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // 再记一笔按钮
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _writeAnother,
                        icon: Icon(Icons.edit_outlined, color: ZoosyTheme.primary, size: 20),
                        label: Text(TranslationService.tr('write_another'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ZoosyTheme.primary)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: ZoosyTheme.primary.withOpacity(0.06),
                          side: BorderSide(color: ZoosyTheme.primary.withOpacity(0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // 底部激励条
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: ZoosyTheme.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline, size: 20, color: ZoosyTheme.primary),
                          const SizedBox(width: 10),
                          Text(
                            TranslationService.tr('reflection_builds_resilience'),
                            style: TextStyle(fontSize: 13, color: ZoosyTheme.textMutedOf(context)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  彩屑粒子模型
// ============================================================
class _ConfettiParticle {
  final double x;
  final double speedX;
  final double speedY;
  double rotation;
  final double rotationSpeed;
  final double size;
  final Color color;
  final double delay;

  _ConfettiParticle({
    required this.x,
    required this.speedX,
    required this.speedY,
    required this.rotation,
    required this.rotationSpeed,
    required this.size,
    required this.color,
    required this.delay,
  });
}

// ============================================================
//  彩屑画板
// ============================================================
class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = (progress - p.delay).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final x = p.x * size.width + p.speedX * t * size.width;
      final y = -p.size - t * t * size.height * 1.2;
      final alpha = (1 - t * 0.6).clamp(0.0, 1.0);
      final rot = p.rotation + p.rotationSpeed * t * 20;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);

      final paint = Paint()
        ..color = p.color.withOpacity(alpha)
        ..style = PaintingStyle.fill;

      // 矩形彩屑
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}
