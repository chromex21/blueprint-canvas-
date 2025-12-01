import 'package:flutter/material.dart';
import 'theme_manager.dart';
import 'quick_actions_toolbar.dart';
import 'shapes_panel.dart';
import 'settings_dialog.dart';
import 'painters/grid_painter_optimized.dart';
import 'managers/node_manager_optimized.dart';
import 'models/canvas_node.dart';
import 'widgets/interactive_canvas_optimized.dart';
import 'core/viewport_controller.dart';

/// CanvasLayout: Main layout with compact control panel and canvas
///
/// Structure:
/// - Compact side panel with quick actions toolbar (300px)
/// - Canvas area with rounded border
/// - Settings accessible via dialog
/// - Shapes accessible via slide-out panel
class CanvasLayout extends StatefulWidget {
  final ThemeManager themeManager;

  const CanvasLayout({super.key, required this.themeManager});

  @override
  State<CanvasLayout> createState() => _CanvasLayoutState();
}

class _CanvasLayoutState extends State<CanvasLayout> {
  // Canvas settings state
  bool _showGrid = true;
  bool _snapToGrid = false;
  double _gridSpacing = 50.0;

  // UI state
  bool _showShapesPanel = false;
  CanvasTool _activeTool = CanvasTool.select;
  NodeType? _selectedShapeType; // For shape placement

  // Node manager (using optimized version for better performance)
  late final NodeManagerOptimized _nodeManager;

  // Viewport controller (ENABLED for zoom/pan support)
  late final ViewportController _viewportController;

  @override
  void initState() {
    super.initState();
    // Use optimized node manager for better performance
    _nodeManager = NodeManagerOptimized();

    // ✅ STABILIZATION FIX: Enable viewport controller for zoom/pan
    _viewportController = ViewportController();
  }

  @override
  void dispose() {
    _nodeManager.dispose();
    _viewportController.dispose();
    super.dispose();
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(
        themeManager: widget.themeManager,
        currentGridSpacing: _gridSpacing,
        currentGridVisible: _showGrid,
        currentSnapToGrid: _snapToGrid,
        currentDockScale: 1.0,
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
          setState(() {
            _gridSpacing = 50.0;
            _showGrid = true;
            _snapToGrid = false;
          });
        },
        onDockScaleChanged: (v) {},
      ),
    );
  }

  void _toggleShapesPanel() {
    setState(() {
      _showShapesPanel = !_showShapesPanel;
      if (!_showShapesPanel) {
        // When closing panel, reset to select tool
        _activeTool = CanvasTool.select;
        _selectedShapeType = null;
      } else {
        // When opening panel, activate shapes tool
        _activeTool = CanvasTool.shapes;
      }
    });
  }

  void _handleShapeSelected(NodeType shapeType) {
    setState(() {
      _selectedShapeType = shapeType;
      _activeTool = CanvasTool.shapes; // Ensure shapes tool is active
      // Keep panel open, user will click canvas to place
    });
  }

  void _handleShapePlaced() {
    // Don't close panel - allow multiple placements
    // Panel stays open until user manually closes it
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.themeManager,
      builder: (context, _) {
        final theme = widget.themeManager.currentTheme;

        return Scaffold(
          backgroundColor: theme.backgroundColor,
          body: Stack(
            children: [
              Row(
                children: [
                  // Canvas Area (with rounded border)
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
                        child: Stack(
                          children: [
                            // Background grid layer (optimized with viewport)
                            // Note: Grid appearance is immutable; ThemeManager has no effect
                            OptimizedGridPainter(
                              showGrid: _showGrid,
                              viewportController: _viewportController,
                              gridSpacing: _gridSpacing,
                            ),
                            // Interactive canvas layer (nodes/connections) - OPTIMIZED
                            InteractiveCanvasOptimized(
                              themeManager: widget.themeManager,
                              nodeManager: _nodeManager,
                              viewportController: _viewportController,
                              activeTool: _activeTool,
                              snapToGrid: _snapToGrid,
                              gridSpacing: _gridSpacing,
                              selectedShapeType: _selectedShapeType,
                              onShapePlaced: _handleShapePlaced,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Compact Control Panel (right side)
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
                    child: Column(
                      children: [
                        // Header
                        Container(
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
                                  color: theme.accentColor.withValues(
                                    alpha: 0.1,
                                  ),
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
                                      'Canvas Studio',
                                      style: TextStyle(
                                        color: theme.textColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Blueprint System',
                                      style: TextStyle(
                                        color: theme.textColor.withValues(
                                          alpha: 0.6,
                                        ),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Quick Actions Toolbar
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: QuickActionsToolbar(
                            themeManager: widget.themeManager,
                            onSettingsTap: _openSettings,
                            onShapesTool: _toggleShapesPanel,
                            onMediaTool: () {},
                            onToolChanged: (tool) {
                              setState(() => _activeTool = tool);
                            },
                            activeTool: _activeTool,
                          ),
                        ),

                        // Expandable content area (for future features)
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Placeholder for future features
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.backgroundColor.withValues(
                                      alpha: 0.3,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: theme.borderColor.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.layers_outlined,
                                            size: 16,
                                            color: theme.textColor.withValues(
                                              alpha: 0.7,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'LAYERS',
                                            style: TextStyle(
                                              color: theme.textColor.withValues(
                                                alpha: 0.7,
                                              ),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Layer management coming soon...',
                                        style: TextStyle(
                                          color: theme.textColor.withValues(
                                            alpha: 0.5,
                                          ),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Properties placeholder
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.backgroundColor.withValues(
                                      alpha: 0.3,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: theme.borderColor.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.tune,
                                            size: 16,
                                            color: theme.textColor.withValues(
                                              alpha: 0.7,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'PROPERTIES',
                                            style: TextStyle(
                                              color: theme.textColor.withValues(
                                                alpha: 0.7,
                                              ),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Select an element to view properties',
                                        style: TextStyle(
                                          color: theme.textColor.withValues(
                                            alpha: 0.5,
                                          ),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Footer info
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.backgroundColor.withValues(alpha: 0.2),
                            border: Border(
                              top: BorderSide(
                                color: theme.borderColor.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: theme.textColor.withValues(alpha: 0.5),
                                size: 14,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Click ⚙ for canvas settings',
                                  style: TextStyle(
                                    color: theme.textColor.withValues(
                                      alpha: 0.5,
                                    ),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Shapes Panel Overlay (slide-in from right)
              if (_showShapesPanel)
                Positioned(
                  right: 300, // Position next to control panel
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: () {}, // Prevents closing when tapping panel
                    child: ShapesPanel(
                      themeManager: widget.themeManager,
                      onClose: _toggleShapesPanel,
                      onShapeSelected: _handleShapeSelected,
                    ),
                  ),
                ),

              // Backdrop when shapes panel is open - REMOVED
              // Panel now stays open to allow multiple shape placements
              // User must click X to close
            ],
          ),
        );
      },
    );
  }
}
