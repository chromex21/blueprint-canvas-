import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/canvas_node.dart';
import '../managers/node_manager.dart';
import '../theme_manager.dart';
import '../quick_actions_toolbar.dart';
import 'viewport_controller.dart';

/// CanvasInteractionManager: Handles all canvas interactions and gestures
///
/// Responsibilities:
/// - Gesture detection and handling
/// - Tool-specific interaction logic
/// - Coordinate transformation via ViewportController
/// - State management for interactions (dragging, selection, etc.)
/// - Accessibility support for interactions
class CanvasInteractionManager extends StatefulWidget {
  final ThemeManager themeManager;
  final NodeManager nodeManager;
  final ViewportController viewportController;
  final CanvasTool activeTool;
  final bool snapToGrid;
  final double gridSpacing;
  final NodeType? selectedShapeType;
  final Size canvasSize;
  final VoidCallback? onShapePlaced;
  final Function(String nodeId)? onNodeEditorRequested;
  final Widget child;

  const CanvasInteractionManager({
    super.key,
    required this.themeManager,
    required this.nodeManager,
    required this.viewportController,
    required this.activeTool,
    required this.canvasSize,
    required this.child,
    this.snapToGrid = false,
    this.gridSpacing = 50.0,
    this.selectedShapeType,
    this.onShapePlaced,
    this.onNodeEditorRequested,
  });

  @override
  State<CanvasInteractionManager> createState() =>
      _CanvasInteractionManagerState();
}

class _CanvasInteractionManagerState extends State<CanvasInteractionManager> {
  // Interaction state
  String? _draggedNodeId;
  Offset? _connectionStart;
  String? _connectionSourceId;
  Offset? _currentPointer;
  bool _isPanning = false;

  // Multi-select state
  Offset? _selectBoxStart;
  Offset? _selectBoxEnd;

