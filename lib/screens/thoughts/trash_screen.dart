import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import '../../services/trash_service.dart';
import '../../widgets/toast_util.dart';

class TrashScreen extends StatefulWidget {
  final Function(Reflection) onRestore;

  const TrashScreen({Key? key, required this.onRestore}) : super(key: key);

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<Reflection> _trash = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await TrashService.loadTrash();
    if (mounted) setState(() { _trash = list; _loading = false; });
  }

  void _restore(Reflection ref) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: ZoosyTheme.surfaceOf(ctx), surfaceTintColor: Colors.transparent,
      title: Text(ctx.l10n.trash_restore, style: TextStyle(color: ZoosyTheme.textDarkOf(ctx))),
      content: Text(ctx.l10n.trash_restore_confirm, style: TextStyle(color: ZoosyTheme.textMutedOf(ctx))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.cancel)),
        TextButton(onPressed: () async {
          Navigator.pop(ctx);
          await TrashService.permanentDelete(ref.id);
          widget.onRestore(ref);
          await _load();
          if (mounted) ToastUtil.showToast(context, message: ctx.l10n.trash_restore_success, icon: Icons.restore, color: Colors.green);
        }, child: Text(ctx.l10n.trash_restore, style: TextStyle(color: ZoosyTheme.primary))),
      ],
    ));
  }

  void _permanentDelete(Reflection ref) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: ZoosyTheme.surfaceOf(ctx), surfaceTintColor: Colors.transparent,
      title: Text(ctx.l10n.trash_permanent_delete, style: TextStyle(color: ZoosyTheme.textDarkOf(ctx))),
      content: Text(ctx.l10n.trash_permanent_confirm, style: TextStyle(color: ZoosyTheme.textMutedOf(ctx))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.cancel)),
        TextButton(onPressed: () async {
          Navigator.pop(ctx);
          await TrashService.permanentDelete(ref.id);
          await _load();
          if (mounted) ToastUtil.showToast(context, message: ctx.l10n.deleted, icon: Icons.delete, color: Colors.red);
        }, child: Text(ctx.l10n.trash_permanent_delete, style: const TextStyle(color: Colors.red))),
      ],
    ));
  }

  void _clearAll() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: ZoosyTheme.surfaceOf(ctx), surfaceTintColor: Colors.transparent,
      title: Text(ctx.l10n.trash_clear_all, style: TextStyle(color: ZoosyTheme.textDarkOf(ctx))),
      content: Text(ctx.l10n.trash_clear_all_confirm, style: TextStyle(color: ZoosyTheme.textMutedOf(ctx))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.cancel)),
        TextButton(onPressed: () async {
          Navigator.pop(ctx);
          await TrashService.clearAll();
          await _load();
          if (mounted) ToastUtil.showToast(context, message: ctx.l10n.deleted, icon: Icons.delete_sweep, color: Colors.red);
        }, child: Text(ctx.l10n.trash_clear_all, style: const TextStyle(color: Colors.red))),
      ],
    ));
  }

  String _daysRemaining(String deletedAt) {
    try {
      final dt = DateTime.parse(deletedAt);
      final days = 30 - DateTime.now().difference(dt).inDays;
      return context.l10n.trash_days_remaining('$days');
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.trash_title, style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0,
        actions: [
          if (_trash.isNotEmpty)
            IconButton(onPressed: _clearAll, icon: Icon(Icons.delete_sweep, color: ZoosyTheme.textMutedOf(context))),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: ZoosyTheme.primary))
          : _trash.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.delete_outline, size: 64, color: ZoosyTheme.textMutedOf(context).withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text(context.l10n.trash_empty, style: TextStyle(fontSize: 16, color: ZoosyTheme.textMutedOf(context))),
                  const SizedBox(height: 8),
                  Text(context.l10n.trash_empty_sub, style: TextStyle(fontSize: 12, color: ZoosyTheme.textMutedOf(context).withOpacity(0.6))),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _trash.length,
                  itemBuilder: (context, idx) {
                    final ref = _trash[idx];
                    return Card(
                      color: ZoosyTheme.surfaceOf(context), surfaceTintColor: Colors.transparent, elevation: 0.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.15))),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(children: [
                          Icon(Icons.delete_outline, color: ZoosyTheme.textMutedOf(context).withOpacity(0.5), size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(ref.title.isEmpty ? ref.content.substring(0, ref.content.length.clamp(0, 20)) : ref.title,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context)),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Text(_daysRemaining(ref.time), style: TextStyle(fontSize: 10, color: ZoosyTheme.textMutedOf(context))),
                        ]),
                        if (ref.content.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(ref.content, style: TextStyle(fontSize: 13, color: ZoosyTheme.textMutedOf(context), height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                        const SizedBox(height: 12),
                        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                          TextButton.icon(
                            onPressed: () => _restore(ref),
                            icon: Icon(Icons.restore, size: 16, color: ZoosyTheme.primary),
                            label: Text(context.l10n.trash_restore, style: TextStyle(color: ZoosyTheme.primary, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => _permanentDelete(ref),
                            icon: Icon(Icons.delete_forever, size: 16, color: Colors.red),
                            label: Text(context.l10n.trash_permanent_delete, style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                        ]),
                      ])),
                    );
                  },
                ),
    );
  }
}
