import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

void main() {
  group(IdentitySkeletonizer, () {
    Widget buildSubject({
      required bool isLoading,
      Duration fallthroughTimeout = const Duration(seconds: 7),
      bool excludeSemantics = false,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: IdentitySkeletonizer(
            isLoading: isLoading,
            fallthroughTimeout: fallthroughTimeout,
            excludeSemantics: excludeSemantics,
            child: Semantics(
              label: 'Identity',
              child: const SizedBox.square(dimension: 64, key: Key('child')),
            ),
          ),
        ),
      );
    }

    Skeletonizer findSkeletonizer(WidgetTester tester) {
      // Skeletonizer is abstract; the concrete runtime widget is a private
      // subclass, so bySubtype is required (mirrors the helper in
      // profile_header_widget_test.dart).
      return tester.widget<Skeletonizer>(find.bySubtype<Skeletonizer>());
    }

    testWidgets('Skeletonizer.enabled is false when isLoading is false', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(isLoading: false));

      expect(findSkeletonizer(tester).enabled, isFalse);
      expect(find.byKey(const Key('child')), findsOneWidget);
    });

    testWidgets('Skeletonizer.enabled is true when isLoading is true', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(isLoading: true));

      expect(findSkeletonizer(tester).enabled, isTrue);
    });

    testWidgets('keeps semantics by default while shimmering', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(buildSubject(isLoading: true));

      expect(find.bySemanticsLabel('Identity'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('can hide placeholder semantics only while shimmering', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        buildSubject(
          isLoading: true,
          fallthroughTimeout: const Duration(seconds: 3),
          excludeSemantics: true,
        ),
      );

      expect(find.bySemanticsLabel('Identity'), findsNothing);

      await tester.pump(const Duration(seconds: 4));

      expect(find.bySemanticsLabel('Identity'), findsOneWidget);
      await tester.pumpAndSettle();
      semantics.dispose();
    });

    testWidgets(
      'Skeletonizer.enabled flips to false after fallthroughTimeout when '
      'isLoading remains true (avoids infinite shimmer for users with no '
      'Kind 0)',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            isLoading: true,
            fallthroughTimeout: const Duration(seconds: 3),
          ),
        );
        expect(findSkeletonizer(tester).enabled, isTrue);

        // Advance past the timeout.
        await tester.pump(const Duration(seconds: 4));
        expect(findSkeletonizer(tester).enabled, isFalse);

        // Cancel the lingering switch animation so the test framework
        // doesn't complain about pending timers when the widget tears down.
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'isLoading flipping true -> false cancels the pending timer',
      (tester) async {
        await tester.pumpWidget(buildSubject(isLoading: true));
        expect(findSkeletonizer(tester).enabled, isTrue);

        await tester.pumpWidget(buildSubject(isLoading: false));
        expect(findSkeletonizer(tester).enabled, isFalse);

        // No timer should fire after the cancel — advance well past the
        // default 7s timeout and confirm the state stays put.
        await tester.pump(const Duration(seconds: 10));
        expect(findSkeletonizer(tester).enabled, isFalse);
      },
    );

    testWidgets(
      'repeated rebuilds with the same isLoading do not restart the timer',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            isLoading: true,
            fallthroughTimeout: const Duration(seconds: 3),
          ),
        );

        // Advance halfway through the timeout window.
        await tester.pump(const Duration(seconds: 2));
        expect(findSkeletonizer(tester).enabled, isTrue);

        // Force a rebuild with the same isLoading — if the timer were
        // restarted on every build, the timeout would fire 3 s after this
        // pump rather than 1 s after.
        await tester.pumpWidget(
          buildSubject(
            isLoading: true,
            fallthroughTimeout: const Duration(seconds: 3),
          ),
        );

        // Advance just past the original 3 s deadline.
        await tester.pump(const Duration(seconds: 2));
        expect(findSkeletonizer(tester).enabled, isFalse);

        await tester.pumpAndSettle();
      },
    );

    testWidgets('disposing during a pending timer does not throw', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          isLoading: true,
          fallthroughTimeout: const Duration(seconds: 3),
        ),
      );
      expect(findSkeletonizer(tester).enabled, isTrue);

      // Replace the subtree before the timer fires — the State's dispose
      // should cancel the timer cleanly.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      // Advance past the original timeout — no callback should fire on
      // the disposed state.
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('default fallthroughTimeout is 7 seconds', (tester) async {
      await tester.pumpWidget(buildSubject(isLoading: true));
      expect(findSkeletonizer(tester).enabled, isTrue);

      // Just before 7 s — still shimmering.
      await tester.pump(const Duration(seconds: 6));
      expect(findSkeletonizer(tester).enabled, isTrue);

      // Past 7 s — dissolved.
      await tester.pump(const Duration(seconds: 2));
      expect(findSkeletonizer(tester).enabled, isFalse);

      await tester.pumpAndSettle();
    });
  });
}
