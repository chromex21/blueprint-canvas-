import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/canvas_node.dart';
import '../models/node_connection.dart';
import '../theme_manager.dart';

/// ConnectionPainter: Custom painter for rendering node connections
class ConnectionPainter extends CustomPainter {
  final List<NodeConnection> connections;
  final List<CanvasNode> nodes;
  final CanvasTheme theme;

  ConnectionPainter({
    required this.connections,
    required this.nodes,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final connection in connections) {
      _paintConnection(canvas, connection);
    }
  }

  void _paintConnection(Canvas canvas, NodeConnection connection) {
    // Find source and target nodes
    final sourceNode = nodes.firstWhere(
      (node) => node.id == connection.sourceNodeId,
      orElse: () => CanvasNode(
        id: '',
        position: Offset.zero,
        size: Size.zero,
        type: NodeType.basicNode,
        color: Colors.transparent,
      ),
    );

    final targetNode = nodes.firstWhere(
      (node) => node.id == connection.targetNodeId,
      orElse: () => CanvasNode(
        id: '',
        position: Offset.zero,
        size: Size.zero,
        type: NodeType.basicNode,
        color: Colors.transparent,
      ),
    );

    // Skip if nodes not found
    if (sourceNode.id.isEmpty || targetNode.id.isEmpty) return;

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
    final paint = Paint()
      ..color = connection.color
      ..strokeWidth = connection.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw line
    canvas.drawLine(start, end, paint);

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
    final paint = Paint()
      ..color = connection.color
      ..strokeWidth = connection.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, end, paint);
  }

  /// Draw a dashed line (for associations)
  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    NodeConnection connection,
  ) {
    final paint = Paint()
      ..color = connection.color
      ..strokeWidth = connection.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const dashWidth = 8.0;
    const dashSpace = 4.0;

    final distance = (end - start).distance;
    final direction = (end - start) / distance;

    double currentDistance = 0;
    while (currentDistance < distance) {
      final dashStart = start + direction * currentDistance;
      final dashEnd = start + direction * math.min(currentDistance + dashWidth, distance);
      canvas.drawLine(dashStart, dashEnd, paint);
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
    final paint = Paint()
      ..color = connection.color
      ..strokeWidth = connection.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Calculate control points for smooth curve
    final midX = (start.dx + end.dx) / 2;
    final controlPoint1 = Offset(midX, start.dy);
    final controlPoint2 = Offset(midX, end.dy);

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        end.dx,
        end.dy,
      );

    canvas.drawPath(path, paint);

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

    final arrowPath = Path()
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

    final arrowPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(ConnectionPainter oldDelegate) {
    return oldDelegate.connections != connections ||
        oldDelegate.nodes != nodes ||
        oldDelegate.theme != theme;
  }
}
