import 'dart:convert';
import 'dart:io';

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
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: child,
      ),
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
}
