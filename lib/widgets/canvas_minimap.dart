import 'package:flutter/material.dart';
import '../core/viewport_controller.dart';
import '../managers/shape_manager.dart';
import '../models/canvas_shape.dart';
import '../theme_manager.dart';

/// CanvasMinimap: Overview map showing canvas content and current viewport
/// 
/// FEATURES:
/// - Shows all shapes as small dots/rectangles
/// - Displays current viewport as a rectangle overlay
/// - Home/recenter button to reset view to origin
/// - Click on minimap to jump to that position
class CanvasMinimap extends StatefulWidget {
  final ViewportController viewportController;
  final ShapeManager shapeManager;
  final ThemeManager themeManager;
  final Size canvasSize;

  const CanvasMinimap({
    super.key,
    required this.viewportController,
    required this.shapeManager,
    required this.themeManager,
    required this.canvasSize,
  });

  @override
  State<CanvasMinimap> createState() => _CanvasMinimapState();
}

class _CanvasMinimapState extends State<CanvasMinimap> {
  static const double _minimapSize = 200.0;
  static const double _minimapPadding = 8.0;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.viewportController,
        widget.shapeManager,
        widget.themeManager,
      ]),
      builder: (context, _) {
        final theme = widget.themeManager.currentTheme;
        
        return Positioned(
          bottom: 16,
          right: 16,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _minimapSize,
              height: _minimapSize,
              decoration: BoxDecoration(
                color: theme.panelColor.withValues(alpha: _isHovered ? 0.95 : 0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.borderColor.withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    // Minimap content
                    _buildMinimapContent(theme),
                    
                    // Home/recenter button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _buildHomeButton(theme),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMinimapContent(CanvasTheme theme) {
    // Calculate bounds of all shapes
    final shapes = widget.shapeManager.shapes;
    
    // Get current viewport bounds
    final viewportBounds = widget.viewportController.getViewportBounds(widget.canvasSize);
    
    if (shapes.isEmpty) {
      // Show viewport centered when no shapes
      final centerX = _minimapSize / 2;
      final centerY = _minimapSize / 2;
      final viewportScale = 0.05; // Scale down viewport for display
      final viewportRect = Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: viewportBounds.width * viewportScale,
        height: viewportBounds.height * viewportScale,
      );

      return CustomPaint(
        painter: _MinimapPainter(
          shapes: [],
          viewportRect: viewportRect,
          theme: theme,
          scale: viewportScale,
          offset: Offset(centerX - viewportBounds.center.dx * viewportScale, centerY - viewportBounds.center.dy * viewportScale),
        ),
        size: Size(_minimapSize, _minimapSize),
      );
    }

    // Find bounds of all content
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final shape in shapes) {
      final bounds = shape.bounds;
      minX = minX < bounds.left ? minX : bounds.left;
      minY = minY < bounds.top ? minY : bounds.top;
      maxX = maxX > bounds.right ? maxX : bounds.right;
      maxY = maxY > bounds.bottom ? maxY : bounds.bottom;
    }

    // Include viewport in bounds calculation to ensure it's always visible
    minX = (minX < viewportBounds.left ? minX : viewportBounds.left) - 50;
    minY = (minY < viewportBounds.top ? minY : viewportBounds.top) - 50;
    maxX = (maxX > viewportBounds.right ? maxX : viewportBounds.right) + 50;
    maxY = (maxY > viewportBounds.bottom ? maxY : viewportBounds.bottom) + 50;

    // Add padding around content
    const padding = 50.0;
    final contentWidth = (maxX - minX + padding * 2).clamp(100.0, double.infinity);
    final contentHeight = (maxY - minY + padding * 2).clamp(100.0, double.infinity);

    // Calculate scale to fit content in minimap
    final scaleX = (_minimapSize - _minimapPadding * 2) / contentWidth;
    final scaleY = (_minimapSize - _minimapPadding * 2) / contentHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    // Calculate offset to center content
    final offsetX = _minimapPadding + (contentWidth * scale - (maxX - minX) * scale) / 2 - minX * scale;
    final offsetY = _minimapPadding + (contentHeight * scale - (maxY - minY) * scale) / 2 - minY * scale;

    // Calculate viewport rectangle in minimap coordinates
    final viewportRect = Rect.fromLTWH(
      offsetX + (viewportBounds.left - minX + padding) * scale,
      offsetY + (viewportBounds.top - minY + padding) * scale,
      viewportBounds.width * scale,
      viewportBounds.height * scale,
    );

    return CustomPaint(
      painter: _MinimapPainter(
        shapes: shapes,
        viewportRect: viewportRect,
        theme: theme,
        scale: scale,
        offset: Offset(offsetX - minX * scale, offsetY - minY * scale),
      ),
      size: Size(_minimapSize, _minimapSize),
    );
  }


  Widget _buildHomeButton(CanvasTheme theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _recenterView,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: theme.accentColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.accentColor.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.home,
            color: theme.accentColor,
            size: 18,
          ),
        ),
      ),
    );
  }

  void _recenterView() {
    widget.viewportController.reset(canvasSize: widget.canvasSize);
  }
}

class _MinimapPainter extends CustomPainter {
  final List<CanvasShape> shapes;
  final Rect viewportRect;
  final CanvasTheme theme;
  final double scale;
  final Offset offset;

  _MinimapPainter({
    required this.shapes,
    required this.viewportRect,
    required this.theme,
    required this.scale,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    final backgroundPaint = Paint()
      ..color = theme.backgroundColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    // Draw grid (optional, subtle)
    final gridPaint = Paint()
      ..color = theme.gridColor.withValues(alpha: 0.1)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    
    const gridSpacing = 25.0;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw shapes as small rectangles/dots
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    final shapePaint = Paint()
      ..style = PaintingStyle.fill;

    for (final shape in shapes) {
      // Use shape color with reduced opacity
      shapePaint.color = shape.color.withValues(alpha: 0.6);
      
      final bounds = shape.bounds;
      // Draw as small rectangle (min 2x2 pixels for visibility)
      final minimapBounds = Rect.fromLTWH(
        bounds.left,
        bounds.top,
        bounds.width.clamp(2.0, double.infinity),
        bounds.height.clamp(2.0, double.infinity),
      );
      
      canvas.drawRect(minimapBounds, shapePaint);
    }

    canvas.restore();

    // Draw viewport rectangle overlay
    if (viewportRect.overlaps(Offset.zero & size)) {
      // Viewport border
      final viewportBorderPaint = Paint()
        ..color = theme.accentColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawRect(viewportRect, viewportBorderPaint);

      // Viewport fill (semi-transparent)
      final viewportFillPaint = Paint()
        ..color = theme.accentColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;
      canvas.drawRect(viewportRect, viewportFillPaint);
    }
  }

  @override
  bool shouldRepaint(_MinimapPainter oldDelegate) {
    return oldDelegate.shapes.length != shapes.length ||
        oldDelegate.viewportRect != viewportRect ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale ||
        oldDelegate.offset != offset;
  }
}

