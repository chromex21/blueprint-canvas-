import 'package:flutter/material.dart';
import '../theme_manager.dart';
import '../managers/node_manager.dart';
import '../widgets/node_editor_dialog.dart';

/// CanvasOverlayManager: Manages temporary overlay widgets for editing
/// 
/// This ensures that overlay widgets are only spawned when actively editing,
/// and are properly synchronized with the underlying data.
class CanvasOverlayManager {
  final BuildContext context;
  final ThemeManager themeManager;
  final NodeManager nodeManager;

  CanvasOverlayManager({
    required this.context,
    required this.themeManager,
    required this.nodeManager,
  });

  /// Show node editor overlay for text/content editing
  /// OPTIMIZATION: Uses barrierDismissible and ensures dialog doesn't block canvas rendering
  /// 
  /// ✅ MASTER PROMPT: Only Rectangle, RoundedRectangle, and Pill shapes are text-editable
  Future<String?> showNodeEditor({
    required String nodeId,
    required Offset canvasPosition,
    required Size canvasSize,
  }) async {
    final node = nodeManager.getNode(nodeId);
    if (node == null) return null;

    // ✅ MASTER PROMPT: Check if node type supports text editing
    if (!node.isTextEditable) {
      // Show info message for non-text-editable shapes
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This shape type does not support text editing. Only Rectangle, RoundedRectangle, and Pill shapes can contain text.',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: themeManager.currentTheme.accentColor,
          duration: const Duration(seconds: 2),
        ),
      );
      return null;
    }

    // Show dialog as overlay
    // Note: Using barrierDismissible: true allows the canvas to remain interactive
    // The dialog is non-blocking and won't prevent canvas repaints
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54, // Semi-transparent barrier
      builder: (context) => NodeEditorDialog(
        initialContent: node.content,
        theme: themeManager.currentTheme,
      ),
    );

    return result;
  }

  /// Show tool properties overlay (for future use)
  Future<Map<String, dynamic>?> showToolProperties({
    required String toolId,
    required Offset canvasPosition,
    required Map<String, dynamic> currentProperties,
  }) async {
    // TODO: Implement tool properties overlay
    // For now, return null to indicate no changes
    return null;
  }

  /// Show inline text editor overlay (alternative to dialog)
  /// This creates a temporary widget overlay positioned over the node
  Widget? buildInlineTextEditor({
    required String nodeId,
    required Offset nodePosition,
    required Size nodeSize,
    required Offset canvasOffset,
    required Function(String) onSave,
    required VoidCallback onCancel,
  }) {
    final node = nodeManager.getNode(nodeId);
    if (node == null) return null;

    // Calculate screen position
    final screenPosition = Offset(
      canvasOffset.dx + nodePosition.dx,
      canvasOffset.dy + nodePosition.dy,
    );

    // Use TextEditingController instead of initialValue
    final controller = TextEditingController(text: node.content);

    return Positioned(
      left: screenPosition.dx,
      top: screenPosition.dy,
      width: nodeSize.width,
      child: Material(
        color: themeManager.currentTheme.panelColor,
        borderRadius: BorderRadius.circular(8),
        elevation: 8,
        child: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(
            color: themeManager.currentTheme.textColor,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.all(8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: themeManager.currentTheme.accentColor,
                width: 2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: themeManager.currentTheme.accentColor,
                width: 2,
              ),
            ),
          ),
          onSubmitted: (value) {
            onSave(value);
            onCancel();
          },
          onEditingComplete: () {
            // Auto-save on edit complete
          },
        ),
      ),
    );
  }
}

/// OverlayEditingState: Tracks which element is currently being edited
class OverlayEditingState {
  String? editingElementId;
  OverlayType? overlayType;
  Offset? overlayPosition;
  Size? overlaySize;

  bool get isEditing => editingElementId != null;

  void startEditing({
    required String elementId,
    required OverlayType type,
    Offset? position,
    Size? size,
  }) {
    editingElementId = elementId;
    overlayType = type;
    overlayPosition = position;
    overlaySize = size;
  }

  void stopEditing() {
    editingElementId = null;
    overlayType = null;
    overlayPosition = null;
    overlaySize = null;
  }
}

enum OverlayType {
  textEditor,
  propertiesPanel,
  toolConfiguration,
}

