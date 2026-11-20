// ABOUTME: Tests for ChromaKeyTapToPick: a tap on the color mask preview
// ABOUTME: reads the patch of footage under it, one read at a time.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_tap_to_pick.dart';
import 'package:openvine/widgets/video_editor/eyedropper/eyedropper_snapshot.dart';

const _green = Color(0xFF00C000);
const _magenta = Color(0xFFC000C0);

const _size = Size(200, 100);

void main() {
  group(ChromaKeyTapToPick, () {
    late List<Uint8List> picked;

    setUp(() => picked = []);

    /// A 40x20 capture of the preview whose left half is green and right half
    /// magenta: wide enough that a patch near either side stays in its half.
    Future<EyedropperSnapshot> halves(WidgetTester tester) async {
      const width = 40;
      const height = 20;
      final image = await tester.runAsync(
        () => createTestImage(width: width, height: height, cache: false),
      );
      final pixels = ByteData(width * height * 4);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          pixels.setUint32(
            (y * width + x) * 4,
            x < width ~/ 2 ? 0x00C000FF : 0xC000C0FF,
          );
        }
      }
      return EyedropperSnapshot(image: image!, pixels: pixels, size: _size);
    }

    /// The distinct colors in an RGBA [patch].
    Set<Color> colorsIn(Uint8List patch) => {
      for (var i = 0; i < patch.length; i += 4)
        Color.fromARGB(patch[i + 3], patch[i], patch[i + 1], patch[i + 2]),
    };

    Future<void> pump(
      WidgetTester tester, {
      required EyedropperCapture capture,
      Widget child = const ColoredBox(color: _green),
    }) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: _size,
              child: ChromaKeyTapToPick(
                onPatchPicked: picked.add,
                capture: capture,
                child: child,
              ),
            ),
          ),
        ),
      );
    }

    group('interactions', () {
      testWidgets('reads the footage patch under each tap', (tester) async {
        final snapshots = [await halves(tester), await halves(tester)];
        await pump(
          tester,
          capture: (_, {required pixelRatio}) async => snapshots.removeAt(0),
        );

        await tester.tapAt(const Offset(30, 50));
        await tester.pump();
        await tester.tapAt(const Offset(170, 50));
        await tester.pump();

        expect(
          picked.map(colorsIn),
          equals([
            {_green},
            {_magenta},
          ]),
        );
        // A patch, not a pixel: the amount is measured from its spread.
        const side = 2 * ChromaKeyTapToPick.patchRadius + 1;
        expect(picked.first.length, equals(side * side * 4));
      });

      testWidgets("reads a tap the child's own tap recognizer would win", (
        tester,
      ) async {
        // The camera preview always registers a tap for focus, and the inner
        // of two tap recognizers wins the arena: a tap recognizer around it
        // never fired, so the camera could not pick a color at all.
        final snapshot = await halves(tester);
        await pump(
          tester,
          capture: (_, {required pixelRatio}) async => snapshot,
          child: GestureDetector(
            onTap: () {},
            onScaleStart: (_) {},
            child: const ColoredBox(color: _green),
          ),
        );

        await tester.tapAt(const Offset(30, 50));
        await tester.pump();

        expect(
          picked.map(colorsIn),
          equals([
            {_green},
          ]),
        );
      });

      testWidgets('leaves a drag to the child', (tester) async {
        final snapshot = await halves(tester);
        await pump(
          tester,
          capture: (_, {required pixelRatio}) async => snapshot,
        );

        await tester.dragFrom(const Offset(30, 50), const Offset(60, 0));
        await tester.pump();

        expect(picked, isEmpty);
        snapshot.dispose();
      });

      testWidgets('drops a tap that lands while a read is still running', (
        tester,
      ) async {
        final snapshot = await halves(tester);
        final pending = Completer<EyedropperSnapshot?>();
        var captures = 0;
        await pump(
          tester,
          capture: (_, {required pixelRatio}) {
            captures++;
            return pending.future;
          },
        );

        // A quick second tap would otherwise apply two colors out of order.
        await tester.tapAt(const Offset(30, 50));
        await tester.pump();
        await tester.tapAt(const Offset(170, 50));
        await tester.pump();
        pending.complete(snapshot);
        await tester.pump();

        expect(captures, equals(1));
        expect(
          picked.map(colorsIn),
          equals([
            {_green},
          ]),
        );
      });
    });
  });
}
