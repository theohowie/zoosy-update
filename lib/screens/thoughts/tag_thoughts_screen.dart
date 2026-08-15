import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import 'reflection_detail_screen.dart';

class TagThoughtsScreen extends StatelessWidget {
  final String tag;
  final List<Reflection> reflections;
  final Function(String) onToggleFavorite;
  final Function(String) onDeleteReflection;
  final Function(Reflection) onUpdateReflection;

  const TagThoughtsScreen({
    Key? key, required this.tag, required this.reflections,
    required this.onToggleFavorite, required this.onDeleteReflection, required this.onUpdateReflection,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final filtered = reflections.where((r) => r.tags.contains(tag)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.tag_label(tag), style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0),
      body: filtered.isEmpty
          ? Center(child: Text(context.l10n.no_records, style: TextStyle(color: ZoosyTheme.textMutedOf(context))))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (context, idx) {
                final ref = filtered[idx];
                return Card(
                  color: ZoosyTheme.surfaceOf(context), surfaceTintColor: Colors.transparent, elevation: 0.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.black.withOpacity(0.04))),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReflectionDetailScreen(
                      reflection: ref, onToggleFavorite: onToggleFavorite, onDeleteReflection: onDeleteReflection, onUpdateReflection: onUpdateReflection,
                    ))),
                    child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(child: Text(ref.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Text(ref.time, style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context), fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 8),
                      Text(ref.content, style: TextStyle(fontSize: 13, color: ZoosyTheme.textMutedOf(context), height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ])),
                  ),
                );
              },
            ),
    );
  }
}
