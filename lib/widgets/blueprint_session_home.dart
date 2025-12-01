import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/blueprint_session_manager.dart';
import '../models/session_info.dart';
import '../theme_manager.dart';
import 'session_carousel_view.dart';
import '../simple_canvas_layout.dart';
import '../managers/shape_manager.dart';
import '../managers/media_manager.dart';
import '../models/canvas_shape.dart';
import '../models/canvas_media.dart';
import '../core/viewport_controller.dart';
import 'dart:typed_data';
import 'dart:convert';

/// BlueprintSessionHome: Pre-canvas session management screen
/// 
/// Opens before the main canvas, allowing users to:
/// - Create a new session
/// - Load an existing session
/// - Delete sessions
/// - Rename sessions (optional)
/// 
/// After selecting/creating a session, navigates to canvas with session data loaded.
/// Handles missing/corrupted sessions gracefully with clear error dialogs.
class BlueprintSessionHome extends StatefulWidget {
  final ThemeManager themeManager;
  final BlueprintSessionManager sessionManager;
  final Function(String sessionName, Map<String, dynamic> sessionData)? onSessionSelected;

  const BlueprintSessionHome({
    super.key,
    required this.themeManager,
    required this.sessionManager,
    this.onSessionSelected,
  });

  @override
  State<BlueprintSessionHome> createState() => _BlueprintSessionHomeState();
}

enum SortMode {
  recentFirst,
  aToZ,
  zToA,
}

class _BlueprintSessionHomeState extends State<BlueprintSessionHome> {
  List<SessionInfo> _sessions = [];
  List<SessionInfo> _filteredSessions = [];
  bool _isLoading = true;
  SessionInfo? _selectedSession;
  String? _errorMessage;
  String _searchQuery = '';
  SortMode _sortMode = SortMode.recentFirst;
  final TextEditingController _searchController = TextEditingController();
  
  // Multi-select state
  bool _isSelectionMode = false;
  final Set<String> _selectedSessionNames = <String>{};

