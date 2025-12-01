import 'package:flutter/material.dart';
import '../models/session_info.dart';
import '../theme_manager.dart';
import 'session_grid_card.dart';

/// SessionGridView: Grid view of all sessions with premium card design
/// 
/// Displays sessions in a responsive grid (2-3 columns).
/// Shows empty state when no sessions exist.
/// Handles session selection and actions.
class SessionGridView extends StatelessWidget {
  final List<SessionInfo> sessions;
  final SessionInfo? selectedSession;
  final ThemeManager themeManager;
  final ValueChanged<SessionInfo> onSessionSelected;
  final ValueChanged<SessionInfo> onSessionDoubleTapped;
  final ValueChanged<SessionInfo>? onSessionRename;
  final ValueChanged<SessionInfo>? onSessionDelete;

  const SessionGridView({
    super.key,
    required this.sessions,
    required this.selectedSession,
    required this.themeManager,
    required this.onSessionSelected,
    required this.onSessionDoubleTapped,
    this.onSessionRename,
    this.onSessionDelete,
  });

  /// Calculate number of columns based on screen width
  int _calculateCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 900) {
      return 3;
    } else if (width > 600) {
      return 2;
    } else {
      return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeManager,
      builder: (context, _) {
        final theme = themeManager.currentTheme;

        if (sessions.isEmpty) {
          return _buildEmptyState(theme);
        }

        final crossAxisCount = _calculateCrossAxisCount(context);
        final aspectRatio = crossAxisCount == 1 ? 3.0 : 1.3;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: aspectRatio,
          ),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            final isSelected = selectedSession?.name == session.name;

            return SessionGridCard(
              session: session,
              isSelected: isSelected,
              themeManager: themeManager,
              onTap: () => onSessionSelected(session),
              onDoubleTap: () => onSessionDoubleTapped(session),
              onRename: onSessionRename != null
                  ? () => onSessionRename!(session)
                  : null,
              onDelete: onSessionDelete != null
                  ? () => onSessionDelete!(session)
                  : null,
            );
          },
        );
      },
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

