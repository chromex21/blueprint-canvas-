import 'package:flutter/material.dart';
import '../theme_manager.dart';

/// SessionActionButtons: Action buttons for session management
/// 
/// Provides buttons for:
/// - New Session
/// - Load Session (enabled when session selected)
/// - Delete Session (enabled when session selected)
/// 
/// Responsive layout (row on desktop, column on mobile)
class SessionActionButtons extends StatelessWidget {
  final ThemeManager themeManager;
  final bool hasSelection;
  final VoidCallback onNewSession;
  final VoidCallback onLoadSession;
  final VoidCallback onDeleteSession;

  const SessionActionButtons({
    super.key,
    required this.themeManager,
    required this.hasSelection,
    required this.onNewSession,
    required this.onLoadSession,
    required this.onDeleteSession,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeManager,
      builder: (context, _) {
        final theme = themeManager.currentTheme;
        final isMobile = MediaQuery.of(context).size.width < 600;

        if (isMobile) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildButton(
                context,
                theme,
                icon: Icons.add,
                label: 'New Session',
                onPressed: onNewSession,
                isPrimary: true,
              ),
              const SizedBox(height: 8),
              _buildButton(
                context,
                theme,
                icon: Icons.folder_open,
                label: 'Load Session',
                onPressed: hasSelection ? onLoadSession : null,
                isPrimary: false,
              ),
              const SizedBox(height: 8),
              _buildButton(
                context,
                theme,
                icon: Icons.delete_outline,
                label: 'Delete Session',
                onPressed: hasSelection ? onDeleteSession : null,
                isPrimary: false,
                isDestructive: true,
              ),
            ],
          );
        } else {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildButton(
                context,
                theme,
                icon: Icons.add,
                label: 'New Session',
                onPressed: onNewSession,
                isPrimary: true,
              ),
              const SizedBox(width: 12),
              _buildButton(
                context,
                theme,
                icon: Icons.folder_open,
                label: 'Load Session',
                onPressed: hasSelection ? onLoadSession : null,
                isPrimary: false,
              ),
              const SizedBox(width: 12),
              _buildButton(
                context,
                theme,
                icon: Icons.delete_outline,
                label: 'Delete Session',
                onPressed: hasSelection ? onDeleteSession : null,
                isPrimary: false,
                isDestructive: true,
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildButton(
    BuildContext context,
    CanvasTheme theme, {
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool isPrimary,
    bool isDestructive = false,
  }) {
    final backgroundColor = isPrimary
        ? theme.accentColor
        : isDestructive
            ? Colors.red.withValues(alpha: 0.1)
            : theme.panelColor;

    final foregroundColor = isPrimary
        ? Colors.white
        : isDestructive
            ? Colors.red
            : theme.accentColor;

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isDestructive
                ? Colors.red.withValues(alpha: 0.3)
                : theme.accentColor.withValues(alpha: isPrimary ? 1.0 : 0.3),
            width: isPrimary ? 0 : 1,
          ),
        ),
        elevation: isPrimary ? 2 : 0,
      ),
    );
  }
}
