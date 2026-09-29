// ABOUTME: Tests for runWithAppErrorHandlers, which every app-launching E2E
// ABOUTME: suite runs its scenario inside so a failed check cannot hang (#9659)

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../integration_test/helpers/test_setup.dart';

void main() {
  group('runWithAppErrorHandlers', () {
    testWidgets(
      'restores both error hooks before a failure leaves the scenario',
      (tester) async {
        final testHandler = FlutterError.onError;
        final testBuilder = ErrorWidget.builder;
        FlutterExceptionHandler? handlerWhenCaught;
        ErrorWidgetBuilder? builderWhenCaught;

        try {
          await runWithAppErrorHandlers(() async {
            // What app.main() does: replace both hooks, without chaining.
            FlutterError.onError = (_) {};
            ErrorWidget.builder = (_) => const SizedBox.shrink();
            throw TestFailure('a check failed');
          });
        } on TestFailure {
          handlerWhenCaught = FlutterError.onError;
          builderWhenCaught = ErrorWidget.builder;
        }
        // Put the test's own handler back before asserting: if the helper
        // regressed, the stand-in above would swallow the failure below and
        // hang this test the same way #9659 hung the suites.
        FlutterError.onError = testHandler;
        ErrorWidget.builder = testBuilder;

        expect(handlerWhenCaught, same(testHandler));
        expect(builderWhenCaught, same(testBuilder));
      },
    );

    testWidgets('restores ErrorWidget.builder when the scenario passes', (
      tester,
    ) async {
      final testBuilder = ErrorWidget.builder;

      await runWithAppErrorHandlers(() async {
        ErrorWidget.builder = (_) => const SizedBox.shrink();
        expect(ErrorWidget.builder, isNot(same(testBuilder)));
      });

      expect(ErrorWidget.builder, same(testBuilder));
    });

    testWidgets(
      "leaves the app's FlutterError.onError to the teardown when the "
      'scenario passes',
      (tester) async {
        void appHandler(FlutterErrorDetails details) {}

        await runWithAppErrorHandlers(() async {
          FlutterError.onError = appHandler;
        });

        expect(FlutterError.onError, same(appHandler));
      },
    );

    testWidgets('swallows known noise and reports every other error', (
      tester,
    ) async {
      await runWithAppErrorHandlers(() async {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: StateError('setState() called after dispose()'),
          ),
        );
        expect(tester.takeException(), isNull);

        FlutterError.reportError(
          FlutterErrorDetails(exception: StateError('a real failure')),
        );
        expect(tester.takeException(), isA<StateError>());
      });
    });
  });
}
