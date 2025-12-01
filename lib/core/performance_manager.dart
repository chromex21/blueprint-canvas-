import 'dart:collection';
// 'dart:math' not currently used; removed to reduce analyzer noise
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/canvas_node.dart';
// NodeManager not referenced in this file; remove unused import
import 'viewport_controller.dart';

/// PerformanceManager: Advanced performance optimization for large-scale canvas operations
///
/// Features:
/// - Advanced viewport culling with margin and LOD
/// - Object pooling for geometry and paint objects
/// - Render caching for complex shapes and groups
/// - Spatial indexing for fast collision detection
/// - Level-of-detail (LOD) rendering based on zoom
/// - Frame rate monitoring and adaptive quality
class PerformanceManager {
  // Performance configuration
  static const int maxVisibleNodes = 1000; // Maximum nodes to render per frame
  static const double cullingMargin = 100.0; // Extra margin for culling bounds
  static const int maxCacheSize = 500; // Maximum cached render objects
  static const double lodThreshold1 =
      0.8; // Below this scale, use simplified rendering
  static const double lodThreshold2 =
      0.6; // Below this scale, use minimal rendering

  // Object pools
  final Queue<Paint> _paintPool = Queue<Paint>();
  final Queue<Path> _pathPool = Queue<Path>();
  final Queue<Rect> _rectPool = Queue<Rect>();

  // Render cache
  final Map<String, CachedRenderData> _renderCache = {};
  final LinkedHashMap<String, int> _cacheAccessOrder = LinkedHashMap();

  // Spatial indexing
  final Map<String, _SpatialCell> _spatialGrid = {};
  final double _gridCellSize = 200.0; // Grid cell size for spatial indexing

  // Performance metrics
  int _frameCount = 0;
  int _lastRenderedNodes = 0;
  double _averageFrameTime = 16.67; // Target 60fps
  final List<double> _frameTimeSamples = [];

  // Level of detail state
  LODLevel _currentLOD = LODLevel.full;

  // ============================================================================
  // VIEWPORT CULLING WITH ADVANCED OPTIMIZATIONS
  // ============================================================================

  /// Advanced viewport culling with spatial indexing and LOD
  List<CanvasNode> cullVisibleNodes(
    List<CanvasNode> allNodes,
    Rect viewportBounds,
    ViewportController viewportController,
  ) {
    final stopwatch = Stopwatch()..start();

    // Update LOD based on zoom level
    _updateLevelOfDetail(viewportController.scale);

    // Expand viewport bounds with margin for smooth scrolling
    final expandedBounds = viewportBounds.inflate(cullingMargin);

    // Use spatial indexing for efficient culling
    final visibleNodes = _spatialCull(allNodes, expandedBounds);

    // Apply additional optimizations based on node count
    final optimizedNodes = _applyRenderOptimizations(visibleNodes);

    _lastRenderedNodes = optimizedNodes.length;
    stopwatch.stop();
    _recordFrameTime(stopwatch.elapsedMicroseconds / 1000.0);

    return optimizedNodes;
  }

