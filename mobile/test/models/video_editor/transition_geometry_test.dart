import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ClipTransition, ClipTransitionType, EditorVideo;

void main() {
  const dissolve = ClipTransition(type: ClipTransitionType.dissolve);
  const fadeToBlack = ClipTransition(type: ClipTransitionType.fadeToBlack);

  group('transitionConsumedPerSide', () {
    test('an overlap consumes twice its duration per side', () {
      final t = dissolve.copyWith(duration: const Duration(milliseconds: 400));
      expect(
        transitionConsumedPerSide(
          const Duration(seconds: 3),
          const Duration(seconds: 3),
          t,
        ),
        equals(const Duration(milliseconds: 800)),
      );
    });

    test('a dip consumes half its duration per side', () {
      final t = fadeToBlack.copyWith(duration: const Duration(seconds: 2));
      expect(
        transitionConsumedPerSide(
          const Duration(seconds: 3),
          const Duration(seconds: 3),
          t,
        ),
        equals(const Duration(seconds: 1)),
      );
    });

    test('clamps to the shorter of the two adjacent clips', () {
      final t = fadeToBlack.copyWith(duration: const Duration(seconds: 4));
      // Half of 4s = 2s, but the shorter clip is only 1s.
      expect(
        transitionConsumedPerSide(
          const Duration(seconds: 1),
          const Duration(seconds: 3),
          t,
        ),
        equals(const Duration(seconds: 1)),
      );
    });
  });

  group('transitionDurationForConsumed', () {
    test('inverts the overlap geometry (consumed × 0.5)', () {
      expect(
        transitionDurationForConsumed(
          const Duration(milliseconds: 800),
          ClipTransitionType.dissolve,
        ),
        equals(const Duration(milliseconds: 400)),
      );
    });

    test('inverts the dip geometry (consumed × 2)', () {
      expect(
        transitionDurationForConsumed(
          const Duration(milliseconds: 500),
          ClipTransitionType.fadeToBlack,
        ),
        equals(const Duration(seconds: 1)),
      );
    });

    test('returns zero when there is no room', () {
      expect(
        transitionDurationForConsumed(
          Duration.zero,
          ClipTransitionType.dissolve,
        ),
        equals(Duration.zero),
      );
      expect(
        transitionDurationForConsumed(
          const Duration(milliseconds: -10),
          ClipTransitionType.fadeToBlack,
        ),
        equals(Duration.zero),
      );
    });

    test('round-trips with transitionConsumedPerSide for in-bounds values', () {
      final t = dissolve.copyWith(duration: const Duration(milliseconds: 600));
      final consumed = transitionConsumedPerSide(
        const Duration(seconds: 5),
        const Duration(seconds: 5),
        t,
      );
      expect(
        transitionDurationForConsumed(consumed, ClipTransitionType.dissolve),
        equals(const Duration(milliseconds: 600)),
      );
    });
  });

  group('clampTransitions', () {
    DivineVideoClip clip(
      String id,
      Duration duration, {
      ClipTransition? transition,
      double? playbackSpeed,
    }) => DivineVideoClip(
      id: id,
      video: EditorVideo.file('${Directory.systemTemp.path}/$id.mp4'),
      duration: duration,
      recordedAt: DateTime(2026),
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
      transition: transition,
      playbackSpeed: playbackSpeed,
    );

    test('keeps the last clip transition as the loop-restart wrap', () {
      // The last clip's transition is no longer dropped: it wraps the last
      // clip's tail into the first clip's head. A 500ms dissolve fits two 2s
      // clips, so it passes through unchanged.
      final clips = [
        clip('a', const Duration(seconds: 2)),
        clip('b', const Duration(seconds: 2), transition: dissolve),
      ];

      expect(clampTransitions(clips)['b'], equals(dissolve));
    });

    test('returns null for a clip with no transition', () {
      final clips = [
        clip('a', const Duration(seconds: 2)),
        clip('b', const Duration(seconds: 2)),
      ];

      expect(clampTransitions(clips)['a'], isNull);
    });

    test('passes an in-bounds overlap through unchanged', () {
      // Two 2s clips → overlap ceiling is half the shorter clip = 1s. 800ms is
      // within bounds.
      final eightHundred = dissolve.copyWith(
        duration: const Duration(milliseconds: 800),
      );
      final clips = [
        clip('a', const Duration(seconds: 2), transition: eightHundred),
        clip('b', const Duration(seconds: 2)),
      ];

      expect(clampTransitions(clips)['a'], equals(eightHundred));
    });

    test('clamps an overlap longer than half the shorter clip', () {
      final tooLong = dissolve.copyWith(
        duration: const Duration(milliseconds: 1500),
      );
      final clips = [
        clip('a', const Duration(seconds: 2), transition: tooLong),
        clip('b', const Duration(seconds: 2)),
      ];

      // Half the shorter (2s) clip = 1s.
      expect(
        clampTransitions(clips)['a']?.duration,
        equals(const Duration(seconds: 1)),
      );
    });

    test('lets a dip run up to twice the shorter clip', () {
      // Dips fade out then in (sequential), so a 1500ms dip on 2s clips
      // (ceiling 4s) is left unchanged where the same overlap would be clamped.
      final dip = fadeToBlack.copyWith(
        duration: const Duration(milliseconds: 1500),
      );
      final clips = [
        clip('a', const Duration(seconds: 2), transition: dip),
        clip('b', const Duration(seconds: 2)),
      ];

      expect(
        clampTransitions(clips)['a']?.duration,
        equals(const Duration(milliseconds: 1500)),
      );
    });

    test('clamps on playbackDuration for speed-changed clips', () {
      // A 2× clip of 4s source occupies 2s of playback → overlap ceiling 1s.
      final tooLong = dissolve.copyWith(
        duration: const Duration(milliseconds: 1500),
      );
      final clips = [
        clip(
          'a',
          const Duration(seconds: 4),
          transition: tooLong,
          playbackSpeed: 2,
        ),
        clip('b', const Duration(seconds: 4), playbackSpeed: 2),
      ];

      expect(
        clampTransitions(clips)['a']?.duration,
        equals(const Duration(seconds: 1)),
      );
    });

    test('splits a shared middle clip between two over-consuming dips', () {
      // 3×1s clips with 2s dips on both boundaries. Each dip alone would consume
      // the whole 1s middle clip; together they must not overlap, so each is
      // clamped to 1s (0.5s consumed per side → head + tail exactly fills the
      // middle clip). This is what fixes the "both halves the same color" bug.
      final dip2s = fadeToBlack.copyWith(duration: const Duration(seconds: 2));
      final clips = [
        clip('a', const Duration(seconds: 1), transition: dip2s),
        clip('b', const Duration(seconds: 1), transition: dip2s),
        clip('c', const Duration(seconds: 1)),
      ];

      final clamped = clampTransitions(clips);
      expect(clamped['a']?.duration, equals(const Duration(seconds: 1)));
      expect(clamped['b']?.duration, equals(const Duration(seconds: 1)));
      expect(clamped['c'], isNull);
    });

    test('splits a shared middle clip between two over-consuming overlaps', () {
      // 3×1s clips with a dissolve at the overlap ceiling (500ms) on both
      // boundaries. Each alone would consume the whole 1s middle clip, leaving
      // no solo body — and the native overlap (planOverlap) then falls back to
      // a hard cut, dropping the transition. Clamped, they split the clip: each
      // becomes 250ms so the middle keeps 500ms of solo body for both blends.
      final overlap500 = dissolve.copyWith(
        duration: const Duration(milliseconds: 500),
      );
      final clips = [
        clip('a', const Duration(seconds: 1), transition: overlap500),
        clip('b', const Duration(seconds: 1), transition: overlap500),
        clip('c', const Duration(seconds: 1)),
      ];

      final clamped = clampTransitions(clips);
      expect(clamped['a']?.duration, equals(const Duration(milliseconds: 250)));
      expect(clamped['b']?.duration, equals(const Duration(milliseconds: 250)));
    });

    test('does not reduce a single dip even when the middle clip is short', () {
      // Only the first boundary has a transition, so the 1s middle clip is
      // consumed from one side only — the dip keeps its full (in-bounds) length.
      final dip1s = fadeToBlack.copyWith(duration: const Duration(seconds: 1));
      final clips = [
        clip('a', const Duration(seconds: 1), transition: dip1s),
        clip('b', const Duration(seconds: 1)),
        clip('c', const Duration(seconds: 1)),
      ];

      final clamped = clampTransitions(clips);
      expect(clamped['a']?.duration, equals(const Duration(seconds: 1)));
    });

    test(
      'scales the two boundaries by their demand on an over-consumed clip',
      () {
        // The middle clip (1s) is over-consumed: its incoming dip wants 1s/side
        // (2s dip) and its outgoing overlap wants 1s/side (500ms dissolve). They
        // share the 1s budget proportionally to their equal demand → 0.5s each,
        // so neither side over-runs and the clip is split between them.
        final dip2s = fadeToBlack.copyWith(
          duration: const Duration(seconds: 2),
        );
        final overlap500 = dissolve.copyWith(
          duration: const Duration(milliseconds: 500),
        );
        final clips = [
          clip('a', const Duration(seconds: 1), transition: dip2s),
          clip('b', const Duration(seconds: 1), transition: overlap500),
          clip('c', const Duration(seconds: 1)),
        ];

        final clamped = clampTransitions(clips);
        // Dip: 0.5s consumed → duration 1s. Overlap: 0.5s consumed → duration
        // 250ms.
        expect(clamped['a']?.duration, equals(const Duration(seconds: 1)));
        expect(
          clamped['b']?.duration,
          equals(const Duration(milliseconds: 250)),
        );
      },
    );
  });

  group('output timeline', () {
    DivineVideoClip clip(
      String id,
      Duration duration, {
      ClipTransition? transition,
    }) => DivineVideoClip(
      id: id,
      video: EditorVideo.file('${Directory.systemTemp.path}/$id.mp4'),
      duration: duration,
      recordedAt: DateTime(2026),
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
      transition: transition,
    );

    group('renderedOutputDuration', () {
      test('subtracts the blend of an overlap from the total', () {
        // 2×1s with a 500ms dissolve → the blend removes 500ms → 1.5s.
        final overlap500 = dissolve.copyWith(
          duration: const Duration(milliseconds: 500),
        );
        final clips = [
          clip('a', const Duration(seconds: 1), transition: overlap500),
          clip('b', const Duration(seconds: 1)),
        ];

        expect(
          renderedOutputDuration(clips),
          equals(const Duration(milliseconds: 1500)),
        );
      });

      test('leaves the total unchanged for dips', () {
        // Dips fade out then in without overlapping, so the timeline length is
        // unchanged: 3×1s with two dips stays 3s.
        final dip = fadeToBlack.copyWith(duration: const Duration(seconds: 1));
        final clips = [
          clip('a', const Duration(seconds: 1), transition: dip),
          clip('b', const Duration(seconds: 1), transition: dip),
          clip('c', const Duration(seconds: 1)),
        ];

        expect(
          renderedOutputDuration(clips),
          equals(const Duration(seconds: 3)),
        );
      });

      test('equals the sum when there are no transitions', () {
        final clips = [
          clip('a', const Duration(seconds: 1)),
          clip('b', const Duration(milliseconds: 500)),
        ];

        expect(
          renderedOutputDuration(clips),
          equals(const Duration(milliseconds: 1500)),
        );
      });
    });

    group('editorToOutputPosition', () {
      // 2×1s with a 500ms dissolve: editor axis 0..2s, output axis 0..1.5s.
      // The blend covers editor [0.5s, 1.5s] (2×500ms) → 500ms of output.
      final overlap500 = dissolve.copyWith(
        duration: const Duration(milliseconds: 500),
      );
      final clips = [
        clip('a', const Duration(seconds: 1), transition: overlap500),
        clip('b', const Duration(seconds: 1)),
      ];

      test('exposes both editor clock boundaries without the loop wrap', () {
        expect(TransitionTimelineMap.fromClips(clips).clockBoundaries, [
          const Duration(milliseconds: 500),
          const Duration(milliseconds: 1500),
        ]);
        expect(
          TransitionTimelineMap.fromClips([
            clip('a', const Duration(seconds: 1), transition: overlap500),
          ]).clockBoundaries,
          isEmpty,
        );
      });

      test('is the identity before the blend region', () {
        expect(
          editorToOutputPosition(clips, const Duration(milliseconds: 250)),
          equals(const Duration(milliseconds: 250)),
        );
      });

      test('compresses 2:1 inside the blend region', () {
        // Boundary at editor 1s is the blend midpoint → output 0.75s.
        expect(
          editorToOutputPosition(clips, const Duration(seconds: 1)),
          equals(const Duration(milliseconds: 750)),
        );
      });

      test('maps the editor end onto the output end', () {
        expect(
          editorToOutputPosition(clips, const Duration(seconds: 2)),
          equals(const Duration(milliseconds: 1500)),
        );
      });

      test('is the identity when no transition shortens the timeline', () {
        final plain = [
          clip('a', const Duration(seconds: 1)),
          clip('b', const Duration(seconds: 1)),
        ];

        expect(
          editorToOutputPosition(plain, const Duration(milliseconds: 1500)),
          equals(const Duration(milliseconds: 1500)),
        );
      });
    });

    group('outputToEditorPosition', () {
      // 2×1s with a 500ms dissolve: editor axis 0..2s, output axis 0..1.5s.
      // The blend covers editor [0.5s, 1.5s] (2×500ms) → 500ms of output.
      final overlap500 = dissolve.copyWith(
        duration: const Duration(milliseconds: 500),
      );
      final clips = [
        clip('a', const Duration(seconds: 1), transition: overlap500),
        clip('b', const Duration(seconds: 1)),
      ];

      test('is the identity before the blend region', () {
        expect(
          outputToEditorPosition(clips, const Duration(milliseconds: 250)),
          equals(const Duration(milliseconds: 250)),
        );
      });

      test('expands 1:2 inside the blend region', () {
        // Output 0.75s sits at the blend midpoint → editor boundary 1s.
        expect(
          outputToEditorPosition(clips, const Duration(milliseconds: 750)),
          equals(const Duration(seconds: 1)),
        );
      });

      test('maps the output end onto the editor end', () {
        expect(
          outputToEditorPosition(clips, const Duration(milliseconds: 1500)),
          equals(const Duration(seconds: 2)),
        );
      });

      test('clamps a negative output to zero', () {
        expect(
          outputToEditorPosition(clips, const Duration(milliseconds: -100)),
          equals(Duration.zero),
        );
      });

      test('round-trips with editorToOutputPosition', () {
        for (final editorMs in [0, 250, 500, 750, 1000, 1250, 1500, 2000]) {
          final editor = Duration(milliseconds: editorMs);
          final output = editorToOutputPosition(clips, editor);
          expect(
            outputToEditorPosition(clips, output),
            equals(editor),
            reason: 'editor ${editorMs}ms should survive a round-trip',
          );
        }
      });

      test('is the identity when no transition shortens the timeline', () {
        final plain = [
          clip('a', const Duration(seconds: 1)),
          clip('b', const Duration(seconds: 1)),
        ];

        expect(
          outputToEditorPosition(plain, const Duration(milliseconds: 1500)),
          equals(const Duration(milliseconds: 1500)),
        );
      });
    });

    group(TransitionTimelineMap, () {
      final overlap500 = dissolve.copyWith(
        duration: const Duration(milliseconds: 500),
      );

      test('exposes editor and output durations for an overlap', () {
        final map = TransitionTimelineMap.fromClips([
          clip('a', const Duration(seconds: 1), transition: overlap500),
          clip('b', const Duration(seconds: 1)),
        ]);

        expect(map.editorDuration, equals(const Duration(seconds: 2)));
        expect(map.outputDuration, equals(const Duration(milliseconds: 1500)));
      });

      test('editor and output durations match for a dip', () {
        final dip500 = fadeToBlack.copyWith(
          duration: const Duration(milliseconds: 500),
        );
        final map = TransitionTimelineMap.fromClips([
          clip('a', const Duration(seconds: 1), transition: dip500),
          clip('b', const Duration(seconds: 1)),
        ]);

        expect(map.editorDuration, equals(map.outputDuration));
      });

      group('editorToOutputOrNull', () {
        test('returns null for a null position', () {
          final map = TransitionTimelineMap.fromClips([
            clip('a', const Duration(seconds: 1), transition: overlap500),
            clip('b', const Duration(seconds: 1)),
          ]);

          expect(map.editorToOutputOrNull(null), isNull);
        });

        test('maps a non-null position like editorToOutput', () {
          final map = TransitionTimelineMap.fromClips([
            clip('a', const Duration(seconds: 1), transition: overlap500),
            clip('b', const Duration(seconds: 1)),
          ]);

          // The editor end (2s) lands on the shorter output end (1.5s).
          expect(
            map.editorToOutputOrNull(const Duration(seconds: 2)),
            equals(map.editorToOutput(const Duration(seconds: 2))),
          );
          expect(
            map.editorToOutputOrNull(const Duration(seconds: 2)),
            equals(const Duration(milliseconds: 1500)),
          );
        });

        test('is the identity when no transition shortens the timeline', () {
          final map = TransitionTimelineMap.fromClips([
            clip('a', const Duration(seconds: 1)),
            clip('b', const Duration(seconds: 1)),
          ]);

          expect(
            map.editorToOutputOrNull(const Duration(milliseconds: 1500)),
            equals(const Duration(milliseconds: 1500)),
          );
        });
      });
    });
  });

  group('loop-restart wrap', () {
    DivineVideoClip clip(
      String id,
      Duration duration, {
      ClipTransition? transition,
    }) => DivineVideoClip(
      id: id,
      video: EditorVideo.file('${Directory.systemTemp.path}/$id.mp4'),
      duration: duration,
      recordedAt: DateTime(2026),
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
      transition: transition,
    );

    group('clampTransitions', () {
      test('passes an in-bounds single-clip wrap through unchanged', () {
        // One 4s clip: an 800ms dissolve carves 1.6s head + 1.6s tail, leaving
        // an 0.8s middle body, so it fits and is not reduced.
        final wrap = dissolve.copyWith(
          duration: const Duration(milliseconds: 800),
        );
        expect(
          clampTransitions([
            clip('a', const Duration(seconds: 4), transition: wrap),
          ])['a'],
          equals(wrap),
        );
      });

      test('clamps a single-clip wrap that would consume the whole clip', () {
        // A 1500ms dissolve on a 2s clip wants 2×(1500×2)=6s of a 2s clip; the
        // head+tail budget caps it to half the clip per side → 500ms.
        final tooLong = dissolve.copyWith(
          duration: const Duration(milliseconds: 1500),
        );
        expect(
          clampTransitions([
            clip('a', const Duration(seconds: 2), transition: tooLong),
          ])['a']?.duration,
          equals(const Duration(milliseconds: 500)),
        );
      });

      test('passes an in-bounds multi-clip wrap through unchanged', () {
        // Two 4s clips, no interior transition: a 500ms dissolve carves 1s from
        // the last clip's tail and 1s from the first clip's head, both fit.
        final wrap = dissolve.copyWith(
          duration: const Duration(milliseconds: 500),
        );
        final clips = [
          clip('a', const Duration(seconds: 4)),
          clip('b', const Duration(seconds: 4), transition: wrap),
        ];

        expect(clampTransitions(clips)['b'], equals(wrap));
      });
    });

    // The loop-restart wrap's blend plays at the loop point, past the last
    // clip, so it shortens the output length without adding a blend region to
    // the position mapping — the ruler and playhead map exactly as without a
    // wrap and never go negative or run past the editor timeline.
    group('editor↔output map', () {
      test('renderedOutputDuration subtracts an overlap wrap blend', () {
        final wrap = dissolve.copyWith(
          duration: const Duration(milliseconds: 800),
        );
        expect(
          renderedOutputDuration([
            clip('a', const Duration(seconds: 4), transition: wrap),
          ]),
          equals(const Duration(milliseconds: 3200)),
        );
      });

      test('renderedOutputDuration keeps a dip wrap at full length', () {
        final wrap = fadeToBlack.copyWith(
          duration: const Duration(seconds: 1),
        );
        expect(
          renderedOutputDuration([
            clip('a', const Duration(seconds: 4), transition: wrap),
          ]),
          equals(const Duration(seconds: 4)),
        );
      });

      test('renderedOutputDuration subtracts interior and wrap blends', () {
        // The interior a→b dissolve and the wrap on b each remove their 500ms
        // blend: 4s − 0.5s − 0.5s.
        final t = dissolve.copyWith(
          duration: const Duration(milliseconds: 500),
        );
        final clips = [
          clip('a', const Duration(seconds: 2), transition: t),
          clip('b', const Duration(seconds: 2), transition: t),
        ];

        expect(
          renderedOutputDuration(clips),
          equals(const Duration(seconds: 3)),
        );
      });

      test('editorToOutputPosition is the identity for a single-clip wrap', () {
        final wrap = dissolve.copyWith(
          duration: const Duration(milliseconds: 800),
        );
        final clips = [
          clip('a', const Duration(seconds: 4), transition: wrap),
        ];
        expect(
          editorToOutputPosition(clips, const Duration(seconds: 2)),
          equals(const Duration(seconds: 2)),
        );
        expect(
          editorToOutputPosition(clips, const Duration(seconds: 4)),
          equals(const Duration(seconds: 4)),
        );
      });
    });

    group(LoopWrapDisplay, () {
      test('is none without a loop transition', () {
        final display = LoopWrapDisplay.fromClips([
          clip('a', const Duration(seconds: 3)),
        ]);
        expect(display.isActive, isFalse);
        expect(
          display.displayTotal([clip('a', const Duration(seconds: 3))]),
          equals(const Duration(seconds: 3)),
        );
      });

      test('shortens first head + last tail and appends the overlap seam', () {
        // 500ms dissolve → 1s consumed per side, seam 2s−1s/2... = 1.5s.
        final wrap = dissolve.copyWith(
          duration: const Duration(milliseconds: 500),
        );
        final clips = [
          clip('a', const Duration(seconds: 3)),
          clip('b', const Duration(seconds: 3), transition: wrap),
        ];
        final display = LoopWrapDisplay.fromClips(clips);

        expect(display.consumedPerSide, equals(const Duration(seconds: 1)));
        expect(
          display.seamDuration,
          equals(const Duration(milliseconds: 1500)),
        );
        expect(
          display.displayDuration(clips.first, isFirst: true, isLast: false),
          equals(const Duration(seconds: 2)),
        );
        expect(
          display.displayDuration(clips.last, isFirst: false, isLast: true),
          equals(const Duration(seconds: 2)),
        );
        // Total = 6s − 2×1s + 1.5s = 5.5s — exactly the export length
        // (6s − 500ms blend).
        expect(
          display.displayTotal(clips),
          equals(const Duration(milliseconds: 5500)),
        );
      });

      test('keeps the total unchanged for a dip wrap', () {
        // Dips don't shorten the export; consumed head+tail return in full via
        // the seam region: total stays Σ.
        final wrap = fadeToBlack.copyWith(
          duration: const Duration(seconds: 1),
        );
        final clips = [
          clip('a', const Duration(seconds: 3), transition: wrap),
        ];
        final display = LoopWrapDisplay.fromClips(clips);

        expect(
          display.consumedPerSide,
          equals(const Duration(milliseconds: 500)),
        );
        expect(display.seamDuration, equals(const Duration(seconds: 1)));
        expect(
          display.displayTotal(clips),
          equals(const Duration(seconds: 3)),
        );
      });

      test('consumes both ends of a single clip', () {
        final wrap = dissolve.copyWith(
          duration: const Duration(milliseconds: 250),
        );
        final clips = [
          clip('a', const Duration(seconds: 3), transition: wrap),
        ];
        final display = LoopWrapDisplay.fromClips(clips);

        // 250ms dissolve → 500ms per side, both from the same clip.
        expect(
          display.displayDuration(clips.first, isFirst: true, isLast: true),
          equals(const Duration(seconds: 2)),
        );
      });
    });

    group('loopTransitionRoomPerSide', () {
      test('is half the playback for a single clip', () {
        expect(
          loopTransitionRoomPerSide([clip('a', const Duration(seconds: 4))]),
          equals(const Duration(seconds: 2)),
        );
      });

      test('is the shorter of the joined tail and head', () {
        expect(
          loopTransitionRoomPerSide([
            clip('a', const Duration(seconds: 3)),
            clip('b', const Duration(seconds: 2)),
          ]),
          equals(const Duration(seconds: 2)),
        );
      });

      test('excludes the neighbours own internal transitions', () {
        // a→b dissolve (500ms) consumes 1s of b's head, leaving 1s tail for the
        // wrap; a's own outgoing consumes 1s of its tail, leaving 2s head. The
        // tighter side (1s) wins.
        final internal = dissolve.copyWith(
          duration: const Duration(milliseconds: 500),
        );
        expect(
          loopTransitionRoomPerSide([
            clip('a', const Duration(seconds: 3), transition: internal),
            clip('b', const Duration(seconds: 2)),
          ]),
          equals(const Duration(seconds: 1)),
        );
      });
    });
  });
}
