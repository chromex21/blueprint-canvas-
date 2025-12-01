import 'package:flutter/material.dart';
import '../models/canvas_node.dart';
import '../managers/node_manager.dart';
import '../painters/node_painter_optimized.dart';
import '../painters/connection_painter.dart';
import '../widgets/node_editor_dialog.dart';
import '../theme_manager.dart';
import '../quick_actions_toolbar.dart';

/// InteractiveCanvas: Main interactive canvas widget (DIRTY RECT OPTIMIZED)
///
/// PERFORMANCE OPTIMIZATIONS:
/// - Dirty rect region invalidation during node dragging
/// - Only repaints local area around moving nodes
/// - Grid layer remains static (cached texture - DO NOT MODIFY)
/// - Eliminates full-canvas repaints on pointer move
///
/// Handles gestures, renders nodes/connections, and manages user interactions
class InteractiveCanvas extends StatefulWidget {
  final ThemeManager themeManager;
  final NodeManager nodeManager;
  final CanvasTool activeTool;
  final bool snapToGrid;
  final double gridSpacing;
  final NodeType? selectedShapeType;
  final VoidCallback? onShapePlaced;

  const InteractiveCanvas({
    super.key,
    required this.themeManager,
    required this.nodeManager,
    required this.activeTool,
    this.snapToGrid = false,
    this.gridSpacing = 50.0,
    this.selectedShapeType,
    this.onShapePlaced,
  });

  @override
  State<InteractiveCanvas> createState() => _InteractiveCanvasState();
}

class _InteractiveCanvasState extends State<InteractiveCanvas> {
  // Gesture state
  String? _draggedNodeId;
  // ignore: unused_field
  Offset? _dragStart;
  Offset? _connectionStart;
  String? _connectionSourceId;
  Offset? _currentPointer;

  // Multi-select state
  Offset? _selectBoxStart;
  Offset? _selectBoxEnd;

  // Canvas boundaries
  Size? _canvasSize;

