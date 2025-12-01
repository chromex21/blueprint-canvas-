import 'package:flutter/material.dart';
import 'canvas_node.dart';

/// CanvasElementData: Base class for all lightweight canvas elements
/// 
/// This represents the data model for canvas elements without any widget overhead.
/// All rendering is handled via CustomPainter.
abstract class CanvasElementData {
  final String id;
  Offset position;
  Size size;
  Color color;
  bool isSelected;
  double rotation;
  Map<String, dynamic> metadata;

  CanvasElementData({
    required this.id,
    required this.position,
    required this.size,
    required this.color,
    this.isSelected = false,
    this.rotation = 0.0,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};

  /// Get the center point of this element
  Offset get center => Offset(
        position.dx + size.width / 2,
        position.dy + size.height / 2,
      );

  /// Get the bounding rectangle
  Rect get bounds => Rect.fromLTWH(
        position.dx,
        position.dy,
        size.width,
        size.height,
      ).inflate(rotation != 0 ? 10 : 0); // Add padding for rotated elements

  /// Check if a point is inside this element's bounds
  bool containsPoint(Offset point) {
    final rect = Rect.fromLTWH(
      position.dx,
      position.dy,
      size.width,
      size.height,
    );
    return rect.contains(point);
  }

  /// Create a copy with modified properties
  CanvasElementData copyWith({
    Offset? position,
    Size? size,
    Color? color,
    bool? isSelected,
    double? rotation,
    Map<String, dynamic>? metadata,
  });
}

/// NodeData: Lightweight data representation for canvas nodes
/// Extends CanvasElementData to maintain compatibility
class NodeData extends CanvasElementData {
  final NodeType type;
  String content;

  NodeData({
    required super.id,
    required super.position,
    required super.size,
    required super.color,
    required this.type,
    this.content = '',
    super.isSelected,
    super.rotation,
    super.metadata,
  });

  @override
  NodeData copyWith({
    Offset? position,
    Size? size,
    Color? color,
    bool? isSelected,
    double? rotation,
    Map<String, dynamic>? metadata,
    NodeType? type,
    String? content,
  }) {
    return NodeData(
      id: id,
      position: position ?? this.position,
      size: size ?? this.size,
      color: color ?? this.color,
      type: type ?? this.type,
      content: content ?? this.content,
      isSelected: isSelected ?? this.isSelected,
      rotation: rotation ?? this.rotation,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert from CanvasNode for backward compatibility
  factory NodeData.fromCanvasNode(CanvasNode node) {
    return NodeData(
      id: node.id,
      position: node.position,
      size: node.size,
      color: node.color,
      type: node.type,
      content: node.content,
      isSelected: node.isSelected,
      rotation: node.rotation,
      metadata: Map<String, dynamic>.from(node.metadata),
    );
  }

  /// Convert to CanvasNode for backward compatibility
  CanvasNode toCanvasNode() {
    return CanvasNode(
      id: id,
      position: position,
      size: size,
      type: type,
      content: content,
      color: color,
      isSelected: isSelected,
      rotation: rotation,
      metadata: Map<String, dynamic>.from(metadata),
    );
  }
}

/// ToolData: Lightweight data representation for canvas tools
class ToolData extends CanvasElementData {
  final ToolType toolType;
  Map<String, dynamic> properties;

  ToolData({
    required super.id,
    required super.position,
    required super.size,
    required super.color,
    required this.toolType,
    this.properties = const {},
    super.isSelected,
    super.rotation,
    super.metadata,
  });

  @override
  ToolData copyWith({
    Offset? position,
    Size? size,
    Color? color,
    bool? isSelected,
    double? rotation,
    Map<String, dynamic>? metadata,
    ToolType? toolType,
    Map<String, dynamic>? properties,
  }) {
    return ToolData(
      id: id,
      position: position ?? this.position,
      size: size ?? this.size,
      color: color ?? this.color,
      toolType: toolType ?? this.toolType,
      properties: properties ?? this.properties,
      isSelected: isSelected ?? this.isSelected,
      rotation: rotation ?? this.rotation,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// ToolType: Types of tools that can be placed on canvas
enum ToolType {
  annotation,
  marker,
  measurement,
  custom,
}

// NodeType and CanvasNode are imported from canvas_node.dart
// They are already available in the same package

