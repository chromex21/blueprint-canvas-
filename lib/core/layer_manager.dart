import 'package:flutter/material.dart';
import '../managers/node_manager.dart';

/// Layer: Represents a logical grouping of canvas elements
class CanvasLayer {
  final String id;
  final String name;
  final bool isVisible;
  final bool isLocked;
  final double opacity;
  final Set<String> nodeIds;
  final Color color;
  final int zOrder;

  const CanvasLayer({
    required this.id,
    required this.name,
    this.isVisible = true,
    this.isLocked = false,
    this.opacity = 1.0,
    Set<String>? nodeIds,
    this.color = Colors.grey,
    this.zOrder = 0,
  }) : nodeIds = nodeIds ?? const <String>{};

  CanvasLayer copyWith({
    String? name,
    bool? isVisible,
    bool? isLocked,
    double? opacity,
    Set<String>? nodeIds,
    Color? color,
    int? zOrder,
  }) {
    return CanvasLayer(
      id: id,
      name: name ?? this.name,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
      opacity: opacity ?? this.opacity,
      nodeIds: nodeIds ?? this.nodeIds,
      color: color ?? this.color,
      zOrder: zOrder ?? this.zOrder,
    );
  }

  /// Check if this layer contains a specific node
  bool containsNode(String nodeId) => nodeIds.contains(nodeId);

  /// Get node count in this layer
  int get nodeCount => nodeIds.length;
}

/// LayerManager: Manages canvas layers for organization and rendering control
class LayerManager extends ChangeNotifier {
  final List<CanvasLayer> _layers = [];
  final NodeManager _nodeManager;
  String? _activeLayerId;
  int _nextZOrder = 0;

  LayerManager({required NodeManager nodeManager})
    : _nodeManager = nodeManager {
    // Create default layer
    _createDefaultLayer();

    // Listen to node changes
    _nodeManager.addListener(_onNodesChanged);
  }

  // ============================================================================
  // GETTERS
  // ============================================================================

  List<CanvasLayer> get layers => List.unmodifiable(_layers);
  String? get activeLayerId => _activeLayerId;
  CanvasLayer? get activeLayer => getLayer(_activeLayerId);
  int get layerCount => _layers.length;

  /// Get layers sorted by z-order (bottom to top)
  List<CanvasLayer> get layersByZOrder {
    final sorted = List<CanvasLayer>.from(_layers);
    sorted.sort((a, b) => a.zOrder.compareTo(b.zOrder));
    return sorted;
  }

  /// Get visible layers only
  List<CanvasLayer> get visibleLayers {
    return _layers.where((layer) => layer.isVisible).toList();
  }

  // ============================================================================
  // LAYER CRUD OPERATIONS
  // ============================================================================

  /// Create a new layer
  String createLayer({
    String? name,
    Color? color,
    bool? isVisible,
    bool? isLocked,
    double? opacity,
  }) {
    final id = 'layer_${DateTime.now().microsecondsSinceEpoch}';
    final layerName = name ?? 'Layer ${_layers.length + 1}';

    final layer = CanvasLayer(
      id: id,
      name: layerName,
      isVisible: isVisible ?? true,
      isLocked: isLocked ?? false,
      opacity: opacity ?? 1.0,
      color: color ?? _generateLayerColor(),
      zOrder: _nextZOrder++,
    );

    _layers.add(layer);
    _activeLayerId = id;
    notifyListeners();

    return id;
  }

  /// Delete a layer (moves nodes to default layer)
  bool deleteLayer(String layerId) {
    if (_layers.length <= 1) return false; // Can't delete last layer

    final layer = getLayer(layerId);
    if (layer == null) return false;

    // Move all nodes to default layer
    final defaultLayer = _layers.first;
    if (layer.nodeIds.isNotEmpty) {
      final updatedDefault = defaultLayer.copyWith(
        nodeIds: Set<String>.from(defaultLayer.nodeIds)..addAll(layer.nodeIds),
      );
      _updateLayer(defaultLayer.id, updatedDefault);
    }

    // Remove layer
    _layers.removeWhere((l) => l.id == layerId);

    // Update active layer if needed
    if (_activeLayerId == layerId) {
      _activeLayerId = _layers.first.id;
    }

    notifyListeners();
    return true;
  }

