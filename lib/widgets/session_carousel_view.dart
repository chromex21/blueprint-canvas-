import 'package:flutter/material.dart';
import '../models/session_info.dart';
import '../theme_manager.dart';
import 'session_grid_card.dart';

/// SessionCarouselView: Horizontal paged carousel with 3 sessions per page
/// 
/// Features:
/// - Shows 3 session cards per page
/// - Navigation arrows for multiple pages
/// - Smooth slide transitions
/// - Centered layout
/// - Multi-select support
class SessionCarouselView extends StatefulWidget {
  final List<SessionInfo> sessions;
  final SessionInfo? selectedSession;
  final bool isSelectionMode;
  final Set<String> selectedSessionNames;
  final ThemeManager themeManager;
  final ValueChanged<SessionInfo> onSessionSelected;
  final ValueChanged<SessionInfo> onSessionDoubleTapped;
  final ValueChanged<SessionInfo>? onSessionRename;
  final ValueChanged<SessionInfo>? onSessionDelete;

  const SessionCarouselView({
    super.key,
    required this.sessions,
    required this.selectedSession,
    required this.isSelectionMode,
    required this.selectedSessionNames,
    required this.themeManager,
    required this.onSessionSelected,
    required this.onSessionDoubleTapped,
    this.onSessionRename,
    this.onSessionDelete,
  });

  @override
  State<SessionCarouselView> createState() => _SessionCarouselViewState();
}

class _SessionCarouselViewState extends State<SessionCarouselView> {
  late PageController _pageController;
  int _currentPage = 0;
  static const int _sessionsPerPage = 3;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(SessionCarouselView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset to first page if sessions changed significantly
    if (widget.sessions.length != oldWidget.sessions.length ||
        (widget.sessions.isNotEmpty && oldWidget.sessions.isNotEmpty &&
            widget.sessions[0].name != oldWidget.sessions[0].name)) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _currentPage = 0;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int get _totalPages => (widget.sessions.length / _sessionsPerPage).ceil();
  bool get _hasMultiplePages => widget.sessions.length > _sessionsPerPage;
  bool get _canGoPrevious => _currentPage > 0;
  bool get _canGoNext => _currentPage < _totalPages - 1;

  List<SessionInfo> _getSessionsForPage(int page) {
    final start = page * _sessionsPerPage;
    final end = (start + _sessionsPerPage).clamp(0, widget.sessions.length);
    return widget.sessions.sublist(start, end);
  }

  void _goToPreviousPage() {
    if (_canGoPrevious) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNextPage() {
    if (_canGoNext) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.themeManager,
      builder: (context, _) {
        final theme = widget.themeManager.currentTheme;

        if (widget.sessions.isEmpty) {
          return _buildEmptyState(theme);
        }

        return Column(
          children: [
            // Carousel with navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left arrow
                if (_hasMultiplePages)
                  _buildNavigationArrow(
                    theme,
                    icon: Icons.chevron_left_rounded,
                    onPressed: _canGoPrevious ? _goToPreviousPage : null,
                    isLeft: true,
                  ),
                
                // Page view container
                Flexible(
                  child: SizedBox(
                    width: double.infinity,
                    height: 280,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemCount: _totalPages,
                      itemBuilder: (context, pageIndex) {
                        final pageSessions = _getSessionsForPage(pageIndex);
                        return _buildPage(theme, pageSessions);
                      },
                    ),
                  ),
                ),

                // Right arrow
                if (_hasMultiplePages)
                  _buildNavigationArrow(
                    theme,
                    icon: Icons.chevron_right_rounded,
                    onPressed: _canGoNext ? _goToNextPage : null,
                    isLeft: false,
                  ),
              ],
            ),

            // Page indicators
            if (_hasMultiplePages && _totalPages > 1) ...[
              const SizedBox(height: 16),
              _buildPageIndicators(theme),
            ],
          ],
        );
      },
    );
  }

  /// Build a single page with up to 3 session cards
  Widget _buildPage(CanvasTheme theme, List<SessionInfo> pageSessions) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < _sessionsPerPage; i++)
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: i < pageSessions.length
                        ? SessionGridCard(
                            session: pageSessions[i],
                            isSelected: widget.isSelectionMode
                                ? widget.selectedSessionNames.contains(pageSessions[i].name)
                                : widget.selectedSession?.name == pageSessions[i].name,
                            isSelectionMode: widget.isSelectionMode,
                            themeManager: widget.themeManager,
                            onTap: () => widget.onSessionSelected(pageSessions[i]),
                            onDoubleTap: () => widget.onSessionDoubleTapped(pageSessions[i]),
                            onRename: widget.onSessionRename != null
                                ? () => widget.onSessionRename!(pageSessions[i])
                                : null,
                            onDelete: widget.onSessionDelete != null
                                ? () => widget.onSessionDelete!(pageSessions[i])
                                : null,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build navigation arrow
  Widget _buildNavigationArrow(
    CanvasTheme theme, {
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isLeft,
  }) {
    return Container(
      width: 48,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.panelColor.withValues(alpha: 0.7),
        shape: BoxShape.circle,
        border: Border.all(
          color: onPressed != null
              ? theme.accentColor.withValues(alpha: 0.3)
              : theme.borderColor.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: theme.accentColor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Icon(
            icon,
            color: onPressed != null
                ? theme.accentColor
                : theme.textColor.withValues(alpha: 0.3),
            size: 28,
          ),
        ),
      ),
    );
  }

  /// Build page indicators
  Widget _buildPageIndicators(CanvasTheme theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _totalPages,
        (index) => Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index == _currentPage
                ? theme.accentColor
                : theme.accentColor.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState(CanvasTheme theme) {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_outlined,
                size: 48,
                color: theme.accentColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No sessions yet',
              style: TextStyle(
                color: theme.textColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new session to get started',
              style: TextStyle(
                color: theme.textColor.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

