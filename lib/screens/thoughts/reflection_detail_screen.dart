import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/reflection.dart';
import '../../services/ai_service.dart';
import '../../services/translation_service.dart';
import '../../widgets/toast_util.dart';
import 'new_reflection_screen.dart';
import 'image_gallery_screen.dart';

class ReflectionDetailScreen extends StatefulWidget {
  final Reflection reflection;
  final Function(String) onToggleFavorite;
  final Function(String) onDeleteReflection;
  final Function(Reflection) onUpdateReflection;

  const ReflectionDetailScreen({Key? key, required this.reflection, required this.onToggleFavorite, required this.onDeleteReflection, required this.onUpdateReflection}) : super(key: key);

  @override
  State<ReflectionDetailScreen> createState() => _ReflectionDetailScreenState();
}

class _ReflectionDetailScreenState extends State<ReflectionDetailScreen> {
  late bool _isFav;
  bool _aiEnabled = true;
  final GlobalKey _captureKey = GlobalKey();

  @override
  void initState() { super.initState(); _isFav = widget.reflection.isFavorite; _loadAI(); }

  Future<void> _loadAI() async {
    final enabled = await AIService.isEnabled();
    if (mounted) setState(() => _aiEnabled = enabled);
  }

  Future<void> _shareText() async {
    final text = '${widget.reflection.title}\n${widget.reflection.content}\n\n—— Zoosy 思考记录';
    await Share.share(text);
  }

