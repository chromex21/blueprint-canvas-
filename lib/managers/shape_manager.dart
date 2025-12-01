import 'package:flutter/material.dart';
import '../models/canvas_shape.dart';

/// ShapeManager: Lightweight manager for canvas shapes
/// 
/// PERFORMANCE OPTIMIZATIONS:
/// - Simple list-based storage (no spatial indexing needed for small-medium canvases)
/// - Minimal state (just shapes list)
/// - Fast lookups by ID
/// - Efficient selection management
class ShapeManager extends ChangeNotifier {
  final List<CanvasShape> _shapes = [];
  final Set<String> _selectedShapeIds = {};

  // Getters
  List<CanvasShape> get shapes => List.unmodifiable(_shapes);
  Set<String> get selectedShapeIds => Set.unmodifiable(_selectedShapeIds);
  List<CanvasShape> get selectedShapes =>
      _shapes.where((shape) => _selectedShapeIds.contains(shape.id)).toList();
  bool get hasSelection => _selectedShapeIds.isNotEmpty;
  int get shapeCount => _shapes.length;

  // ============================================================================
  // SHAPE CRUD OPERATIONS
  // ============================================================================

  /// Add a new shape to the canvas
  void addShape(CanvasShape shape) {
    _shapes.add(shape);
    notifyListeners();
  }

  /// Remove a shape
  void removeShape(String shapeId) {
    _shapes.removeWhere((shape) => shape.id == shapeId);
    _selectedShapeIds.remove(shapeId);
    notifyListeners();
  }

  /// Remove all selected shapes
  void removeSelectedShapes() {
    _shapes.removeWhere((shape) => _selectedShapeIds.contains(shape.id));
    _selectedShapeIds.clear();
    notifyListeners();
  }

  /// Update a shape's properties
  void updateShape(String shapeId, CanvasShape updatedShape) {
    final index = _shapes.indexWhere((shape) => shape.id == shapeId);
    if (index != -1) {
      _shapes[index] = updatedShape;
      notifyListeners();
    }
  }

  /// Get a shape by ID
  CanvasShape? getShape(String shapeId) {
    try {
      return _shapes.firstWhere((shape) => shape.id == shapeId);
    } catch (e) {
      return null;
    }
  }

  /// Find shape at a specific position
  CanvasShape? getShapeAtPosition(Offset position) {
    // Search in reverse order (top to bottom in z-order)
    for (int i = _shapes.length - 1; i >= 0; i--) {
      final shape = _shapes[i];
      if (shape.containsPoint(position)) {
        return shape;
      }
    }
    return null;
  }

  /// Get shapes in a rectangle
  List<CanvasShape> getShapesInRect(Rect rect) {
    return _shapes.where((shape) {
      return rect.overlaps(shape.bounds);
    }).toList();
  }

  // ============================================================================
  // SELECTION OPERATIONS
  // ============================================================================

  /// Select a shape
  void selectShape(String shapeId) {
    _selectedShapeIds.clear();
    _selectedShapeIds.add(shapeId);
    
    // Update shape selection state
    for (final shape in _shapes) {
      if (shape.id == shapeId) {
        updateShape(shapeId, shape.copyWith(isSelected: true));
      } else if (shape.isSelected) {
        updateShape(shape.id, shape.copyWith(isSelected: false));
      }
    }
  }

  /// Select multiple shapes
  void selectMultiple(List<String> shapeIds) {
    _selectedShapeIds.clear();
    _selectedShapeIds.addAll(shapeIds);
    
    // Update shape selection state
    for (final shape in _shapes) {
      final shouldBeSelected = shapeIds.contains(shape.id);
      if (shape.isSelected != shouldBeSelected) {
        updateShape(shape.id, shape.copyWith(isSelected: shouldBeSelected));
      }
    }
  }

  /// Clear all selections
  void clearSelection() {
    _selectedShapeIds.clear();
    
    // Update shape selection state
    for (final shape in _shapes) {
      if (shape.isSelected) {
        updateShape(shape.id, shape.copyWith(isSelected: false));
      }
    }
  }

  /// Select shapes within a rectangle
  void selectShapesInRect(Rect selectionRect) {
    final shapesInRect = getShapesInRect(selectionRect);
    selectMultiple(shapesInRect.map((shape) => shape.id).toList());
  }

  // ============================================================================
  // POSITIONING OPERATIONS
  // ============================================================================

  /// Move a shape by a delta offset
  void moveShape(String shapeId, Offset delta) {
    final shape = getShape(shapeId);
    if (shape != null) {
      updateShape(shapeId, shape.copyWith(position: shape.position + delta));
    }
  }

  /// Move all selected shapes by a delta offset
  void moveSelectedShapes(Offset delta) {
    for (final shapeId in _selectedShapeIds) {
      moveShape(shapeId, delta);
    }
  }

  /// Set shape position directly
  void setShapePosition(String shapeId, Offset position) {
    final shape = getShape(shapeId);
    if (shape != null) {
      updateShape(shapeId, shape.copyWith(position: position));
    }
  }

  /// Resize a shape
  void resizeShape(String shapeId, Size newSize) {
    final shape = getShape(shapeId);
    if (shape != null) {
      updateShape(shapeId, shape.copyWith(size: newSize));
    }
  }

  // ============================================================================
  // CONTENT OPERATIONS
  // ============================================================================

  /// Update shape text
  void updateShapeText(String shapeId, String text) {
    final shape = getShape(shapeId);
    if (shape != null) {
      updateShape(shapeId, shape.copyWith(text: text));
    }
  }

  /// Update shape color
  void updateShapeColor(String shapeId, Color color) {
    final shape = getShape(shapeId);
    if (shape != null) {
      updateShape(shapeId, shape.copyWith(color: color));
    }
  }

  /// Update shape notes
  void updateShapeNotes(String shapeId, String notes) {
    final shape = getShape(shapeId);
    if (shape != null) {
      updateShape(shapeId, shape.copyWith(notes: notes));
    }
  }

  /// Update shape border visibility
  void updateShapeBorder(String shapeId, bool showBorder) {
    final shape = getShape(shapeId);
    if (shape != null) {
      updateShape(shapeId, shape.copyWith(showBorder: showBorder));
    }
  }

  /// Bring shape to front (z-order)
  void bringToFront(String shapeId) {
    final shape = getShape(shapeId);
    if (shape != null) {
      _shapes.removeWhere((s) => s.id == shapeId);
      _shapes.add(shape);
      notifyListeners();
    }
  }

  /// Send shape to back (z-order)
  void sendToBack(String shapeId) {
    final shape = getShape(shapeId);
    if (shape != null) {
      _shapes.removeWhere((s) => s.id == shapeId);
      _shapes.insert(0, shape);
      notifyListeners();
    }
  }

  /// Clear all shapes
  void clearCanvas() {
    _shapes.clear();
    _selectedShapeIds.clear();
    notifyListeners();
  }
}

