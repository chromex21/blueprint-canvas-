import 'package:flutter/material.dart';
import 'theme_manager.dart';
import 'managers/shape_manager.dart';
import 'managers/media_manager.dart';
import 'models/canvas_shape.dart';
import 'models/canvas_media.dart';
import 'widgets/simple_canvas.dart';
import 'widgets/shape_selection_panel.dart';
import 'widgets/media_panel.dart';
import 'widgets/edit_tool_panel.dart';
import 'widgets/canvas_minimap.dart';
import 'quick_actions_toolbar.dart';
import 'settings_dialog.dart';
import 'core/viewport_controller.dart';
import 'dart:typed_data';

/// SimpleCanvasLayout: Simplified canvas layout with shapes only
/// 
/// FEATURES:
/// - Select/Move shapes
/// - Add shapes with inline text
/// - Erase shapes
/// - Settings (optional)
/// - No nodes, connections, layers, or text objects
class SimpleCanvasLayout extends StatefulWidget {
  final ThemeManager themeManager;
  final ShapeManager? shapeManager; // Optional: for session loading
  final MediaManager? mediaManager; // Optional: for session loading
  final ViewportController? viewportController; // Optional: for session loading
  final VoidCallback? onSaveAndExit; // Optional: save & exit callback

  const SimpleCanvasLayout({
    super.key,
    required this.themeManager,
    this.shapeManager,
    this.mediaManager,
    this.viewportController,
    this.onSaveAndExit,
  });

  @override
  State<SimpleCanvasLayout> createState() => _SimpleCanvasLayoutState();
}

class _SimpleCanvasLayoutState extends State<SimpleCanvasLayout> {
  late final ShapeManager _shapeManager;
  late final MediaManager _mediaManager;
  late final ViewportController _viewportController;
  late final bool _ownsShapeManager;
  late final bool _ownsMediaManager;
  late final bool _ownsViewportController;
  CanvasTool _activeTool = CanvasTool.select;
  ShapeType? _selectedShapeType;
  String? _selectedEmoji;
  MediaImportData? _selectedImage;
  bool _showShapePanel = false;
  bool _showMediaPanel = false;
  bool _showGrid = true;
  double _gridSpacing = 50.0;
  bool _snapToGrid = false;
  double _dockScale = 1.5; // Dock panel scale - default to Large (1.5x)
  
  // Track original sizes for scaling (reset when selection changes)
  final Map<String, Size> _originalSizes = {}; // Object ID -> original size

  @override
  void initState() {
    super.initState();
    _shapeManager = widget.shapeManager ?? ShapeManager();
    _mediaManager = widget.mediaManager ?? MediaManager();
    _viewportController = widget.viewportController ?? ViewportController();
    _ownsShapeManager = widget.shapeManager == null;
    _ownsMediaManager = widget.mediaManager == null;
    _ownsViewportController = widget.viewportController == null;
  }

  // Expose managers for session save/load
  ShapeManager get shapeManager => _shapeManager;
  MediaManager get mediaManager => _mediaManager;

  @override
  void dispose() {
    if (_ownsShapeManager) {
      _shapeManager.dispose();
    }
    if (_ownsMediaManager) {
      _mediaManager.dispose();
    }
    if (_ownsViewportController) {
      _viewportController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main canvas area (full width, not affected by panel)
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // Canvas
                  SimpleCanvas(
                    themeManager: widget.themeManager,
                    shapeManager: _shapeManager,
                    mediaManager: _mediaManager,
                    activeTool: _activeTool,
                    selectedShapeType: _selectedShapeType,
                    selectedEmoji: _selectedEmoji,
                    selectedImage: _selectedImage,
                    onShapePlaced: () {
                      // Shape placed - panel stays open for multiple placements
                    },
                    showGrid: _showGrid,
                    gridSpacing: _gridSpacing,
                    snapToGrid: _snapToGrid,
                    viewportController: _viewportController,
                  ),

                  // Toolbar (top-right)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: QuickActionsToolbar(
                      themeManager: widget.themeManager,
                      activeTool: _activeTool,
                      onSaveAndExit: widget.onSaveAndExit, // Pass save & exit callback
                      onToolChanged: (tool) {
                        setState(() {
                          _activeTool = tool;
                          if (tool == CanvasTool.shapes) {
                            _showShapePanel = true;
                            _showMediaPanel = false;
                          } else if (tool == CanvasTool.media) {
                            _showMediaPanel = true;
                            _showShapePanel = false;
                          } else {
                            _showShapePanel = false;
                            _showMediaPanel = false;
                          }
                        });
                      },
                      onShapesTool: () {
                        setState(() {
                          _showShapePanel = true;
                          _showMediaPanel = false;
                        });
                      },
                      onMediaTool: () {
                        setState(() {
                          _showMediaPanel = true;
                          _showShapePanel = false;
                        });
                      },
                      onSettingsTap: () {
                        _showSettingsDialog();
                      },
                    ),
                  ),

