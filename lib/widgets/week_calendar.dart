import 'package:flutter/material.dart';
import 'package:zoosy/generated/l10n/l10n_ext.dart';

import '../models/reflection.dart';

/// 周历组件控制器：供外部（如内容区滑动）把周视图跳转到指定日期所在周。
class WeekCalendarController {
  WeekCalendarState? _state;

  void attach(WeekCalendarState state) => _state = state;
  void detach() => _state = null;

  /// 动画跳转到指定日期（yyyy-MM-dd）所在的周。
  void jumpToWeek(String dateStr) => _state?._jumpToWeek(dateStr);

  /// 动画跳回"今天"所在周。
  void jumpToToday() => _state?._jumpToToday();
}

/// 可复用周历组件。
///
/// 实现思路：单个 [PageView.builder] + "10000 基准页"技巧——
/// 把"今天"映射为页码 10000，任意日期都能换算成整数页码（按天偏移），
/// 从而天然支持无限左右滑动翻周，无需维护"上一页/下一页"数据结构。
///
/// 组件是**受控**的：选中日期由外部传入 [selectedDate]，
/// 任何选中变化通过 [onDateSelected] 通知外部（点击日期、翻周自动选中周一）。
/// 外部如需反向控制（内容区滑动时同步周视图），使用 [controller]。
class WeekCalendar extends StatefulWidget {
  const WeekCalendar({
    Key? key,
    required this.selectedDate,
    required this.onDateSelected,
    this.controller,
    this.hasEntries,
    this.today,
    this.onWeekChanged,
    this.weekdayLabels,
  }) : super(key: key);

  /// 当前选中日期（yyyy-MM-dd）。
  final String selectedDate;

  /// 选中日期变化回调（点击日期 / 翻周后选中日不在该周而自动选中周一）。
  final ValueChanged<String> onDateSelected;

  /// 可选控制器，供外部把周视图跳到指定日期所在周。
  final WeekCalendarController? controller;

  /// 某天（yyyy-MM-dd）是否有记录，用于显示日期下方的小圆点。
  final bool Function(String dateStr)? hasEntries;

  /// 基准"今天"，默认 [DateTime.now]（App 跨天时由外部刷新后传入）。
  final DateTime? today;

  /// 当前显示周的周一变化回调，供外部更新标题"年月"。
  final ValueChanged<DateTime>? onWeekChanged;

  /// 周一到周日的标签。
  final List<String>? weekdayLabels;

  @override
  State<WeekCalendar> createState() => WeekCalendarState();
}

class WeekCalendarState extends State<WeekCalendar> {
  /// 基准页："今天"所在周的页码。
  static const int basePage = 10000;

  late PageController _pageController;
  late DateTime _today;
  late DateTime _currentWeekStart;
  int _currentPage = basePage;

  DateTime get currentWeekStart => _currentWeekStart;

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _mondayOfWeek(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  /// 页码 → 该周 7 天。
  List<DateTime> _getWeekDays(int page) {
    final monday = _mondayOfWeek(_today).add(Duration(days: (page - basePage) * 7));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  /// 外部调用：跳到指定日期所在周（若目标周不是当前周）。
  void _jumpToWeek(String dateStr) {
    final d = DateTime.parse(dateStr);
    final weekOffset = _mondayOfWeek(d).difference(_mondayOfWeek(_today)).inDays ~/ 7;
    final target = basePage + weekOffset;
    if (target != _currentPage) {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// 外部调用：跳回"今天"所在周。
  void _jumpToToday() {
    _pageController.animateToPage(
      basePage,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  void initState() {
    super.initState();
    _today = widget.today ?? DateTime.now();
    _currentWeekStart = _mondayOfWeek(_today);
    _pageController = PageController(initialPage: basePage);
    widget.controller?.attach(this);
  }

  @override
  void didUpdateWidget(WeekCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 跨天：基准"今天"变化时同步内部状态（页码 10000 仍对应新的今天所在周，无需翻页）
    final today = widget.today ?? DateTime.now();
    if (_dateStr(today) != _dateStr(_today)) {
      _today = today;
      _currentWeekStart = _mondayOfWeek(today);
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller?.detach();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      physics: const BouncingScrollPhysics(),
      onPageChanged: (page) {
        setState(() {
          _currentPage = page;
          _currentWeekStart = _getWeekDays(page)[0];
        });
        widget.onWeekChanged?.call(_currentWeekStart);
        // 若当前选中日期不在这一周，自动选中该周周一并通知外部
        final days = _getWeekDays(page);
        if (!days.any((d) => _dateStr(d) == widget.selectedDate)) {
          widget.onDateSelected(_dateStr(days[0]));
        }
      },
      itemBuilder: (context, page) => _buildWeekRow(_getWeekDays(page)),
    );
  }

  Widget _buildWeekRow(List<DateTime> days) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (i) {
        final d = days[i];
        final dateStr = _dateStr(d);
        final isSel = dateStr == widget.selectedDate;
        final isToday = dateStr == _dateStr(_today);
        final hasEntries = widget.hasEntries?.call(dateStr) ?? false;
        return GestureDetector(
          onTap: () => widget.onDateSelected(dateStr),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                (widget.weekdayLabels ??
                    [context.l10n.weekday_mon, context.l10n.weekday_tue, context.l10n.weekday_wed, context.l10n.weekday_thu, context.l10n.weekday_fri, context.l10n.weekday_sat, context.l10n.weekday_sun])[i],
                style: TextStyle(
                  fontSize: 11,
                  color: isToday ? ZoosyTheme.primary : ZoosyTheme.textMutedOf(context),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isToday
                      ? ZoosyTheme.primary
                      : (isSel ? ZoosyTheme.primary.withOpacity(0.15) : Colors.transparent),
                  shape: BoxShape.circle,
                  boxShadow: isToday
                      ? [
                          BoxShadow(
                            color: ZoosyTheme.primary.withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${d.day}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isToday
                        ? Colors.white
                        : (isSel ? ZoosyTheme.primary : ZoosyTheme.textDarkOf(context)),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: isToday
                      ? ZoosyTheme.primary
                      : (hasEntries
                          ? ZoosyTheme.textMutedOf(context).withOpacity(0.5)
                          : Colors.transparent),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