  // Dirty rect tracking for optimization
  final Map<String, Rect> _previousNodeRects = {};
  // ignore: unused_field
  Rect? _previousDirtyRect;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.themeManager, widget.nodeManager]),
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
              // Capture canvas size for boundary checks
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_canvasSize != constraints.biggest) {
                  setState(() {
                    _canvasSize = constraints.biggest;
                  });
                }
              });

              return MouseRegion(
                onHover: (event) {
                  // PERFORMANCE FIX: Don't trigger setState on every mouse move!
                  // Only update pointer position and repaint if drawing connection
                  final newPointer = event.localPosition;

                  // Only repaint if actively showing temporary connection line and position changed
                  if (_connectionStart != null &&
                      _connectionSourceId != null &&
                      (_currentPointer == null ||
                          _currentPointer != newPointer)) {
                    _currentPointer = newPointer;
                    setState(() {}); // Minimal targeted repaint
                  } else {
                    _currentPointer = newPointer;
                  }
                },
                child: CustomPaint(
                  painter: _CanvasLayerPainter(
                    theme: theme,
                    nodeManager: widget.nodeManager,
                    connectionStart: _connectionStart,
                    currentPointer: _currentPointer,
                    selectBoxStart: _selectBoxStart,
                    selectBoxEnd: _selectBoxEnd,
                    dirtyRect: _computeDirtyRect(),
                  ),
                  size: Size.infinite,
                ),
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

  /// Compute dirty rect = union of old and new positions of moving nodes
  Rect? _computeDirtyRect() {
    if (_draggedNodeId == null) {
      _previousDirtyRect = null;
      _previousNodeRects.clear();
      return null; // No dragging - full repaint needed
    }

    final draggingNodes =
        widget.nodeManager.selectedNodeIds.contains(_draggedNodeId)
        ? widget.nodeManager.selectedNodeIds.toList()
        : [_draggedNodeId!];

    Rect? dirtyRect;

    for (final nodeId in draggingNodes) {
      final node = widget.nodeManager.getNode(nodeId);
      if (node == null) continue;

      // Current node rect (with padding for shadows/selection glow)
      final currentRect = Rect.fromLTWH(
        node.position.dx,
        node.position.dy,
        node.size.width,
        node.size.height,
      ).inflate(20); // Padding for selection effects

      // Get previous rect
      final prevRect = _previousNodeRects[nodeId];

      if (prevRect != null) {
        // Union of old and new positions
        dirtyRect = dirtyRect == null
            ? currentRect.expandToInclude(prevRect)
            : dirtyRect.expandToInclude(currentRect.expandToInclude(prevRect));
      } else {
        // First drag frame - use current rect
        dirtyRect = dirtyRect == null
            ? currentRect
            : dirtyRect.expandToInclude(currentRect);
      }

      // Store current rect for next frame
      _previousNodeRects[nodeId] = currentRect;
    }

    _previousDirtyRect = dirtyRect;
    return dirtyRect;
  }

  // ============================================================================
  // GESTURE HANDLERS
  // ============================================================================

  void _handleTapDown(TapDownDetails details) {
    final position = details.localPosition;

    switch (widget.activeTool) {
      case CanvasTool.select:
        _handleSelectTap(position);
        break;
      case CanvasTool.node:
        _handleNodeCreation(position);
        break;
      case CanvasTool.text:
        _handleTextCreation(position);
        break;
      case CanvasTool.connector:
        _handleConnectorTap(position);
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
    if (_currentPointer == null) return;

    // Only allow editing in select mode
    if (widget.activeTool != CanvasTool.select) return;

    final node = widget.nodeManager.getNodeAtPosition(_currentPointer!);
    if (node != null) {
      _openNodeEditor(node.id);
    }
  }

  void _handlePanStart(DragStartDetails details) {
    final position = details.localPosition;

    switch (widget.activeTool) {
      case CanvasTool.select:
        _handleSelectPanStart(position);
        break;
      default:
        break;
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final position = details.localPosition;
    final delta = details.delta;

    switch (widget.activeTool) {
      case CanvasTool.select:
        _handleSelectPanUpdate(position, delta);
        break;
      default:
        break;
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    switch (widget.activeTool) {
      case CanvasTool.select:
        _handleSelectPanEnd();
        break;
      default:
        break;
    }
  }

  // ============================================================================
  // SELECT TOOL LOGIC
  // ============================================================================

  void _handleSelectTap(Offset position) {
    final node = widget.nodeManager.getNodeAtPosition(position);

    if (node != null) {
      // Single tap on node - select it
      widget.nodeManager.selectNode(node.id);
    } else {
      // Tap on empty space - clear selection
      widget.nodeManager.clearSelection();
    }
  }

  void _handleSelectPanStart(Offset position) {
    final node = widget.nodeManager.getNodeAtPosition(position);

    if (node != null) {
      // Start dragging a node
      setState(() {
        _draggedNodeId = node.id;
        _dragStart = position;
        _previousNodeRects.clear(); // Reset dirty rect tracking
      });
      widget.nodeManager.selectNode(node.id);
    } else {
      // Start selection box
      setState(() {
        _selectBoxStart = position;
        _selectBoxEnd = position;
      });
    }
  }

  void _handleSelectPanUpdate(Offset position, Offset delta) {
    if (_draggedNodeId != null) {
      // Drag node(s) with boundary constraints
      final snappedDelta = widget.snapToGrid ? _snapToGrid(delta) : delta;

      if (widget.nodeManager.selectedNodeIds.contains(_draggedNodeId)) {
        // Move all selected nodes with constraints
        _moveSelectedNodesConstrained(snappedDelta);
      } else {
        // Move single node with constraints
        _moveSingleNodeConstrained(_draggedNodeId!, snappedDelta);
      }
    } else if (_selectBoxStart != null) {
      // Update selection box
      setState(() {
        _selectBoxEnd = position;
      });
    }
  }

  void _handleSelectPanEnd() {
    if (_selectBoxStart != null && _selectBoxEnd != null) {
      // Finalize multi-select
      final rect = Rect.fromPoints(_selectBoxStart!, _selectBoxEnd!);
      widget.nodeManager.selectNodesInRect(rect);
    }

    setState(() {
      _draggedNodeId = null;
      _dragStart = null;
      _selectBoxStart = null;
      _selectBoxEnd = null;
      _previousNodeRects.clear(); // Clear dirty rect cache
    });
  }

  // ============================================================================
  // NODE CREATION LOGIC
  // ============================================================================

  void _handleNodeCreation(Offset position) {
    final snappedPosition = widget.snapToGrid
        ? _snapPositionToGrid(position)
        : position;

    // Ensure node stays within bounds
    final constrainedPosition = _constrainToBounds(
      snappedPosition,
      const Size(140, 80),
    );

    final theme = widget.themeManager.currentTheme;
    final node = CanvasNode.createBasicNode(
      constrainedPosition,
      theme.accentColor,
    );

    widget.nodeManager.addNode(node);

    // Open editor immediately
    _openNodeEditor(node.id);
  }

  // ============================================================================
  // TEXT CREATION LOGIC
  // ============================================================================

  void _handleTextCreation(Offset position) {
    final snappedPosition = widget.snapToGrid
        ? _snapPositionToGrid(position)
        : position;

    // Ensure text block stays within bounds
    final constrainedPosition = _constrainToBounds(
      snappedPosition,
      const Size(200, 60),
    );

    final theme = widget.themeManager.currentTheme;
    final node = CanvasNode.createTextBlock(
      constrainedPosition,
      theme.textColor,
    );

    widget.nodeManager.addNode(node);

    // Open editor immediately
    _openNodeEditor(node.id);
  }

  // ============================================================================
  // SHAPE CREATION LOGIC
  // ============================================================================

  void _handleShapeCreation(Offset position) {
    if (widget.selectedShapeType == null) {
      // No shape selected - ignore click
      return;
    }

    final snappedPosition = widget.snapToGrid
        ? _snapPositionToGrid(position)
        : position;

    // Ensure shape stays within bounds
    final constrainedPosition = _constrainToBounds(
      snappedPosition,
      const Size(120, 120),
    );

    final theme = widget.themeManager.currentTheme;
    final node = CanvasNode.createShape(
      constrainedPosition,
      widget.selectedShapeType!,
      theme.accentColor,
    );

    widget.nodeManager.addNode(node);

    // Notify parent that shape was placed (but don't close panel)
    widget.onShapePlaced?.call();
  }

  // ============================================================================
  // CONNECTOR LOGIC
  // ============================================================================

  void _handleConnectorTap(Offset position) {
    final node = widget.nodeManager.getNodeAtPosition(position);

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

  // ============================================================================
  // ERASER LOGIC
  // ============================================================================

  void _handleEraserTap(Offset position) {
    final node = widget.nodeManager.getNodeAtPosition(position);
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

  Future<void> _openNodeEditor(String nodeId) async {
    final node = widget.nodeManager.getNode(nodeId);
    if (node == null) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => NodeEditorDialog(
        initialContent: node.content,
        theme: widget.themeManager.currentTheme,
      ),
    );

    if (result != null) {
      widget.nodeManager.updateNodeContent(nodeId, result);
    }
  }

  // ============================================================================
  // BOUNDARY CONSTRAINT HELPERS
  // ============================================================================

  /// Constrains a position to stay within canvas bounds
  Offset _constrainToBounds(Offset position, Size nodeSize) {
    if (_canvasSize == null) return position;

    final maxX = _canvasSize!.width - nodeSize.width;
    final maxY = _canvasSize!.height - nodeSize.height;

    return Offset(position.dx.clamp(0, maxX), position.dy.clamp(0, maxY));
  }

  /// Moves a single node with boundary constraints
  void _moveSingleNodeConstrained(String nodeId, Offset delta) {
    final node = widget.nodeManager.getNode(nodeId);
    if (node == null || _canvasSize == null) {
      widget.nodeManager.moveNode(nodeId, delta);
      return;
    }

    final newPosition = node.position + delta;
    final constrainedPosition = _constrainToBounds(newPosition, node.size);
    final constrainedDelta = constrainedPosition - node.position;

    widget.nodeManager.moveNode(nodeId, constrainedDelta);
  }

  /// Moves all selected nodes with boundary constraints
  void _moveSelectedNodesConstrained(Offset delta) {
    if (_canvasSize == null) {
      widget.nodeManager.moveSelectedNodes(delta);
      return;
    }

    // Calculate the constrained delta that works for all selected nodes
    Offset constrainedDelta = delta;

    for (final nodeId in widget.nodeManager.selectedNodeIds) {
      final node = widget.nodeManager.getNode(nodeId);
      if (node != null) {
        final newPosition = node.position + delta;
        final constrainedPosition = _constrainToBounds(newPosition, node.size);
        final nodeDelta = constrainedPosition - node.position;

        // Use the most restrictive delta for all nodes
        if (nodeDelta.dx.abs() < constrainedDelta.dx.abs()) {
          constrainedDelta = Offset(nodeDelta.dx, constrainedDelta.dy);
        }
        if (nodeDelta.dy.abs() < constrainedDelta.dy.abs()) {
          constrainedDelta = Offset(constrainedDelta.dx, nodeDelta.dy);
        }
      }
    }

    widget.nodeManager.moveSelectedNodes(constrainedDelta);
  }
}

// ============================================================================
// CANVAS LAYER PAINTER (DIRTY RECT OPTIMIZED)
// ============================================================================

/// Custom painter with dirty rect region invalidation
/// Only repaints local area around moving nodes (not entire canvas)
/// Grid layer is static cached texture - DO NOT MODIFY
class _CanvasLayerPainter extends CustomPainter {
  final CanvasTheme theme;
  final NodeManager nodeManager;
  final Offset? connectionStart;
  final Offset? currentPointer;
  final Offset? selectBoxStart;
  final Offset? selectBoxEnd;
  final Rect? dirtyRect; // Region to repaint

  _CanvasLayerPainter({
    required this.theme,
    required this.nodeManager,
    this.connectionStart,
    this.currentPointer,
    this.selectBoxStart,
    this.selectBoxEnd,
    this.dirtyRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Apply dirty rect clipping if dragging nodes
    if (dirtyRect != null) {
      canvas.save();
      canvas.clipRect(dirtyRect!);
    }

    // PERFORMANCE FIX: Only process nodes in dirty rect during drag
    final nodesToDraw = dirtyRect != null
        ? _getNodesInRect(dirtyRect!)
        : nodeManager.nodes;

    // 1. Draw connections first (behind nodes)
    if (nodeManager.connections.isNotEmpty) {
      // PERFORMANCE FIX: Filter connections that connect to visible nodes
      final visibleNodeIds = nodesToDraw.map((n) => n.id).toSet();
      final visibleConnections = nodeManager.connections.where((conn) {
        return visibleNodeIds.contains(conn.sourceNodeId) ||
            visibleNodeIds.contains(conn.targetNodeId);
      }).toList();

      if (visibleConnections.isNotEmpty) {
        final nodeMap = <String, CanvasNode>{
          for (final n in nodeManager.nodes) n.id: n,
        };
        final connectionPainter = ConnectionPainter(
          connections: visibleConnections,
          nodeMap: nodeMap,
          theme: theme,
        );
        connectionPainter.paint(canvas, size);
      }
    }

    // 2. Draw temporary connection line (while creating)
    if (connectionStart != null && currentPointer != null) {
      final paint = Paint()
        ..color = theme.accentColor.withValues(alpha: 0.6)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(connectionStart!, currentPointer!, paint);

      // Draw small circle at start
      canvas.drawCircle(
        connectionStart!,
        4,
        Paint()..color = theme.accentColor,
      );
    }

    // 3. Draw nodes on top (only affected nodes)
    if (nodesToDraw.isNotEmpty) {
      // Use optimized painter for better performance
      final nodePainter = OptimizedNodePainter(
        nodes: nodesToDraw,
        theme: theme,
      );
      nodePainter.paint(canvas, size);
    }

    // 4. Draw selection box (if active)
    if (selectBoxStart != null && selectBoxEnd != null) {
      final rect = Rect.fromPoints(selectBoxStart!, selectBoxEnd!);

      // Fill
      final fillPaint = Paint()
        ..color = theme.accentColor.withValues(alpha: 0.1)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, fillPaint);

      // Border
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
  bool shouldRepaint(_CanvasLayerPainter oldDelegate) {
    return oldDelegate.theme != theme ||
        oldDelegate.nodeManager != nodeManager ||
        oldDelegate.connectionStart != connectionStart ||
        oldDelegate.currentPointer != currentPointer ||
        oldDelegate.selectBoxStart != selectBoxStart ||
        oldDelegate.selectBoxEnd != selectBoxEnd ||
        oldDelegate.dirtyRect != dirtyRect;
  }

  /// PERFORMANCE HELPER: Get only nodes that intersect with given rect
  List<CanvasNode> _getNodesInRect(Rect rect) {
    return nodeManager.nodes.where((node) {
      final nodeRect = Rect.fromLTWH(
        node.position.dx,
        node.position.dy,
        node.size.width,
        node.size.height,
      );
      return rect.overlaps(nodeRect);
    }).toList();
  }
}

// ============================================================================
// HELPER EXTENSIONS
// ============================================================================

extension RectExtensions on Rect {
  /// Expand this rect to include another rect
  Rect expandToInclude(Rect other) {
    return Rect.fromLTRB(
      left < other.left ? left : other.left,
      top < other.top ? top : other.top,
      right > other.right ? right : other.right,
      bottom > other.bottom ? bottom : other.bottom,
    );
  }
}
