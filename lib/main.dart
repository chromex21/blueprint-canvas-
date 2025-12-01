import 'package:flutter/material.dart';
import 'theme_manager.dart';
import 'services/blueprint_session_manager.dart';
import 'widgets/blueprint_session_home.dart';

void main() {
  runApp(const SimpleCanvasApp());
}

class SimpleCanvasApp extends StatefulWidget {
  const SimpleCanvasApp({super.key});

  @override
  State<SimpleCanvasApp> createState() => _SimpleCanvasAppState();
}

class _SimpleCanvasAppState extends State<SimpleCanvasApp> {
  late final ThemeManager _themeManager;
  late final BlueprintSessionManager _sessionManager;

  @override
  void initState() {
    super.initState();
    _themeManager = ThemeManager();
    _sessionManager = BlueprintSessionManager();
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
          title: 'Blueprint Canvas',
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
          home: BlueprintSessionHome(
            themeManager: _themeManager,
            sessionManager: _sessionManager,
          ),
        );
      },
    );
  }
}
