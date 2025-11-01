import 'package:flutter/material.dart';
import 'theme_manager.dart';

/// ControlPanel: Side-mounted control interface for canvas settings
/// 
/// Features:
/// - Fixed width (300px)
/// - Aligned left or right (configurable)
/// - Theme-aware styling that updates with canvas
/// - All canvas controls centralized here
/// - No floating/overlay elements in canvas area
class ControlPanel extends StatefulWidget {
  final ThemeManager themeManager;
  final bool alignRight;
  final ValueChanged<double> onGridSpacingChanged;
  final ValueChanged<double> onDotSizeChanged;
  final ValueChanged<bool> onGridVisibilityChanged;
  final ValueChanged<bool> onSnapToGridChanged;
  final VoidCallback onResetView;
  final double currentGridSpacing;
  final double currentDotSize;
  final bool currentGridVisible;
  final bool currentSnapToGrid;

  const ControlPanel({
    super.key,
    required this.themeManager,
    this.alignRight = true,
    required this.onGridSpacingChanged,
    required this.onDotSizeChanged,
    required this.onGridVisibilityChanged,
    required this.onSnapToGridChanged,
    required this.onResetView,
    required this.currentGridSpacing,
    required this.currentDotSize,
    required this.currentGridVisible,
    required this.currentSnapToGrid,
  });

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  static const double panelWidth = 300.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.themeManager,
      builder: (context, _) {
        final theme = widget.themeManager.currentTheme;
        
        return Container(
          width: panelWidth,
          height: double.infinity,
          decoration: BoxDecoration(
            color: theme.panelColor,
            border: Border(
              left: widget.alignRight
                  ? BorderSide(color: theme.borderColor.withValues(alpha: 0.3), width: 1)
                  : BorderSide.none,
              right: !widget.alignRight
                  ? BorderSide(color: theme.borderColor.withValues(alpha: 0.3), width: 1)
                  : BorderSide.none,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: Offset(widget.alignRight ? -5 : 5, 0),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(theme),
                const SizedBox(height: 24),

                // Theme Selector
                _buildThemeSelector(theme),
                const SizedBox(height: 24),

                // Grid Controls Section
                _buildSectionHeader('Grid Controls', theme),
                const SizedBox(height: 12),
                _buildGridControls(theme),
                const SizedBox(height: 24),

                // View Controls Section
                _buildSectionHeader('View Controls', theme),
                const SizedBox(height: 12),
                _buildViewControls(theme),
                const SizedBox(height: 24),

                // Quick Actions
                _buildSectionHeader('Quick Actions', theme),
                const SizedBox(height: 12),
                _buildQuickActions(theme),

                const SizedBox(height: 40),

                // Info Footer
                _buildInfoFooter(theme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(CanvasTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.grid_on,
                color: theme.accentColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Canvas Controls',
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Modular Blueprint System',
                    style: TextStyle(
                      color: theme.textColor.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Divider(color: theme.borderColor.withValues(alpha: 0.2)),
      ],
    );
  }

  Widget _buildThemeSelector(CanvasTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Theme',
          style: TextStyle(
            color: theme.textColor.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.backgroundColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.borderColor.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: CanvasTheme.allThemes.map((t) {
              final isSelected = t.name == theme.name;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => widget.themeManager.setTheme(t),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.accentColor.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: t.accentColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            t.name,
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: theme.accentColor,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, CanvasTheme theme) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: theme.accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: theme.textColor.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildGridControls(CanvasTheme theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.borderColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          // Grid Visibility Toggle
          _buildToggleRow(
            'Show Grid',
            widget.currentGridVisible,
            widget.onGridVisibilityChanged,
            theme,
            Icons.grid_4x4,
          ),
          const SizedBox(height: 12),

          // Snap to Grid Toggle
          _buildToggleRow(
            'Snap to Grid',
            widget.currentSnapToGrid,
            widget.onSnapToGridChanged,
            theme,
            Icons.grid_3x3,
          ),
          const SizedBox(height: 16),

          // Grid Spacing Slider
          _buildSlider(
            'Grid Spacing',
            widget.currentGridSpacing,
            25,
            200,
            7,
            widget.onGridSpacingChanged,
            theme,
            unit: 'px',
          ),
          const SizedBox(height: 12),

          // Dot Size Slider
          _buildSlider(
            'Dot Size',
            widget.currentDotSize,
            1,
            5,
            null,
            widget.onDotSizeChanged,
            theme,
            unit: 'px',
            decimals: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildViewControls(CanvasTheme theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.borderColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pan & Zoom',
            style: TextStyle(
              color: theme.textColor.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '• Drag to pan\n• Scroll to zoom\n• Pinch gesture (mobile)',
            style: TextStyle(
              color: theme.textColor.withValues(alpha: 0.6),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(CanvasTheme theme) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: widget.onResetView,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset View'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accentColor.withValues(alpha: 0.15),
              foregroundColor: theme.accentColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: theme.accentColor.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
    CanvasTheme theme,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, color: theme.accentColor.withValues(alpha: 0.6), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: theme.textColor.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: theme.accentColor,
          activeTrackColor: theme.accentColor.withValues(alpha: 0.3),
        ),
      ],
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    int? divisions,
    ValueChanged<double> onChanged,
    CanvasTheme theme, {
    String unit = '',
    int decimals = 0,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: theme.textColor.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${value.toStringAsFixed(decimals)}$unit',
                style: TextStyle(
                  color: theme.accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: theme.accentColor,
            inactiveTrackColor: theme.accentColor.withValues(alpha: 0.2),
            thumbColor: theme.accentColor,
            overlayColor: theme.accentColor.withValues(alpha: 0.2),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoFooter(CanvasTheme theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.borderColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: theme.textColor.withValues(alpha: 0.5),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Modular canvas system with unified theming',
              style: TextStyle(
                color: theme.textColor.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
