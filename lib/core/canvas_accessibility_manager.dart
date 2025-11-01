import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import '../models/canvas_node.dart';
import '../managers/node_manager.dart';
import 'viewport_controller.dart';

/// CanvasAccessibilityManager: Provides comprehensive accessibility support
///
/// Features:
/// - Screen reader support with semantic descriptions
/// - Keyboard navigation for all canvas elements
/// - Focus management with visual indicators
/// - High contrast mode compatibility
/// - Voice-over announcements for state changes
/// - Alternative text for visual elements
class CanvasAccessibilityManager extends ChangeNotifier {
  final NodeManager _nodeManager;
  final ViewportController _viewportController;

  // Focus management
  String? _focusedNodeId;
  int _currentFocusIndex = 0;

  // Accessibility state
  bool _screenReaderMode = false;
  bool _highContrastMode = false;
  bool _announceActions = true;

  // Navigation state
  final List<String> _navigableElements = [];

  CanvasAccessibilityManager({
    required NodeManager nodeManager,
    required ViewportController viewportController,
  }) : _nodeManager = nodeManager,
       _viewportController = viewportController {
    // Listen to node changes to update navigable elements
    _nodeManager.addListener(_updateNavigableElements);
  }

  // ============================================================================
  // GETTERS
  // ============================================================================

  String? get focusedNodeId => _focusedNodeId;
  bool get screenReaderMode => _screenReaderMode;
  bool get highContrastMode => _highContrastMode;
  bool get announceActions => _announceActions;
  List<String> get navigableElements => List.unmodifiable(_navigableElements);

  int get totalElements => _navigableElements.length;
  int get currentFocusIndex => _currentFocusIndex;

  // ============================================================================
  // CONFIGURATION
  // ============================================================================

  void setScreenReaderMode(bool enabled) {
    if (_screenReaderMode != enabled) {
      _screenReaderMode = enabled;
      notifyListeners();

      if (enabled) {
        _announceMessage(
          'Screen reader mode enabled. Use Tab to navigate elements.',
        );
      }
    }
  }

  void setHighContrastMode(bool enabled) {
    if (_highContrastMode != enabled) {
      _highContrastMode = enabled;
      notifyListeners();

      if (_announceActions) {
        _announceMessage(
          enabled
              ? 'High contrast mode enabled'
              : 'High contrast mode disabled',
        );
      }
    }
  }

  void setAnnounceActions(bool enabled) {
    _announceActions = enabled;
    if (enabled) {
      _announceMessage('Action announcements enabled');
    }
  }

  // ============================================================================
  // FOCUS MANAGEMENT
  // ============================================================================

  /// Set focus to a specific node
  void focusNode(String nodeId) {
    if (_nodeManager.getNode(nodeId) != null) {
      _focusedNodeId = nodeId;
      _currentFocusIndex = _navigableElements.indexOf(nodeId);
      notifyListeners();

      final node = _nodeManager.getNode(nodeId)!;
      if (_announceActions) {
        _announceMessage(_generateNodeDescription(node));
      }
    }
  }

  /// Move focus to next element
  void focusNext() {
    if (_navigableElements.isEmpty) return;

    _currentFocusIndex = (_currentFocusIndex + 1) % _navigableElements.length;
    final nodeId = _navigableElements[_currentFocusIndex];
    focusNode(nodeId);
  }

  /// Move focus to previous element
  void focusPrevious() {
    if (_navigableElements.isEmpty) return;

    _currentFocusIndex = (_currentFocusIndex - 1) % _navigableElements.length;
    if (_currentFocusIndex < 0) {
      _currentFocusIndex = _navigableElements.length - 1;
    }
    final nodeId = _navigableElements[_currentFocusIndex];
    focusNode(nodeId);
  }

  /// Clear focus
  void clearFocus() {
    _focusedNodeId = null;
    _currentFocusIndex = 0;
    notifyListeners();
  }

  /// Focus first element
  void focusFirst() {
    if (_navigableElements.isNotEmpty) {
      _currentFocusIndex = 0;
      focusNode(_navigableElements.first);
    }
  }

  /// Focus last element
  void focusLast() {
    if (_navigableElements.isNotEmpty) {
      _currentFocusIndex = _navigableElements.length - 1;
      focusNode(_navigableElements.last);
    }
  }

  // ============================================================================
  // SEMANTIC DESCRIPTIONS
  // ============================================================================

  /// Generate semantic description for a node
  String _generateNodeDescription(CanvasNode node) {
    final buffer = StringBuffer();

    // Node type
    buffer.write(_getNodeTypeDescription(node.type));

    // Content
    if (node.content.isNotEmpty) {
      buffer.write(' with content: ${node.content}');
    }

    // Position
    buffer.write(
      ' at position ${node.position.dx.round()}, ${node.position.dy.round()}',
    );

    // Selection state
    if (node.isSelected) {
      buffer.write(', selected');
    }

    // Connections
    final connectionCount = node.connectedTo.length;
    if (connectionCount > 0) {
      buffer.write(
        ', connected to $connectionCount other ${connectionCount == 1 ? 'node' : 'nodes'}',
      );
    }

    return buffer.toString();
  }

  String _getNodeTypeDescription(NodeType type) {
    switch (type) {
      case NodeType.basicNode:
        return 'Basic node';
      case NodeType.stickyNote:
        return 'Sticky note';
      case NodeType.textBlock:
        return 'Text block';
      case NodeType.shapeRect:
        return 'Rectangle shape';
      case NodeType.shapeCircle:
        return 'Circle shape';
      case NodeType.shapeDiamond:
        return 'Diamond shape';
      case NodeType.shapeTriangle:
        return 'Triangle shape';
      case NodeType.shapeHexagon:
        return 'Hexagon shape';
    }
  }

