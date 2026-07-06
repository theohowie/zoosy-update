import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import '../../services/theme_service.dart';
import '../../services/translation_service.dart';
import '../../services/prefs_util.dart';
import 'home_screen.dart';
import '../thoughts/search_screen.dart';
import '../thoughts/all_thoughts_screen.dart';
import '../stats/stats_screen.dart';
import '../settings/settings_screen.dart';
import '../thoughts/new_reflection_screen.dart';
import '../settings/theme_settings_screen.dart';
import '../../widgets/toast_util.dart';
import '../about/vip_center_screen.dart';

class MainNavigation extends StatefulWidget {
  final List<Reflection> reflections;
  final List<NotificationItem> notifications;
  final Function(Reflection) onAddReflection;
  final Function(String) onToggleFavorite;
  final Function(String) onDeleteReflection;
  final Function(List<String>) onDeleteReflections;
  final Function(Reflection) onUpdateReflection;
  final Function(Reflection) onRestoreFromTrash;
  final VoidCallback onLogout;
  final VoidCallback onThemeChanged;

  const MainNavigation({Key? key, required this.reflections, required this.notifications,
    required this.onAddReflection, required this.onToggleFavorite, required this.onDeleteReflection,
    required this.onDeleteReflections, required this.onUpdateReflection, required this.onRestoreFromTrash, required this.onLogout, required this.onThemeChanged}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  late List<Widget> _screens;
  String _navBarStyle = 'default';

  // 多选模式状态
  bool _isSelectionMode = false;
  int _selectedCount = 0;
  VoidCallback? _onSelectAll;
  VoidCallback? _onDelete;
  VoidCallback? _onExitSelectionMode;

  @override
  void initState() {
    super.initState();
    _buildScreens();
    _loadNavBarStyle();
  }

  Future<void> _loadNavBarStyle() async {
    final style = await PrefsUtil.getNavBarStyle();
    if (mounted) setState(() => _navBarStyle = style);
  }

  @override
  void didUpdateWidget(MainNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    _buildScreens();
    _loadNavBarStyle();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadNavBarStyle();
  }

  void _buildScreens() {
    _screens = [
      HomeScreen(reflections: widget.reflections, onToggleFavorite: widget.onToggleFavorite, onDeleteReflection: widget.onDeleteReflection, onUpdateReflection: widget.onUpdateReflection),
      AllThoughtsScreen(
        reflections: widget.reflections,
        onToggleFavorite: widget.onToggleFavorite,
        onDeleteReflection: widget.onDeleteReflection,
        onDeleteReflections: widget.onDeleteReflections,
        onUpdateReflection: widget.onUpdateReflection,
        onSelectionChanged: (isSelectionMode, selectedCount, onSelectAll, onDelete, onExit) {
          setState(() {
            _isSelectionMode = isSelectionMode;
            _selectedCount = selectedCount;
            _onSelectAll = onSelectAll;
            _onDelete = onDelete;
            _onExitSelectionMode = onExit;
          });
        },
      ),
      StatsScreen(reflections: widget.reflections, onToggleFavorite: widget.onToggleFavorite, onDeleteReflection: widget.onDeleteReflection, onUpdateReflection: widget.onUpdateReflection),
      SettingsScreen(reflectionsCount: widget.reflections.length, reflections: widget.reflections, onToggleFavorite: widget.onToggleFavorite, onDeleteReflection: widget.onDeleteReflection, onUpdateReflection: widget.onUpdateReflection, onRestoreFromTrash: widget.onRestoreFromTrash, onLogout: widget.onLogout, onThemeChanged: widget.onThemeChanged, onNavBarChanged: () => _loadNavBarStyle()),
    ];
  }

  void _openSearch() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SearchScreen(
      reflections: widget.reflections,
      onToggleFavorite: widget.onToggleFavorite,
      onDeleteReflection: widget.onDeleteReflection,
      onUpdateReflection: widget.onUpdateReflection,
    )));
  }

  void _openNewReflection() {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => NewReflectionScreen(onSave: (ref) {
      widget.onAddReflection(ref);
      ToastUtil.showToast(context, message: TranslationService.tr('thought_recorded'), icon: Icons.check, color: Colors.green);
    })));
  }

  Future<void> _openThemeSettings() async {
    final color = await ThemeService.getColor();
    final mode = await ThemeService.getMode();
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ThemeSettingsScreen(
      currentColor: color, currentMode: mode, onChanged: widget.onThemeChanged,
    )));
    _loadNavBarStyle();
  }

  @override
  Widget build(BuildContext context) {
    final showSearch = (_currentIndex == 0 || _currentIndex == 1) && !_isSelectionMode;
    final showVip = _currentIndex == 3 && !_isSelectionMode;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: ZoosyTheme.bgOf(context).withOpacity(0.95),
        surfaceTintColor: Colors.transparent, elevation: 0,
        title: _isSelectionMode
            ? GestureDetector(
                onTap: _onExitSelectionMode,
                behavior: HitTestBehavior.opaque,
                child: Row(children: [
                  Icon(Icons.close, color: ZoosyTheme.textDarkOf(context), size: 24),
                  const SizedBox(width: 12),
                  Text(
                    TranslationService.tr('selected_count', params: {'count': '$_selectedCount'}),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context)),
                  ),
                ]),
              )
            : GestureDetector(
                onTap: _openThemeSettings,
                behavior: HitTestBehavior.opaque,
                child: Row(children: [
                  Container(width: 32, height: 32,
                    decoration: const BoxDecoration(color: Color(0xFFE5DEFF), shape: BoxShape.circle),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(ThemeService.currentLogoAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.psychology, size: 18, color: Color(0xFF7C5CFC)),
                      ),
                  ),
                  const SizedBox(width: 12),
                  Text('Zoosy', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w800, fontSize: 20, color: ZoosyTheme.primary)),
                ]),
              ),
        actions: [
          if (_isSelectionMode)
            IconButton(
              onPressed: _onSelectAll,
              icon: Icon(
                _selectedCount == widget.reflections.length ? Icons.check_circle : Icons.check_circle_outline,
                color: ZoosyTheme.primary,
              ),
              tooltip: TranslationService.tr('select_all'),
            ),
          if (_isSelectionMode)
            IconButton(
              onPressed: _selectedCount > 0 ? _onDelete : null,
              icon: Icon(Icons.delete_outline, color: _selectedCount > 0 ? Colors.red : Colors.grey),
              tooltip: TranslationService.tr('delete'),
            ),
          if (showSearch)
            IconButton(
              onPressed: _openSearch,
              icon: Icon(Icons.search, color: ZoosyTheme.primary),
            ),
          if (showVip)
            IconButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VipCenterScreen())),
              icon: Icon(Icons.workspace_premium, color: ZoosyTheme.primary),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _navBarStyle == 'floating' ? _buildFloatingBody() : _buildDefaultBody(),
      bottomNavigationBar: _navBarStyle == 'floating' ? null : _buildDefaultNavBar(),
    );
  }

  // ==================== 默认样式 ====================
  Widget _buildDefaultBody() {
    return IndexedStack(
      index: _currentIndex,
      children: _screens,
    );
  }

  Widget _buildDefaultNavBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(), notchMargin: 8.0,
      color: ZoosyTheme.surfaceOf(context), elevation: 0,
      child: SizedBox(height: 48,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _buildNavBarItem(Icons.home_filled, TranslationService.tr('nav_home'), 0),
          _buildNavBarItem(Icons.list_alt_rounded, TranslationService.tr('nav_all'), 1),
          SizedBox(width: 48, height: 48, child: Center(child: SizedBox(width: 48, height: 48,
            child: FloatingActionButton(
              onPressed: _openNewReflection,
              backgroundColor: ZoosyTheme.primary, elevation: 6, shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ))),
          _buildNavBarItem(Icons.insights_rounded, TranslationService.tr('nav_stats'), 2),
          _buildNavBarItem(Icons.person_outline, TranslationService.tr('nav_profile'), 3),
        ]),
      ),
    );
  }

  Widget _buildNavBarItem(IconData icon, String label, int index) {
    final bool isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: isSelected ? ZoosyTheme.primary : ZoosyTheme.textMutedOf(context).withOpacity(0.5), size: 24),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? ZoosyTheme.primary : ZoosyTheme.textMutedOf(context).withOpacity(0.5))),
      ]),
    );
  }

  // ==================== 悬浮样式 ====================
  Widget _buildFloatingBody() {
    return Stack(
      children: [
        // 内容区域（底部留出空间给悬浮导航栏）
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          child: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
        ),
        // 悬浮导航栏
        Positioned(
          left: 0,
          right: 0,
          bottom: 32,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 左侧导航栏（胶囊形状）
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: ZoosyTheme.surfaceOf(context),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFloatingNavItem(Icons.home_filled, 0),
                      _buildFloatingNavItem(Icons.list_alt_rounded, 1),
                      _buildFloatingNavItem(Icons.insights_rounded, 2),
                      _buildFloatingNavItem(Icons.person_outline, 3),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // 右侧新建按钮（圆形）
                GestureDetector(
                  onTap: _openNewReflection,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: ZoosyTheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: ZoosyTheme.primary.withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 28),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingNavItem(IconData icon, int index) {
    final bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: isSelected ? ZoosyTheme.primary : ZoosyTheme.textMutedOf(context).withOpacity(0.5),
          size: 26,
        ),
      ),
    );
  }
}
