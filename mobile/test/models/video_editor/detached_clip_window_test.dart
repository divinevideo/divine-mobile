import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/detached_clip_window.dart';

void main() {
  group('detachedClipWindow', () {
    test("keeps the slot when a placeholder holds the timeline's length", () {
      final window = detachedClipWindow(
        slotStart: const Duration(seconds: 4),
        playbackDuration: const Duration(seconds: 3),
        compositionDuration: const Duration(seconds: 10),
      );

      expect(window, (
        start: const Duration(seconds: 4),
        end: const Duration(seconds: 7),
      ));
    });

    test('pulls the last clip back inside a timeline that just lost it', () {
      // Clips of 4 s and 3 s; the 3 s tail was detached and its slot closed,
      // so the timeline is now 4 s and the slot starts exactly at its end —
      // a window nothing would ever play.
      final window = detachedClipWindow(
        slotStart: const Duration(seconds: 4),
        playbackDuration: const Duration(seconds: 3),
        compositionDuration: const Duration(seconds: 4),
      );

      expect(window, (
        start: const Duration(seconds: 1),
        end: const Duration(seconds: 4),
      ));
    });

    test('pulls a middle clip back when the tail behind it is too short', () {
      // 2 s, 5 s (detached, slot closed), 1 s: the timeline is 3 s and the
      // slot's own 5 s would run 4 s past it.
      final window = detachedClipWindow(
        slotStart: const Duration(seconds: 2),
        playbackDuration: const Duration(seconds: 5),
        compositionDuration: const Duration(seconds: 3),
      );

      expect(window, (start: Duration.zero, end: const Duration(seconds: 3)));
    });

    test('leaves a slot alone that still fits after the gap closed', () {
      // 3 s (detached, slot closed), 6 s: the 3 s window overlaps the clip
      // that moved up into the slot and needs no shifting.
      final window = detachedClipWindow(
        slotStart: Duration.zero,
        playbackDuration: const Duration(seconds: 3),
        compositionDuration: const Duration(seconds: 6),
      );

      expect(window, (start: Duration.zero, end: const Duration(seconds: 3)));
    });
  });
}
