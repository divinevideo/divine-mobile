// ABOUTME: Tests for PreviewComposition — the background seam/speed renders
// ABOUTME: behind the preview player and the position map that follows them.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/clip_speed_render_service.dart';
import 'package:openvine/services/video_editor/preview_composition.dart';
import 'package:openvine/services/video_editor/transition_seam_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as editor;

// pro_video_editor's ClipTransition defaults to a 500ms duration.
const _dissolve = editor.ClipTransition(
  type: editor.ClipTransitionType.dissolve,
);

// 500ms dissolve on 3s clips → consumed 1000ms/side, seam 1500ms.
const _seam = TransitionSeam(
  path: '/tmp/seam.mp4',
  duration: Duration(milliseconds: 1500),
  tailConsumed: Duration(milliseconds: 1000),
  headConsumed: Duration(milliseconds: 1000),
);

DivineVideoClip _clip(
  String id, {
  editor.ClipTransition? transition,
  double? playbackSpeed,
}) => DivineVideoClip(
  id: id,
  video: editor.EditorVideo.file(File('/tmp/$id.mp4')),
  duration: const Duration(seconds: 3),
  recordedAt: DateTime(2024),
  targetAspectRatio: model.AspectRatio.square,
  originalAspectRatio: 1,
  transition: transition,
  playbackSpeed: playbackSpeed,
);

/// Seam service whose renders complete only when the test releases them.
class _GatedSeamService extends TransitionSeamRenderService {
  final pending = <String, Completer<TransitionSeam?>>{};

  /// Renders [cancelRendersExcept] dropped, still waiting to settle — a
  /// native encode does not stop the instant it is cancelled.
  final cancelled = <String, Completer<TransitionSeam?>>{};
  int renderCalls = 0;

  String _id(DivineVideoClip a, DivineVideoClip b) =>
      seamKey(a, b, a.transition!);

  @override
  bool isRendering(
    DivineVideoClip clipA,
    DivineVideoClip clipB,
    editor.ClipTransition transition,
  ) => pending.containsKey(_id(clipA, clipB));

  @override
  Future<TransitionSeam?> render({
    required DivineVideoClip clipA,
    required DivineVideoClip clipB,
    required editor.ClipTransition transition,
  }) {
    renderCalls++;
    final id = _id(clipA, clipB);
    return pending.putIfAbsent(id, Completer.new).future;
  }

  @override
  void cancelRendersExcept(Set<String> keep) {
    for (final key in pending.keys.toList()) {
      if (!keep.contains(key)) cancelled[key] = pending.remove(key)!;
    }
  }

  /// Lands the render for [a]→[b] with [seam] (`null` = failed render).
  Future<void> land(
    DivineVideoClip a,
    DivineVideoClip b, {
    TransitionSeam? seam = _seam,
  }) async {
    final id = _id(a, b);
    final completer = pending.remove(id) ?? cancelled.remove(id)!;
    if (seam != null) cacheSeamForTest(a, b, a.transition!, seam);
    completer.complete(seam);
    await completer.future;
  }
}

class _GatedSpeedService extends ClipSpeedRenderService {
  final pending = <String, Completer<RenderedSpeedClip?>>{};

  @override
  bool isRendering(DivineVideoClip clip) => pending.containsKey(clip.id);

  @override
  Future<RenderedSpeedClip?> render(DivineVideoClip clip) =>
      pending.putIfAbsent(clip.id, Completer.new).future;

  Future<void> land(DivineVideoClip clip) async {
    const rendered = RenderedSpeedClip(
      path: '/tmp/speed.mp4',
      duration: Duration(milliseconds: 1500),
    );
    cacheForTest(clip, rendered);
    final completer = pending.remove(clip.id)!;
    completer.complete(rendered);
    await completer.future;
  }
}

