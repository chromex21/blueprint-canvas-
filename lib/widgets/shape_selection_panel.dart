import 'package:flutter/material.dart';
import '../models/canvas_shape.dart';
import '../theme_manager.dart';

/// ShapeSelectionPanel: Clean minimal dock for shape selection
/// 
/// Design Philosophy:
/// "I hold shapes. I place shapes. I reorder shapes. I shut up."
class ShapeSelectionPanel extends StatefulWidget {
  final ThemeManager themeManager;
  final ShapeType? selectedShapeType;
  final ValueChanged<ShapeType?> onShapeTypeSelected;
  final VoidCallback onClose;
  final double dockScale; // Scale factor for dock size

  const ShapeSelectionPanel({
    super.key,
    required this.themeManager,
    required this.selectedShapeType,
    required this.onShapeTypeSelected,
    required this.onClose,
    this.dockScale = 1.0,
  });

  @override
  State<ShapeSelectionPanel> createState() => _ShapeSelectionPanelState();
}

class _ShapeSelectionPanelState extends State<ShapeSelectionPanel> with SingleTickerProviderStateMixin {
  // Shape dock order (left = most important/frequent)
  static final List<_ShapeDockItem> _shapeDock = [
    _ShapeDockItem(ShapeType.rectangle, Icons.crop_square, 'Rectangle', true),
    _ShapeDockItem(ShapeType.roundedRectangle, Icons.rounded_corner, 'Rounded', true),
    _ShapeDockItem(ShapeType.circle, Icons.circle_outlined, 'Circle', false),
    _ShapeDockItem(ShapeType.pill, Icons.lens_outlined, 'Pill', true),
    _ShapeDockItem(ShapeType.diamond, Icons.diamond_outlined, 'Diamond', false),
    _ShapeDockItem(ShapeType.triangle, Icons.change_history, 'Triangle', false),
  ];

  ShapeType? _hoveredShape;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate scaled dimensions with better proportions
    final dockWidth = (40 * widget.dockScale).clamp(30.0, 80.0); // Better base width
    final iconSize = (28 * widget.dockScale).clamp(22.0, 56.0); // Slightly smaller icons
    final iconActualSize = (18 * widget.dockScale).clamp(14.0, 36.0); // Icon graphic size
    final spacing = (10 * widget.dockScale).clamp(8.0, 20.0); // More breathing room
    final horizontalPadding = (6 * widget.dockScale).clamp(4.0, 12.0); // Left/right padding

    return SlideTransition(
      position: _slideAnimation,
      child: AnimatedBuilder(
        animation: widget.themeManager,
        builder: (context, _) {
          final theme = widget.themeManager.currentTheme;

          return Container(
            width: dockWidth,
            height: double.infinity,
            decoration: BoxDecoration(
              color: theme.panelColor.withValues(alpha: 0.95),
              border: Border(
                right: BorderSide(
                  color: theme.borderColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_shapeDock.length, (index) {
                    final item = _shapeDock[index];
                    final isSelected = widget.selectedShapeType == item.type;
                    final isHovered = _hoveredShape == item.type;
                    
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index < _shapeDock.length - 1 ? spacing : 0,
                      ),
                      child: _buildShapeIcon(item, isSelected, isHovered, theme, iconSize, iconActualSize),
                    );
                  }),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShapeIcon(_ShapeDockItem item, bool isSelected, bool isHovered, CanvasTheme theme, double iconSize, double iconActualSize) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredShape = item.type),
      onExit: (_) => setState(() => _hoveredShape = null),
      child: GestureDetector(
        onTap: () => widget.onShapeTypeSelected(isSelected ? null : item.type),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.accentColor.withValues(alpha: 0.2)
                    : (isHovered ? theme.backgroundColor.withValues(alpha: 0.3) : Colors.transparent),
                borderRadius: BorderRadius.circular(6 * widget.dockScale),
                border: Border.all(
                  color: isSelected
                      ? theme.accentColor
                      : (item.isTextEditable 
                          ? theme.accentColor.withValues(alpha: 0.3)
                          : theme.borderColor.withValues(alpha: 0.15)),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Center(
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 120),
                  scale: isHovered ? 1.08 : 1.0,
                  child: Icon(
                    item.icon,
                    size: iconActualSize,
                    color: isSelected
                        ? theme.accentColor
                        : theme.textColor.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
            
            // Tooltip label (show on hover only)
            if (isHovered)
              Positioned(
                left: 40,
                top: 0,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: 1.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.panelColor,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: theme.borderColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.label,
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (item.isTextEditable) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.text_fields,
                              size: 10,
                              color: theme.accentColor.withValues(alpha: 0.6),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShapeDockItem {
  final ShapeType type;
  final IconData icon;
  final String label;
  final bool isTextEditable;

  const _ShapeDockItem(this.type, this.icon, this.label, this.isTextEditable);
}
