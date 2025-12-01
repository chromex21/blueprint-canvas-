import 'package:flutter/material.dart';
import '../models/session_info.dart';
import '../theme_manager.dart';

/// SessionGridCard: Premium grid card for session display
/// 
/// Features:
/// - Gradient background
/// - Neon glow on hover/select (cyan/teal accent)
/// - Rounded corners (20-24px)
/// - Strong visual hierarchy
/// - Smooth animations
class SessionGridCard extends StatefulWidget {
  final SessionInfo session;
  final bool isSelected;
  final bool isSelectionMode;
  final ThemeManager themeManager;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const SessionGridCard({
    super.key,
    required this.session,
    required this.isSelected,
    this.isSelectionMode = false,
    required this.themeManager,
    required this.onTap,
    required this.onDoubleTap,
    this.onRename,
    this.onDelete,
  });

  @override
  State<SessionGridCard> createState() => _SessionGridCardState();
}

class _SessionGridCardState extends State<SessionGridCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    // Start animation if selected
    if (widget.isSelected) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SessionGridCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Start/stop animation based on selection state
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _glowController.repeat(reverse: true);
      } else if (!_isHovered) {
        _glowController.stop();
        _glowController.reset();
      }
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

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
      animation: Listenable.merge([widget.themeManager, _glowAnimation]),
      builder: (context, _) {
        final theme = widget.themeManager.currentTheme;
        final accentColor = theme.accentColor;
        final isActive = widget.isSelected || _isHovered;
        final glowIntensity = isActive ? _glowAnimation.value : 0.0;
        // Thicker border in selection mode when selected
        final borderWidth = widget.isSelectionMode && widget.isSelected
            ? 3.0
            : (isActive ? 2.0 : 1.5);

        return MouseRegion(
          onEnter: (_) {
            setState(() => _isHovered = true);
            if (!widget.isSelected) {
              _glowController.repeat(reverse: true);
            }
          },
          onExit: (_) {
            setState(() => _isHovered = false);
            if (!widget.isSelected) {
              _glowController.stop();
              _glowController.reset();
            }
          },
          child: GestureDetector(
            onDoubleTap: widget.isSelectionMode ? null : widget.onDoubleTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isSelected
                      ? [
                          accentColor.withValues(alpha: 0.2),
                          accentColor.withValues(alpha: 0.1),
                          theme.panelColor.withValues(alpha: 0.8),
                        ]
                      : [
                          theme.panelColor.withValues(alpha: 0.6),
                          theme.panelColor.withValues(alpha: 0.4),
                          theme.backgroundColor.withValues(alpha: 0.3),
                        ],
                ),
                border: Border.all(
                  color: isActive
                      ? accentColor.withValues(alpha: 0.6 + glowIntensity * 0.4)
                      : theme.borderColor.withValues(alpha: 0.2),
                  width: borderWidth,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: accentColor.withValues(
                              alpha: (0.2 + glowIntensity * 0.3) + 
                                     (widget.isSelectionMode && widget.isSelected ? 0.2 : 0.0)),
                          blurRadius: widget.isSelectionMode && widget.isSelected ? 24.0 : 20.0,
                          spreadRadius: widget.isSelectionMode && widget.isSelected ? 4.0 : 2.0,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: accentColor.withValues(
                              alpha: (0.1 + glowIntensity * 0.2) +
                                     (widget.isSelectionMode && widget.isSelected ? 0.15 : 0.0)),
                          blurRadius: widget.isSelectionMode && widget.isSelected ? 50.0 : 40.0,
                          spreadRadius: widget.isSelectionMode && widget.isSelected ? -1.0 : -2.0,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          spreadRadius: -2,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap,
                    borderRadius: BorderRadius.circular(22),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Header with icon and actions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  widget.isSelectionMode && widget.isSelected
                                      ? Icons.check_circle
                                      : Icons.assignment_outlined,
                                  color: accentColor,
                                  size: 24,
                                ),
                              ),
                              // Action buttons (hidden in selection mode)
                              if (!widget.isSelectionMode)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget.onRename != null)
                                      _buildActionButton(
                                        theme,
                                        icon: Icons.edit_outlined,
                                        onPressed: widget.onRename!,
                                        color: theme.textColor,
                                      ),
                                    const SizedBox(width: 4),
                                    if (widget.onDelete != null)
                                      _buildActionButton(
                                        theme,
                                        icon: Icons.delete_outline,
                                        onPressed: widget.onDelete!,
                                        color: Colors.red,
                                      ),
                                  ],
                                ),
                            ],
                          ),

                          // Session name and timestamp
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  widget.session.name,
                                  style: TextStyle(
                                    color: theme.textColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: theme.textColor
                                          .withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatTimestamp(widget.session.lastModified),
                                      style: TextStyle(
                                        color: theme.textColor
                                            .withValues(alpha: 0.6),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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

  /// Build action button
  Widget _buildActionButton(
    CanvasTheme theme, {
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.panelColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: color.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

