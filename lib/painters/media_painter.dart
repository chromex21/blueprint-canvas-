import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:async';
import '../models/canvas_media.dart';
import '../theme_manager.dart';
import '../core/viewport_controller.dart';

/// MediaPainter: High-performance painter for canvas media (emoji stickers and images)
class MediaPainter extends CustomPainter {
  final List<CanvasMedia> mediaItems;
  final CanvasTheme theme;
  final ViewportController? viewportController;
  final Size canvasSize;

  // Image cache for loaded images
  static final Map<String, ui.Image> _imageCache = {};
  static final Map<String, Future<ui.Image?>> _loadingImages = {};
  
  // Callback to trigger repaint when images load
  VoidCallback? onImageLoaded;

  MediaPainter({
    required this.mediaItems,
    required this.theme,
    this.viewportController,
    required this.canvasSize,
    this.onImageLoaded,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Apply viewport transform if available
    if (viewportController != null) {
      canvas.save();
      canvas.transform(viewportController!.transform.storage);
    }

    for (final media in mediaItems) {
      _paintMedia(canvas, media);
    }

    if (viewportController != null) {
      canvas.restore();
    }
  }

  void _paintMedia(Canvas canvas, CanvasMedia media) {
    canvas.save();

    final rect = Rect.fromLTWH(
      media.position.dx,
      media.position.dy,
      media.size.width,
      media.size.height,
    );

    switch (media.type) {
      case MediaType.emoji:
        _paintEmoji(canvas, rect, media);
        break;
      case MediaType.image:
        _paintImage(canvas, rect, media);
        break;
      case MediaType.svg:
        _paintSvg(canvas, rect, media);
        break;
    }

    // Draw selection outline if selected
    if (media.isSelected) {
      _drawSelectionOutline(canvas, rect);
    }

    canvas.restore();
  }

  void _paintEmoji(Canvas canvas, Rect rect, CanvasMedia media) {
    if (media.emoji == null) return;

    // Draw emoji as text
    final textPainter = TextPainter(
      text: TextSpan(
        text: media.emoji!,
        style: TextStyle(
          fontSize: rect.height * 0.8, // Use 80% of height for emoji size
          fontFamily: 'Noto Color Emoji', // Fallback to system emoji font
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final offset = Offset(
      rect.left + (rect.width - textPainter.width) / 2,
      rect.top + (rect.height - textPainter.height) / 2,
    );
    textPainter.paint(canvas, offset);
  }

  void _paintImage(Canvas canvas, Rect rect, CanvasMedia media) {
    if (media.imageData == null) return;

    final cacheKey = media.id;
    ui.Image? image = _imageCache[cacheKey];

    if (image == null && !_loadingImages.containsKey(cacheKey)) {
      // Start loading image asynchronously (will be drawn on next frame)
      _loadImageAsync(cacheKey, media.imageData!);
      // Draw placeholder while loading
      _drawPlaceholder(canvas, rect);
      return;
    } else if (_loadingImages.containsKey(cacheKey)) {
      // Image is still loading, draw placeholder
      _drawPlaceholder(canvas, rect);
      return;
    }

    if (image != null) {
      // Draw image
      final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      canvas.drawImageRect(
        image,
        srcRect,
        rect,
        Paint()..filterQuality = FilterQuality.high,
      );
    }
  }

  Future<void> _loadImageAsync(String cacheKey, Uint8List imageData) async {
    final completer = Completer<ui.Image?>();
    _loadingImages[cacheKey] = completer.future;

    try {
      final codec = await ui.instantiateImageCodec(imageData);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      _imageCache[cacheKey] = image;
      completer.complete(image);
      // Trigger repaint callback
      onImageLoaded?.call();
    } catch (e) {
      completer.complete(null);
    } finally {
      _loadingImages.remove(cacheKey);
    }
  }

  void _drawPlaceholder(Canvas canvas, Rect rect) {
    // Draw a simple placeholder rectangle
    final paint = Paint()
      ..color = theme.borderColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawRect(rect, paint);
    
    // Draw loading text
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Loading...',
        style: TextStyle(
          color: theme.textColor.withValues(alpha: 0.5),
          fontSize: 12,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - textPainter.width) / 2,
        rect.top + (rect.height - textPainter.height) / 2,
      ),
    );
  }

  void _paintSvg(Canvas canvas, Rect rect, CanvasMedia media) {
    // SVG rendering requires a library like flutter_svg
    // For now, we'll render it as a placeholder or use a simple image decoder
    // TODO: Implement proper SVG rendering with flutter_svg package
    if (media.imageData == null) return;

    // For now, try to render as PNG (many SVGs can be decoded as images)
    // This is a temporary solution until we add flutter_svg
    _paintImage(canvas, rect, media);
  }

  void _drawSelectionOutline(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = theme.accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw selection rectangle with rounded corners
    final selectionRect = rect.inflate(4);
    final rrect = RRect.fromRectAndRadius(selectionRect, const Radius.circular(4));
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(MediaPainter oldDelegate) {
    return oldDelegate.mediaItems != mediaItems ||
           oldDelegate.theme != theme ||
           oldDelegate.viewportController != viewportController;
  }

  /// Clear image cache
  static void clearImageCache() {
    for (final image in _imageCache.values) {
      image.dispose();
    }
    _imageCache.clear();
    _loadingImages.clear();
  }
}

