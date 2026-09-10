// ABOUTME: Pins the framework contract behind #5839's belt-and-suspenders
// ABOUTME: pattern for ErrorWidget.builder / FlutterError.onError restores.
//
// The integration_test suites (mobile/integration_test) save ErrorWidget.builder
// and FlutterError.onError at the start of each test and restore them so an
// early `expect` failure cannot leak the override into a later test in the same
// file. #5839 made those restores exception-safe. The correct shape is
// ASYMMETRIC, and this test encodes why:
//
//   * ErrorWidget.builder MUST be restored INLINE before the body ends.
//     flutter_test's `_verifyErrorWidgetBuilderUnset` runs at end-of-body,
//     BEFORE any `addTearDown` callback, and fails the test with
//     "The value of ErrorWidget.builder was changed by the test." So an
//     addTearDown-only restore breaks the happy path. The integration tests
//     ALSO register an addTearDown restore (the "suspenders") so the throw
//     path is covered — addTearDown runs regardless of test outcome.
//   * FlutterError.onError may be restored via addTearDown ONLY, because the
//     binding resets it to its pre-test value in postTest() after every test.
//
// It is impossible to demonstrate the *failing* case (addTearDown-only builder
// restore) from a PASSING test: on the happy path the framework verify fails
// the test, and on the throw path the uncaught throw fails the test. That is
// exactly the constraint this pattern works around, so this file pins the
// POSITIVE contract instead. If a future refactor drops the inline
// ErrorWidget.builder restore, the first test below fails loudly.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('integration_test error-handler restore contract (#5839)', () {
    testWidgets(
      'belt-and-suspenders: inline ErrorWidget.builder restore satisfies the '
      'end-of-body framework verify',
      (tester) async {
        final originalBuilder = ErrorWidget.builder;
        // Suspenders: covers the throw path (runs even if the body throws).
        addTearDown(() => ErrorWidget.builder = originalBuilder);

        // Simulate what app.main() does: install a custom error widget builder.
        ErrorWidget.builder = (details) => const SizedBox.shrink();
        // Prove the install changed the builder, so the restore asserted
        // below is a real round trip and not an untouched default (#8617).
        expect(ErrorWidget.builder, isNot(same(originalBuilder)));
        await tester.pumpWidget(const SizedBox());

        // Belt: the INLINE restore is what keeps the framework's end-of-body
        // _verifyErrorWidgetBuilderUnset happy. Removing this line makes this
        // test fail with "The value of ErrorWidget.builder was changed by the
        // test." — which is the regression #5839 guards against.
        ErrorWidget.builder = originalBuilder;

        expect(ErrorWidget.builder, same(originalBuilder));
      },
    );

    testWidgets(
      'FlutterError.onError may be restored via addTearDown only (no inline '
      'restore needed) — the binding resets it per test',
      (tester) async {
        final originalOnError = FlutterError.onError;
        // No inline restore: the throw-safe teardown is sufficient for onError
        // because the binding resets FlutterError.onError in postTest().
        addTearDown(() => FlutterError.onError = originalOnError);

        FlutterError.onError = (details) {};
        await tester.pumpWidget(const SizedBox());

        // Reaching here without the framework failing the test is the proof:
        // unlike ErrorWidget.builder, a still-overridden onError at end-of-body
        // does not trip a verify. The override is distinct from the original.
        expect(FlutterError.onError, isNot(same(originalOnError)));
      },
    );
  });
}
