import 'package:flutter/material.dart';
import 'theme_manager.dart';
import 'canvas_layout.dart';

void main() {
  runApp(const DarkCanvasApp());
}

class DarkCanvasApp extends StatefulWidget {
  const DarkCanvasApp({super.key});

  @override
  State<DarkCanvasApp> createState() => _DarkCanvasAppState();
}

class _DarkCanvasAppState extends State<DarkCanvasApp> {
  late final ThemeManager _themeManager;

  @override
  void initState() {
    super.initState();
    _themeManager = ThemeManager();
  }

  @override
  void dispose() {
    _themeManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeManager,
      builder: (context, _) {
        final theme = _themeManager.currentTheme;

        return MaterialApp(
          title: 'Dark Canvas Core',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: theme.backgroundColor.computeLuminance() > 0.5
                ? Brightness.light
                : Brightness.dark,
            scaffoldBackgroundColor: theme.backgroundColor,
            primaryColor: theme.accentColor,
            colorScheme: ColorScheme.fromSeed(
              seedColor: theme.accentColor,
              brightness: theme.backgroundColor.computeLuminance() > 0.5
                  ? Brightness.light
                  : Brightness.dark,
            ),
          ),
          home: CanvasLayout(themeManager: _themeManager),
        );
      },
    );
  }
}
