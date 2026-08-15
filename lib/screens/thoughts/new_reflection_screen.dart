import 'package:zoosy/generated/l10n/l10n_ext.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/reflection.dart';
import '../../services/ai_service.dart';
import '../../services/location_service.dart';
import '../../services/voice_service.dart';
import '../../services/draft_service.dart';
import '../../utils/input_sanitizer.dart';
import 'save_success_screen.dart';
import '../../services/prefs_util.dart';
import '../../widgets/toast_util.dart';

class NewReflectionScreen extends StatefulWidget {
  final Function(Reflection) onSave;
  final Reflection? editReflection;

  const NewReflectionScreen({Key? key, required this.onSave, this.editReflection}) : super(key: key);

  @override
  State<NewReflectionScreen> createState() => _NewReflectionScreenState();
}

class _NewReflectionScreenState extends State<NewReflectionScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final FocusNode _contentFocusNode;
  late List<String> selectedTags;
  List<String> _imagePaths = [];
  bool _generatingAI = false;
  bool _isListening = false;
  bool _contentFocused = false;
  List<String> tagOptions = [];
  String? _currentLocation;
  bool _locationEnabled = true;
  bool _isLoadingLocation = false;
  String? _locationError;
  bool get _isEditing => widget.editReflection != null;
  static const int maxImages = 9;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.editReflection?.title ?? '');
    _contentController = TextEditingController(text: widget.editReflection?.content ?? '');
    _contentFocusNode = FocusNode();
    _contentFocusNode.addListener(() {
      if (mounted) setState(() => _contentFocused = _contentFocusNode.hasFocus);
    });
    selectedTags = widget.editReflection?.tags.isNotEmpty == true ? List.from(widget.editReflection!.tags) : [];
    // 从单条 imageUrl 解析多张图片（逗号分隔）
    final img = widget.editReflection?.imageUrl;
    if (img != null && img.isNotEmpty) _imagePaths = img.split('||');
    // 编辑时保留原位置
    _currentLocation = widget.editReflection?.location;
    _loadTags();
    _loadLocationSettings();
  }

  Future<void> _loadLocationSettings() async {
    _locationEnabled = await PrefsUtil.isLocationEnabled();
    if (mounted && !_isEditing && _locationEnabled) {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!_locationEnabled) return;

    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      final result = await LocationService.getCurrentLocationResult();
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          if (result.isSuccess) {
            _currentLocation = result.location?.address;
            _locationError = null;
          } else {
            _currentLocation = null;
            _locationError = result.errorMessage;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _locationError = context.l10n.nr_location_failed;
        });
      }
    }
  }

  Future<void> _retryLocation() async {
    _getCurrentLocation();
  }

  Future<void> _loadTags() async {
    final tags = await PrefsUtil.loadCustomTags();
    if (mounted) setState(() => tagOptions = tags);
  }

  @override
  void dispose() { _titleController.dispose(); _contentController.dispose(); _contentFocusNode.dispose(); super.dispose(); }

  bool get _hasContent => _titleController.text.trim().isNotEmpty || _contentController.text.trim().isNotEmpty;

  Future<bool> _onWillPop() async {
    if (!_hasContent) return true;
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: ZoosyTheme.surfaceOf(ctx), surfaceTintColor: Colors.transparent,
      title: Text(ctx.l10n.unsaved_changes, style: TextStyle(color: ZoosyTheme.textDarkOf(ctx))),
      content: Text(ctx.l10n.draft_save_to_drafts, style: TextStyle(color: ZoosyTheme.textMutedOf(ctx))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: Text(ctx.l10n.draft_discard)),
        TextButton(onPressed: () => Navigator.pop(ctx, 'save'), child: Text(ctx.l10n.draft_save, style: TextStyle(color: ZoosyTheme.primary, fontWeight: FontWeight.bold))),
      ],
    ));
    if (result == 'save') {
      await _saveToDraft();
      return true;
    }
    return result == 'discard';
  }

  Future<void> _saveToDraft() async {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final draftId = _isEditing ? widget.editReflection!.id : 'draft-${DateTime.now().millisecondsSinceEpoch}';
    final draft = Reflection(
      id: draftId,
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      date: _isEditing ? widget.editReflection!.date : dateStr,
      time: _isEditing ? widget.editReflection!.time : timeStr,
      tags: selectedTags,
      isFavorite: false,
      imageUrl: _imagePaths.isNotEmpty ? _imagePaths.join('||') : null,
      aiSummary: null,
      emotions: const [],
    );
    await DraftService.saveDraft(draft);
    if (mounted) ToastUtil.showToast(context, message: context.l10n.draft_edited, icon: Icons.article, color: ZoosyTheme.primary);
  }

  Future<void> _pickImages() async {
    if (_imagePaths.length >= maxImages) {
      ToastUtil.showToast(context, message: context.l10n.max_images('$maxImages'), icon: Icons.warning_amber_rounded, color: Colors.orange);
      return;
    }
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(maxWidth: 2048, maxHeight: 2048);
    if (files.isNotEmpty) {
      setState(() {
        for (final f in files) {
          if (_imagePaths.length < maxImages) _imagePaths.add(f.path);
        }
      });
    }
  }

  void _removeImage(int index) => setState(() => _imagePaths.removeAt(index));

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await VoiceService.stopListening();
      setState(() => _isListening = false);
      return;
    }

    await VoiceService.startListening(
      onResult: (text) {
        if (mounted) {
          setState(() {
            final current = _contentController.text;
            if (current.isEmpty) {
              _contentController.text = text;
            } else {
              _contentController.text = '$current $text';
            }
            _contentController.selection = TextSelection.fromPosition(
              TextPosition(offset: _contentController.text.length),
            );
          });
        }
      },
      onListeningComplete: () {
        if (mounted) setState(() => _isListening = false);
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isListening = false);
          String msg;
          switch (error) {
            case 'guest_blocked':
              msg = context.l10n.voice_guest_blocked;
              break;
            case 'limit_reached':
              msg = context.l10n.voice_limit_reached;
              break;
            case 'mic_denied':
              msg = context.l10n.voice_mic_denied;
              break;
            case 'not_available':
              msg = context.l10n.voice_not_available;
              break;
            default:
              msg = error;
          }
          ToastUtil.showToast(context, message: msg, icon: Icons.mic_off, color: Colors.redAccent);
        }
      },
    );
    if (mounted) setState(() => _isListening = true);
  }

  Future<void> _save() async {
    // 输入消毒
    final titleResult = InputSanitizer.sanitizeTitle(_titleController.text.trim());
    final contentResult = InputSanitizer.sanitizeContent(_contentController.text.trim());
    final sanitizedTags = selectedTags
        .map((tag) => InputSanitizer.sanitizeTag(tag).sanitized)
        .where((tag) => tag.isNotEmpty)
        .toList();

    final title = titleResult.sanitized;
    final content = contentResult.sanitized;

    if (title.isEmpty || content.isEmpty) {
      ToastUtil.showToast(context, message: context.l10n.please_enter_content, icon: Icons.info_outline);
      return;
    }

    // 显示消毒警告
    if (titleResult.hasWarning) {
      ToastUtil.showToast(context, message: titleResult.warning!, icon: Icons.warning_amber_rounded, color: Colors.orange);
    } else if (contentResult.hasWarning) {
      ToastUtil.showToast(context, message: contentResult.warning!, icon: Icons.warning_amber_rounded, color: Colors.orange);
    }

    setState(() => _generatingAI = true);

    String? aiSummary;
    if (await AIService.isEnabled()) {
      aiSummary = await AIService.generateSummary(content, title);
    }

    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // 复制图片到应用文档目录（防止系统缓存被清除）
    final List<String> savedPaths = [];
    try {
      final dir = await getApplicationDocumentsDirectory();
      for (final p in _imagePaths) {
        final src = File(p);
        if (await src.exists()) {
          final ext = p.endsWith('.png') ? '.png' : '.jpg';
          final dest = File('${dir.path}/zoosy_img_${DateTime.now().millisecondsSinceEpoch}_${savedPaths.length}$ext');
          await src.copy(dest.path);
          savedPaths.add(dest.path);
        } else {
          // 文件不存在则跳过，避免后续 Image.file 报错
        }
      }
    } catch (_) {
      // 复制失败时只保留仍存在的原路径
      savedPaths.addAll(_imagePaths.where((p) => File(p).existsSync()));
    }

    final newRef = Reflection(
      id: _isEditing ? widget.editReflection!.id : 'ref-${DateTime.now().millisecondsSinceEpoch}',
      title: title, content: content,
      date: _isEditing ? widget.editReflection!.date : _todayStr(),
      time: _isEditing ? widget.editReflection!.time : timeStr,
      tags: sanitizedTags,
      isFavorite: widget.editReflection?.isFavorite ?? false,
      imageUrl: savedPaths.isNotEmpty ? savedPaths.join('||') : null,
      aiSummary: aiSummary,
      emotions: _isEditing ? widget.editReflection!.emotions : ['洞察', '反思'],
      location: _locationEnabled ? _currentLocation : null,
    );

    widget.onSave(newRef);
    if (!_isEditing) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SaveSuccessScreen(
          reflection: newRef,
          onSave: widget.onSave,
        )),
      );
    } else {
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(title: Text(_isEditing ? context.l10n.edit_thought : context.l10n.new_thought, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.bold)),
          surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: _titleController,
            decoration: InputDecoration(hintText: context.l10n.title_hint, labelText: context.l10n.title_label, filled: true, fillColor: ZoosyTheme.surfaceOf(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.3)))),
            style: TextStyle(fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context)),
          ),
          const SizedBox(height: 16),
          Stack(children: [
            TextField(controller: _contentController, focusNode: _contentFocusNode, maxLines: 6,
              decoration: InputDecoration(
                hintText: context.l10n.content_hint,
                labelText: context.l10n.content_label,
                filled: true,
                fillColor: ZoosyTheme.surfaceOf(context),
                alignLabelWithHint: true,
                contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: ZoosyTheme.outlineOf(context).withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: ZoosyTheme.primaryOf(context), width: 2),
                ),
              ),
              style: TextStyle(color: ZoosyTheme.textDarkOf(context)),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Row(children: [
                if (_imagePaths.length < maxImages) ...[
                  Material(
                    color: ZoosyTheme.surfaceOf(context),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _pickImages,
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Icon(Icons.add, color: ZoosyTheme.primaryOf(context), size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Material(
                  color: ZoosyTheme.surfaceOf(context),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _toggleVoiceInput,
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_outlined,
                        color: _isListening ? Colors.redAccent : ZoosyTheme.primaryOf(context),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ]),

          const SizedBox(height: 24),

          // 图片网格
          if (_imagePaths.isNotEmpty) ...[
            Wrap(spacing: 8, runSpacing: 8, children: List.generate(_imagePaths.length, (i) {
              return ClipRRect(borderRadius: BorderRadius.circular(12),
                child: Stack(children: [
                  Image.file(File(_imagePaths[i]), width: (MediaQuery.of(context).size.width - 56) / 3, height: (MediaQuery.of(context).size.width - 56) / 3, fit: BoxFit.cover),
                  Positioned(top: 2, right: 2, child: GestureDetector(
                    onTap: () => _removeImage(i),
                    child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 14)),
                  )),
                ]),
              );
            })),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 24),

          Text(context.l10n.select_tags, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ZoosyTheme.textDarkOf(context))),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: tagOptions.map((tag) {
            final bool isSel = selectedTags.contains(tag);
            return FilterChip(label: Text(tag), selected: isSel, onSelected: (val) { setState(() { if (isSel) selectedTags.remove(tag); else selectedTags.add(tag); }); },
              backgroundColor: ZoosyTheme.containerLowOf(context), selectedColor: ZoosyTheme.primary.withOpacity(0.15), checkmarkColor: ZoosyTheme.primary, side: BorderSide.none,
              labelStyle: TextStyle(fontSize: 11, color: isSel ? ZoosyTheme.primary : ZoosyTheme.textMutedOf(context), fontWeight: FontWeight.bold));
          }).toList()),
          const SizedBox(height: 16),

          // 位置信息
          if (_locationEnabled) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: ZoosyTheme.containerLowOf(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (_isLoadingLocation) ...[
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ZoosyTheme.textMutedOf(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.location_getting,
                        style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context)),
                      ),
                    ),
                  ] else if (_currentLocation != null) ...[
                    Icon(Icons.location_on, size: 14, color: ZoosyTheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _currentLocation!,
                        style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else if (_locationError != null) ...[
                    Icon(Icons.location_off, size: 14, color: Colors.orange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _locationError!,
                        style: TextStyle(fontSize: 11, color: Colors.orange),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _retryLocation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: ZoosyTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          context.l10n.retry,
                          style: TextStyle(fontSize: 10, color: ZoosyTheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ] else ...[
                    Icon(Icons.location_off_outlined, size: 14, color: ZoosyTheme.textMutedOf(context).withOpacity(0.5)),
                    const SizedBox(width: 6),
                    Text(
                      context.l10n.location_disabled,
                      style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context).withOpacity(0.5)),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),

          SizedBox(height: 55,
            child: ElevatedButton.icon(
              onPressed: (_generatingAI && !_isEditing) ? null : _save,
              icon: _generatingAI ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Icon(Icons.check, color: Colors.white),
              label: Text(_isEditing ? context.l10n.save_modify : (_generatingAI ? context.l10n.generating_ai : context.l10n.save_thought),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: ZoosyTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 4),
            ),
          ),
          const SizedBox(height: 48),
        ]),
        ),
      ),
    );
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
