import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../core/models/image_record.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/settings_provider.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/record_svg_image.dart';

class ImagePreviewPage extends ConsumerStatefulWidget {
  const ImagePreviewPage({
    super.key,
    required this.record,
    this.records = const [],
    this.initialIndex = 0,
  });

  final ImageRecord record;
  final List<ImageRecord> records;
  final int initialIndex;

  @override
  ConsumerState<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends ConsumerState<ImagePreviewPage> {
  static const double _minScaleFactor = 0.8;
  static const double _maxScaleFactor = 4.0;
  static const double _wheelZoomStep = 1.12;
  static const double _scaleSnapTolerance = 0.015;
  static const Duration _pageTurnDuration = Duration(milliseconds: 220);

  late final PageController _pageController;
  late List<ImageRecord> _records;
  late List<_PreviewPhotoController> _photoControllers;
  late Future<String?> _actualSizeLabelFuture;
  late Future<String?> _fileSizeLabelFuture;
  StreamSubscription<PhotoViewControllerValue>? _controllerSubscription;

  int _currentIndex = 0;
  double? _baselineScale;
  double _currentScale = 1.0;
  bool _infoCollapsed = false;
  final Map<String, Size> _svgSizes = {};

  ImageRecord get _currentRecord => _records[_currentIndex];
  PhotoViewController get _photoViewController =>
      _photoControllers[_currentIndex].photoViewController;
  PhotoViewScaleStateController get _scaleStateController =>
      _photoControllers[_currentIndex].scaleStateController;
  bool get _hasPrevious => _currentIndex > 0;
  bool get _hasNext => _currentIndex < _records.length - 1;
  bool get _showsNavigationArrows =>
      _records.length > 1 && (Platform.isWindows || Platform.isMacOS);
  bool get _supportsPointerScrollZoom => Platform.isWindows || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    _records = _initialRecords();
    _photoControllers = _createPhotoControllers(_records.length);
    _currentIndex = _initialIndexFor(_records);
    _pageController = PageController(initialPage: _currentIndex);
    _actualSizeLabelFuture = _resolveActualSizeLabel();
    _fileSizeLabelFuture = _resolveFileSizeLabel();
    _infoCollapsed = ref.read(settingsProvider).previewInfoCollapsed;
    _listenToCurrentController();
  }

