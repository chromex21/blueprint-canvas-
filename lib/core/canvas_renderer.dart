import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/canvas_node.dart';
import '../managers/node_manager.dart';
import '../painters/node_painter.dart';
import '../painters/connection_painter.dart';
import '../theme_manager.dart';
import '../quick_actions_toolbar.dart';
import 'viewport_controller.dart';
import 'canvas_interaction_manager.dart';

/// CanvasRenderer: Handles all canvas rendering operations
///
/// Responsibilities:
/// - Coordinate transforms for rendering
/// - Layer-based rendering (background, connections, nodes, overlays)
/// - Viewport culling for performance
/// - Selection and interaction visual feedback
/// - Accessibility rendering support
class CanvasRenderer extends CustomPainter {
  final CanvasTheme theme;
  final NodeManager nodeManager;
  final ViewportController viewportController;
  final Size canvasSize;

  // Interaction visuals
  final Offset? connectionStart;
  final Offset? currentPointer;
  final Rect? selectionBoxBounds;

  // Accessibility
  final bool showAccessibilityOverlay;

  const CanvasRenderer({
    required this.theme,
    required this.nodeManager,
    required this.viewportController,
    required this.canvasSize,
    this.connectionStart,
    this.currentPointer,
    this.selectionBoxBounds,
    this.showAccessibilityOverlay = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Setup transform for viewport
    canvas.save();
    canvas.transform(viewportController.transform.storage);

    // Get visible bounds for culling
    final visibleBounds = viewportController.getVisibleWorldRect(size);

    // 1. Draw connections first (behind nodes)
    _drawConnections(canvas, size, visibleBounds);

    // 2. Draw temporary connection line (while creating)
    _drawTemporaryConnection(canvas, size);

    // 3. Draw nodes on top
    _drawNodes(canvas, size, visibleBounds);

    canvas.restore();

    // 4. Draw screen-space overlays (selection box, UI elements)
    _drawScreenSpaceOverlays(canvas, size);

    // 5. Draw accessibility overlays if enabled
    if (showAccessibilityOverlay) {
      _drawAccessibilityOverlay(canvas, size);
    }
  }

  // ============================================================================
  // LAYER RENDERING METHODS
  // ============================================================================

  void _drawConnections(Canvas canvas, Size size, Rect visibleBounds) {
    if (nodeManager.connections.isEmpty) return;

    // Filter connections that might be visible
    final visibleConnections = nodeManager.connections.where((connection) {
      final sourceNode = nodeManager.getNode(connection.sourceNodeId);
      final targetNode = nodeManager.getNode(connection.targetNodeId);

      if (sourceNode == null || targetNode == null) return false;

      // Simple bounds check - if either node is visible, connection might be visible
      return _isNodeVisible(sourceNode, visibleBounds) ||
          _isNodeVisible(targetNode, visibleBounds);
    }).toList();

    if (visibleConnections.isNotEmpty) {
      final connectionPainter = ConnectionPainter(
        connections: visibleConnections,
        nodes: nodeManager.nodes,
        theme: theme,
      );
      connectionPainter.paint(canvas, size);
    }
  }

  void _drawTemporaryConnection(Canvas canvas, Size size) {
    if (connectionStart == null || currentPointer == null) return;

    // Convert screen pointer to world coordinates
    final worldPointer = viewportController.screenToWorld(
      currentPointer!,
      canvasSize,
    );

    final paint = Paint()
      ..color = theme.accentColor.withOpacity(0.6)
      ..strokeWidth =
          2 /
          viewportController
              .scale // Scale stroke width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(connectionStart!, worldPointer, paint);

    // Draw small circle at start
    canvas.drawCircle(
      connectionStart!,
      4 / viewportController.scale, // Scale radius
      Paint()..color = theme.accentColor,
    );
  }

  void _drawNodes(Canvas canvas, Size size, Rect visibleBounds) {
    if (nodeManager.nodes.isEmpty) return;

    // Filter nodes to only render visible ones
    final visibleNodes = nodeManager.nodes.where((node) {
      return _isNodeVisible(node, visibleBounds);
    }).toList();

    if (visibleNodes.isNotEmpty) {
      final nodePainter = NodePainter(nodes: visibleNodes, theme: theme);
      nodePainter.paint(canvas, size);
    }
  }

  void _drawScreenSpaceOverlays(Canvas canvas, Size size) {
    // Draw selection box (screen space)
    if (selectionBoxBounds != null) {
      _drawSelectionBox(canvas, size);
    }
  }

  void _drawSelectionBox(Canvas canvas, Size size) {
    if (selectionBoxBounds == null) return;

    // Fill
    final fillPaint = Paint()
      ..color = theme.accentColor.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    canvas.drawRect(selectionBoxBounds!, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = theme.accentColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(selectionBoxBounds!, borderPaint);
  }

  void _drawAccessibilityOverlay(Canvas canvas, Size size) {
    // Draw accessibility indicators for screen readers
    final accessibilityPaint = Paint()
      ..color = Colors.yellow.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Highlight focusable elements
    for (final node in nodeManager.nodes) {
      if (_isNodeVisible(node, viewportController.getVisibleWorldRect(size))) {
        // Convert world node bounds to screen bounds
        final screenTopLeft = viewportController.worldToScreen(
          node.position,
          canvasSize,
        );
        final screenSize = viewportController.worldSizeToScreen(node.size);

        final screenRect = Rect.fromLTWH(
          screenTopLeft.dx,
          screenTopLeft.dy,
          screenSize.width,
          screenSize.height,
        );

        canvas.drawRect(screenRect, accessibilityPaint);
      }
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Check if a node is visible in the current viewport
  bool _isNodeVisible(CanvasNode node, Rect visibleBounds) {
    final nodeRect = Rect.fromLTWH(
      node.position.dx,
      node.position.dy,
      node.size.width,
      node.size.height,
    );

    return visibleBounds.overlaps(nodeRect);
  }

  @override
  bool shouldRepaint(CanvasRenderer oldDelegate) {
    return oldDelegate.theme != theme ||
        oldDelegate.nodeManager != nodeManager ||
        oldDelegate.viewportController != viewportController ||
        oldDelegate.canvasSize != canvasSize ||
        oldDelegate.connectionStart != connectionStart ||
        oldDelegate.currentPointer != currentPointer ||
        oldDelegate.selectionBoxBounds != selectionBoxBounds ||
        oldDelegate.showAccessibilityOverlay != showAccessibilityOverlay;
  }
}

/// Enhanced CanvasWidget that combines interaction and rendering
class EnhancedInteractiveCanvas extends StatefulWidget {
  final ThemeManager themeManager;
  final NodeManager nodeManager;
  final ViewportController viewportController;
  final CanvasTool activeTool;
  final bool snapToGrid;
  final double gridSpacing;
  final NodeType? selectedShapeType;
  final VoidCallback? onShapePlaced;
  final Function(String nodeId)? onNodeEditorRequested;

  const EnhancedInteractiveCanvas({
    super.key,
    required this.themeManager,
    required this.nodeManager,
    required this.viewportController,
    required this.activeTool,
    this.snapToGrid = false,
    this.gridSpacing = 50.0,
    this.selectedShapeType,
    this.onShapePlaced,
    this.onNodeEditorRequested,
  });

  @override
  State<EnhancedInteractiveCanvas> createState() =>
      _EnhancedInteractiveCanvasState();
}

class _EnhancedInteractiveCanvasState extends State<EnhancedInteractiveCanvas>
    with TickerProviderStateMixin {
  Size _canvasSize = Size.zero;
  bool _showAccessibilityOverlay = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.themeManager,
        widget.nodeManager,
        widget.viewportController,
      ]),
      builder: (context, _) {
        final theme = widget.themeManager.currentTheme;

        return LayoutBuilder(
          builder: (context, constraints) {
            // Update canvas size
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_canvasSize != constraints.biggest) {
                setState(() {
                  _canvasSize = constraints.biggest;
                });
              }
            });

            return Semantics(
              label: 'Interactive Canvas',
              hint: 'Canvas for creating and editing nodes and connections',
              child: Focus(
                autofocus: true,
                onKeyEvent: _handleKeyEvent,
                child: CanvasInteractionManager(
                  themeManager: widget.themeManager,
                  nodeManager: widget.nodeManager,
                  viewportController: widget.viewportController,
                  activeTool: widget.activeTool,
                  canvasSize: _canvasSize,
                  snapToGrid: widget.snapToGrid,
                  gridSpacing: widget.gridSpacing,
                  selectedShapeType: widget.selectedShapeType,
                  onShapePlaced: widget.onShapePlaced,
                  onNodeEditorRequested: widget.onNodeEditorRequested,
                  child: CustomPaint(
                    painter: CanvasRenderer(
                      theme: theme,
                      nodeManager: widget.nodeManager,
                      viewportController: widget.viewportController,
                      canvasSize: _canvasSize,
                      showAccessibilityOverlay: _showAccessibilityOverlay,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================================
  // ACCESSIBILITY & KEYBOARD SUPPORT
  // ============================================================================

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Toggle accessibility overlay
      if (event.logicalKey == LogicalKeyboardKey.f1) {
        setState(() {
          _showAccessibilityOverlay = !_showAccessibilityOverlay;
        });
        return KeyEventResult.handled;
      }

      // Canvas navigation
      if (event.logicalKey == LogicalKeyboardKey.space) {
        widget.viewportController.reset(canvasSize: _canvasSize);
        return KeyEventResult.handled;
      }

      // Delete selected nodes
      if (event.logicalKey == LogicalKeyboardKey.delete ||
          event.logicalKey == LogicalKeyboardKey.backspace) {
        widget.nodeManager.removeSelectedNodes();
        return KeyEventResult.handled;
      }

      // Select all
      if (event.logicalKey == LogicalKeyboardKey.keyA &&
          HardwareKeyboard.instance.isControlPressed) {
        final allNodeIds = widget.nodeManager.nodes.map((n) => n.id).toList();
        widget.nodeManager.selectMultiple(allNodeIds);
        return KeyEventResult.handled;
      }

      // Zoom controls
      if (event.logicalKey == LogicalKeyboardKey.equal &&
          HardwareKeyboard.instance.isControlPressed) {
        widget.viewportController.zoomAt(
          Offset(_canvasSize.width / 2, _canvasSize.height / 2),
          1.2,
          _canvasSize,
        );
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.minus &&
          HardwareKeyboard.instance.isControlPressed) {
        widget.viewportController.zoomAt(
          Offset(_canvasSize.width / 2, _canvasSize.height / 2),
          0.8,
          _canvasSize,
        );
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }
}
