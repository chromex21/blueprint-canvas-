import 'package:flutter/material.dart';
import '../models/canvas_node.dart';
import '../models/node_connection.dart';

/// NodeManager: Manages all canvas nodes and their connections
class NodeManager extends ChangeNotifier {
  final List<CanvasNode> _nodes = [];
  final List<NodeConnection> _connections = [];
  final Set<String> _selectedNodeIds = {};

  // Getters
  List<CanvasNode> get nodes => List.unmodifiable(_nodes);
  List<NodeConnection> get connections => List.unmodifiable(_connections);
  Set<String> get selectedNodeIds => Set.unmodifiable(_selectedNodeIds);
  
  List<CanvasNode> get selectedNodes =>
      _nodes.where((node) => _selectedNodeIds.contains(node.id)).toList();

  bool get hasSelection => _selectedNodeIds.isNotEmpty;
  int get nodeCount => _nodes.length;
  int get connectionCount => _connections.length;

  // ============================================================================
  // NODE CRUD OPERATIONS
  // ============================================================================

  /// Add a new node to the canvas
  void addNode(CanvasNode node) {
    _nodes.add(node);
    notifyListeners();
  }

  /// Remove a node and its connections
  void removeNode(String nodeId) {
    _nodes.removeWhere((node) => node.id == nodeId);
    _connections.removeWhere(
      (conn) => conn.sourceNodeId == nodeId || conn.targetNodeId == nodeId,
    );
    _selectedNodeIds.remove(nodeId);
    notifyListeners();
  }

  /// Remove all selected nodes
  void removeSelectedNodes() {
    for (final id in _selectedNodeIds.toList()) {
      removeNode(id);
    }
  }

  /// Update a node's properties
  void updateNode(String nodeId, CanvasNode updatedNode) {
    final index = _nodes.indexWhere((node) => node.id == nodeId);
    if (index != -1) {
      _nodes[index] = updatedNode;
      notifyListeners();
    }
  }

  /// Get a node by ID
  CanvasNode? getNode(String nodeId) {
    try {
      return _nodes.firstWhere((node) => node.id == nodeId);
    } catch (e) {
      return null;
    }
  }

  /// Find node at a specific position
  CanvasNode? getNodeAtPosition(Offset position) {
    // Search in reverse order (top to bottom in z-order)
    for (int i = _nodes.length - 1; i >= 0; i--) {
      if (_nodes[i].containsPoint(position)) {
        return _nodes[i];
      }
    }
    return null;
  }

  /// Clear all nodes and connections
  void clearCanvas() {
    _nodes.clear();
    _connections.clear();
    _selectedNodeIds.clear();
    notifyListeners();
  }

  // ============================================================================
  // SELECTION OPERATIONS
  // ============================================================================

  /// Select a single node
  void selectNode(String nodeId, {bool clearOthers = true}) {
    if (clearOthers) {
      _selectedNodeIds.clear();
    }
    _selectedNodeIds.add(nodeId);
    
    // Update node's selected state
    final node = getNode(nodeId);
    if (node != null) {
      updateNode(nodeId, node.copyWith(isSelected: true));
    }
    
    notifyListeners();
  }

  /// Deselect a single node
  void deselectNode(String nodeId) {
    _selectedNodeIds.remove(nodeId);
    
    // Update node's selected state
    final node = getNode(nodeId);
    if (node != null) {
      updateNode(nodeId, node.copyWith(isSelected: false));
    }
    
    notifyListeners();
  }

  /// Toggle node selection
  void toggleNodeSelection(String nodeId) {
    if (_selectedNodeIds.contains(nodeId)) {
      deselectNode(nodeId);
    } else {
      selectNode(nodeId, clearOthers: false);
    }
  }

  /// Select multiple nodes
  void selectMultiple(List<String> nodeIds) {
    _selectedNodeIds.clear();
    _selectedNodeIds.addAll(nodeIds);
    
    // Update all nodes' selected state
    for (final node in _nodes) {
      if (nodeIds.contains(node.id)) {
        updateNode(node.id, node.copyWith(isSelected: true));
      } else {
        updateNode(node.id, node.copyWith(isSelected: false));
      }
    }
    
    notifyListeners();
  }

  /// Clear all selections
  void clearSelection() {
    for (final nodeId in _selectedNodeIds.toList()) {
      final node = getNode(nodeId);
      if (node != null) {
        updateNode(nodeId, node.copyWith(isSelected: false));
      }
    }
    _selectedNodeIds.clear();
    notifyListeners();
  }