  @override
  void didUpdateWidget(covariant ImagePreviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record != widget.record ||
        oldWidget.records != widget.records) {
      _controllerSubscription?.cancel();
      _disposePhotoControllers();
      _records = _initialRecords();
      _photoControllers = _createPhotoControllers(_records.length);
      _currentIndex = _initialIndexFor(_records);
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentIndex);
      }
      _resetZoomState();
      _actualSizeLabelFuture = _resolveActualSizeLabel();
      _fileSizeLabelFuture = _resolveFileSizeLabel();
      _listenToCurrentController();
    }
  }

  @override
  void dispose() {
    _controllerSubscription?.cancel();
    _pageController.dispose();
    _disposePhotoControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = _currentRecord;
    final scaffold = Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          if (record.resultImagePath != null || record.resultImageUrl != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: '保存到本地',
                onPressed: () => _saveImage(context, ref),
                icon: const Icon(Icons.download_rounded),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildViewer()),
          Positioned(top: 16, right: 16, child: _ZoomBadge(label: _zoomLabel)),
          if (_showsNavigationArrows && _hasPrevious)
            Positioned(
              left: 24,
              top: 0,
              bottom: 0,
              child: Center(
                child: _PreviewNavigationButton(
                  tooltip: '上一张',
                  icon: Icons.chevron_left_rounded,
                  onPressed: _showPrevious,
                ),
              ),
            ),
          if (_showsNavigationArrows && _hasNext)
            Positioned(
              right: 24,
              top: 0,
              bottom: 0,
              child: Center(
                child: _PreviewNavigationButton(
                  tooltip: '下一张',
                  icon: Icons.chevron_right_rounded,
                  onPressed: _showNext,
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: animation,
                    alignment: Alignment.bottomLeft,
                    child: child,
                  ),
                ),
                child: _infoCollapsed
                    ? _buildCollapsedInfoButton()
                    : _buildExpandedInfoPanel(record),
              ),
            ),
          ),
        ],
      ),
    );

    if (!_showsNavigationArrows) {
      return scaffold;
    }

    return Focus(autofocus: true, onKeyEvent: _handleKeyEvent, child: scaffold);
  }

  List<ImageRecord> _initialRecords() {
    final inputRecords = widget.records.isEmpty
        ? [widget.record]
        : widget.records;
    final seenIds = <String>{};
    final records = <ImageRecord>[];

    for (final record in inputRecords) {
      if (_canPreviewRecord(record) && seenIds.add(record.id)) {
        records.add(record);
      }
    }

    if (!seenIds.contains(widget.record.id)) {
      records.add(widget.record);
    }

    return records.isEmpty ? [widget.record] : records;
  }

  int _initialIndexFor(List<ImageRecord> records) {
    final initialIndex = widget.initialIndex;
    if (initialIndex >= 0 &&
        initialIndex < records.length &&
        records[initialIndex].id == widget.record.id) {
      return initialIndex;
    }

    final recordIndex = records.indexWhere(
      (record) => record.id == widget.record.id,
    );
    return recordIndex < 0 ? 0 : recordIndex;
  }

  List<_PreviewPhotoController> _createPhotoControllers(int count) {
    return List<_PreviewPhotoController>.generate(
      count,
      (_) => _PreviewPhotoController(),
    );
  }

  void _disposePhotoControllers() {
    for (final controller in _photoControllers) {
      controller.dispose();
    }
  }

  void _listenToCurrentController() {
    _controllerSubscription?.cancel();
    _controllerSubscription = _photoViewController.outputStateStream.listen(
      _handleControllerValue,
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft && _hasPrevious) {
      _showPrevious();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight && _hasNext) {
      _showNext();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _showPrevious() {
    _animateToIndex(_currentIndex - 1);
  }

  void _showNext() {
    _animateToIndex(_currentIndex + 1);
  }

  void _animateToIndex(int index) {
    if (index < 0 || index >= _records.length || index == _currentIndex) {
      return;
    }

    if (!_pageController.hasClients) {
      _handlePageChanged(index);
      return;
    }

    _pageController.animateToPage(
      index,
      duration: _pageTurnDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _handlePageChanged(int index) {
    if (index < 0 || index >= _records.length) {
      return;
    }

    setState(() {
      _currentIndex = index;
      _baselineScale = null;
      _currentScale = 1.0;
      _actualSizeLabelFuture = _resolveActualSizeLabel();
      _fileSizeLabelFuture = _resolveFileSizeLabel();
    });

    _listenToCurrentController();
    _resetZoomState();
  }

  void _resetZoomState() {
    _photoViewController.reset();
    _scaleStateController.reset();
    _baselineScale = null;
    _currentScale = 1.0;
  }

  bool _canPreviewRecord(ImageRecord record) {
    return record.resultImagePath != null ||
        record.resultImageUrl != null ||
        record.sourceAttachmentPaths.isNotEmpty;
  }

  void _toggleInfoCollapsed() {
    final next = !_infoCollapsed;
    setState(() => _infoCollapsed = next);
    ref.read(settingsProvider.notifier).setPreviewInfoCollapsed(next);
  }

  Widget _buildCollapsedInfoButton() {
    return Material(
      key: const ValueKey('preview-info-collapsed'),
      color: Colors.black.withValues(alpha: 0.72),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _toggleInfoCollapsed,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: const Icon(Icons.info_outline_rounded, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildExpandedInfoPanel(ImageRecord record) {
    return Container(
      key: const ValueKey('preview-info-expanded'),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PreviewChip(label: record.sizeLabel),
                        _ActualSizePreviewChip(
                          labelFuture: _actualSizeLabelFuture,
                        ),
                        _FileSizePreviewChip(labelFuture: _fileSizeLabelFuture),
                        _PreviewChip(label: record.outputFormatLabel),
                        if (record.outputFormat == 'gif')
                          _PreviewChip(
                            label:
                                '${record.frameCount} 帧 · ${record.frameDurationMs} ms/帧',
                          ),
                        if (record.complexity != null)
                          _PreviewChip(label: '复杂度 ${record.complexity}'),
                        if (record.svgOptions != null)
                          _PreviewChip(
                            label: 'SVG ${record.svgOptions!.model}',
                          ),
                        if (record.svgOptions?.reasoningEffort != null)
                          _PreviewChip(
                            label:
                                'SVG 推理 ${record.svgOptions!.reasoningEffort!.name}',
                          ),
                        if (record.markupPath != null)
                          const _PreviewChip(label: '标注引导'),
                        _PreviewChip(label: record.qualityLabel),
                        _PreviewChip(label: record.model),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: '收起',
                  onPressed: _toggleInfoCollapsed,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.close_fullscreen_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 84),
              child: SingleChildScrollView(
                child: Text(
                  record.prompt,
                  style: const TextStyle(color: Colors.white, height: 1.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleControllerValue(PhotoViewControllerValue value) {
    final scale = value.scale;
    if (!mounted || scale == null || scale <= 0) {
      return;
    }

    setState(() {
      _baselineScale ??= scale;
      _currentScale = scale;
    });
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (!_supportsPointerScrollZoom || event is! PointerScrollEvent) {
      return;
    }

    final currentScale = _photoViewController.scale;
    final baselineScale = _baselineScale;
    if (currentScale == null ||
        baselineScale == null ||
        currentScale <= 0 ||
        baselineScale <= 0) {
      return;
    }

    final scaleDelta = event.scrollDelta.dy < 0
        ? _wheelZoomStep
        : 1 / _wheelZoomStep;
    final nextScale = (currentScale * scaleDelta).clamp(
      baselineScale * _minScaleFactor,
      baselineScale * _maxScaleFactor,
    );

    final snappedScale = _isNearBaseline(nextScale, baselineScale)
        ? baselineScale
        : nextScale;
    if ((snappedScale - currentScale).abs() < 0.0001) {
      return;
    }

    _photoViewController.scale = snappedScale;
    if (snappedScale == baselineScale) {
      _scaleStateController.setInvisibly(PhotoViewScaleState.initial);
    }
  }

  Widget _buildViewer() {
    final gallery = PhotoViewGallery.builder(
      itemCount: _records.length,
      pageController: _pageController,
      onPageChanged: _handlePageChanged,
      scrollPhysics: const BouncingScrollPhysics(),
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      loadingBuilder: (context, event) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      builder: _buildGalleryItem,
    );

    if (!_supportsPointerScrollZoom) {
      return gallery;
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerSignal: _handlePointerSignal,
      child: gallery,
    );
  }

  PhotoViewGalleryPageOptions _buildGalleryItem(
    BuildContext context,
    int index,
  ) {
    final record = _records[index];
    final controller = _photoControllers[index];
    if (record.isSvg) {
      return PhotoViewGalleryPageOptions.customChild(
        child: RecordSvgImage(record: record),
        childSize:
            _svgSizes[record.id] ??
            Size(
              record.width > 0 ? record.width.toDouble() : 1024,
              record.height > 0 ? record.height.toDouble() : 1024,
            ),
        controller: controller.photoViewController,
        scaleStateController: controller.scaleStateController,
        minScale: PhotoViewComputedScale.contained * _minScaleFactor,
        maxScale: PhotoViewComputedScale.contained * _maxScaleFactor,
        initialScale: PhotoViewComputedScale.contained,
      );
    }
    final provider = _previewImageProvider(record);

    if (provider == null) {
      return PhotoViewGalleryPageOptions.customChild(
        child: const Icon(Icons.broken_image_rounded, color: Colors.white70),
        childSize: const Size.square(120),
        controller: controller.photoViewController,
        scaleStateController: controller.scaleStateController,
        minScale: PhotoViewComputedScale.contained * _minScaleFactor,
        maxScale: PhotoViewComputedScale.contained * _maxScaleFactor,
        initialScale: PhotoViewComputedScale.contained,
      );
    }

    return PhotoViewGalleryPageOptions(
      imageProvider: provider,
      heroAttributes: PhotoViewHeroAttributes(tag: 'image-${record.id}'),
      controller: controller.photoViewController,
      scaleStateController: controller.scaleStateController,
      minScale: PhotoViewComputedScale.contained * _minScaleFactor,
      maxScale: PhotoViewComputedScale.contained * _maxScaleFactor,
      initialScale: PhotoViewComputedScale.contained,
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Icon(Icons.broken_image_rounded, color: Colors.white70),
      ),
    );
  }

  Future<String?> _resolveActualSizeLabel() async {
    final record = _currentRecord;
    if (record.isSvg) {
      try {
        final size = await svgSizeForRecord(record);
        if (size == null) return null;
        if (mounted) setState(() => _svgSizes[record.id] = size);
        return '实际尺寸${size.width.round()}x${size.height.round()}';
      } catch (_) {
        return null;
      }
    }
    final provider = _previewImageProvider();
    if (provider == null) {
      return null;
    }

    try {
      final info = await _resolveImageInfo(provider);
      final width = info.image.width;
      final height = info.image.height;
      info.dispose();
      return '实际尺寸${width}x$height';
    } catch (_) {
      return null;
    }
  }

  Future<String?> _resolveFileSizeLabel() async {
    final record = _currentRecord;
    try {
      final resultImagePath = record.resultImagePath;
      if (resultImagePath != null && File(resultImagePath).existsSync()) {
        return _formatBytes(File(resultImagePath).lengthSync());
      }

      final sourceImagePath = record.sourceImagePath;
      if (sourceImagePath != null && File(sourceImagePath).existsSync()) {
        return _formatBytes(File(sourceImagePath).lengthSync());
      }

      for (final path in record.sourceAttachmentPaths) {
        if (path.isNotEmpty && File(path).existsSync()) {
          return _formatBytes(File(path).lengthSync());
        }
      }

      final b64 = record.resultB64;
      if (b64 != null && b64.isNotEmpty) {
        return _formatBytes(_estimateBase64Bytes(b64));
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  int _estimateBase64Bytes(String b64) {
    final normalized = b64.contains(',') ? b64.split(',').last : b64;
    final padding = normalized.endsWith('==')
        ? 2
        : normalized.endsWith('=')
        ? 1
        : 0;
    return (normalized.length * 3 ~/ 4) - padding;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '--';
    }
    const kb = 1024;
    const mb = kb * 1024;
    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(2)}M';
    }
    final kbValue = bytes / kb;
    return kbValue >= 10
        ? '${kbValue.round()}K'
        : '${kbValue.toStringAsFixed(1)}K';
  }

  ImageProvider? _previewImageProvider([ImageRecord? previewRecord]) {
    final record = previewRecord ?? _currentRecord;
    final resultImagePath = record.resultImagePath;
    if (resultImagePath != null && File(resultImagePath).existsSync()) {
      return FileImage(File(resultImagePath));
    }

    final sourceImagePath = record.sourceImagePath;
    if (sourceImagePath != null && File(sourceImagePath).existsSync()) {
      return FileImage(File(sourceImagePath));
    }

    for (final path in record.sourceAttachmentPaths) {
      if (path.isNotEmpty && File(path).existsSync()) {
        return FileImage(File(path));
      }
    }

    final resultImageUrl = record.resultImageUrl;
    if (resultImageUrl != null && resultImageUrl.isNotEmpty) {
      return CachedNetworkImageProvider(resultImageUrl);
    }

    return null;
  }

  Future<ImageInfo> _resolveImageInfo(ImageProvider provider) {
    final completer = Completer<ImageInfo>();
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (image, synchronousCall) {
        if (!completer.isCompleted) {
          completer.complete(image);
        }
        stream.removeListener(listener);
      },
      onError: (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  Future<void> _saveImage(BuildContext context, WidgetRef ref) async {
    try {
      final extension = _resolvedExtension();
      final record = _currentRecord;
      final savedPath = await ref
          .read(imageSaveServiceProvider)
          .saveImage(
            suggestedFileName: 'mint-image-${record.id}.$extension',
            localPath: record.resultImagePath,
            imageUrl: record.resultImageUrl,
          );

      if (!context.mounted) {
        return;
      }

      if (savedPath == null || savedPath.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已取消保存。')));
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('图片已保存到：$savedPath')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
    }
  }

  String _resolvedExtension() {
    final localPath = _currentRecord.resultImagePath;
    if (localPath != null) {
      final extension = localPath.split('.').last;
      if (extension.isNotEmpty) {
        return extension;
      }
    }
    return _currentRecord.outputFormat;
  }

  bool _isNearBaseline(double scale, double baselineScale) =>
      (scale - baselineScale).abs() <= baselineScale * _scaleSnapTolerance;

  String get _zoomLabel {
    final baselineScale = _baselineScale;
    if (baselineScale == null || baselineScale <= 0 || _currentScale <= 0) {
      return '100%';
    }

    final percent = (_currentScale / baselineScale) * 100;
    return '${percent.clamp(10.0, 9999.0).round()}%';
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppThemeTokens.primaryStrong.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: Colors.white),
      ),
    );
  }
}

class _PreviewPhotoController {
  _PreviewPhotoController()
    : photoViewController = PhotoViewController(),
      scaleStateController = PhotoViewScaleStateController();

  final PhotoViewController photoViewController;
  final PhotoViewScaleStateController scaleStateController;

  void dispose() {
    scaleStateController.dispose();
    photoViewController.dispose();
  }
}

class _PreviewNavigationButton extends StatelessWidget {
  const _PreviewNavigationButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        color: Colors.black.withValues(alpha: 0.62),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: 34),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints.tightFor(width: 58, height: 58),
          splashRadius: 29,
        ),
      ),
    );
  }
}

class _ActualSizePreviewChip extends StatelessWidget {
  const _ActualSizePreviewChip({required this.labelFuture});

  final Future<String?> labelFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: labelFuture,
      builder: (context, snapshot) {
        return _PreviewChip(label: snapshot.data ?? '实际尺寸--');
      },
    );
  }
}

class _FileSizePreviewChip extends StatelessWidget {
  const _FileSizePreviewChip({required this.labelFuture});

  final Future<String?> labelFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: labelFuture,
      builder: (context, snapshot) {
        return _PreviewChip(label: snapshot.data ?? '--');
      },
    );
  }
}

class _ZoomBadge extends StatelessWidget {
  const _ZoomBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.only(top: 12, right: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