  Future<void> _shareImage() async {
    try {
      // \u9884\u4e0b\u8f7d\u6240\u6709\u7f51\u7edc\u56fe\u7247\u5230\u4e34\u65f6\u6587\u4ef6
      final Map<String, String> imgMap = {};
      final imgUrl = widget.reflection.imageUrl;
      final hasImg = imgUrl != null && imgUrl.isNotEmpty;
      if (hasImg) {
        final dir = await getTemporaryDirectory();
        for (final url in imgUrl.split('||')) {
          final u = url.trim();
          if (u.isEmpty) continue;
          if (u.startsWith('/') || u.startsWith('file://')) {
            imgMap[u] = u.replaceFirst('file://', '');
          } else {
            try {
              final resp = await http.get(Uri.parse(u));
              final ext = u.endsWith('.png') ? '.png' : '.jpg';
              final file = File('${dir.path}/zoosy_share_img_${imgMap.length}$ext');
              await file.writeAsBytes(resp.bodyBytes);
              imgMap[u] = file.path;
            } catch (_) {}
          }
        }
      }

      final render = OverlayEntry(builder: (ctx) {
        final localImgPaths = imgMap.values.toList();
        return Positioned(
          top: -10000,
          child: RepaintBoundary(
            key: _captureKey,
            child: Material(
              child: Container(
                width: 360, padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [ZoosyTheme.primary.withOpacity(0.04), ZoosyTheme.bgLight])),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Zoosy', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ZoosyTheme.primary)),
                  const SizedBox(height: 16),
                  Text(widget.reflection.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ZoosyTheme.textDark)),
                  const SizedBox(height: 8),
                  Text('${widget.reflection.date}  ${widget.reflection.time}', style: TextStyle(fontSize: 11, color: ZoosyTheme.textMuted)),
                  const SizedBox(height: 12),
                  if (widget.reflection.tags.isNotEmpty) ...[
                    Wrap(spacing: 6, runSpacing: 4, children: widget.reflection.tags.map((t) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: ZoosyTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: Text(t, style: TextStyle(fontSize: 10, color: ZoosyTheme.primary, fontWeight: FontWeight.bold)))).toList()),
                    const SizedBox(height: 12),
                  ],
                  Text(widget.reflection.content, style: const TextStyle(fontSize: 13, color: ZoosyTheme.textMuted, height: 1.5)),
                  if (localImgPaths.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ...localImgPaths.map((path) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(File(path), width: double.infinity, fit: BoxFit.contain),
                      ),
                    )),
                  ],
                  const SizedBox(height: 20),
                  Center(child: Text('\u2014\u2014 Zoosy \u601d\u8003\u8bb0\u5f55 \u2014\u2014', style: TextStyle(fontSize: 10, color: ZoosyTheme.textMuted))),
                ]),
              ),
            ),
          ),
        );
      });

      Overlay.of(context).insert(render);
      try {
        await Future.delayed(const Duration(milliseconds: 300));

        final boundary = _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) { _shareText(); return; }

        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

        if (byteData == null) { _shareText(); return; }

        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/zoosy_share_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(byteData.buffer.asUint8List());
        await Share.shareXFiles([XFile(file.path)], text: TranslationService.tr('thought_from_zoosy'));
      } finally {
        // 无论分享成功与否，都清理临时文件
        for (final path in imgMap.values) {
          try { await File(path).delete(); } catch (_) {}
        }
        // 确保 OverlayEntry 一定被移除，防止内存泄漏
        render.remove();
      }
    } catch (e) {
      _shareText();
    }
  }

  void _showShareOptions() {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(TranslationService.tr('share'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ZoosyTheme.textDark)),
        const SizedBox(height: 20),
        ListTile(leading: Icon(Icons.text_fields, color: ZoosyTheme.primary), title: Text(TranslationService.tr('share_text')), onTap: () { Navigator.pop(ctx); _shareText(); }),
        ListTile(leading: Icon(Icons.image_outlined, color: ZoosyTheme.primary), title: Text(TranslationService.tr('share_image')), onTap: () { Navigator.pop(ctx); _shareImage(); }),
      ])),
    );
  }

  void _edit() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => NewReflectionScreen(
      onSave: (ref) { widget.onUpdateReflection(ref); Navigator.pop(context); ToastUtil.showToast(context, message: TranslationService.tr('updated'), icon: Icons.check, color: Colors.green); },
      editReflection: widget.reflection,
    )));
  }

  void _delete() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: ZoosyTheme.surfaceOf(ctx), surfaceTintColor: Colors.transparent,
      title: Text(TranslationService.tr('delete_record'), style: TextStyle(color: ZoosyTheme.textDarkOf(ctx))), content: Text(TranslationService.tr('delete_record_confirm'), style: TextStyle(color: ZoosyTheme.textMutedOf(ctx))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(TranslationService.tr('cancel'))), TextButton(onPressed: () { widget.onDeleteReflection(widget.reflection.id); Navigator.pop(ctx); Navigator.pop(context); ToastUtil.showToast(context, message: TranslationService.tr('reflection_deleted'), icon: Icons.delete_outline, color: Colors.redAccent); }, child: Text(TranslationService.tr('delete'), style: TextStyle(color: Colors.red)))],
    ));
  }

  /// \u56fe\u7247\u52a0\u8f7d\u5931\u8d25\u5360\u4f4d
  Widget _imgErr(BuildContext _, Object __, StackTrace? ___) {
    return Container(color: ZoosyTheme.primary.withOpacity(0.05),
      child: Center(child: Icon(Icons.broken_image, color: ZoosyTheme.textMuted.withOpacity(0.3))));
  }

  /// \u5168\u5c4f\u56fe\u7247\u6d4f\u89c8\u5668\uff08\u5c0f\u7ea2\u4e66\u98ce\u683c\uff09
  void _openImageViewer(int index) {
    final urls = (widget.reflection.imageUrl ?? '')
        .split('||')
        .map((u) => u.trim())
        .where((u) => u.isNotEmpty)
        .toList();
    if (urls.isEmpty || index >= urls.length) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ImageGalleryScreen(
        imageUrls: urls,
        initialIndex: index,
        caption: widget.reflection.title,
        tags: widget.reflection.tags,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.reflection.imageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Zoosy', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.bold)),
        surfaceTintColor: Colors.transparent, backgroundColor: Colors.transparent, elevation: 0,
        actions: [
          IconButton(onPressed: _showShareOptions, icon: Icon(Icons.share_outlined, color: ZoosyTheme.primary)),
          IconButton(onPressed: () { setState(() => _isFav = !_isFav); widget.onToggleFavorite(widget.reflection.id); }, icon: Icon(_isFav ? Icons.star : Icons.star_border, color: ZoosyTheme.primary)),
        ],
      ),
      body: Column(children: [
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.reflection.title, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 26, fontWeight: FontWeight.w800, color: ZoosyTheme.textDarkOf(context), letterSpacing: -0.5)),
            const SizedBox(height: 10),
            Row(children: [
              Text(widget.reflection.date, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ZoosyTheme.textMutedOf(context))),
              const SizedBox(width: 8), Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)), const SizedBox(width: 8),
              Text(widget.reflection.time, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ZoosyTheme.textMutedOf(context))),
            ]),
            if (widget.reflection.location != null && widget.reflection.location!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.location_on_outlined, size: 14, color: ZoosyTheme.textMutedOf(context)),
                const SizedBox(width: 4),
                Expanded(child: Text(widget.reflection.location!, style: TextStyle(fontSize: 11, color: ZoosyTheme.textMutedOf(context)))),
              ]),
            ],
            const SizedBox(height: 16),
            Wrap(spacing: 6, runSpacing: 6, children: widget.reflection.tags.map((t) => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: ZoosyTheme.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(20)), child: Text(t, style: TextStyle(fontSize: 11, color: ZoosyTheme.primary, fontWeight: FontWeight.bold)))).toList()),
            const SizedBox(height: 24),
            Text(widget.reflection.content, style: TextStyle(fontSize: 15, color: ZoosyTheme.textMutedOf(context), height: 1.6)),
            if (hasImage) ...[
              const SizedBox(height: 20),
              ...imageUrl.split('||').where((u) => u.trim().isNotEmpty).toList().asMap().entries.map((entry) {
                final i = entry.key;
                final u = entry.value.trim();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => _openImageViewer(i),
                    child: Hero(
                      tag: 'gallery_img_$i',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: u.startsWith('/') || u.startsWith('file://')
                            ? Image.file(File(u.replaceFirst('file://', '')), width: double.infinity, fit: BoxFit.contain, errorBuilder: _imgErr)
                            : Image.network(u, width: double.infinity, fit: BoxFit.contain, errorBuilder: _imgErr),
                      ),
                    ),
                  ),
                );
              }),
            ],
            if (_aiEnabled) ...[
              const SizedBox(height: 28),
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF2D2D3F).withOpacity(0.85)
                          : Colors.white.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.15)
                          : Colors.white.withOpacity(0.5)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ZoosyTheme.primary.withOpacity(0.15), shape: BoxShape.circle), child: Icon(Icons.psychology, color: ZoosyTheme.primary, size: 20)),
                        const SizedBox(width: 10),
                        Text(TranslationService.tr('ai_summary'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ZoosyTheme.primary)),
                      ]),
                      const SizedBox(height: 14),
                      Text(widget.reflection.aiSummary ?? TranslationService.tr('no_ai_summary'), style: TextStyle(fontSize: 13.5, color: ZoosyTheme.textDarkOf(context), height: 1.6)),
                    ]),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ]),
        )),
        Container(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), decoration: BoxDecoration(color: ZoosyTheme.surfaceOf(context), boxShadow: [BoxShadow(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2))]),
          child: Row(children: [
            Expanded(child: SizedBox(height: 48, child: ElevatedButton.icon(onPressed: _edit, icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 18), label: Text(TranslationService.tr('edit'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: ZoosyTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))))),
            const SizedBox(width: 12),
            Expanded(child: SizedBox(height: 48, child: ElevatedButton.icon(onPressed: _delete, icon: const Icon(Icons.delete, color: Colors.white, size: 18), label: Text(TranslationService.tr('delete'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBA1A1A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))))),
          ]),
        ),
      ]),
    );
  }
}
