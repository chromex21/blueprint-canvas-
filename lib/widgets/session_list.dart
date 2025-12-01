import 'package:flutter/material.dart';
import '../models/session.dart';
import '../theme_manager.dart';
import 'session_item.dart';

/// SessionList: Grid/List display of sessions
/// 
/// Features:
/// - Responsive grid layout (adapts to screen size)
/// - Smooth scrolling
/// - Selection handling
/// - Empty state when no sessions
class SessionList extends StatelessWidget {
  final List<Session> sessions;
  final Session? selectedSession;
  final ThemeManager themeManager;
  final ValueChanged<Session> onSessionSelected;
  final ValueChanged<Session> onSessionOpened;

  const SessionList({
    super.key,
    required this.sessions,
    required this.selectedSession,
    required this.themeManager,
    required this.onSessionSelected,
    required this.onSessionOpened,
  });

  /// Calculate cross-axis count based on screen width
  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4;
    if (width > 800) return 3;
    if (width > 600) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeManager,
      builder: (context, _) {
        final theme = themeManager.currentTheme;

        if (sessions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_open_outlined,
                  size: 64,
                  color: theme.textColor.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No sessions yet',
                  style: TextStyle(
                    color: theme.textColor.withValues(alpha: 0.6),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a new session to get started',
                  style: TextStyle(
                    color: theme.textColor.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        final crossAxisCount = _getCrossAxisCount(context);
        final isGrid = crossAxisCount > 1;

        if (isGrid) {
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return SessionItem(
                session: session,
                isSelected: selectedSession?.id == session.id,
                themeManager: themeManager,
                onTap: () => onSessionSelected(session),
                onDoubleTap: () => onSessionOpened(session),
              );
            },
          );
        } else {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SessionItem(
                  session: session,
                  isSelected: selectedSession?.id == session.id,
                  themeManager: themeManager,
                  onTap: () => onSessionSelected(session),
                  onDoubleTap: () => onSessionOpened(session),
                ),
              );
            },
          );
        }
      },
    );
  }
}

