import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../../core/models/image_record.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/theme.dart';

class ImagePreviewPage extends ConsumerStatefulWidget {
  const ImagePreviewPage({super.key, required this.record});

  final ImageRecord record;

  @override
  ConsumerState<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends ConsumerState<ImagePreviewPage> {
  static const double _minScaleFactor = 0.8;
  static const double _maxScaleFactor = 4.0;
  static const double _wheelZoomStep = 1.12;
  static const double _scaleSnapTolerance = 0.015;

  late final PhotoViewController _photoViewController;
  late final PhotoViewScaleStateController _scaleStateController;
  late Future<String?> _actualSizeLabelFuture;
  StreamSubscription<PhotoViewControllerValue>? _controllerSubscription;

  double? _baselineScale;
  double _currentScale = 1.0;

  bool get _supportsPointerScrollZoom => Platform.isWindows || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    _photoViewController = PhotoViewController();
    _scaleStateController = PhotoViewScaleStateController();
    _actualSizeLabelFuture = _resolveActualSizeLabel();
    _controllerSubscription = _photoViewController.outputStateStream.listen(
      _handleControllerValue,
    );
  }

  @override
  void didUpdateWidget(covariant ImagePreviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record != widget.record) {
      _actualSizeLabelFuture = _resolveActualSizeLabel();
    }
  }

  @override
  void dispose() {
    _controllerSubscription?.cancel();
    _scaleStateController.dispose();
    _photoViewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
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
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PreviewChip(label: record.sizeLabel),
                        _ActualSizePreviewChip(
                          labelFuture: _actualSizeLabelFuture,
                        ),
                        _PreviewChip(label: record.qualityLabel),
                        _PreviewChip(label: record.model),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 84),
                      child: SingleChildScrollView(
                        child: Text(
                          record.prompt,
                          style: const TextStyle(
                            color: Colors.white,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
    final record = widget.record;

    if (record.resultImagePath != null &&
        File(record.resultImagePath!).existsSync()) {
      return _buildPhotoView(FileImage(File(record.resultImagePath!)));
    }

    if (record.sourceImagePath != null &&
        File(record.sourceImagePath!).existsSync()) {
      return _buildPhotoView(FileImage(File(record.sourceImagePath!)));
    }

    if (record.resultImageUrl != null) {
      return CachedNetworkImage(
        imageUrl: record.resultImageUrl!,
        imageBuilder: (context, provider) => _buildPhotoView(provider),
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        errorWidget: (context, url, error) => const Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.white70),
        ),
      );
    }

    return const Center(
      child: Icon(Icons.broken_image_rounded, color: Colors.white70),
    );
  }

  Widget _buildPhotoView(ImageProvider provider) {
    final photoView = PhotoView(
      heroAttributes: PhotoViewHeroAttributes(tag: 'image-${widget.record.id}'),
      controller: _photoViewController,
      scaleStateController: _scaleStateController,
      imageProvider: provider,
      minScale: PhotoViewComputedScale.contained * _minScaleFactor,
      maxScale: PhotoViewComputedScale.contained * _maxScaleFactor,
      initialScale: PhotoViewComputedScale.contained,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
    );

    if (!_supportsPointerScrollZoom) {
      return photoView;
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerSignal: _handlePointerSignal,
      child: photoView,
    );
  }

  Future<String?> _resolveActualSizeLabel() async {
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

  ImageProvider? _previewImageProvider() {
    final record = widget.record;

    final resultImagePath = record.resultImagePath;
    if (resultImagePath != null && File(resultImagePath).existsSync()) {
      return FileImage(File(resultImagePath));
    }

    final sourceImagePath = record.sourceImagePath;
    if (sourceImagePath != null && File(sourceImagePath).existsSync()) {
      return FileImage(File(sourceImagePath));
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
      final savedPath = await ref
          .read(imageSaveServiceProvider)
          .saveImage(
            suggestedFileName: 'mint-image-${widget.record.id}.$extension',
            localPath: widget.record.resultImagePath,
            imageUrl: widget.record.resultImageUrl,
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
    final localPath = widget.record.resultImagePath;
    if (localPath != null) {
      final extension = localPath.split('.').last;
      if (extension.isNotEmpty) {
        return extension;
      }
    }
    return 'png';
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
