import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 全屏图片浏览器
/// 功能：左右滑动切换、双指缩放+旋转、双击以点击点缩放、沉浸模式、毛玻璃悬浮栏、轮播指示器
class ImageGalleryScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String? caption;
  final List<String>? tags;

  const ImageGalleryScreen({
    Key? key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.caption,
    this.tags,
  }) : super(key: key);

  @override
  State<ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<ImageGalleryScreen> {
  late PageController _pageCtrl;
  late int _currentIndex;
  final List<TransformationController> _transformCtls = [];
  bool _barsVisible = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _currentIndex);
    for (var i = 0; i < widget.imageUrls.length; i++) {
      _transformCtls.add(TransformationController());
    }
    // 进入沉浸模式（隐藏状态栏和导航栏）
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in _transformCtls) {
      c.dispose();
    }
    // 恢复系统栏
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 主内容：左右滑动切换图片
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.imageUrls.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (ctx, i) {
              return Hero(
                tag: 'gallery_img_$i',
                child: _ZoomableImage(
                  url: widget.imageUrls[i],
                  transformationController: _transformCtls[i],
                  onTap: () => setState(() => _barsVisible = !_barsVisible),
                ),
              );
            },
          ),

          // 顶部毛玻璃栏：← 返回 + 页码
          if (_barsVisible)
            Positioned(
              top: 0, left: 0, right: 0,
              child: _buildTopBar(topPad),
            ),

          // 底部毛玻璃栏：配文 + 标签
          if (_barsVisible)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildBottomBar(),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(double topPad) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(top: topPad + 4, bottom: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.6), Colors.transparent]),
          ),
          child: Row(children: [
            // 返回按钮
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(margin: const EdgeInsets.only(left: 4), padding: const EdgeInsets.all(8),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 24)),
            ),
            const Spacer(),
            // 页码指示器
            if (widget.imageUrls.length > 1)
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12)),
                child: Text('${_currentIndex + 1} / ${widget.imageUrls.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final hasCaption = widget.caption != null && widget.caption!.isNotEmpty;
    final hasTags = widget.tags != null && widget.tags!.isNotEmpty;
    if (!hasCaption && !hasTags) return const SizedBox.shrink();
    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.only(top: 12, bottom: 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
              colors: [Colors.black.withOpacity(0.7), Colors.transparent]),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (hasCaption)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(widget.caption!, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            if (hasTags)
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 6, right: 20, bottom: 4),
                child: Wrap(spacing: 6,
                  children: widget.tags!.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                    child: Text('#$t', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  )).toList(),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// 可缩放图片组件：支持双击以点击点缩放、双指捏合缩放旋转
class _ZoomableImage extends StatefulWidget {
  final String url;
  final TransformationController transformationController;
  final VoidCallback onTap;

  const _ZoomableImage({
    required this.url,
    required this.transformationController,
    required this.onTap,
  });

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  Offset? _doubleTapPosition;

  Widget _buildImage(String url) {
    final placeholder = Container(color: const Color(0xFF1A1A1A), child: Center(child: Icon(Icons.broken_image, color: Colors.white24, size: 48)));
    if (url.startsWith('/') || url.startsWith('file://')) {
      return Image.file(File(url.replaceFirst('file://', '')), fit: BoxFit.contain, errorBuilder: (_, __, ___) => placeholder);
    }
    return Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => placeholder);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (details) {
        _doubleTapPosition = details.localPosition;
      },
      onDoubleTap: () {
        final ctl = widget.transformationController;
        final currentScale = ctl.value.getMaxScaleOnAxis();
        if ((currentScale - 1.0).abs() < 0.05) {
          // 围绕双击点放大 2.5 倍
          final pos = _doubleTapPosition ?? Offset.zero;
          final matrix = Matrix4.identity();
          matrix.translate(pos.dx, pos.dy);
          matrix.scale(2.5);
          matrix.translate(-pos.dx, -pos.dy);
          ctl.value = matrix;
        } else {
          ctl.value = Matrix4.identity();
        }
      },
      child: InteractiveViewer(
        transformationController: widget.transformationController,
        minScale: 1.0,
        maxScale: 5.0,
        child: _buildImage(widget.url),
      ),
    );
  }
}