  // Viewport interaction state
  double _lastScale = 1.0;
  Offset? _lastFocalPoint;

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Handle mouse wheel for zooming
      onPointerSignal: _handlePointerSignal,
      child: GestureDetector(
        // Primary touch interactions
        onTapDown: _handleTapDown,
        onDoubleTap: _handleDoubleTap,

        // Use scale gesture for both pan and pinch-to-zoom
        onScaleStart: _handleScaleStart,
        onScaleUpdate: _handleScaleUpdate,
        onScaleEnd: _handleScaleEnd,

        child: MouseRegion(onHover: _handleMouseHover, child: widget.child),
      ),
    );
  }

  // ============================================================================
  // MOUSE & POINTER EVENTS
  // ============================================================================

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final delta = event.scrollDelta.dy;
      final scaleFactor = delta > 0 ? 0.9 : 1.1;
      final focalPoint = event.localPosition;

      widget.viewportController.zoomAt(
        focalPoint,
        scaleFactor,
        widget.canvasSize,
      );
    }
  }

  void _handleMouseHover(PointerHoverEvent event) {
    setState(() {
      _currentPointer = event.localPosition;
    });
  }

  // ============================================================================
  // TAP GESTURES
  // ============================================================================

  void _handleTapDown(TapDownDetails details) {
    final screenPosition = details.localPosition;
    final worldPosition = widget.viewportController.screenToWorld(
      screenPosition,
      widget.canvasSize,
    );

    switch (widget.activeTool) {
      case CanvasTool.select:
        _handleSelectTap(worldPosition, screenPosition);
        break;
      case CanvasTool.node:
        _handleNodeCreation(worldPosition);
        break;
      case CanvasTool.text:
        _handleTextCreation(worldPosition);
        break;
      case CanvasTool.connector:
        _handleConnectorTap(worldPosition);
        break;
      case CanvasTool.shapes:
        _handleShapeCreation(worldPosition);
        break;
      case CanvasTool.eraser:
        _handleEraserTap(worldPosition);
        break;
      default:
        break;
    }
  }

  void _handleDoubleTap() {
    if (_currentPointer == null) return;

    // Only allow editing in select mode
    if (widget.activeTool != CanvasTool.select) return;

    final worldPosition = widget.viewportController.screenToWorld(
      _currentPointer!,
      widget.canvasSize,
    );
    final node = widget.nodeManager.getNodeAtPosition(worldPosition);

    if (node != null) {
      widget.onNodeEditorRequested?.call(node.id);
    }
  }

  // ============================================================================
  // SCALE GESTURES (Handles both pan and pinch-to-zoom)
  // ============================================================================

  void _handleScaleStart(ScaleStartDetails details) {
    _lastScale = 1.0; // Reset to 1.0 for relative scaling
    _lastFocalPoint = details.focalPoint;

    final screenPosition = details.focalPoint;
    final worldPosition = widget.viewportController.screenToWorld(
      screenPosition,
      widget.canvasSize,
    );

    // Handle interaction start based on active tool
    switch (widget.activeTool) {
      case CanvasTool.select:
        _handleSelectPanStart(worldPosition, screenPosition);
        break;
      default:
        // For non-select tools, enable canvas panning
        _isPanning = true;
        break;
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final screenPosition = details.focalPoint;

    if (details.pointerCount == 2) {
      // Multi-finger pinch zoom
      final scaleFactor = details.scale / _lastScale;

      widget.viewportController.zoomAt(
        screenPosition,
        scaleFactor,
        widget.canvasSize,
      );
      _lastScale = details.scale;
    } else if (details.pointerCount == 1 && _lastFocalPoint != null) {
      // Single finger pan/drag
      final worldPosition = widget.viewportController.screenToWorld(
        screenPosition,
        widget.canvasSize,
      );

      // Calculate delta from last focal point
      final screenDelta = details.focalPoint - _lastFocalPoint!;

      if (_isPanning) {
        // Canvas panning
        widget.viewportController.pan(screenDelta);
      } else {
        // Handle tool-specific interactions
        switch (widget.activeTool) {
          case CanvasTool.select:
            _handleSelectPanUpdate(worldPosition, screenPosition, screenDelta);
            break;
          default:
            break;
        }
      }
    }

    // Update last focal point
    _lastFocalPoint = details.focalPoint;
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _lastScale = 1.0;
    _lastFocalPoint = null;

    if (_isPanning) {
      _isPanning = false;
    } else {
      switch (widget.activeTool) {
        case CanvasTool.select:
          _handleSelectPanEnd();
          break;
        default:
          break;
      }
    }
  }

  // ============================================================================
  // TOOL-SPECIFIC HANDLERS
  // ============================================================================

  void _handleSelectTap(Offset worldPosition, Offset screenPosition) {
    final node = widget.nodeManager.getNodeAtPosition(worldPosition);

    if (node != null) {
      // Single tap on node - select it
      widget.nodeManager.selectNode(node.id);
    } else {
      // Tap on empty space - clear selection
      widget.nodeManager.clearSelection();
    }
  }

  void _handleSelectPanStart(Offset worldPosition, Offset screenPosition) {
    final node = widget.nodeManager.getNodeAtPosition(worldPosition);

    if (node != null) {
      // Start dragging a node
      setState(() {
        _draggedNodeId = node.id;
      });
      widget.nodeManager.selectNode(node.id);
    } else {
      // Start selection box
      setState(() {
        _selectBoxStart = screenPosition;
        _selectBoxEnd = screenPosition;
      });
    }
  }

  void _handleSelectPanUpdate(
    Offset worldPosition,
    Offset screenPosition,
    Offset screenDelta,
  ) {
    if (_draggedNodeId != null) {
      // Convert screen delta to world delta for node movement
      final worldDelta = widget.viewportController.screenSizeToWorld(
        Size(screenDelta.dx, screenDelta.dy),
      );
      final worldDeltaOffset = Offset(worldDelta.width, worldDelta.height);

      final snappedDelta = widget.snapToGrid
          ? _snapToGrid(worldDeltaOffset)
          : worldDeltaOffset;

      if (widget.nodeManager.selectedNodeIds.contains(_draggedNodeId)) {
        // Move all selected nodes
        widget.nodeManager.moveSelectedNodes(snappedDelta);
      } else {
        // Move single node
        widget.nodeManager.moveNode(_draggedNodeId!, snappedDelta);
      }
    } else if (_selectBoxStart != null) {
      // Update selection box
      setState(() {
        _selectBoxEnd = screenPosition;
      });
    }
  }

  void _handleSelectPanEnd() {
    if (_selectBoxStart != null && _selectBoxEnd != null) {
      // Convert selection box to world coordinates
      final worldStart = widget.viewportController.screenToWorld(
        _selectBoxStart!,
        widget.canvasSize,
      );
      final worldEnd = widget.viewportController.screenToWorld(
        _selectBoxEnd!,
        widget.canvasSize,
      );

      final rect = Rect.fromPoints(worldStart, worldEnd);
      widget.nodeManager.selectNodesInRect(rect);
    }

    setState(() {
      _draggedNodeId = null;
      _selectBoxStart = null;
      _selectBoxEnd = null;
    });
  }

  void _handleNodeCreation(Offset worldPosition) {
    final snappedPosition = widget.snapToGrid
        ? _snapPositionToGrid(worldPosition)
        : worldPosition;

    final theme = widget.themeManager.currentTheme;
    final node = CanvasNode.createBasicNode(snappedPosition, theme.accentColor);

    widget.nodeManager.addNode(node);
    widget.onNodeEditorRequested?.call(node.id);
  }

  void _handleTextCreation(Offset worldPosition) {
    final snappedPosition = widget.snapToGrid
        ? _snapPositionToGrid(worldPosition)
        : worldPosition;

    final theme = widget.themeManager.currentTheme;
    final node = CanvasNode.createTextBlock(snappedPosition, theme.textColor);

    widget.nodeManager.addNode(node);
    widget.onNodeEditorRequested?.call(node.id);
  }

  void _handleShapeCreation(Offset worldPosition) {
    if (widget.selectedShapeType == null) return;

    final snappedPosition = widget.snapToGrid
        ? _snapPositionToGrid(worldPosition)
        : worldPosition;

    final theme = widget.themeManager.currentTheme;
    final node = CanvasNode.createShape(
      snappedPosition,
      widget.selectedShapeType!,
      theme.accentColor,
    );

    widget.nodeManager.addNode(node);
    widget.onShapePlaced?.call();
  }

  void _handleConnectorTap(Offset worldPosition) {
    final node = widget.nodeManager.getNodeAtPosition(worldPosition);

    if (node == null) {
      // Cancel connection if clicking empty space
      setState(() {
        _connectionStart = null;
        _connectionSourceId = null;
      });
      return;
    }

    if (_connectionSourceId == null) {
      // First click - start connection
      setState(() {
        _connectionSourceId = node.id;
        _connectionStart = node.center;
      });
    } else {
      // Second click - complete connection
      if (_connectionSourceId != node.id) {
        final theme = widget.themeManager.currentTheme;
        widget.nodeManager.connectNodes(
          _connectionSourceId!,
          node.id,
          color: theme.accentColor,
        );
      }

      setState(() {
        _connectionStart = null;
        _connectionSourceId = null;
      });
    }
  }

  void _handleEraserTap(Offset worldPosition) {
    final node = widget.nodeManager.getNodeAtPosition(worldPosition);
    if (node != null) {
      widget.nodeManager.removeNode(node.id);
    }
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

  // ============================================================================
  // GETTERS FOR RENDERING
  // ============================================================================

  /// Current pointer position in screen coordinates
  Offset? get currentPointer => _currentPointer;

  /// Connection start position in world coordinates
  Offset? get connectionStart => _connectionStart;

  /// Selection box bounds in screen coordinates
  Rect? get selectionBoxBounds {
    if (_selectBoxStart == null || _selectBoxEnd == null) return null;
    return Rect.fromPoints(_selectBoxStart!, _selectBoxEnd!);
  }
}
