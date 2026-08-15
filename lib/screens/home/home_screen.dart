import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/reflection.dart';
import '../../services/theme_service.dart';
import '../thoughts/reflection_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<Reflection> reflections;
  final Function(String) onToggleFavorite;
  final Function(String) onDeleteReflection;
  final Function(Reflection) onUpdateReflection;

  const HomeScreen({Key? key, required this.reflections, required this.onToggleFavorite, required this.onDeleteReflection, required this.onUpdateReflection}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late DateTime _today;
  late String _selectedDate;
  late PageController _weekPageController;
  late PageController _contentPageController;
  int _currentWeekPage = 10000;
  int _contentPage = 10000;
  DateTime? _currentWeekStart;
  bool _isAnimatingContent = false;
  List<String> get _weekDays => [
    context.l10n.weekday_mon, context.l10n.weekday_tue, context.l10n.weekday_wed, context.l10n.weekday_thu,
    context.l10n.weekday_fri, context.l10n.weekday_sat, context.l10n.weekday_sun,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _today = DateTime.now();
    _selectedDate = _dateStr(_today);
    _weekPageController = PageController(initialPage: _currentWeekPage);
    _contentPageController = PageController(initialPage: _contentPage);
    _currentWeekStart = _mondayOfWeek(_today);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _weekPageController.dispose();
    _contentPageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_dateStr(now) != _dateStr(_today)) {
        setState(() {
          _today = now;
          _selectedDate = _dateStr(_today);
          _currentWeekStart = _mondayOfWeek(_today);
        });
      }
    }
  }

  String _dateStr(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  DateTime _mondayOfWeek(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));
  List<DateTime> _getWeekDays(int page) {
    final monday = _mondayOfWeek(_today).add(Duration(days: (page - 10000) * 7));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }
  bool _isToday(String dateStr) => dateStr == _dateStr(_today);

  /// 根据 contentPage 计算对应的日期字符串
  String _dateForContentPage(int page) {
    final d = _today.add(Duration(days: page - 10000));
    return _dateStr(d);
  }

  /// 根据日期字符串计算对应的 contentPage
  int _pageForDate(String dateStr) {
    final d = DateTime.parse(dateStr);
    final diff = DateTime(d.year, d.month, d.day).difference(
      DateTime(_today.year, _today.month, _today.day),
    ).inDays;
    return 10000 + diff;
  }

  /// 点击日历上的日期 → 同步内容区
  void _onDateSelected(String dateStr) {
    setState(() => _selectedDate = dateStr);
    final targetPage = _pageForDate(dateStr);
    _isAnimatingContent = true;
    _contentPageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    ).then((_) => _isAnimatingContent = false);
  }

  /// 内容区滑动后 → 同步日历和选中日期
  void _onContentPageChanged(int page) {
    final dateStr = _dateForContentPage(page);
    setState(() {
      _contentPage = page;
      _selectedDate = dateStr;
    });
    // 如果内容区是由日历切换触发的动画，不反向同步周视图，避免周被拉回去
    if (_isAnimatingContent) return;
    // 同步日历周视图：计算当前日期所在的周 page
    final d = DateTime.parse(dateStr);
    final weekMonday = _mondayOfWeek(d);
    final weekOffset = weekMonday.difference(_mondayOfWeek(_today)).inDays ~/ 7;
    final targetWeekPage = 10000 + weekOffset;
    if (targetWeekPage != _currentWeekPage) {
      _weekPageController.animateToPage(
        targetWeekPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onDoubleTap: () {
                  _weekPageController.animateToPage(10000, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                  _onDateSelected(_dateStr(_today));
                  setState(() { _currentWeekPage = 10000; _currentWeekStart = _mondayOfWeek(_today); });
                },
                child: Text(context.l10n.date_header(_currentWeekStart?.year ?? _today.year, _currentWeekStart?.month ?? _today.month),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context)),
                    key: ValueKey(_currentWeekStart?.month)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: ZoosyTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(context.l10n.active_calendar, style: TextStyle(fontSize: 9, color: ZoosyTheme.primary, fontWeight: FontWeight.bold)),
              )
            ]),
            const SizedBox(height: 10),
            SizedBox(
              height: 68,
              child: PageView.builder(
                controller: _weekPageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (page) {
                  setState(() {
                    _currentWeekPage = page;
                    final days = _getWeekDays(page);
                    _currentWeekStart = days[0];
                  });
                  final days = _getWeekDays(page);
                  // 如果当前选中日期不在这一周，跳转到该周的第一天并同步内容区
                  if (!days.any((d) => _dateStr(d) == _selectedDate)) {
                    _onDateSelected(_dateStr(days[0]));
                  }
                },
                itemBuilder: (context, page) => _buildWeekRow(_getWeekDays(page)),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: ZoosyTheme.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Icon(Icons.analytics_outlined, color: ZoosyTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(_isToday(_selectedDate) ? context.l10n.today_thoughts : context.l10n.daily_records,
                  style: TextStyle(fontSize: 12, color: ZoosyTheme.primary, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(_selectedDate, style: TextStyle(fontSize: 10, color: ZoosyTheme.primary.withOpacity(0.7), fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _contentPageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: _onContentPageChanged,
            itemBuilder: (context, page) {
              final dateStr = _dateForContentPage(page);
              final filtered = widget.reflections.where((r) => r.date == dateStr).toList();
              if (filtered.isEmpty) {
                return _buildEmptyState(dateStr);
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: filtered.length,
                itemBuilder: (context, idx) => _buildReflectionCard(filtered[idx]),
              );
            },
          ),
        )
      ],
    );
  }

  Widget _buildWeekRow(List<DateTime> days) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (i) {
        final d = days[i]; final dateStr = _dateStr(d);
        final isSel = dateStr == _selectedDate; final isToday = _isToday(dateStr);
        final hasEntries = widget.reflections.any((r) => r.date == dateStr);
        return GestureDetector(
          onTap: () => _onDateSelected(dateStr),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(_weekDays[i], style: TextStyle(fontSize: 11, color: isToday ? ZoosyTheme.primary : ZoosyTheme.textMutedOf(context))),
            const SizedBox(height: 4),
            Container(width: 36, height: 36,
              decoration: BoxDecoration(
                color: isToday ? ZoosyTheme.primary : (isSel ? ZoosyTheme.primary.withOpacity(0.15) : Colors.transparent),
                shape: BoxShape.circle,
                boxShadow: isToday ? [BoxShadow(color: ZoosyTheme.primary.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))] : null,
              ),
              alignment: Alignment.center,
              child: Text('${d.day}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                  color: isToday ? Colors.white : (isSel ? ZoosyTheme.primary : ZoosyTheme.textDarkOf(context)))),
            ),
            const SizedBox(height: 3),
            Container(width: 4, height: 4,
              decoration: BoxDecoration(
                color: isToday ? ZoosyTheme.primary : (hasEntries ? ZoosyTheme.textMutedOf(context).withOpacity(0.5) : Colors.transparent),
                shape: BoxShape.circle),
            )
          ]),
        );
      }),
    );
  }

  Widget _buildEmptyState(String dateStr) {
    final isFuture = dateStr.compareTo(_dateStr(_today)) > 0;
    final isPast = dateStr.compareTo(_dateStr(_today)) < 0;
    String title, subtitle;
    if (isFuture) { title = context.l10n.day_not_reached; subtitle = context.l10n.day_not_reached_sub; }
    else if (isPast) { title = context.l10n.no_record_day; subtitle = context.l10n.no_record_day_sub; }
    else { title = context.l10n.no_record_today; subtitle = context.l10n.no_record_today_sub; }

    return SingleChildScrollView(
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 24.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0),
          decoration: BoxDecoration(color: ZoosyTheme.surfaceOf(context).withOpacity(0.5), borderRadius: BorderRadius.circular(36),
              border: Border.all(color: ZoosyTheme.outlineOf(context).withOpacity(0.15))),
          child: Column(children: [
            ClipRRect(borderRadius: BorderRadius.circular(20),
              child: Image.asset(ThemeService.currentLogoAsset,
                  width: 120, height: 120, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 120, height: 120,
                    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.psychology_outlined, size: 48, color: Color(0xFFC9C4D7)),
                  ),
              ),
            ),
            const SizedBox(height: 24),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
            const SizedBox(height: 10),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: ZoosyTheme.textMutedOf(context), height: 1.4)),
          ]),
        ),
      ),
    );
  }

  Widget _buildReflectionCard(Reflection ref) {
    return Card(
      color: ZoosyTheme.surfaceOf(context), surfaceTintColor: Colors.transparent, elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.15))),
      margin: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => ReflectionDetailScreen(
            reflection: ref, onToggleFavorite: widget.onToggleFavorite,
            onDeleteReflection: widget.onDeleteReflection, onUpdateReflection: widget.onUpdateReflection,
          ))).then((value) => setState(() {}));
        },
        child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(ref.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context)), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text(ref.time, style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context), fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          Text(ref.content, style: TextStyle(fontSize: 13, color: ZoosyTheme.textMutedOf(context), height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Wrap(spacing: 6, runSpacing: 4, children: ref.tags.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: ZoosyTheme.containerLowOf(context), borderRadius: BorderRadius.circular(12)),
              child: Text(t, style: TextStyle(fontSize: 10, color: ZoosyTheme.textMutedOf(context), fontWeight: FontWeight.bold)),
            )).toList())),
            if (ref.location != null && ref.location!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Icon(Icons.location_on_outlined, size: 12, color: ZoosyTheme.textMutedOf(context).withOpacity(0.6)),
              const SizedBox(width: 2),
              Flexible(child: Text(ref.location!, style: TextStyle(fontSize: 9, color: ZoosyTheme.textMutedOf(context).withOpacity(0.6)), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ]),
        ])),
      ),
    );
  }
}
