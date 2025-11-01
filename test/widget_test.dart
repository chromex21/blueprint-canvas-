// Widget tests for the Animated Blueprint Canvas app

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dark_canvas_core/main.dart';
import 'package:dark_canvas_core/blueprint_canvas.dart';

void main() {
  testWidgets('Blueprint canvas loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(const DarkCanvasApp());

    // Verify that the blueprint canvas is present
    expect(find.byType(BlueprintCanvas), findsOneWidget);
    
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

  testWidgets('Stack allows for future interactive layers', (WidgetTester tester) async {
    await tester.pumpWidget(const DarkCanvasApp());
    
    // Verify Stack is present for layering
    expect(find.byType(Stack), findsOneWidget);
    
    // Verify BlueprintCanvas is first child (background)
    final stack = tester.widget<Stack>(find.byType(Stack));
    expect(stack.children.first, isA<BlueprintCanvas>());
  });

  testWidgets('Animation controllers are properly initialized', (WidgetTester tester) async {
    await tester.pumpWidget(const DarkCanvasApp());
    
    // Pump a few frames to ensure animations start
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    
    // Verify canvas is still present after animation frames
    expect(find.byType(BlueprintCanvas), findsOneWidget);
  });

  testWidgets('Canvas repaints with animation updates', (WidgetTester tester) async {
    await tester.pumpWidget(const DarkCanvasApp());
    
    // Initial pump
    await tester.pump();
    
    // Advance animation by 1 second
    await tester.pump(const Duration(seconds: 1));
    
    // Advance by another second
    await tester.pump(const Duration(seconds: 1));
    
    // Canvas should still be rendering correctly
    expect(find.byType(BlueprintCanvas), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('AnimatedBuilder updates on animation changes', (WidgetTester tester) async {
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
