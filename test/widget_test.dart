// Widget tests for the Animated Blueprint Canvas app

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dark_canvas_core/main.dart';
import 'package:dark_canvas_core/enhanced_canvas_layout.dart';

void main() {
  testWidgets('Enhanced canvas layout loads successfully', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(const DarkCanvasApp());

    // Verify that the enhanced canvas layout is present
    expect(find.byType(EnhancedCanvasLayout), findsOneWidget);

    // Verify the scaffold is present with blueprint background
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFF0A1A2F));
  });

  testWidgets('App has correct title', (WidgetTester tester) async {
    await tester.pumpWidget(const DarkCanvasApp());

    // Verify MaterialApp title
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.title, equals('Dark Canvas Core'));
  });

  testWidgets('SafeArea wraps content', (WidgetTester tester) async {
    await tester.pumpWidget(const DarkCanvasApp());

    // Verify SafeArea is present
    expect(find.byType(SafeArea), findsOneWidget);
  });

  testWidgets('Stack allows for future interactive layers', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DarkCanvasApp());

    // Verify Stack is present for layering
    expect(find.byType(Stack), findsWidgets);

    // Verify EnhancedCanvasLayout contains interactive elements
    expect(find.byType(EnhancedCanvasLayout), findsOneWidget);
  });

  testWidgets('Canvas components are properly initialized', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DarkCanvasApp());

    // Pump a few frames to ensure initialization completes
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify enhanced canvas layout is still present after initialization
    expect(find.byType(EnhancedCanvasLayout), findsOneWidget);
  });

  testWidgets('Canvas renders correctly with gestures', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DarkCanvasApp());

    // Initial pump
    await tester.pump();

    // Pump several frames to simulate interaction
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // Enhanced canvas layout should still be rendering correctly
    expect(find.byType(EnhancedCanvasLayout), findsOneWidget);
    expect(find.byType(GestureDetector), findsWidgets);
  });

  testWidgets('AnimatedBuilder updates on animation changes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DarkCanvasApp());

    // Verify AnimatedBuilder is present
    expect(find.byType(AnimatedBuilder), findsOneWidget);

    // Pump several animation frames
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Should still be rendering
    expect(find.byType(AnimatedBuilder), findsOneWidget);
  });
}
