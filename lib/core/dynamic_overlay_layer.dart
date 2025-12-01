import 'package:flutter/material.dart';
import '../models/canvas_shape.dart';
import '../managers/shape_manager.dart';
import '../painters/shape_painter.dart';
import '../theme_manager.dart';
import '../quick_actions_toolbar.dart';

/// DynamicOverlayLayer: Renders ONLY interactive elements
///
/// ARCHITECTURE:
/// - Lightweight shape objects (no node logic)
/// - Dirty rect clipping during drag
/// - Optional text labels inside shapes
/// - Frame-by-frame updates only for moving/editing elements
///
/// KEY OPTIMIZATIONS:
/// - No full-canvas repaints on mouse move
/// - Dirty rect region invalidation during drag
/// - Viewport culling (optional, for large canvases)
/// - Paint object pooling
class DynamicOverlayLayer extends StatefulWidget {
  final ThemeManager themeManager;
  final ShapeManager shapeManager; // New: lightweight shape manager
  final CanvasTool activeTool;
  final bool snapToGrid;
  final double gridSpacing;
  final ShapeType? selectedShapeType;
  final VoidCallback? onShapePlaced;

  const DynamicOverlayLayer({
    super.key,
    required this.themeManager,
    required this.shapeManager,
    required this.activeTool,
    this.snapToGrid = false,
    this.gridSpacing = 50.0,
    this.selectedShapeType,
    this.onShapePlaced,
  });

  @override
  State<DynamicOverlayLayer> createState() => _DynamicOverlayLayerState();
}

class _DynamicOverlayLayerState extends State<DynamicOverlayLayer> {
  // Gesture state
  // ignore: unused_field
  Offset? _dragStart;
  String? _draggedShapeId;
  Offset? _currentPointer;

  // Multi-select state
  Offset? _selectBoxStart;
  Offset? _selectBoxEnd;

  // Canvas size
  Size _canvasSize = Size.zero;

  // Dirty rect tracking
  // ignore: unused_field
  Rect? _previousDirtyRect;
  final Map<String, Rect> _previousShapeRects = {};

  // Text editing state
  String? _editingShapeId;
  TextEditingController? _textController;
  FocusNode? _textFocusNode;

