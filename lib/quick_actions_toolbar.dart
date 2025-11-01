import 'package:flutter/material.dart';
import 'theme_manager.dart';

/// ToolbarButton: Individual tool button for the quick actions toolbar
class ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color accentColor;

  const ToolbarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
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
                  ? accentColor.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive
                    ? accentColor.withValues(alpha: 0.5)
                    : accentColor.withValues(alpha: 0.1),
                width: isActive ? 2 : 1,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? accentColor : accentColor.withValues(alpha: 0.6),
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
  final ValueChanged<CanvasTool> onToolChanged;
  final CanvasTool activeTool;

  const QuickActionsToolbar({
    super.key,
    required this.themeManager,
    required this.onSettingsTap,
    required this.onShapesTool,
    required this.onToolChanged,
    required this.activeTool,
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
            border: Border.all(
              color: theme.borderColor.withValues(alpha: 0.2),
            ),
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
                  // Select/Cursor tool
                  ToolbarButton(
                    icon: Icons.near_me,
                    label: 'Select',
                    isActive: widget.activeTool == CanvasTool.select,
                    onTap: () => widget.onToolChanged(CanvasTool.select),
                    accentColor: theme.accentColor,
                  ),

                  // Node creation
                  ToolbarButton(
                    icon: Icons.add_circle_outline,
                    label: 'Add Node',
                    isActive: widget.activeTool == CanvasTool.node,
                    onTap: () => widget.onToolChanged(CanvasTool.node),
                    accentColor: theme.accentColor,
                  ),

                  // Text tool
                  ToolbarButton(
                    icon: Icons.text_fields,
                    label: 'Text',
                    isActive: widget.activeTool == CanvasTool.text,
                    onTap: () => widget.onToolChanged(CanvasTool.text),
                    accentColor: theme.accentColor,
                  ),

                  // Connector/Line tool
                  ToolbarButton(
                    icon: Icons.timeline,
                    label: 'Connector',
                    isActive: widget.activeTool == CanvasTool.connector,
                    onTap: () => widget.onToolChanged(CanvasTool.connector),
                    accentColor: theme.accentColor,
                  ),

                  // Shapes tool (opens slide-out)
                  ToolbarButton(
                    icon: Icons.category_outlined,
                    label: 'Shapes',
                    isActive: widget.activeTool == CanvasTool.shapes,
                    onTap: () {
                      widget.onToolChanged(CanvasTool.shapes);
                      widget.onShapesTool();
                    },
                    accentColor: theme.accentColor,
                  ),

                  // Eraser tool
                  ToolbarButton(
                    icon: Icons.auto_fix_off,
                    label: 'Eraser',
                    isActive: widget.activeTool == CanvasTool.eraser,
                    onTap: () => widget.onToolChanged(CanvasTool.eraser),
                    accentColor: theme.accentColor,
                  ),

                  // Settings button
                  ToolbarButton(
                    icon: Icons.settings,
                    label: 'Settings',
                    isActive: false,
                    onTap: widget.onSettingsTap,
                    accentColor: theme.accentColor,
                  ),
                ],
              ),

              // Active tool indicator
              if (widget.activeTool != CanvasTool.select) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
enum CanvasTool {
  select,
  node,
  text,
  connector,
  shapes,
  eraser,
}

extension CanvasToolExtension on CanvasTool {
  String get name {
    switch (this) {
      case CanvasTool.select:
        return 'Select';
      case CanvasTool.node:
        return 'Node';
      case CanvasTool.text:
        return 'Text';
      case CanvasTool.connector:
        return 'Connector';
      case CanvasTool.shapes:
        return 'Shapes';
      case CanvasTool.eraser:
        return 'Eraser';
    }
  }
}
