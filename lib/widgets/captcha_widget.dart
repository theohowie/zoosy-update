import 'dart:math';
import 'package:flutter/material.dart';
import '../models/reflection.dart'; // ZoosyTheme

/// 图形验证码组件
class CaptchaWidget extends StatefulWidget {
  final ValueChanged<String>? onCodeChanged;

  const CaptchaWidget({Key? key, this.onCodeChanged}) : super(key: key);

  @override
  State<CaptchaWidget> createState() => CaptchaWidgetState();
}

class CaptchaWidgetState extends State<CaptchaWidget> {
  String _currentCode = '';
  final List<Color> _colors = [
    const Color(0xFF4828C8),
    const Color(0xFFE91E63),
    const Color(0xFF4CAF50),
    const Color(0xFFFF9800),
    const Color(0xFF2196F3),
    const Color(0xFF9C27B0),
  ];

  @override
  void initState() {
    super.initState();
    _generateCode();
  }

  void _generateCode() {
    final random = Random();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    _currentCode = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    widget.onCodeChanged?.call(_currentCode);
    setState(() {});
  }

  void refresh() { _generateCode(); }

  bool verify(String input) {
    return input.toUpperCase() == _currentCode;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _generateCode,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ZoosyTheme.outline.withOpacity(0.3)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: CustomPaint(
            painter: _CaptchaPainter(_currentCode, _colors),
            child: Center(
              child: Text(
                _currentCode,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                  color: Colors.transparent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptchaPainter extends CustomPainter {
  final String code;
  final List<Color> colors;

  _CaptchaPainter(this.code, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(code.hashCode);
    final bgPaint = Paint()..color = const Color(0xFFF5F0FF);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 干扰线
    for (int i = 0; i < 4; i++) {
      final linePaint = Paint()
        ..color = colors[random.nextInt(colors.length)].withOpacity(0.3)
        ..strokeWidth = random.nextDouble() * 1.5 + 0.5;
      canvas.drawLine(
        Offset(random.nextDouble() * size.width, random.nextDouble() * size.height),
        Offset(random.nextDouble() * size.width, random.nextDouble() * size.height),
        linePaint,
      );
    }

    // 干扰点
    for (int i = 0; i < 30; i++) {
      final dotPaint = Paint()
        ..color = colors[random.nextInt(colors.length)].withOpacity(0.2);
      canvas.drawCircle(
        Offset(random.nextDouble() * size.width, random.nextDouble() * size.height),
        random.nextDouble() * 2 + 1,
        dotPaint,
      );
    }

    // 文字
    final charWidth = size.width / code.length;
    for (int i = 0; i < code.length; i++) {
      final char = code[i];
      final textPainter = TextPainter(
        text: TextSpan(
          text: char,
          style: TextStyle(
            fontSize: 20 + random.nextDouble() * 4,
            color: colors[random.nextInt(colors.length)],
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final x = i * charWidth + (charWidth - textPainter.width) / 2;
      final y = (size.height - textPainter.height) / 2 + (random.nextDouble() - 0.5) * 6;

      canvas.save();
      canvas.translate(x + textPainter.width / 2, y + textPainter.height / 2);
      canvas.rotate((random.nextDouble() - 0.5) * 0.3);
      canvas.translate(-textPainter.width / 2, -textPainter.height / 2);
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
