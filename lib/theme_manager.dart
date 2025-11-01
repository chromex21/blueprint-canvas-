import 'package:flutter/material.dart';

/// ThemeManager: Unified theme system for canvas and control panel
/// 
/// Manages color schemes that bind the control panel appearance
/// with the canvas border, creating a cohesive visual experience.
class ThemeManager extends ChangeNotifier {
  CanvasTheme _currentTheme = CanvasTheme.blueprintBlue;

  CanvasTheme get currentTheme => _currentTheme;

  void setTheme(CanvasTheme theme) {
    if (_currentTheme != theme) {
      _currentTheme = theme;
      notifyListeners();
    }
  }

  Color get accentColor => _currentTheme.accentColor;
  Color get backgroundColor => _currentTheme.backgroundColor;
  Color get panelColor => _currentTheme.panelColor;
  Color get borderColor => _currentTheme.borderColor;
  Color get gridColor => _currentTheme.gridColor;
  Color get textColor => _currentTheme.textColor;

  // Animation intensity settings (0.0 to 1.0)
  double _gridPulseIntensity = 0.7;
  double _radarSweepIntensity = 0.5;
  bool _animationsEnabled = true;

  double get gridPulseIntensity => _gridPulseIntensity;
  double get radarSweepIntensity => _radarSweepIntensity;
  bool get animationsEnabled => _animationsEnabled;

  void setGridPulseIntensity(double value) {
    if (_gridPulseIntensity != value) {
      _gridPulseIntensity = value.clamp(0.0, 1.0);
      notifyListeners();
    }
  }

  void setRadarSweepIntensity(double value) {
    if (_radarSweepIntensity != value) {
      _radarSweepIntensity = value.clamp(0.0, 1.0);
      notifyListeners();
    }
  }

  void setAnimationsEnabled(bool value) {
    if (_animationsEnabled != value) {
      _animationsEnabled = value;
      notifyListeners();
    }
  }
}

/// CanvasTheme: Defines a complete color scheme for the canvas system
class CanvasTheme {
  final String name;
  final Color accentColor;
  final Color backgroundColor;
  final Color panelColor;
  final Color borderColor;
  final Color gridColor;
  final Color textColor;

  const CanvasTheme({
    required this.name,
    required this.accentColor,
    required this.backgroundColor,
    required this.panelColor,
    required this.borderColor,
    required this.gridColor,
    required this.textColor,
  });

  // ============================================================================
  // DEFAULT THEMES
  // ============================================================================

  /// Blueprint Blue: Classic technical drawing aesthetic
  static const blueprintBlue = CanvasTheme(
    name: 'Blueprint Blue',
    accentColor: Color(0xFF00D9FF),
    backgroundColor: Color(0xFF0A1A2F),
    panelColor: Color(0xFF0D1B2E),
    borderColor: Color(0xFF00D9FF),
    gridColor: Color(0xFF00D9FF),
    textColor: Color(0xFFE0F7FF),
  );

  /// Dark Neon: Cyberpunk-inspired high contrast
  static const darkNeon = CanvasTheme(
    name: 'Dark Neon',
    accentColor: Color(0xFFFF0088),
    backgroundColor: Color(0xFF0D0D0D),
    panelColor: Color(0xFF1A1A1A),
    borderColor: Color(0xFFFF0088),
    gridColor: Color(0xFFFF0088),
    textColor: Color(0xFFFFE0F0),
  );

  /// Whiteboard Minimal: Clean, professional, high visibility
  static const whiteboardMinimal = CanvasTheme(
    name: 'Whiteboard Minimal',
    accentColor: Color(0xFF2196F3),
    backgroundColor: Color(0xFFF5F5F5),
    panelColor: Color(0xFFFFFFFF),
    borderColor: Color(0xFF2196F3),
    gridColor: Color(0xFFBDBDBD),
    textColor: Color(0xFF212121),
  );

  /// Get all available themes
  static List<CanvasTheme> get allThemes => [
        blueprintBlue,
        darkNeon,
        whiteboardMinimal,
      ];
}
