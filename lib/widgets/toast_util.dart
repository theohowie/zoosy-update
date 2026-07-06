import 'package:flutter/material.dart';
import '../models/reflection.dart';

/// 底部气泡 Toast — 使用 OverlayEntry 实现，不依赖 ScaffoldMessenger
class ToastUtil {
  static OverlayEntry? _currentEntry;

  /// 显示底部气泡
  static void showToast(
    BuildContext context, {
    required String message,
    IconData? icon,
    Color? color,
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    // 移除之前的 toast
    _currentEntry?.remove();

    final overlay = Overlay.of(context);
    final themeColor = color ?? ZoosyTheme.primary;

    final entry = OverlayEntry(builder: (ctx) {
      return _ToastWidget(
        message: message,
        icon: icon,
        color: themeColor,
        duration: duration,
        onRemove: () {
          _currentEntry = null;
        },
      );
    });

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

/// 内部使用的 StatefulWidget，管理动画生命周期
class _ToastWidget extends StatefulWidget {
  final String message;
  final IconData? icon;
  final Color color;
  final Duration duration;
  final VoidCallback onRemove;

  const _ToastWidget({
    required this.message,
    required this.icon,
    required this.color,
    required this.duration,
    required this.onRemove,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnim = Tween(begin: 0.0, end: 1.0).animate(_controller);

    _controller.forward();

    // 自动消失
    Future.delayed(widget.duration, () {
      if (mounted) _dismiss();
    });
  }

  Future<void> _dismiss() async {
    _controller.reverse();
    await Future.delayed(const Duration(milliseconds: 350));
    if (mounted) {
      final entry = ToastUtil._currentEntry;
      widget.onRemove();
      entry?.remove();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 100,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Opacity(
            opacity: _fadeAnim.value,
            child: Transform.translate(
              offset: Offset(0, _slideAnim.value.dy * 60),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: ZoosyTheme.textDarkOf(context).withOpacity(0.88),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: widget.color, size: 18),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