  @override
  void dispose() {
    _textController?.dispose();
    _textFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.themeManager, widget.shapeManager]),
      builder: (context, _) {
        final theme = widget.themeManager.currentTheme;

        return GestureDetector(
          onTapDown: _handleTapDown,
          onDoubleTap: _handleDoubleTap,
          onPanStart: _handlePanStart,
          onPanUpdate: _handlePanUpdate,
          onPanEnd: _handlePanEnd,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Update canvas size
              final newSize = constraints.biggest;
              if (_canvasSize != newSize) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _canvasSize = newSize;
                    });
                  }
                });
              }

              return Stack(
                children: [
                  // Main overlay canvas
                  MouseRegion(
                    onHover: _handleHover,
                    child: CustomPaint(
                      painter: _DynamicOverlayPainter(
                        theme: theme,
                        shapeManager: widget.shapeManager,
                        currentPointer: _currentPointer,
                        selectBoxStart: _selectBoxStart,
                        selectBoxEnd: _selectBoxEnd,
                        dirtyRect: _computeDirtyRect(),
                      ),
                      size: Size.infinite,
                    ),
                  ),

                  // Text editing overlay (when editing shape text)
                  if (_editingShapeId != null) _buildTextEditingOverlay(),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ============================================================================
  // DIRTY RECT OPTIMIZATION
  // ============================================================================

  Rect? _computeDirtyRect() {
    if (_draggedShapeId == null) {
      _previousDirtyRect = null;
      _previousShapeRects.clear();
      return null; // No dragging - full repaint needed
    }

    final draggingShapes =
        widget.shapeManager.selectedShapeIds.contains(_draggedShapeId)
        ? widget.shapeManager.selectedShapeIds.toList()
        : [_draggedShapeId!];

    Rect? dirtyRect;

    for (final shapeId in draggingShapes) {
      final shape = widget.shapeManager.getShape(shapeId);
      if (shape == null) continue;

      // Current shape rect (with padding for selection effects)
      final currentRect = Rect.fromLTWH(
        shape.position.dx,
        shape.position.dy,
        shape.size.width,
        shape.size.height,
      ).inflate(20);

      // Get previous rect
      final prevRect = _previousShapeRects[shapeId];

      if (prevRect != null) {
        // Union of old and new positions
        dirtyRect = dirtyRect == null
            ? currentRect.expandToInclude(prevRect)
            : dirtyRect.expandToInclude(currentRect.expandToInclude(prevRect));
      } else {
        // First drag frame
        dirtyRect = dirtyRect == null
            ? currentRect
            : dirtyRect.expandToInclude(currentRect);
      }

      _previousShapeRects[shapeId] = currentRect;
    }

    _previousDirtyRect = dirtyRect;
    return dirtyRect;
  }

  // ============================================================================
  // GESTURE HANDLERS
  // ============================================================================

  void _handleHover(PointerEvent event) {
    final newPointer = event.localPosition;

    // Only update pointer without setState (performance)
    if (_currentPointer != newPointer) {
      _currentPointer = newPointer;
    }
  }

  void _handleTapDown(TapDownDetails details) {
    // If text editor is open and user clicks outside, close it
    if (_editingShapeId != null) {
      final shape = widget.shapeManager.getShape(_editingShapeId!);
      if (shape != null) {
        final shapeRect = Rect.fromLTWH(
          shape.position.dx,
          shape.position.dy,
          shape.size.width,
          shape.size.height,
        );
        // If click is outside the editing shape, close editor
        if (!shapeRect.contains(details.localPosition)) {
          _stopTextEditing(saveText: true);
          return; // Don't process the tap further
        }
      }
    }

    final position = details.localPosition;

    switch (widget.activeTool) {
      case CanvasTool.select:
        _handleSelectTap(position);
        break;
      case CanvasTool.editor:
        // Editor tool: single tap to start editing text-editable shapes
        final shape = widget.shapeManager.getShapeAtPosition(position);
        if (shape != null && shape.isTextEditable) {
          _startTextEditing(shape.id);
        }
        break;
      case CanvasTool.shapes:
        _handleShapeCreation(position);
        break;
      case CanvasTool.eraser:
        _handleEraserTap(position);
        break;
      default:
        break;
    }
  }

  void _handleDoubleTap() {
    // Text editing only works when editor tool is active
    if (_currentPointer == null || widget.activeTool != CanvasTool.editor) {
      return;
    }

    final shape = widget.shapeManager.getShapeAtPosition(_currentPointer!);
    if (shape != null && shape.isTextEditable) {
      _startTextEditing(shape.id);
    }
  }

  void _handlePanStart(DragStartDetails details) {
    final position = details.localPosition;

    if (widget.activeTool == CanvasTool.select) {
      _handleSelectPanStart(position);
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final position = details.localPosition;
    final delta = details.delta;

    if (widget.activeTool == CanvasTool.select) {
      _handleSelectPanUpdate(position, delta);
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (widget.activeTool == CanvasTool.select) {
      _handleSelectPanEnd();
    }
  }

  // ============================================================================
  // SELECT TOOL LOGIC
  // ============================================================================

  void _handleSelectTap(Offset position) {
    final shape = widget.shapeManager.getShapeAtPosition(position);

    if (shape != null) {
      widget.shapeManager.selectShape(shape.id);
    } else {
      widget.shapeManager.clearSelection();
    }
  }

  void _handleSelectPanStart(Offset position) {
    final shape = widget.shapeManager.getShapeAtPosition(position);

    if (shape != null) {
      setState(() {
        _draggedShapeId = shape.id;
        _dragStart = position;
        _previousShapeRects.clear();
      });
      widget.shapeManager.selectShape(shape.id);
    } else {
      setState(() {
        _selectBoxStart = position;
        _selectBoxEnd = position;
      });
    }
  }

  void _handleSelectPanUpdate(Offset position, Offset delta) {
    if (_draggedShapeId != null) {
      // Drag shape(s)
      final snappedDelta = widget.snapToGrid ? _snapToGrid(delta) : delta;

      if (widget.shapeManager.selectedShapeIds.contains(_draggedShapeId)) {
        _moveSelectedShapesConstrained(snappedDelta);
      } else {
        _moveSingleShapeConstrained(_draggedShapeId!, snappedDelta);
      }
    } else if (_selectBoxStart != null) {
      setState(() {
        _selectBoxEnd = position;
      });
    }
  }

  void _handleSelectPanEnd() {
    if (_selectBoxStart != null && _selectBoxEnd != null) {
      final rect = Rect.fromPoints(_selectBoxStart!, _selectBoxEnd!);
      widget.shapeManager.selectShapesInRect(rect);
    }

    setState(() {
      _draggedShapeId = null;
      _dragStart = null;
      _selectBoxStart = null;
      _selectBoxEnd = null;
      _previousShapeRects.clear();
    });
  }

  // ============================================================================
  // SHAPE CREATION LOGIC
  // ============================================================================

  void _handleShapeCreation(Offset position) {
    if (widget.selectedShapeType == null) return;

    final snappedPosition = widget.snapToGrid
        ? _snapPositionToGrid(position)
        : position;

    final constrainedPosition = _constrainToBounds(
      snappedPosition,
      const Size(120, 120),
    );

    final theme = widget.themeManager.currentTheme;
    late final CanvasShape shape;
    switch (widget.selectedShapeType!) {
      case ShapeType.rectangle:
        shape = CanvasShape.createRectangle(
          constrainedPosition,
          theme.accentColor,
        );
        break;
      case ShapeType.roundedRectangle:
        shape = CanvasShape.createRoundedRectangle(
          constrainedPosition,
          theme.accentColor,
        );
        break;
      case ShapeType.pill:
        shape = CanvasShape.createPill(constrainedPosition, theme.accentColor);
        break;
      case ShapeType.circle:
        shape = CanvasShape.createCircle(
          constrainedPosition,
          theme.accentColor,
        );
        break;
      case ShapeType.ellipse:
        shape = CanvasShape.createEllipse(
          constrainedPosition,
          theme.accentColor,
        );
        break;
      case ShapeType.diamond:
        shape = CanvasShape.createDiamond(
          constrainedPosition,
          theme.accentColor,
        );
        break;
      case ShapeType.triangle:
        shape = CanvasShape.createTriangle(
          constrainedPosition,
          theme.accentColor,
        );
        break;
      case ShapeType.polygon:
        shape = CanvasShape.createPolygon(
          constrainedPosition,
          theme.accentColor,
        );
        break;
    }

    widget.shapeManager.addShape(shape);
    widget.onShapePlaced?.call();
  }

  // ============================================================================
  // ERASER LOGIC
  // ============================================================================

  void _handleEraserTap(Offset position) {
    final shape = widget.shapeManager.getShapeAtPosition(position);
    if (shape != null) {
      widget.shapeManager.removeShape(shape.id);
    }
  }

  // ============================================================================
  // TEXT EDITING
  // ============================================================================

  void _startTextEditing(String shapeId) {
    final shape = widget.shapeManager.getShape(shapeId);
    if (shape == null || !shape.isTextEditable) return;

    // Close any existing editor first
    _stopTextEditing(saveText: false);

    _textController = TextEditingController(text: shape.text);
    _textFocusNode = FocusNode();

    setState(() {
      _editingShapeId = shapeId;
    });

    // Auto-focus after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _textFocusNode != null) {
        _textFocusNode!.requestFocus();
      }
    });
  }

  void _stopTextEditing({bool saveText = true}) {
    if (_editingShapeId != null) {
      if (saveText && _textController != null) {
        widget.shapeManager.updateShapeText(
          _editingShapeId!,
          _textController!.text,
        );
      }

      _textController?.dispose();
      _textFocusNode?.dispose();

      setState(() {
        _editingShapeId = null;
        _textController = null;
        _textFocusNode = null;
      });
    }
  }

  Widget _buildTextEditingOverlay() {
    final shape = widget.shapeManager.getShape(_editingShapeId!);
    if (shape == null || !shape.isTextEditable || _textController == null) {
      return const SizedBox.shrink();
    }

    final theme = widget.themeManager.currentTheme;

    return Positioned(
      left: shape.position.dx,
      top: shape.position.dy,
      width: shape.size.width,
      height: shape.size.height,
      child: GestureDetector(
        // Prevent clicks on text editor from propagating to canvas
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _textController,
            focusNode: _textFocusNode,
            textAlign: TextAlign.center,
            maxLines: null,
            maxLength: 100, // ✅ MASTER PROMPT: Enforce max character length
            style: TextStyle(color: theme.textColor, fontSize: 14),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderSide: BorderSide(color: theme.accentColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: theme.accentColor, width: 2),
              ),
              contentPadding: const EdgeInsets.all(8),
              filled: true,
              fillColor: theme.backgroundColor.withValues(alpha: 0.9),
            ),
            // Close editor when Enter is pressed
            onSubmitted: (value) {
              _stopTextEditing(saveText: true);
            },
            // Close editor when Escape is pressed (cancel)
            onEditingComplete: () {
              // Don't auto-close on editing complete, only on submit
            },
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  Offset _snapPositionToGrid(Offset position) {
    final x = (position.dx / widget.gridSpacing).round() * widget.gridSpacing;
    final y = (position.dy / widget.gridSpacing).round() * widget.gridSpacing;
    return Offset(x.toDouble(), y.toDouble());
  }

  Offset _snapToGrid(Offset delta) {
    final x = (delta.dx / widget.gridSpacing).round() * widget.gridSpacing;
    final y = (delta.dy / widget.gridSpacing).round() * widget.gridSpacing;
    return Offset(x.toDouble(), y.toDouble());
  }

  Offset _constrainToBounds(Offset position, Size shapeSize) {
    if (_canvasSize.isEmpty) return position;

    final maxX = _canvasSize.width - shapeSize.width;
    final maxY = _canvasSize.height - shapeSize.height;

    return Offset(position.dx.clamp(0, maxX), position.dy.clamp(0, maxY));
  }

  void _moveSingleShapeConstrained(String shapeId, Offset delta) {
    final shape = widget.shapeManager.getShape(shapeId);
    if (shape == null || _canvasSize.isEmpty) {
      widget.shapeManager.moveShape(shapeId, delta);
      return;
    }

    final newPosition = shape.position + delta;
    final constrainedPosition = _constrainToBounds(newPosition, shape.size);
    final constrainedDelta = constrainedPosition - shape.position;

    widget.shapeManager.moveShape(shapeId, constrainedDelta);
  }

  void _moveSelectedShapesConstrained(Offset delta) {
    if (_canvasSize.isEmpty) {
      widget.shapeManager.moveSelectedShapes(delta);
      return;
    }

    Offset constrainedDelta = delta;

    for (final shapeId in widget.shapeManager.selectedShapeIds) {
      final shape = widget.shapeManager.getShape(shapeId);
      if (shape != null) {
        final newPosition = shape.position + delta;
        final constrainedPosition = _constrainToBounds(newPosition, shape.size);
        final shapeDelta = constrainedPosition - shape.position;

        if (shapeDelta.dx.abs() < constrainedDelta.dx.abs()) {
          constrainedDelta = Offset(shapeDelta.dx, constrainedDelta.dy);
        }
        if (shapeDelta.dy.abs() < constrainedDelta.dy.abs()) {
          constrainedDelta = Offset(constrainedDelta.dx, shapeDelta.dy);
        }
      }
    }

    widget.shapeManager.moveSelectedShapes(constrainedDelta);
  }
}

// ============================================================================
// DYNAMIC OVERLAY PAINTER
// ============================================================================

class _DynamicOverlayPainter extends CustomPainter {
  final CanvasTheme theme;
  final ShapeManager shapeManager;
  final Offset? currentPointer;
  final Offset? selectBoxStart;
  final Offset? selectBoxEnd;
  final Rect? dirtyRect;

  _DynamicOverlayPainter({
    required this.theme,
    required this.shapeManager,
    this.currentPointer,
    this.selectBoxStart,
    this.selectBoxEnd,
    this.dirtyRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Apply dirty rect clipping if dragging
    if (dirtyRect != null) {
      canvas.save();
      canvas.clipRect(dirtyRect!);
    }

    // Get shapes to draw (all or dirty rect subset)
    final shapesToDraw = dirtyRect != null
        ? _getShapesInRect(dirtyRect!)
        : shapeManager.shapes;

    // Draw shapes
    if (shapesToDraw.isNotEmpty) {
      final shapePainter = ShapePainter(shapes: shapesToDraw, theme: theme);
      shapePainter.paint(canvas, size);
    }

    // Draw selection box
    if (selectBoxStart != null && selectBoxEnd != null) {
      final rect = Rect.fromPoints(selectBoxStart!, selectBoxEnd!);

      final fillPaint = Paint()
        ..color = theme.accentColor.withValues(alpha: 0.1)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, fillPaint);

      final borderPaint = Paint()
        ..color = theme.accentColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawRect(rect, borderPaint);
    }

    // Restore canvas if clipping was applied
    if (dirtyRect != null) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_DynamicOverlayPainter oldDelegate) {
    return oldDelegate.theme != theme ||
        oldDelegate.shapeManager != shapeManager ||
        oldDelegate.currentPointer != currentPointer ||
        oldDelegate.selectBoxStart != selectBoxStart ||
        oldDelegate.selectBoxEnd != selectBoxEnd ||
        oldDelegate.dirtyRect != dirtyRect;
  }

  List<CanvasShape> _getShapesInRect(Rect rect) {
    return shapeManager.shapes.where((shape) {
      final shapeRect = Rect.fromLTWH(
        shape.position.dx,
        shape.position.dy,
        shape.size.width,
        shape.size.height,
      );
      return rect.overlaps(shapeRect);
    }).toList();
  }
}

// ============================================================================
// HELPER EXTENSIONS
// ============================================================================

extension RectExtensions on Rect {
  Rect expandToInclude(Rect other) {
    return Rect.fromLTRB(
      left < other.left ? left : other.left,
      top < other.top ? top : other.top,
      right > other.right ? right : other.right,
      bottom > other.bottom ? bottom : other.bottom,
    );
  }
}
