// ABOUTME: Widget tests for ClipManagerScreen - main clip management UI
// ABOUTME: Validates grid display, navigation, and user interactions

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/clip_manager_screen.dart';

void main() {
  group('ClipManagerScreen', () {
    testWidgets('shows empty state when no clips', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ClipManagerScreen(),
          ),
        ),
      );

      expect(find.text('No clips recorded'), findsOneWidget);
      expect(find.text('Record'), findsOneWidget);
    });

    testWidgets('shows header with duration', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ClipManagerScreen(),
          ),
        ),
      );

      expect(find.text('0.0s / 6.3s'), findsOneWidget);
    });

    testWidgets('shows Next button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ClipManagerScreen(),
          ),
        ),
      );

      expect(find.text('Next'), findsOneWidget);
    });
  });
}
