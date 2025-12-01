import 'package:flutter/material.dart';
import 'theme_manager.dart';

/// SettingsDialog: Popup dialog for canvas settings
class SettingsDialog extends StatefulWidget {
  final ThemeManager themeManager;
  final double currentGridSpacing;
  final bool currentGridVisible;
  final bool currentSnapToGrid;
  final double currentDockScale; // Dock panel size scale
  final ValueChanged<double> onGridSpacingChanged;
  final ValueChanged<bool> onGridVisibilityChanged;
  final ValueChanged<bool> onSnapToGridChanged;
  final ValueChanged<double> onDockScaleChanged; // Dock scale callback
  final VoidCallback onResetView;

  const SettingsDialog({
    super.key,
    required this.themeManager,
    required this.currentGridSpacing,
    required this.currentGridVisible,
    required this.currentSnapToGrid,
    required this.currentDockScale,
    required this.onGridSpacingChanged,
    required this.onGridVisibilityChanged,
    required this.onSnapToGridChanged,
    required this.onDockScaleChanged,
    required this.onResetView,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late double _gridSpacing;
  late bool _gridVisible;
  late bool _snapToGrid;
  late double _dockScale;

  @override
  void initState() {
    super.initState();
    _gridSpacing = widget.currentGridSpacing;
    _gridVisible = widget.currentGridVisible;
    _snapToGrid = widget.currentSnapToGrid;
    _dockScale = widget.currentDockScale;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.themeManager,
      builder: (context, _) {
        final theme = widget.themeManager.currentTheme;

        return Dialog(
          backgroundColor: theme.panelColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.borderColor.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: Container(
            width: 500,
            constraints: const BoxConstraints(maxHeight: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.backgroundColor.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: theme.borderColor.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.settings,
                          color: theme.accentColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Canvas Settings',
                              style: TextStyle(
                                color: theme.textColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                              'Configure canvas appearance and behavior',
                              style: TextStyle(
                                color: theme.textColor.withValues(alpha: 0.6),
                                fontSize: 13,
                              ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.accentColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: theme.accentColor.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'v2.0 Stable',
                                    style: TextStyle(
                                      color: theme.accentColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: theme.textColor.withValues(alpha: 0.7),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Theme Section
                        _buildSectionHeader('Theme', theme, Icons.palette),
                        const SizedBox(height: 12),
                        _buildThemeSelector(theme),
                        const SizedBox(height: 24),

                        // Canvas Controls Section
                        _buildSectionHeader('Canvas Controls', theme, Icons.grid_on),
                        const SizedBox(height: 12),
                        _buildCanvasControls(theme),
                        const SizedBox(height: 24),

                        // Dock Panel Size Section
                        _buildSectionHeader('Dock Panels', theme, Icons.dock),
                        const SizedBox(height: 12),
                        _buildDockPanelControls(theme),
                        const SizedBox(height: 24),

                        // Quick Actions Section
                        _buildSectionHeader('Quick Actions', theme, Icons.flash_on),
                        const SizedBox(height: 12),
                        _buildQuickActions(theme),
                      ],
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.backgroundColor.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: theme.borderColor.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          // Reset to initial values
                          setState(() {
                            _gridSpacing = widget.currentGridSpacing;
                            _gridVisible = widget.currentGridVisible;
                            _snapToGrid = widget.currentSnapToGrid;
                            _dockScale = widget.currentDockScale;
                          });
                        },
                        child: Text(
                          'Reset',
                          style: TextStyle(color: theme.textColor.withValues(alpha: 0.7)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          // Apply changes
                          widget.onGridSpacingChanged(_gridSpacing);
                          widget.onGridVisibilityChanged(_gridVisible);
                          widget.onSnapToGridChanged(_snapToGrid);
                          widget.onDockScaleChanged(_dockScale);
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, CanvasTheme theme, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.accentColor,
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
        const SizedBox(width: 8),
        Expanded(
          child: Divider(
            color: theme.borderColor.withValues(alpha: 0.2),
            thickness: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildThemeSelector(CanvasTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
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
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.accentColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: t.accentColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.name,
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          Text(
                            _getThemeDescription(t.name),
                            style: TextStyle(
                              color: theme.textColor.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: theme.accentColor,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getThemeDescription(String themeName) {
    switch (themeName) {
      case 'Blueprint Blue':
        return 'Classic technical drawing style';
      case 'Dark Neon':
        return 'Cyberpunk high contrast';
      case 'Whiteboard Minimal':
        return 'Clean professional look';
      default:
        return '';
    }
  }

  Widget _buildCanvasControls(CanvasTheme theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.borderColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          // Grid Visibility
          _buildToggle(
            'Show Grid',
            _gridVisible,
            (value) => setState(() => _gridVisible = value),
            theme,
            Icons.grid_4x4,
          ),
          const SizedBox(height: 16),

          // Snap to Grid
          _buildToggle(
            'Snap to Grid',
            _snapToGrid,
            (value) => setState(() => _snapToGrid = value),
            theme,
            Icons.grid_3x3,
          ),
          const SizedBox(height: 20),

          // Grid Spacing
          _buildSlider(
            'Grid Spacing',
            _gridSpacing,
            25,
            200,
            7,
            (value) => setState(() => _gridSpacing = value),
            theme,
            unit: 'px',
          ),
        ],
      ),
    );
  }

  Widget _buildDockPanelControls(CanvasTheme theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.borderColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info text
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: theme.accentColor.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Adjust the size of shape and media dock panels',
                  style: TextStyle(
                    color: theme.textColor.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Dock Scale Slider
          _buildSlider(
            'Dock Panel Size',
            _dockScale,
            0.75,
            2.0,
            5,
            (value) => setState(() => _dockScale = value),
            theme,
            unit: 'x',
            decimals: 2,
          ),
          
          const SizedBox(height: 8),
          
          // Scale indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildScaleIndicator('Compact', 0.75, _dockScale, theme),
              _buildScaleIndicator('Default', 1.0, _dockScale, theme),
              _buildScaleIndicator('Large', 1.5, _dockScale, theme),
              _buildScaleIndicator('Max', 2.0, _dockScale, theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScaleIndicator(String label, double scale, double currentScale, CanvasTheme theme) {
    final isActive = (currentScale - scale).abs() < 0.1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? theme.accentColor.withValues(alpha: 0.15)
            : theme.backgroundColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isActive
              ? theme.accentColor.withValues(alpha: 0.5)
              : theme.borderColor.withValues(alpha: 0.2),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive
              ? theme.accentColor
              : theme.textColor.withValues(alpha: 0.5),
          fontSize: 10,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }


  Widget _buildQuickActions(CanvasTheme theme) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              widget.onResetView();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset View'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accentColor.withValues(alpha: 0.15),
              foregroundColor: theme.accentColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildToggle(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
    CanvasTheme theme,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, color: theme.accentColor.withValues(alpha: 0.6), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: theme.textColor.withValues(alpha: 0.8),
              fontSize: 14,
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
                fontSize: 14,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${value.toStringAsFixed(decimals)}$unit',
                style: TextStyle(
                  color: theme.accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
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

}
