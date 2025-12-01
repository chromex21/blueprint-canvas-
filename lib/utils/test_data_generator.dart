import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/canvas_node.dart';
import '../managers/node_manager.dart';

/// TestDataGenerator: Utility to generate large numbers of nodes for performance testing
class TestDataGenerator {
  static const List<Color> nodeColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.indigo,
    Colors.amber,
  ];

  static const List<NodeType> nodeTypes = [
    NodeType.basicNode,
    NodeType.shapeRect,
    NodeType.shapeCircle,
    NodeType.shapeDiamond,
    NodeType.shapeTriangle,
    NodeType.shapeHexagon,
    NodeType.stickyNote,
    NodeType.textBlock,
  ];

  /// Generate a grid of test nodes
  static void generateGrid(
    NodeManager nodeManager, {
    int columns = 10,
    int rows = 10,
    double spacing = 200.0,
    Offset center = Offset.zero,
  }) {
    final random = math.Random();

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < columns; col++) {
        final position = Offset(
          center.dx + (col - columns / 2) * spacing,
          center.dy + (row - rows / 2) * spacing,
        );

        final node = CanvasNode(
          id: 'test_node_${row}_$col',
          position: position,
          size: const Size(100, 80),
          type: nodeTypes[random.nextInt(nodeTypes.length)],
          content: 'Node $row,$col',
          color: nodeColors[random.nextInt(nodeColors.length)],
        );

        nodeManager.addNode(node);
      }
    }
  }

  /// Generate randomly distributed nodes
  static void generateRandom(
    NodeManager nodeManager, {
    int count = 100,
    double areaWidth = 2000.0,
    double areaHeight = 2000.0,
    Offset center = Offset.zero,
  }) {
    final random = math.Random();

    for (int i = 0; i < count; i++) {
      final position = Offset(
        center.dx + (random.nextDouble() - 0.5) * areaWidth,
        center.dy + (random.nextDouble() - 0.5) * areaHeight,
      );

      final node = CanvasNode(
        id: 'random_node_$i',
        position: position,
        size: Size(
          50 + random.nextDouble() * 100, // Width 50-150
          40 + random.nextDouble() * 80, // Height 40-120
        ),
        type: nodeTypes[random.nextInt(nodeTypes.length)],
        content: 'Node $i',
        color: nodeColors[random.nextInt(nodeColors.length)],
      );

      nodeManager.addNode(node);
    }
  }

  /// Generate a large number of nodes for stress testing
  static void generateStressTest(NodeManager nodeManager, {int count = 1000}) {
    generateRandom(
      nodeManager,
      count: count,
      areaWidth: 10000.0,
      areaHeight: 10000.0,
    );
  }

  /// Generate nodes in a spiral pattern
  static void generateSpiral(
    NodeManager nodeManager, {
    int count = 100,
    double spacing = 50.0,
    Offset center = Offset.zero,
  }) {
    final random = math.Random();

    for (int i = 0; i < count; i++) {
      final angle = i * 0.5;
      final radius = i * spacing / 10;

      final position = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      final node = CanvasNode(
        id: 'spiral_node_$i',
        position: position,
        size: const Size(80, 60),
        type: nodeTypes[random.nextInt(nodeTypes.length)],
        content: 'Spiral $i',
        color: nodeColors[random.nextInt(nodeColors.length)],
      );

      nodeManager.addNode(node);
    }
  }

  /// Generate connected nodes for connection performance testing
  static void generateConnectedNodes(
    NodeManager nodeManager, {
    int count = 50,
    double connectionProbability = 0.1,
  }) {
    // First generate random nodes
    generateRandom(
      nodeManager,
      count: count,
      areaWidth: 1500,
      areaHeight: 1500,
    );

    // Then add random connections
    final nodes = nodeManager.nodes;
    final random = math.Random();

    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        if (random.nextDouble() < connectionProbability) {
          // Add connection between nodes[i] and nodes[j]
          nodes[i].connectedTo.add(nodes[j].id);

          // Create a connection between the nodes
          nodeManager.connectNodes(nodes[i].id, nodes[j].id);
        }
      }
    }
  }

  /// Clear all test data
  static void clearTestData(NodeManager nodeManager) {
    // Remove all nodes that start with test prefixes
    final testPrefixes = ['test_node_', 'random_node_', 'spiral_node_'];

    final nodesToRemove = nodeManager.nodes
        .where(
          (node) => testPrefixes.any((prefix) => node.id.startsWith(prefix)),
        )
        .map((node) => node.id)
        .toList();

    for (final nodeId in nodesToRemove) {
      nodeManager.removeNode(nodeId);
    }
  }

  /// Get performance test recommendations
  static String getPerformanceTestInfo() {
    return '''
Performance Test Data Generator

Keyboard Shortcuts:
• Ctrl+Shift+1: Generate 10x10 grid (100 nodes)
• Ctrl+Shift+2: Generate 500 random nodes  
• Ctrl+Shift+3: Generate 1000+ stress test
• Ctrl+Shift+4: Generate spiral pattern
• Ctrl+Shift+5: Generate connected nodes
• Ctrl+Shift+0: Clear all test data

• Ctrl+P: Toggle performance metrics

Performance Features:
✓ Spatial indexing for O(1) culling
✓ Level-of-detail rendering at different zoom levels
✓ Object pooling for Paint/Path objects
✓ Render caching for complex shapes
✓ Adaptive quality based on frame rate

Zoom out to see LOD system:
• > 50% scale: Full detail rendering
• 20-50% scale: Simplified shapes  
• < 20% scale: Minimal rectangles
''';
  }
}
