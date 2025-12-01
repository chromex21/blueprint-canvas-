import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../core/viewport_controller.dart';

/// OptimizedGridPainter: Viewport-aware grid with zoom/pan support
///
/// PERFORMANCE OPTIMIZATIONS:
/// - Grid cached as GPU texture
/// - Cache invalidated only on zoom/pan changes or size changes
/// - Viewport-aware rendering
/// - Smooth performance during zoom/pan operations
///
/// GRID APPEARANCE IS IMMUTABLE:
/// - Grid color: #2196F3 (Blueprint Blue)
/// - Grid opacity: 0.15
/// - Grid stroke width: 0.5
/// - ThemeManager has no effect on grid appearance
class OptimizedGridPainter extends StatefulWidget {
  final bool showGrid;
  final ViewportController? viewportController;
  final double gridSpacing;

  const OptimizedGridPainter({
    super.key,
    required this.showGrid,
    this.viewportController,
    this.gridSpacing = 50.0,
  });

  @override
  State<OptimizedGridPainter> createState() => _OptimizedGridPainterState();
}

class _OptimizedGridPainterState extends State<OptimizedGridPainter> {
  // Cached grid texture (single GPU texture)
  // OPTIMIZATION: Cache grid in world space, apply viewport transform at render time
  ui.Picture? _cachedGridPicture;
  Size? _cachedSize;
  double? _cachedGridSpacing;
  double? _cachedScale;

  // Cache bounds (larger than viewport to reduce regeneration)
  static const double _cacheMargin = 500.0; // Extra margin around viewport
  Rect? _cachedBounds;

