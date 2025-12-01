import 'package:flutter/material.dart';
import '../theme_manager.dart';
import '../services/session_manager.dart';
import '../models/session.dart';
import '../widgets/session_list.dart';
import '../widgets/session_action_buttons.dart';
import '../simple_canvas_layout.dart';
import '../models/canvas_shape.dart';
import '../managers/shape_manager.dart';
import '../core/viewport_controller.dart';

/// SessionManagerScreen: Pre-canvas screen for managing Blueprint sessions
/// 
/// Features:
/// - Full-screen widget (not a dialog)
/// - Appears on app start, before opening canvas
/// - Responsive layout (mobile, tablet, desktop)
/// - Dark/Light theme compatible
/// - Create, load, save, delete sessions
/// - Clean, professional UI
class SessionManagerScreen extends StatefulWidget {
  final ThemeManager themeManager;

  const SessionManagerScreen({
    super.key,
    required this.themeManager,
  });

  @override
  State<SessionManagerScreen> createState() => _SessionManagerScreenState();
}

class _SessionManagerScreenState extends State<SessionManagerScreen> {
  late final SessionManager _sessionManager;
  Session? _selectedSession;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _sessionManager = SessionManager();
    _initializeSessions();
  }

  @override
  void dispose() {
    _sessionManager.dispose();
    super.dispose();
  }

  /// Initialize session manager and load sessions
  Future<void> _initializeSessions() async {
    try {
      setState(() => _isLoading = true);
      await _sessionManager.initialize();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e, stackTrace) {
      debugPrint('Error initializing sessions: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to initialize session manager: ${e.toString()}');
      }
    }
  }

  /// Create a new session and open canvas
  Future<void> _createNewSession() async {
    try {
      setState(() => _isLoading = true);
      debugPrint('Creating new session...');
      
      final session = await _sessionManager.createSession();
      debugPrint('Session created: ${session.id}');
      
      if (!mounted) return;
      setState(() => _isLoading = false);
      
      await _openCanvas(session);
    } catch (e, stackTrace) {
      debugPrint('Error creating session: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to create session: ${e.toString()}');
      }
    }
  }

  /// Load selected session and open canvas
  Future<void> _loadSession() async {
    if (_selectedSession == null) return;

    try {
      await _openCanvas(_selectedSession!);
    } catch (e) {
      _showError('Failed to load session: $e');
    }
  }

  /// Delete selected session with confirmation
  Future<void> _deleteSession() async {
    if (_selectedSession == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildDeleteConfirmationDialog(),
    );

    if (confirmed == true) {
      try {
        await _sessionManager.deleteSession(_selectedSession!);
        setState(() => _selectedSession = null);
        _showSuccess('Session deleted successfully');
      } catch (e) {
        _showError('Failed to delete session: $e');
      }
    }
  }

  /// Open canvas with session data
  Future<void> _openCanvas(Session session) async {
    try {
      debugPrint('Opening canvas for session: ${session.id}');
      
      // Load session data (will be empty for new sessions)
      final sessionData = await _sessionManager.loadSessionData(session);
      debugPrint('Loaded session data: ${sessionData.shapes.length} shapes');

      // Navigate to canvas
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => _CanvasScreenWrapper(
            themeManager: widget.themeManager,
            session: session,
            sessionManager: _sessionManager,
            initialSessionData: sessionData,
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Error opening canvas: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        _showError('Failed to open canvas: ${e.toString()}');
      }
    }
  }

  /// Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Show success message
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Build delete confirmation dialog
  Widget _buildDeleteConfirmationDialog() {
    return AnimatedBuilder(
      animation: widget.themeManager,
      builder: (context, _) {
        final theme = widget.themeManager.currentTheme;

        return AlertDialog(
          backgroundColor: theme.panelColor,
          title: Text(
            'Delete Session',
            style: TextStyle(color: theme.textColor),
          ),
          content: Text(
            'Are you sure you want to delete "${_selectedSession?.name}"? This action cannot be undone.',
            style: TextStyle(color: theme.textColor.withValues(alpha: 0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: theme.textColor.withValues(alpha: 0.7)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.themeManager,
      builder: (context, _) {
        final theme = widget.themeManager.currentTheme;

        return Scaffold(
          backgroundColor: theme.backgroundColor,
          appBar: AppBar(
            title: Text(
              'Blueprint Sessions',
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: theme.panelColor,
            elevation: 0,
            iconTheme: IconThemeData(color: theme.textColor),
          ),
          body: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: theme.accentColor,
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Reduced top spacing
                        const SizedBox(height: 16),

                        // Card container with session list and actions
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: theme.panelColor,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: theme.borderColor.withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                // Session list inside card
                                Expanded(
                                  child: AnimatedBuilder(
                                    animation: _sessionManager,
                                    builder: (context, _) {
                                      return SessionList(
                                        sessions: _sessionManager.sessions,
                                        selectedSession: _selectedSession,
                                        themeManager: widget.themeManager,
                                        onSessionSelected: (session) {
                                          setState(() => _selectedSession = session);
                                        },
                                        onSessionOpened: (session) {
                                          _selectedSession = session;
                                          _loadSession();
                                        },
                                      );
                                    },
                                  ),
                                ),

                                // Action buttons inside card footer
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: theme.backgroundColor.withValues(alpha: 0.3),
                                    border: Border(
                                      top: BorderSide(
                                        color: theme.borderColor.withValues(alpha: 0.15),
                                        width: 1,
                                      ),
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(24),
                                      bottomRight: Radius.circular(24),
                                    ),
                                  ),
                                  child: SessionActionButtons(
                                    themeManager: widget.themeManager,
                                    hasSelection: _selectedSession != null,
                                    onNewSession: _createNewSession,
                                    onLoadSession: _loadSession,
                                    onDeleteSession: _deleteSession,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Bottom spacing
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

/// CanvasScreenWrapper: Wraps SimpleCanvasLayout with session management
/// 
/// Handles:
/// - Loading session data into canvas
/// - Saving canvas data to session
/// - Navigating back to session manager
class _CanvasScreenWrapper extends StatefulWidget {
  final ThemeManager themeManager;
  final Session session;
  final SessionManager sessionManager;
  final CanvasSessionData initialSessionData;

  const _CanvasScreenWrapper({
    required this.themeManager,
    required this.session,
    required this.sessionManager,
    required this.initialSessionData,
  });

  @override
  State<_CanvasScreenWrapper> createState() => _CanvasScreenWrapperState();
}

class _CanvasScreenWrapperState extends State<_CanvasScreenWrapper> {
  late final ShapeManager _shapeManager;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _shapeManager = ShapeManager();
    _loadSessionData();
  }

  @override
  void dispose() {
    _shapeManager.dispose();
    super.dispose();
  }

  /// Load session data into canvas
  void _loadSessionData() {
    // Load shapes from session data
    for (final shapeJson in widget.initialSessionData.shapes) {
      try {
        // Convert JSON to CanvasShape
        // This is a simplified version - you may need to adjust based on your CanvasShape structure
        final shape = _shapeFromJson(shapeJson);
        if (shape != null) {
          _shapeManager.addShape(shape);
        }
      } catch (e) {
        debugPrint('Error loading shape: $e');
      }
    }

    // Mark as changed when shapes are modified
    _shapeManager.addListener(_onShapesChanged);
  }

  /// Convert JSON to CanvasShape
  CanvasShape? _shapeFromJson(Map<String, dynamic> json) {
    try {
      // Parse shape type from string (e.g., "ShapeType.rectangle")
      final typeString = json['type'] as String;
      ShapeType shapeType = ShapeType.rectangle;
      try {
        final typeName = typeString.split('.').last;
        shapeType = ShapeType.values.firstWhere(
          (e) => e.toString().split('.').last == typeName,
          orElse: () => ShapeType.rectangle,
        );
      } catch (e) {
        debugPrint('Error parsing shape type: $e');
      }

      return CanvasShape(
        id: json['id'] as String,
        position: Offset(
          (json['position'] as Map<String, dynamic>)['dx'] as double,
          (json['position'] as Map<String, dynamic>)['dy'] as double,
        ),
        size: Size(
          (json['size'] as Map<String, dynamic>)['width'] as double,
          (json['size'] as Map<String, dynamic>)['height'] as double,
        ),
        type: shapeType,
        color: Color(json['color'] as int),
        text: json['text'] as String? ?? '',
        isSelected: false,
        cornerRadius: (json['cornerRadius'] as num?)?.toDouble() ?? 8.0,
      );
    } catch (e) {
      debugPrint('Error parsing shape: $e');
      return null;
    }
  }

  /// Handle shape changes
  void _onShapesChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  /// Save canvas data to session
  Future<void> _saveSession() async {
    try {
      // Convert shapes to JSON
      final shapesJson = _shapeManager.shapes.map((shape) => _shapeToJson(shape)).toList();

      final sessionData = CanvasSessionData(
        shapes: shapesJson,
        // Add viewport and settings if needed
      );

      await widget.sessionManager.saveSessionData(widget.session, sessionData);
      setState(() => _hasUnsavedChanges = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Session saved successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving session: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Convert CanvasShape to JSON
  Map<String, dynamic> _shapeToJson(CanvasShape shape) {
    return {
      'id': shape.id,
      'position': {'dx': shape.position.dx, 'dy': shape.position.dy},
      'size': {'width': shape.size.width, 'height': shape.size.height},
      'type': shape.type.toString(),
      // ignore: deprecated_member_use
      'color': shape.color.value, // Using value for JSON serialization
      'text': shape.text,
      'cornerRadius': shape.cornerRadius,
    };
  }

  /// Handle back button press
  Future<bool> _onWillPop() async {
    if (_hasUnsavedChanges) {
      final save = await showDialog<bool>(
        context: context,
        builder: (context) => _buildSaveConfirmationDialog(),
      );

      if (save == true) {
        await _saveSession();
        // Wait a bit for save to complete
        await Future.delayed(const Duration(milliseconds: 100));
      } else if (save == false) {
        // User chose to discard
        return true;
      } else {
        // User cancelled the dialog
        return false;
      }
    }

    return true;
  }

  /// Build save confirmation dialog
  Widget _buildSaveConfirmationDialog() {
    return AnimatedBuilder(
      animation: widget.themeManager,
      builder: (context, _) {
        final theme = widget.themeManager.currentTheme;

        return AlertDialog(
          backgroundColor: theme.panelColor,
          title: Text(
            'Save Changes',
            style: TextStyle(color: theme.textColor),
          ),
          content: Text(
            'You have unsaved changes. Do you want to save before leaving?',
            style: TextStyle(color: theme.textColor.withValues(alpha: 0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Discard',
                style: TextStyle(color: theme.textColor.withValues(alpha: 0.7)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(
                'Cancel',
                style: TextStyle(color: theme.textColor.withValues(alpha: 0.7)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: theme.accentColor,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          }
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            SimpleCanvasLayout(
              themeManager: widget.themeManager,
              shapeManager: _shapeManager,
              viewportController: ViewportController(),
            ),
            // Back and Save buttons overlay (top-left)
            Positioned(
              top: 16,
              left: 16,
              child: AnimatedBuilder(
                animation: widget.themeManager,
                builder: (context, _) {
                  final theme = widget.themeManager.currentTheme;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Back button
                      ElevatedButton.icon(
                        onPressed: () async {
                          final shouldPop = await _onWillPop();
                          if (shouldPop && mounted && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('Back to Sessions'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.panelColor,
                          foregroundColor: theme.textColor,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: theme.borderColor.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Save button
                      ElevatedButton.icon(
                        onPressed: _saveSession,
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('Save Session'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

