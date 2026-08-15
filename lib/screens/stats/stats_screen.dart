import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/reflection.dart';
import '../../services/page_settings.dart';
import '../thoughts/tag_thoughts_screen.dart';

class StatsScreen extends StatefulWidget {
  final List<Reflection> reflections;
  final Function(String) onToggleFavorite;
  final Function(String) onDeleteReflection;
  final Function(Reflection) onUpdateReflection;

  const StatsScreen({Key? key, required this.reflections, required this.onToggleFavorite, required this.onDeleteReflection, required this.onUpdateReflection}) : super(key: key);

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String period = 'day';
  String _chartType = 'line';
  bool _showTagDist = true;
  bool _showMenu = false;
  late ScrollController _chartScrollCtrl;
  final GlobalKey _chartKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _chartScrollCtrl = ScrollController();
    // 首次渲染后滚动到今天位置
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSettings();
  }

  @override
  void dispose() { _chartScrollCtrl.dispose(); super.dispose(); }

  Future<void> _loadSettings() async {
    final show = await PageSettings.showTagDistribution();
    if (mounted) setState(() => _showTagDist = show);
  }

  int _currentStreak(List<Reflection> reflections) {
    if (reflections.isEmpty) return 0;
    final dates = reflections.map((r) => r.date).toSet().toList()..sort();
    final today = DateTime.now(); int streak = 0;
    var d = DateTime(today.year, today.month, today.day);
    while (true) {
      final s = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      if (dates.contains(s)) { streak++; d = d.subtract(const Duration(days: 1)); } else break;
    }
    return streak;
  }

  int _maxStreak(List<Reflection> reflections) {
    if (reflections.isEmpty) return 0;
    final dates = reflections.map((r) => r.date).toSet().toList()..sort();
    if (dates.isEmpty) return 0;
    int max = 1, cur = 1;
    for (int i = 1; i < dates.length; i++) {
      if (DateTime.parse(dates[i]).difference(DateTime.parse(dates[i-1])).inDays == 1) { cur++; if (cur > max) max = cur; } else cur = 1;
    }
    return max;
  }

  Map<String, dynamic> _weeklyCompare() {
    final now = DateTime.now();
    final tm = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final lm = tm.subtract(const Duration(days: 7));
    int tw = 0, lw = 0;
    for (final r in widget.reflections) {
      final p = r.date.split('-'); final d = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
      if (!d.isBefore(tm) && !d.isAfter(tm.add(const Duration(days: 6)))) tw++;
      if (!d.isBefore(lm) && !d.isAfter(lm.add(const Duration(days: 6)))) lw++;
    }
    int c = tw - lw; double pct = lw > 0 ? (c / lw * 100).roundToDouble() : (tw > 0 ? 100 : 0);
    return {'change': c, 'pct': pct};
  }

  Map<String, dynamic> _bestTag() {
    final now = DateTime.now();
    final tm = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final lm = tm.subtract(const Duration(days: 7));
    Map<String, int> tc = {}, lc = {};
    for (final r in widget.reflections) {
      final p = r.date.split('-'); final d = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
      final its = !d.isBefore(tm) && !d.isAfter(tm.add(const Duration(days: 6)));
      final ils = !d.isBefore(lm) && !d.isAfter(lm.add(const Duration(days: 6)));
      for (final t in r.tags) { if (its) tc[t] = (tc[t] ?? 0) + 1; if (ils) lc[t] = (lc[t] ?? 0) + 1; }
    }
    String bt = ''; int bg = 0;
    for (final tag in tc.keys) { final g = (tc[tag] ?? 0) - (lc[tag] ?? 0); if (g > bg) { bg = g; bt = tag; } }
    if (bt.isEmpty && tc.isNotEmpty) bt = tc.entries.first.key;
    return {'tag': bt, 'growth': bg, 'thisCount': tc[bt] ?? 0};
  }

  void _toggleMenu() => setState(() => _showMenu = !_showMenu);
  void _setChart(String t) => setState(() { _chartType = t; _showMenu = false; _scrollToToday(); });
  void _scrollToToday() {
    final pw = _pointWidth;
    final half = _totalPeriods ~/ 2;
    final offset = half * pw - 140;
    if (_chartScrollCtrl.hasClients) _chartScrollCtrl.animateTo(offset, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  int get _totalPeriods => 200;
  double get _pointWidth => period == 'day' ? 44 : (period == 'week' ? 120 : 80);

  int _dayCount(String date) { final m = <String, int>{}; for (final r in widget.reflections) m[r.date] = (m[r.date] ?? 0) + 1; return m[date] ?? 0; }

  List<double> _chartDataMulti() {
    final half = _totalPeriods ~/ 2; final today = DateTime.now();
    return List.generate(_totalPeriods, (i) => _dayCount('${today.add(Duration(days: i - half)).year}-${today.add(Duration(days: i - half)).month.toString().padLeft(2, '0')}-${today.add(Duration(days: i - half)).day.toString().padLeft(2, '0')}').toDouble());
  }

  List<double> _chartDataWeeks() {
    final half = _totalPeriods ~/ 2; final today = DateTime.now();
    final thisMon = DateTime(today.year, today.month, today.day - (today.weekday - 1));
    return List.generate(_totalPeriods, (w) {
      final mon = thisMon.add(Duration(days: (w - half) * 7)); int sum = 0;
      for (int i = 0; i < 7; i++) { final d = mon.add(Duration(days: i)); sum += _dayCount('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'); }
      return sum.toDouble();
    });
  }

  List<double> _chartDataMonths() {
    final half = _totalPeriods ~/ 2; final today = DateTime.now();
    return List.generate(_totalPeriods, (m) {
      final month = DateTime(today.year, today.month + m - half, 1);
      final dim = DateTime(month.year, month.month + 1, 0).day; int sum = 0;
      for (int i = 1; i <= dim; i++) sum += _dayCount('${month.year}-${month.month.toString().padLeft(2, '0')}-${i.toString().padLeft(2, '0')}');
      return sum.toDouble();
    });
  }

  List<String> _chartLabelsDaily() {
    final half = _totalPeriods ~/ 2; final today = DateTime.now();
    return List.generate(_totalPeriods, (i) { final d = today.add(Duration(days: i - half)); return '${d.month}/${d.day}'; });
  }

  List<String> _chartLabelsWeeks() {
    final half = _totalPeriods ~/ 2; final today = DateTime.now();
    final thisMon = DateTime(today.year, today.month, today.day - (today.weekday - 1));
    return List.generate(_totalPeriods, (w) { final mon = thisMon.add(Duration(days: (w - half) * 7)); return '${mon.month}/${mon.day}'; });
  }

  List<String> _chartLabelsMonths() {
    final half = _totalPeriods ~/ 2; final today = DateTime.now();
    return List.generate(_totalPeriods, (m) { final month = DateTime(today.year, today.month + m - half, 1); return context.l10n.ss_month_label(month.month); });
  }

  List<double> get _allChartData => period == 'day' ? _chartDataMulti() : (period == 'week' ? _chartDataWeeks() : _chartDataMonths());
  List<String> get _allChartLabels => period == 'day' ? _chartLabelsDaily() : (period == 'week' ? _chartLabelsWeeks() : _chartLabelsMonths());

  int get _totalForDisplay {
    final now = DateTime.now();
    if (period == 'day') return _dayCount('${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}');
    if (period == 'week') { final mon = DateTime(now.year, now.month, now.day - (now.weekday - 1)); int sum = 0; for (int i = 0; i < 7; i++) { final d = mon.add(Duration(days: i)); sum += _dayCount('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'); } return sum; }
    final month = DateTime(now.year, now.month, 1); final dim = DateTime(month.year, month.month + 1, 0).day; int sum = 0;
    for (int i = 1; i <= dim; i++) sum += _dayCount('${month.year}-${month.month.toString().padLeft(2, '0')}-${i.toString().padLeft(2, '0')}');
    return sum;
  }

  Future<void> _shareChartAsImage() async {
    try {
      final boundary = _chartKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/zoosy_chart.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: context.l10n.chart_share_text);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final totalLogs = widget.reflections.length;
    final tagCounts = <String, int>{}; for (var r in widget.reflections) { for (var t in r.tags) tagCounts[t] = (tagCounts[t] ?? 0) + 1; }
    final sortedTags = tagCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final compare = _weeklyCompare(); final best = _bestTag();

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(context.l10n.stats_trend, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
            Row(mainAxisSize: MainAxisSize.min, children: [
              AnimatedCrossFade(
                firstChild: Row(mainAxisSize: MainAxisSize.min, children: [
                  _iconBtn(Icons.share_outlined, () { _showMenu = false; _shareChartAsImage(); }), const SizedBox(width: 6),
                  _iconBtn(Icons.refresh, () { _scrollToToday(); setState(() => _showMenu = false); }), const SizedBox(width: 6),
                  if (_chartType != 'donut') _iconBtn(Icons.pie_chart_outline, () { _setChart('donut'); }) else _iconBtn(Icons.show_chart, () { _setChart('line'); }), const SizedBox(width: 6),
                  if (_chartType != 'bar') _iconBtn(Icons.bar_chart_outlined, () { _setChart('bar'); }) else _iconBtn(Icons.show_chart, () { _setChart('line'); }), const SizedBox(width: 6),
                ]),
                secondChild: const SizedBox(width: 0),
                crossFadeState: _showMenu ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 250),
              ),
              InkWell(onTap: _toggleMenu, borderRadius: BorderRadius.circular(20),
                child: AnimatedRotation(turns: _showMenu ? 0.25 : 0, duration: const Duration(milliseconds: 250),
                  child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.more_horiz, color: ZoosyTheme.textDarkOf(context))))),
            ]),
          ]),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: ZoosyTheme.containerLowOf(context), borderRadius: BorderRadius.circular(30)),
            child: Row(children: [
              ['day', context.l10n.period_day],
              ['week', context.l10n.period_week],
              ['month', context.l10n.period_month],
            ].map((e) {
              final code = e[0];
              final label = e[1];
              final sel = period == code;
              return Expanded(child: GestureDetector(
                onTap: () { setState(() => period = code); _scrollToToday(); },
                child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: sel ? ZoosyTheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(20)), alignment: Alignment.center,
                  child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: sel ? Colors.white : ZoosyTheme.textMutedOf(context))))),
              );
            }).toList()),
          ),
          const SizedBox(height: 16),
          _buildChartSection(),
          const SizedBox(height: 16),
          _buildBentoGrid(totalLogs, _currentStreak(widget.reflections), _maxStreak(widget.reflections), compare),
          const SizedBox(height: 16),
          _buildInsightCard(best),
          if (_showTagDist) ...[
            const SizedBox(height: 24), Text(context.l10n.tag_distribution, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))), const SizedBox(height: 12),
            sortedTags.isEmpty ? Center(child: Text(context.l10n.no_tag_data)) : Column(children: sortedTags.map((e) => _buildTagRow(e.key, e.value, ((e.value / totalLogs) * 100).round())).toList()),
          ],
          const SizedBox(height: 48),
        ]),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
    child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ZoosyTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 18, color: ZoosyTheme.primary)));

  Widget _buildChartSection() => RepaintBoundary(key: _chartKey,
    child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: ZoosyTheme.surfaceOf(context), borderRadius: BorderRadius.circular(28), border: Border.all(color: ZoosyTheme.outlineOf(context).withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [Icon(Icons.insights, color: ZoosyTheme.primary, size: 18), const SizedBox(width: 8), Text(_chartType == 'donut' ? context.l10n.tag_distribution : context.l10n.record_count_label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ZoosyTheme.textMutedOf(context)))]),
          Text(_chartType == 'donut' ? '' : context.l10n.ss_count(_totalForDisplay), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        if (_chartType == 'donut') _buildDonutChart() else _buildLineBarChart(),
      ])));

  Widget _buildDonutChart() {
    final tc = <String, int>{}; for (final r in widget.reflections) { for (final t in r.tags) tc[t] = (tc[t] ?? 0) + 1; }
    final total = tc.values.fold(0, (a, b) => a + b);
    if (total == 0) return SizedBox(height: 120, child: Center(child: Text(context.l10n.no_data, style: TextStyle(color: ZoosyTheme.textMutedOf(context)))));
    final sorted = tc.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return SizedBox(height: 140, child: Row(children: [
      SizedBox(width: 120, height: 130, child: CustomPaint(size: const Size(120, 130), painter: ChartDonutPainter(values: sorted.map((e) => e.value.toDouble()).toList(), centerFillColor: ZoosyTheme.surfaceOf(context)))),
      const SizedBox(width: 16),
      Expanded(child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < sorted.length && i < 8; i++)
              Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: ChartDonutPainter.colors[i % ChartDonutPainter.colors.length], shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(sorted[i].key, style: TextStyle(fontSize: 12, color: ZoosyTheme.textDarkOf(context)))),
                Text('${(sorted[i].value / total * 100).round()}%', style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context), fontWeight: FontWeight.bold)),
              ])),
          ],
        ))),
    ]));
  }

  Widget _buildLineBarChart() {
    final data = _allChartData; final labels = _allChartLabels; final pw = _pointWidth; final tw = data.length * pw;
    return SizedBox(height: 150, child: SingleChildScrollView(scrollDirection: Axis.horizontal, controller: _chartScrollCtrl,
      child: SizedBox(width: tw, height: 150,
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _chartType == 'bar' ? ChartBarPainter(values: data, labels: labels, pointWidth: pw) : ChartSplinePainter(values: data, pointWidth: pw))),
          Positioned(bottom: 4, left: 0, right: 0, child: Row(children: labels.map((d) => SizedBox(width: pw, child: Center(child: Text(d, style: TextStyle(fontSize: 9, color: ZoosyTheme.textMutedOf(context)))))).toList())),
        ])),
    ));
  }

  Widget _buildBentoGrid(int tl, int cs, int ms, Map<String, dynamic> cmp) {
    final c = cmp['change'] as int; final pct = cmp['pct'] as double;
    final arrow = c > 0 ? '↑' : (c < 0 ? '↓' : '');
    final label = c == 0 ? context.l10n.same_vs_last_week : '$arrow ${pct.round()}% ${context.l10n.vs_last_week}';
    final color = c > 0 ? Colors.green : (c < 0 ? Colors.red : ZoosyTheme.textMutedOf(context));
    return Column(children: [
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: ZoosyTheme.surfaceOf(context), borderRadius: BorderRadius.circular(24), border: Border.all(color: ZoosyTheme.outlineOf(context).withOpacity(0.2))),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.l10n.total, style: TextStyle(fontSize: 12, color: ZoosyTheme.textMutedOf(context), fontWeight: FontWeight.w600)), const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text('$tl', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ZoosyTheme.textDarkOf(context))), const SizedBox(width: 4), Text(context.l10n.unit_piece, style: TextStyle(fontSize: 12, color: ZoosyTheme.primary, fontWeight: FontWeight.bold)),
            ]),
          ]),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold))),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: ZoosyTheme.surfaceOf(context), borderRadius: BorderRadius.circular(24), border: Border.all(color: ZoosyTheme.outlineOf(context).withOpacity(0.2))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.local_fire_department, color: Colors.redAccent, size: 28), const SizedBox(height: 8), Text(context.l10n.consecutive_days, style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context), fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text('$cs ${context.l10n.unit_day}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ZoosyTheme.textDarkOf(context))), const SizedBox(height: 2), Text(context.l10n.keep_going, style: TextStyle(fontSize: 9, color: Colors.redAccent, fontWeight: FontWeight.w600))]))),
        const SizedBox(width: 12),
        Expanded(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: ZoosyTheme.surfaceOf(context), borderRadius: BorderRadius.circular(24), border: Border.all(color: ZoosyTheme.outlineOf(context).withOpacity(0.2))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.military_tech, color: ZoosyTheme.primary, size: 28), const SizedBox(height: 8), Text(context.l10n.longest_streak, style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context), fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text('$ms ${context.l10n.unit_day}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ZoosyTheme.textDarkOf(context))), const SizedBox(height: 2), Text(context.l10n.personal_best, style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold))]))),
      ]),
    ]);
  }

  Widget _buildInsightCard(Map<String, dynamic> best) {
    final tag = best['tag'] as String; final g = best['growth'] as int; final tc = best['thisCount'] as int;
    final msg = (tag.isEmpty || tc == 0) ? context.l10n.no_record_this_week : (g > 0 ? context.l10n.ss_insight_growth(tag, g) : context.l10n.ss_insight_current(tag, tc));
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: ZoosyTheme.primary, borderRadius: BorderRadius.circular(24)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.lightbulb, color: Colors.white, size: 20)),
        const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.l10n.weekly_insight, style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text(msg, style: const TextStyle(fontSize: 11.5, color: Colors.white70))])),
      ]));
  }

  Widget _buildTagRow(String name, int count, int ratio) => GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TagThoughtsScreen(tag: name, reflections: widget.reflections, onToggleFavorite: widget.onToggleFavorite, onDeleteReflection: widget.onDeleteReflection, onUpdateReflection: widget.onUpdateReflection))),
    child: Container(padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: ZoosyTheme.surfaceOf(context), borderRadius: BorderRadius.circular(20), border: Border.all(color: ZoosyTheme.outlineOf(context).withOpacity(0.2))),
      child: Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: ZoosyTheme.primary, shape: BoxShape.circle)), const SizedBox(width: 12),
        Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))), const Spacer(),
        Text('$count', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ZoosyTheme.textDarkOf(context))), const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: ZoosyTheme.containerLowOf(context), borderRadius: BorderRadius.circular(10)), child: Text('$ratio%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ZoosyTheme.textMutedOf(context)))),
        const SizedBox(width: 8), Icon(Icons.chevron_right, size: 16, color: ZoosyTheme.textMutedOf(context)),
      ])));
}

