import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/blurhash_display.dart';

void main() {
  group(BlurhashDisplay, () {
    // A real, decodable blurhash — the decode path under test rejects
    // malformed strings before it ever produces an image.
    const validBlurhash = 'L5H2EC=PM+yV0g-mq.wG9c010J}I';
    // A second decodable hash, so a widget update actually re-decodes.
    const otherValidBlurhash = 'LEHV6nWB2yk8pyo0adR*.7kCMdnj';

    testWidgets('keeps decode future stable across parent rebuilds', (
      tester,
    ) async {
      late StateSetter rebuildParent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuildParent = setState;
                // Non-const so each parent rebuild produces a new
                // BlurhashDisplay instance and forces its build() to run —
                // mirroring how the profile grid hosts the widget.
                // ignore: prefer_const_constructors
                return BlurhashDisplay(blurhash: validBlurhash);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final futureBuilderFinder = find.byType(FutureBuilder<ui.Image?>);
      expect(futureBuilderFinder, findsOneWidget);
      final firstFuture = tester
          .widget<FutureBuilder<ui.Image?>>(futureBuilderFinder)
          .future;
      expect(firstFuture, isNotNull);

      rebuildParent(() {});
      await tester.pump();

      final secondFuture = tester
          .widget<FutureBuilder<ui.Image?>>(futureBuilderFinder)
          .future;
      expect(secondFuture, same(firstFuture));
    });

    testWidgets('applies opacity to the gradient fallback colors', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BlurhashDisplay(
              blurhash: validBlurhash,
              width: 100,
              height: 100,
              opacity: 0.5,
            ),
          ),
        ),
      );
      // First frame after decode: the image future is still pending, so the
      // gradient fallback renders — its colors must carry the alpha instead
      // of a saveLayer-costing Opacity widget.
      final container = tester.widget<Container>(find.byType(Container));
      final gradient =
          (container.decoration! as BoxDecoration).gradient! as LinearGradient;
      for (final color in gradient.colors) {
        expect(color.a, lessThanOrEqualTo(0.5 + 0.01));
      }
      expect(gradient.colors.first.a, closeTo(0.5, 0.01));
      expect(find.byType(Opacity), findsNothing);
    });

    testWidgets('disposes the decoded image when unmounted', (tester) async {
      await tester.pumpWidget(
        const SizedBox(
          width: 100,
          height: 100,
          child: BlurhashDisplay(blurhash: validBlurhash),
        ),
      );
      final image = await _decodedImage(tester);
      expect(image.debugDisposed, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());

      expect(image.debugDisposed, isTrue);
    });

    testWidgets('disposes the previous image once a new blurhash decodes', (
      tester,
    ) async {
      await tester.pumpWidget(
        const SizedBox(
          width: 100,
          height: 100,
          child: BlurhashDisplay(blurhash: validBlurhash),
        ),
      );
      final first = await _decodedImage(tester);

      await tester.pumpWidget(
        const SizedBox(
          width: 100,
          height: 100,
          child: BlurhashDisplay(blurhash: otherValidBlurhash),
        ),
      );
      final second = await _decodedImage(tester);

      expect(second, isNot(same(first)));
      expect(first.debugDisposed, isTrue);
      expect(second.debugDisposed, isFalse);
    });
  });
}

/// Resolves the image the widget's [FutureBuilder] is waiting on.
///
/// The decode hops between the engine and `then` callbacks queued in the test's
/// fake-async zone. Awaiting the future inside a single `runAsync` therefore
/// never completes; alternating real event-queue turns with pumps does.
Future<ui.Image> _decodedImage(WidgetTester tester) async {
  final future = tester
      .widget<FutureBuilder<ui.Image?>>(find.byType(FutureBuilder<ui.Image?>))
      .future!;
  ui.Image? image;
  var completed = false;
  unawaited(
    future.then((value) {
      image = value;
      completed = true;
    }),
  );
  for (var attempt = 0; attempt < 50 && !completed; attempt++) {
    await tester.runAsync(pumpEventQueue);
    await tester.pump();
  }
  expect(completed, isTrue, reason: 'blurhash decode never completed');
  expect(image, isNotNull);
  return image!;
}
