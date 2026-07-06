import 'package:flutter/material.dart';
import '../../models/reflection.dart';
import '../../services/prefs_util.dart';
import '../../services/translation_service.dart';
import '../../utils/input_sanitizer.dart';
import '../../widgets/toast_util.dart';

class TagSettingsScreen extends StatefulWidget {
  const TagSettingsScreen({Key? key}) : super(key: key);

  @override
  State<TagSettingsScreen> createState() => _TagSettingsScreenState();
}

class _TagSettingsScreenState extends State<TagSettingsScreen> {
  List<String> _tags = [];
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tags = await PrefsUtil.loadCustomTags();
    if (mounted) setState(() => _tags = tags);
  }

  Future<void> _addTag() async {
    // 输入消毒
    final result = InputSanitizer.sanitizeTag(_controller.text.trim());
    final text = result.sanitized;
    if (text.isEmpty) return;
    if (_tags.contains(text)) {
      ToastUtil.showToast(context, message: TranslationService.tr('tag_exists'), icon: Icons.warning_amber_rounded, color: Colors.orange);
      return;
    }
    // 显示消毒警告
    if (result.hasWarning) {
      ToastUtil.showToast(context, message: result.warning!, icon: Icons.warning_amber_rounded, color: Colors.orange);
    }
    _tags.add(text);
    await PrefsUtil.saveCustomTags(_tags);
    _controller.clear();
    if (mounted) setState(() {});
  }

  Future<void> _deleteTag(int index) async {
    final tag = _tags[index];
    _tags.removeAt(index);
    await PrefsUtil.saveCustomTags(_tags);
    if (mounted) setState(() {});
    ToastUtil.showToast(context, message: TranslationService.tr('tag_deleted', params: {'tag': tag}), icon: Icons.delete_outline, color: Colors.redAccent);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(TranslationService.tr('tag_settings'), style: TextStyle(fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 添加标签输入框
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: TranslationService.tr('enter_new_tag'),
                      filled: true,
                      fillColor: ZoosyTheme.surfaceOf(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.3)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    style: TextStyle(color: ZoosyTheme.textDarkOf(context)),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _addTag,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ZoosyTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // 标签列表
            if (_tags.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(TranslationService.tr('no_tags'), style: TextStyle(color: ZoosyTheme.textMutedOf(context))),
                ),
              )
            else
              Card(
                color: ZoosyTheme.surfaceOf(context),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.2)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _tags.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ZoosyTheme.primary.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.label_outline, color: ZoosyTheme.primary, size: 18),
                      ),
                      title: Text(
                        _tags[index],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: ZoosyTheme.textDarkOf(context),
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, color: ZoosyTheme.textMutedOf(context), size: 20),
                        onPressed: () => _deleteTag(index),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
