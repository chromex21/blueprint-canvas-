import 'package:flutter/material.dart';
import 'theme_manager.dart';

/// ToolbarButton: Individual tool button for the quick actions toolbar
class ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color accentColor;
  final Color? customColor; // For special buttons like Save & Exit

  const ToolbarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.accentColor,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = customColor ?? accentColor;

    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive
                  ? buttonColor.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive
                    ? buttonColor.withValues(alpha: 0.5)
                    : buttonColor.withValues(alpha: 0.1),
                width: isActive ? 2 : 1,
              ),
            ),
            child: Icon(
              icon,
              color: isActive
                  ? buttonColor
                  : buttonColor.withValues(alpha: 0.6),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

/// QuickActionsToolbar: Main toolbar for canvas tools
class QuickActionsToolbar extends StatefulWidget {
  final ThemeManager themeManager;
  final VoidCallback onSettingsTap;
  final VoidCallback onShapesTool;
  final VoidCallback onMediaTool;
  final VoidCallback? onSaveAndExit; // Optional save & exit callback
  final ValueChanged<CanvasTool> onToolChanged;
  final CanvasTool activeTool;

  const QuickActionsToolbar({
    super.key,
    required this.themeManager,
    required this.onSettingsTap,
    required this.onShapesTool,
    required this.onMediaTool,
    required this.onToolChanged,
    required this.activeTool,
    this.onSaveAndExit,
  });

  @override
  State<QuickActionsToolbar> createState() => _QuickActionsToolbarState();
}

class _QuickActionsToolbarState extends State<QuickActionsToolbar> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.themeManager,
      builder: (context, _) {
        final theme = widget.themeManager.currentTheme;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.backgroundColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.borderColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.construction,
                    size: 16,
                    color: theme.textColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TOOLS',
                    style: TextStyle(
                      color: theme.textColor.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tools Grid
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Save & Exit button (if callback provided)
                  if (widget.onSaveAndExit != null)
                    ToolbarButton(
                      icon: Icons.exit_to_app,
                      label: 'Save & Exit',
                      isActive: false,
                      onTap: widget.onSaveAndExit!,
                      accentColor: theme.accentColor,
                      customColor: Colors.green,
                    ),

                  // Select/Move tool
                  ToolbarButton(
                    icon: Icons.near_me,
                    label: 'Select',
                    isActive: widget.activeTool == CanvasTool.select,
                    onTap: () => widget.onToolChanged(CanvasTool.select),
                    accentColor: theme.accentColor,
                  ),

                  // Add Shapes tool (opens shape selection)
                  ToolbarButton(
                    icon: Icons.shape_line_outlined,
                    label: 'Add Shapes',
                    isActive: widget.activeTool == CanvasTool.shapes,
                    onTap: () {
                      widget.onToolChanged(CanvasTool.shapes);
                      widget.onShapesTool();
                    },
                    accentColor: theme.accentColor,
                  ),

                  // Media import tool (emoji stickers + PNG/SVG files)
                  ToolbarButton(
                    icon: Icons.image_outlined,
                    label: 'Media',
                    isActive: widget.activeTool == CanvasTool.media,
                    onTap: () {
                      widget.onToolChanged(CanvasTool.media);
                      widget.onMediaTool();
                    },
                    accentColor: theme.accentColor,
                  ),

                  // Pan tool (for manually panning the canvas)
                  ToolbarButton(
                    icon: Icons.pan_tool,
                    label: 'Pan',
                    isActive: widget.activeTool == CanvasTool.pan,
                    onTap: () => widget.onToolChanged(CanvasTool.pan),
                    accentColor: theme.accentColor,
                  ),

                  // Text Editor tool
                  ToolbarButton(
                    icon: Icons.edit_note,
                    label: 'Edit Text',
                    isActive: widget.activeTool == CanvasTool.editor,
                    onTap: () => widget.onToolChanged(CanvasTool.editor),
                    accentColor: theme.accentColor,
                  ),

                  // Eraser/Delete tool
                  ToolbarButton(
                    icon: Icons.delete_outline,
                    label: 'Erase',
                    isActive: widget.activeTool == CanvasTool.eraser,
                    onTap: () => widget.onToolChanged(CanvasTool.eraser),
                    accentColor: theme.accentColor,
                  ),

                  // Settings button (optional)
                  ToolbarButton(
                    icon: Icons.settings,
                    label: 'Settings',
                    isActive: widget.activeTool == CanvasTool.settings,
                    onTap: () {
                      widget.onToolChanged(CanvasTool.settings);
                      widget.onSettingsTap();
                    },
                    accentColor: theme.accentColor,
                  ),
                ],
              ),

              // Active tool indicator
              if (widget.activeTool != CanvasTool.select) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: theme.accentColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.activeTool.name} active',
                        style: TextStyle(
                          color: theme.accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// CanvasTool enum for tracking active tool
/// SIMPLIFIED: Only essential tools (select, pan, shapes, eraser, editor, settings, media)
enum CanvasTool {
  select, // Select/Move tool
  pan, // Pan tool (manually pan canvas)
  shapes, // Add Shapes tool
  node, // Node creation (compatibility)
  text, // Text tool (compatibility)
  connector, // Connector tool (compatibility)
  eraser, // Erase/Delete tool
  editor, // Text Editor tool (for editing shape text)
  media, // Media import tool (emoji stickers + PNG/SVG files)
  settings, // Settings tool (optional)
}

extension CanvasToolExtension on CanvasTool {
  String get name {
    switch (this) {
      case CanvasTool.select:
        return 'Select';
      case CanvasTool.pan:
        return 'Pan';
      case CanvasTool.shapes:
        return 'Shapes';
      case CanvasTool.node:
        return 'Node';
      case CanvasTool.text:
        return 'Text';
      case CanvasTool.connector:
        return 'Connector';
      case CanvasTool.editor:
        return 'Editor';
      case CanvasTool.eraser:
        return 'Eraser';
      case CanvasTool.media:
        return 'Media';
      case CanvasTool.settings:
        return 'Settings';
    }
  }
}
