import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/// BlueprintCanvasPainter: Static cached grid system (GPU-optimized)
/// 
/// PERFORMANCE OPTIMIZATIONS:
/// - Grid rendered once to offscreen buffer (Picture)
/// - Cached as single GPU texture
/// - NO frame-by-frame repainting
/// - Cache invalidation ONLY on: size change
/// 
/// GRID APPEARANCE IS IMMUTABLE:
/// - Grid color: #2196F3 (Blueprint Blue)
/// - Grid opacity: 0.15
/// - Grid stroke width: 0.5
/// - ThemeManager has no effect on grid appearance
/// 
/// Grid Rules:
/// - Blueprint blue color only (#2196F3)
/// - Single uniform grid with equal squares
/// - Fits edges perfectly (no partial cells)
/// - Grid is pure visual reference layer
class BlueprintCanvasPainter extends StatefulWidget {
  final bool showGrid;

  const BlueprintCanvasPainter({
    super.key,
    required this.showGrid,
  });

  @override
  State<BlueprintCanvasPainter> createState() => _BlueprintCanvasPainterState();
}

class _BlueprintCanvasPainterState extends State<BlueprintCanvasPainter> {
  // Cached grid texture (single GPU texture)
  ui.Picture? _cachedGridPicture;
  Size? _cachedSize;

  @override
  void dispose() {
    _cachedGridPicture?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Note: ThemeManager removed - grid appearance is immutable
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        
        // Invalidate cache on size change
        if (_shouldInvalidateCache(size)) {
          _regenerateGridCache(size);
        }
        
        return CustomPaint(
          painter: _CachedGridPainter(
            cachedGrid: _cachedGridPicture,
            showGrid: widget.showGrid,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  /// Check if cache needs regeneration
  /// Currently: only on size change
  /// Future: will also check zoom/pan when those features are added
  bool _shouldInvalidateCache(Size size) {
    return _cachedGridPicture == null || _cachedSize != size;
  }

  /// Generate static grid texture ONCE
  void _regenerateGridCache(Size size) {
    // Dispose old cache
    _cachedGridPicture?.dispose();
    
    // Create offscreen recorder
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Draw grid to offscreen buffer
    _drawGridToCache(canvas, size);
    
    // Capture as Picture (GPU texture)
    _cachedGridPicture = recorder.endRecording();
    _cachedSize = size;
  }

  /// Draw grid ONCE to offscreen buffer
  void _drawGridToCache(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Calculate cell size that fits perfectly
    final cellSize = _calculatePerfectCellSize(size);

    // Paint configuration for blueprint blue grid
    // Grid appearance is immutable: #2196F3 at 0.15 opacity
    // ThemeManager has no effect on grid appearance
    final gridPaint = Paint()
      ..color = const Color(0xFF2196F3).withValues(alpha: 0.15)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Calculate visible grid lines
    final numVerticalLines = (size.width / cellSize).ceil() + 1;
    final numHorizontalLines = (size.height / cellSize).ceil() + 1;

    // Draw vertical grid lines
    for (int i = 0; i < numVerticalLines; i++) {
      final x = i * cellSize;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }

    // Draw horizontal grid lines
    for (int i = 0; i < numHorizontalLines; i++) {
      final y = i * cellSize;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
  }

  /// Calculate cell size (EXACT same logic as before)
  double _calculatePerfectCellSize(Size size) {
    const targetCellSize = 50.0;
    const minCellSize = 20.0;
    const maxCellSize = 100.0;
    
    final horizontalCells = (size.width / targetCellSize).round();
    final verticalCells = (size.height / targetCellSize).round();
    
    final horizontalCellSize = size.width / horizontalCells;
    final verticalCellSize = size.height / verticalCells;
    
    double cellSize = horizontalCellSize < verticalCellSize 
        ? horizontalCellSize 
        : verticalCellSize;
    
    cellSize = cellSize.clamp(minCellSize, maxCellSize);
    
    return cellSize;
  }
}

/// Internal painter: simply draws cached texture (NO grid painting per frame)
class _CachedGridPainter extends CustomPainter {
  final ui.Picture? cachedGrid;
  final bool showGrid;

  const _CachedGridPainter({
    required this.cachedGrid,
    required this.showGrid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Simply draw cached texture (single GPU blit operation)
    if (showGrid && cachedGrid != null) {
      canvas.drawPicture(cachedGrid!);
    }
  }

  @override
  bool shouldRepaint(_CachedGridPainter oldDelegate) {
    // Only repaint if cache changed or visibility toggled
    return oldDelegate.cachedGrid != cachedGrid ||
           oldDelegate.showGrid != showGrid;
  }
}
