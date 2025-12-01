import 'package:flutter/material.dart';
import '../models/session_info.dart';
import '../theme_manager.dart';
import 'session_list_item.dart';

/// SessionListView: List view of all sessions
/// 
/// Displays sessions in a scrollable list.
/// Shows empty state when no sessions exist.
/// Handles session selection and actions.
class SessionListView extends StatelessWidget {
  final List<SessionInfo> sessions;
  final SessionInfo? selectedSession;
  final ThemeManager themeManager;
  final ValueChanged<SessionInfo> onSessionSelected;
  final ValueChanged<SessionInfo> onSessionDoubleTapped;
  final ValueChanged<SessionInfo>? onSessionRename;
  final ValueChanged<SessionInfo>? onSessionDelete;

  const SessionListView({
    super.key,
    required this.sessions,
    required this.selectedSession,
    required this.themeManager,
    required this.onSessionSelected,
    required this.onSessionDoubleTapped,
    this.onSessionRename,
    this.onSessionDelete,
  });

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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            final isSelected = selectedSession?.name == session.name;

            return SessionListItem(
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
}