  @override
  void dispose() {
    _cachedGridPicture?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Note: ThemeManager removed - grid appearance is immutable
    // Only listen to viewport changes if viewport controller exists
    if (widget.viewportController != null) {
      return AnimatedBuilder(
        animation: widget.viewportController!,
        builder: (context, _) {
          return _buildGrid();
        },
      );
    } else {
      return _buildGrid();
    }
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        // Check if cache needs regeneration
        if (_shouldInvalidateCache(size)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _regenerateGridCache(size);
            }
          });
        }

        return RepaintBoundary(
          child: CustomPaint(
            painter: _CachedGridPainterOptimized(
              cachedGrid: _cachedGridPicture,
              showGrid: widget.showGrid,
              viewportController: widget.viewportController,
              gridSpacing: _cachedGridSpacing ?? widget.gridSpacing,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }

  /// Check if cache needs regeneration
  /// OPTIMIZATION: Only regenerate when:
  /// - Cache doesn't exist
  /// - Size changed
  /// - Grid spacing changed
  /// - Viewport moved outside cached bounds (with margin)
  bool _shouldInvalidateCache(Size size) {
    if (_cachedGridPicture == null ||
        _cachedSize != size ||
        _cachedGridSpacing != widget.gridSpacing ||
        _cachedScale != widget.viewportController?.scale) {
      return true;
    }

    // Check if viewport is still within cached bounds
    final viewport = widget.viewportController;
    if (viewport != null && _cachedBounds != null) {
      final visibleBounds = viewport.getViewportBounds(size);

      // Only regenerate if viewport moved outside cached bounds (with margin)
      // Check if visible bounds are fully contained within cached bounds
      if (!_cachedBounds!.contains(visibleBounds.topLeft) ||
          !_cachedBounds!.contains(visibleBounds.bottomRight)) {
        return true;
      }
    }

    return false;
  }

  /// Generate static grid texture in world space
  /// OPTIMIZATION: Cache grid in world space with margin, apply viewport transform at render time
  void _regenerateGridCache(Size size) {
    // Dispose old cache
    _cachedGridPicture?.dispose();

    final viewport = widget.viewportController;

    // Calculate cache bounds (viewport + margin to reduce regeneration)
    Rect cacheBounds;
    if (viewport != null) {
      final visibleBounds = viewport.getViewportBounds(size);
      cacheBounds = visibleBounds.inflate(_cacheMargin);
    } else {
      // No viewport: cache entire canvas
      cacheBounds = Rect.fromLTWH(0, 0, size.width, size.height);
    }

    // Create offscreen recorder
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Determine world-space spacing that keeps a readable spacing in screen pixels
    final double scale = viewport?.scale ?? 1.0;
    final double effectiveGridSpacing = _computeWorldGridSpacing(
      widget.gridSpacing,
      scale,
    );

    // Draw grid to offscreen buffer in world space (no viewport transform)
    final sw = Stopwatch()..start();
    _drawGridToCache(canvas, cacheBounds, effectiveGridSpacing);
    sw.stop();

    // Capture as Picture (GPU texture)
    _cachedGridPicture = recorder.endRecording();
    _cachedSize = size;
    _cachedGridSpacing = effectiveGridSpacing;
    _cachedScale = scale;
    _cachedBounds = cacheBounds;

    debugPrint('Grid cache regenerated: bounds=$cacheBounds size=$size spacing=$effectiveGridSpacing scale=$scale took=${sw.elapsedMilliseconds}ms');

    // Trigger repaint
    if (mounted) {
      setState(() {});
    }
  }

  /// Draw grid to cache in world space
  /// OPTIMIZATION: Draw grid in world coordinates, viewport transform applied at render time
  void _drawGridToCache(Canvas canvas, Rect bounds, double spacing) {
    if (bounds.width <= 0 || bounds.height <= 0) return;

    // Paint configuration for blueprint blue grid
    // Grid appearance is immutable: #2196F3 at 0.15 opacity
    // ThemeManager has no effect on grid appearance
    // Note: Stroke width is in world space (will be scaled by viewport at render time)
    final gridPaint = Paint()
      ..color = const Color(0xFF2196F3).withValues(alpha: 0.15)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Calculate grid line positions in world space
    final startX = (bounds.left / spacing).floor() * spacing;
    final startY = (bounds.top / spacing).floor() * spacing;
    final endX = (bounds.right / spacing).ceil() * spacing;
    final endY = (bounds.bottom / spacing).ceil() * spacing;

    // Draw vertical grid lines (in world space)
    for (double x = startX; x <= endX; x += spacing) {
      canvas.drawLine(
        Offset(x, bounds.top),
        Offset(x, bounds.bottom),
        gridPaint,
      );
    }

    // Draw horizontal grid lines (in world space)
    for (double y = startY; y <= endY; y += spacing) {
      canvas.drawLine(
        Offset(bounds.left, y),
        Offset(bounds.right, y),
        gridPaint,
      );
    }
  }

  /// Compute a world-space grid spacing that keeps the grid spacing in
  /// screen pixels within a readable range. This prevents lines becoming
  /// too dense or too sparse when zooming.
  double _computeWorldGridSpacing(double baseSpacing, double scale) {
    const double minScreenSpacing = 40.0; // px
    const double maxScreenSpacing = 200.0; // px

    double spacing = baseSpacing;
    double screen = spacing * scale;

    // If grid appears too tight on screen, increase world spacing (double)
    while (screen < minScreenSpacing) {
      spacing *= 2.0;
      screen = spacing * scale;
      // Prevent runaway loop
      if (spacing > baseSpacing * 1024) break;
    }

    // If grid appears too sparse on screen, decrease world spacing (half)
    while (screen > maxScreenSpacing && spacing > 1.0) {
      spacing /= 2.0;
      screen = spacing * scale;
    }

    return spacing;
  }
}

/// Internal painter: draws cached texture with viewport transform
class _CachedGridPainterOptimized extends CustomPainter {
  final ui.Picture? cachedGrid;
  final bool showGrid;
  final ViewportController? viewportController;
  final double gridSpacing;

  static int _frameCounter = 0;

  const _CachedGridPainterOptimized({
    required this.cachedGrid,
    required this.showGrid,
    this.viewportController,
    required this.gridSpacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!showGrid || cachedGrid == null) return;

    // OPTIMIZATION: Apply viewport transform to cached world-space grid
    // This allows us to cache the grid once and reuse it across viewport changes
    if (viewportController != null) {
      canvas.save();
      canvas.transform(viewportController!.transform.storage);
    }

    // Draw cached texture (single GPU blit operation)
    // Grid is cached in world space, viewport transform applied above
    // Sample draw timing every 60 frames to avoid spamming logs
    _frameCounter = (_frameCounter + 1) & 0x7fffffff;
    if (_frameCounter % 60 == 0) {
      final sw = Stopwatch()..start();
      canvas.drawPicture(cachedGrid!);
      sw.stop();
      debugPrint('Grid draw (sampled): ${sw.elapsedMicroseconds}µs at size=$size');
    } else {
      canvas.drawPicture(cachedGrid!);
    }

    // Restore canvas
    if (viewportController != null) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CachedGridPainterOptimized oldDelegate) {
    return oldDelegate.cachedGrid != cachedGrid ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.viewportController != viewportController ||
        oldDelegate.gridSpacing != gridSpacing;
  }
}

/// Alternative: Simple grid painter for static grids (no viewport)
class SimpleGridPainter extends CustomPainter {
  final bool showGrid;
  final double gridSpacing;
  final Color gridColor;
  final double gridOpacity;

  const SimpleGridPainter({
    required this.showGrid,
    this.gridSpacing = 50.0,
    this.gridColor = const Color(0xFF2196F3),
    this.gridOpacity = 0.15,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!showGrid) return;

    // Paint configuration
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: gridOpacity)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Calculate number of grid lines
    final numVerticalLines = (size.width / gridSpacing).ceil() + 1;
    final numHorizontalLines = (size.height / gridSpacing).ceil() + 1;

    // Draw vertical grid lines
    for (int i = 0; i < numVerticalLines; i++) {
      final x = i * gridSpacing;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Draw horizontal grid lines
    for (int i = 0; i < numHorizontalLines; i++) {
      final y = i * gridSpacing;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(SimpleGridPainter oldDelegate) {
    return oldDelegate.showGrid != showGrid ||
        oldDelegate.gridSpacing != gridSpacing ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.gridOpacity != gridOpacity;
  }
}
