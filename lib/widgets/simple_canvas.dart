import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/canvas_shape.dart';
import '../models/canvas_media.dart';
import '../managers/shape_manager.dart';
import '../managers/media_manager.dart';
import '../painters/shape_painter.dart';
import '../theme_manager.dart';
import '../quick_actions_toolbar.dart';
import '../painters/grid_painter_optimized.dart';
import '../core/viewport_controller.dart';

/// Resize handle positions
enum ResizeHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  top,
  bottom,
  left,
  right,
}

/// SimpleCanvas: Lightweight, high-performance canvas for shapes only
///
/// FEATURES:
/// - Select/Move shapes
/// - Add shapes with inline text
/// - Erase shapes
/// - Inline text editing (double-click or edit icon)
/// - 60fps performance with many shapes
class SimpleCanvas extends StatefulWidget {
  final ThemeManager themeManager;
  final ShapeManager shapeManager;
  final MediaManager mediaManager;
  final CanvasTool activeTool;
  final ShapeType? selectedShapeType;
  final String? selectedEmoji; // Selected emoji from media panel
  final MediaImportData? selectedImage; // Selected image from media panel
  final VoidCallback? onShapePlaced;
  final bool showGrid;
  final double gridSpacing;
  final bool snapToGrid;
  final ViewportController? viewportController;

  const SimpleCanvas({
    super.key,
    required this.themeManager,
    required this.shapeManager,
    required this.mediaManager,
    required this.activeTool,
    this.selectedShapeType,
    this.selectedEmoji,
    this.selectedImage,
    this.onShapePlaced,
    this.showGrid = true,
    this.gridSpacing = 50.0,
    this.snapToGrid = false,
    this.viewportController,
  });

  @override
  State<SimpleCanvas> createState() => _SimpleCanvasState();
}

class _SimpleCanvasState extends State<SimpleCanvas> {
  // Gesture state
  String? _draggedShapeId;
  String? _draggedMediaId;
  Offset? _selectBoxStart;
  Offset? _selectBoxEnd;

  // Canvas boundaries
  Size _canvasSize = Size.zero;

  // Inline text editing state
  String? _editingShapeId;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

  // Key for canvas repaint control
  // ignore: unused_field
  final GlobalKey _canvasKey = GlobalKey();

  // BuildContext for showing feedback messages
  BuildContext? _canvasBuildContext;

  // Zoom and pan state
  double _initialScale = 1.0;
  Offset? _lastPanPosition;

  // Select tool dragging state (handled via scale gestures)
  Offset? _selectDragCurrent;

  // Edit Tool state (resize handles)
  String? _resizingObjectId; // Shape or media ID being resized
  bool _isResizing = false;
  Offset? _resizeStartPosition;
  Size? _resizeStartSize;
  ResizeHandle? _activeResizeHandle;

  // Hover state for note tooltips
  Offset? _hoverPosition;
  String? _hoveredShapeId;
  String? _hoveredMediaId;

