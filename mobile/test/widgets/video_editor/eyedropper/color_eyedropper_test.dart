// ABOUTME: Tests for ColorEyedropper: a lifted finger picks the color under
// ABOUTME: it, touches stay off what is below, and it closes when it cannot
// ABOUTME: capture.

import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/eyedropper/color_eyedropper.dart';
import 'package:openvine/widgets/video_editor/eyedropper/eyedropper_snapshot.dart';

const _green = Color(0xFF00C000);
const _magenta = Color(0xFFC000C0);

/// Where the boundary sits on the 400x400 test surface.
const _source = Rect.fromLTWH(100, 100, 200, 100);

void main() {
  group(ColorEyedropper, () {
    late List<Color> picked;
    late int cancels;
    late int tapsBelow;
    late double? capturedAt;

    setUp(() {
      picked = [];
      cancels = 0;
      tapsBelow = 0;
      capturedAt = null;
    });

    /// A snapshot of the boundary whose left half is green and right half
    /// magenta, four image pixels each — wide enough that a pick averaged
    /// over its neighbours stays inside one half.
    Future<EyedropperSnapshot> halves(WidgetTester tester) async {
      const width = 8;
      final image = await tester.runAsync(
        () => createTestImage(width: width, cache: false),
      );
      final pixels = ByteData(width * 4);
      for (var x = 0; x < width; x++) {
        pixels.setUint32(x * 4, x < width ~/ 2 ? 0x00C000FF : 0xC000C0FF);
      }
      return EyedropperSnapshot(
        image: image!,
        pixels: pixels,
        size: _source.size,
      );
    }

    Future<void> pump(
      WidgetTester tester, {
      EyedropperSnapshot? snapshot,
      bool sourceIsBoundary = true,
    }) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final key = GlobalKey();
      final below = GestureDetector(
        onTap: () => tapsBelow++,
        child: const ColoredBox(color: _green),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fromRect(
                  rect: _source,
                  child: sourceIsBoundary
                      ? RepaintBoundary(key: key, child: below)
                      : KeyedSubtree(key: key, child: below),
                ),
                Positioned.fill(
                  child: ColorEyedropper(
                    sourceKey: key,
                    onColorPicked: picked.add,
                    onCancel: () => cancels++,
                    capture: (boundary, {required pixelRatio}) async {
                      capturedAt = pixelRatio;
                      return snapshot;
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      // The capture starts after the first frame and lands in the next.
      await tester.pump();
      await tester.pump();
    }

    group('picking', () {
      testWidgets('picks the color under the finger when it lifts', (
        tester,
      ) async {
        await pump(tester, snapshot: await halves(tester));
        expect(capturedAt, 3);

        final finger = await tester.startGesture(const Offset(150, 150));
        await tester.pump();
        expect(picked, isEmpty, reason: 'touching alone picks nothing');

        await finger.up();
        await tester.pump();
        expect(picked, [_green]);
        expect(cancels, 0);
      });

      testWidgets('picks where a drag ends', (tester) async {
        await pump(tester, snapshot: await halves(tester));

        final finger = await tester.startGesture(const Offset(150, 150));
        await finger.moveTo(const Offset(250, 150));
        await finger.up();
        await tester.pump();

        expect(picked, [_magenta]);
      });

      testWidgets('picks from the nearest edge outside the boundary', (
        tester,
      ) async {
        await pump(tester, snapshot: await halves(tester));

        await tester.tapAt(const Offset(390, 20));
        await tester.pump();

        expect(picked, [_magenta]);
      });

      testWidgets('shows the loupe only while a finger is down', (
        tester,
      ) async {
        await pump(tester, snapshot: await halves(tester));
        final painters = find.descendant(
          of: find.byType(ColorEyedropper),
          matching: find.byType(CustomPaint),
        );
        final idle = painters.evaluate().length;

        final finger = await tester.startGesture(const Offset(150, 150));
        await tester.pump();
        expect(painters, findsNWidgets(idle + 1));

        await finger.up();
        await tester.pump();
        expect(painters, findsNWidgets(idle));
      });

      testWidgets('ignores a second finger while one is picking', (
        tester,
      ) async {
        await pump(tester, snapshot: await halves(tester));

        final first = await tester.startGesture(const Offset(150, 150));
        final second = await tester.startGesture(const Offset(250, 150));
        await second.up();
        await tester.pump();
        expect(picked, isEmpty);

        await first.up();
        await tester.pump();
        expect(picked, [_green]);
      });

      testWidgets('keeps touches off what lies below', (tester) async {
        await pump(tester, snapshot: await halves(tester));

        await tester.tapAt(const Offset(150, 150));
        await tester.pump();

        expect(picked, [_green]);
        expect(tapsBelow, 0);
      });
    });

    group('closing', () {
      testWidgets('closes without a color from its close button', (
        tester,
      ) async {
        await pump(tester, snapshot: await halves(tester));
        final l10n = lookupAppLocalizations(const Locale('en'));
        final close = find.byWidgetPredicate(
          (widget) =>
              widget is DivineIconButton &&
              widget.semanticLabel ==
                  l10n.videoEditorEyedropperCancelSemanticLabel,
        );
        final hint = find.text(l10n.videoEditorEyedropperHint);
        expect(hint, findsOneWidget);
        // Both sit at the top, where the host's toolbar was, not over the
        // middle of what is being picked from.
        expect(tester.getRect(close).bottom, lessThan(_source.top));
        expect(tester.getRect(hint).bottom, lessThan(_source.top));

        await tester.tap(close);
        await tester.pump();

        expect(cancels, 1);
        expect(picked, isEmpty);
      });

      testWidgets('closes when the boundary cannot be captured', (
        tester,
      ) async {
        await pump(tester);

        expect(capturedAt, isNotNull);
        expect(cancels, 1);
      });

      testWidgets('closes when the key is not on a repaint boundary', (
        tester,
      ) async {
        await pump(
          tester,
          snapshot: await halves(tester),
          sourceIsBoundary: false,
        );

        expect(capturedAt, isNull);
        expect(cancels, 1);
      });

      testWidgets('releases the captured frame when it goes away', (
        tester,
      ) async {
        final snapshot = await halves(tester);
        await pump(tester, snapshot: snapshot);
        expect(snapshot.image.debugDisposed, isFalse);

        await tester.pumpWidget(const SizedBox.shrink());

        expect(snapshot.image.debugDisposed, isTrue);
      });
    });
  });
}