  /// Spatial grid-based culling for O(1) average case performance
  List<CanvasNode> _spatialCull(List<CanvasNode> nodes, Rect bounds) {
    _updateSpatialGrid(nodes);

    final visibleNodes = <CanvasNode>[];

    // Calculate grid cells that intersect with viewport
    final minX = (bounds.left / _gridCellSize).floor();
    final maxX = (bounds.right / _gridCellSize).ceil();
    final minY = (bounds.top / _gridCellSize).floor();
    final maxY = (bounds.bottom / _gridCellSize).ceil();

    // Check only relevant grid cells
    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        final cellKey = '$x,$y';
        final cell = _spatialGrid[cellKey];

        if (cell != null) {
          for (final node in cell.nodes) {
            if (_nodeIntersectsBounds(node, bounds)) {
              visibleNodes.add(node);
            }
          }
        }
      }
    }

    return visibleNodes;
  }

  /// Update spatial grid with current node positions
  void _updateSpatialGrid(List<CanvasNode> nodes) {
    // Clear previous frame data
    _spatialGrid.clear();

    // Populate grid cells
    for (final node in nodes) {
      final cellX = (node.position.dx / _gridCellSize).floor();
      final cellY = (node.position.dy / _gridCellSize).floor();
      final cellKey = '$cellX,$cellY';

      final cell = _spatialGrid.putIfAbsent(cellKey, () => _SpatialCell());
      cell.nodes.add(node);
    }
  }

  /// Check if node intersects with bounds (with node size consideration)
  bool _nodeIntersectsBounds(CanvasNode node, Rect bounds) {
    final nodeSize = _getNodeSize(node);
    final nodeRect = Rect.fromCenter(
      center: node.position,
      width: nodeSize.width,
      height: nodeSize.height,
    );

    return nodeRect.overlaps(bounds);
  }

  Size _getNodeSize(CanvasNode node) {
    // Return appropriate size based on node type
    switch (node.type) {
      case NodeType.shapeRect:
        return const Size(120, 80);
      case NodeType.shapeCircle:
        return const Size(100, 100);
      case NodeType.shapeTriangle:
        return const Size(100, 100);
      case NodeType.shapeDiamond:
        return const Size(120, 80);
      case NodeType.shapeHexagon:
        return const Size(110, 110);
      default:
        return const Size(100, 80);
    }
  }

  // ============================================================================
  // LEVEL OF DETAIL (LOD) SYSTEM
  // ============================================================================

  void _updateLevelOfDetail(double scale) {
    if (scale < lodThreshold2) {
      _currentLOD = LODLevel.minimal;
    } else if (scale < lodThreshold1) {
      _currentLOD = LODLevel.simplified;
    } else {
      _currentLOD = LODLevel.full;
    }
  }

  LODLevel getCurrentLOD() => _currentLOD;

  /// Apply rendering optimizations based on performance metrics
  List<CanvasNode> _applyRenderOptimizations(List<CanvasNode> nodes) {
    // If we have too many nodes, prioritize based on importance
    if (nodes.length > maxVisibleNodes) {
      // Sort by distance from viewport center or importance
      nodes.sort((a, b) {
        // For now, simple sorting by position - can be enhanced
        return a.position.distance.compareTo(b.position.distance);
      });

      return nodes.take(maxVisibleNodes).toList();
    }

    return nodes;
  }

  // ============================================================================
  // OBJECT POOLING SYSTEM
  // ============================================================================

  /// Get pooled Paint object to avoid allocations
  Paint getPaint() {
    if (_paintPool.isNotEmpty) {
      return _paintPool.removeFirst()..reset();
    }
    return Paint();
  }

  /// Return Paint object to pool
  void returnPaint(Paint paint) {
    if (_paintPool.length < 50) {
      // Limit pool size
      _paintPool.add(paint);
    }
  }

  /// Get pooled Path object
  Path getPath() {
    if (_pathPool.isNotEmpty) {
      return _pathPool.removeFirst()..reset();
    }
    return Path();
  }

  /// Return Path object to pool
  void returnPath(Path path) {
    if (_pathPool.length < 50) {
      _pathPool.add(path);
    }
  }

  /// Get pooled Rect object
  Rect getRect(double left, double top, double right, double bottom) {
    // For Rect, we can't pool effectively due to immutability
    // But we can cache common rect calculations
    return Rect.fromLTRB(left, top, right, bottom);
  }

  // ============================================================================
  // RENDER CACHING SYSTEM
  // ============================================================================

  /// Get cached render data for a node
  CachedRenderData? getCachedRender(String nodeId, double scale) {
    final cacheKey = '$nodeId@${scale.toStringAsFixed(2)}';
    final cached = _renderCache[cacheKey];

    if (cached != null) {
      // Update access order for LRU cache
      _cacheAccessOrder.remove(cacheKey);
      _cacheAccessOrder[cacheKey] = DateTime.now().millisecondsSinceEpoch;
      return cached;
    }

    return null;
  }

  /// Cache render data for a node
  void cacheRender(String nodeId, double scale, ui.Picture picture) {
    final cacheKey = '$nodeId@${scale.toStringAsFixed(2)}';

    // Implement LRU cache eviction
    if (_renderCache.length >= maxCacheSize) {
      _evictOldestCacheEntry();
    }

    _renderCache[cacheKey] = CachedRenderData(
      picture: picture,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    _cacheAccessOrder[cacheKey] = DateTime.now().millisecondsSinceEpoch;
  }

  void _evictOldestCacheEntry() {
    if (_cacheAccessOrder.isNotEmpty) {
      final oldestKey = _cacheAccessOrder.keys.first;
      _renderCache.remove(oldestKey);
      _cacheAccessOrder.remove(oldestKey);
    }
  }

  /// Clear render cache (call when nodes change significantly)
  void clearRenderCache() {
    _renderCache.clear();
    _cacheAccessOrder.clear();
  }

  // ============================================================================
  // PERFORMANCE MONITORING
  // ============================================================================

  void _recordFrameTime(double frameTime) {
    _frameTimeSamples.add(frameTime);

    // Keep only recent samples
    if (_frameTimeSamples.length > 60) {
      _frameTimeSamples.removeAt(0);
    }

    // Calculate rolling average
    if (_frameTimeSamples.isNotEmpty) {
      _averageFrameTime =
          _frameTimeSamples.reduce((a, b) => a + b) / _frameTimeSamples.length;
    }

    _frameCount++;
  }

  /// Get current performance metrics
  PerformanceMetrics getMetrics() {
    return PerformanceMetrics(
      frameCount: _frameCount,
      averageFrameTime: _averageFrameTime,
      lastRenderedNodes: _lastRenderedNodes,
      currentLOD: _currentLOD,
      cacheSize: _renderCache.length,
      fps: 1000.0 / _averageFrameTime,
    );
  }

  /// Dispose of resources
  void dispose() {
    _renderCache.clear();
    _cacheAccessOrder.clear();
    _spatialGrid.clear();
    _paintPool.clear();
    _pathPool.clear();
    _rectPool.clear();
  }
}

// ============================================================================
// SUPPORTING CLASSES AND ENUMS
// ============================================================================

enum LODLevel {
  minimal, // Just colored rectangles
  simplified, // Basic shapes without details
  full, // Full detail rendering
}

class _SpatialCell {
  final List<CanvasNode> nodes = [];
}

class CachedRenderData {
  final ui.Picture picture;
  final int timestamp;

  CachedRenderData({required this.picture, required this.timestamp});
}

class PerformanceMetrics {
  final int frameCount;
  final double averageFrameTime;
  final int lastRenderedNodes;
  final LODLevel currentLOD;
  final int cacheSize;
  final double fps;

  const PerformanceMetrics({
    required this.frameCount,
    required this.averageFrameTime,
    required this.lastRenderedNodes,
    required this.currentLOD,
    required this.cacheSize,
    required this.fps,
  });

  @override
  String toString() {
    return 'Performance: ${fps.toStringAsFixed(1)}fps, '
        '$lastRenderedNodes nodes, '
        'LOD: ${currentLOD.name}, '
        'Cache: $cacheSize';
  }
}

/// Extension for Paint object reset
extension PaintReset on Paint {
  void reset() {
    color = const Color(0xFF000000);
    strokeWidth = 0.0;
    style = PaintingStyle.fill;
    strokeCap = StrokeCap.butt;
    strokeJoin = StrokeJoin.miter;
    isAntiAlias = true;
  }
}
