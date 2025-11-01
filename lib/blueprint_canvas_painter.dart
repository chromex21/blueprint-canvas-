import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'theme_manager.dart';

/// BlueprintCanvasPainter: Enhanced theme-aware dynamic grid canvas
/// 
/// Features:
/// - Animated blueprint-style grid with breathing effect
/// - Radar sweep effect for living blueprint feel
/// - Enhanced grid pulse with intensity control
/// - Theme-integrated colors that update with panel
/// - Optimized viewport-based rendering
/// - Smooth 60+ FPS performance
class BlueprintCanvasPainter extends StatefulWidget {
  final ThemeManager themeManager;
  final bool showGrid;
  final double gridSpacing;
  final double dotSize;

  const BlueprintCanvasPainter({
    super.key,
    required this.themeManager,
    required this.showGrid,
    required this.gridSpacing,
    required this.dotSize,
  });

  @override
  State<BlueprintCanvasPainter> createState() => _BlueprintCanvasPainterState();
}

class _BlueprintCanvasPainterState extends State<BlueprintCanvasPainter>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _radarController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Glow breathing animation - gentle 6 second cycle
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _glowAnimation = CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    );

    // Radar sweep animation - slow sweep every 12 seconds
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _glowAnimation,
        _radarController,
        widget.themeManager,
      ]),
      builder: (context, _) {
        final theme = widget.themeManager.currentTheme;
        final animationsEnabled = widget.themeManager.animationsEnabled;
        
        // Calculate animation values
        final glowOpacity = animationsEnabled
            ? 0.05 + (_glowAnimation.value * 0.08 * widget.themeManager.gridPulseIntensity)
            : 0.07;

        return CustomPaint(
          painter: _GridPainter(
            theme: theme,
            showGrid: widget.showGrid,
            gridSpacing: widget.gridSpacing,
            dotSize: widget.dotSize,
            glowOpacity: glowOpacity,
            radarProgress: animationsEnabled ? _radarController.value : 0.0,
            radarIntensity: widget.themeManager.radarSweepIntensity,
            animationsEnabled: animationsEnabled,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

/// Internal painter that renders the enhanced blueprint grid
class _GridPainter extends CustomPainter {
  final CanvasTheme theme;
  final bool showGrid;
  final double gridSpacing;
  final double dotSize;
  final double glowOpacity;
  final double radarProgress;
  final double radarIntensity;
  final bool animationsEnabled;

  const _GridPainter({
    required this.theme,
    required this.showGrid,
    required this.gridSpacing,
    required this.dotSize,
    required this.glowOpacity,
    required this.radarProgress,
    required this.radarIntensity,
    required this.animationsEnabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // ========================================================================
    // BACKGROUND: Theme-aware gradient
    // ========================================================================
    final Rect rect = Offset.zero & size;
    
    // Check if this is a light theme (whiteboard)
    final bool isLightTheme = theme.backgroundColor.computeLuminance() > 0.5;
    
    final Paint background = Paint()
      ..shader = LinearGradient(
        colors: isLightTheme
            ? [theme.backgroundColor, theme.backgroundColor]
            : [
                theme.backgroundColor,
                Color.lerp(theme.backgroundColor, Colors.black, 0.2)!,
              ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    
    canvas.drawRect(rect, background);

    if (!showGrid) return;

    // ========================================================================
    // GRID LINES: Enhanced adaptive spacing with pulse animation
    // ========================================================================
    final double targetCells = 25.0;
    final double spacingX = size.width / targetCells;
    final double spacingY = size.height / targetCells;
    final double adaptiveSpacing = math.max(gridSpacing, 
      (spacingX < spacingY ? spacingX : spacingY).clamp(20.0, gridSpacing * 2)
    );

    // Enhanced base opacity with pulse breathing
    final double baseOpacity = isLightTheme ? 0.12 : glowOpacity;
    final double pulseMultiplier = 1.0 + (glowOpacity * 0.3);
    final double animatedOpacity = baseOpacity * pulseMultiplier;

    // Grid paint with enhanced breathing effect
    final Paint gridPaint = Paint()
      ..color = theme.gridColor.withValues(alpha: animatedOpacity)
      ..strokeWidth = isLightTheme ? 0.5 : 0.5
      ..style = PaintingStyle.stroke;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += adaptiveSpacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += adaptiveSpacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // ========================================================================
    // ACCENT LINES: Major grid lines with enhanced glow
    // ========================================================================
    final double majorSpacing = adaptiveSpacing * 5;
    final double majorOpacity = isLightTheme 
        ? 0.25 
        : (glowOpacity * 2.5 * pulseMultiplier).clamp(0.0, 0.4);
    
    final Paint accentPaint = Paint()
      ..color = theme.gridColor.withValues(alpha: majorOpacity)
      ..strokeWidth = isLightTheme ? 1.0 : 1.0
      ..style = PaintingStyle.stroke;

    // Major vertical lines
    for (double x = 0; x < size.width; x += majorSpacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        accentPaint,
      );
    }

    // Major horizontal lines
    for (double y = 0; y < size.height; y += majorSpacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        accentPaint,
      );
    }

    // ========================================================================
    // RADAR SWEEP EFFECT: Diagonal scanning beam
    // ========================================================================
    if (!isLightTheme && animationsEnabled && radarIntensity > 0) {
      _drawRadarSweep(canvas, size);
    }

    // ========================================================================
    // CORNER MARKERS: Blueprint-style indicators with pulse
    // ========================================================================
    final double cornerOpacity = isLightTheme 
        ? 0.35 
        : (glowOpacity * 3.5 * pulseMultiplier).clamp(0.0, 0.5);
    final Paint cornerPaint = Paint()
      ..color = theme.gridColor.withValues(alpha: cornerOpacity)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const double cornerSize = 20.0;

    // Draw all four corners
    _drawCornerMarkers(canvas, size, cornerPaint, cornerSize);

    // ========================================================================
    // GRID INTERSECTIONS: Subtle glowing dots at major intersections
    // ========================================================================
    if (!isLightTheme && animationsEnabled) {
      _drawIntersectionGlow(canvas, size, majorSpacing, pulseMultiplier);
    }
  }

  /// Enhanced radar sweep with intensity control
  void _drawRadarSweep(Canvas canvas, Size size) {
    final double diagonalLength = math.sqrt(size.width * size.width + size.height * size.height);
    final double sweepWidth = 300 * radarIntensity;
    
    // Calculate sweep position (diagonal movement)
    final double sweepPosition = radarProgress * (diagonalLength + sweepWidth * 2) - sweepWidth;

    // Only draw when visible
    if (sweepPosition < -sweepWidth || sweepPosition > diagonalLength + sweepWidth) return;

    // Create diagonal gradient beam
    final Paint radarPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(sweepPosition - sweepWidth, 0),
        Offset(sweepPosition + sweepWidth, 0),
        [
          theme.gridColor.withValues(alpha: 0.0),
          theme.gridColor.withValues(alpha: 0.03 * radarIntensity),
          theme.gridColor.withValues(alpha: 0.05 * radarIntensity),
          theme.gridColor.withValues(alpha: 0.03 * radarIntensity),
          theme.gridColor.withValues(alpha: 0.0),
        ],
        [0.0, 0.3, 0.5, 0.7, 1.0],
        TileMode.clamp,
        Matrix4.rotationZ(-0.785398).storage, // -45 degrees
      )
      ..blendMode = BlendMode.plus;

    canvas.drawRect(Offset.zero & size, radarPaint);
  }

  /// Glowing dots at major grid intersections
  void _drawIntersectionGlow(Canvas canvas, Size size, double spacing, double pulseMultiplier) {
    final Paint glowPaint = Paint()
      ..color = theme.gridColor.withValues(alpha: 0.15 * pulseMultiplier)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4.0);

    // Draw glowing dots at major intersections
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 2.0, glowPaint);
      }
    }
  }

  void _drawCornerMarkers(Canvas canvas, Size size, Paint paint, double cornerSize) {
    // Top-left
    canvas.drawLine(Offset.zero, Offset(cornerSize, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, cornerSize), paint);

    // Top-right
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width - cornerSize, 0),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, cornerSize),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(0, size.height),
      Offset(cornerSize, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - cornerSize),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - cornerSize, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - cornerSize),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) {
    return oldDelegate.theme != theme ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.gridSpacing != gridSpacing ||
        oldDelegate.dotSize != dotSize ||
        oldDelegate.glowOpacity != glowOpacity ||
        oldDelegate.radarProgress != radarProgress ||
        oldDelegate.radarIntensity != radarIntensity ||
        oldDelegate.animationsEnabled != animationsEnabled;
  }
}
