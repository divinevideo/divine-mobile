// ABOUTME: Unit tests for the pure timeline geometry helpers.
// ABOUTME: Verifies scroll-offset ↔ playback-position conversion symmetry
// ABOUTME: across single-clip, multi-clip, and empty-clip compositions.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_geometry.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

AudioEvent _audio({
  required String id,
  required Duration startTime,
  required Duration endTime,
  Duration startOffset = Duration.zero,
  double? duration,
  String? anchorClipId,
}) => AudioEvent(
  id: id,
  pubkey: '',
  createdAt: 0,
  url: '/tmp/$id.wav',
  duration: duration,
  startTime: startTime,
  endTime: endTime,
  startOffset: startOffset,
  anchorClipId: anchorClipId,
);

DivineVideoClip _clip(
  String id,
  int seconds, {
  double? speed,
  Duration trimStart = Duration.zero,
  Duration trimEnd = Duration.zero,
  ClipTransition? transition,
}) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/tmp/$id.mp4'),
  duration: Duration(seconds: seconds),
  recordedAt: DateTime(2025),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
  playbackSpeed: speed,
  trimStart: trimStart,
  trimEnd: trimEnd,
  transition: transition,
);

void main() {
  // Three-clip composition used throughout most tests:
  //   clip 0 → 2 s, clip 1 → 3 s, clip 2 → 2 s  (total 7 s)
  // At pixelsPerSecond=52 and clipGap=1 the layout is:
  //   [0…104 px] gap [105…260 px] gap [261…365 px]
  //
  // Position → offset reference table
  //   pos  0 s  → 0 * 52 + 0 gaps =   0 px
  //   pos  1 s  → 1 * 52 + 0 gaps =  52 px  (within clip 0)
  //   pos  2 s  → 2 * 52 + 1 gap  = 105 px  (start of gap after clip 0)
  //   pos  2.5s → 2.5*52 + 1 gap  = 131 px  (within clip 1)
  //   pos  5 s  → 5 * 52 + 2 gaps = 262 px  (start of gap after clip 1)
  //   pos  6 s  → 6 * 52 + 2 gaps = 314 px  (within clip 2)

  final clips = [_clip('c0', 2), _clip('c1', 3), _clip('c2', 2)];
  const pps = 52.0;
  const totalDuration = Duration(seconds: 7);

  group(timelinePositionToScrollOffset, () {
    test('returns 0 for zero position', () {
      expect(
        timelinePositionToScrollOffset(clips, Duration.zero, pps),
        equals(0.0),
      );
    });

    test('no gap offset within first clip', () {
      expect(
        timelinePositionToScrollOffset(clips, const Duration(seconds: 1), pps),
        equals(52.0),
      );
    });

    test('adds one gap at the boundary between clip 0 and clip 1', () {
      expect(
        timelinePositionToScrollOffset(clips, const Duration(seconds: 2), pps),
        equals(105.0), // 2 * 52 + 1
      );
    });

    test('one gap within clip 1', () {
      expect(
        timelinePositionToScrollOffset(
          clips,
          const Duration(milliseconds: 2500),
          pps,
        ),
        equals(131.0), // 2.5 * 52 + 1
      );
    });

    test('adds two gaps at the boundary between clip 1 and clip 2', () {
      expect(
        timelinePositionToScrollOffset(clips, const Duration(seconds: 5), pps),
        equals(262.0), // 5 * 52 + 2
      );
    });

    test('two gaps within clip 2', () {
      expect(
        timelinePositionToScrollOffset(clips, const Duration(seconds: 6), pps),
        equals(314.0), // 6 * 52 + 2
      );
    });

    test('does not add a trailing gap at total duration', () {
      expect(
        timelinePositionToScrollOffset(clips, totalDuration, pps),
        equals(366.0), // 7 * 52 + 2
      );
    });

    test('empty clip list — no gaps added', () {
      expect(
        timelinePositionToScrollOffset([], const Duration(seconds: 3), pps),
        equals(156.0), // 3 * 52
      );
    });

    test('single clip — no gaps', () {
      expect(
        timelinePositionToScrollOffset(
          [_clip('only', 10)],
          const Duration(seconds: 4),
          pps,
        ),
        equals(208.0), // 4 * 52
      );
    });
  });

  group(timelineScrollOffsetToPosition, () {
    test('returns zero for zero offset', () {
      expect(
        timelineScrollOffsetToPosition(clips, 0.0, pps, totalDuration),
        equals(Duration.zero),
      );
    });

    test('no gap correction within first clip', () {
      expect(
        timelineScrollOffsetToPosition(clips, 52.0, pps, totalDuration),
        equals(const Duration(seconds: 1)),
      );
    });

    test('subtracts one gap at clip 0/1 boundary', () {
      expect(
        timelineScrollOffsetToPosition(clips, 105.0, pps, totalDuration),
        equals(const Duration(seconds: 2)),
      );
    });

    test('maps offsets inside the clip 0/1 gap to the shared boundary', () {
      expect(
        timelineScrollOffsetToPosition(clips, 104.5, pps, totalDuration),
        equals(const Duration(seconds: 2)),
      );
    });

    test('subtracts one gap within clip 1', () {
      expect(
        timelineScrollOffsetToPosition(clips, 131.0, pps, totalDuration),
        equals(const Duration(milliseconds: 2500)),
      );
    });

    test('subtracts two gaps at clip 1/2 boundary', () {
      expect(
        timelineScrollOffsetToPosition(clips, 262.0, pps, totalDuration),
        equals(const Duration(seconds: 5)),
      );
    });

    test('maps offsets inside the clip 1/2 gap to the shared boundary', () {
      expect(
        timelineScrollOffsetToPosition(clips, 261.5, pps, totalDuration),
        equals(const Duration(seconds: 5)),
      );
    });

    test('subtracts two gaps within clip 2', () {
      expect(
        timelineScrollOffsetToPosition(clips, 314.0, pps, totalDuration),
        equals(const Duration(seconds: 6)),
      );
    });

    test('clamps negative offsets to Duration.zero', () {
      expect(
        timelineScrollOffsetToPosition(clips, -10.0, pps, totalDuration),
        equals(Duration.zero),
      );
    });

    test('clamps offsets beyond end to totalDuration', () {
      expect(
        timelineScrollOffsetToPosition(clips, 99999.0, pps, totalDuration),
        equals(totalDuration),
      );
    });

    test('maps the exact end offset back to total duration', () {
      expect(
        timelineScrollOffsetToPosition(clips, 366.0, pps, totalDuration),
        equals(totalDuration),
      );
    });

    test('empty clip list — no gap subtraction', () {
      expect(
        timelineScrollOffsetToPosition(
          [],
          156.0,
          pps,
          const Duration(seconds: 10),
        ),
        equals(const Duration(seconds: 3)),
      );
    });
  });

  group(
    'round-trip: scrollOffsetToPosition ∘ positionToScrollOffset == id',
    () {
      for (final pos in [
        Duration.zero,
        const Duration(seconds: 1),
        const Duration(seconds: 2),
        const Duration(milliseconds: 2500),
        const Duration(seconds: 5),
        const Duration(seconds: 6),
        totalDuration,
      ]) {
        test('position $pos survives round-trip', () {
          final offset = timelinePositionToScrollOffset(clips, pos, pps);
          final recovered = timelineScrollOffsetToPosition(
            clips,
            offset,
            pps,
            totalDuration,
          );
          expect(recovered, equals(pos));
        });
      }
    },
  );

  // Regression for the pinch-zoom drift fix in `_updatePinchZoom`.
  //
  // Old bug: zoom preserved scroll by `_scrollController.offset * ratio`,
  // which over-shoots by `clipsPassed × clipGap × (ratio - 1)` px once the
  // playhead is past clip 0 (gaps stay 1 px, they don't scale with pps).
  //
  // New behavior re-anchors through the gap-aware helpers: derive the
  // current playback position at the old pps, then map it back to a scroll
  // offset at the new pps. The composite position must remain stable.
  group('pinch-zoom anchoring keeps playhead position stable', () {
    const newPps = 104.0; // 2× zoom-in

    for (final pos in [
      const Duration(milliseconds: 2500), // inside clip 1
      const Duration(seconds: 5), // boundary clip 1/2
      const Duration(seconds: 6), // inside clip 2
    ]) {
      test('position $pos stays centered across pps change', () {
        // Simulate the playhead sitting at `pos` at the old pps.
        final oldOffset = timelinePositionToScrollOffset(clips, pos, pps);

        // What the new gap-aware pinch logic would jump to:
        final anchorPosition = timelineScrollOffsetToPosition(
          clips,
          oldOffset,
          pps,
          totalDuration,
        );
        final newOffset = timelinePositionToScrollOffset(
          clips,
          anchorPosition,
          newPps,
        );

        // The recovered position at the new pps must match the original.
        final recovered = timelineScrollOffsetToPosition(
          clips,
          newOffset,
          newPps,
          totalDuration,
        );
        expect(recovered, equals(pos));

        // Sanity: the naive `oldOffset * ratio` path drifts (proving the
        // gap-aware re-anchor is doing real work past clip 0).
        const ratio = newPps / pps;
        final naiveOffset = oldOffset * ratio;
        expect(
          naiveOffset,
          isNot(equals(newOffset)),
          reason:
              'Past clip 0 the naive scroll-rescale must differ from the '
              'gap-aware anchoring; otherwise the regression would be '
              'silently lost.',
        );
      });
    }
  });

  group(clipAtTimelinePosition, () {
    test('resolves the clip whose playback span holds the position', () {
      expect(
        clipAtTimelinePosition(clips, const Duration(seconds: 1)),
        clips[0],
      );
      expect(
        clipAtTimelinePosition(clips, const Duration(milliseconds: 2500)),
        clips[1],
      );
      expect(
        clipAtTimelinePosition(clips, const Duration(seconds: 6)),
        clips[2],
      );
    });

    test('a boundary belongs to the clip that starts there', () {
      expect(
        clipAtTimelinePosition(clips, const Duration(seconds: 2)),
        clips[1],
      );
    });

    test('walks in playback time, so speed and trims count', () {
      // c0 plays 1s of its 2s at 2×, c1 has 1s trimmed off: 0.5s + 2s.
      final timed = [
        _clip('c0', 2, speed: 2, trimStart: const Duration(seconds: 1)),
        _clip('c1', 3, trimEnd: const Duration(seconds: 1)),
        _clip('c2', 2),
      ];

      expect(
        clipAtTimelinePosition(timed, const Duration(milliseconds: 400)),
        timed[0],
      );
      expect(
        clipAtTimelinePosition(timed, const Duration(milliseconds: 600)),
        timed[1],
      );
      expect(
        clipAtTimelinePosition(timed, const Duration(milliseconds: 2600)),
        timed[2],
      );
    });

    test('the last clip absorbs a position past the composition end', () {
      expect(
        clipAtTimelinePosition(clips, const Duration(seconds: 9)),
        clips[2],
      );
    });

    test('is null for an empty composition', () {
      expect(clipAtTimelinePosition(const [], Duration.zero), isNull);
    });
  });

  group(clipSourcePositionToTimelinePosition, () {
    test(
      'maps a second-clip start trim handle to the clip start in timeline',
      () {
        final trimClips = [
          _clip('clip-1', 10),
          _clip('clip-2', 10, trimStart: const Duration(seconds: 2)),
        ];

        expect(
          clipSourcePositionToTimelinePosition(
            trimClips,
            clipId: 'clip-2',
            sourcePosition: const Duration(seconds: 2),
          ),
          equals(const Duration(seconds: 10)),
        );
      },
    );

    test('keeps second-clip trim preview outside an early overlay range', () {
      final trimClips = [
        _clip('clip-1', 10),
        _clip('clip-2', 10, trimStart: const Duration(seconds: 1)),
      ];

      final position = clipSourcePositionToTimelinePosition(
        trimClips,
        clipId: 'clip-2',
        sourcePosition: const Duration(seconds: 1),
      );

      expect(position, equals(const Duration(seconds: 10)));
      expect(position, greaterThan(const Duration(seconds: 5)));
    });

    test('maps positions inside a trimmed target clip', () {
      final trimClips = [
        _clip('clip-1', 10),
        _clip('clip-2', 10, trimStart: const Duration(seconds: 2)),
      ];

      expect(
        clipSourcePositionToTimelinePosition(
          trimClips,
          clipId: 'clip-2',
          sourcePosition: const Duration(seconds: 4),
        ),
        equals(const Duration(seconds: 12)),
      );
    });

    test('respects playback speed for preceding and target clips', () {
      final trimClips = [
        _clip('clip-1', 10, speed: 2.0),
        _clip('clip-2', 10, speed: 2.0, trimStart: const Duration(seconds: 2)),
      ];

      expect(
        clipSourcePositionToTimelinePosition(
          trimClips,
          clipId: 'clip-2',
          sourcePosition: const Duration(seconds: 6),
        ),
        equals(const Duration(seconds: 7)),
      );
    });

    test('returns null when source position is outside trimmed range', () {
      final trimClips = [
        _clip('clip-1', 10),
        _clip('clip-2', 10, trimStart: const Duration(seconds: 2)),
      ];

      expect(
        clipSourcePositionToTimelinePosition(
          trimClips,
          clipId: 'clip-2',
          sourcePosition: const Duration(seconds: 1),
        ),
        isNull,
      );
    });

    test('returns null for an unknown clip id', () {
      expect(
        clipSourcePositionToTimelinePosition(
          clips,
          clipId: 'missing',
          sourcePosition: Duration.zero,
        ),
        isNull,
      );
    });
  });

  group(rebaseTimelineMarkersForClipState, () {
    test('keeps a marker attached to the same clip source position', () {
      final oldClips = [
        _clip('a', 3),
        _clip('b', 5),
        _clip('c', 2),
        _clip('d', 4),
      ];
      final newClips = [
        _clip('d', 4),
        _clip('b', 5),
        _clip('a', 3),
        _clip('c', 2),
      ];

      expect(
        rebaseTimelineMarkersForClipState(
          oldClips: oldClips,
          newClips: newClips,
          markers: [const Duration(seconds: 5)],
        ),
        equals([const Duration(seconds: 6)]),
      );
    });

    test('sorts rebased markers from multiple clips', () {
      final oldClips = [_clip('a', 3), _clip('b', 5), _clip('c', 2)];
      final newClips = [_clip('c', 2), _clip('a', 3), _clip('b', 5)];

      expect(
        rebaseTimelineMarkersForClipState(
          oldClips: oldClips,
          newClips: newClips,
          markers: [const Duration(seconds: 4), const Duration(seconds: 9)],
        ),
        equals([const Duration(seconds: 1), const Duration(seconds: 6)]),
      );
    });

    test('respects trimmed and speed-adjusted playback duration', () {
      final oldClips = [
        _clip('intro', 10, speed: 2.0),
        _clip('target', 10, speed: 2.0, trimStart: const Duration(seconds: 2)),
      ];
      final newClips = [
        _clip('target', 10, speed: 2.0, trimStart: const Duration(seconds: 2)),
        _clip('intro', 10, speed: 2.0),
      ];

      expect(
        rebaseTimelineMarkersForClipState(
          oldClips: oldClips,
          newClips: newClips,
          markers: [const Duration(seconds: 6)],
        ),
        equals([const Duration(seconds: 1)]),
      );
    });

    test('anchors an exact internal boundary to the following clip', () {
      final oldClips = [_clip('a', 3), _clip('b', 5), _clip('c', 2)];
      final newClips = [_clip('c', 2), _clip('b', 5), _clip('a', 3)];

      expect(
        rebaseTimelineMarkersForClipState(
          oldClips: oldClips,
          newClips: newClips,
          markers: [const Duration(seconds: 3)],
        ),
        equals([const Duration(seconds: 2)]),
      );
    });

    test('drops a marker when its source position is trimmed from the end', () {
      final oldClips = [_clip('clip', 6)];
      final newClips = [_clip('clip', 6, trimEnd: const Duration(seconds: 3))];

      expect(
        rebaseTimelineMarkersForClipState(
          oldClips: oldClips,
          newClips: newClips,
          markers: [const Duration(seconds: 5)],
        ),
        isEmpty,
      );
    });

    test(
      'drops a marker when its source position is trimmed from the start',
      () {
        final oldClips = [_clip('clip', 6)];
        final newClips = [
          _clip('clip', 6, trimStart: const Duration(seconds: 3)),
        ];

        expect(
          rebaseTimelineMarkersForClipState(
            oldClips: oldClips,
            newClips: newClips,
            markers: [const Duration(seconds: 2)],
          ),
          isEmpty,
        );
      },
    );

    test('moves a visible source marker when trimStart advances', () {
      final oldClips = [_clip('clip', 6)];
      final newClips = [
        _clip('clip', 6, trimStart: const Duration(seconds: 3)),
      ];

      expect(
        rebaseTimelineMarkersForClipState(
          oldClips: oldClips,
          newClips: newClips,
          markers: [const Duration(seconds: 5)],
        ),
        equals([const Duration(seconds: 2)]),
      );
    });

    test('keeps marker anchored to source time across speed changes', () {
      final oldClips = [_clip('clip', 10)];
      final newClips = [_clip('clip', 10, speed: 2.0)];

      expect(
        rebaseTimelineMarkersForClipState(
          oldClips: oldClips,
          newClips: newClips,
          markers: [const Duration(seconds: 6)],
        ),
        equals([const Duration(seconds: 3)]),
      );
    });

    test('shifts later markers when a preceding clip speed changes', () {
      final oldClips = [_clip('intro', 4), _clip('target', 6)];
      final newClips = [_clip('intro', 4, speed: 2.0), _clip('target', 6)];

      expect(
        rebaseTimelineMarkersForClipState(
          oldClips: oldClips,
          newClips: newClips,
          markers: [const Duration(seconds: 6)],
        ),
        equals([const Duration(seconds: 4)]),
      );
    });

    test('drops markers whose source clip no longer exists', () {
      final oldClips = [_clip('a', 3), _clip('b', 5)];
      final newClips = [_clip('a', 3)];

      expect(
        rebaseTimelineMarkersForClipState(
          oldClips: oldClips,
          newClips: newClips,
          markers: [const Duration(seconds: 4)],
        ),
        isEmpty,
      );
    });

    test('shifts later markers earlier when a preceding clip is removed', () {
      final oldClips = [_clip('a', 3), _clip('b', 5), _clip('c', 4)];
      final newClips = [_clip('a', 3), _clip('c', 4)];

      expect(
        rebaseTimelineMarkersForClipState(
          oldClips: oldClips,
          newClips: newClips,
          markers: [const Duration(seconds: 10)],
        ),
        equals([const Duration(seconds: 5)]),
      );
    });

    test('shifts later markers right when a copy is inserted mid-timeline', () {
      // Mirrors the clip-duplication call site: the copy lands directly
      // after its source, so markers on later clips move right by the
      // copy's duration while earlier markers stay put.
      final oldClips = [_clip('a', 3), _clip('b', 5)];
      final newClips = [_clip('a', 3), _clip('a_copy', 3), _clip('b', 5)];

      expect(
        rebaseTimelineMarkersForClipState(
          oldClips: oldClips,
          newClips: newClips,
          markers: [const Duration(seconds: 1), const Duration(seconds: 6)],
        ),
        equals([const Duration(seconds: 1), const Duration(seconds: 9)]),
      );
    });

    test('keeps earlier markers in place when a clip is appended', () {
      // A clip added at the end leaves every existing clip's start time
      // alone, so markers on them must not move. The duplicate call site
      // now inserts after the source; see the mid-timeline case above.
      final oldClips = [_clip('a', 3), _clip('b', 5)];
      final newClips = [_clip('a', 3), _clip('b', 5), _clip('a_copy', 3)];

      expect(
        rebaseTimelineMarkersForClipState(
          oldClips: oldClips,
          newClips: newClips,
          markers: [const Duration(seconds: 1), const Duration(seconds: 6)],
        ),
        equals([const Duration(seconds: 1), const Duration(seconds: 6)]),
      );
    });

    test('clamps a marker past the timeline end to the last clip end', () {
      final oldClips = [_clip('a', 3), _clip('b', 5)];
      final newClips = [_clip('a', 3), _clip('b', 5)];

      expect(
        rebaseTimelineMarkersForClipState(
          oldClips: oldClips,
          newClips: newClips,
          markers: [const Duration(seconds: 20)],
        ),
        equals([const Duration(seconds: 8)]),
      );
    });
  });

  group('DivineVideoClip.playbackDuration', () {
    test('null speed → same as trimmedDuration', () {
      final clip = _clip('a', 10);
      expect(clip.playbackDuration, equals(clip.trimmedDuration));
    });

    test('speed 1.0 → same as trimmedDuration', () {
      final clip = _clip('a', 10, speed: 1.0);
      expect(clip.playbackDuration, equals(clip.trimmedDuration));
    });

    test('speed 2.0 → half of trimmedDuration', () {
      final clip = _clip('a', 10, speed: 2.0);
      expect(clip.playbackDuration, equals(const Duration(seconds: 5)));
    });

    test('speed 0.5 → double of trimmedDuration', () {
      final clip = _clip('a', 10, speed: 0.5);
      expect(clip.playbackDuration, equals(const Duration(seconds: 20)));
    });

    test('playbackDurationInSeconds matches playbackDuration', () {
      final clip = _clip('a', 10, speed: 2.0);
      expect(clip.playbackDurationInSeconds, equals(5.0));
    });
  });

  group('speed-aware geometry', () {
    // Two-clip composition: clip 0 is 10 s at 2×speed (→ 5 s wide),
    // clip 1 is 4 s at 1×speed (→ 4 s wide).  Total playback = 9 s.
    final speedClips = [_clip('fast', 10, speed: 2.0), _clip('normal', 4)];
    const speedPps = 52.0;
    const speedTotal = Duration(seconds: 9);

    test('positionToOffset: 0 s → 0 px', () {
      expect(
        timelinePositionToScrollOffset(speedClips, Duration.zero, speedPps),
        equals(0.0),
      );
    });

    test('positionToOffset: 5 s (end of fast clip) → 261 px (5*52 + gap)', () {
      // 5 s * 52 pps = 260, + 1 gap = 261
      expect(
        timelinePositionToScrollOffset(
          speedClips,
          const Duration(seconds: 5),
          speedPps,
        ),
        equals(261.0),
      );
    });

    test('positionToOffset: 2.5 s (mid fast clip) → 130 px (no gap yet)', () {
      expect(
        timelinePositionToScrollOffset(
          speedClips,
          const Duration(milliseconds: 2500),
          speedPps,
        ),
        equals(130.0),
      );
    });

    test('positionToOffset: 7 s (mid normal clip) → 365 px', () {
      // 7 s * 52 + 1 gap = 364 + 1 = 365
      expect(
        timelinePositionToScrollOffset(
          speedClips,
          const Duration(seconds: 7),
          speedPps,
        ),
        equals(365.0),
      );
    });

    test('round-trip at 5 s boundary with speed', () {
      const pos = Duration(seconds: 5);
      final offset = timelinePositionToScrollOffset(speedClips, pos, speedPps);
      final recovered = timelineScrollOffsetToPosition(
        speedClips,
        offset,
        speedPps,
        speedTotal,
      );
      expect(recovered, equals(pos));
    });

    test('round-trip at 7 s with speed', () {
      const pos = Duration(seconds: 7);
      final offset = timelinePositionToScrollOffset(speedClips, pos, speedPps);
      final recovered = timelineScrollOffsetToPosition(
        speedClips,
        offset,
        speedPps,
        speedTotal,
      );
      expect(recovered, equals(pos));
    });
  });

  // A loop transition draws the first/last clips shortened by the wrap-consumed
  // head/tail and appends a blend seam at the end (see [LoopWrapDisplay]). The
  // playhead position is on that display axis, so the scroll mappings must count
  // clip-gap boundaries on the display axis too — otherwise the playhead drifts
  // from the drawn strip by a gap width near each boundary.
  //
  //   clips: c0 = 4 s, c1 = 4 s with a 500 ms dissolve loop wrap
  //   → consumed = 1 s per side, display c0 = 3 s, c1 = 3 s, seam = 1.5 s
  //   display layout @ pps 52, clipGap 1:
  //     [0…156 px] gap [157…313 px]  seam [313…391 px]  (total 7.5 s → 390 px)
  group('loop-wrap-aware geometry', () {
    const dissolve = ClipTransition(type: ClipTransitionType.dissolve);
    final wrapClips = [
      _clip('w0', 4),
      _clip(
        'w1',
        4,
        transition: dissolve.copyWith(
          duration: const Duration(milliseconds: 500),
        ),
      ),
    ];
    final wrap = LoopWrapDisplay.fromClips(wrapClips);
    const displayTotal = Duration(milliseconds: 7500);
    const clipGap = 1.0;

    test('LoopWrapDisplay carries the expected consumed span', () {
      expect(wrap.consumedPerSide, equals(const Duration(seconds: 1)));
      expect(wrap.displayTotal(wrapClips), equals(displayTotal));
    });

    test('positionToOffset counts the gap on the display boundary', () {
      // 3.5 s is 0.5 s into c1 on the display axis (c1 starts at display 3 s),
      // so the gap after c0 is already crossed → +1 gap.
      const pos = Duration(milliseconds: 3500);
      expect(
        timelinePositionToScrollOffset(wrapClips, pos, pps, wrap: wrap),
        equals(3.5 * pps + clipGap),
      );
    });

    test('positionToOffset without the wrap misses the display gap', () {
      // Without the wrap the raw c0 duration (4 s) still contains 3.5 s, so the
      // gap is not counted — the drift the wrap parameter fixes.
      const pos = Duration(milliseconds: 3500);
      expect(
        timelinePositionToScrollOffset(wrapClips, pos, pps),
        equals(3.5 * pps),
      );
    });

    test('positionToOffset maps the seam region past every clip gap', () {
      // 6.5 s is 0.5 s into the seam (bodies end at display 6 s); one gap sits
      // before it (between c0 and c1).
      const pos = Duration(milliseconds: 6500);
      expect(
        timelinePositionToScrollOffset(wrapClips, pos, pps, wrap: wrap),
        equals(6.5 * pps + clipGap),
      );
    });

    test('offsetToPosition round-trips a display-axis position', () {
      const pos = Duration(milliseconds: 3500);
      final offset = timelinePositionToScrollOffset(
        wrapClips,
        pos,
        pps,
        wrap: wrap,
      );
      expect(
        timelineScrollOffsetToPosition(
          wrapClips,
          offset,
          pps,
          displayTotal,
          wrap: wrap,
        ),
        equals(pos),
      );
    });

    test('offsetToPosition clamps to the shortened display total', () {
      expect(
        timelineScrollOffsetToPosition(
          wrapClips,
          99999,
          pps,
          displayTotal,
          wrap: wrap,
        ),
        equals(displayTotal),
      );
    });
  });

  // Edge-based gap-aware converters used to position overlay layers
  // (text/audio) against the gap-aware clip strip. Overlays carry a
  // pure-ms cumulative clip-edge list `[0, e1, e2, …]`.
  //
  //   edges [0, 2000, 5000, 7000] @ pps 52, clipGap 1
  //   ms 2000 → 2*52 + 1 gap  = 105 px (boundary after clip 0)
  //   ms 5000 → 5*52 + 2 gaps = 262 px (boundary after clip 1)
  //   ms 7000 → 7*52 + 2 gaps = 366 px (final edge, no trailing gap)
  group(timelineMsToOverlayOffset, () {
    const edges = [0, 2000, 5000, 7000];

    test('0 ms → 0 px', () {
      expect(timelineMsToOverlayOffset(edges, 0, pps), equals(0.0));
    });

    test('within first clip — no gap', () {
      expect(timelineMsToOverlayOffset(edges, 1000, pps), equals(52.0));
    });

    test('first internal boundary adds one gap', () {
      expect(timelineMsToOverlayOffset(edges, 2000, pps), equals(105.0));
    });

    test('second internal boundary adds two gaps', () {
      expect(timelineMsToOverlayOffset(edges, 5000, pps), equals(262.0));
    });

    test('final edge does not add a trailing gap', () {
      expect(timelineMsToOverlayOffset(edges, 7000, pps), equals(366.0));
    });

    test('single-clip edges fall back to gap-free', () {
      expect(
        timelineMsToOverlayOffset(const [0, 10000], 4000, pps),
        equals(208.0),
      );
    });

    test('empty/degenerate edges fall back to gap-free', () {
      expect(timelineMsToOverlayOffset(const [0], 3000, pps), equals(156.0));
    });
  });

  group(timelineOverlayOffsetToMs, () {
    const edges = [0, 2000, 5000, 7000];
    const totalMs = 7000;

    test('0 px → 0 ms', () {
      expect(timelineOverlayOffsetToMs(edges, 0, pps, totalMs), equals(0));
    });

    test('within first clip — no gap correction', () {
      expect(timelineOverlayOffsetToMs(edges, 52, pps, totalMs), equals(1000));
    });

    test('subtracts one gap at first boundary', () {
      expect(timelineOverlayOffsetToMs(edges, 105, pps, totalMs), equals(2000));
    });

    test('subtracts two gaps at second boundary', () {
      expect(timelineOverlayOffsetToMs(edges, 262, pps, totalMs), equals(5000));
    });

    test('offset inside a gap clamps to the shared boundary', () {
      expect(
        timelineOverlayOffsetToMs(edges, 104.5, pps, totalMs),
        equals(2000),
      );
    });

    test('clamps offsets beyond the end to totalMs', () {
      expect(
        timelineOverlayOffsetToMs(edges, 99999, pps, totalMs),
        equals(totalMs),
      );
    });

    for (final ms in [0, 1000, 2000, 5000, 7000]) {
      test('round-trip ms $ms survives offset conversion', () {
        final offset = timelineMsToOverlayOffset(edges, ms, pps);
        expect(
          timelineOverlayOffsetToMs(edges, offset, pps, totalMs),
          equals(ms),
        );
      });
    }
  });

  group(audioLeftTrimResult, () {
    test('advances the source offset when the left handle moves right', () {
      final track = _audio(
        id: 'sound',
        startTime: const Duration(seconds: 10),
        endTime: const Duration(seconds: 20),
      );

      final result = audioLeftTrimResult(
        track,
        newStartTime: const Duration(seconds: 13),
      );

      expect(result.startOffset, const Duration(seconds: 3));
      expect(result.anchorStillValid, isTrue);
    });

    test('clears the anchor when revealing before the audio source head', () {
      final track = _audio(
        id: 'sound',
        startTime: const Duration(seconds: 13),
        endTime: const Duration(seconds: 20),
        startOffset: const Duration(seconds: 2),
      );

      final result = audioLeftTrimResult(
        track,
        newStartTime: const Duration(seconds: 10),
      );

      expect(result.startOffset, Duration.zero);
      expect(result.anchorStillValid, isFalse);
    });

    test(
      'clears the anchor when trimming beyond the audio source duration',
      () {
        final track = _audio(
          id: 'sound',
          startTime: const Duration(seconds: 10),
          endTime: const Duration(seconds: 20),
          startOffset: const Duration(seconds: 8),
          duration: 10,
        );

        final result = audioLeftTrimResult(
          track,
          newStartTime: const Duration(seconds: 13),
        );

        expect(result.startOffset, const Duration(seconds: 10));
        expect(result.anchorStillValid, isFalse);
      },
    );
  });

  group(rebaseAnchoredAudioForClipState, () {
    // Two clips, both 10 s, no trim. clip-b starts at timeline 10 s.
    // An anchored track covers clip-b exactly: 10–20 s, startOffset 0.
    List<DivineVideoClip> baseClips() => [_clip('a', 10), _clip('b', 10)];

    test('shifts the anchored track left when its clip is trimmed left', () {
      // Trim clip-b's left edge by 3 s. The audio keeps its full content and
      // span, translating left so its tail stays in sync (J-Cut).
      final clips = [
        _clip('a', 10),
        _clip('b', 10, trimStart: const Duration(seconds: 3)),
      ];
      final track = _audio(
        id: 'b-audio',
        startTime: const Duration(seconds: 10),
        endTime: const Duration(seconds: 20),
        anchorClipId: 'b',
      );

      final result = rebaseAnchoredAudioForClipState(clips, [track]);

      expect(result.single.startTime, const Duration(seconds: 7));
      expect(result.single.endTime, const Duration(seconds: 17));
      // Content (startOffset) and span are preserved.
      expect(result.single.startOffset, Duration.zero);
      expect(
        result.single.endTime! - result.single.startTime,
        const Duration(seconds: 10),
      );
    });

    test('keeps the anchored track in place when its clip is right-trimmed '
        '(L-Cut overhang into the next clip)', () {
      // [a:10][b:10][c:10]. clip-b right-trimmed by 3 s → b occupies
      // timeline 10–17 s, c ripples to 17–27 s. The anchored audio must stay
      // put so its tail (…20 s) trails over clip-c's video.
      final clips = [
        _clip('a', 10),
        _clip('b', 10, trimEnd: const Duration(seconds: 3)),
        _clip('c', 10),
      ];
      final track = _audio(
        id: 'b-audio',
        startTime: const Duration(seconds: 10),
        endTime: const Duration(seconds: 20),
        anchorClipId: 'b',
      );

      final result = rebaseAnchoredAudioForClipState(clips, [track]);

      // Audio does not move on a right-trim.
      expect(result.single.startTime, const Duration(seconds: 10));
      expect(result.single.endTime, const Duration(seconds: 20));
      // Its end now overhangs clip-b's trimmed end (17 s) into clip-c.
      expect(result.single.endTime, greaterThan(const Duration(seconds: 17)));
    });

    test('ripples a later anchored track when an earlier clip is trimmed', () {
      // clip-a trimmed left by 4 s → total shrinks, clip-b ripples to start
      // at timeline 6 s. clip-b's anchored audio must follow.
      final clips = [
        _clip('a', 10, trimStart: const Duration(seconds: 4)),
        _clip('b', 10),
      ];
      final track = _audio(
        id: 'b-audio',
        startTime: const Duration(seconds: 10),
        endTime: const Duration(seconds: 20),
        anchorClipId: 'b',
      );

      final result = rebaseAnchoredAudioForClipState(clips, [track]);

      expect(result.single.startTime, const Duration(seconds: 6));
      expect(result.single.endTime, const Duration(seconds: 16));
    });

    test(
      'uses playback-time starts when an earlier clip has playbackSpeed',
      () {
        // clip-a is 4 s source at 0.5x, so it occupies 8 s on the timeline.
        // clip-b's anchored audio follows that playback-time start.
        final clips = [_clip('a', 4, speed: 0.5), _clip('b', 10)];
        final track = _audio(
          id: 'b-audio',
          startTime: const Duration(seconds: 10),
          endTime: const Duration(seconds: 20),
          anchorClipId: 'b',
        );

        final result = rebaseAnchoredAudioForClipState(clips, [track]);

        expect(result.single.startTime, const Duration(seconds: 8));
        expect(result.single.endTime, const Duration(seconds: 18));
      },
    );

    test('uses audio-file time when the anchored clip has playbackSpeed', () {
      // The track was extracted from clip-b when trimStart was 3 s at 2x:
      // source offset 3 s maps to audio-file offset 1.5 s. Advancing the
      // clip trim to 4 s should create a 0.5 s audio lead, not a 1 s lead.
      final clips = [
        _clip('a', 10),
        _clip('b', 10, speed: 2.0, trimStart: const Duration(seconds: 4)),
      ];
      final track = _audio(
        id: 'b-audio',
        startTime: const Duration(seconds: 10),
        endTime: const Duration(milliseconds: 13500),
        startOffset: const Duration(milliseconds: 1500),
        anchorClipId: 'b',
      );

      final result = rebaseAnchoredAudioForClipState(clips, [track]);

      expect(result.single.startTime, const Duration(milliseconds: 9500));
      expect(result.single.endTime, const Duration(seconds: 13));
      expect(result.single.startOffset, const Duration(milliseconds: 1500));
      expect(
        result.single.endTime! - result.single.startTime,
        const Duration(milliseconds: 3500),
      );
    });

    test('preserves a user-shortened span (L-Cut) while translating', () {
      // User right-trimmed the audio to 10–15 s (5 s span). A later clip
      // edit must keep that span, only translating it.
      final clips = [
        _clip('a', 10),
        _clip('b', 10, trimStart: const Duration(seconds: 3)),
      ];
      final track = _audio(
        id: 'b-audio',
        startTime: const Duration(seconds: 10),
        endTime: const Duration(seconds: 15),
        anchorClipId: 'b',
      );

      final result = rebaseAnchoredAudioForClipState(clips, [track]);

      expect(result.single.startTime, const Duration(seconds: 7));
      expect(result.single.endTime, const Duration(seconds: 12));
    });

    test('clips impossible pre-roll for an anchored first clip', () {
      // clip-a is first (timeline start 0). Trimming it left by 3 s cannot
      // produce a lead, so the start clamps to zero and the lost pre-roll is
      // consumed from the audio source offset instead.
      final clips = [
        _clip('a', 10, trimStart: const Duration(seconds: 3)),
        _clip('b', 10),
      ];
      final track = _audio(
        id: 'a-audio',
        startTime: Duration.zero,
        endTime: const Duration(seconds: 10),
        anchorClipId: 'a',
      );

      final result = rebaseAnchoredAudioForClipState(clips, [track]);

      expect(result.single.startTime, Duration.zero);
      expect(result.single.startOffset, const Duration(seconds: 3));
      expect(result.single.endTime, const Duration(seconds: 7));
      expect(
        result.single.endTime! - result.single.startTime,
        const Duration(seconds: 7),
      );
    });

    test('leaves an un-anchored track untouched', () {
      final clips = [
        _clip('a', 10),
        _clip('b', 10, trimStart: const Duration(seconds: 3)),
      ];
      final tracks = [
        _audio(
          id: 'free',
          startTime: const Duration(seconds: 10),
          endTime: const Duration(seconds: 20),
        ),
      ];

      final result = rebaseAnchoredAudioForClipState(clips, tracks);

      // No anchored track moved → original list instance returned.
      expect(identical(result, tracks), isTrue);
      expect(result.single.startTime, const Duration(seconds: 10));
      expect(result.single.endTime, const Duration(seconds: 20));
    });

    test('leaves a track whose anchor clip was removed untouched', () {
      final track = _audio(
        id: 'orphan',
        startTime: const Duration(seconds: 10),
        endTime: const Duration(seconds: 20),
        anchorClipId: 'gone',
      );

      final result = rebaseAnchoredAudioForClipState(baseClips(), [track]);

      expect(result.single.startTime, const Duration(seconds: 10));
      expect(result.single.endTime, const Duration(seconds: 20));
    });

    test(
      'left-trimmed anchored audio is not repositioned by an unrelated clip edit',
      () {
        // The sound began aligned with clip-b at 10–20 s, then the user moved
        // its left trim handle to 13 s. The trim consumes 3 s of source audio,
        // so the anchor invariant still holds after any unrelated clip edit.
        final clips = [_clip('a', 10), _clip('b', 10), _clip('copy', 10)];
        final track = _audio(
          id: 'b-audio',
          startTime: const Duration(seconds: 13),
          endTime: const Duration(seconds: 20),
          startOffset: const Duration(seconds: 3),
          anchorClipId: 'b',
        );
        final tracks = [track];

        final result = rebaseAnchoredAudioForClipState(clips, tracks);

        expect(identical(result, tracks), isTrue);
        expect(result.single.startTime, const Duration(seconds: 13));
        expect(result.single.endTime, const Duration(seconds: 20));
        expect(result.single.startOffset, const Duration(seconds: 3));
      },
    );

    test(
      'detached clamped left-trim audio is not repositioned by a later clip edit',
      () {
        final clips = [_clip('a', 10), _clip('b', 10), _clip('copy', 10)];
        final track = _audio(
          id: 'b-audio',
          startTime: const Duration(seconds: 9),
          endTime: const Duration(seconds: 19),
        );
        final tracks = [track];

        final result = rebaseAnchoredAudioForClipState(clips, tracks);

        expect(identical(result, tracks), isTrue);
        expect(result.single.startTime, const Duration(seconds: 9));
        expect(result.single.endTime, const Duration(seconds: 19));
      },
    );

    test('returns the same list instance when nothing moves', () {
      // Anchored track already aligned with its un-edited clip.
      final tracks = [
        _audio(
          id: 'b-audio',
          startTime: const Duration(seconds: 10),
          endTime: const Duration(seconds: 20),
          anchorClipId: 'b',
        ),
      ];

      final result = rebaseAnchoredAudioForClipState(baseClips(), tracks);

      expect(identical(result, tracks), isTrue);
    });

    test('returns the same empty list instance', () {
      const tracks = <AudioEvent>[];
      expect(
        identical(rebaseAnchoredAudioForClipState(baseClips(), tracks), tracks),
        isTrue,
      );
    });
  });

  group(growAudioToCompositionEnd, () {
    // The #6401 shape: nine stills at a one-frame hold (300ms) with a
    // sound clamped to that end, then a hold change stretching them to 6.6s.
    const shortComposition = Duration(milliseconds: 300);
    const longComposition = Duration(milliseconds: 6600);
    const maxDuration = Duration(seconds: 6, milliseconds: 300);

    List<AudioEvent> grow(
      List<AudioEvent> tracks, {
      Duration previousDuration = shortComposition,
      Duration duration = longComposition,
    }) => growAudioToCompositionEnd(
      tracks,
      previousDuration: previousDuration,
      duration: duration,
      maxDuration: maxDuration,
    );

    test('stretches a window that ran to the old composition end', () {
      final track = _audio(
        id: 'sound',
        startTime: Duration.zero,
        endTime: shortComposition,
        duration: 30,
      );

      expect(grow([track]).single.endTime, maxDuration);
    });

    test('follows the end across the millisecond the window persists at', () {
      // Nine such holds are 300006µs, but the window round-trips through
      // editor history as whole milliseconds. Comparing it against the exact
      // composition end would read the truncation as a deliberate trim.
      final track = _audio(
        id: 'sound',
        startTime: Duration.zero,
        endTime: const Duration(milliseconds: 300),
        duration: 30,
      );

      expect(
        grow(
          [track],
          previousDuration: const Duration(microseconds: 300006),
        ).single.endTime,
        maxDuration,
      );
    });

    test('stops where the sound runs out of source content', () {
      // A 2s sound cannot cover the 6.375s composition.
      final track = _audio(
        id: 'sound',
        startTime: Duration.zero,
        endTime: shortComposition,
        duration: 2,
      );

      expect(grow([track]).single.endTime, const Duration(seconds: 2));
    });

    test('measures the remaining source from the track start and offset', () {
      // A 2s sound, 0.5s of it already trimmed off the head, dropped 1s into
      // the timeline: it can play until 1s + (2s - 0.5s) = 2.5s.
      final track = _audio(
        id: 'sound',
        startTime: const Duration(seconds: 1),
        endTime: shortComposition + const Duration(seconds: 1),
        startOffset: const Duration(milliseconds: 500),
        duration: 2,
      );

      expect(
        grow(
          [track],
          previousDuration: shortComposition + const Duration(seconds: 1),
        ).single.endTime,
        const Duration(milliseconds: 2500),
      );
    });

    test('leaves a window the user trimmed shorter than the composition', () {
      final track = _audio(
        id: 'sound',
        startTime: Duration.zero,
        endTime: const Duration(milliseconds: 200),
        duration: 30,
      );

      final tracks = [track];
      expect(identical(grow(tracks), tracks), isTrue);
    });

    test('leaves an unbounded window to the render clamp', () {
      final track = AudioEvent(
        id: 'sound',
        pubkey: '',
        createdAt: 0,
        url: '/tmp/sound.wav',
        duration: 30,
      );

      final tracks = [track];
      expect(identical(grow(tracks), tracks), isTrue);
    });

    test('never shortens a window when the composition shrank', () {
      final track = _audio(
        id: 'sound',
        startTime: Duration.zero,
        endTime: longComposition,
        duration: 30,
      );

      final tracks = [track];
      expect(
        identical(
          grow(
            tracks,
            previousDuration: longComposition,
            duration: shortComposition,
          ),
          tracks,
        ),
        isTrue,
      );
    });

    test('keeps a trimmed window after the composition shrank under it', () {
      // Trim to 1.5s over a 3s composition, drop the hold so the composition
      // is 1.125s (the window now overhangs, because nothing shortens it),
      // then raise the hold to 4.5s. The overhang is not coverage — reading it
      // as "reached the old end" would grow the window and eat the trim.
      final track = _audio(
        id: 'sound',
        startTime: Duration.zero,
        endTime: const Duration(milliseconds: 1500),
        duration: 30,
      );

      final tracks = [track];
      expect(
        identical(
          grow(
            tracks,
            previousDuration: const Duration(milliseconds: 1125),
            duration: const Duration(milliseconds: 4500),
          ),
          tracks,
        ),
        isTrue,
      );
    });

    test('stops where the source ends without clawing the window back', () {
      // A 1s sound with 0.8s trimmed off its head runs out at 200ms — behind
      // the window's 375ms end, e.g. after the duration-heal path corrected a
      // too-long source length. Growing must not shorten the window to 200ms.
      final track = _audio(
        id: 'sound',
        startTime: Duration.zero,
        endTime: shortComposition,
        startOffset: const Duration(milliseconds: 800),
        duration: 1,
      );

      final tracks = [track];
      expect(identical(grow(tracks), tracks), isTrue);
    });

    test('carries skipped tracks through in order while one grows', () {
      final covering = _audio(
        id: 'music',
        startTime: Duration.zero,
        endTime: shortComposition,
        duration: 30,
      );
      final trimmed = _audio(
        id: 'voice-over',
        startTime: Duration.zero,
        endTime: const Duration(milliseconds: 200),
        duration: 30,
      );
      final unbounded = AudioEvent(
        id: 'ambience',
        pubkey: '',
        createdAt: 0,
        url: '/tmp/ambience.wav',
        duration: 30,
      );

      final result = grow([covering, trimmed, unbounded]);

      expect(result, hasLength(3));
      expect(result[0].endTime, maxDuration);
      expect(identical(result[1], trimmed), isTrue);
      expect(identical(result[2], unbounded), isTrue);
    });
  });

  group(stopMotionInitialPixelsPerSecond, () {
    List<StopMotionClipFrame> framesOf(int count, Duration hold) => [
      for (var i = 0; i < count; i++)
        StopMotionClipFrame(path: 'f$i.jpg', duration: hold),
    ];

    test('scales so the average still gets the target tile width', () {
      // 100ms stills → pps = targetTileWidth / 0.1s.
      final pps = stopMotionInitialPixelsPerSecond(
        framesOf(10, const Duration(milliseconds: 100)),
      );
      expect(pps, TimelineConstants.stopMotionTargetTileWidth / 0.1);
    });

    test('clamps to the stop-motion zoom ceiling for tiny holds', () {
      // 1ms stills would need an absurd zoom; the ceiling caps it.
      final pps = stopMotionInitialPixelsPerSecond(
        framesOf(5, const Duration(milliseconds: 1)),
      );
      expect(pps, TimelineConstants.stopMotionMaxPixelsPerSecond);
    });

    test('never zooms below the video default for long holds', () {
      final pps = stopMotionInitialPixelsPerSecond(
        framesOf(3, const Duration(seconds: 5)),
      );
      expect(pps, TimelineConstants.pixelsPerSecond);
    });

    test('falls back to the video default for an empty frame list', () {
      expect(
        stopMotionInitialPixelsPerSecond(const []),
        TimelineConstants.pixelsPerSecond,
      );
    });
  });
}