  @override
  void didUpdateWidget(SimpleCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Close text editor if tool changes away from editor
    if (oldWidget.activeTool == CanvasTool.editor &&
        widget.activeTool != CanvasTool.editor) {
      _stopTextEditing(saveText: true);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.themeManager,
        widget.shapeManager,
        widget.mediaManager,
        if (widget.viewportController != null) widget.viewportController!,
      ]),
      builder: (context, _) {
        final theme = widget.themeManager.currentTheme;

        return Listener(
          // Handle mouse wheel for zoom (desktop fallback)
          onPointerSignal: (event) {
            if (event is PointerScrollEvent &&
                widget.viewportController != null) {
              final size =
                  _canvasSize.isEmpty ||
                      _canvasSize.width <= 0 ||
                      _canvasSize.height <= 0
                  ? const Size(800, 600)
                  : _canvasSize;
              final scrollDelta = event.scrollDelta.dy;
              if (scrollDelta != 0) {
                final zoomFactor = scrollDelta > 0 ? 0.9 : 1.1;
                widget.viewportController!.zoomAt(
                  event.localPosition,
                  zoomFactor,
                  size,
                );
              }
            }
          },
          child: MouseRegion(
            onHover: (event) {
              // Only show tooltips when not actively interacting
              if (widget.activeTool != CanvasTool.pan &&
                  !_isResizing &&
                  _draggedShapeId == null &&
                  _draggedMediaId == null) {
                _handleHover(event.localPosition);
              }
            },
            onExit: (event) {
              setState(() {
                _hoverPosition = null;
                _hoveredShapeId = null;
                _hoveredMediaId = null;
              });
            },
            child: GestureDetector(
              // Allow pan gestures to work even when zoomed
              behavior: HitTestBehavior.opaque,
              // Scale gesture recognizer handles both zoom and pan (and shape dragging)
              onScaleStart: _handleScaleStart,
              onScaleUpdate: _handleScaleUpdate,
              onScaleEnd: _handleScaleEnd,
              // Tap gestures
              onTapDown: _handleTapDown,
              onDoubleTapDown: (details) =>
                  _handleDoubleTapAtPosition(details.localPosition),
              child: Builder(
                builder: (context) {
                  // Store context for use in handlers (for showing feedback)
                  _canvasBuildContext = context;
                  return LayoutBuilder(
                    builder: (context, constraints) {
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
                          // Grid background
                          if (widget.showGrid)
                            OptimizedGridPainter(
                              showGrid: widget.showGrid,
                              viewportController: widget.viewportController,
                              gridSpacing: widget.gridSpacing,
                            ),

                          // Unified z-ordered rendering (shapes and media interleaved)
                          ..._buildZOrderedLayers(theme),

                          // Inline text editor overlay
                          if (_editingShapeId != null)
                            ...[_buildInlineTextEditor()].whereType<Widget>(),

                          // Selection box overlay
                          if (_selectBoxStart != null && _selectBoxEnd != null)
                            _buildSelectionBox(theme),

                          // Resize handles overlay (Edit Tool)
                          _buildResizeHandles(theme),

                          // Note tooltip overlay (hover tooltip for shapes/media with notes)
                          _buildNoteTooltip(theme),

                          // Pan limit feedback overlay
                          if (widget.viewportController != null &&
                              widget.viewportController!.isAtPanLimit)
                            _buildPanLimitFeedback(theme),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build layers in z-order (shapes and media interleaved)
  List<Widget> _buildZOrderedLayers(CanvasTheme theme) {
    // Get all objects (shapes and media) and sort by z-index
    final allObjects = <_CanvasObject>[];

    // Add shapes
    for (final shape in widget.shapeManager.shapes) {
      allObjects.add(_CanvasObject.shape(shape));
    }

    // Add media
    for (final media in widget.mediaManager.mediaItems) {
      allObjects.add(_CanvasObject.media(media));
    }

    // Sort by z-index (lower z-index = rendered first = appears behind)
    allObjects.sort((a, b) => a.zIndex.compareTo(b.zIndex));

    // Group objects by type for efficient rendering
    // Render shapes in batches (CustomPaint) and media as individual widgets
    final layers = <Widget>[];
    List<CanvasShape> currentShapeBatch = [];

    for (final obj in allObjects) {
      if (obj.isShape) {
        // Add to current shape batch
        currentShapeBatch.add(obj.shape!);
      } else {
        // Render accumulated shapes first, then media
        if (currentShapeBatch.isNotEmpty) {
          layers.add(_buildShapeLayer(currentShapeBatch, theme));
          currentShapeBatch = [];
        }
        // Render media widget
        layers.add(_buildMediaWidget(obj.media!, theme));
      }
    }

    // Render remaining shapes
    if (currentShapeBatch.isNotEmpty) {
      layers.add(_buildShapeLayer(currentShapeBatch, theme));
    }

    return layers;
  }

  /// Build a shape layer (CustomPaint) for a batch of shapes
  Widget _buildShapeLayer(List<CanvasShape> shapes, CanvasTheme theme) {
    return CustomPaint(
      painter: _ShapeLayerPainter(
        shapes: shapes,
        theme: theme,
        viewportController: widget.viewportController,
      ),
      size: Size.infinite,
    );
  }

  void _handleHover(Offset screenPosition) {
    // Only process hover if not dragging/resizing to avoid interference
    if (_isResizing || _draggedShapeId != null || _draggedMediaId != null) {
      return;
    }

    // Convert screen position to world coordinates
    final worldPos = _screenToWorld(screenPosition);

    // Check if hovering over a shape with notes (objects are now properly z-ordered)
    final media = widget.mediaManager.getMediaAtPosition(worldPos);
    final shape = widget.shapeManager.getShapeAtPosition(worldPos);

    String? newHoveredShapeId;
    String? newHoveredMediaId;

    // Prioritize media (rendered on top)
    if (media != null && media.notes.isNotEmpty) {
      newHoveredMediaId = media.id;
    } else if (shape != null && shape.notes.isNotEmpty) {
      newHoveredShapeId = shape.id;
    }

    // Only update state if hover target changed (performance optimization)
    if (newHoveredShapeId != _hoveredShapeId ||
        newHoveredMediaId != _hoveredMediaId) {
      setState(() {
        _hoverPosition = screenPosition;
        _hoveredShapeId = newHoveredShapeId;
        _hoveredMediaId = newHoveredMediaId;
      });
    } else if (newHoveredShapeId == null && newHoveredMediaId == null) {
      // Not hovering over anything with notes - clear tooltip
      if (_hoverPosition != null) {
        setState(() {
          _hoverPosition = null;
          _hoveredShapeId = null;
          _hoveredMediaId = null;
        });
      }
    } else {
      // Update position only (same object, mouse moved)
      if (_hoverPosition != screenPosition) {
        setState(() {
          _hoverPosition = screenPosition;
        });
      }
    }
  }

  Widget _buildNoteTooltip(CanvasTheme theme) {
    if (_hoverPosition == null ||
        (_hoveredShapeId == null && _hoveredMediaId == null)) {
      return const SizedBox.shrink();
    }

    String noteText = '';
    if (_hoveredShapeId != null) {
      final shape = widget.shapeManager.getShape(_hoveredShapeId!);
      if (shape != null && shape.notes.isNotEmpty) {
        noteText = shape.notes;
      }
    } else if (_hoveredMediaId != null) {
      final media = widget.mediaManager.getMedia(_hoveredMediaId!);
      if (media != null && media.notes.isNotEmpty) {
        noteText = media.notes;
      }
    }

    if (noteText.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate tooltip position (above cursor, with smart positioning to avoid screen edges)
    const tooltipWidth = 250.0;
    const tooltipHeight = 60.0;
    final screenWidth = _canvasSize.width;

    double tooltipLeft = _hoverPosition!.dx + 10;
    double tooltipTop = _hoverPosition!.dy - tooltipHeight - 10;

    // Adjust if tooltip would go off screen
    if (tooltipLeft + tooltipWidth > screenWidth) {
      tooltipLeft = _hoverPosition!.dx - tooltipWidth - 10;
    }
    if (tooltipLeft < 0) {
      tooltipLeft = 10;
    }
    if (tooltipTop < 0) {
      tooltipTop =
          _hoverPosition!.dy + 10; // Show below cursor if no room above
    }

    // Position tooltip
    return Positioned(
      left: tooltipLeft,
      top: tooltipTop,
      child: IgnorePointer(
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 250, minWidth: 100),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.panelColor.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.accentColor.withValues(alpha: 0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.note, size: 16, color: theme.accentColor),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    noteText,
                    style: TextStyle(color: theme.textColor, fontSize: 12),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanLimitFeedback(CanvasTheme theme) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.accentColor.withValues(alpha: 0.6),
            width: 4,
          ),
        ),
        child: Container(color: theme.accentColor.withValues(alpha: 0.1)),
      ),
    );
  }

  // ============================================================================
  // ZOOM AND PAN GESTURE HANDLERS
  // ============================================================================

  void _handleScaleStart(ScaleStartDetails details) {
    if (widget.viewportController == null) return;

    // Store initial scale for relative zoom calculation
    _initialScale = widget.viewportController!.scale;

    if (details.pointerCount == 1) {
      // Single finger gesture
      if (widget.activeTool == CanvasTool.pan) {
        // Pan tool: prepare for viewport panning
        _lastPanPosition = details.focalPoint;
      } else if (widget.activeTool == CanvasTool.select) {
        // Select tool: check if we're starting to drag a shape/media or create selection box
        final worldPos = _screenToWorld(details.focalPoint);
        final shape = widget.shapeManager.getShapeAtPosition(worldPos);
        final media = widget.mediaManager.getMediaAtPosition(worldPos);

        if (shape != null) {
          // Start dragging a shape
          setState(() {
            _draggedShapeId = shape.id;
            _draggedMediaId = null;
            _selectDragCurrent = worldPos;
          });
          widget.shapeManager.selectShape(shape.id);
          widget.mediaManager.clearSelection();
        } else if (media != null) {
          // Start dragging media
          setState(() {
            _draggedMediaId = media.id;
            _draggedShapeId = null;
            _selectDragCurrent = worldPos;
          });
          widget.mediaManager.selectMedia(media.id);
          widget.shapeManager.clearSelection();
        } else {
          // Start selection box
          setState(() {
            _selectBoxStart = worldPos;
            _selectBoxEnd = worldPos;
          });
        }
      } else if (widget.activeTool == CanvasTool.editor) {
        // Editor tool: check for resize handle or start dragging
        final worldPos = _screenToWorld(details.focalPoint);
        final shape = widget.shapeManager.selectedShapes.isNotEmpty
            ? widget.shapeManager.selectedShapes.first
            : null;
        final media = widget.mediaManager.selectedMedia;

        // Check if clicking on a resize handle
        if (shape != null) {
          final handle = _getResizeHandleAtPosition(shape, worldPos);
          if (handle != null) {
            setState(() {
              _isResizing = true;
              _resizingObjectId = shape.id;
              _activeResizeHandle = handle;
              _resizeStartPosition = worldPos;
              _resizeStartSize = shape.size;
            });
          } else {
            // Start dragging shape
            setState(() {
              _draggedShapeId = shape.id;
              _selectDragCurrent = worldPos;
            });
          }
        } else if (media != null) {
          final handle = _getResizeHandleAtPositionForMedia(media, worldPos);
          if (handle != null) {
            setState(() {
              _isResizing = true;
              _resizingObjectId = media.id;
              _activeResizeHandle = handle;
              _resizeStartPosition = worldPos;
              _resizeStartSize = media.size;
            });
          } else {
            // Start dragging media
            setState(() {
              _draggedMediaId = media.id;
              _selectDragCurrent = worldPos;
            });
          }
        }
      }
    } else if (details.pointerCount == 2) {
      // Two fingers: prepare for pinch-to-zoom
      _lastPanPosition = null;
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (widget.viewportController == null) return;

    final size =
        _canvasSize.isEmpty || _canvasSize.width <= 0 || _canvasSize.height <= 0
        ? const Size(800, 600)
        : _canvasSize;

    if (details.pointerCount == 2) {
      // Pinch-to-zoom (two fingers) - zoom toward center of pinch
      // details.scale starts at 1.0 at gesture start, changes as fingers move apart/together
      // Calculate target scale based on initial scale and gesture scale
      final targetScale = (_initialScale * details.scale).clamp(0.5, 3.0);

      // Get current scale from viewport
      final currentScale = widget.viewportController!.scale;

      // Only update if scale changed significantly to avoid unnecessary updates
      if ((targetScale - currentScale).abs() > 0.01) {
        // Calculate delta scale for zoomAt
        final deltaScale = targetScale / currentScale;
        widget.viewportController!.zoomAt(details.focalPoint, deltaScale, size);
      }
    } else if (details.pointerCount == 1) {
      // Single finger gesture
      if (widget.activeTool == CanvasTool.pan && _lastPanPosition != null) {
        // Pan tool: pan the viewport
        final delta = details.focalPoint - _lastPanPosition!;
        widget.viewportController!.pan(delta);
        _lastPanPosition = details.focalPoint;
      } else if (widget.activeTool == CanvasTool.select) {
        // Select tool: drag shape/media or update selection box
        final worldPos = _screenToWorld(details.focalPoint);

        if (_draggedShapeId != null && _selectDragCurrent != null) {
          // Drag shape(s) - calculate delta from last position
          final delta = worldPos - _selectDragCurrent!;
          _selectDragCurrent = worldPos;

          if (widget.shapeManager.selectedShapeIds.contains(_draggedShapeId)) {
            widget.shapeManager.moveSelectedShapes(delta);
          } else {
            widget.shapeManager.moveShape(_draggedShapeId!, delta);
          }
        } else if (_draggedMediaId != null && _selectDragCurrent != null) {
          // Drag media - calculate delta from last position
          final delta = worldPos - _selectDragCurrent!;
          _selectDragCurrent = worldPos;

          final media = widget.mediaManager.selectedMedia;
          if (media != null) {
            final newPosition = media.position + delta;
            widget.mediaManager.updateMediaPosition(media.id, newPosition);
          }
        } else if (_selectBoxStart != null) {
          // Update selection box
          setState(() {
            _selectBoxEnd = worldPos;
          });
        }
      } else if (widget.activeTool == CanvasTool.editor) {
        // Editor tool: handle resizing or dragging
        final worldPos = _screenToWorld(details.focalPoint);

        if (_isResizing &&
            _resizingObjectId != null &&
            _resizeStartPosition != null &&
            _resizeStartSize != null &&
            _activeResizeHandle != null) {
          // Handle resizing
          _handleResize(worldPos);
        } else if (_draggedShapeId != null && _selectDragCurrent != null) {
          // Drag shape
          final delta = worldPos - _selectDragCurrent!;
          _selectDragCurrent = worldPos;
          widget.shapeManager.moveShape(_draggedShapeId!, delta);
        } else if (_draggedMediaId != null && _selectDragCurrent != null) {
          // Drag media
          final delta = worldPos - _selectDragCurrent!;
          _selectDragCurrent = worldPos;
          final media = widget.mediaManager.selectedMedia;
          if (media != null) {
            final newPosition = media.position + delta;
            widget.mediaManager.updateMediaPosition(media.id, newPosition);
          }
        }
      }
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _initialScale = 1.0;
    _lastPanPosition = null;

    // Finalize tool operations
    if (widget.activeTool == CanvasTool.select) {
      if (_selectBoxStart != null && _selectBoxEnd != null) {
        // Finalize multi-select
        final rect = Rect.fromPoints(_selectBoxStart!, _selectBoxEnd!);
        widget.shapeManager.selectShapesInRect(rect);
        widget.mediaManager.selectMediaInRect(rect);
      }

      setState(() {
        _draggedShapeId = null;
        _draggedMediaId = null;
        _selectBoxStart = null;
        _selectBoxEnd = null;
        _selectDragCurrent = null;
      });
    } else if (widget.activeTool == CanvasTool.editor) {
      // Finalize editor tool operations
      setState(() {
        _isResizing = false;
        _resizingObjectId = null;
        _resizeStartPosition = null;
        _resizeStartSize = null;
        _activeResizeHandle = null;
        _draggedShapeId = null;
        _draggedMediaId = null;
        _selectDragCurrent = null;
      });
    }
  }

  Widget? _buildInlineTextEditor() {
    final shape = widget.shapeManager.getShape(_editingShapeId!);
    if (shape == null) return null;

    // Convert world coordinates to screen coordinates
    final screenPos = _worldToScreen(shape.position);
    final screenSize = widget.viewportController != null
        ? Size(
            shape.size.width * widget.viewportController!.scale,
            shape.size.height * widget.viewportController!.scale,
          )
        : shape.size;

    return Positioned(
      left: screenPos.dx,
      top: screenPos.dy,
      width: screenSize.width,
      height: screenSize.height,
      child: Material(
        color: Colors.transparent,
        child: TextField(
          controller: _textController,
          focusNode: _textFocusNode,
          autofocus: true,
          maxLines: null,
          maxLength: 100, // ✅ MASTER PROMPT: Enforce max character length
          textAlign: TextAlign.center,
          style: TextStyle(
            color: widget.themeManager.currentTheme.textColor,
            fontSize: widget.viewportController != null
                ? 14 * widget.viewportController!.scale
                : 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(8),
            isDense: true,
            hintText: 'Enter text...',
            hintStyle: TextStyle(
              color: widget.themeManager.currentTheme.textColor.withValues(
                alpha: 0.3,
              ),
            ),
            counterText: '', // Hide character counter
          ),
          onSubmitted: (value) {
            _stopTextEditing(saveText: true);
          },
          onEditingComplete: () {
            _stopTextEditing(saveText: true);
          },
        ),
      ),
    );
  }

  Widget _buildSelectionBox(CanvasTheme theme) {
    if (_selectBoxStart == null || _selectBoxEnd == null) {
      return const SizedBox.shrink();
    }

    // Convert world coordinates to screen coordinates
    final screenStart = _worldToScreen(_selectBoxStart!);
    final screenEnd = _worldToScreen(_selectBoxEnd!);

    final rect = Rect.fromPoints(screenStart, screenEnd);

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.accentColor.withValues(alpha: 0.5),
              width: 2,
            ),
            color: theme.accentColor.withValues(alpha: 0.1),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // GESTURE HANDLERS
  // ============================================================================

  void _handleTapDown(TapDownDetails details) {
    final position = _screenToWorld(details.localPosition);

    switch (widget.activeTool) {
      case CanvasTool.select:
        // Close text editor if open when switching to select tool
        if (_editingShapeId != null) {
          _stopTextEditing(saveText: true);
        }
        _handleSelectTap(position);
        break;
      case CanvasTool.editor:
        // Editor tool: select object for editing (shapes or media)
        // Note: Text editing can be done via EditToolPanel OR inline editor (double-click)
        final shape = widget.shapeManager.getShapeAtPosition(position);
        final media = widget.mediaManager.getMediaAtPosition(position);

        if (shape != null) {
          widget.shapeManager.selectShape(shape.id);
          widget.mediaManager.clearSelection();
          // Close inline editor if open (EditToolPanel will handle text editing)
          if (_editingShapeId != null) {
            _stopTextEditing(saveText: true);
          }
          // Don't auto-open inline editor - user can double-click if they want inline editing
          // EditToolPanel provides text editing via the panel
        } else if (media != null) {
          widget.mediaManager.selectMedia(media.id);
          widget.shapeManager.clearSelection();
          // Close inline editor if open
          if (_editingShapeId != null) {
            _stopTextEditing(saveText: true);
          }
        } else {
          // Clicked outside - deselect all
          widget.shapeManager.clearSelection();
          widget.mediaManager.clearSelection();
          if (_editingShapeId != null) {
            _stopTextEditing(saveText: true);
          }
        }
        break;
      case CanvasTool.shapes:
        // Close text editor if open when switching to shapes tool
        if (_editingShapeId != null) {
          _stopTextEditing(saveText: true);
        }
        _handleShapeCreation(position);
        break;
      case CanvasTool.node:
      case CanvasTool.connector:
        // Compatibility: node/connector behave like shapes
        if (_editingShapeId != null) {
          _stopTextEditing(saveText: true);
        }
        _handleShapeCreation(position);
        break;
      case CanvasTool.text:
        // Compatibility: text tool should start inline editing when possible
        if (_editingShapeId != null) {
          _stopTextEditing(saveText: true);
        }
        final target = widget.shapeManager.getShapeAtPosition(position);
        if (target != null && target.isTextEditable) {
          _startInlineTextEditing(target.id);
        } else {
          // No editable target: clear selection to be conservative
          widget.shapeManager.clearSelection();
          widget.mediaManager.clearSelection();
        }
        break;
      case CanvasTool.eraser:
        // Close text editor if open when switching to eraser tool
        if (_editingShapeId != null) {
          _stopTextEditing(saveText: true);
        }
        _handleEraserTap(position);
        break;
      case CanvasTool.media:
        // Place emoji or image on canvas
        _handleMediaPlacement(position);
        break;
      case CanvasTool.pan:
        // Close text editor if open when switching to pan tool
        if (_editingShapeId != null) {
          _stopTextEditing(saveText: true);
        }
        // Pan is handled in onScaleStart/Update/End
        break;
      case CanvasTool.settings:
        // Settings handled by toolbar
        break;
    }
  }

  void _handleDoubleTapAtPosition(Offset position) {
    // Text editing only works when editor tool is active
    if (widget.activeTool != CanvasTool.editor) return;

    final worldPos = _screenToWorld(position);
    final shape = widget.shapeManager.getShapeAtPosition(worldPos);

    // ✅ MASTER PROMPT: Only allow text editing on text-editable shapes
    if (shape != null && shape.isTextEditable) {
      _startInlineTextEditing(shape.id);
    }
  }

  // ============================================================================
  // INTERACTION HANDLERS
  // ============================================================================

  void _handleSelectTap(Offset position) {
    // Try to select media first (rendered on top), then shapes
    final media = widget.mediaManager.getMediaAtPosition(position);
    final shape = widget.shapeManager.getShapeAtPosition(position);

    if (media != null) {
      widget.mediaManager.selectMedia(media.id);
      widget.shapeManager.clearSelection();
    } else if (shape != null) {
      widget.shapeManager.selectShape(shape.id);
      widget.mediaManager.clearSelection();
    } else {
      widget.shapeManager.clearSelection();
      widget.mediaManager.clearSelection();
    }
  }

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

    CanvasShape shape;
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
      case ShapeType.pill:
        shape = CanvasShape.createPill(constrainedPosition, theme.accentColor);
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

    // ✅ MASTER PROMPT: Start inline text editing only for text-editable shapes and when editor tool is active
    if (shape.isTextEditable && widget.activeTool == CanvasTool.editor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startInlineTextEditing(shape.id);
      });
    }
  }

  void _handleEraserTap(Offset position) {
    // Try to erase media first (rendered on top), then shapes
    final media = widget.mediaManager.getMediaAtPosition(position);
    if (media != null) {
      widget.mediaManager.removeMedia(media.id);
      return;
    }

    final shape = widget.shapeManager.getShapeAtPosition(position);
    if (shape != null) {
      widget.shapeManager.removeShape(shape.id);
    }
  }

  void _handleMediaPlacement(Offset position) {
    // Use selected emoji/image from widget props (set by media panel callbacks)
    final emoji = widget.selectedEmoji;
    final image = widget.selectedImage;

    if (emoji == null && image == null) {
      // Nothing selected - show helpful message
      if (_canvasBuildContext != null && mounted) {
        _showPlacementHint(_canvasBuildContext!);
      }
      return;
    }

    final snappedPosition = widget.snapToGrid
        ? _snapPositionToGrid(position)
        : position;

    if (emoji != null) {
      final constrainedPosition = _constrainToBounds(
        snappedPosition,
        const Size(64, 64),
      );
      final emojiMedia = CanvasMedia.createEmoji(
        constrainedPosition,
        emoji,
        size: 64.0,
      );
      widget.mediaManager.addMedia(emojiMedia);
      if (_canvasBuildContext != null && mounted) {
        _showPlacementSuccess(_canvasBuildContext!, 'Emoji placed');
      }
      // Keep emoji selected for multiple placements (don't clear)
    } else if (image != null) {
      try {
        // Constrain based on image size (with max limits)
        final maxSize = Size(
          image.size.width.clamp(32, 500),
          image.size.height.clamp(32, 500),
        );
        final constrainedPosition = _constrainToBounds(
          snappedPosition,
          maxSize,
        );

        // Use the original image size as intrinsic size for accurate border rendering
        final intrinsicSize = image.size;

        final media = image.isSvg
            ? CanvasMedia.createSvg(
                constrainedPosition,
                image.imageData,
                maxSize,
                image.filePath,
                intrinsicSize: intrinsicSize,
              )
            : CanvasMedia.createImage(
                constrainedPosition,
                image.imageData,
                maxSize,
                image.filePath,
                intrinsicSize: intrinsicSize,
              );
        widget.mediaManager.addMedia(media);
        if (_canvasBuildContext != null && mounted) {
          _showPlacementSuccess(_canvasBuildContext!, 'Image placed on canvas');
        }
      } catch (e) {
        if (_canvasBuildContext != null && mounted) {
          _showPlacementError(
            _canvasBuildContext!,
            'Failed to place image: $e',
          );
        }
      }
      // Keep image selected for multiple placements (don't clear)
    }
  }

  void _showPlacementSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade900,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showPlacementError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade900,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showPlacementHint(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Select an emoji or import an image first',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade900,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _startInlineTextEditing(String shapeId) {
    final shape = widget.shapeManager.getShape(shapeId);
    // ✅ MASTER PROMPT: Only allow text editing on text-editable shapes
    if (shape == null || !shape.isTextEditable) return;

    setState(() {
      _editingShapeId = shapeId;
      _textController.text = shape.text;
    });

    // Focus the text field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textFocusNode.requestFocus();
      _textController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _textController.text.length,
      );
    });
  }

  void _stopTextEditing({bool saveText = true}) {
    if (_editingShapeId == null) return;

    if (saveText && _editingShapeId != null) {
      widget.shapeManager.updateShapeText(
        _editingShapeId!,
        _textController.text,
      );
    }

    setState(() {
      _editingShapeId = null;
    });
    _textFocusNode.unfocus();
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  Offset _screenToWorld(Offset screenPoint) {
    if (widget.viewportController != null) {
      return widget.viewportController!.screenToWorld(screenPoint, _canvasSize);
    }
    return screenPoint;
  }

  Offset _worldToScreen(Offset worldPoint) {
    if (widget.viewportController != null) {
      return widget.viewportController!.worldToScreen(worldPoint, _canvasSize);
    }
    return worldPoint;
  }

  Offset _snapPositionToGrid(Offset position) {
    final spacing = widget.gridSpacing;
    final x = (position.dx / spacing).round() * spacing;
    final y = (position.dy / spacing).round() * spacing;
    return Offset(x, y);
  }

  Offset _constrainToBounds(Offset position, Size shapeSize) {
    if (_canvasSize.isEmpty) return position;

    final maxX = _canvasSize.width - shapeSize.width;
    final maxY = _canvasSize.height - shapeSize.height;

    return Offset(position.dx.clamp(0, maxX), position.dy.clamp(0, maxY));
  }

  // ============================================================================
  // RESIZE HANDLES
  // ============================================================================

  /// Get resize handle at position (for shapes)
  ResizeHandle? _getResizeHandleAtPosition(CanvasShape shape, Offset position) {
    if (!shape.isSelected) return null;

    const handleSize = 8.0;
    final rect = Rect.fromLTWH(
      shape.position.dx,
      shape.position.dy,
      shape.size.width,
      shape.size.height,
    );

    // Check each corner and edge
    final handles = [
      (ResizeHandle.topLeft, Offset(rect.left, rect.top)),
      (ResizeHandle.topRight, Offset(rect.right, rect.top)),
      (ResizeHandle.bottomLeft, Offset(rect.left, rect.bottom)),
      (ResizeHandle.bottomRight, Offset(rect.right, rect.bottom)),
      (ResizeHandle.top, Offset(rect.center.dx, rect.top)),
      (ResizeHandle.bottom, Offset(rect.center.dx, rect.bottom)),
      (ResizeHandle.left, Offset(rect.left, rect.center.dy)),
      (ResizeHandle.right, Offset(rect.right, rect.center.dy)),
    ];

    for (final (handle, handlePos) in handles) {
      if ((position - handlePos).distance < handleSize) {
        return handle;
      }
    }

    return null;
  }

  /// Get resize handle at position (for media)
  ResizeHandle? _getResizeHandleAtPositionForMedia(
    CanvasMedia media,
    Offset position,
  ) {
    if (!media.isSelected) return null;

    const handleSize = 8.0;
    final rect = Rect.fromLTWH(
      media.position.dx,
      media.position.dy,
      media.size.width,
      media.size.height,
    );

    // Check each corner and edge
    final handles = [
      (ResizeHandle.topLeft, Offset(rect.left, rect.top)),
      (ResizeHandle.topRight, Offset(rect.right, rect.top)),
      (ResizeHandle.bottomLeft, Offset(rect.left, rect.bottom)),
      (ResizeHandle.bottomRight, Offset(rect.right, rect.bottom)),
      (ResizeHandle.top, Offset(rect.center.dx, rect.top)),
      (ResizeHandle.bottom, Offset(rect.center.dx, rect.bottom)),
      (ResizeHandle.left, Offset(rect.left, rect.center.dy)),
      (ResizeHandle.right, Offset(rect.right, rect.center.dy)),
    ];

    for (final (handle, handlePos) in handles) {
      if ((position - handlePos).distance < handleSize) {
        return handle;
      }
    }

    return null;
  }

  /// Handle resize operation
  void _handleResize(Offset currentPosition) {
    if (_resizingObjectId == null ||
        _resizeStartPosition == null ||
        _resizeStartSize == null ||
        _activeResizeHandle == null) {
      return;
    }

    final delta = currentPosition - _resizeStartPosition!;
    final newSize = _calculateNewSize(
      _resizeStartSize!,
      delta,
      _activeResizeHandle!,
    );

    // Apply minimum size constraints
    final minSize = const Size(20, 20);
    final constrainedSize = Size(
      newSize.width.clamp(minSize.width, double.infinity),
      newSize.height.clamp(minSize.height, double.infinity),
    );

    // Update shape or media
    final shape = widget.shapeManager.getShape(_resizingObjectId!);
    if (shape != null) {
      widget.shapeManager.updateShape(
        _resizingObjectId!,
        shape.copyWith(size: constrainedSize),
      );
    } else {
      final media = widget.mediaManager.mediaItems.firstWhere(
        (m) => m.id == _resizingObjectId,
        orElse: () => widget.mediaManager.mediaItems.first,
      );
      if (media.id == _resizingObjectId) {
        widget.mediaManager.updateMediaSize(
          _resizingObjectId!,
          constrainedSize,
        );
      }
    }
  }

  /// Calculate new size based on resize handle and delta
  Size _calculateNewSize(Size startSize, Offset delta, ResizeHandle handle) {
    double newWidth = startSize.width;
    double newHeight = startSize.height;

    switch (handle) {
      case ResizeHandle.topLeft:
        newWidth = startSize.width - delta.dx;
        newHeight = startSize.height - delta.dy;
        break;
      case ResizeHandle.topRight:
        newWidth = startSize.width + delta.dx;
        newHeight = startSize.height - delta.dy;
        break;
      case ResizeHandle.bottomLeft:
        newWidth = startSize.width - delta.dx;
        newHeight = startSize.height + delta.dy;
        break;
      case ResizeHandle.bottomRight:
        newWidth = startSize.width + delta.dx;
        newHeight = startSize.height + delta.dy;
        break;
      case ResizeHandle.top:
        newHeight = startSize.height - delta.dy;
        break;
      case ResizeHandle.bottom:
        newHeight = startSize.height + delta.dy;
        break;
      case ResizeHandle.left:
        newWidth = startSize.width - delta.dx;
        break;
      case ResizeHandle.right:
        newWidth = startSize.width + delta.dx;
        break;
    }

    return Size(newWidth, newHeight);
  }

  /// Build resize handles overlay
  Widget _buildResizeHandles(CanvasTheme theme) {
    if (widget.activeTool != CanvasTool.editor) {
      return const SizedBox.shrink();
    }

    final shape = widget.shapeManager.selectedShapes.isNotEmpty
        ? widget.shapeManager.selectedShapes.first
        : null;
    final media = widget.mediaManager.selectedMedia;

    if (shape == null && media == null) {
      return const SizedBox.shrink();
    }

    final rect = shape != null
        ? Rect.fromLTWH(
            shape.position.dx,
            shape.position.dy,
            shape.size.width,
            shape.size.height,
          )
        : Rect.fromLTWH(
            media!.position.dx,
            media.position.dy,
            media.size.width,
            media.size.height,
          );

    // Convert to screen coordinates
    final screenRect = Rect.fromLTWH(
      _worldToScreen(rect.topLeft).dx,
      _worldToScreen(rect.topLeft).dy,
      rect.width * (widget.viewportController?.scale ?? 1.0),
      rect.height * (widget.viewportController?.scale ?? 1.0),
    );

    const handleSize = 8.0;
    final handles = [
      (ResizeHandle.topLeft, Offset(screenRect.left, screenRect.top)),
      (ResizeHandle.topRight, Offset(screenRect.right, screenRect.top)),
      (ResizeHandle.bottomLeft, Offset(screenRect.left, screenRect.bottom)),
      (ResizeHandle.bottomRight, Offset(screenRect.right, screenRect.bottom)),
      (ResizeHandle.top, Offset(screenRect.center.dx, screenRect.top)),
      (ResizeHandle.bottom, Offset(screenRect.center.dx, screenRect.bottom)),
      (ResizeHandle.left, Offset(screenRect.left, screenRect.center.dy)),
      (ResizeHandle.right, Offset(screenRect.right, screenRect.center.dy)),
    ];

    return Stack(
      children: handles.map((handle) {
        return Positioned(
          left: handle.$2.dx - handleSize / 2,
          top: handle.$2.dy - handleSize / 2,
          width: handleSize,
          height: handleSize,
          child: Container(
            decoration: BoxDecoration(
              color: theme.accentColor,
              border: Border.all(color: Colors.white, width: 1),
              borderRadius: BorderRadius.circular(handleSize / 2),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMediaWidget(CanvasMedia media, CanvasTheme theme) {
    // Convert world coordinates to screen coordinates
    final screenPos = _worldToScreen(media.position);
    final screenSize = widget.viewportController != null
        ? Size(
            media.size.width * widget.viewportController!.scale,
            media.size.height * widget.viewportController!.scale,
          )
        : media.size;

    // Calculate the actual rendered image size based on BoxFit.contain
    // This ensures the border fits tightly around the image, not the container
    Size? renderedImageSize;
    Offset? imageOffset;

    if (media.type == MediaType.image || media.type == MediaType.svg) {
      final intrinsicSize = media.intrinsicSize ?? media.size;
      if (intrinsicSize.width > 0 && intrinsicSize.height > 0) {
        final containerAspect = screenSize.width / screenSize.height;
        final imageAspect = intrinsicSize.width / intrinsicSize.height;

        if (imageAspect > containerAspect) {
          // Image is wider - fit to width
          renderedImageSize = Size(
            screenSize.width,
            screenSize.width / imageAspect,
          );
          imageOffset = Offset(
            0,
            (screenSize.height - renderedImageSize.height) / 2,
          );
        } else {
          // Image is taller - fit to height
          renderedImageSize = Size(
            screenSize.height * imageAspect,
            screenSize.height,
          );
          imageOffset = Offset(
            (screenSize.width - renderedImageSize.width) / 2,
            0,
          );
        }
      } else {
        // Fallback: use container size
        renderedImageSize = screenSize;
        imageOffset = Offset.zero;
      }
    } else {
      // Emoji fills the container
      renderedImageSize = screenSize;
      imageOffset = Offset.zero;
    }

    Widget content;
    switch (media.type) {
      case MediaType.emoji:
        // Render emoji as text
        content = Center(
          child: Text(
            media.emoji ?? '',
            style: TextStyle(fontSize: screenSize.height * 0.8),
            textAlign: TextAlign.center,
          ),
        );
        break;
      case MediaType.image:
      case MediaType.svg:
        // Render image using Image.memory
        content = Image.memory(
          media.imageData!,
          width: screenSize.width,
          height: screenSize.height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: screenSize.width,
              height: screenSize.height,
              color: theme.borderColor.withValues(alpha: 0.1),
              child: Icon(
                Icons.broken_image,
                color: theme.textColor.withValues(alpha: 0.3),
                size: 24,
              ),
            );
          },
        );
        break;
    }

    // Determine if we should show a border and what style
    final showBorder = media.isSelected || media.showBorder;
    final borderWidth = media.isSelected ? 2.0 : 0.5; // Thinner borders
    final borderColor = media.isSelected
        ? theme.accentColor
        : theme.borderColor.withValues(
            alpha: 0.15,
          ); // Very subtle default border
    final borderRadius = BorderRadius.circular(
      1,
    ); // Minimal radius for tight fit

    return Positioned(
      left: screenPos.dx,
      top: screenPos.dy,
      width: screenSize.width,
      height: screenSize.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Image content
          content,
          // Border - only around the actual rendered image size
          if (showBorder)
            Positioned(
              left: imageOffset.dx,
              top: imageOffset.dy,
              width: renderedImageSize.width,
              height: renderedImageSize.height,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor, width: borderWidth),
                  borderRadius: borderRadius,
                ),
              ),
            ),
          // Note indicator badge (top-right corner, positioned relative to actual image)
          if (media.notes.isNotEmpty)
            Positioned(
              top: imageOffset.dy + 4,
              right:
                  screenSize.width -
                  (imageOffset.dx + renderedImageSize.width) +
                  4,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: theme.accentColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'N',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Helper class to represent canvas objects (shapes or media) for z-ordering
class _CanvasObject {
  final CanvasShape? shape;
  final CanvasMedia? media;
  final int zIndex;
  final bool isShape;

  _CanvasObject.shape(this.shape)
    : media = null,
      isShape = true,
      zIndex = shape!.zIndex;

  _CanvasObject.media(this.media)
    : shape = null,
      isShape = false,
      zIndex = media!.zIndex;
}

/// Painter for a batch of shapes at a specific z-index level
class _ShapeLayerPainter extends CustomPainter {
  final List<CanvasShape> shapes;
  final CanvasTheme theme;
  final ViewportController? viewportController;

  _ShapeLayerPainter({
    required this.shapes,
    required this.theme,
    this.viewportController,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Apply viewport transform if available
    if (viewportController != null) {
      canvas.save();
      canvas.transform(viewportController!.transform.storage);
    }

    // Draw shapes
    if (shapes.isNotEmpty) {
      final shapePainter = ShapePainter(shapes: shapes, theme: theme);
      shapePainter.paint(canvas, size);
    }

    // Restore canvas
    if (viewportController != null) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ShapeLayerPainter oldDelegate) {
    return oldDelegate.shapes != shapes || oldDelegate.theme != theme;
  }
}

// Legacy _ShapeCanvasPainter removed because it's unused in the current
// codepaths. Keeping the implementation in repository history if needed.
