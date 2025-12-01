import 'package:flutter/material.dart';
import 'theme_manager.dart';
import 'models/canvas_node.dart';

/// ShapesPanel: Slide-out panel for shape selection
class ShapesPanel extends StatelessWidget {
  final ThemeManager themeManager;
  final VoidCallback onClose;
  final Function(NodeType) onShapeSelected;

  const ShapesPanel({
    super.key,
    required this.themeManager,
    required this.onClose,
    required this.onShapeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeManager,
      builder: (context, _) {
        final theme = themeManager.currentTheme;

        return Container(
          width: 280,
          height: double.infinity,
          decoration: BoxDecoration(
            color: theme.panelColor,
            border: Border(
              left: BorderSide(
                color: theme.borderColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
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
                    Icon(Icons.category, color: theme.accentColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Shape Library',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: theme.textColor.withValues(alpha: 0.7),
                      ),
                      onPressed: onClose,
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),

              // Shapes Grid
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TEXT-EDITABLE SHAPES (Rectangle, RoundedRectangle, Pill)
                      _buildShapeCategory('Text-Editable Shapes', theme, [
                        _ShapeItem(
                          Icons.rectangle_outlined,
                          'Rectangle',
                          NodeType.shapeRect,
                          isTextEditable: true,
                        ),
                        _ShapeItem(
                          Icons.rounded_corner,
                          'Rounded Rect',
                          NodeType.basicNode,
                          isTextEditable: true,
                        ),
                        _ShapeItem(
                          Icons.panorama_horizontal,
                          'Pill',
                          NodeType.shapePill,
                          isTextEditable: true,
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // OTHER SHAPES (Circle, Triangle, Diamond, Hexagon)
                      _buildShapeCategory('Other Shapes', theme, [
                        _ShapeItem(
                          Icons.circle_outlined,
                          'Circle',
                          NodeType.shapeCircle,
                        ),
                        _ShapeItem(
                          Icons.change_history,
                          'Triangle',
                          NodeType.shapeTriangle,
                        ),
                        _ShapeItem(
                          Icons.crop_square,
                          'Diamond',
                          NodeType.shapeDiamond,
                        ),
                        _ShapeItem(
                          Icons.hexagon_outlined,
                          'Hexagon',
                          NodeType.shapeHexagon,
                        ),
                      ]),

                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.accentColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: theme.accentColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Only Rectangle, Rounded Rect, and Pill shapes support text editing',
                                style: TextStyle(
                                  color: theme.textColor.withValues(alpha: 0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Click a shape, then click the canvas to place it',
                        style: TextStyle(
                          color: theme.textColor.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShapeCategory(
    String title,
    CanvasTheme theme,
    List<_ShapeItem> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: theme.textColor.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildShapeButton(item, theme);
          },
        ),
      ],
    );
  }

  Widget _buildShapeButton(_ShapeItem item, CanvasTheme theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (item.nodeType != null) {
            onShapeSelected(item.nodeType!);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: theme.backgroundColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: item.isTextEditable
                  ? theme.accentColor.withValues(
                      alpha: 0.4,
                    ) // Highlight text-editable shapes
                  : theme.borderColor.withValues(alpha: 0.2),
              width: item.isTextEditable ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                color: theme.accentColor.withValues(alpha: 0.8),
                size: 28,
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  color: theme.textColor.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
              if (item.isTextEditable)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.text_fields,
                    color: theme.accentColor.withValues(alpha: 0.5),
                    size: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShapeItem {
  final IconData icon;
  final String label;
  final NodeType? nodeType;
  final bool isTextEditable;

  _ShapeItem(
    this.icon,
    this.label,
    this.nodeType, {
    this.isTextEditable = false,
  });
}
