import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme_manager.dart';
import '../quick_actions_toolbar.dart';
import '../shapes_panel.dart';
import '../settings_dialog.dart';
import '../blueprint_canvas_painter.dart';
import '../managers/node_manager.dart';
import '../models/canvas_node.dart';
import '../widgets/node_editor_dialog.dart';
import 'core/viewport_controller.dart';
import 'core/canvas_accessibility_manager.dart';
import 'core/layer_manager.dart';
import 'core/canvas_renderer.dart';

/// EnhancedCanvasLayout: Advanced canvas with modular architecture
/// 
/// Features:
/// - Viewport transformation (zoom/pan)
/// - Layer management system
/// - Comprehensive accessibility support
/// - Modular interaction and rendering
/// - Keyboard shortcuts
/// - Performance optimization
class EnhancedCanvasLayout extends StatefulWidget {
  final ThemeManager themeManager;

  const EnhancedCanvasLayout({
    super.key,
    required this.themeManager,
  });

  @override
  State<EnhancedCanvasLayout> createState() => _EnhancedCanvasLayoutState();
}

class _EnhancedCanvasLayoutState extends State<EnhancedCanvasLayout>
    with TickerProviderStateMixin {
  // Canvas settings state
  bool _showGrid = true;
  bool _snapToGrid = false;
  double _gridSpacing = 50.0;

  // UI state
  bool _showShapesPanel = false;
  bool _showLayersPanel = false;
  CanvasTool _activeTool = CanvasTool.select;
  NodeType? _selectedShapeType;

  // Core managers
  late final NodeManager _nodeManager;
  late final ViewportController _viewportController;
  late final CanvasAccessibilityManager _accessibilityManager;
  late final LayerManager _layerManager;

  @override
  void initState() {
    super.initState();
    
    // Initialize core managers
    _nodeManager = NodeManager();
    _viewportController = ViewportController();
    _layerManager = LayerManager(nodeManager: _nodeManager);
    _accessibilityManager = CanvasAccessibilityManager(
      nodeManager: _nodeManager,
      viewportController: _viewportController,
    );

    // Listen for accessibility announcements
    _nodeManager.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    _nodeManager.removeListener(_onSelectionChanged);
    _nodeManager.dispose();
    _viewportController.dispose();
    _accessibilityManager.dispose();
    _layerManager.dispose();
    super.dispose();
  }

  void _onSelectionChanged() {
    _accessibilityManager.announceSelectionChange();
  }

  // ============================================================================
  // UI EVENT HANDLERS
  // ============================================================================

  void _openSettings() {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(
        themeManager: widget.themeManager,
        currentGridSpacing: _gridSpacing,
        currentGridVisible: _showGrid,
        currentSnapToGrid: _snapToGrid,
        onGridSpacingChanged: (value) {
          setState(() => _gridSpacing = value);
        },
        onGridVisibilityChanged: (value) {
          setState(() => _showGrid = value);
        },
        onSnapToGridChanged: (value) {
          setState(() => _snapToGrid = value);
        },
        onResetView: () {
          _viewportController.reset();
        },
      ),
    );
  }

  void _toggleShapesPanel() {
    setState(() {
      _showShapesPanel = !_showShapesPanel;
      if (!_showShapesPanel) {
        _activeTool = CanvasTool.select;
        _selectedShapeType = null;
      } else {
        _activeTool = CanvasTool.shapes;
        // Close layers panel if open
        _showLayersPanel = false;
      }
    });
  }

  void _toggleLayersPanel() {
    setState(() {
      _showLayersPanel = !_showLayersPanel;
      if (_showLayersPanel) {
        // Close shapes panel if open
        _showShapesPanel = false;
      }
    });
  }

  void _handleShapeSelected(NodeType shapeType) {
    setState(() {
      _selectedShapeType = shapeType;
      _activeTool = CanvasTool.shapes;
    });
  }

  void _handleShapePlaced() {
    // Keep panel open for multiple placements
  }

  void _handleToolChanged(CanvasTool tool) {
    setState(() {
      _activeTool = tool;
      if (tool != CanvasTool.shapes) {
        _selectedShapeType = null;
      }
    });
  }

  Future<void> _openNodeEditor(String nodeId) async {
    final node = _nodeManager.getNode(nodeId);
    if (node == null) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => NodeEditorDialog(
        initialContent: node.content,
        theme: widget.themeManager.currentTheme,
      ),
    );

    if (result != null) {
      _nodeManager.updateNodeContent(nodeId, result);
    }
  }

  // ============================================================================
  // KEYBOARD HANDLING
  // ============================================================================

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Handle accessibility shortcuts
      final action = CanvasAccessibilityShortcuts.getActionForKey(
        event.logicalKey,
        ctrlPressed: HardwareKeyboard.instance.isControlPressed,
      );
      
      if (action != null && _accessibilityManager.handleKeyboardAction(action)) {
        return KeyEventResult.handled;
      }

      // Canvas-specific shortcuts
      if (_handleCanvasShortcuts(event)) {
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  bool _handleCanvasShortcuts(KeyDownEvent event) {
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    // Zoom shortcuts
    if (event.logicalKey == LogicalKeyboardKey.equal && isCtrl) {
      _viewportController.zoomAt(
        Offset(MediaQuery.of(context).size.width / 2, 
               MediaQuery.of(context).size.height / 2),
        1.2,
        MediaQuery.of(context).size,
      );
      return true;
    }
    
    if (event.logicalKey == LogicalKeyboardKey.minus && isCtrl) {
      _viewportController.zoomAt(
        Offset(MediaQuery.of(context).size.width / 2, 
               MediaQuery.of(context).size.height / 2),
        0.8,
        MediaQuery.of(context).size,
      );
      return true;
    }

    // Reset view
    if (event.logicalKey == LogicalKeyboardKey.digit0 && isCtrl) {
      _viewportController.reset();
      return true;
    }

    // Fit to content
    if (event.logicalKey == LogicalKeyboardKey.digit1 && isCtrl) {
      if (_nodeManager.nodes.isNotEmpty) {
        final bounds = _calculateContentBounds();
        _viewportController.fitToContent(bounds, MediaQuery.of(context).size);
      }
      return true;
    }

    // Tool shortcuts
    if (event.logicalKey == LogicalKeyboardKey.keyV) {
      _handleToolChanged(CanvasTool.select);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyN) {
      _handleToolChanged(CanvasTool.node);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyT) {
      _handleToolChanged(CanvasTool.text);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyC) {
      _handleToolChanged(CanvasTool.connector);
      return true;
    }

    // Layer shortcuts
    if (event.logicalKey == LogicalKeyboardKey.keyL && isShift) {
      _toggleLayersPanel();
      return true;
    }

    return false;
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  Rect _calculateContentBounds() {
    if (_nodeManager.nodes.isEmpty) return Rect.zero;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final node in _nodeManager.nodes) {
      minX = minX < node.position.dx ? minX : node.position.dx;
      minY = minY < node.position.dy ? minY : node.position.dy;
      maxX = maxX > (node.position.dx + node.size.width) 
          ? maxX : (node.position.dx + node.size.width);
      maxY = maxY > (node.position.dy + node.size.height) 
          ? maxY : (node.position.dy + node.size.height);
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  // ============================================================================
  // BUILD METHOD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.themeManager,
      builder: (context, _) {
        final theme = widget.themeManager.currentTheme;

        return Scaffold(
          backgroundColor: theme.backgroundColor,
          body: Focus(
            autofocus: true,
            onKeyEvent: _handleKeyEvent,
            child: Stack(
              children: [
                Row(
                  children: [
                    // Canvas Area
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.borderColor.withValues(alpha: 0.5),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.borderColor.withValues(alpha: 0.1),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _accessibilityManager.buildCanvasSemantics(
                            child: Stack(
                              children: [
                                // Background grid layer
                                BlueprintCanvasPainter(
                                  themeManager: widget.themeManager,
                                  showGrid: _showGrid,
                                  gridSpacing: _gridSpacing,
                                  dotSize: 2.0,
                                ),
                                // Enhanced interactive canvas
                                EnhancedInteractiveCanvas(
                                  themeManager: widget.themeManager,
                                  nodeManager: _nodeManager,
                                  viewportController: _viewportController,
                                  activeTool: _activeTool,
                                  snapToGrid: _snapToGrid,
                                  gridSpacing: _gridSpacing,
                                  selectedShapeType: _selectedShapeType,
                                  onShapePlaced: _handleShapePlaced,
                                  onNodeEditorRequested: _openNodeEditor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Control Panel
                    Container(
                      width: 300,
                      decoration: BoxDecoration(
                        color: theme.panelColor,
                        border: Border(
                          left: BorderSide(
                            color: theme.borderColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(-5, 0),
                          ),
                        ],
                      ),
                      child: _buildControlPanel(theme),
                    ),
                  ],
                ),

                // Panels
                if (_showShapesPanel) _buildShapesPanel(),
                if (_showLayersPanel) _buildLayersPanel(theme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlPanel(CanvasTheme theme) {
    return Column(
      children: [
        // Header
        _buildPanelHeader(theme),
        
        // Quick Actions
        Padding(
          padding: const EdgeInsets.all(16),
          child: QuickActionsToolbar(
            themeManager: widget.themeManager,
            onSettingsTap: _openSettings,
            onShapesTool: _toggleShapesPanel,
            onToolChanged: _handleToolChanged,
            activeTool: _activeTool,
          ),
        ),

        // Layer Controls
        _buildLayerControls(theme),
        
        // Viewport Info
        _buildViewportInfo(theme),
        
        Expanded(child: Container()),
        
        // Footer
        _buildPanelFooter(theme),
      ],
    );
  }

  Widget _buildPanelHeader(CanvasTheme theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: theme.borderColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.dashboard_customize,
              color: theme.accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enhanced Canvas',
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Modular System',
                  style: TextStyle(
                    color: theme.textColor.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayerControls(CanvasTheme theme) {
    return AnimatedBuilder(
      animation: _layerManager,
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.backgroundColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.borderColor.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.layers,
                    size: 16,
                    color: theme.textColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'LAYERS',
                    style: TextStyle(
                      color: theme.textColor.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.add, size: 16),
                    onPressed: () => _layerManager.createLayer(),
                    color: theme.accentColor,
                    iconSize: 16,
                  ),
                  IconButton(
                    icon: Icon(Icons.list, size: 16),
                    onPressed: _toggleLayersPanel,
                    color: theme.accentColor,
                    iconSize: 16,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Active: ${_layerManager.activeLayer?.name ?? 'None'}',
                style: TextStyle(
                  color: theme.textColor.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
              Text(
                '${_layerManager.layerCount} layers total',
                style: TextStyle(
                  color: theme.textColor.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildViewportInfo(CanvasTheme theme) {
    return AnimatedBuilder(
      animation: _viewportController,
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.backgroundColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.borderColor.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.zoom_in,
                    size: 16,
                    color: theme.textColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'VIEWPORT',
                    style: TextStyle(
                      color: theme.textColor.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Zoom: ${(_viewportController.scale * 100).toInt()}%',
                style: TextStyle(
                  color: theme.textColor.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
              Text(
                'Pan: ${_viewportController.translation.dx.toInt()}, ${_viewportController.translation.dy.toInt()}',
                style: TextStyle(
                  color: theme.textColor.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPanelFooter(CanvasTheme theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.2),
        border: Border(
          top: BorderSide(
            color: theme.borderColor.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.accessibility_new,
                color: theme.textColor.withValues(alpha: 0.5),
                size: 14,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Press F1 for accessibility help',
                  style: TextStyle(
                    color: theme.textColor.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.keyboard,
                color: theme.textColor.withValues(alpha: 0.5),
                size: 14,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ctrl+0: Reset • Ctrl+1: Fit all',
                  style: TextStyle(
                    color: theme.textColor.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShapesPanel() {
    return Positioned(
      right: 300,
      top: 0,
      bottom: 0,
      child: ShapesPanel(
        themeManager: widget.themeManager,
        onClose: _toggleShapesPanel,
        onShapeSelected: _handleShapeSelected,
      ),
    );
  }

  Widget _buildLayersPanel(CanvasTheme theme) {
    return Positioned(
      right: 300,
      top: 0,
      bottom: 0,
      width: 280,
      child: AnimatedBuilder(
        animation: _layerManager,
        builder: (context, _) {
          return Container(
            decoration: BoxDecoration(
              color: theme.panelColor,
              border: Border.all(
                color: theme.borderColor.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(-5, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.backgroundColor.withValues(alpha: 0.3),
                    border: Border(
                      bottom: BorderSide(
                        color: theme.borderColor.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.layers, color: theme.accentColor, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Layers',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _toggleLayersPanel,
                        color: theme.textColor.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                ),
                
                // Layer list
                Expanded(
                  child: ListView.builder(
                    itemCount: _layerManager.layers.length,
                    itemBuilder: (context, index) {
                      final layer = _layerManager.layers[index];
                      final isActive = layer.id == _layerManager.activeLayerId;
                      
                      return ListTile(
                        selected: isActive,
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: layer.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(
                          layer.name,
                          style: TextStyle(
                            color: theme.textColor,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '${layer.nodeCount} nodes',
                          style: TextStyle(
                            color: theme.textColor.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                layer.isVisible 
                                    ? Icons.visibility 
                                    : Icons.visibility_off,
                                size: 16,
                              ),
                              onPressed: () => _layerManager.toggleLayerVisibility(layer.id),
                              color: theme.textColor.withValues(alpha: 0.6),
                            ),
                            IconButton(
                              icon: Icon(
                                layer.isLocked 
                                    ? Icons.lock 
                                    : Icons.lock_open,
                                size: 16,
                              ),
                              onPressed: () => _layerManager.toggleLayerLock(layer.id),
                              color: theme.textColor.withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                        onTap: () => _layerManager.setActiveLayer(layer.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}