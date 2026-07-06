import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import '../../models/reflection.dart';
import '../../services/theme_service.dart';
import 'widget_guide_screen.dart';
import '../../widgets/toast_util.dart';

final MethodChannel _directWidgetChannel = MethodChannel('zoosy/widget_update');

class WidgetSettingsScreen extends StatefulWidget {
  final int reflectionCount;
  final int currentStreak;
  final List<Reflection> reflections;

  const WidgetSettingsScreen({Key? key, required this.reflectionCount, required this.currentStreak, this.reflections = const []}) : super(key: key);

  @override
  State<WidgetSettingsScreen> createState() => _WidgetSettingsScreenState();
}

class _WidgetSettingsScreenState extends State<WidgetSettingsScreen> {
  String _selectedStyle = 'style1';
  String _labelType = '总共思考';

  @override
  void initState() {
    super.initState();
    _loadSaved();
    // 进入页面时自动保存实时数据
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSaveData());
  }

  Future<void> _autoSaveData() async {
    await HomeWidget.saveWidgetData('reflection_count', widget.reflectionCount.toString());
    await HomeWidget.saveWidgetData('current_streak', widget.currentStreak.toString());
  }

  Future<void> _loadSaved() async {
    try {
      final style = await HomeWidget.getWidgetData<String>('style');
      final label = await HomeWidget.getWidgetData<String>('widget_label');
      if (style != null && mounted) setState(() => _selectedStyle = style);
      if (label != null && mounted) setState(() => _labelType = label);
    } catch (_) {}
  }

  Future<void> _updateWidget() async {
    // 获取最近一条思考
    String recentTitle = '最近思考';
    String recentContent = '从今天起，记录每一个值得思考的瞬间。';
    String recentDate = '';
    if (widget.reflections.isNotEmpty) {
      final sorted = List<Reflection>.from(widget.reflections)..sort((a, b) => '${b.date} ${b.time}'.compareTo('${a.date} ${a.time}'));
      recentTitle = sorted.first.title;
      recentContent = sorted.first.content;
      if (recentContent.length > 72) recentContent = '${recentContent.substring(0, 72)}...';
      recentDate = _formatDate(sorted.first.date, sorted.first.time);
    }

    await HomeWidget.saveWidgetData('reflection_count', widget.reflectionCount.toString());
    await HomeWidget.saveWidgetData('current_streak', widget.currentStreak.toString());
    await HomeWidget.saveWidgetData('style', _selectedStyle);
    await HomeWidget.saveWidgetData('widget_label', _labelType);
    await HomeWidget.saveWidgetData('recent_title', recentTitle);
    await HomeWidget.saveWidgetData('recent_content', recentContent);
    await HomeWidget.saveWidgetData('recent_date', recentDate);
    // 保存当前主题色
    final themeColor = '#${ZoosyTheme.primary.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    await HomeWidget.saveWidgetData('theme_color', themeColor);
    // 保存当前主题对应的 logo 索引（0=默认，1~7=logo1~logo7）
    final logoIndex = ThemeService.iconIndexForColor(ZoosyTheme.primary).toString();
    await HomeWidget.saveWidgetData('logo_index', logoIndex);
  try {
    await HomeWidget.updateWidget(androidName: 'ZoosyWidgetProvider', iOSName: 'ZoosyWidget');
    // 也尝试用默认名触发一次更新（兼容某些设备）
    try { await HomeWidget.updateWidget(); } catch (_) {}
  } catch (_) {}
  // 通过直通通道再强刷一次
  try {
    await _directWidgetChannel.invokeMethod('updateWidget', {
      'reflection_count': widget.reflectionCount.toString(),
      'current_streak': widget.currentStreak.toString(),
      'style': _selectedStyle,
      'widget_label': _labelType,
      'recent_title': recentTitle,
      'recent_content': recentContent,
      'recent_date': recentDate,
      'theme_color': themeColor,
      'logo_index': ThemeService.iconIndexForColor(ZoosyTheme.primary).toString(),
      'last_updated': DateTime.now().millisecondsSinceEpoch.toString(),
    });
  } catch (_) {}
  if (mounted) ToastUtil.showToast(context, message: '数据已保存，请稍后查看桌面小组件', icon: Icons.widgets, color: Colors.green);
  }

  /// 获取最近一条思考（按日期+时间排序）
  Reflection? _getRecentThought() {
    if (widget.reflections.isEmpty) return null;
    final sorted = List<Reflection>.from(widget.reflections)..sort((a, b) => '${b.date} ${b.time}'.compareTo('${a.date} ${a.time}'));
    return sorted.first;
  }

  /// 最近思考样式预览行
  List<Widget> _buildStyle3Preview() {
    final recent = _getRecentThought();
    final title = recent?.title ?? '';
    final content = recent != null
        ? (recent.content.length > 72 ? '${recent.content.substring(0, 72)}...' : recent.content)
        : '从今天起，记录每一个值得思考的瞬间。';
    final date = recent != null ? _formatDate(recent.date, recent.time) : '';
    return [
      _previewRow('💭  最近思考', ZoosyTheme.primary, true),
      if (title.isNotEmpty) _previewRow(title, ZoosyTheme.primary, true),
      _previewRow(content, ZoosyTheme.textMutedOf(context), false),
      if (date.isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 4),
          child: Align(alignment: Alignment.centerRight,
            child: Text(date, style: TextStyle(fontSize: 8, color: ZoosyTheme.textMutedOf(context))),
          ),
        ),
    ];
  }

  /// 格式化日期用于小组件显示
  String _formatDate(String date, String time) {
    try {
      final parts = date.split('-');
      if (parts.length == 3) {
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);
        return '$y年${m}月${d}日 $time';
      }
    } catch (_) {}
    return '$date $time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('小组件设置', style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('选择样式', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
          const SizedBox(height: 16),

          _buildStyleCard('style1', '统计卡片', Icons.bar_chart, [
            _previewRow('Zoosy', ZoosyTheme.primary, true),
            _previewRow('$_labelType', ZoosyTheme.textMutedOf(context), false),
            _previewRow('${widget.reflectionCount}条', ZoosyTheme.primary, true),
            _previewRow('🐙 zoosy', const Color(0xFFC9C4D7), false),
          ]),
          if (_selectedStyle == 'style1') ...[
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: ZoosyTheme.primary.withOpacity(0.04), borderRadius: BorderRadius.circular(14), border: Border.all(color: ZoosyTheme.primary.withOpacity(0.1))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('第二行显示内容', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: ['总共思考', '今日思考', '连续记录'].map((t) {
                  final sel = _labelType == t;
                  return ChoiceChip(label: Text(t), selected: sel, onSelected: (v) { if (v) setState(() => _labelType = t); },
                    selectedColor: ZoosyTheme.primary, labelStyle: TextStyle(fontSize: 12, color: sel ? Colors.white : ZoosyTheme.textMutedOf(context)));
                }).toList()),
              ]),
            ),
          ],
          const SizedBox(height: 12),

          _buildStyleCard('style2', '快捷记录', Icons.add_circle_outline, [
            _previewRow('  Zoosy', ZoosyTheme.primary, true),
            _previewRow('[ + 新建思考 ]', ZoosyTheme.primary, false),
          ]),
          const SizedBox(height: 12),

          _buildStyleCard('style3', '最近思考', Icons.article_outlined, _buildStyle3Preview()),

          const SizedBox(height: 28),
          SizedBox(height: 48, child: ElevatedButton.icon(
            onPressed: _updateWidget,
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('更新小组件', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: ZoosyTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          )),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WidgetGuideScreen())),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: ZoosyTheme.primary.withOpacity(0.04), borderRadius: BorderRadius.circular(14), border: Border.all(color: ZoosyTheme.primary.withOpacity(0.1))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('如何添加小组件？', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
                  const Spacer(),
                  Icon(Icons.chevron_right, size: 18, color: ZoosyTheme.textMutedOf(context)),
                ]),
                const SizedBox(height: 6),
                Text('1. 点击上方「更新小组件」保存数据', style: TextStyle(fontSize: 12, color: ZoosyTheme.textMutedOf(context), height: 1.5)),
                Text('2. 长按桌面空白处 → 小组件 → 找到 Zoosy', style: TextStyle(fontSize: 12, color: ZoosyTheme.textMutedOf(context), height: 1.5)),
                Text('3. 选择对应尺寸拖到桌面', style: TextStyle(fontSize: 12, color: ZoosyTheme.textMutedOf(context), height: 1.5)),
              ]),
            ),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _buildStyleCard(String id, String name, IconData icon, List<Widget> previewRows) {
    final isSel = _selectedStyle == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedStyle = id),
      child: Container(
        decoration: BoxDecoration(
          color: ZoosyTheme.surfaceOf(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSel ? ZoosyTheme.primary : ZoosyTheme.outlineOf(context).withOpacity(0.2), width: isSel ? 2 : 1),
        ),
        child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
          Expanded(flex: 3,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: ZoosyTheme.primary.withOpacity(0.04), borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: previewRows),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(icon, size: 18, color: ZoosyTheme.primary), const SizedBox(width: 6), Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context)))]),
            const SizedBox(height: 6),
            if (isSel) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: ZoosyTheme.primary, borderRadius: BorderRadius.circular(8)),
              child: const Text('使用中', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ])),
        ])),
      ),
    );
  }

  Widget _previewRow(String text, Color color, bool bold) {
    return Padding(padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: TextStyle(fontSize: bold ? 13 : 10, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color), maxLines: 1, overflow: TextOverflow.ellipsis));
  }
}
