import 'package:flutter/material.dart';
import '../theme_manager.dart';
import '../models/canvas_shape.dart';
import '../models/canvas_media.dart';

/// EditToolPanel: Quick toolbar for editing selected objects (shapes/media)
/// Appears when Edit Tool is active and an object is selected
class EditToolPanel extends StatefulWidget {
  final ThemeManager themeManager;
  final CanvasShape? selectedShape;
  final CanvasMedia? selectedMedia;
  final Function(String notes) onNotesChanged;
  final Function(String text) onTextChanged;
  final Function(double scale) onScaleChanged;
  final Function(bool showBorder) onBorderToggled;

  const EditToolPanel({
    super.key,
    required this.themeManager,
    this.selectedShape,
    this.selectedMedia,
    required this.onNotesChanged,
    required this.onTextChanged,
    required this.onScaleChanged,
    required this.onBorderToggled,
  });

  @override
  State<EditToolPanel> createState() => _EditToolPanelState();
}

class _EditToolPanelState extends State<EditToolPanel> {
  double _baseScale = 1.0;
  Size? _originalSize;

  // Text editing controllers (stateful to preserve focus and cursor position)
  TextEditingController? _textController;
  TextEditingController? _notesController;
  String? _currentShapeId; // Track which shape we're editing
  // Track which media we're editing. May be updated but not referenced
  // elsewhere yet; suppress analyzer noise.
  // ignore: unused_field
  String? _currentMediaId; // Track which media we're editing

  @override
  void initState() {
    super.initState();
    _originalSize = widget.selectedShape?.size ?? widget.selectedMedia?.size;
    // Calculate initial scale if size exists
    if (_originalSize != null) {
      _baseScale = 1.0;
    }

    // Initialize text controllers
    _initializeControllers();
  }

  void _initializeControllers() {
    final shape = widget.selectedShape;
    final media = widget.selectedMedia;

    // Initialize text controller for shapes
    if (shape != null && shape.isTextEditable) {
      _textController?.dispose();
      _textController = TextEditingController(text: shape.text);
      _currentShapeId = shape.id;
    } else {
      _textController?.dispose();
      _textController = null;
      _currentShapeId = null;
    }

    // Initialize notes controller
    final notes = shape?.notes ?? media?.notes ?? '';
    _notesController?.dispose();
    _notesController = TextEditingController(text: notes);

    if (media != null) {
      _currentMediaId = media.id;
    } else {
      _currentMediaId = null;
    }
  }