  /// Select nodes within a rectangle
  void selectNodesInRect(Rect selectionRect) {
    final nodesInRect = _nodes.where((node) {
      final nodeRect = Rect.fromLTWH(
        node.position.dx,
        node.position.dy,
        node.size.width,
        node.size.height,
      );
      return selectionRect.overlaps(nodeRect);
    }).map((node) => node.id).toList();

    selectMultiple(nodesInRect);
  }

  // ============================================================================
  // POSITIONING OPERATIONS
  // ============================================================================

  /// Move a node by a delta offset
  void moveNode(String nodeId, Offset delta) {
    final node = getNode(nodeId);
    if (node != null) {
      updateNode(
        nodeId,
        node.copyWith(position: node.position + delta),
      );
    }
  }

  /// Move all selected nodes by a delta offset
  void moveSelectedNodes(Offset delta) {
    for (final nodeId in _selectedNodeIds) {
      moveNode(nodeId, delta);
    }
  }

  /// Set node position directly
  void setNodePosition(String nodeId, Offset position) {
    final node = getNode(nodeId);
    if (node != null) {
      updateNode(nodeId, node.copyWith(position: position));
    }
  }

  /// Bring node to front (z-order)
  void bringToFront(String nodeId) {
    final node = getNode(nodeId);
    if (node != null) {
      _nodes.removeWhere((n) => n.id == nodeId);
      _nodes.add(node);
      notifyListeners();
    }
  }

  /// Send node to back (z-order)
  void sendToBack(String nodeId) {
    final node = getNode(nodeId);
    if (node != null) {
      _nodes.removeWhere((n) => n.id == nodeId);
      _nodes.insert(0, node);
      notifyListeners();
    }
  }

  // ============================================================================
  // CONNECTION OPERATIONS
  // ============================================================================

  /// Create a connection between two nodes
  void connectNodes(
    String sourceNodeId,
    String targetNodeId, {
    ConnectionType type = ConnectionType.arrow,
    Color? color,
  }) {
    // Don't create duplicate connections
    final existingConn = _connections.firstWhere(
      (conn) =>
          conn.sourceNodeId == sourceNodeId &&
          conn.targetNodeId == targetNodeId,
      orElse: () => NodeConnection(
        id: '',
        sourceNodeId: '',
        targetNodeId: '',
        color: Colors.transparent,
      ),
    );

    if (existingConn.id.isEmpty) {
      final connection = NodeConnection(
        id: NodeConnection.generateId(sourceNodeId, targetNodeId),
        sourceNodeId: sourceNodeId,
        targetNodeId: targetNodeId,
        type: type,
        color: color ?? Colors.grey,
      );

      _connections.add(connection);

      // Update source node's connection list
      final sourceNode = getNode(sourceNodeId);
      if (sourceNode != null) {
        final updatedConnections = List<String>.from(sourceNode.connectedTo)
          ..add(targetNodeId);
        updateNode(
          sourceNodeId,
          sourceNode.copyWith(connectedTo: updatedConnections),
        );
      }

      notifyListeners();
    }
  }

  /// Remove a connection
  void disconnectNodes(String sourceNodeId, String targetNodeId) {
    _connections.removeWhere(
      (conn) =>
          conn.sourceNodeId == sourceNodeId &&
          conn.targetNodeId == targetNodeId,
    );

    // Update source node's connection list
    final sourceNode = getNode(sourceNodeId);
    if (sourceNode != null) {
      final updatedConnections = List<String>.from(sourceNode.connectedTo)
        ..remove(targetNodeId);
      updateNode(
        sourceNodeId,
        sourceNode.copyWith(connectedTo: updatedConnections),
      );
    }

    notifyListeners();
  }

  /// Get all connections for a node
  List<NodeConnection> getNodeConnections(String nodeId) {
    return _connections
        .where(
          (conn) =>
              conn.sourceNodeId == nodeId || conn.targetNodeId == nodeId,
        )
        .toList();
  }

  // ============================================================================
  // CONTENT OPERATIONS
  // ============================================================================

  /// Update node content (text)
  void updateNodeContent(String nodeId, String content) {
    final node = getNode(nodeId);
    if (node != null) {
      updateNode(nodeId, node.copyWith(content: content));
    }
  }

  /// Update node color
  void updateNodeColor(String nodeId, Color color) {
    final node = getNode(nodeId);
    if (node != null) {
      updateNode(nodeId, node.copyWith(color: color));
    }
  }

  /// Update node size
  void updateNodeSize(String nodeId, Size size) {
    final node = getNode(nodeId);
    if (node != null) {
      updateNode(nodeId, node.copyWith(size: size));
    }
  }
}
