import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import '../../services/prefs_util.dart';
import 'reflection_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final List<Reflection> reflections;
  final Function(String) onToggleFavorite;
  final Function(String) onDeleteReflection;
  final Function(Reflection) onUpdateReflection;

  const SearchScreen({Key? key, required this.reflections, required this.onToggleFavorite, required this.onDeleteReflection, required this.onUpdateReflection}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String query = '';
  List<String> selectedTags = [];
  List<String> _searchHistory = [];
  List<String> popularTags = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tags = await PrefsUtil.loadCustomTags();
    if (mounted) setState(() => popularTags = tags);
  }

  Future<void> _loadHistory() async {
    final history = await PrefsUtil.loadSearchHistory();
    if (mounted) setState(() => _searchHistory = history);
  }

  Future<void> _saveQuery(String q) async {
    await PrefsUtil.addSearchHistory(q);
    await _loadHistory();
  }

  Future<void> _removeFromHistory(String q) async {
    await PrefsUtil.removeSearchHistory(q);
    await _loadHistory();
  }

  Future<void> _clearHistory() async {
    await PrefsUtil.clearSearchHistory();
    await _loadHistory();
  }

  void _submitSearch(String q) {
    setState(() => query = q);
    _saveQuery(q);
    FocusScope.of(context).unfocus();
  }

  void _onQueryChanged(String text) {
    setState(() => query = text);
    // 当用户输入内容时，有搜索结果后自动保存关键词会干扰体验，
    // 只在用户主动点击搜索按钮或结果时保存
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = query.trim().isNotEmpty;
    final results = widget.reflections.where((ref) {
      final matchesQuery = isSearching &&
          (ref.title.toLowerCase().contains(query.toLowerCase()) ||
              ref.content.toLowerCase().contains(query.toLowerCase()));
      final matchesTags = selectedTags.isEmpty ||
          selectedTags.every((t) => ref.tags.contains(t));
      return matchesQuery && matchesTags;
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              onChanged: _onQueryChanged,
              onSubmitted: (q) => _submitSearch(q),
              controller: TextEditingController.fromValue(
                TextEditingValue(text: query),
              ),
              decoration: InputDecoration(
                hintText: isSearching ? query : context.l10n.search_hint,
                prefixIcon: Icon(Icons.search, color: ZoosyTheme.primary),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (query.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          setState(() => query = '');
                        },
                      ),
                    IconButton(
                      icon: Icon(Icons.search, color: ZoosyTheme.primary),
                      onPressed: () => _submitSearch(query),
                    ),
                  ],
                ),
                filled: true,
                fillColor: ZoosyTheme.containerLowOf(context),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ===== 热门标签（始终显示） =====
            Text(context.l10n.hot_tags, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: popularTags.map((tag) {
                final bool isSel = selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSel,
                  onSelected: (val) {
                    setState(() {
                      if (isSel) {
                        selectedTags.remove(tag);
                      } else {
                        selectedTags.add(tag);
                      }
                    });
                  },
                  backgroundColor: ZoosyTheme.containerLowOf(context),
                  selectedColor: ZoosyTheme.primary.withOpacity(0.15),
                  checkmarkColor: ZoosyTheme.primary,
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: isSel ? ZoosyTheme.primary : ZoosyTheme.textMutedOf(context),
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ===== 搜索历史 / 搜索结果 =====
            if (isSearching) ...[
              // 搜索结果
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.l10n.search_result, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
                  Text(context.l10n.result_count('${results.length}'), style: TextStyle(fontSize: 12, color: ZoosyTheme.textMutedOf(context), fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              if (results.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.0),
                  child: Center(
                    child: Text(context.l10n.no_results, style: TextStyle(color: ZoosyTheme.textMutedOf(context))),
                  ),
                )
              else
                ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: results.length,
                    itemBuilder: (context, idx) {
                      final r = results[idx];
                      return Card(
                        color: ZoosyTheme.surfaceOf(context), surfaceTintColor: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.2)),
                        ),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          onTap: () {
                            _saveQuery(query);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ReflectionDetailScreen(
                                  reflection: r,
                                  onToggleFavorite: widget.onToggleFavorite,
                                  onDeleteReflection: widget.onDeleteReflection,
                                  onUpdateReflection: widget.onUpdateReflection,
                                ),
                              ),
                            ).then((_) {
                              if (mounted) setState(() {});
                            });
                          },
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ZoosyTheme.primary.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.description_outlined, color: ZoosyTheme.primary, size: 20),
                          ),
                          title: Text(r.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ZoosyTheme.textDarkOf(context))),
                          subtitle: Text('${r.date} · ${r.time}', style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context))),
                          trailing: const Icon(Icons.chevron_right, size: 18),
                        ),
                      );
                    },
                  ),
            ] else ...[
              // 搜索历史
              if (_searchHistory.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.l10n.search_history, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
                    GestureDetector(
                      onTap: _clearHistory,
                      child: Text(context.l10n.clear, style: TextStyle(fontSize: 12, color: ZoosyTheme.primary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...List.generate(_searchHistory.length, (i) {
                  final h = _searchHistory[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.history, size: 20, color: ZoosyTheme.textMutedOf(context)),
                      title: Text(h, style: TextStyle(fontSize: 14, color: ZoosyTheme.textDarkOf(context))),
                      trailing: IconButton(
                        icon: Icon(Icons.close, size: 16, color: ZoosyTheme.textMutedOf(context).withOpacity(0.5)),
                        onPressed: () => _removeFromHistory(h),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      onTap: () => _submitSearch(h),
                    ),
                  );
                }),
              ] else ...[
                // 无搜索历史时显示提示
                if (selectedTags.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text(context.l10n.no_history, style: TextStyle(color: ZoosyTheme.textMutedOf(context))),
                    ),
                  ),
              ],
              // 已选标签时，即使无搜索词也展示匹配结果（标签过滤模式）
              if (selectedTags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.l10n.tag_match, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
                    Text(context.l10n.result_count('${results.length}'), style: TextStyle(fontSize: 12, color: ZoosyTheme.textMutedOf(context), fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                if (results.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0),
                    child: Center(child: Text(context.l10n.no_tag_match, style: TextStyle(color: ZoosyTheme.textMutedOf(context)))),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: results.length,
                    itemBuilder: (context, idx) {
                      final r = results[idx];
                      return Card(
                        color: ZoosyTheme.surfaceOf(context), surfaceTintColor: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.2)),
                        ),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ReflectionDetailScreen(
                                  reflection: r,
                                  onToggleFavorite: widget.onToggleFavorite,
                                  onDeleteReflection: widget.onDeleteReflection,
                                  onUpdateReflection: widget.onUpdateReflection,
                                ),
                              ),
                            ).then((_) {
                              if (mounted) setState(() {});
                            });
                          },
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ZoosyTheme.primary.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.description_outlined, color: ZoosyTheme.primary, size: 20),
                          ),
                          title: Text(r.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ZoosyTheme.textDarkOf(context))),
                          subtitle: Text('${r.date} · ${r.time}', style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context))),
                          trailing: const Icon(Icons.chevron_right, size: 18),
                        ),
                      );
                    },
                  ),
              ],
            ],
            const SizedBox(height: 48),
          ],
        ),
      ),
      ),
    );
  }
}
