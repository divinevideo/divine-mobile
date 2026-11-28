import 'dart:async';
import 'dart:ui' show Rect;

import 'package:divine_video_player/src/desktop/desktop_video_frame_ready.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('waitForDesktopVideoFrame', () {
    test('keeps the SDK one-pixel placeholder behind the frame wait', () async {
      final rect = _TrackedRect();
      addTearDown(rect.dispose);
      final firstFrame = Completer<void>();
      final disposed = Completer<void>();
      var rendered = false;
      final waiting = waitForDesktopVideoFrame(
        firstFrame: firstFrame.future,
        rect: rect,
        disposed: disposed.future,
      );
      unawaited(waiting.then((_) => rendered = true));

      firstFrame.complete();
      rect.value = const Rect.fromLTWH(0, 0, 1, 1);
      await pumpEventQueue();
      expect(rendered, isFalse);

      rect.value = const Rect.fromLTWH(0, 0, 1280, 720);
      await waiting;
      expect(rendered, isTrue);
      expect(rect.listening, isFalse);
    });

    test(
      'cancels and releases its listener when the output is disposed',
      () async {
        final rect = _TrackedRect();
        addTearDown(rect.dispose);
        final firstFrame = Completer<void>();
        final disposed = Completer<void>();
        final waiting = waitForDesktopVideoFrame(
          firstFrame: firstFrame.future,
          rect: rect,
          disposed: disposed.future,
        );
        final cancelled = expectLater(waiting, throwsStateError);

        disposed.complete();
        firstFrame.complete();
        await cancelled;
        expect(rect.listening, isFalse);
      },
    );
  });
}

class _TrackedRect extends ValueNotifier<Rect?> {
  _TrackedRect() : super(null);

  bool get listening => hasListeners;
}