  /// Get layer by ID
  CanvasLayer? getLayer(String? layerId) {
    if (layerId == null) return null;
    try {
      return _layers.firstWhere((layer) => layer.id == layerId);
    } catch (e) {
      return null;
    }
  }

  /// Update layer properties
  void updateLayer(
    String layerId, {
    String? name,
    bool? isVisible,
    bool? isLocked,
    double? opacity,
    Color? color,
  }) {
    final layer = getLayer(layerId);
    if (layer == null) return;

    final updatedLayer = layer.copyWith(
      name: name,
      isVisible: isVisible,
      isLocked: isLocked,
      opacity: opacity,
      color: color,
    );

    _updateLayer(layerId, updatedLayer);
  }

  void _updateLayer(String layerId, CanvasLayer updatedLayer) {
    final index = _layers.indexWhere((l) => l.id == layerId);
    if (index != -1) {
      _layers[index] = updatedLayer;
      notifyListeners();
    }
  }

  /// Set active layer
  void setActiveLayer(String layerId) {
    if (getLayer(layerId) != null) {
      _activeLayerId = layerId;
      notifyListeners();
    }
  }

  // ============================================================================
  // NODE-LAYER MANAGEMENT
  // ============================================================================

  /// Add node to specific layer
  void addNodeToLayer(String nodeId, String layerId) {
    final layer = getLayer(layerId);
    if (layer == null) return;

    // Remove from other layers first
    _removeNodeFromAllLayers(nodeId);

    // Add to target layer
    final updatedLayer = layer.copyWith(
      nodeIds: Set<String>.from(layer.nodeIds)..add(nodeId),
    );
    _updateLayer(layerId, updatedLayer);
  }

  /// Move node to different layer
  void moveNodeToLayer(String nodeId, String targetLayerId) {
    addNodeToLayer(nodeId, targetLayerId);
  }

  /// Remove node from all layers
  void _removeNodeFromAllLayers(String nodeId) {
    for (final layer in _layers) {
      if (layer.containsNode(nodeId)) {
        final updatedLayer = layer.copyWith(
          nodeIds: Set<String>.from(layer.nodeIds)..remove(nodeId),
        );
        _updateLayer(layer.id, updatedLayer);
      }
    }
  }

  /// Get layer containing a specific node
  CanvasLayer? getNodeLayer(String nodeId) {
    try {
      return _layers.firstWhere((layer) => layer.containsNode(nodeId));
    } catch (e) {
      return null;
    }
  }

  /// Get all nodes in a specific layer
  List<String> getLayerNodeIds(String layerId) {
    final layer = getLayer(layerId);
    return layer?.nodeIds.toList() ?? [];
  }

  // ============================================================================
  // LAYER ORDERING
  // ============================================================================

  /// Move layer up in z-order
  void moveLayerUp(String layerId) {
    final layer = getLayer(layerId);
    if (layer == null) return;

    // Find layer above this one
    final layersSorted = layersByZOrder;
    final currentIndex = layersSorted.indexWhere((l) => l.id == layerId);

    if (currentIndex < layersSorted.length - 1) {
      final targetLayer = layersSorted[currentIndex + 1];
      final newZOrder = targetLayer.zOrder;

      // Swap z-orders
      _updateLayer(layerId, layer.copyWith(zOrder: newZOrder));
      _updateLayer(targetLayer.id, targetLayer.copyWith(zOrder: layer.zOrder));
    }
  }

  /// Move layer down in z-order
  void moveLayerDown(String layerId) {
    final layer = getLayer(layerId);
    if (layer == null) return;

    // Find layer below this one
    final layersSorted = layersByZOrder;
    final currentIndex = layersSorted.indexWhere((l) => l.id == layerId);

    if (currentIndex > 0) {
      final targetLayer = layersSorted[currentIndex - 1];
      final newZOrder = targetLayer.zOrder;

      // Swap z-orders
      _updateLayer(layerId, layer.copyWith(zOrder: newZOrder));
      _updateLayer(targetLayer.id, targetLayer.copyWith(zOrder: layer.zOrder));
    }
  }

