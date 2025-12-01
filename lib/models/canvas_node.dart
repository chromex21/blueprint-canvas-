import 'package:flutter/material.dart';
import 'dart:math' as math;

/// NodeType: Different types of nodes users can create
/// 
/// TEXT-EDITABLE SHAPES (per master prompt):
/// - basicNode (RoundedRectangle)
/// - shapeRect (Rectangle) 
/// - shapePill (Pill)
enum NodeType {
  basicNode,      // Mind map bubble / RoundedRectangle (TEXT-EDITABLE)
  stickyNote,     // Post-it style note
  textBlock,      // Free-form text (📝 tool)
  shapeRect,      // Rectangle (TEXT-EDITABLE)
  shapePill,      // Pill/Oval shape (TEXT-EDITABLE)
  shapeCircle,    // Circle (NOT text-editable)
  shapeDiamond,   // Diamond (NOT text-editable)
  shapeTriangle,  // Triangle (NOT text-editable)
  shapeHexagon,   // Hexagon (NOT text-editable)
}

/// CanvasNode: Represents a single node on the canvas
class CanvasNode {
  final String id;
  Offset position;
  Size size;
  NodeType type;
  String content;
  Color color;
  bool isSelected;
  double rotation;
  List<String> connectedTo; // IDs of nodes this connects to
  Map<String, dynamic> metadata;

  CanvasNode({
    required this.id,
    required this.position,
    required this.size,
    required this.type,
    this.content = '',
    required this.color,
    this.isSelected = false,
    this.rotation = 0.0,
    List<String>? connectedTo,
    Map<String, dynamic>? metadata,
  })  : connectedTo = connectedTo ?? [],
        metadata = metadata ?? {};

  /// Create a copy with modified properties
  CanvasNode copyWith({
    Offset? position,
    Size? size,
    NodeType? type,
    String? content,
    Color? color,
    bool? isSelected,
    double? rotation,
    List<String>? connectedTo,
    Map<String, dynamic>? metadata,
  }) {
    return CanvasNode(
      id: id,
      position: position ?? this.position,
      size: size ?? this.size,
      type: type ?? this.type,
      content: content ?? this.content,
      color: color ?? this.color,
      isSelected: isSelected ?? this.isSelected,
      rotation: rotation ?? this.rotation,
      connectedTo: connectedTo ?? this.connectedTo,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Check if a point is inside this node's bounds
  bool containsPoint(Offset point) {
    final rect = Rect.fromLTWH(
      position.dx,
      position.dy,
      size.width,
      size.height,
    );
    return rect.contains(point);
  }

  /// Get the center point of this node
  Offset get center => Offset(
        position.dx + size.width / 2,
        position.dy + size.height / 2,
      );

  /// Factory constructors for different node types
  
  /// Create a basic node (mind map bubble)
  static CanvasNode createBasicNode(Offset position, Color color) {
    return CanvasNode(
      id: _generateId(),
      position: position,
      size: const Size(140, 80),
      type: NodeType.basicNode,
      content: 'Node',
      color: color,
    );
  }

  /// Create a sticky note
  static CanvasNode createStickyNote(Offset position, Color color) {
    return CanvasNode(
      id: _generateId(),
      position: position,
      size: const Size(150, 150),
      type: NodeType.stickyNote,
      content: 'Note',
      color: color,
      rotation: -2.0 * math.pi / 180, // Slight rotation (-2 degrees)
    );
  }

  /// Create a text block
  static CanvasNode createTextBlock(Offset position, Color textColor) {
    return CanvasNode(
      id: _generateId(),
      position: position,
      size: const Size(200, 60),
      type: NodeType.textBlock,
      content: 'Text',
      color: textColor,
    );
  }

  /// Create a shape node
  static CanvasNode createShape(
    Offset position,
    NodeType shapeType,
    Color color,
  ) {
    assert(shapeType == NodeType.shapeRect ||
        shapeType == NodeType.shapePill ||
        shapeType == NodeType.shapeCircle ||
        shapeType == NodeType.shapeDiamond ||
        shapeType == NodeType.shapeTriangle ||
        shapeType == NodeType.shapeHexagon);

    // Pill shape has different dimensions
    final size = shapeType == NodeType.shapePill 
        ? const Size(150, 80) 
        : const Size(120, 120);

    return CanvasNode(
      id: _generateId(),
      position: position,
      size: size,
      type: shapeType,
      content: '',
      color: color,
    );
  }

  /// Check if this node type supports text editing (per master prompt)
  /// Only Rectangle, RoundedRectangle (basicNode), and Pill are text-editable
  bool get isTextEditable {
    return type == NodeType.basicNode ||  // RoundedRectangle
           type == NodeType.shapeRect ||  // Rectangle
           type == NodeType.shapePill;    // Pill
  }

  /// Generate unique ID
  static String _generateId() {
    return 'node_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(9999)}';
  }

  /// Sticky note color palette
  static const List<Color> stickyNotePalette = [
    Color(0xFFFFF59D), // Yellow
    Color(0xFFFFCC80), // Orange
    Color(0xFFEF9A9A), // Red
    Color(0xFFCE93D8), // Purple
    Color(0xFF90CAF9), // Blue
    Color(0xFF80CBC4), // Teal
    Color(0xFFA5D6A7), // Green
    Color(0xFFFFAB91), // Deep Orange
  ];

  /// Get random sticky note color
  static Color getRandomStickyColor() {
    return stickyNotePalette[math.Random().nextInt(stickyNotePalette.length)];
  }
}