class ChartSplinePainter extends CustomPainter {
  final List<double> values; final double pointWidth;
  ChartSplinePainter({this.values = const [], this.pointWidth = 44});

  @override
  void paint(Canvas canvas, Size s) {
    if (values.isEmpty || s.width <= 0 || s.height <= 0) return;
    final max = values.reduce((a, b) => a > b ? a : b);
    final base = max > 0 ? max : 1.0;
    final h = s.height - 20; final n = values.length; final step = pointWidth; final w = n * step;
    final pts = <Offset>[];
    for (int i = 0; i < n; i++) {
      final v = values[i]; double y;
      if (max <= 0) y = h * 0.5; else y = h - (v / base) * h * 0.85 - h * 0.05;
      pts.add(Offset(i * step + step / 2, y));
    }
    final line = Paint()..color = ZoosyTheme.primary..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final fill = Paint()..style = PaintingStyle.fill..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [ZoosyTheme.primary.withOpacity(0.2), ZoosyTheme.primary.withOpacity(0.0)]).createShader(Rect.fromLTWH(0, 0, w, s.height));
    final path = Path(); path.moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < n; i++) path.cubicTo(pts[i-1].dx+(pts[i].dx-pts[i-1].dx)/2, pts[i-1].dy, pts[i-1].dx+(pts[i].dx-pts[i-1].dx)/2, pts[i].dy, pts[i].dx, pts[i].dy);
    final fp = Path.from(path); fp.lineTo(w, s.height); fp.lineTo(0, s.height); fp.close();
    canvas.drawPath(fp, fill); canvas.drawPath(path, line);
    final o = Paint()..color = ZoosyTheme.primary; final inn = Paint()..color = Colors.white;
    for (int i = 0; i < n; i++) { canvas.drawCircle(pts[i], 5, o); canvas.drawCircle(pts[i], 3, inn); }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class ChartDonutPainter extends CustomPainter {
  final List<double> values;
  final Color centerFillColor;
  ChartDonutPainter({this.values = const [], this.centerFillColor = Colors.white});
  static const colors = [Color(0xFF4828C8), Color(0xFFE91E63), Color(0xFFFF9800), Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFF9C27B0), Color(0xFF00BCD4), Color(0xFFF44336), Color(0xFF607D8B)];

  @override
  void paint(Canvas canvas, Size s) {
    if (values.isEmpty || s.width <= 0) return;
    final total = values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return;
    final c = Offset(s.width / 2, s.height / 2); final r = min(s.width, s.height) * 0.35; double start = -pi / 2;
    for (int i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, (values[i] / total) * 2 * pi, true, Paint()..color = colors[i % colors.length]);
      start += (values[i] / total) * 2 * pi;
    }
    canvas.drawCircle(c, r * 0.58, Paint()..color = centerFillColor);
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => true;

}

class ChartBarPainter extends CustomPainter {
  final List<double> values; final List<String> labels; final double pointWidth;
  ChartBarPainter({this.values = const [], this.labels = const [], this.pointWidth = 44});

  @override
  void paint(Canvas canvas, Size s) {
    if (values.isEmpty || s.width <= 0 || s.height <= 0) return;
    final max = values.reduce((a, b) => a > b ? a : b);
    final base = max > 0 ? max : 1.0;
    final h = s.height - 20; final n = values.length; final step = pointWidth;
    final barW = step * 0.6, gap = step * 0.4;
    for (int i = 0; i < n; i++) {
      final bh = (values[i] / base) * h * 0.8;
      final x = i * step + gap / 2; final y = h - bh - h * 0.05;
      canvas.drawRRect(RRect.fromRectAndCorners(Rect.fromLTWH(x, y, barW, bh), topLeft: const Radius.circular(4), topRight: const Radius.circular(4)), Paint()..color = ZoosyTheme.primary.withOpacity(0.6 + (values[i] / base) * 0.4));
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
