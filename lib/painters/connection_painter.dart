import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/canvas_node.dart';
import '../models/node_connection.dart';
import '../theme_manager.dart';

/// ConnectionPainter: Optimized painter for rendering node connections
/// 
/// PERFORMANCE OPTIMIZATIONS:
/// - O(1) node lookup using Map instead of O(n) firstWhere
/// - Paint object pooling to avoid allocations
/// - Path object reuse for arrowheads and curves
/// - Complexity: O(M) where M = number of connections
class ConnectionPainter extends CustomPainter {
  final List<NodeConnection> connections;
  final Map<String, CanvasNode> nodeMap; // O(1) lookup instead of O(n) firstWhere
  final CanvasTheme theme;

  // Reusable Paint objects (created once, reused)
  late final Paint _linePaint;
  late final Paint _arrowPaint;
  late final Path _arrowPath;
  late final Path _curvePath;

  ConnectionPainter({
    required this.connections,
    required Map<String, CanvasNode> nodeMap,
    required this.theme,
  }) : nodeMap = Map<String, CanvasNode>.unmodifiable(nodeMap) {
    // Preallocate Paint objects
    _linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    _arrowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    // Preallocate Path objects
    _arrowPath = Path();
    _curvePath = Path();
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final connection in connections) {
      _paintConnection(canvas, connection);
    }
  }

  void _paintConnection(Canvas canvas, NodeConnection connection) {
    // O(1) lookup instead of O(n) firstWhere
    final sourceNode = nodeMap[connection.sourceNodeId];
    final targetNode = nodeMap[connection.targetNodeId];

    // Skip if nodes not found
    if (sourceNode == null || targetNode == null) return;

    // Calculate connection points (center of nodes)
    final startPoint = sourceNode.center;
    final endPoint = targetNode.center;

    // Draw based on connection type
    switch (connection.type) {
      case ConnectionType.arrow:
        _drawArrowLine(canvas, startPoint, endPoint, connection);
        break;
      case ConnectionType.line:
        _drawStraightLine(canvas, startPoint, endPoint, connection);
        break;
      case ConnectionType.dashed:
        _drawDashedLine(canvas, startPoint, endPoint, connection);
        break;
      case ConnectionType.curve:
        _drawCurvedLine(canvas, startPoint, endPoint, connection);
        break;
    }
  }

  /// Draw a straight line with arrow
  void _drawArrowLine(
    Canvas canvas,
    Offset start,
    Offset end,
    NodeConnection connection,
  ) {
    // Reuse preallocated Paint object
    _linePaint
      ..color = connection.color
      ..strokeWidth = connection.strokeWidth;

    // Draw line
    canvas.drawLine(start, end, _linePaint);

    // Draw arrowhead
    _drawArrowhead(canvas, start, end, connection.color, connection.strokeWidth);
  }

  /// Draw a straight line without arrow
  void _drawStraightLine(
    Canvas canvas,
    Offset start,
    Offset end,
    NodeConnection connection,
  ) {
    // Reuse preallocated Paint object
    _linePaint
      ..color = connection.color
      ..strokeWidth = connection.strokeWidth;

    canvas.drawLine(start, end, _linePaint);
  }

  /// Draw a dashed line (for associations)
  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    NodeConnection connection,
  ) {
    // Reuse preallocated Paint object
    _linePaint
      ..color = connection.color
      ..strokeWidth = connection.strokeWidth;

    const dashWidth = 8.0;
    const dashSpace = 4.0;

    final distance = (end - start).distance;
    final direction = (end - start) / distance;

    double currentDistance = 0;
    while (currentDistance < distance) {
      final dashStart = start + direction * currentDistance;
      final dashEnd = start + direction * math.min(currentDistance + dashWidth, distance);
      canvas.drawLine(dashStart, dashEnd, _linePaint);
      currentDistance += dashWidth + dashSpace;
    }
  }

  /// Draw a curved line (Bezier curve) with arrow
  void _drawCurvedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    NodeConnection connection,
  ) {
    // Reuse preallocated Paint object
    _linePaint
      ..color = connection.color
      ..strokeWidth = connection.strokeWidth;

    // Calculate control points for smooth curve
    final midX = (start.dx + end.dx) / 2;
    final controlPoint1 = Offset(midX, start.dy);
    final controlPoint2 = Offset(midX, end.dy);

    // Reuse preallocated Path object
    _curvePath.reset();
    _curvePath
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        end.dx,
        end.dy,
      );

    canvas.drawPath(_curvePath, _linePaint);

    // Draw arrowhead at end
    _drawArrowhead(canvas, start, end, connection.color, connection.strokeWidth);
  }

  /// Draw an arrowhead at the end point
  void _drawArrowhead(
    Canvas canvas,
    Offset start,
    Offset end,
    Color color,
    double strokeWidth,
  ) {
    const arrowSize = 10.0;
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);

    // Reuse preallocated Path object
    _arrowPath.reset();
    _arrowPath
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - arrowSize * math.cos(angle - math.pi / 6),
        end.dy - arrowSize * math.sin(angle - math.pi / 6),
      )
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - arrowSize * math.cos(angle + math.pi / 6),
        end.dy - arrowSize * math.sin(angle + math.pi / 6),
      );

    // Reuse preallocated Paint object
    _arrowPaint
      ..color = color
      ..strokeWidth = strokeWidth;

    canvas.drawPath(_arrowPath, _arrowPaint);
  }

  @override
  bool shouldRepaint(ConnectionPainter oldDelegate) {
    return oldDelegate.connections != connections ||
        oldDelegate.nodeMap != nodeMap ||
        oldDelegate.theme != theme;
  }
}
