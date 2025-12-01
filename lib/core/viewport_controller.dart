import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as math64;
import 'dart:math' as math;

/// ViewportController: Manages canvas viewport transformations
///
/// Provides:
/// - Zoom control with configurable limits
/// - Pan/translation with smooth constraints
/// - World-to-screen coordinate conversion
/// - Screen-to-world coordinate conversion
/// - Proper transform matrix management
/// - Smooth animation support for view changes
class ViewportController extends ChangeNotifier {
  // Transform state
  Matrix4 _transform = Matrix4.identity();
  Offset _translation = Offset.zero;
  double _scale = 1.0;

  // Constraints - Updated: max 300% (3.0), min 50% (0.5) for clear visibility
  static const double minScale = 0.5;
  static const double maxScale = 3.0;
  static const double maxTranslation = 50000.0; // Virtually infinite

  // Animation support
  AnimationController? _animationController;
  Animation<Matrix4>? _transformAnimation;

  // Pan limit feedback
  bool _isAtPanLimit = false;
  bool get isAtPanLimit => _isAtPanLimit;

  // Getters
  Matrix4 get transform => Matrix4.copy(_transform);
  Offset get translation => _translation;
  double get scale => _scale;

  /// Current viewport bounds in world coordinates
  Rect getViewportBounds(Size canvasSize) {
    if (canvasSize.isEmpty) return Rect.zero;

    final topLeft = screenToWorld(Offset.zero, canvasSize);
    final bottomRight = screenToWorld(
      Offset(canvasSize.width, canvasSize.height),
      canvasSize,
    );

    return Rect.fromPoints(topLeft, bottomRight);
  }

  // ============================================================================
  // COORDINATE CONVERSION
  // ============================================================================

  /// Convert world coordinates to screen coordinates
  Offset worldToScreen(Offset worldPoint, Size canvasSize) {
    final Matrix4 matrix = _buildTransformMatrix(canvasSize);
    final math64.Vector3 transformed = matrix.transform3(
      math64.Vector3(worldPoint.dx, worldPoint.dy, 0.0),
    );

    return Offset(transformed.x, transformed.y);
  }

  /// Convert screen coordinates to world coordinates
  Offset screenToWorld(Offset screenPoint, Size canvasSize) {
    final Matrix4 matrix = _buildTransformMatrix(canvasSize);
    final Matrix4 inverted = Matrix4.inverted(matrix);
    final math64.Vector3 transformed = inverted.transform3(
      math64.Vector3(screenPoint.dx, screenPoint.dy, 0.0),
    );

    return Offset(transformed.x, transformed.y);
  }

  /// Convert world size to screen size
  Size worldSizeToScreen(Size worldSize) {
    return Size(worldSize.width * _scale, worldSize.height * _scale);
  }

  /// Convert screen size to world size
  Size screenSizeToWorld(Size screenSize) {
    return Size(screenSize.width / _scale, screenSize.height / _scale);
  }

  // ============================================================================
  // TRANSFORMATION OPERATIONS
  // ============================================================================

  /// Zoom in/out centered on a specific point (cursor position)
  /// This ensures the point under the cursor stays fixed during zoom
  void zoomAt(Offset focalPoint, double deltaScale, Size canvasSize) {
    if (canvasSize.isEmpty) return;
    
    final double newScale = (_scale * deltaScale).clamp(minScale, maxScale);
    if (newScale == _scale) return; // No change needed

    // Get the world coordinates of the point under the cursor BEFORE changing scale
    // Current transform: screen = translation + world * scale
    // So: world = (screen - translation) / scale
    final oldScale = _scale;
    final oldTranslation = _translation;
    
    // Calculate world coordinates using current transform
    final worldX = (focalPoint.dx - oldTranslation.dx) / oldScale;
    final worldY = (focalPoint.dy - oldTranslation.dy) / oldScale;

    // Update scale
    _scale = newScale;

    // Calculate new translation so the same world point appears at the same screen position
    // We want: focalPoint = newTranslation + world * newScale
    // So: newTranslation = focalPoint - world * newScale
    _translation = Offset(
      (focalPoint.dx - worldX * newScale).clamp(-maxTranslation, maxTranslation),
      (focalPoint.dy - worldY * newScale).clamp(-maxTranslation, maxTranslation),
    );

    _updateTransform(canvasSize);
    notifyListeners();
  }