  @override
  void didUpdateWidget(EditToolPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if selection changed
    final selectionChanged =
        oldWidget.selectedShape?.id != widget.selectedShape?.id ||
        oldWidget.selectedMedia?.id != widget.selectedMedia?.id;

    // Reset scale when selection changes
    if (selectionChanged) {
      _originalSize = widget.selectedShape?.size ?? widget.selectedMedia?.size;
      _baseScale = 1.0;
      // Reinitialize controllers when selection changes
      _initializeControllers();
    } else {
      // Update original size if it changed externally (e.g., via resize handles)
      final currentSize =
          widget.selectedShape?.size ?? widget.selectedMedia?.size;
      if (currentSize != null && _originalSize != null) {
        // Check if size changed significantly (not just from our scaling)
        // If the ratio changed, it means resize handles were used, so reset
        final currentRatio = currentSize.width / currentSize.height;
        final originalRatio = _originalSize!.width / _originalSize!.height;
        if ((currentRatio - originalRatio).abs() > 0.01) {
          // Aspect ratio changed, reset original size
          _originalSize = currentSize;
          _baseScale = 1.0;
        } else {
          // Update scale based on current size vs original
          if (_originalSize!.width > 0 && _originalSize!.height > 0) {
            final scaleX = currentSize.width / _originalSize!.width;
            final scaleY = currentSize.height / _originalSize!.height;
            _baseScale = (scaleX + scaleY) / 2; // Average scale
          }
        }
      }

      // Sync text controller with shape text if it changed externally (e.g., from inline editor)
      // But only if the controller is not currently focused (to avoid cursor jumping while typing)
      final shape = widget.selectedShape;
      if (shape != null && shape.isTextEditable && _textController != null) {
        if (shape.id == _currentShapeId) {
          // Only sync if text changed externally AND controller is not focused
          // This prevents cursor jumping while user is typing in EditToolPanel
          final hasFocus =
              _textController!.selection.isValid &&
              _textController!.selection.baseOffset >= 0;
          if (!hasFocus && shape.text != _textController!.text) {
            // Text changed externally (e.g., from inline editor), update controller
            _textController!.text = shape.text;
            _textController!.selection = TextSelection.collapsed(
              offset: shape.text.length,
            );
          }
        }
      }

      // Sync notes controller if notes changed externally (only when not focused)
      final notes = shape?.notes ?? widget.selectedMedia?.notes ?? '';
      if (_notesController != null) {
        final hasFocus =
            _notesController!.selection.isValid &&
            _notesController!.selection.baseOffset >= 0;
        if (!hasFocus && notes != _notesController!.text) {
          _notesController!.text = notes;
          _notesController!.selection = TextSelection.collapsed(
            offset: notes.length,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _textController?.dispose();
    _notesController?.dispose();
    super.dispose();
  }

  bool get hasSelection =>
      widget.selectedShape != null || widget.selectedMedia != null;
  bool get isShape => widget.selectedShape != null;
  bool get isMedia => widget.selectedMedia != null;
  bool get isTextEditable => widget.selectedShape?.isTextEditable ?? false;

  @override
  Widget build(BuildContext context) {
    if (!hasSelection) {
      return const SizedBox.shrink();
    }

    // Calculate current scale based on original size
    final currentSize = isShape
        ? widget.selectedShape!.size
        : widget.selectedMedia!.size;
    if (_originalSize != null &&
        _originalSize!.width > 0 &&
        _originalSize!.height > 0) {
      final scaleX = currentSize.width / _originalSize!.width;
      final scaleY = currentSize.height / _originalSize!.height;
      final avgScale = (scaleX + scaleY) / 2;
      // Only update if significantly different (avoid jitter)
      if ((avgScale - _baseScale).abs() > 0.01) {
        setState(() {
          _baseScale = avgScale;
        });
      }
    } else {
      _originalSize = currentSize;
      _baseScale = 1.0;
    }

    return AnimatedBuilder(
      animation: widget.themeManager,
      builder: (context, _) {
        final theme = widget.themeManager.currentTheme;

        // Get current values directly from selected object (always up-to-date)
        // These are passed from parent which listens to managers
        final currentText = isShape && widget.selectedShape!.isTextEditable
            ? widget.selectedShape!.text
            : '';
        final currentNotes = isShape
            ? widget.selectedShape!.notes
            : widget.selectedMedia!.notes;
        final showBorder = isShape
            ? widget.selectedShape!.showBorder
            : widget.selectedMedia!.showBorder;

        // Sync controllers with current values (only update if not focused to avoid cursor jumping)
        // This ensures the TextField shows the correct text even if it changed externally
        if (_textController != null && _textController!.text != currentText) {
          // Only sync if the controller is not currently being edited
          // We check this by seeing if the text length matches what we expect
          // A more sophisticated check would use FocusNode, but this works for now
          final cursorPosition = _textController!.selection.baseOffset;
          final wasAtEnd = cursorPosition >= _textController!.text.length - 1;

          // If cursor was at the end, it's likely the user finished typing
          // If text changed externally, update the controller
          if (wasAtEnd || currentText.isEmpty) {
            _textController!.text = currentText;
            _textController!.selection = TextSelection.collapsed(
              offset: currentText.length,
            );
          }
        }

        if (_notesController != null &&
            _notesController!.text != currentNotes) {
          // Similar logic for notes
          final cursorPosition = _notesController!.selection.baseOffset;
          final wasAtEnd = cursorPosition >= _notesController!.text.length - 1;

          if (wasAtEnd || currentNotes.isEmpty) {
            _notesController!.text = currentNotes;
            _notesController!.selection = TextSelection.collapsed(
              offset: currentNotes.length,
            );
          }
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320, minWidth: 280),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.panelColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.borderColor.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      color: theme.accentColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Edit ${isShape ? "Shape" : "Media"}',
                      style: TextStyle(
                        color: theme.textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Size/Scale Section
                Text(
                  'Size',
                  style: TextStyle(
                    color: theme.textColor.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Width: ${currentSize.width.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: theme.textColor.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Height: ${currentSize.height.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: theme.textColor.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Scale slider (starts at 1.0, represents multiplier)
                Row(
                  children: [
                    Icon(
                      Icons.zoom_out,
                      size: 16,
                      color: theme.textColor.withValues(alpha: 0.7),
                    ),
                    Expanded(
                      child: Slider(
                        value: _baseScale,
                        min: 0.5,
                        max: 2.0,
                        divisions: 30,
                        label: '${(_baseScale * 100).toStringAsFixed(0)}%',
                        onChanged: (value) {
                          setState(() {
                            _baseScale = value;
                          });
                          // Apply scale relative to original size
                          widget.onScaleChanged(value);
                        },
                        activeColor: theme.accentColor,
                      ),
                    ),
                    Icon(
                      Icons.zoom_in,
                      size: 16,
                      color: theme.textColor.withValues(alpha: 0.7),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Text Editing (for text-editable shapes)
                if (isShape && isTextEditable) ...[
                  Text(
                    'Text',
                    style: TextStyle(
                      color: theme.textColor.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_textController != null)
                    TextField(
                      controller: _textController,
                      onChanged: (text) {
                        // Update shape text immediately as user types
                        widget.onTextChanged(text);
                      },
                      maxLength: 100,
                      style: TextStyle(color: theme.textColor, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Enter text...',
                        hintStyle: TextStyle(
                          color: theme.textColor.withValues(alpha: 0.4),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: theme.borderColor.withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: theme.borderColor.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: theme.accentColor,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: theme.backgroundColor.withValues(alpha: 0.3),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        counterText: '',
                      ),
                    ),
                  const SizedBox(height: 16),
                ],

                // Notes Section
                Text(
                  'Notes',
                  style: TextStyle(
                    color: theme.textColor.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (_notesController != null)
                  TextField(
                    controller: _notesController,
                    onChanged: (notes) {
                      // Update notes immediately as user types
                      widget.onNotesChanged(notes);
                    },
                    maxLines: 3,
                    maxLength: 500,
                    style: TextStyle(color: theme.textColor, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Add notes or annotations...',
                      hintStyle: TextStyle(
                        color: theme.textColor.withValues(alpha: 0.4),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: theme.borderColor.withValues(alpha: 0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: theme.borderColor.withValues(alpha: 0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: theme.accentColor,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: theme.backgroundColor.withValues(alpha: 0.3),
                      contentPadding: const EdgeInsets.all(12),
                      counterText: '',
                    ),
                  ),
                const SizedBox(height: 16),

                // Border Toggle
                Row(
                  children: [
                    Checkbox(
                      value: showBorder,
                      onChanged: (value) {
                        if (value != null) {
                          widget.onBorderToggled(value);
                        }
                      },
                      activeColor: theme.accentColor,
                      checkColor: Colors.white,
                    ),
                    Expanded(
                      child: Text(
                        'Show Border',
                        style: TextStyle(
                          color: theme.textColor.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
