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

  // Constraints
  static const double minScale = 0.1;
  static const double maxScale = 5.0;
  static const double maxTranslation = 50000.0; // Virtually infinite

  // Animation support
  AnimationController? _animationController;
  Animation<Matrix4>? _transformAnimation;

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

  /// Zoom in/out centered on a specific point
  void zoomAt(Offset focalPoint, double deltaScale, Size canvasSize) {
    final double newScale = (_scale * deltaScale).clamp(minScale, maxScale);

    if (newScale == _scale) return; // No change needed

    // Convert focal point to world coordinates before scaling
    final worldFocal = screenToWorld(focalPoint, canvasSize);

    // Update scale
    _scale = newScale;

    // Adjust translation to keep focal point in same screen position
    final newScreenFocal = worldToScreen(worldFocal, canvasSize);
    final offset = focalPoint - newScreenFocal;

    _translation = Offset(
      (_translation.dx + offset.dx).clamp(-maxTranslation, maxTranslation),
      (_translation.dy + offset.dy).clamp(-maxTranslation, maxTranslation),
    );

    _updateTransform(canvasSize);
    notifyListeners();
  }

  /// Pan the viewport by a delta amount
  void pan(Offset delta) {
    _translation = Offset(
      (_translation.dx + delta.dx).clamp(-maxTranslation, maxTranslation),
      (_translation.dy + delta.dy).clamp(-maxTranslation, maxTranslation),
    );

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
  Matrix4 _buildTransformMatrix(Size canvasSize) {
    return Matrix4.identity()
      ..translate(_translation.dx, _translation.dy)
      ..scale(_scale, _scale);
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
