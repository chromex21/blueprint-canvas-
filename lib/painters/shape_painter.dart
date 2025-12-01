import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/canvas_shape.dart';
import '../theme_manager.dart';

/// ShapePainter: High-performance painter for canvas shapes
///
/// PERFORMANCE OPTIMIZATIONS:
/// - Preallocated Paint objects (no per-frame allocations)
/// - Reusable Path objects (reset before each use)
/// - Efficient shape rendering
/// - Text layout caching
class ShapePainter extends CustomPainter {
  final List<CanvasShape> shapes;
  final CanvasTheme theme;

  // Preallocated Paint objects (reused across all shapes)
  late final Paint _fillPaint;
  late final Paint _strokePaint;
  late final Paint _selectionPaint;
  // _textPaint removed (unused). Text rendering uses TextPainter and cache.

  // Reusable Path object (reset before each use)
  late final Path _reusablePath;

  // Text layout cache
  static final Map<String, _CachedTextLayout> _textLayoutCache = {};
  static const int _maxCacheSize = 100;

  ShapePainter({required this.shapes, required this.theme}) {
    // Preallocate Paint objects
    _fillPaint = Paint()..style = PaintingStyle.fill;

    _strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    _selectionPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Preallocate Path object
    _reusablePath = Path();
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final shape in shapes) {
      _paintShape(canvas, shape);
    }
  }

  void _paintShape(Canvas canvas, CanvasShape shape) {
    canvas.save();

    final rect = Rect.fromLTWH(
      shape.position.dx,
      shape.position.dy,
      shape.size.width,
      shape.size.height,
    );

    // Draw shape based on type
    switch (shape.type) {
      case ShapeType.rectangle:
        _paintRectangle(canvas, rect, shape);
        break;
      case ShapeType.roundedRectangle:
        _paintRoundedRectangle(canvas, rect, shape);
        break;
      case ShapeType.circle:
        _paintCircle(canvas, rect, shape);
        break;
      case ShapeType.ellipse:
        _paintEllipse(canvas, rect, shape);
        break;
      case ShapeType.diamond:
        _paintDiamond(canvas, rect, shape);
        break;
      case ShapeType.triangle:
        _paintTriangle(canvas, rect, shape);
        break;
      case ShapeType.pill:
        _paintPill(canvas, rect, shape);
        break;
      case ShapeType.polygon:
        _paintPolygon(canvas, rect, shape);
        break;
    }

    // Draw border/highlight
    if (shape.showBorder) {
      if (shape.isSelected) {
        // Blue accent border when selected
        _drawSelectionOutline(canvas, rect);
      } else {
        // Faint border on import
        _drawFaintBorder(canvas, rect, shape);
      }
    }

    // Draw text if present
    if (shape.text.isNotEmpty) {
      _drawText(canvas, shape, rect);
    }

    // Draw note indicator if notes are present
    if (shape.notes.isNotEmpty) {
      _drawNoteIndicator(canvas, rect, shape);
    }

    canvas.restore();
  }

  void _paintRectangle(Canvas canvas, Rect rect, CanvasShape shape) {
    _fillPaint.color = shape.color.withValues(alpha: 0.3);
    _strokePaint.color = shape.color;

    canvas.drawRect(rect, _fillPaint);
    canvas.drawRect(rect, _strokePaint);
  }

  void _paintRoundedRectangle(Canvas canvas, Rect rect, CanvasShape shape) {
    _fillPaint.color = shape.color.withValues(alpha: 0.3);
    _strokePaint.color = shape.color;

    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(shape.cornerRadius),
    );
    canvas.drawRRect(rrect, _fillPaint);
    canvas.drawRRect(rrect, _strokePaint);
  }

  void _paintCircle(Canvas canvas, Rect rect, CanvasShape shape) {
    final center = rect.center;
    final radius = math.min(rect.width, rect.height) / 2;

    _fillPaint.color = shape.color.withValues(alpha: 0.3);
    _strokePaint.color = shape.color;

    canvas.drawCircle(center, radius, _fillPaint);
    canvas.drawCircle(center, radius, _strokePaint);
  }

  void _paintEllipse(Canvas canvas, Rect rect, CanvasShape shape) {
    _fillPaint.color = shape.color.withValues(alpha: 0.3);
    _strokePaint.color = shape.color;

    canvas.drawOval(rect, _fillPaint);
    canvas.drawOval(rect, _strokePaint);
  }

  void _paintDiamond(Canvas canvas, Rect rect, CanvasShape shape) {
    final center = rect.center;
    // halfW/halfH not needed; using rect edges directly

    _reusablePath.reset();
    _reusablePath
      ..moveTo(center.dx, rect.top)
      ..lineTo(rect.right, center.dy)
      ..lineTo(center.dx, rect.bottom)
      ..lineTo(rect.left, center.dy)
      ..close();

    _fillPaint.color = shape.color.withValues(alpha: 0.3);
    _strokePaint.color = shape.color;

    canvas.drawPath(_reusablePath, _fillPaint);
    canvas.drawPath(_reusablePath, _strokePaint);
  }

  void _paintTriangle(Canvas canvas, Rect rect, CanvasShape shape) {
    _reusablePath.reset();
    _reusablePath
      ..moveTo(rect.center.dx, rect.top)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();

    _fillPaint.color = shape.color.withValues(alpha: 0.3);
    _strokePaint.color = shape.color;

    canvas.drawPath(_reusablePath, _fillPaint);
    canvas.drawPath(_reusablePath, _strokePaint);
  }

  void _paintPill(Canvas canvas, Rect rect, CanvasShape shape) {
    final radius = math.min(rect.width, rect.height) / 2;

    _fillPaint.color = shape.color.withValues(alpha: 0.3);
    _strokePaint.color = shape.color;

    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(rrect, _fillPaint);
    canvas.drawRRect(rrect, _strokePaint);
  }

  void _paintPolygon(Canvas canvas, Rect rect, CanvasShape shape) {
    final center = rect.center;
    final radius = math.min(rect.width, rect.height) / 2;
    const sides = 6; // Hexagon

    _reusablePath.reset();
    for (int i = 0; i < sides; i++) {
      final angle = (math.pi * 2 / sides) * i - math.pi / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        _reusablePath.moveTo(x, y);
      } else {
        _reusablePath.lineTo(x, y);
      }
    }
    _reusablePath.close();

    _fillPaint.color = shape.color.withValues(alpha: 0.3);
    _strokePaint.color = shape.color;

    canvas.drawPath(_reusablePath, _fillPaint);
    canvas.drawPath(_reusablePath, _strokePaint);
  }

  void _drawSelectionOutline(Canvas canvas, Rect rect) {
    _selectionPaint.color = theme.accentColor;

    // Draw selection rectangle with rounded corners
    final selectionRect = rect.inflate(4);
    final rrect = RRect.fromRectAndRadius(
      selectionRect,
      const Radius.circular(4),
    );
    canvas.drawRRect(rrect, _selectionPaint);
  }

  void _drawFaintBorder(Canvas canvas, Rect rect, CanvasShape shape) {
    final faintPaint = Paint()
      ..color = theme.borderColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw faint border with rounded corners for rounded shapes
    if (shape.type == ShapeType.roundedRectangle ||
        shape.type == ShapeType.pill) {
      final rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(shape.cornerRadius),
      );
      canvas.drawRRect(rrect, faintPaint);
    } else {
      canvas.drawRect(rect, faintPaint);
    }
  }

  void _drawText(Canvas canvas, CanvasShape shape, Rect rect) {
    // ✅ MASTER PROMPT: Only draw text on text-editable shapes
    if (shape.text.isEmpty || !shape.isTextEditable) return;

    final cacheKey = '${shape.id}_${shape.text}_${rect.width}_${rect.height}';
    var cachedLayout = _textLayoutCache[cacheKey];

    if (cachedLayout == null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: shape.text,
          style: TextStyle(
            color: theme.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(minWidth: 0, maxWidth: rect.width);

      cachedLayout = _CachedTextLayout(textPainter: textPainter);

      if (_textLayoutCache.length >= _maxCacheSize) {
        _evictOldestTextCache();
      }
      _textLayoutCache[cacheKey] = cachedLayout;
    }

    final offset = Offset(
      rect.left + (rect.width - cachedLayout.textPainter.width) / 2,
      rect.top + (rect.height - cachedLayout.textPainter.height) / 2,
    );
    cachedLayout.textPainter.paint(canvas, offset);
  }

  void _drawNoteIndicator(Canvas canvas, Rect rect, CanvasShape shape) {
    // Draw a small note badge in the top-right corner
    const badgeSize = 16.0;
    const badgePadding = 4.0;
    final badgePosition = Offset(
      rect.right - badgeSize - badgePadding,
      rect.top + badgePadding,
    );

    // Draw badge background (small circle)
    final badgePaint = Paint()
      ..color = theme.accentColor.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      badgePosition + Offset(badgeSize / 2, badgeSize / 2),
      badgeSize / 2,
      badgePaint,
    );

    // Draw badge border (white outline for contrast)
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(
      badgePosition + Offset(badgeSize / 2, badgeSize / 2),
      badgeSize / 2 - 0.75,
      borderPaint,
    );

    // Draw note icon (simple text "N" or comment icon)
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'N',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      badgePosition +
          Offset(
            (badgeSize - textPainter.width) / 2,
            (badgeSize - textPainter.height) / 2,
          ),
    );
    textPainter.dispose();
  }

  void _evictOldestTextCache() {
    if (_textLayoutCache.isEmpty) return;
    _textLayoutCache.remove(_textLayoutCache.keys.first);
  }

  @override
  bool shouldRepaint(ShapePainter oldDelegate) {
    return oldDelegate.shapes != shapes || oldDelegate.theme != theme;
  }

  /// Clear text layout cache
  static void clearTextCache() {
    for (final layout in _textLayoutCache.values) {
      layout.textPainter.dispose();
    }
    _textLayoutCache.clear();
  }
}

/// Cached text layout data
class _CachedTextLayout {
  final TextPainter textPainter;

  _CachedTextLayout({required this.textPainter});
}
