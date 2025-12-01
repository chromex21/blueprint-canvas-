import 'package:flutter/material.dart';
import '../models/session_info.dart';
import '../theme_manager.dart';

/// SessionListItem: Individual session item in the session list
/// 
/// Displays session name and last modified timestamp.
/// Supports selection, double-tap to load, and action buttons.
class SessionListItem extends StatelessWidget {
  final SessionInfo session;
  final bool isSelected;
  final ThemeManager themeManager;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const SessionListItem({
    super.key,
    required this.session,
    required this.isSelected,
    required this.themeManager,
    required this.onTap,
    required this.onDoubleTap,
    this.onRename,
    this.onDelete,
  });

  /// Format timestamp for display
  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeManager,
      builder: (context, _) {
        final theme = themeManager.currentTheme;

        return GestureDetector(
          onDoubleTap: onDoubleTap,
          child: Card(
            color: isSelected
                ? theme.accentColor.withValues(alpha: 0.15)
                : theme.panelColor,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                Icons.assignment_outlined,
                color: isSelected
                    ? theme.accentColor
                    : theme.textColor.withValues(alpha: 0.6),
              ),
              title: Text(
                session.name,
                style: TextStyle(
                  color: theme.textColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                _formatTimestamp(session.lastModified),
                style: TextStyle(
                  color: theme.textColor.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onRename != null)
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        color: theme.textColor.withValues(alpha: 0.6),
                      ),
                      onPressed: onRename,
                      tooltip: 'Rename',
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: Colors.red.withValues(alpha: 0.6),
                      ),
                      onPressed: onDelete,
                      tooltip: 'Delete',
                    ),
                ],
              ),
              selected: isSelected,
              onTap: onTap,
            ),
          ),
        );
      },
    );
  }
}



