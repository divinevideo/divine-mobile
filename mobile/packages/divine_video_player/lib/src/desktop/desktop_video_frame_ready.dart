import 'dart:async';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

/// Waits for the desktop video output's first visible frame.
Future<void> waitForDesktopVideoFrame({
  required Future<void> firstFrame,
  required ValueListenable<Rect?> rect,
  required Future<void> disposed,
}) async {
  final visible = Completer<void>();
  void checkOutput() {
    final output = rect.value;
    if (output != null &&
        (output.width > 1 || output.height > 1) &&
        !visible.isCompleted) {
      visible.complete();
    }
  }

  rect.addListener(checkOutput);
  checkOutput();
  try {
    final ready = Future.wait<void>([
      firstFrame,
      visible.future,
    ], eagerError: true).then<void>((_) {});
    await Future.any<void>([
      ready,
      disposed.then<void>((_) {
        throw StateError('Video output was disposed before its first frame.');
      }),
    ]);
  } finally {
    rect.removeListener(checkOutput);
  }
}
