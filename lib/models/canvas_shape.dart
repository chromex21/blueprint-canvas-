import 'package:flutter/material.dart';

/// ShapeType: Types of shapes that can be created on the canvas
enum ShapeType {
  rectangle,
  roundedRectangle,
  circle,
  ellipse,
  diamond,
  triangle,
  pill,
  polygon,
}

/// CanvasShape: Lightweight shape model for high-performance rendering
/// 
/// Only stores essential data: id, position, size, color, optional text
/// No connections, metadata, or complex state - optimized for speed
class CanvasShape {
  final String id;
  Offset position;
  Size size;
  ShapeType type;
  Color color;
  String text; // Optional inline text
  String notes; // Optional notes/annotations
  bool isSelected;
  double cornerRadius; // For rounded rectangle
  bool showBorder; // Whether to show border/highlight
  int zIndex; // Z-order for layering (higher = on top)

  CanvasShape({
    required this.id,
    required this.position,
    required this.size,
    required this.type,
    required this.color,
    this.text = '',
    this.notes = '',
    this.isSelected = false,
    this.cornerRadius = 8.0, // Default for rounded rectangle
    this.showBorder = true, // Default to showing border
    int? zIndex,
  }) : zIndex = zIndex ?? _generateZIndex();

  /// Create a copy with modified properties
  CanvasShape copyWith({
    Offset? position,
    Size? size,
    ShapeType? type,
    Color? color,
    String? text,
    String? notes,
    bool? isSelected,
    double? cornerRadius,
    bool? showBorder,
    int? zIndex,
  }) {
    return CanvasShape(
      id: id,
      position: position ?? this.position,
      size: size ?? this.size,
      type: type ?? this.type,
      color: color ?? this.color,
      text: text ?? this.text,
      notes: notes ?? this.notes,
      isSelected: isSelected ?? this.isSelected,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      showBorder: showBorder ?? this.showBorder,
      zIndex: zIndex ?? this.zIndex,
    );
  }

  /// Check if a point is inside this shape's bounds
  bool containsPoint(Offset point) {
    final rect = Rect.fromLTWH(
      position.dx,
      position.dy,
      size.width,
      size.height,
    );
    
    // For now, use simple rectangular bounds
    // Can be enhanced for circle/ellipse/etc. later
    return rect.contains(point);
  }

  /// Get the center point of this shape
  Offset get center => Offset(
        position.dx + size.width / 2,
        position.dy + size.height / 2,
      );

  /// Get the bounding rectangle of this shape
  Rect get bounds => Rect.fromLTWH(
        position.dx,
        position.dy,
        size.width,
        size.height,
      );

  /// Check if this shape type supports text editing (per master prompt)
  /// Only Rectangle, RoundedRectangle, and Pill are text-editable
  bool get isTextEditable {
    return type == ShapeType.rectangle ||
           type == ShapeType.roundedRectangle ||
           type == ShapeType.pill;
  }

  /// Factory constructors for different shape types
  
  /// Create a rectangle shape
  static CanvasShape createRectangle(Offset position, Color color) {
    return CanvasShape(
      id: _generateId(),
      position: position,
      size: const Size(120, 120),
      type: ShapeType.rectangle,
      color: color,
    );
  }

  /// Create a rounded rectangle shape
  static CanvasShape createRoundedRectangle(Offset position, Color color, {double cornerRadius = 12.0}) {
    return CanvasShape(
      id: _generateId(),
      position: position,
      size: const Size(120, 120),
      type: ShapeType.roundedRectangle,
      color: color,
      cornerRadius: cornerRadius,
    );
  }

  /// Create a circle shape
  static CanvasShape createCircle(Offset position, Color color) {
    return CanvasShape(
      id: _generateId(),
      position: position,
      size: const Size(120, 120),
      type: ShapeType.circle,
      color: color,
    );
  }

  /// Create an ellipse shape
  static CanvasShape createEllipse(Offset position, Color color) {
    return CanvasShape(
      id: _generateId(),
      position: position,
      size: const Size(150, 100),
      type: ShapeType.ellipse,
      color: color,
    );
  }

  /// Create a diamond shape
  static CanvasShape createDiamond(Offset position, Color color) {
    return CanvasShape(
      id: _generateId(),
      position: position,
      size: const Size(120, 120),
      type: ShapeType.diamond,
      color: color,
    );
  }

  /// Create a triangle shape
  static CanvasShape createTriangle(Offset position, Color color) {
    return CanvasShape(
      id: _generateId(),
      position: position,
      size: const Size(120, 120),
      type: ShapeType.triangle,
      color: color,
    );
  }

  /// Create a pill/oval shape
  static CanvasShape createPill(Offset position, Color color) {
    return CanvasShape(
      id: _generateId(),
      position: position,
      size: const Size(150, 80),
      type: ShapeType.pill,
      color: color,
    );
  }

  /// Create a polygon shape (hexagon by default)
  static CanvasShape createPolygon(Offset position, Color color) {
    return CanvasShape(
      id: _generateId(),
      position: position,
      size: const Size(120, 120),
      type: ShapeType.polygon,
      color: color,
    );
  }

  /// Generate unique ID
  static String _generateId() {
    return 'shape_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
  }

  /// Generate unique z-index (shared across shapes and media)
  static int _generateZIndex() {
    return globalZIndexCounter++;
  }

  static int _counter = 0;
  static int globalZIndexCounter = 0; // Shared z-index counter for unified layering (public for CanvasMedia access)
}