  /// Send layer to back
  void sendLayerToBack(String layerId) {
    final layer = getLayer(layerId);
    if (layer == null) return;

    // Find minimum z-order and set this layer below it
    final minZOrder = _layers
        .map((l) => l.zOrder)
        .fold<int>(_nextZOrder, (min, z) => z < min ? z : min);

    _updateLayer(layerId, layer.copyWith(zOrder: minZOrder - 1));
  }

  /// Bring layer to front
  void bringLayerToFront(String layerId) {
    final layer = getLayer(layerId);
    if (layer == null) return;

    _updateLayer(layerId, layer.copyWith(zOrder: _nextZOrder++));
  }

  // ============================================================================
  // LAYER VISIBILITY & INTERACTION
  // ============================================================================

  /// Toggle layer visibility
  void toggleLayerVisibility(String layerId) {
    final layer = getLayer(layerId);
    if (layer != null) {
      updateLayer(layerId, isVisible: !layer.isVisible);
    }
  }

  /// Toggle layer lock state
  void toggleLayerLock(String layerId) {
    final layer = getLayer(layerId);
    if (layer != null) {
      updateLayer(layerId, isLocked: !layer.isLocked);
    }
  }

  /// Check if a node can be interacted with (layer not locked and visible)
  bool canInteractWithNode(String nodeId) {
    final layer = getNodeLayer(nodeId);
    return layer != null && layer.isVisible && !layer.isLocked;
  }

  /// Get effective opacity for a node (combines layer and node opacity)
  double getNodeEffectiveOpacity(String nodeId) {
    final layer = getNodeLayer(nodeId);
    return layer?.opacity ?? 1.0;
  }

  // ============================================================================
  // BULK OPERATIONS
  // ============================================================================

  /// Hide all layers except specified one
  void soloLayer(String layerId) {
    for (final layer in _layers) {
      updateLayer(layer.id, isVisible: layer.id == layerId);
    }
  }

  /// Show all layers
  void showAllLayers() {
    for (final layer in _layers) {
      updateLayer(layer.id, isVisible: true);
    }
  }

  /// Lock all layers except specified one
  void lockAllExcept(String layerId) {
    for (final layer in _layers) {
      updateLayer(layer.id, isLocked: layer.id != layerId);
    }
  }

  /// Unlock all layers
  void unlockAllLayers() {
    for (final layer in _layers) {
      updateLayer(layer.id, isLocked: false);
    }
  }

  // ============================================================================
  // INTERNAL HELPERS
  // ============================================================================

  void _createDefaultLayer() {
    final defaultLayer = CanvasLayer(
      id: 'default_layer',
      name: 'Main Layer',
      color: Colors.blue,
      zOrder: _nextZOrder++,
    );
    _layers.add(defaultLayer);
    _activeLayerId = defaultLayer.id;
  }

  void _onNodesChanged() {
    // When nodes are added/removed, ensure they're in a layer
    final allNodeIds = _nodeManager.nodes.map((n) => n.id).toSet();
    final layerNodeIds = _layers.expand((l) => l.nodeIds).toSet();

    // Add orphaned nodes to active layer
    final orphanedNodes = allNodeIds.difference(layerNodeIds);
    if (orphanedNodes.isNotEmpty && _activeLayerId != null) {
      final activeLayer = getLayer(_activeLayerId!);
      if (activeLayer != null) {
        final updatedLayer = activeLayer.copyWith(
          nodeIds: Set<String>.from(activeLayer.nodeIds)..addAll(orphanedNodes),
        );
        _updateLayer(_activeLayerId!, updatedLayer);
      }
    }

    // Remove deleted nodes from layers
    final deletedNodes = layerNodeIds.difference(allNodeIds);
    for (final nodeId in deletedNodes) {
      _removeNodeFromAllLayers(nodeId);
    }
  }

  Color _generateLayerColor() {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    return colors[_layers.length % colors.length];
  }

  @override
  void dispose() {
    _nodeManager.removeListener(_onNodesChanged);
    super.dispose();
  }
}
