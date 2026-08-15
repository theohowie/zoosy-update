import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import '../../services/prefs_util.dart';
import '../../widgets/toast_util.dart';

class NavBarSettingsScreen extends StatefulWidget {
  const NavBarSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NavBarSettingsScreen> createState() => _NavBarSettingsScreenState();
}

class _NavBarSettingsScreenState extends State<NavBarSettingsScreen> {
  String _currentStyle = 'default';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _currentStyle = await PrefsUtil.getNavBarStyle();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await PrefsUtil.setNavBarStyle(_currentStyle);
    if (!mounted) return;
    ToastUtil.showToast(context, message: context.l10n.updated, icon: Icons.check, color: Colors.green);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(
      appBar: AppBar(title: Text(context.l10n.nav_bar_settings, style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0),
      body: const Center(child: CircularProgressIndicator()),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.nav_bar_settings, style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(context.l10n.save, style: TextStyle(color: ZoosyTheme.primary, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // 预览区域
          Text(context.l10n.preview, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ZoosyTheme.textMutedOf(context))),
          const SizedBox(height: 12),
          _buildPreview(),

          const SizedBox(height: 24),

          // 样式选择
          Text(context.l10n.nav_style_desc, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ZoosyTheme.textMutedOf(context))),
          const SizedBox(height: 12),
          Card(
            color: ZoosyTheme.surfaceOf(context),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.2)),
            ),
            child: Column(children: [
              _buildStyleOption('default', context.l10n.nav_style_default, context.l10n.nav_style_default_desc),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildStyleOption('floating', context.l10n.nav_style_floating, context.l10n.nav_style_floating_desc),
            ]),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: ZoosyTheme.bgOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZoosyTheme.outlineOf(context).withOpacity(0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // 模拟内容区域
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: ZoosyTheme.surfaceOf(context).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.article_outlined, size: 32, color: ZoosyTheme.textMutedOf(context).withOpacity(0.3)),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.preview_content,
                        style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context).withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 导航栏预览
            if (_currentStyle == 'default')
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildDefaultNavBarPreview(),
              )
            else
              Positioned(
                left: 0,
                right: 0,
                bottom: 20,
                child: _buildFloatingNavBarPreview(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultNavBarPreview() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: ZoosyTheme.surfaceOf(context),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(
          top: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.2)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItemPreview(Icons.home_filled, context.l10n.nav_home, true),
          _buildNavItemPreview(Icons.list_alt_rounded, context.l10n.nav_all, false),
          _buildAddButtonPreview(),
          _buildNavItemPreview(Icons.insights_rounded, context.l10n.nav_stats, false),
          _buildNavItemPreview(Icons.person_outline, context.l10n.nav_profile, false),
        ],
      ),
    );
  }

  Widget _buildFloatingNavBarPreview() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 左侧导航栏（胶囊形状）
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: ZoosyTheme.surfaceOf(context),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFloatingNavItemPreview(Icons.home_filled, true),
                _buildFloatingNavItemPreview(Icons.list_alt_rounded, false),
                _buildFloatingNavItemPreview(Icons.insights_rounded, false),
                _buildFloatingNavItemPreview(Icons.person_outline, false),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 右侧新建按钮（圆形）
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ZoosyTheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: ZoosyTheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItemPreview(IconData icon, String label, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: isSelected ? ZoosyTheme.primary : ZoosyTheme.textMutedOf(context).withOpacity(0.5),
          size: 20,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? ZoosyTheme.primary : ZoosyTheme.textMutedOf(context).withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingNavItemPreview(IconData icon, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Icon(
        icon,
        color: isSelected ? ZoosyTheme.primary : ZoosyTheme.textMutedOf(context).withOpacity(0.5),
        size: 22,
      ),
    );
  }

  Widget _buildAddButtonPreview() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: ZoosyTheme.primary,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.add, color: Colors.white, size: 22),
    );
  }

  Widget _buildStyleOption(String value, String title, String subtitle) {
    final isSelected = _currentStyle == value;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? ZoosyTheme.primary.withOpacity(0.1) : ZoosyTheme.containerLowOf(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          value == 'default' ? Icons.view_carousel_outlined : Icons.view_carousel,
          color: isSelected ? ZoosyTheme.primary : ZoosyTheme.textMutedOf(context),
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: ZoosyTheme.textDarkOf(context),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context)),
      ),
      trailing: Radio<String>(
        value: value,
        groupValue: _currentStyle,
        activeColor: ZoosyTheme.primary,
        onChanged: (v) {
          if (v != null) setState(() => _currentStyle = v);
        },
      ),
      onTap: () => setState(() => _currentStyle = value),
    );
  }
}
