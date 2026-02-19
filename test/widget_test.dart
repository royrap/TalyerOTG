// This is a basic Flutter widget test for RoadAid app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roadaidapp/main.dart';

void main() {
  testWidgets('RoadAid app loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    
    // Wait for async initialization to complete
    await tester.pumpAndSettle();

    // Verify that our app loads with a MaterialApp
    expect(find.byType(MaterialApp), findsOneWidget);
    
    // The app should load either the login screen or the main app
    // depending on authentication state
    expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
  });
}


