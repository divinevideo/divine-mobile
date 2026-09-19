import 'dart:convert';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/widgets/stop_motion/stop_motion_player.dart';

void main() {
  // 1x1 transparent PNG.
  final pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    '+M8AAAMBAQDJ/IY1AAAAAElFTkSuQmCC',
  );

  late Directory tempDir;
  late List<StopMotionClipFrame> frames;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('stop_motion_player_test');
    frames = [
      for (final name in ['a', 'b', 'c'])
        StopMotionClipFrame(
          path: (File(
            '${tempDir.path}/$name.png',
          )..writeAsBytesSync(pngBytes)).path,
          duration: const Duration(milliseconds: 100),
        ),
    ];
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  String currentPath(WidgetTester tester) {
    final image = tester.widget<Image>(find.byType(Image));
    return (image.image as FileImage).file.path;
  }

  Widget wrap(Widget child, {bool reduceMotion = false}) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    );
  }

  testWidgets('advances through frames over time and loops', (tester) async {
    await tester.pumpWidget(wrap(StopMotionPlayer(frames: frames)));

    await tester.pump();
    expect(currentPath(tester), frames[0].path);

    await tester.pump(const Duration(milliseconds: 110));
    expect(currentPath(tester), frames[1].path);

    await tester.pump(const Duration(milliseconds: 100));
    expect(currentPath(tester), frames[2].path);

    // Wraps back to the first frame after the last (seamless loop).
    await tester.pump(const Duration(milliseconds: 100));
    expect(currentPath(tester), frames[0].path);
  });

  testWidgets('holds the first frame when animations are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(StopMotionPlayer(frames: frames), reduceMotion: true),
    );

    await tester.pump();
    expect(currentPath(tester), frames[0].path);

    await tester.pump(const Duration(milliseconds: 500));
    expect(currentPath(tester), frames[0].path);
  });

  group('controlled mode (position provided)', () {
    testWidgets('renders the frame for the supplied position', (tester) async {
      // Frames are 3 × 100ms → windows [0,100)=0, [100,200)=1, [200,300)=2.
      await tester.pumpWidget(
        wrap(
          StopMotionPlayer(
            frames: frames,
            position: const Duration(milliseconds: 50),
          ),
        ),
      );
      await tester.pump();
      expect(currentPath(tester), frames[0].path);

      await tester.pumpWidget(
        wrap(
          StopMotionPlayer(
            frames: frames,
            position: const Duration(milliseconds: 150),
          ),
        ),
      );
      await tester.pump();
      expect(currentPath(tester), frames[1].path);

      await tester.pumpWidget(
        wrap(
          StopMotionPlayer(
            frames: frames,
            position: const Duration(milliseconds: 250),
          ),
        ),
      );
      await tester.pump();
      expect(currentPath(tester), frames[2].path);
    });

    testWidgets('holds the last frame at the end of the sequence', (
      tester,
    ) async {
      // The editor clamps the playhead to the composition total *inclusive*, so
      // scrubbing to the end hands over exactly the 300ms total. Wrapping that
      // to 0 would show the first still while the timed layers sit at the end.
      await tester.pumpWidget(
        wrap(
          StopMotionPlayer(
            frames: frames,
            position: const Duration(milliseconds: 300),
          ),
        ),
      );
      await tester.pump();
      expect(currentPath(tester), frames[2].path);
    });

    testWidgets('does not self-advance — the frame is frozen for a fixed '
        'position', (tester) async {
      await tester.pumpWidget(
        wrap(
          StopMotionPlayer(
            frames: frames,
            position: const Duration(milliseconds: 50),
          ),
        ),
      );
      await tester.pump();
      expect(currentPath(tester), frames[0].path);

      // Pumping wall-clock time must not change the frame: the caller owns the
      // clock, so play/pause is respected (a paused editor holds the frame).
      await tester.pump(const Duration(milliseconds: 500));
      expect(currentPath(tester), frames[0].path);
    });
  });

  group('missing still', () {
    // Resolving the file is real I/O, so the failure needs real event-loop
    // turns to arrive. Polled rather than waited on for a fixed span: one span
    // is a coin flip once CI runs four shards on one box.
    Future<void> pumpUntilPlaceholder(WidgetTester tester) async {
      for (
        var attempt = 0;
        attempt < 50 && find.byType(DivineIcon).evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
      }
    }

    // No image-cache eviction here, unlike clip_thumbnail_image_test: setUp
    // makes a fresh randomly-named temp dir per test, so a failed resolution
    // retained under this key can never be read back by another test.
    Future<void> pumpMissing(WidgetTester tester, String name) async {
      await tester.pumpWidget(
        wrap(
          StopMotionPlayer(
            frames: [
              StopMotionClipFrame(
                path: '${tempDir.path}/$name',
                duration: const Duration(milliseconds: 100),
              ),
            ],
          ),
        ),
      );
      await pumpUntilPlaceholder(tester);
    }

    // The recorder deletes a still's file on undo, discard, reset and a mode
    // switch, and a library row can outlive them, so a frame path without its
    // file is a reachable state. Decoding it through a bare Image.file throws
    // PathNotFoundException with no image-stream error listener attached,
    // which FlutterError.onError records as a *fatal* crash (#5796's class).
    testWidgets('renders the placeholder instead of throwing when a still is '
        'gone', (tester) async {
      await pumpMissing(tester, 'deleted_by_undo.png');

      expect(tester.takeException(), isNull);
      expect(find.byType(DivineIcon), findsOneWidget);
    });

    // precacheImage always registers its own error listener, so it reports
    // fatally even once the displayed image carries an errorBuilder. Pumping
    // the whole player covers both reporters.
    testWidgets('precaching a gone still reports no error', (tester) async {
      await pumpMissing(tester, 'never_written.png');

      expect(tester.takeException(), isNull);
    });
  });
}