                  // Minimap (bottom-right)
                  CanvasMinimap(
                    viewportController: _viewportController,
                    shapeManager: _shapeManager,
                    themeManager: widget.themeManager,
                    canvasSize: constraints.biggest,
                  ),
                ],
              );
            },
          ),

          // Shape selection panel overlay (slides in from left, does NOT affect layout)
          // This is an overlay - canvas maintains full size, shapes don't move
          if (_showShapePanel)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: ShapeSelectionPanel(
                themeManager: widget.themeManager,
                selectedShapeType: _selectedShapeType,
                dockScale: _dockScale, // Pass dock scale
                onShapeTypeSelected: (shapeType) {
                  setState(() {
                    _selectedShapeType = shapeType;
                  });
                },
                onClose: () {
                  setState(() {
                    _showShapePanel = false;
                    _activeTool = CanvasTool.select;
                  });
                },
              ),
            ),

          // Media panel overlay (slides in from left, does NOT affect layout)
          if (_showMediaPanel)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: MediaPanel(
                themeManager: widget.themeManager,
                dockScale: _dockScale, // Pass dock scale
                onEmojiSelected: (emoji) {
                  // Store selected emoji - will be placed on canvas click
                  setState(() {
                    _selectedEmoji = emoji;
                    _selectedImage = null;
                    _selectedShapeType = null; // Clear shape selection
                  });
                },
                onImageSelected: (Uint8List imageData, Size size, String filePath, bool isSvg) {
                  // Store selected image - will be placed on canvas click
                  setState(() {
                    _selectedImage = MediaImportData(
                      imageData: imageData,
                      size: size,
                      filePath: filePath,
                      isSvg: isSvg,
                    );
                    _selectedEmoji = null;
                    _selectedShapeType = null; // Clear shape selection
                  });
                },
                onClose: () {
                  setState(() {
                    _showMediaPanel = false;
                    _activeTool = CanvasTool.select;
                    _selectedEmoji = null;
                    _selectedImage = null;
                  });
                },
              ),
            ),

          // Edit Tool panel (bottom-right, appears when Edit Tool is active and object is selected)
          if (_activeTool == CanvasTool.editor)
            AnimatedBuilder(
              // Listen to both managers to rebuild when selection changes
              animation: Listenable.merge([_shapeManager, _mediaManager]),
              builder: (context, child) {
                final selectedShape = _shapeManager.selectedShapes.isNotEmpty
                    ? _shapeManager.selectedShapes.first
                    : null;
                final selectedMedia = _mediaManager.selectedMedia;
                
                // Store original sizes when selection changes
                if (selectedShape != null && !_originalSizes.containsKey(selectedShape.id)) {
                  _originalSizes[selectedShape.id] = selectedShape.size;
                }
                if (selectedMedia != null && !_originalSizes.containsKey(selectedMedia.id)) {
                  _originalSizes[selectedMedia.id] = selectedMedia.size;
                }
                
                // Only show panel if something is selected
                if (selectedShape == null && selectedMedia == null) {
                  return const SizedBox.shrink();
                }
                
                return Positioned(
                  bottom: 16,
                  right: 16,
                  child: EditToolPanel(
                    themeManager: widget.themeManager,
                    selectedShape: selectedShape,
                    selectedMedia: selectedMedia,
                    onNotesChanged: (notes) {
                      if (selectedShape != null) {
                        _shapeManager.updateShapeNotes(selectedShape.id, notes);
                      } else if (selectedMedia != null) {
                        _mediaManager.updateMediaNotes(selectedMedia.id, notes);
                      }
                    },
                    onTextChanged: (text) {
                      if (selectedShape != null && selectedShape.isTextEditable) {
                        _shapeManager.updateShapeText(selectedShape.id, text);
                      }
                    },
                    onScaleChanged: (scale) {
                      // Apply scaling to selected object (scale is a multiplier from original size)
                      if (selectedShape != null) {
                        // Get or store original size
                        if (!_originalSizes.containsKey(selectedShape.id)) {
                          _originalSizes[selectedShape.id] = selectedShape.size;
                        }
                        final originalSize = _originalSizes[selectedShape.id]!;
                        
                        // Apply scale to original size
                        final newSize = Size(
                          originalSize.width * scale,
                          originalSize.height * scale,
                        );
                        _shapeManager.updateShape(selectedShape.id, selectedShape.copyWith(size: newSize));
                      } else if (selectedMedia != null) {
                        // Get or store original size
                        if (!_originalSizes.containsKey(selectedMedia.id)) {
                          _originalSizes[selectedMedia.id] = selectedMedia.size;
                        }
                        final originalSize = _originalSizes[selectedMedia.id]!;
                        
                        // Apply scale to original size
                        final newSize = Size(
                          originalSize.width * scale,
                          originalSize.height * scale,
                        );
                        _mediaManager.updateMediaSize(selectedMedia.id, newSize);
                      }
                    },
                    onBorderToggled: (showBorder) {
                      if (selectedShape != null) {
                        _shapeManager.updateShapeBorder(selectedShape.id, showBorder);
                      } else if (selectedMedia != null) {
                        _mediaManager.updateMediaBorder(selectedMedia.id, showBorder);
                      }
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(
        themeManager: widget.themeManager,
        currentGridSpacing: _gridSpacing,
        currentGridVisible: _showGrid,
        currentSnapToGrid: _snapToGrid,
        currentDockScale: _dockScale,
        onGridSpacingChanged: (value) {
          setState(() {
            _gridSpacing = value;
          });
        },
        onGridVisibilityChanged: (value) {
          setState(() {
            _showGrid = value;
          });
        },
        onSnapToGridChanged: (value) {
          setState(() {
            _snapToGrid = value;
          });
        },
        onDockScaleChanged: (value) {
          setState(() {
            _dockScale = value;
          });
        },
        onResetView: () {
          setState(() {
            _gridSpacing = 50.0;
            _showGrid = true;
            _snapToGrid = false;
            _dockScale = 1.5; // Reset to Large as default
          });
        },
      ),
    );
  }
}