void main() {
  group(PreviewComposition, () {
    late _GatedSeamService seams;
    late _GatedSpeedService speeds;
    late List<DivineVideoClip> clips;
    late int seamLandings;
    late int speedLandings;
    late PreviewComposition composition;

    setUp(() {
      seams = _GatedSeamService();
      speeds = _GatedSpeedService();
      clips = [];
      seamLandings = 0;
      speedLandings = 0;
      composition = PreviewComposition(
        readClips: () => clips,
        runDetached: (operation, _) => unawaited(operation),
        onSeamRendered: () => seamLandings++,
        onSpeedClipRendered: () => speedLandings++,
        seamService: seams,
        speedRenderService: speeds,
      );
    });

    group('ensureSeamsRendered', () {
      test('renders each boundary and the loop wrap once, then reports each '
          'landing', () async {
        final a = _clip('a', transition: _dissolve);
        final b = _clip('b', transition: _dissolve);
        clips = [a, b];

        composition
          ..ensureSeamsRendered(clips)
          // A second pass while both renders are in flight must not start
          // another render or bump the counter again.
          ..ensureSeamsRendered(clips);

        expect(seams.renderCalls, 2);
        expect(composition.pendingSeamRenders.value, 2);

        await seams.land(a, b);
        expect(composition.pendingSeamRenders.value, 1);
        expect(seamLandings, 1);

        await seams.land(b, a);
        expect(composition.pendingSeamRenders.value, 0);
        expect(seamLandings, 2);

        // Both seams are cached now: nothing left to render.
        composition.ensureSeamsRendered(clips);
        expect(seams.renderCalls, 2);
      });

      test(
        'a failed render clears the pending overlay without a resync',
        () async {
          final a = _clip('a', transition: _dissolve);
          final b = _clip('b');
          clips = [a, b];

          composition.ensureSeamsRendered(clips);
          await seams.land(a, b, seam: null);

          expect(composition.pendingSeamRenders.value, 0);
          expect(seamLandings, 0);
        },
      );
      test('cancels the render for a boundary a later edit replaced, and '
          'neither counts it nor resyncs when it lands anyway', () async {
        final a = _clip('a', transition: _dissolve);
        final b = _clip('b');
        clips = [a, b];
        composition.ensureSeamsRendered(clips);
        expect(composition.pendingSeamRenders.value, 1);

        // A committed trim on clip a mints a new seam key for the boundary.
        final trimmed = a.copyWith(trimEnd: const Duration(milliseconds: 200));
        clips = [trimmed, b];
        composition.ensureSeamsRendered(clips);

        expect(seams.cancelled.keys, [seams.seamKey(a, b, _dissolve)]);
        expect(seams.pending.keys, [seams.seamKey(trimmed, b, _dissolve)]);
        expect(composition.pendingSeamRenders.value, 1);

        // The superseded encode still finishes natively: it must not reload
        // the player for a seam the timeline no longer contains.
        await seams.land(a, b);
        expect(seamLandings, 0);
        expect(composition.pendingSeamRenders.value, 1);

        await seams.land(trimmed, b);
        expect(seamLandings, 1);
        expect(composition.pendingSeamRenders.value, 0);
      });

      test('does not resync for a seam the clips stopped needing without a '
          'new render pass', () async {
        final a = _clip('a', transition: _dissolve);
        final b = _clip('b');
        clips = [a, b];
        composition.ensureSeamsRendered(clips);

        // The transition is removed before the render lands.
        clips = [_clip('a'), b];
        await seams.land(a, b);

        expect(seamLandings, 0);
        expect(composition.pendingSeamRenders.value, 0);
      });
    });

    group('ensureSpeedClipsRendered', () {
      test('renders a retimed clip and reports the landing', () async {
        final fast = _clip('fast', playbackSpeed: 2);
        clips = [fast];

        composition
          ..ensureSpeedClipsRendered(clips)
          ..ensureSpeedClipsRendered(clips);
        expect(speeds.pending.keys, ['fast']);

        await speeds.land(fast);
        expect(speedLandings, 1);

        composition.ensureSpeedClipsRendered(clips);
        expect(speeds.pending, isEmpty);
      });

      test('skips a clip whose body a rendered seam already consumes', () {
        final a = _clip('a', transition: _dissolve, playbackSpeed: 2);
        final b = _clip('b', playbackSpeed: 2);
        clips = [a, b];
        seams.cacheSeamForTest(a, b, _dissolve, _seam);

        composition.ensureSpeedClipsRendered(clips);

        expect(speeds.pending, isEmpty);
      });

      test('skips the first and last clip while a loop wrap is active', () {
        final a = _clip('a', playbackSpeed: 2);
        final middle = _clip('middle', playbackSpeed: 2);
        final last = _clip('last', transition: _dissolve, playbackSpeed: 2);
        clips = [a, middle, last];

        composition.ensureSpeedClipsRendered(clips);

        expect(speeds.pending.keys, ['middle']);
      });
    });

    group('position mapping', () {
      test('follows the seam cache without a rebuild of the player clips', () {
        final a = _clip('a', transition: _dissolve);
        final b = _clip('b');
        clips = [a, b];
        const boundary = Duration(seconds: 3);

        // No seam yet: the composite timeline is the editor timeline.
        expect(composition.timelineToPlayer(boundary), boundary);

        seams.cacheSeamForTest(a, b, _dissolve, _seam);

        // Mid-seam lands on the clip boundary once the seam is cached.
        expect(
          composition.timelineToPlayer(boundary),
          const Duration(milliseconds: 2750),
        );
        expect(
          composition.playerToTimeline(const Duration(milliseconds: 2750)),
          boundary,
        );
      });

      test('buildPlayerClips splices the cached seam it maps against', () {
        final a = _clip('a', transition: _dissolve);
        final b = _clip('b');
        clips = [a, b];
        seams.cacheSeamForTest(a, b, _dissolve, _seam);

        final playerClips = composition.buildPlayerClips(clips);

        expect(playerClips.map((c) => c.uri), [
          '/tmp/a.mp4',
          '/tmp/seam.mp4',
          '/tmp/b.mp4',
        ]);
      });
    });

    test('a render landing after dispose neither resyncs nor touches the '
        'disposed overlay counter', () async {
      final a = _clip('a', transition: _dissolve);
      final b = _clip('b');
      clips = [a, b];

      composition
        ..ensureSeamsRendered(clips)
        ..dispose();
      await seams.land(a, b);

      expect(seamLandings, 0);
    });
  });
}