  @override
  void initState() {
    super.initState();
    _filteredSessions = [];
    _loadSessions();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// Handle search query changes
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _applyFiltersAndSort();
    });
  }

  /// Apply filters and sort to sessions
  void _applyFiltersAndSort() {
    var filtered = _sessions;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((session) =>
              session.name.toLowerCase().contains(_searchQuery))
          .toList();
    }

    // Apply sort
    switch (_sortMode) {
      case SortMode.recentFirst:
        filtered.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        break;
      case SortMode.aToZ:
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case SortMode.zToA:
        filtered.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
    }

    setState(() {
      _filteredSessions = filtered;
      // Clear single selection if selected session is filtered out
      if (_selectedSession != null &&
          !_filteredSessions.any((s) => s.name == _selectedSession!.name)) {
        _selectedSession = null;
      }
      // Remove multi-selected sessions that are filtered out
      _selectedSessionNames.removeWhere((name) =>
          !_filteredSessions.any((s) => s.name == name));
    });
  }

  /// Load list of sessions
  /// Only loads session metadata (not full session data) for performance
  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessions = await widget.sessionManager.listSessions();
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
      _applyFiltersAndSort();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load sessions: $e';
        _isLoading = false;
      });
      debugPrint('Error loading sessions: $e');
    }
  }

  /// Handle new session creation
  Future<void> _handleNewSession() async {
    // Prompt for session name
    final nameController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildNameDialog(
        title: 'New Session',
        hint: 'Enter session name',
        controller: nameController,
      ),
    );

    if (confirmed != true || nameController.text.trim().isEmpty) {
      return;
    }

    final sessionName = nameController.text.trim();

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Create new session with empty data
      await widget.sessionManager.saveSession(sessionName, <String, dynamic>{});

      // Reload sessions list
      await _loadSessions();
      _applyFiltersAndSort();

      // Open the new session
      await _openSession(sessionName);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create session: $e';
        _isLoading = false;
      });
      debugPrint('Error creating session: $e');
    }
  }

  /// Handle session loading
  Future<void> _handleLoadSession() async {
    if (_selectedSession == null) return;

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      await _openSession(_selectedSession!.name);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load session: $e';
        _isLoading = false;
      });
      debugPrint('Error loading session: $e');
    }
  }

  /// Open session in canvas
  /// Handles missing/corrupted sessions gracefully
  Future<void> _openSession(String sessionName) async {
    try {
      // Load session data
      final sessionData = await widget.sessionManager.loadSession(sessionName);

      // Handle missing/corrupted sessions gracefully
      if (sessionData.isEmpty) {
        throw Exception('Session data is empty or corrupted');
      }

      // Extract canvas data
      final canvasData = sessionData['data'] as Map<String, dynamic>? ?? <String, dynamic>{};

      // Call callback or navigate to canvas
      if (widget.onSessionSelected != null) {
        widget.onSessionSelected!(sessionName, canvasData);
      } else {
        // Default: Navigate to canvas with session data
        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => _CanvasWithSession(
              themeManager: widget.themeManager,
              sessionManager: widget.sessionManager,
              sessionName: sessionName,
              sessionData: canvasData,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to open session: $e';
        _isLoading = false;
      });
      debugPrint('Error opening session: $e');

      // Show error dialog
      if (mounted) {
        _showErrorDialog('Failed to open session', e.toString());
      }
    }
  }

  /// Handle session deletion (single)
  Future<void> _handleDeleteSession() async {
    if (_selectedSession == null) return;

    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildDeleteDialog(_selectedSession!.name),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final deletedName = _selectedSession!.name;
      await widget.sessionManager.deleteSession(deletedName);
      await _loadSessions(); // Reload session list
      setState(() {
        _selectedSession = null;
        _selectedSessionNames.remove(deletedName);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Session "$deletedName" deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to delete session', e.toString());
      }
      debugPrint('Error deleting session: $e');
    }
  }

  /// Handle multi-select session deletion
  Future<void> _handleDeleteSelectedSessions() async {
    if (_selectedSessionNames.isEmpty) return;

    final count = _selectedSessionNames.length;
    final sessionList = _selectedSessionNames.join(', ');
    
    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildMultiDeleteDialog(count, sessionList),
    );

    if (confirmed != true) {
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      // Delete all selected sessions
      int successCount = 0;
      for (final sessionName in _selectedSessionNames) {
        try {
          await widget.sessionManager.deleteSession(sessionName);
          successCount++;
        } catch (e) {
          debugPrint('Error deleting session "$sessionName": $e');
        }
      }

      await _loadSessions(); // Reload session list
      
      setState(() {
        _selectedSessionNames.clear();
        _isSelectionMode = false;
        _selectedSession = null;
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount session${successCount != 1 ? 's' : ''} deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        _showErrorDialog('Failed to delete sessions', e.toString());
      }
      debugPrint('Error deleting sessions: $e');
    }
  }

  /// Toggle selection mode
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        // Exit selection mode - clear selections
        _selectedSessionNames.clear();
        _selectedSession = null;
      }
    });
  }

  /// Toggle session selection in multi-select mode
  void _toggleSessionSelection(SessionInfo session) {
    if (!_isSelectionMode) return;
    
    setState(() {
      if (_selectedSessionNames.contains(session.name)) {
        _selectedSessionNames.remove(session.name);
      } else {
        _selectedSessionNames.add(session.name);
      }
    });
  }

  /// Handle session renaming
  Future<void> _handleRenameSession() async {
    if (_selectedSession == null) return;

    final nameController = TextEditingController(text: _selectedSession!.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildNameDialog(
        title: 'Rename Session',
        hint: 'Enter new session name',
        controller: nameController,
      ),
    );

    if (confirmed != true || nameController.text.trim().isEmpty) {
      return;
    }

    final newName = nameController.text.trim();

    if (newName == _selectedSession!.name) {
      return; // No change
    }

    try {
      // Load old session data
      final oldSessionData = await widget.sessionManager.loadSession(_selectedSession!.name);

      // Save with new name
      await widget.sessionManager.saveSession(newName, oldSessionData['data'] as Map<String, dynamic>);

      // Delete old session
      await widget.sessionManager.deleteSession(_selectedSession!.name);

      // Reload sessions list
      await _loadSessions();
      _applyFiltersAndSort();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Session renamed to "$newName"'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to rename session', e.toString());
      }
      debugPrint('Error renaming session: $e');
    }
  }

  /// Show error dialog
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => _buildErrorDialog(title, message),
    );
  }

  /// Build name input dialog
  Widget _buildNameDialog({
    required String title,
    required String hint,
    required TextEditingController controller,
  }) {
    return AnimatedBuilder(
      animation: widget.themeManager,
      builder: (context, _) {
        final theme = widget.themeManager.currentTheme;

        return AlertDialog(
          backgroundColor: theme.panelColor,
          title: Text(
            title,
            style: TextStyle(color: theme.textColor),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: theme.textColor.withValues(alpha: 0.5)),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: theme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: theme.accentColor),
              ),
            ),
            style: TextStyle(color: theme.textColor),
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
              child: Text(
                'OK',
                style: TextStyle(color: theme.accentColor),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build delete confirmation dialog
  Widget _buildDeleteDialog(String sessionName) {
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
            'Are you sure you want to delete "$sessionName"? This action cannot be undone.',
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

  /// Build multi-delete confirmation dialog
  Widget _buildMultiDeleteDialog(int count, String sessionList) {
    return AnimatedBuilder(
      animation: widget.themeManager,
      builder: (context, _) {
        final theme = widget.themeManager.currentTheme;

        return AlertDialog(
          backgroundColor: theme.panelColor,
          title: Text(
            'Delete $count Session${count != 1 ? 's' : ''}',
            style: TextStyle(color: theme.textColor),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete $count selected session${count != 1 ? 's' : ''}? This action cannot be undone.',
                style: TextStyle(color: theme.textColor.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.backgroundColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  sessionList.length > 100
                      ? '${sessionList.substring(0, 100)}...'
                      : sessionList,
                  style: TextStyle(
                    color: theme.textColor.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
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
              child: Text('Delete $count'),
            ),
          ],
        );
      },
    );
  }

  /// Build error dialog
  Widget _buildErrorDialog(String title, String message) {
    return AnimatedBuilder(
      animation: widget.themeManager,
      builder: (context, _) {
        final theme = widget.themeManager.currentTheme;

        return AlertDialog(
          backgroundColor: theme.panelColor,
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: theme.textColor),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(color: theme.textColor.withValues(alpha: 0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: TextStyle(color: theme.accentColor),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return AnimatedBuilder(
      animation: widget.themeManager,
      builder: (context, _) {
        final theme = widget.themeManager.currentTheme;

        return Scaffold(
          backgroundColor: theme.backgroundColor,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.backgroundColor,
                  theme.backgroundColor.withValues(alpha: 0.95),
                  theme.panelColor.withValues(alpha: 0.3),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Hero Header with Search and Sort
                          _buildHeroHeaderWithControls(context, theme),
                          const SizedBox(height: 48),
                          
                          // Error message (if any)
                          if (_errorMessage != null)
                            _buildErrorMessage(theme),
                          
                          if (_errorMessage != null) const SizedBox(height: 24),
                          
                          // Frosted Glass Session Container
                          _buildSessionContainer(
                            context,
                            theme,
                            screenSize,
                          ),
                          
                          const SizedBox(height: 40),
                          
                          // Floating Pill Action Buttons
                          _buildFloatingActions(theme),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build hero header with search and sort controls
  Widget _buildHeroHeaderWithControls(BuildContext context, CanvasTheme theme) {
    final isSmallScreen = MediaQuery.of(context).size.width < 800;
    
    return Column(
      children: [
        // Header row with title and controls
        isSmallScreen
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BLUEPRINT',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                          color: theme.textColor,
                          height: 1.2,
                          shadows: [
                            Shadow(
                              color: theme.accentColor.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Session Manager',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2,
                          color: theme.textColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Select button, Search and Sort (stacked on small screens)
                  Row(
                    children: [
                      _buildSelectButton(theme),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSearchBox(theme)),
                      const SizedBox(width: 12),
                      _buildSortDropdown(theme),
                    ],
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BLUEPRINT',
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                            color: theme.textColor,
                            height: 1.2,
                            shadows: [
                              Shadow(
                                color: theme.accentColor.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Session Manager',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 2,
                            color: theme.textColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Right: Search, Sort, and Select button
                  Row(
                    children: [
                      // Select button
                      _buildSelectButton(theme),
                      const SizedBox(width: 12),
                      // Search box
                      _buildSearchBox(theme),
                      const SizedBox(width: 12),
                      // Sort dropdown
                      _buildSortDropdown(theme),
                    ],
                  ),
                ],
              ),
      ],
    );
  }

  /// Build search box
  Widget _buildSearchBox(CanvasTheme theme) {
    return Container(
      width: 240,
      height: 40,
      decoration: BoxDecoration(
        color: theme.panelColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.borderColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(
          color: theme.textColor,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Search sessions...',
          hintStyle: TextStyle(
            color: theme.textColor.withValues(alpha: 0.5),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: theme.textColor.withValues(alpha: 0.6),
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: theme.textColor.withValues(alpha: 0.6),
                    size: 20,
                  ),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
    );
  }

  /// Build select button
  Widget _buildSelectButton(CanvasTheme theme) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: _isSelectionMode
            ? theme.accentColor.withValues(alpha: 0.2)
            : theme.panelColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isSelectionMode
              ? theme.accentColor.withValues(alpha: 0.5)
              : theme.borderColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleSelectionMode,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isSelectionMode ? Icons.check_circle : Icons.select_all,
                  size: 18,
                  color: _isSelectionMode
                      ? theme.accentColor
                      : theme.textColor.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Text(
                  _isSelectionMode ? 'Cancel' : 'Select',
                  style: TextStyle(
                    color: _isSelectionMode
                        ? theme.accentColor
                        : theme.textColor.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build sort dropdown
  Widget _buildSortDropdown(CanvasTheme theme) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.panelColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.borderColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<SortMode>(
          value: _sortMode,
          icon: Icon(
            Icons.arrow_drop_down_rounded,
            color: theme.textColor.withValues(alpha: 0.6),
          ),
          style: TextStyle(
            color: theme.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          dropdownColor: theme.panelColor,
          borderRadius: BorderRadius.circular(12),
          items: [
            DropdownMenuItem(
              value: SortMode.recentFirst,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time, size: 18, color: theme.accentColor),
                  const SizedBox(width: 8),
                  const Text('Recent first'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: SortMode.aToZ,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort_by_alpha, size: 18, color: theme.accentColor),
                  const SizedBox(width: 8),
                  const Text('A → Z'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: SortMode.zToA,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort_by_alpha, size: 18, color: theme.accentColor),
                  const SizedBox(width: 8),
                  const Text('Z → A'),
                ],
              ),
            ),
          ],
          onChanged: (SortMode? newValue) {
            if (newValue != null) {
              setState(() {
                _sortMode = newValue;
              });
              _applyFiltersAndSort();
            }
          },
        ),
      ),
    );
  }

  /// Build error message banner
  Widget _buildErrorMessage(CanvasTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.red, size: 18),
            onPressed: () {
              setState(() => _errorMessage = null);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  /// Build frosted glass session container
  Widget _buildSessionContainer(
    BuildContext context,
    CanvasTheme theme,
    Size screenSize,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 900),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.accentColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.accentColor.withValues(alpha: 0.1),
            blurRadius: 40,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: -5,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.panelColor.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(24),
            ),
            child: _isLoading
                ? SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: theme.accentColor,
                        strokeWidth: 3,
                      ),
                    ),
                  )
                : SessionCarouselView(
                    sessions: _filteredSessions,
                    selectedSession: _selectedSession,
                    isSelectionMode: _isSelectionMode,
                    selectedSessionNames: _selectedSessionNames,
                    themeManager: widget.themeManager,
                    onSessionSelected: (session) {
                      if (_isSelectionMode) {
                        _toggleSessionSelection(session);
                      } else {
                        setState(() => _selectedSession = session);
                      }
                    },
                    onSessionDoubleTapped: (session) {
                      if (!_isSelectionMode) {
                        _selectedSession = session;
                        _handleLoadSession();
                      }
                    },
                    onSessionRename: (session) {
                      setState(() => _selectedSession = session);
                      _handleRenameSession();
                    },
                    onSessionDelete: (session) {
                      setState(() => _selectedSession = session);
                      _handleDeleteSession();
                    },
                  ),
          ),
        ),
      ),
    );
  }

  /// Build floating pill action buttons
  Widget _buildFloatingActions(CanvasTheme theme) {
    if (_isSelectionMode) {
      // Selection mode buttons
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.center,
        children: [
          _buildPillButton(
            theme: theme,
            icon: Icons.add_rounded,
            label: 'New Session',
            onPressed: _handleNewSession,
            isPrimary: false,
          ),
          _buildPillButton(
            theme: theme,
            icon: Icons.delete_outline_rounded,
            label: 'Delete Selected (${_selectedSessionNames.length})',
            onPressed: _selectedSessionNames.isNotEmpty
                ? _handleDeleteSelectedSessions
                : null,
            isPrimary: false,
            isDestructive: true,
          ),
          _buildPillButton(
            theme: theme,
            icon: Icons.close_rounded,
            label: 'Cancel Selection',
            onPressed: _toggleSelectionMode,
            isPrimary: false,
          ),
        ],
      );
    } else {
      // Normal mode buttons
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.center,
        children: [
          _buildPillButton(
            theme: theme,
            icon: Icons.add_rounded,
            label: 'New Session',
            onPressed: _handleNewSession,
            isPrimary: true,
          ),
          _buildPillButton(
            theme: theme,
            icon: Icons.folder_open_rounded,
            label: 'Load Session',
            onPressed: _selectedSession != null ? _handleLoadSession : null,
            isPrimary: false,
          ),
          _buildPillButton(
            theme: theme,
            icon: Icons.delete_outline_rounded,
            label: 'Delete Session',
            onPressed: _selectedSession != null ? _handleDeleteSession : null,
            isPrimary: false,
            isDestructive: true,
          ),
        ],
      );
    }
  }

  /// Build individual pill button
  Widget _buildPillButton({
    required CanvasTheme theme,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool isPrimary,
    bool isDestructive = false,
  }) {
    final accentColor = theme.accentColor;
    final isEnabled = onPressed != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: isPrimary && isEnabled
                  ? LinearGradient(
                      colors: [
                        accentColor,
                        accentColor.withValues(alpha: 0.8),
                      ],
                    )
                  : null,
              color: isPrimary
                  ? null
                  : theme.panelColor.withValues(alpha: 0.6),
              border: Border.all(
                color: isPrimary
                    ? accentColor.withValues(alpha: 0.5)
                    : isDestructive
                        ? Colors.red.withValues(alpha: 0.3)
                        : theme.borderColor.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: isPrimary && isEnabled
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isEnabled
                      ? (isPrimary
                          ? Colors.white
                          : isDestructive
                              ? Colors.red.withValues(alpha: 0.9)
                              : theme.textColor)
                      : theme.textColor.withValues(alpha: 0.3),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: isEnabled
                        ? (isPrimary
                            ? Colors.white
                            : isDestructive
                                ? Colors.red.withValues(alpha: 0.9)
                                : theme.textColor)
                        : theme.textColor.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// CanvasWithSession: Canvas wrapper that loads session data
/// 
/// This is a stub for integrating session data into the canvas.
/// Replace the canvas loading logic with your actual canvas implementation.
class _CanvasWithSession extends StatefulWidget {
  final ThemeManager themeManager;
  final BlueprintSessionManager sessionManager;
  final String sessionName;
  final Map<String, dynamic> sessionData;

  const _CanvasWithSession({
    required this.themeManager,
    required this.sessionManager,
    required this.sessionName,
    required this.sessionData,
  });

  @override
  State<_CanvasWithSession> createState() => _CanvasWithSessionState();
}

class _CanvasWithSessionState extends State<_CanvasWithSession> {
  late final ShapeManager _shapeManager;
  late final MediaManager _mediaManager;
  late final ViewportController _viewportController;
  SimpleCanvasLayout? _canvasLayout;

  @override
  void initState() {
    super.initState();
    _shapeManager = ShapeManager();
    _mediaManager = MediaManager();
    _viewportController = ViewportController();
    _loadSessionDataIntoCanvas();
  }

  @override
  void dispose() {
    _shapeManager.dispose();
    _mediaManager.dispose();
    _viewportController.dispose();
    super.dispose();
  }

  /// Load session data into canvas
  /// This is a stub - replace with your actual canvas loading logic
  void _loadSessionDataIntoCanvas() {
    try {
      // Extract shapes from session data
      final shapesData = widget.sessionData['shapes'] as List? ?? [];
      
      // Track maximum z-index to update global counter after loading
      int maxZIndex = -1;
      
      // Load shapes into ShapeManager
      for (final shapeData in shapesData) {
        try {
          final shape = _shapeFromJson(shapeData as Map<String, dynamic>);
          if (shape != null) {
            _shapeManager.addShape(shape);
            if (shape.zIndex > maxZIndex) {
              maxZIndex = shape.zIndex;
            }
          }
        } catch (e) {
          debugPrint('Warning: Could not load shape: $e');
        }
      }

      // Extract media from session data
      final mediaData = widget.sessionData['media'] as List? ?? [];
      
      // Load media into MediaManager
      for (final mediaItemData in mediaData) {
        try {
          final media = _mediaFromJson(mediaItemData as Map<String, dynamic>);
          if (media != null) {
            _mediaManager.addMedia(media);
            if (media.zIndex > maxZIndex) {
              maxZIndex = media.zIndex;
            }
          }
        } catch (e) {
          debugPrint('Warning: Could not load media: $e');
        }
      }

      // Update global z-index counter to be higher than all loaded objects
      // This ensures new objects get correct z-index values after loading
      if (maxZIndex >= 0) {
        CanvasShape.globalZIndexCounter = maxZIndex + 1;
      }

      // Extract viewport state (optional)
      final viewportData = widget.sessionData['viewport'] as Map<String, dynamic>?;
      if (viewportData != null) {
        try {
          final scale = viewportData['scale'] as double? ?? 1.0;
          final translationData = viewportData['translation'] as Map<String, dynamic>?;
          if (translationData != null) {
            final dx = translationData['dx'] as double? ?? 0.0;
            final dy = translationData['dy'] as double? ?? 0.0;
            _viewportController.setScale(scale);
            _viewportController.setTranslation(Offset(dx, dy));
          }
        } catch (e) {
          debugPrint('Warning: Could not load viewport state: $e');
        }
      }

      debugPrint('✓ Session data loaded into canvas: ${shapesData.length} shapes');
    } catch (e) {
      debugPrint('Error loading session data into canvas: $e');
    }
  }

  /// Convert JSON to CanvasShape
  CanvasShape? _shapeFromJson(Map<String, dynamic> json) {
    try {
      // Parse shape type
      final typeString = json['type'] as String? ?? 'rectangle';
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

      // Parse position
      final positionData = json['position'] as Map<String, dynamic>? ?? {};
      final position = Offset(
        (positionData['dx'] as num?)?.toDouble() ?? 0.0,
        (positionData['dy'] as num?)?.toDouble() ?? 0.0,
      );

      // Parse size
      final sizeData = json['size'] as Map<String, dynamic>? ?? {};
      final size = Size(
        (sizeData['width'] as num?)?.toDouble() ?? 120.0,
        (sizeData['height'] as num?)?.toDouble() ?? 120.0,
      );

      // Parse color
      final colorValue = json['color'] as int? ?? 0xFF2196F3;
      final color = Color(colorValue);

      // Parse text
      final text = json['text'] as String? ?? '';

      // Parse notes
      final notes = json['notes'] as String? ?? '';

      // Parse corner radius
      final cornerRadius = (json['cornerRadius'] as num?)?.toDouble() ?? 8.0;

      // Parse showBorder
      final showBorder = json['showBorder'] as bool? ?? true;

      // Parse zIndex (for backward compatibility, assign new z-index if not present)
      final zIndex = json['zIndex'] as int?;

      return CanvasShape(
        id: json['id'] as String? ?? _generateShapeId(),
        position: position,
        size: size,
        type: shapeType,
        color: color,
        text: text,
        notes: notes,
        isSelected: false,
        cornerRadius: cornerRadius,
        showBorder: showBorder,
        zIndex: zIndex, // Will use auto-generated z-index if null
      );
    } catch (e) {
      debugPrint('Error parsing shape: $e');
      return null;
    }
  }

  /// Generate a unique shape ID
  String _generateShapeId() {
    return 'shape_${DateTime.now().microsecondsSinceEpoch}';
  }

  /// Convert CanvasMedia to JSON
  Map<String, dynamic> _mediaToJson(CanvasMedia media) {
    final json = <String, dynamic>{
      'id': media.id,
      'position': {'dx': media.position.dx, 'dy': media.position.dy},
      'size': {'width': media.size.width, 'height': media.size.height},
      'type': media.type.toString(),
      'notes': media.notes,
      'showBorder': media.showBorder,
      'zIndex': media.zIndex,
    };

    // Add intrinsic size if available (for accurate border rendering)
    if (media.intrinsicSize != null) {
      json['intrinsicSize'] = {
        'width': media.intrinsicSize!.width,
        'height': media.intrinsicSize!.height,
      };
    }
    
    // Add type-specific data
    if (media.type == MediaType.emoji) {
      json['emoji'] = media.emoji;
    } else {
      // For images/SVG, store as base64
      if (media.imageData != null) {
        json['imageData'] = base64Encode(media.imageData!);
      }
      json['filePath'] = media.filePath;
    }

    return json;
  }

  /// Convert JSON to CanvasMedia
  CanvasMedia? _mediaFromJson(Map<String, dynamic> json) {
    try {
      // Parse position
      final positionData = json['position'] as Map<String, dynamic>? ?? {};
      final position = Offset(
        (positionData['dx'] as num?)?.toDouble() ?? 0.0,
        (positionData['dy'] as num?)?.toDouble() ?? 0.0,
      );

      // Parse size
      final sizeData = json['size'] as Map<String, dynamic>? ?? {};
      final size = Size(
        (sizeData['width'] as num?)?.toDouble() ?? 64.0,
        (sizeData['height'] as num?)?.toDouble() ?? 64.0,
      );

      // Parse type
      final typeString = json['type'] as String? ?? 'emoji';
      MediaType mediaType = MediaType.emoji;
      try {
        final typeName = typeString.split('.').last;
        mediaType = MediaType.values.firstWhere(
          (e) => e.toString().split('.').last == typeName,
          orElse: () => MediaType.emoji,
        );
      } catch (e) {
        debugPrint('Error parsing media type: $e');
      }

      // Parse notes
      final notes = json['notes'] as String? ?? '';

      // Parse showBorder
      final showBorder = json['showBorder'] as bool? ?? true;

      // Parse zIndex (for backward compatibility, assign new z-index if not present)
      final zIndex = json['zIndex'] as int?;
      
      // Parse intrinsic size if available (for accurate border rendering)
      Size? intrinsicSize;
      final intrinsicSizeData = json['intrinsicSize'] as Map<String, dynamic>?;
      if (intrinsicSizeData != null) {
        intrinsicSize = Size(
          (intrinsicSizeData['width'] as num?)?.toDouble() ?? size.width,
          (intrinsicSizeData['height'] as num?)?.toDouble() ?? size.height,
        );
      } else {
        // For backward compatibility, use size as intrinsic size for images
        if (mediaType != MediaType.emoji) {
          intrinsicSize = size;
        }
      }

      // Create media based on type
      if (mediaType == MediaType.emoji) {
        final emoji = json['emoji'] as String? ?? '😀';
        return CanvasMedia(
          id: json['id'] as String? ?? _generateMediaId(),
          position: position,
          size: size,
          type: mediaType,
          emoji: emoji,
          notes: notes,
          showBorder: showBorder,
          zIndex: zIndex, // Will use auto-generated z-index if null
        );
      } else {
        // Image or SVG
        Uint8List? imageData;
        final imageDataBase64 = json['imageData'] as String?;
        if (imageDataBase64 != null) {
          try {
            imageData = base64Decode(imageDataBase64);
          } catch (e) {
            debugPrint('Error decoding image data: $e');
            return null;
          }
        }

        if (imageData == null) {
          debugPrint('Warning: Media has no image data');
          return null;
        }

        final filePath = json['filePath'] as String?;

        if (mediaType == MediaType.svg) {
          return CanvasMedia(
            id: json['id'] as String? ?? _generateMediaId(),
            position: position,
            size: size,
            type: mediaType,
            imageData: imageData,
            filePath: filePath,
            notes: notes,
            showBorder: showBorder,
            zIndex: zIndex, // Will use auto-generated z-index if null
            intrinsicSize: intrinsicSize, // Pass intrinsic size
          );
        } else {
          return CanvasMedia(
            id: json['id'] as String? ?? _generateMediaId(),
            position: position,
            size: size,
            type: mediaType,
            imageData: imageData,
            filePath: filePath,
            notes: notes,
            showBorder: showBorder,
            zIndex: zIndex, // Will use auto-generated z-index if null
            intrinsicSize: intrinsicSize, // Pass intrinsic size
          );
        }
      }
    } catch (e) {
      debugPrint('Error parsing media: $e');
      return null;
    }
  }

  /// Generate a unique media ID
  String _generateMediaId() {
    return 'media_${DateTime.now().microsecondsSinceEpoch}';
  }

  /// Save canvas data to session
  /// This is a stub - replace with your actual canvas saving logic
  Future<void> _saveSession() async {
    try {
      // Extract shapes from ShapeManager
      final shapesJson = _shapeManager.shapes.map((shape) => _shapeToJson(shape)).toList();

      // Extract media from MediaManager
      final mediaJson = _mediaManager.mediaItems.map((media) => _mediaToJson(media)).toList();

      // Extract viewport state
      final viewportJson = <String, dynamic>{
        'scale': _viewportController.scale,
        'translation': {
          'dx': _viewportController.translation.dx,
          'dy': _viewportController.translation.dy,
        },
      };

      // Construct canvas data
      final canvasData = <String, dynamic>{
        'shapes': shapesJson,
        'media': mediaJson,
        'viewport': viewportJson,
      };

      // Save session
      await widget.sessionManager.saveSession(widget.sessionName, canvasData);

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

  /// Show confirmation dialog and save session, then exit
  Future<void> _saveAndExit() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildSaveAndExitDialog(),
    );

    if (confirmed != true) {
      return; // User cancelled
    }

    try {
      // Save session
      await _saveSession();
      
      // Wait a moment for the save to complete and show success message
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Navigate back to session home
      // Since we used pushReplacement, we need to navigate to a new instance
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => BlueprintSessionHome(
              themeManager: widget.themeManager,
              sessionManager: widget.sessionManager,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving and exiting: $e');
      // Error message already shown by _saveSession
    }
  }

  /// Build save and exit confirmation dialog
  Widget _buildSaveAndExitDialog() {
    return AnimatedBuilder(
      animation: widget.themeManager,
      builder: (context, _) {
        final theme = widget.themeManager.currentTheme;

        return AlertDialog(
          backgroundColor: theme.panelColor,
          title: Text(
            'Save and Exit',
            style: TextStyle(color: theme.textColor),
          ),
          content: Text(
            'Do you want to save your session and return to the session manager?',
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
                foregroundColor: theme.accentColor,
              ),
              child: const Text('Save & Exit'),
            ),
          ],
        );
      },
    );
  }

  /// Convert CanvasShape to JSON
  Map<String, dynamic> _shapeToJson(CanvasShape shape) {
    return {
      'id': shape.id,
      'position': {'dx': shape.position.dx, 'dy': shape.position.dy},
      'size': {'width': shape.size.width, 'height': shape.size.height},
      'type': shape.type.toString(),
      // ignore: deprecated_member_use
      'color': shape.color.value,
      'text': shape.text,
      'notes': shape.notes,
      'cornerRadius': shape.cornerRadius,
      'showBorder': shape.showBorder,
      'zIndex': shape.zIndex,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Canvas with integrated Save & Exit in toolbar
    _canvasLayout = SimpleCanvasLayout(
      themeManager: widget.themeManager,
      shapeManager: _shapeManager,
      mediaManager: _mediaManager,
      viewportController: _viewportController,
      onSaveAndExit: _saveAndExit, // Pass save & exit callback to canvas
    );
    return _canvasLayout!;
  }
}
