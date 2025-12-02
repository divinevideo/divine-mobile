// ABOUTME: TDD tests for AsyncValueUIHelpersMixin
// ABOUTME: Verifies AsyncValue UI handling with consistent loading/error states

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/mixins/async_value_ui_helpers_mixin.dart';

void main() {
  group('AsyncValueUIHelpersMixin', () {
    testWidgets('SPEC: should render data widget when AsyncValue has data', (
      tester,
    ) async {
      final mixin = TestAsyncValueUIHelpersMixin();
      final asyncValue = const AsyncValue.data('test data');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: mixin.buildAsyncUI(
              asyncValue,
              onData: (data) => Text('Data: $data'),
            ),
          ),
        ),
      );

      expect(find.text('Data: test data'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
      'SPEC: should render default loading widget when AsyncValue is loading',
      (tester) async {
        final mixin = TestAsyncValueUIHelpersMixin();
        final asyncValue = const AsyncValue<String>.loading();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: mixin.buildAsyncUI(
                asyncValue,
                onData: (data) => Text('Data: $data'),
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Data: test data'), findsNothing);
      },
    );

    testWidgets('SPEC: should render custom loading widget when provided', (
      tester,
    ) async {
      final mixin = TestAsyncValueUIHelpersMixin();
      final asyncValue = const AsyncValue<String>.loading();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: mixin.buildAsyncUI(
              asyncValue,
              onData: (data) => Text('Data: $data'),
              onLoading: () => const Text('Custom Loading'),
            ),
          ),
        ),
      );

      expect(find.text('Custom Loading'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
      'SPEC: should render default error widget when AsyncValue has error',
      (tester) async {
        final mixin = TestAsyncValueUIHelpersMixin();
        final asyncValue = AsyncValue<String>.error(
          'Test error',
          StackTrace.empty,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: mixin.buildAsyncUI(
                asyncValue,
                onData: (data) => Text('Data: $data'),
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.textContaining('Test error'), findsOneWidget);
      },
    );

    testWidgets('SPEC: should render custom error widget when provided', (
      tester,
    ) async {
      final mixin = TestAsyncValueUIHelpersMixin();
      final asyncValue = AsyncValue<String>.error(
        'Test error',
        StackTrace.empty,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: mixin.buildAsyncUI(
              asyncValue,
              onData: (data) => Text('Data: $data'),
              onError: (error, stack) => Text('Custom Error: $error'),
            ),
          ),
        ),
      );

      expect(find.text('Custom Error: Test error'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('SPEC: default loading widget should be centered', (
      tester,
    ) async {
      final mixin = TestAsyncValueUIHelpersMixin();
      final asyncValue = const AsyncValue<String>.loading();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: mixin.buildAsyncUI(
              asyncValue,
              onData: (data) => Text('Data: $data'),
            ),
          ),
        ),
      );

      final center = tester.widget<Center>(
        find.ancestor(
          of: find.byType(CircularProgressIndicator),
          matching: find.byType(Center),
        ),
      );

      expect(center, isNotNull);
    });

    testWidgets(
      'SPEC: default error widget should show error icon and message',
      (tester) async {
        final mixin = TestAsyncValueUIHelpersMixin();
        final asyncValue = AsyncValue<String>.error(
          'Network timeout',
          StackTrace.empty,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: mixin.buildAsyncUI(
                asyncValue,
                onData: (data) => Text('Data: $data'),
              ),
            ),
          ),
        );

        // Should have error icon
        expect(find.byIcon(Icons.error_outline), findsOneWidget);

        // Should have error message
        expect(find.textContaining('Network timeout'), findsOneWidget);

        // Should be centered
        final center = tester.widget<Center>(
          find.ancestor(of: find.byType(Column), matching: find.byType(Center)),
        );
        expect(center, isNotNull);
      },
    );

    testWidgets('SPEC: should handle null data correctly', (tester) async {
      final mixin = TestAsyncValueUIHelpersMixin();
      final asyncValue = const AsyncValue<String?>.data(null);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: mixin.buildAsyncUI(
              asyncValue,
              onData: (data) => Text('Data: ${data ?? "null"}'),
            ),
          ),
        ),
      );

      expect(find.text('Data: null'), findsOneWidget);
    });

    testWidgets('SPEC: should work with complex data types', (tester) async {
      final mixin = TestAsyncValueUIHelpersMixin();
      final asyncValue = AsyncValue.data({'key': 'value', 'count': 42});

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: mixin.buildAsyncUI<Map<String, dynamic>>(
              asyncValue,
              onData: (data) => Text('Count: ${data['count']}'),
            ),
          ),
        ),
      );

      expect(find.text('Count: 42'), findsOneWidget);
    });
  });
}

/// Test helper class that mixes in AsyncValueUIHelpersMixin
class TestAsyncValueUIHelpersMixin with AsyncValueUIHelpersMixin {}
