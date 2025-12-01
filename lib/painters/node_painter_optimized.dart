import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/canvas_node.dart';
import '../theme_manager.dart';

/// OptimizedNodePainter: High-performance node rendering with object pooling
///
/// PERFORMANCE OPTIMIZATIONS:
/// - Text layout caching to avoid recomputation
/// - Paint object pooling (no per-frame allocations)
/// - Path object pooling (no per-frame allocations)
/// - Preallocated Paint objects reused across frames
/// - Optimized rendering paths
/// - Support for viewport transforms
class OptimizedNodePainter extends CustomPainter {
  final List<CanvasNode> nodes;
  final CanvasTheme theme;

  // Text layout cache (key: nodeId+content hash, value: TextPainter)
  static final Map<String, _CachedTextLayout> _textLayoutCache = {};
  static const int _maxCacheSize = 200;

  // Preallocated Paint objects (reused across all nodes)
  late final Paint _shadowPaint;
  late final Paint _bgPaint;
  late final Paint _borderPaint;
  late final Paint _glowPaint;
  late final Paint _fillPaint;
  late final Paint _foldPaint;
  late final Paint _selectionPaint;

  // Preallocated Path objects (reused, reset before use)
  late final Path _reusablePath;

  OptimizedNodePainter({required this.nodes, required this.theme}) {
    // Preallocate all Paint objects (created once, reused forever)
    _shadowPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    _bgPaint = Paint()..style = PaintingStyle.fill;

    _borderPaint = Paint()..style = PaintingStyle.stroke;

    _glowPaint = Paint()..style = PaintingStyle.stroke;

    _fillPaint = Paint()..style = PaintingStyle.fill;

    _foldPaint = Paint()..style = PaintingStyle.fill;

    _selectionPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Preallocate Path object (reused, reset before each use)
    _reusablePath = Path();
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final node in nodes) {
      _paintNode(canvas, node);
    }
  }

  void _paintNode(Canvas canvas, CanvasNode node) {
    canvas.save();

    // Apply rotation if needed
    if (node.rotation != 0) {
      canvas.translate(node.center.dx, node.center.dy);
      canvas.rotate(node.rotation);
      canvas.translate(-node.center.dx, -node.center.dy);
    }

    // Paint based on node type
    switch (node.type) {
      case NodeType.basicNode:
        _paintBasicNode(canvas, node);
        break;
      case NodeType.stickyNote:
        _paintStickyNote(canvas, node);
        break;
      case NodeType.textBlock:
        _paintTextBlock(canvas, node);
        break;
      case NodeType.shapeRect:
        _paintRectangle(canvas, node);
        break;
      case NodeType.shapePill:
        _paintPill(canvas, node);
        break;
      case NodeType.shapeCircle:
        _paintCircle(canvas, node);
        break;
      case NodeType.shapeDiamond:
        _paintDiamond(canvas, node);
        break;
      case NodeType.shapeTriangle:
        _paintTriangle(canvas, node);
        break;
      case NodeType.shapeHexagon:
        _paintHexagon(canvas, node);
        break;
    }

    canvas.restore();
  }

  /// Paint a basic node (mind map bubble)
  void _paintBasicNode(Canvas canvas, CanvasNode node) {
    final rect = Rect.fromLTWH(
      node.position.dx,
      node.position.dy,
      node.size.width,
      node.size.height,
    );

    // Shadow (only if selected) - reuse preallocated Paint
    if (node.isSelected) {
      _shadowPaint.color = theme.accentColor.withValues(alpha: 0.3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(12)),
        _shadowPaint,
      );
    }

    // Background - reuse preallocated Paint
    _bgPaint.color = theme.panelColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      _bgPaint,
    );

    // Border - reuse preallocated Paint
    _borderPaint
      ..color = node.isSelected ? theme.accentColor : node.color
      ..strokeWidth = node.isSelected ? 3 : 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      _borderPaint,
    );

    // Selection glow - reuse preallocated Paint
    if (node.isSelected) {
      _glowPaint
        ..color = theme.accentColor.withValues(alpha: 0.15)
        ..strokeWidth = 6;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(3), const Radius.circular(15)),
        _glowPaint,
      );
    }

    // Text content (with caching)
    _drawTextCached(
      canvas,
      node.id,
      node.content,
      rect,
      theme.textColor,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
  }

  /// Paint a sticky note
  void _paintStickyNote(Canvas canvas, CanvasNode node) {
    final rect = Rect.fromLTWH(
      node.position.dx,
      node.position.dy,
      node.size.width,
      node.size.height,
    );

    // Shadow - reuse preallocated Paint
    _shadowPaint
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRect(rect.shift(const Offset(2, 3)), _shadowPaint);

    // Background with fold corner - reuse preallocated Path
    _reusablePath.reset();
    _reusablePath
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.right - 20, rect.top)
      ..lineTo(rect.right, rect.top + 20)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();

    // Reuse preallocated Paint
    _bgPaint.color = node.color;
    canvas.drawPath(_reusablePath, _bgPaint);

    // Fold corner - reuse preallocated Path
    _reusablePath.reset();
    _reusablePath
      ..moveTo(rect.right - 20, rect.top)
      ..lineTo(rect.right, rect.top + 20)
      ..lineTo(rect.right - 20, rect.top + 20)
      ..close();

    // Reuse preallocated Paint
    _foldPaint.color = node.color.withValues(alpha: 0.7);
    canvas.drawPath(_reusablePath, _foldPaint);

    // Selection border - reuse preallocated Path and Paint
    if (node.isSelected) {
      // Rebuild bgPath for border (or store it)
      _reusablePath.reset();
      _reusablePath
        ..moveTo(rect.left, rect.top)
        ..lineTo(rect.right - 20, rect.top)
        ..lineTo(rect.right, rect.top + 20)
        ..lineTo(rect.right, rect.bottom)
        ..lineTo(rect.left, rect.bottom)
        ..close();

      _borderPaint
        ..color = theme.accentColor
        ..strokeWidth = 3;
      canvas.drawPath(_reusablePath, _borderPaint);
    }

    // Text content with padding (cached)
    final textRect = rect.deflate(12);
    _drawTextCached(
      canvas,
      node.id,
      node.content,
      textRect,
      Colors.black87,
      fontSize: 13,
      maxLines: 6,
    );
  }

  /// Paint a text block (no container)
  void _paintTextBlock(Canvas canvas, CanvasNode node) {
    final rect = Rect.fromLTWH(
      node.position.dx,
      node.position.dy,
      node.size.width,
      node.size.height,
    );

    // Selection outline only - reuse preallocated Paint and Path
    if (node.isSelected) {
      _selectionPaint
        ..color = theme.accentColor.withValues(alpha: 0.3)
        ..strokeWidth = 2;

      _reusablePath.reset();
      _reusablePath.addRect(rect.inflate(4));
      canvas.drawPath(_reusablePath, _selectionPaint);
    }

    // Text content (cached)
    _drawTextCached(
      canvas,
      node.id,
      node.content,
      rect,
      node.color,
      fontSize: 14,
      align: TextAlign.left,
      maxLines: 10,
    );
  }

  /// Paint a rectangle shape (TEXT-EDITABLE per master prompt)
  void _paintRectangle(Canvas canvas, CanvasNode node) {
    final rect = Rect.fromLTWH(
      node.position.dx,
      node.position.dy,
      node.size.width,
      node.size.height,
    );

    // Fill - reuse preallocated Paint
    _fillPaint.color = node.color.withValues(alpha: 0.3);
    canvas.drawRect(rect, _fillPaint);

    // Border - reuse preallocated Paint
    _borderPaint
      ..color = node.isSelected ? theme.accentColor : node.color
      ..strokeWidth = node.isSelected ? 3 : 2;
    canvas.drawRect(rect, _borderPaint);

    // Text content (centered) - only for text-editable shapes
    if (node.content.isNotEmpty) {
      _drawTextCached(
        canvas,
        node.id,
        node.content,
        rect.deflate(8), // Padding
        theme.textColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      );
    }
  }

  /// Paint a pill shape (TEXT-EDITABLE per master prompt)
  void _paintPill(Canvas canvas, CanvasNode node) {
    final rect = Rect.fromLTWH(
      node.position.dx,
      node.position.dy,
      node.size.width,
      node.size.height,
    );

    // Pill shape is an oval/rounded rectangle with circular ends
    final radius = Radius.circular(node.size.height / 2);

    // Fill - reuse preallocated Paint
    _fillPaint.color = node.color.withValues(alpha: 0.3);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), _fillPaint);

    // Border - reuse preallocated Paint
    _borderPaint
      ..color = node.isSelected ? theme.accentColor : node.color
      ..strokeWidth = node.isSelected ? 3 : 2;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), _borderPaint);

    // Text content (centered) - only for text-editable shapes
    if (node.content.isNotEmpty) {
      _drawTextCached(
        canvas,
        node.id,
        node.content,
        rect.deflate(12), // More padding for pill shape
        theme.textColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      );
    }
  }

  /// Paint a circle shape
  void _paintCircle(Canvas canvas, CanvasNode node) {
    final center = node.center;
    final radius = math.min(node.size.width, node.size.height) / 2;

    // Fill - reuse preallocated Paint
    _fillPaint.color = node.color.withValues(alpha: 0.3);
    canvas.drawCircle(center, radius, _fillPaint);

    // Border - reuse preallocated Paint
    _borderPaint
      ..color = node.isSelected ? theme.accentColor : node.color
      ..strokeWidth = node.isSelected ? 3 : 2;
    canvas.drawCircle(center, radius, _borderPaint);
  }

  /// Paint a diamond shape
  void _paintDiamond(Canvas canvas, CanvasNode node) {
    final center = node.center;
    final halfW = node.size.width / 2;
    final halfH = node.size.height / 2;

    // Reuse preallocated Path
    _reusablePath.reset();
    _reusablePath
      ..moveTo(center.dx, center.dy - halfH) // Top
      ..lineTo(center.dx + halfW, center.dy) // Right
      ..lineTo(center.dx, center.dy + halfH) // Bottom
      ..lineTo(center.dx - halfW, center.dy) // Left
      ..close();

    // Fill - reuse preallocated Paint
    _fillPaint.color = node.color.withValues(alpha: 0.3);
    canvas.drawPath(_reusablePath, _fillPaint);

    // Border - reuse preallocated Paint
    _borderPaint
      ..color = node.isSelected ? theme.accentColor : node.color
      ..strokeWidth = node.isSelected ? 3 : 2;
    canvas.drawPath(_reusablePath, _borderPaint);
  }

  /// Paint a triangle shape
  void _paintTriangle(Canvas canvas, CanvasNode node) {
    final center = node.center;
    final height = node.size.height;

    // Reuse preallocated Path
    _reusablePath.reset();
    _reusablePath
      ..moveTo(center.dx, node.position.dy) // Top
      ..lineTo(
        node.position.dx + node.size.width,
        node.position.dy + height,
      ) // Bottom right
      ..lineTo(node.position.dx, node.position.dy + height) // Bottom left
      ..close();

    // Fill - reuse preallocated Paint
    _fillPaint.color = node.color.withValues(alpha: 0.3);
    canvas.drawPath(_reusablePath, _fillPaint);

    // Border - reuse preallocated Paint
    _borderPaint
      ..color = node.isSelected ? theme.accentColor : node.color
      ..strokeWidth = node.isSelected ? 3 : 2;
    canvas.drawPath(_reusablePath, _borderPaint);
  }

  /// Paint a hexagon shape
  void _paintHexagon(Canvas canvas, CanvasNode node) {
    final center = node.center;
    final radius = math.min(node.size.width, node.size.height) / 2;

    // Reuse preallocated Path
    _reusablePath.reset();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        _reusablePath.moveTo(x, y);
      } else {
        _reusablePath.lineTo(x, y);
      }
    }
    _reusablePath.close();

    // Fill - reuse preallocated Paint
    _fillPaint.color = node.color.withValues(alpha: 0.3);
    canvas.drawPath(_reusablePath, _fillPaint);

    // Border - reuse preallocated Paint
    _borderPaint
      ..color = node.isSelected ? theme.accentColor : node.color
      ..strokeWidth = node.isSelected ? 3 : 2;
    canvas.drawPath(_reusablePath, _borderPaint);
  }

  // ============================================================================
  // TEXT RENDERING WITH CACHING
  // ============================================================================

  /// Draw text with layout caching for performance
  void _drawTextCached(
    Canvas canvas,
    String nodeId,
    String text,
    Rect rect,
    Color color, {
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    TextAlign align = TextAlign.center,
    int? maxLines,
  }) {
    if (text.isEmpty) return;

    // Create cache key
    final cacheKey = _createTextCacheKey(
      nodeId,
      text,
      rect,
      fontSize,
      fontWeight,
      align,
      maxLines,
    );

    // Get or create text layout
    _CachedTextLayout? cachedLayout = _textLayoutCache[cacheKey];

    if (cachedLayout == null) {
      // Create new text layout
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
          ),
        ),
        textAlign: align,
        textDirection: TextDirection.ltr,
        maxLines: maxLines,
        ellipsis: maxLines != null ? '...' : null,
      );

      textPainter.layout(minWidth: 0, maxWidth: rect.width);

      // Cache the layout
      cachedLayout = _CachedTextLayout(
        textPainter: textPainter,
        maxWidth: rect.width,
        lastUsed: DateTime.now(),
      );

      // Evict old cache entries if needed
      if (_textLayoutCache.length >= _maxCacheSize) {
        _evictOldestTextCache();
      }

      _textLayoutCache[cacheKey] = cachedLayout;
    } else {
      // OPTIMIZATION: Check if layout needs update (width changed significantly)
      // Since width is now in cache key, this should rarely be needed
      if (cachedLayout.needsUpdate(rect.width)) {
        // Relayout with new width
        cachedLayout.textPainter.layout(minWidth: 0, maxWidth: rect.width);
        cachedLayout.maxWidth = rect.width;
      }
      // Update last used time
      cachedLayout.lastUsed = DateTime.now();
    }

    // Calculate offset for alignment
    final offset = Offset(
      rect.left + (rect.width - cachedLayout.textPainter.width) / 2,
      rect.top + (rect.height - cachedLayout.textPainter.height) / 2,
    );

    // Paint the cached text
    cachedLayout.textPainter.paint(canvas, offset);
  }

  /// Create a cache key for text layout
  /// OPTIMIZATION: Include width in cache key (rounded to avoid minor differences)
  /// This prevents cache invalidation when width changes slightly
  String _createTextCacheKey(
    String nodeId,
    String text,
    Rect rect,
    double fontSize,
    FontWeight fontWeight,
    TextAlign align,
    int? maxLines,
  ) {
    // Use content hash for efficiency
    final contentHash = text.hashCode;
    // Round width to nearest 10 pixels to avoid cache misses from tiny width changes
    final roundedWidth = (rect.width / 10).round() * 10;
    return '${nodeId}_${contentHash}_${roundedWidth}_${fontSize}_${fontWeight.index}_${align.index}_${maxLines ?? -1}';
  }

  /// Evict oldest cache entries
  void _evictOldestTextCache() {
    if (_textLayoutCache.isEmpty) return;

    // Find oldest entry
    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _textLayoutCache.entries) {
      if (oldestTime == null || entry.value.lastUsed.isBefore(oldestTime)) {
        oldestTime = entry.value.lastUsed;
        oldestKey = entry.key;
      }
    }

    // Remove oldest entry
    if (oldestKey != null) {
      _textLayoutCache.remove(oldestKey);
    }
  }

  /// Clear text layout cache (call when nodes change significantly)
  static void clearTextCache() {
    for (final layout in _textLayoutCache.values) {
      layout.textPainter.dispose();
    }
    _textLayoutCache.clear();
  }

  @override
  bool shouldRepaint(OptimizedNodePainter oldDelegate) {
    return oldDelegate.nodes != nodes || oldDelegate.theme != theme;
  }
}

/// Cached text layout data
class _CachedTextLayout {
  final TextPainter textPainter;
  double maxWidth; // Mutable to allow updates
  DateTime lastUsed;

  _CachedTextLayout({
    required this.textPainter,
    required this.maxWidth,
    required this.lastUsed,
  });

  /// Check if layout needs update (width changed significantly)
  /// OPTIMIZATION: Only relayout if width changed by more than 10 pixels
  /// This prevents unnecessary relayouts from tiny width changes
  bool needsUpdate(double newMaxWidth) {
    // Only relayout if width changed significantly (more than 10 pixels)
    return (newMaxWidth - maxWidth).abs() > 10.0;
  }
}
