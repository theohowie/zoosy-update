import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import '../../services/theme_service.dart';
import '../../widgets/toast_util.dart';

class ThemeSettingsScreen extends StatefulWidget {
  final Color currentColor;
  final ThemeMode currentMode;
  final VoidCallback onChanged;

  const ThemeSettingsScreen({
    Key? key,
    required this.currentColor,
    required this.currentMode,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  late Color _selectedColor;
  late ThemeMode _selectedMode;
  bool _isSaving = false;

  /// 是否有未保存的修改
  bool get _hasChanges =>
      _selectedColor.value != widget.currentColor.value ||
      _selectedMode != widget.currentMode;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.currentColor;
    _selectedMode = widget.currentMode;
  }

  /// 返回确认弹窗
  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    if (!mounted) return true;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZoosyTheme.surfaceOf(ctx),
        surfaceTintColor: Colors.transparent,
        title: Text(ctx.l10n.unsaved_changes, style: TextStyle(color: ZoosyTheme.textDarkOf(ctx))),
        content: Text(ctx.l10n.unsaved_changes_desc, style: TextStyle(color: ZoosyTheme.textMutedOf(ctx))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text(ctx.l10n.discard, style: TextStyle(color: ZoosyTheme.textDarkOf(ctx))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            style: ElevatedButton.styleFrom(backgroundColor: ZoosyTheme.primary),
            child: Text(ctx.l10n.save, style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == 'save') {
      await _save();
      return false; // _save 内部会 pop，所以这里不重复 pop
    }
    return result == 'discard';
  }

  Future<void> _save() async {
    try {
      setState(() => _isSaving = true);
      await ThemeService.setColor(_selectedColor);
      await ThemeService.setMode(_selectedMode);
      ZoosyTheme.setPrimary(_selectedColor); // 立即更新全局主题色

      // 主题色有变化时切换桌面图标（包括切回默认主题），MIUI 需重启 launcher 才能生效
      if (widget.currentColor.value != _selectedColor.value) {
        if (!mounted) return;
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: ZoosyTheme.surfaceOf(ctx),
            surfaceTintColor: Colors.transparent,
            title: Text(ctx.l10n.change_app_icon, style: TextStyle(color: ZoosyTheme.textDarkOf(ctx))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ctx.l10n.icon_change_notice, style: TextStyle(fontSize: 13, color: ZoosyTheme.textMutedOf(ctx), height: 1.5)),
                const SizedBox(height: 12),
                Text(ctx.l10n.icon_update_notice, style: TextStyle(fontSize: 13, color: ZoosyTheme.textMutedOf(ctx), height: 1.5)),
                const SizedBox(height: 12),
                Text(ctx.l10n.icon_missing_notice, style: TextStyle(fontSize: 13, color: ZoosyTheme.textMutedOf(ctx), height: 1.5)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: ZoosyTheme.primary),
                child: Text(ctx.l10n.confirm, style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        setState(() => _isSaving = false);
        if (shouldProceed == true) {
          // 用户确认后切换桌面图标
          await ThemeService.setAppIcon(_selectedColor);
          // setAppIcon 会触发进程重启，所以不需要继续执行后续的 pop
          return;
        }
        // 用户取消：保存主题色但不改桌面图标，继续往下执行
      }

      if (!mounted) return;
      ToastUtil.showToast(context, message: context.l10n.theme_saved, icon: Icons.palette, color: ZoosyTheme.primary);
      // 先 pop 当前页面，下一帧再触发父组件重建（避免重建时 context 失效导致崩溃）
      Navigator.pop(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          widget.onChanged();
        } catch (e, stack) {
          debugPrint('[ThemeSettings] 主题变更回调异常: $e\n$stack');
        }
      });
    } catch (e, stack) {
      debugPrint('[ThemeSettings] 保存主题异常: $e\n$stack');
      if (mounted) {
        ToastUtil.showToast(context, message: '${context.l10n.save_failed}$e', icon: Icons.error_outline, color: Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.theme_settings, style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            final canPop = await _onWillPop();
            if (canPop && mounted) Navigator.pop(context);
          },
        ),
      ),
      body: PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          final canPop = await _onWillPop();
          if (canPop && mounted) Navigator.pop(context);
        },
        child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===== 主题颜色 =====
            Text(context.l10n.theme_color, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: List.generate(ThemeService.presetColors.length, (i) {
                final color = ThemeService.presetColors[i];
                final names = [context.l10n.th_color_purple, context.l10n.th_color_pink, context.l10n.th_color_green, context.l10n.th_color_orange, context.l10n.th_color_blue, context.l10n.th_color_violet, context.l10n.th_color_cyan, context.l10n.th_color_red];
            final name = names[i];
                final isSel = _selectedColor.value == color.value;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSel
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSel
                              ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10, spreadRadius: 1)]
                              : [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)],
                        ),
                        child: isSel
                            ? const Icon(Icons.check, color: Colors.white, size: 22)
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          color: isSel ? color : ZoosyTheme.textMutedOf(context),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 28),

            // ===== 模式选择 =====
            Text(context.l10n.display_mode, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
            const SizedBox(height: 12),
            Card(
              color: ZoosyTheme.surfaceOf(context),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  _buildModeTile(ThemeMode.light, Icons.light_mode, context.l10n.light_mode, context.l10n.light_mode_desc),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildModeTile(ThemeMode.dark, Icons.dark_mode, context.l10n.dark_mode, context.l10n.dark_mode_desc),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildModeTile(ThemeMode.system, Icons.settings_brightness, context.l10n.system_default, context.l10n.follow_system_desc),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ===== 实时预览 =====
            Text(context.l10n.live_preview, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
            const SizedBox(height: 12),
            _buildPreview(),
            const SizedBox(height: 28),

            // ===== 保存按钮 =====
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                child: _isSaving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(context.l10n.save_theme, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildModeTile(ThemeMode mode, IconData icon, String title, String subtitle) {
    final isSel = _selectedMode == mode;
    return ListTile(
      leading: Icon(icon, color: isSel ? _selectedColor : ZoosyTheme.textMutedOf(context)),
      title: Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: isSel ? _selectedColor : ZoosyTheme.textDarkOf(context))),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: Radio<ThemeMode>(
        value: mode,
        groupValue: _selectedMode,
        activeColor: _selectedColor,
        onChanged: (v) => setState(() => _selectedMode = v!),
      ),
      onTap: () => setState(() => _selectedMode = mode),
    );
  }

  Widget _buildPreview() {
    final isDark = _selectedMode == ThemeMode.dark ||
        (_selectedMode == ThemeMode.system &&
         WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
    final bgColor = isDark ? const Color(0xFF1E1E2C) : const Color(0xFFFEF7FF);
    final cardColor = isDark ? const Color(0xFF2D2D3F) : Colors.white;
    final textColor = isDark ? Colors.white70 : ZoosyTheme.textDarkOf(context);
    final mutedColor = isDark ? Colors.white38 : ZoosyTheme.textMutedOf(context);
    final accentColor = _selectedColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white12 : ZoosyTheme.outlineOf(context).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // 模拟 AppBar
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(ThemeService.logoAssetForColor(accentColor),
                  width: 32, height: 32, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 32, height: 32,
                    decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(8))),
                ),
              ),
              const SizedBox(width: 10),
              Text('Zoosy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: accentColor)),
              const Spacer(),
              Icon(Icons.notifications_none_outlined, color: accentColor, size: 20),
              const SizedBox(width: 12),
              Icon(Icons.star_border, color: accentColor, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          // 模拟卡片
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(context.l10n.ts_preview_title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(context.l10n.ts_preview_content, style: TextStyle(fontSize: 12, color: mutedColor), maxLines: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(context.l10n.ts_preview_tag1, style: TextStyle(fontSize: 9, color: accentColor, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 6),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: ZoosyTheme.containerLowOf(context), borderRadius: BorderRadius.circular(8)),
                      child: Text(context.l10n.ts_preview_tag2, style: TextStyle(fontSize: 9, color: mutedColor, fontWeight: FontWeight.bold))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 模拟底部导航
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Icon(Icons.home_filled, color: accentColor, size: 20),
                Icon(Icons.search, color: mutedColor, size: 20),
                Container(width: 40, height: 40, decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                  child: const Icon(Icons.add, color: Colors.white, size: 22)),
                Icon(Icons.insights_rounded, color: mutedColor, size: 20),
                Icon(Icons.person_outline, color: mutedColor, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