  /// Pan the viewport by a delta amount
  void pan(Offset delta) {
    final newDx = _translation.dx + delta.dx;
    final newDy = _translation.dy + delta.dy;
    
    final clampedDx = newDx.clamp(-maxTranslation, maxTranslation);
    final clampedDy = newDy.clamp(-maxTranslation, maxTranslation);
    
    // Check if we hit a pan limit
    final hitLimit = (newDx != clampedDx) || (newDy != clampedDy);
    
    _translation = Offset(clampedDx, clampedDy);
    
    // Update pan limit state
    if (hitLimit != _isAtPanLimit) {
      _isAtPanLimit = hitLimit;
      notifyListeners();
      
      // Auto-reset after brief flash (300ms)
      if (_isAtPanLimit) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_isAtPanLimit) {
            _isAtPanLimit = false;
            notifyListeners();
          }
        });
      }
    }

    _updateTransform(Size.zero); // Size not needed for translation-only updates
    notifyListeners();
  }

  /// Set zoom level directly
  void setScale(double newScale, {Offset? center, Size? canvasSize}) {
    final clampedScale = newScale.clamp(minScale, maxScale);

    if (center != null && canvasSize != null) {
      zoomAt(center, clampedScale / _scale, canvasSize);
    } else {
      _scale = clampedScale;
      _updateTransform(canvasSize ?? Size.zero);
      notifyListeners();
    }
  }

  /// Set translation directly
  void setTranslation(Offset newTranslation) {
    _translation = Offset(
      newTranslation.dx.clamp(-maxTranslation, maxTranslation),
      newTranslation.dy.clamp(-maxTranslation, maxTranslation),
    );

    _updateTransform(Size.zero);
    notifyListeners();
  }

  /// Reset viewport to default state
  void reset({Size? canvasSize}) {
    _scale = 1.0;
    _translation = Offset.zero;
    _updateTransform(canvasSize ?? Size.zero);
    notifyListeners();
  }

  /// Fit content to viewport
  void fitToContent(
    Rect contentBounds,
    Size canvasSize, {
    double padding = 50.0,
  }) {
    if (contentBounds.isEmpty || canvasSize.isEmpty) {
      reset(canvasSize: canvasSize);
      return;
    }

    // Calculate scale to fit content with padding
    final availableWidth = canvasSize.width - (padding * 2);
    final availableHeight = canvasSize.height - (padding * 2);

    final scaleX = availableWidth / contentBounds.width;
    final scaleY = availableHeight / contentBounds.height;
    final fitScale = math.min(scaleX, scaleY).clamp(minScale, maxScale);

    // Calculate translation to center content
    final contentCenter = contentBounds.center;
    final screenCenter = Offset(canvasSize.width / 2, canvasSize.height / 2);

    _scale = fitScale;

    // Center the content
    final scaledContentCenter = Offset(
      contentCenter.dx * _scale,
      contentCenter.dy * _scale,
    );

    _translation = screenCenter - scaledContentCenter;

    _updateTransform(canvasSize);
    notifyListeners();
  }

  // ============================================================================
  // ANIMATION SUPPORT
  // ============================================================================

  /// Animate to a specific transform
  void animateTo({
    double? scale,
    Offset? translation,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
    required TickerProvider vsync,
    Size? canvasSize,
  }) {
    // Dispose existing animation
    _animationController?.dispose();

    final targetScale = (scale ?? _scale).clamp(minScale, maxScale);
    final targetTranslation = translation ?? _translation;

    // Create animation controller
    _animationController = AnimationController(
      vsync: vsync,
      duration: duration,
    );

    // Create transform animation
    final begin = Matrix4.copy(_transform);
    _scale = targetScale;
    _translation = targetTranslation;
    _updateTransform(canvasSize ?? Size.zero);
    final end = Matrix4.copy(_transform);

    _transformAnimation = Matrix4Tween(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(parent: _animationController!, curve: curve));

    _transformAnimation!.addListener(() {
      _transform = Matrix4.copy(_transformAnimation!.value);
      notifyListeners();
    });

    _transformAnimation!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationController?.dispose();
        _animationController = null;
        _transformAnimation = null;
      }
    });

    _animationController!.forward();
  }

  // ============================================================================
  // INTERNAL HELPERS
  // ============================================================================

  /// Build the complete transformation matrix
  /// Formula: screen = translation + world * scale
  /// 
  /// For 2D affine transform: screen.x = world.x * scale + translation.x
  ///                          screen.y = world.y * scale + translation.y
  /// 
  /// Matrix format (homogeneous coordinates):
  /// [scale   0       translation.x]
  /// [0       scale   translation.y]
  /// [0       0       1           ]
  Matrix4 _buildTransformMatrix(Size canvasSize) {
    // Build matrix directly to ensure correct format
    // Matrix4 uses column-major order: [m00 m10 m20 m30]
    //                                  [m01 m11 m21 m31]
    //                                  [m02 m12 m22 m32]
    //                                  [m03 m13 m23 m33]
    // 
    // For 2D transform: m00=scale, m11=scale, m03=tx, m13=ty
    final matrix = Matrix4.identity();
    matrix.setEntry(0, 0, _scale);      // m00: scale x
    matrix.setEntry(1, 1, _scale);      // m11: scale y
    matrix.setEntry(0, 3, _translation.dx);  // m03: translate x
    matrix.setEntry(1, 3, _translation.dy);  // m13: translate y
    return matrix;
  }

  /// Update the internal transform matrix
  void _updateTransform(Size canvasSize) {
    _transform = _buildTransformMatrix(canvasSize);
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Check if a world-space rectangle is visible in current viewport
  bool isRectVisible(Rect worldRect, Size canvasSize) {
    final viewportBounds = getViewportBounds(canvasSize);
    return viewportBounds.overlaps(worldRect);
  }

  /// Get visible area in world coordinates
  Rect getVisibleWorldRect(Size canvasSize) {
    return getViewportBounds(canvasSize);
  }

  /// Calculate optimal zoom level for given content
  double calculateOptimalZoom(Rect contentBounds, Size canvasSize) {
    if (contentBounds.isEmpty || canvasSize.isEmpty) return 1.0;

    final scaleX = canvasSize.width / contentBounds.width;
    final scaleY = canvasSize.height / contentBounds.height;

    return math.min(scaleX, scaleY).clamp(minScale, maxScale);
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }
}

/// Extension for Matrix4 tweening support
class Matrix4Tween extends Tween<Matrix4> {
  Matrix4Tween({required Matrix4 begin, required Matrix4 end})
    : super(begin: begin, end: end);

  @override
  Matrix4 lerp(double t) {
    final result = Matrix4.identity();

    // Linear interpolate each matrix element
    for (int i = 0; i < 16; i++) {
      result.setEntry(
        i ~/ 4,
        i % 4,
        begin!.entry(i ~/ 4, i % 4) +
            (end!.entry(i ~/ 4, i % 4) - begin!.entry(i ~/ 4, i % 4)) * t,
      );
    }

    return result;
  }
}