  /// Generate canvas state description
  String generateCanvasDescription() {
    final buffer = StringBuffer();

    buffer.write('Interactive canvas with ${_nodeManager.nodeCount} nodes');

    if (_nodeManager.connectionCount > 0) {
      buffer.write(' and ${_nodeManager.connectionCount} connections');
    }

    final selectedCount = _nodeManager.selectedNodeIds.length;
    if (selectedCount > 0) {
      buffer.write(', $selectedCount selected');
    }

    // Viewport info
    final scale = _viewportController.scale;
    buffer.write(', zoom level ${(scale * 100).round()}%');

    return buffer.toString();
  }

  // ============================================================================
  // KEYBOARD NAVIGATION ACTIONS
  // ============================================================================

  /// Handle keyboard action for focused element
  bool handleKeyboardAction(String action) {
    if (_focusedNodeId == null) return false;

    switch (action) {
      case 'activate':
        // Simulate tap on focused node
        _nodeManager.selectNode(_focusedNodeId!);
        if (_announceActions) {
          _announceMessage('Node selected');
        }
        return true;

      case 'delete':
        _nodeManager.removeNode(_focusedNodeId!);
        if (_announceActions) {
          _announceMessage('Node deleted');
        }
        // Move focus to next available element
        if (_navigableElements.isNotEmpty) {
          focusNext();
        } else {
          clearFocus();
        }
        return true;

      case 'duplicate':
        final node = _nodeManager.getNode(_focusedNodeId!);
        if (node != null) {
          // Create a new node based on the existing one
          final duplicatedNode = CanvasNode(
            id: 'node_${DateTime.now().millisecondsSinceEpoch}',
            position: node.position + const Offset(50, 50),
            size: node.size,
            type: node.type,
            content: node.content,
            color: node.color,
            connectedTo: [], // Don't copy connections
          );
          _nodeManager.addNode(duplicatedNode);
          focusNode(duplicatedNode.id);
          if (_announceActions) {
            _announceMessage('Node duplicated');
          }
        }
        return true;

      default:
        return false;
    }
  }

  // ============================================================================
  // SEMANTIC WIDGET BUILDERS
  // ============================================================================

  /// Build semantic wrapper for a node
  Widget buildNodeSemantics({
    required CanvasNode node,
    required Widget child,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return Semantics(
      label: _generateNodeDescription(node),
      hint: 'Double tap to edit, long press for options',
      focused: _focusedNodeId == node.id,
      selected: node.isSelected,
      button: true,
      onTap: () {
        focusNode(node.id);
        onTap?.call();
      },
      onLongPress: onLongPress,
      child: Focus(
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            focusNode(node.id);
          }
        },
        child: child,
      ),
    );
  }

  /// Build canvas container semantics
  Widget buildCanvasSemantics({required Widget child}) {
    return Semantics(
      container: true,
      label: 'Canvas workspace',
      hint: generateCanvasDescription(),
      child: ExcludeSemantics(excluding: !_screenReaderMode, child: child),
    );
  }

  // ============================================================================
  // ANNOUNCEMENTS
  // ============================================================================

  void _announceMessage(String message) {
    if (!_announceActions) return;

    // Use SemanticsService to announce messages
    SemanticsService.announce(message, TextDirection.ltr);
  }

  /// Announce canvas state change
  void announceCanvasChange(String changeDescription) {
    if (_announceActions) {
      _announceMessage(changeDescription);
    }
  }

  /// Announce selection change
  void announceSelectionChange() {
    final selectedCount = _nodeManager.selectedNodeIds.length;

    String message;
    if (selectedCount == 0) {
      message = 'Selection cleared';
    } else if (selectedCount == 1) {
      final node = _nodeManager.getNode(_nodeManager.selectedNodeIds.first);
      message = node != null
          ? '${_getNodeTypeDescription(node.type)} selected'
          : 'Node selected';
    } else {
      message = '$selectedCount nodes selected';
    }

    _announceMessage(message);
  }

  // ============================================================================
  // INTERNAL HELPERS
  // ============================================================================

  void _updateNavigableElements() {
    _navigableElements.clear();
    _navigableElements.addAll(_nodeManager.nodes.map((node) => node.id));

    // Adjust focus index if needed
    if (_focusedNodeId != null &&
        !_navigableElements.contains(_focusedNodeId)) {
      clearFocus();
    } else if (_currentFocusIndex >= _navigableElements.length) {
      _currentFocusIndex = _navigableElements.length - 1;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _nodeManager.removeListener(_updateNavigableElements);
    super.dispose();
  }
}

/// Accessibility keyboard shortcuts helper
class CanvasAccessibilityShortcuts {
  static final Map<LogicalKeyboardKey, String> shortcuts = {
    LogicalKeyboardKey.tab: 'focus_next',
    LogicalKeyboardKey.enter: 'activate',
    LogicalKeyboardKey.space: 'activate',
    LogicalKeyboardKey.delete: 'delete',
    LogicalKeyboardKey.keyD: 'duplicate', // Ctrl+D
  };

  static String? getActionForKey(
    LogicalKeyboardKey key, {
    bool ctrlPressed = false,
  }) {
    if (ctrlPressed && key == LogicalKeyboardKey.keyD) {
      return 'duplicate';
    }
    return shortcuts[key];
  }
}
