import 'package:flutter/material.dart';

/// NodeConnection: Represents a connection between two nodes
class NodeConnection {
  final String id;
  final String sourceNodeId;
  final String targetNodeId;
  final ConnectionType type;
  final Color color;
  final double strokeWidth;

  NodeConnection({
    required this.id,
    required this.sourceNodeId,
    required this.targetNodeId,
    this.type = ConnectionType.arrow,
    required this.color,
    this.strokeWidth = 2.0,
  });

  /// Create a copy with modified properties
  NodeConnection copyWith({
    String? sourceNodeId,
    String? targetNodeId,
    ConnectionType? type,
    Color? color,
    double? strokeWidth,
  }) {
    return NodeConnection(
      id: id,
      sourceNodeId: sourceNodeId ?? this.sourceNodeId,
      targetNodeId: targetNodeId ?? this.targetNodeId,
      type: type ?? this.type,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
    );
  }

  /// Generate unique ID
  static String generateId(String sourceId, String targetId) {
    return 'conn_${sourceId}_to_$targetId';
  }
}

/// ConnectionType: Visual style of the connection
enum ConnectionType {
  arrow,        // Straight line with arrow
  line,         // Straight line, no arrow
  dashed,       // Dashed line (association)
  curve,        // Bezier curve with arrow (future)
}
