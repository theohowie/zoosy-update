import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import 'reflection_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  final List<Reflection> reflections;
  final Function(String) onToggleFavorite;
  final Function(String) onDeleteReflection;
  final Function(Reflection) onUpdateReflection;

  const FavoritesScreen({
    Key? key, required this.reflections, required this.onToggleFavorite,
    required this.onDeleteReflection, required this.onUpdateReflection,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final favorites = reflections.where((r) => r.isFavorite).toList();

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.my_favorites, style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0),
      body: favorites.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.favorite_border, size: 64, color: ZoosyTheme.textMutedOf(context).withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(context.l10n.no_favorites, style: TextStyle(fontSize: 16, color: ZoosyTheme.textMutedOf(context))),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: favorites.length,
              itemBuilder: (context, idx) {
                final ref = favorites[idx];
                return Card(
                  color: ZoosyTheme.surfaceOf(context), surfaceTintColor: Colors.transparent, elevation: 0.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.15))),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReflectionDetailScreen(
                      reflection: ref, onToggleFavorite: onToggleFavorite, onDeleteReflection: onDeleteReflection, onUpdateReflection: onUpdateReflection,
                    ))),
                    child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Icon(Icons.favorite, color: ZoosyTheme.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(ref.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Text(ref.time, style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context), fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 8),
                      Text(ref.content, style: TextStyle(fontSize: 13, color: ZoosyTheme.textMutedOf(context), height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Text(ref.date, style: TextStyle(fontSize: 10, color: ZoosyTheme.textMutedOf(context))),
                    ])),
                  ),
                );
              },
            ),
    );
  }
}
