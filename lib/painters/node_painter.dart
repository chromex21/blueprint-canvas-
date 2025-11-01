import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/canvas_node.dart';
import '../theme_manager.dart';

/// NodePainter: Custom painter for rendering canvas nodes
class NodePainter extends CustomPainter {
  final List<CanvasNode> nodes;
  final CanvasTheme theme;

  NodePainter({
    required this.nodes,
    required this.theme,
  });

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

    // Shadow
    if (node.isSelected) {
      final shadowPaint = Paint()
        ..color = theme.accentColor.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(12)),
        shadowPaint,
      );
    }

    // Background
    final bgPaint = Paint()
      ..color = theme.panelColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      bgPaint,
    );

    // Border
    final borderPaint = Paint()
      ..color = node.isSelected ? theme.accentColor : node.color
      ..strokeWidth = node.isSelected ? 3 : 2
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      borderPaint,
    );

    // Selection glow
    if (node.isSelected) {
      final glowPaint = Paint()
        ..color = theme.accentColor.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.inflate(3),
          const Radius.circular(15),
        ),
        glowPaint,
      );
    }

    // Text content
    _drawText(
      canvas,
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

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRect(rect.shift(const Offset(2, 3)), shadowPaint);

    // Background with fold corner
    final bgPath = Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.right - 20, rect.top)
      ..lineTo(rect.right, rect.top + 20)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();

    final bgPaint = Paint()
      ..color = node.color
      ..style = PaintingStyle.fill;
    canvas.drawPath(bgPath, bgPaint);

    // Fold corner
    final foldPath = Path()
      ..moveTo(rect.right - 20, rect.top)
      ..lineTo(rect.right, rect.top + 20)
      ..lineTo(rect.right - 20, rect.top + 20)
      ..close();

    final foldPaint = Paint()
      ..color = node.color.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    canvas.drawPath(foldPath, foldPaint);

    // Selection border
    if (node.isSelected) {
      final borderPaint = Paint()
        ..color = theme.accentColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      canvas.drawPath(bgPath, borderPaint);
    }

    // Text content with padding
    final textRect = rect.deflate(12);
    _drawText(
      canvas,
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

    // Selection outline only
    if (node.isSelected) {
      final selectionPaint = Paint()
        ..color = theme.accentColor.withOpacity(0.3)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path()
        ..addRect(rect.inflate(4));
      canvas.drawPath(path, selectionPaint);
    }

    // Text content
    _drawText(
      canvas,
      node.content,
      rect,
      node.color,
      fontSize: 14,
      align: TextAlign.left,
      maxLines: 10,
    );
  }

  /// Paint a rectangle shape
  void _paintRectangle(Canvas canvas, CanvasNode node) {
    final rect = Rect.fromLTWH(
      node.position.dx,
      node.position.dy,
      node.size.width,
      node.size.height,
    );

    // Fill
    final fillPaint = Paint()
      ..color = node.color.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = node.isSelected ? theme.accentColor : node.color
      ..strokeWidth = node.isSelected ? 3 : 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(rect, borderPaint);
  }

  /// Paint a circle shape
  void _paintCircle(Canvas canvas, CanvasNode node) {
    final center = node.center;
    final radius = math.min(node.size.width, node.size.height) / 2;

    // Fill
    final fillPaint = Paint()
      ..color = node.color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = node.isSelected ? theme.accentColor : node.color
      ..strokeWidth = node.isSelected ? 3 : 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, borderPaint);
  }

  /// Paint a diamond shape
  void _paintDiamond(Canvas canvas, CanvasNode node) {
    final center = node.center;
    final halfW = node.size.width / 2;
    final halfH = node.size.height / 2;

    final path = Path()
      ..moveTo(center.dx, center.dy - halfH) // Top
      ..lineTo(center.dx + halfW, center.dy) // Right
      ..lineTo(center.dx, center.dy + halfH) // Bottom
      ..lineTo(center.dx - halfW, center.dy) // Left
      ..close();

    // Fill
    final fillPaint = Paint()
      ..color = node.color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = node.isSelected ? theme.accentColor : node.color
      ..strokeWidth = node.isSelected ? 3 : 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, borderPaint);
  }

  /// Paint a triangle shape
  void _paintTriangle(Canvas canvas, CanvasNode node) {
    final center = node.center;
    final halfW = node.size.width / 2;
    final height = node.size.height;

    final path = Path()
      ..moveTo(center.dx, node.position.dy) // Top
      ..lineTo(node.position.dx + node.size.width, node.position.dy + height) // Bottom right
      ..lineTo(node.position.dx, node.position.dy + height) // Bottom left
      ..close();

    // Fill
    final fillPaint = Paint()
      ..color = node.color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = node.isSelected ? theme.accentColor : node.color
      ..strokeWidth = node.isSelected ? 3 : 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, borderPaint);
  }

  /// Paint a hexagon shape
  void _paintHexagon(Canvas canvas, CanvasNode node) {
    final center = node.center;
    final radius = math.min(node.size.width, node.size.height) / 2;

    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Fill
    final fillPaint = Paint()
      ..color = node.color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = node.isSelected ? theme.accentColor : node.color
      ..strokeWidth = node.isSelected ? 3 : 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, borderPaint);
  }

  /// Helper: Draw text centered in a rectangle
  void _drawText(
    Canvas canvas,
    String text,
    Rect rect,
    Color color, {
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    TextAlign align = TextAlign.center,
    int? maxLines,
  }) {
    if (text.isEmpty) return;

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

    textPainter.layout(
      minWidth: 0,
      maxWidth: rect.width,
    );

    final offset = Offset(
      rect.left + (rect.width - textPainter.width) / 2,
      rect.top + (rect.height - textPainter.height) / 2,
    );

    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(NodePainter oldDelegate) {
    return oldDelegate.nodes != nodes || oldDelegate.theme != theme;
  }
}
