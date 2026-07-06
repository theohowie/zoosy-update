import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import '../../services/translation_service.dart';
import 'reflection_detail_screen.dart';

class AllThoughtsScreen extends StatefulWidget {
  final List<Reflection> reflections;
  final Function(String) onToggleFavorite;
  final Function(String) onDeleteReflection;
  final Function(List<String>) onDeleteReflections;
  final Function(Reflection) onUpdateReflection;
  final Function(bool isSelectionMode, int selectedCount, VoidCallback onSelectAll, VoidCallback onDelete, VoidCallback onExit)? onSelectionChanged;

  const AllThoughtsScreen({Key? key, required this.reflections, required this.onToggleFavorite, required this.onDeleteReflection, required this.onDeleteReflections, required this.onUpdateReflection, this.onSelectionChanged}) : super(key: key);

  @override
  State<AllThoughtsScreen> createState() => _AllThoughtsScreenState();
}

class _AllThoughtsScreenState extends State<AllThoughtsScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  void _enterSelectionMode(String id) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(id);
    });
    _notifySelectionChanged();
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
    _notifySelectionChanged();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        // 取消选中项，但保持多选模式，不自动退出
      } else {
        _selectedIds.add(id);
      }
    });
    _notifySelectionChanged();
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == widget.reflections.length) {
        // 取消全选，但保持多选模式
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(widget.reflections.map((r) => r.id));
      }
    });
    _notifySelectionChanged();
  }

  void _notifySelectionChanged() {
    widget.onSelectionChanged?.call(
      _isSelectionMode,
      _selectedIds.length,
      _selectAll,
      _confirmBatchDelete,
      _exitSelectionMode,
    );
  }

  Future<void> _confirmBatchDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(TranslationService.tr('confirm_delete')),
        content: Text(TranslationService.tr('delete_selected_count', params: {'count': '${_selectedIds.length}'})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(TranslationService.tr('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(TranslationService.tr('delete'), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.onDeleteReflections(_selectedIds.toList());
      _exitSelectionMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<Reflection>.from(widget.reflections)
      ..sort((a, b) => '${b.date} ${b.time}'.compareTo('${a.date} ${a.time}'));

    if (sorted.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.inbox_outlined, size: 64, color: ZoosyTheme.textMutedOf(context).withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(TranslationService.tr('no_thoughts_yet'), style: TextStyle(fontSize: 16, color: ZoosyTheme.textMutedOf(context))),
        ]),
      );
    }

    // 按日期分组
    final grouped = <String, List<Reflection>>{};
    for (final r in sorted) {
      grouped.putIfAbsent(r.date, () => []).add(r);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: grouped.length,
      itemBuilder: (context, idx) {
        final date = grouped.keys.elementAt(idx);
        final dayReflections = grouped[date]!;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (idx > 0) const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                if (_isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: _selectAll,
                      child: Icon(
                        _selectedIds.length == sorted.length ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 20, color: ZoosyTheme.primary,
                      ),
                    ),
                  ),
                Text(date, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ZoosyTheme.textMutedOf(context))),
              ],
            ),
          ),
          ...dayReflections.map((ref) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildCard(ref),
          )),
        ]);
      },
    );
  }

  Widget _buildCard(Reflection ref) {
    final isSelected = _selectedIds.contains(ref.id);
    return Card(
      color: ZoosyTheme.surfaceOf(context), surfaceTintColor: Colors.transparent, elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isSelected ? ZoosyTheme.primary : ZoosyTheme.outlineOf(context).withOpacity(0.15),
          width: isSelected ? 2 : 1,
        ),
      ),
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onLongPress: () => _enterSelectionMode(ref.id),
        onTap: () {
          if (_isSelectionMode) {
            _toggleSelection(ref.id);
            return;
          }
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => ReflectionDetailScreen(
            reflection: ref, onToggleFavorite: widget.onToggleFavorite,
            onDeleteReflection: widget.onDeleteReflection, onUpdateReflection: widget.onUpdateReflection,
          ))).then((value) => setState(() {}));
        },
        child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            if (_isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 22, color: ZoosyTheme.primary,
                ),
              ),
            Expanded(child: Text(ref.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context)), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text(ref.time, style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context), fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          Text(ref.content, style: TextStyle(fontSize: 13, color: ZoosyTheme.textMutedOf(context), height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (ref.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Wrap(spacing: 6, runSpacing: 4, children: ref.tags.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
          ],
        ])),
      ),
    );
  }
}
