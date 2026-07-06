import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import '../../services/translation_service.dart';
import '../../services/draft_service.dart';
import '../../widgets/toast_util.dart';
import 'new_reflection_screen.dart';

class DraftsScreen extends StatefulWidget {
  final Function(Reflection) onPublish;

  const DraftsScreen({Key? key, required this.onPublish}) : super(key: key);

  @override
  State<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen> {
  List<Reflection> _drafts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await DraftService.loadDrafts();
    if (mounted) setState(() { _drafts = list; _loading = false; });
  }

  void _editDraft(Reflection draft) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => NewReflectionScreen(
      editReflection: draft,
      onSave: (ref) async {
        await DraftService.deleteDraft(draft.id);
        widget.onPublish(ref);
      },
    )));
    await _load();
  }

  void _deleteDraft(Reflection draft) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: ZoosyTheme.surfaceOf(ctx), surfaceTintColor: Colors.transparent,
      title: Text(TranslationService.tr('delete'), style: TextStyle(color: ZoosyTheme.textDarkOf(ctx))),
      content: Text(TranslationService.tr('trash_permanent_confirm'), style: TextStyle(color: ZoosyTheme.textMutedOf(ctx))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(TranslationService.tr('cancel'))),
        TextButton(onPressed: () async {
          Navigator.pop(ctx);
          await DraftService.deleteDraft(draft.id);
          await _load();
          if (mounted) ToastUtil.showToast(context, message: TranslationService.tr('draft_deleted'), icon: Icons.delete, color: Colors.red);
        }, child: Text(TranslationService.tr('delete'), style: const TextStyle(color: Colors.red))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(TranslationService.tr('drafts_title'), style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: ZoosyTheme.primary))
          : _drafts.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.article_outlined, size: 64, color: ZoosyTheme.textMutedOf(context).withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text(TranslationService.tr('drafts_empty'), style: TextStyle(fontSize: 16, color: ZoosyTheme.textMutedOf(context))),
                  const SizedBox(height: 8),
                  Text(TranslationService.tr('drafts_empty_sub'), style: TextStyle(fontSize: 12, color: ZoosyTheme.textMutedOf(context).withOpacity(0.6))),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _drafts.length,
                  itemBuilder: (context, idx) {
                    final ref = _drafts[idx];
                    return Card(
                      color: ZoosyTheme.surfaceOf(context), surfaceTintColor: Colors.transparent, elevation: 0.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.15))),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => _editDraft(ref),
                        child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Row(children: [
                            Icon(Icons.edit_note, color: ZoosyTheme.primary.withOpacity(0.6), size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(ref.title.isEmpty ? TranslationService.tr('draft_edit') : ref.title,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context)),
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Text('${ref.date} ${ref.time}', style: TextStyle(fontSize: 10, color: ZoosyTheme.textMutedOf(context))),
                          ]),
                          if (ref.content.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(ref.content, style: TextStyle(fontSize: 13, color: ZoosyTheme.textMutedOf(context), height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                          const SizedBox(height: 12),
                          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                            TextButton.icon(
                              onPressed: () => _editDraft(ref),
                              icon: Icon(Icons.edit, size: 16, color: ZoosyTheme.primary),
                              label: Text(TranslationService.tr('draft_edit'), style: TextStyle(color: ZoosyTheme.primary, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => _deleteDraft(ref),
                              icon: Icon(Icons.delete_outline, size: 16, color: Colors.red),
                              label: Text(TranslationService.tr('delete'), style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ),
                          ]),
                        ])),
                      ),
                    );
                  },
                ),
    );
  }
}
