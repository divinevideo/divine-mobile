import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/services/video_editor/clip_speed_render_service.dart';
import 'package:openvine/services/video_editor/transition_seam_render_service.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as editor;

/// Reports a fixed 1500ms duration for any file, so a persisted seam reads back
/// as valid and [TransitionSeamRenderService] takes its reuse branch.
class _FakeProVideoEditor extends editor.ProVideoEditor {
  _FakeProVideoEditor({this.duration = const Duration(milliseconds: 1500)});

  /// What [getMetadata] reports. Zero drives the rejection branch, where the
  /// service discards the seam it just wrote.
  final Duration duration;

  // The base constructor calls this, and the platform interface throws.
  @override
  void initializeStream() {}

  @override
  Future<editor.VideoMetadata> getMetadata(
    editor.EditorVideo value, {
    bool checkStreamingOptimization = false,
    editor.NativeLogLevel? nativeLogLevel,
  }) async => editor.VideoMetadata(
    duration: duration,
    extension: 'mp4',
    fileSize: 1024,
    resolution: const Size(1080, 1920),
    rotation: 0,
    bitrate: 1000000,
  );
}

void main() {
  DivineVideoClip clip(String id, {editor.ClipTransition? transition}) =>
      DivineVideoClip(
        id: id,
        video: editor.EditorVideo.file(File('/tmp/$id.mp4')),
        duration: const Duration(seconds: 3),
        recordedAt: DateTime(2024),
        targetAspectRatio: model.AspectRatio.square,
        originalAspectRatio: 1,
        transition: transition,
      );

  // pro_video_editor's ClipTransition defaults to a 500ms duration.
  const dissolve = editor.ClipTransition(
    type: editor.ClipTransitionType.dissolve,
  );

  group('buildSeamAwarePlayerClips', () {
    test('plays plain clips when no transition is set', () {
      final clips = [clip('a'), clip('b')];
      final result = buildSeamAwarePlayerClips(
        clips,
        TransitionSeamRenderService(),
      );

      expect(result, hasLength(2));
      expect(result[0].uri, equals('/tmp/a.mp4'));
      expect(result[1].uri, equals('/tmp/b.mp4'));
    });

    test('hard-cuts (full clips, no seam) until the seam is rendered', () {
      final clips = [clip('a', transition: dissolve), clip('b')];
      final result = buildSeamAwarePlayerClips(
        clips,
        TransitionSeamRenderService(),
      );

      // No cached seam → 2 untrimmed clips, no seam clip spliced in.
      expect(result, hasLength(2));
      expect(result[0].end, equals(const Duration(seconds: 3)));
      expect(result[1].start, equals(Duration.zero));
    });

    test('consumes the wrap head/tail eagerly before its seam is rendered', () {
      // The last clip's transition is the loop-restart wrap. Its consumption is
      // applied even before the seam file lands, so the display axis (timeline
      // strips) never shifts under the playhead; only the blend itself is
      // missing until rendered. A 500ms dissolve consumes 2×500ms per side.
      final clips = [clip('a'), clip('b', transition: dissolve)];
      final result = buildSeamAwarePlayerClips(
        clips,
        TransitionSeamRenderService(),
      );

      expect(result, hasLength(2));
      expect(result[0].uri, equals('/tmp/a.mp4'));
      expect(result[0].start, equals(const Duration(seconds: 1)));
      expect(result[0].end, equals(const Duration(seconds: 3)));
      expect(result[1].uri, equals('/tmp/b.mp4'));
      expect(result[1].start, equals(Duration.zero));
      expect(result[1].end, equals(const Duration(seconds: 2)));
    });

    test('consumes the first head + last tail and appends the wrap seam', () {
      // The wrap seam (keyed last→first) consumes the first clip's head (it
      // starts later) and the last clip's tail (replaced by the seam), then is
      // appended so the loop restarts seamlessly through the blend.
      final clipA = clip('a');
      final clipB = clip('b', transition: dissolve);
      final service = TransitionSeamRenderService()
        ..cacheSeamForTest(
          clipB,
          clipA,
          dissolve,
          const TransitionSeam(
            path: '/tmp/wrap.mp4',
            duration: Duration(milliseconds: 500),
            tailConsumed: Duration(milliseconds: 500),
            headConsumed: Duration(milliseconds: 500),
          ),
        );

      final result = buildSeamAwarePlayerClips([clipA, clipB], service);

      expect(result, hasLength(3));
      // First clip: head consumed → starts at 500ms.
      expect(result[0].uri, equals('/tmp/a.mp4'));
      expect(result[0].start, equals(const Duration(milliseconds: 500)));
      expect(result[0].end, equals(const Duration(seconds: 3)));
      // Last clip: tail consumed → ends at 2500ms.
      expect(result[1].uri, equals('/tmp/b.mp4'));
      expect(result[1].start, equals(Duration.zero));
      expect(result[1].end, equals(const Duration(milliseconds: 2500)));
      expect(result[2].uri, equals('/tmp/wrap.mp4'));
    });

    test('wraps a single clip into itself (head + tail into the seam)', () {
      final only = clip('a', transition: dissolve);
      final service = TransitionSeamRenderService()
        ..cacheSeamForTest(
          only,
          only,
          dissolve,
          const TransitionSeam(
            path: '/tmp/wrap.mp4',
            duration: Duration(milliseconds: 500),
            tailConsumed: Duration(milliseconds: 500),
            headConsumed: Duration(milliseconds: 500),
          ),
        );

      final result = buildSeamAwarePlayerClips([only], service);

      expect(result, hasLength(2));
      // Middle body: [500ms, 2500ms].
      expect(result[0].uri, equals('/tmp/a.mp4'));
      expect(result[0].start, equals(const Duration(milliseconds: 500)));
      expect(result[0].end, equals(const Duration(milliseconds: 2500)));
      expect(result[1].uri, equals('/tmp/wrap.mp4'));
    });

    test('splices the rendered seam between trimmed neighbours', () {
      final clipA = clip('a', transition: dissolve);
      final clipB = clip('b');
      final service = TransitionSeamRenderService()
        ..cacheSeamForTest(
          clipA,
          clipB,
          dissolve,
          const TransitionSeam(
            path: '/tmp/seam.mp4',
            duration: Duration(milliseconds: 500),
            tailConsumed: Duration(milliseconds: 500),
            headConsumed: Duration(milliseconds: 500),
          ),
        );

      final result = buildSeamAwarePlayerClips([clipA, clipB], service);

      expect(result, hasLength(3));
      // Clip A body: [0, 2500ms] (last 500ms went into the seam).
      expect(result[0].uri, equals('/tmp/a.mp4'));
      expect(result[0].start, equals(Duration.zero));
      expect(result[0].end, equals(const Duration(milliseconds: 2500)));
      // The seam.
      expect(result[1].uri, equals('/tmp/seam.mp4'));
      // Clip B body: [500ms, 3000ms] (first 500ms went into the seam).
      expect(result[2].uri, equals('/tmp/b.mp4'));
      expect(result[2].start, equals(const Duration(milliseconds: 500)));
      expect(result[2].end, equals(const Duration(seconds: 3)));
    });

    test('plays the pre-rendered normal-rate file at 1× when a speed render '
        'is cached', () {
      final clipA = DivineVideoClip(
        id: 'a',
        video: editor.EditorVideo.file(File('/tmp/a.mp4')),
        duration: const Duration(seconds: 3),
        recordedAt: DateTime(2024),
        targetAspectRatio: model.AspectRatio.square,
        originalAspectRatio: 1,
        playbackSpeed: 2,
        volume: 0.5,
      );
      final speeds = ClipSpeedRenderService()
        ..cacheForTest(
          clipA,
          const RenderedSpeedClip(
            path: '/tmp/a_speed.mp4',
            duration: Duration(milliseconds: 1500),
          ),
        );

      final result = buildSeamAwarePlayerClips(
        [clipA],
        TransitionSeamRenderService(),
        speedRenders: speeds,
      );

      expect(result, hasLength(1));
      // The rendered file plays at 1× (speed already baked in) …
      expect(result[0].uri, equals('/tmp/a_speed.mp4'));
      expect(result[0].playbackSpeed, equals(1.0));
      // … but volume is still applied live, so a mute never re-renders.
      expect(result[0].volume, equals(0.5));
    });

    test('falls back to live retiming when no speed render is cached', () {
      final clipA = DivineVideoClip(
        id: 'a',
        video: editor.EditorVideo.file(File('/tmp/a.mp4')),
        duration: const Duration(seconds: 3),
        recordedAt: DateTime(2024),
        targetAspectRatio: model.AspectRatio.square,
        originalAspectRatio: 1,
        playbackSpeed: 2,
      );

      final result = buildSeamAwarePlayerClips(
        [clipA],
        TransitionSeamRenderService(),
        speedRenders: ClipSpeedRenderService(),
      );

      expect(result, hasLength(1));
      // Source file retimed live by the player until the render lands.
      expect(result[0].uri, equals('/tmp/a.mp4'));
      expect(result[0].playbackSpeed, equals(2.0));
    });

    test('keeps a seam-consumed clip on live retiming even when a speed '
        'render is cached', () {
      final clipA = DivineVideoClip(
        id: 'a',
        video: editor.EditorVideo.file(File('/tmp/a.mp4')),
        duration: const Duration(seconds: 3),
        recordedAt: DateTime(2024),
        targetAspectRatio: model.AspectRatio.square,
        originalAspectRatio: 1,
        playbackSpeed: 2,
        transition: dissolve,
      );
      final clipB = clip('b');
      final seams = TransitionSeamRenderService()
        ..cacheSeamForTest(
          clipA,
          clipB,
          dissolve,
          const TransitionSeam(
            path: '/tmp/seam.mp4',
            duration: Duration(milliseconds: 500),
            tailConsumed: Duration(milliseconds: 500),
            headConsumed: Duration(milliseconds: 500),
          ),
        );
      final speeds = ClipSpeedRenderService()
        ..cacheForTest(
          clipA,
          const RenderedSpeedClip(
            path: '/tmp/a_speed.mp4',
            duration: Duration(milliseconds: 1250),
          ),
        );

      final result = buildSeamAwarePlayerClips(
        [clipA, clipB],
        seams,
        speedRenders: speeds,
      );

      // Clip A's tail feeds the seam, so its body can't use the whole-body
      // rendered file — it stays live-retimed (source file at 2×).
      expect(result[0].uri, equals('/tmp/a.mp4'));
      expect(result[0].playbackSpeed, equals(2.0));
      expect(result[1].uri, equals('/tmp/seam.mp4'));
    });
  });

  group('computeSeamSpans', () {
    DivineVideoClip sized(
      String id,
      Duration duration, {
      double? playbackSpeed,
    }) => DivineVideoClip(
      id: id,
      video: editor.EditorVideo.file(File('/tmp/$id.mp4')),
      duration: duration,
      recordedAt: DateTime(2024),
      targetAspectRatio: model.AspectRatio.square,
      originalAspectRatio: 1,
      playbackSpeed: playbackSpeed,
    );

    final service = TransitionSeamRenderService();

    test('overlap uses 2× blend with a solo lead-in/out on long clips', () {
      final spans = service.computeSeamSpans(
        sized('a', const Duration(seconds: 3)),
        sized('b', const Duration(seconds: 3)),
        dissolve,
      );

      expect(spans.consumed, equals(const Duration(seconds: 1)));
      expect(spans.blend, equals(const Duration(milliseconds: 500)));
      // Solo lead = consumed - blend > 0 → never a degenerate hard cut.
      expect(spans.blend, lessThan(spans.consumed));
      expect(spans.seamTransition.duration, equals(spans.blend));
    });

    test('overlap shrinks proportionally on a clip shorter than the '
        'transition, never exceeding the shorter clip', () {
      final spans = service.computeSeamSpans(
        sized('a', const Duration(milliseconds: 200)),
        sized('b', const Duration(seconds: 3)),
        dissolve, // 500ms, longer than the 200ms clip
      );

      // Clamped to the whole 200ms clip; still blends (blend < consumed).
      expect(spans.consumed, equals(const Duration(milliseconds: 200)));
      expect(spans.blend, equals(const Duration(milliseconds: 100)));
      expect(spans.blend, lessThan(spans.consumed));
    });

    test('dip takes half the duration per side and cannot outrun the span', () {
      const fadeToBlack = editor.ClipTransition(
        type: editor.ClipTransitionType.fadeToBlack,
      );

      final long = service.computeSeamSpans(
        sized('a', const Duration(seconds: 3)),
        sized('b', const Duration(seconds: 3)),
        fadeToBlack,
      );
      expect(long.consumed, equals(const Duration(milliseconds: 250)));
      expect(long.blend, equals(const Duration(milliseconds: 500)));

      final short = service.computeSeamSpans(
        sized('a', const Duration(milliseconds: 200)),
        sized('b', const Duration(milliseconds: 200)),
        fadeToBlack,
      );
      // 200ms/side available → dip clamped to 2× the span, not the 500ms
      // request.
      expect(short.consumed, equals(const Duration(milliseconds: 200)));
      expect(short.blend, equals(const Duration(milliseconds: 400)));
    });

    test('clamps on playbackDuration, not source, for speed-changed clips', () {
      // 4× clips of 2s source each occupy only 500ms of wall-clock time, so the
      // overlap must clamp to that playback span (consumed 500ms, blend 250ms)
      // — not the 2s source span the trimmed-duration basis would have used
      // (which would have allowed the full 1000ms consumed / 500ms blend).
      final spans = service.computeSeamSpans(
        sized('a', const Duration(seconds: 2), playbackSpeed: 4),
        sized('b', const Duration(seconds: 2), playbackSpeed: 4),
        dissolve, // 500ms
      );

      expect(spans.consumed, equals(const Duration(milliseconds: 500)));
      expect(spans.blend, equals(const Duration(milliseconds: 250)));
      expect(spans.blend, lessThan(spans.consumed));
      expect(spans.seamTransition.duration, equals(spans.blend));
    });
  });

  group('cached', () {
    test('reversing a clip swaps the file path and invalidates the seam', () {
      final forward = clip('a', transition: dissolve);
      // Reverse swaps `video` to the physically-reversed file (here with
      // symmetric trims, so the trim-based key alone would not change).
      final reversed = forward.copyWith(
        video: editor.EditorVideo.file(File('/tmp/a_reversed.mp4')),
      );
      final clipB = clip('b');
      final service = TransitionSeamRenderService()
        ..cacheSeamForTest(
          forward,
          clipB,
          dissolve,
          const TransitionSeam(
            path: '/tmp/seam.mp4',
            duration: Duration(milliseconds: 1500),
            tailConsumed: Duration(milliseconds: 1000),
            headConsumed: Duration(milliseconds: 1000),
          ),
        );

      expect(service.cached(forward, clipB, dissolve), isNotNull);
      expect(service.cached(reversed, clipB, dissolve), isNull);
    });

    test('changing a clip volume invalidates the seam', () {
      // Volume is baked into the rendered seam audio, so a mute (or any volume
      // change) after caching must miss the cache and re-render.
      final fullVolume = clip('a', transition: dissolve);
      final muted = fullVolume.copyWith(volume: 0);
      final clipB = clip('b');
      final service = TransitionSeamRenderService()
        ..cacheSeamForTest(
          fullVolume,
          clipB,
          dissolve,
          const TransitionSeam(
            path: '/tmp/seam.mp4',
            duration: Duration(milliseconds: 1500),
            tailConsumed: Duration(milliseconds: 1000),
            headConsumed: Duration(milliseconds: 1000),
          ),
        );

      expect(service.cached(fullVolume, clipB, dissolve), isNotNull);
      expect(service.cached(muted, clipB, dissolve), isNull);
    });

    test('changing a clip duration invalidates the seam', () {
      // `duration` can be trimmed independently of the file (clip_manager caps
      // a clip on add) and `_tailClip`/`_headClip` read it, so it must be part
      // of the key.
      final original = clip('a', transition: dissolve);
      final longer = original.copyWith(duration: const Duration(seconds: 4));
      final clipB = clip('b');
      final service = TransitionSeamRenderService()
        ..cacheSeamForTest(
          original,
          clipB,
          dissolve,
          const TransitionSeam(
            path: '/tmp/seam.mp4',
            duration: Duration(milliseconds: 1500),
            tailConsumed: Duration(milliseconds: 1000),
            headConsumed: Duration(milliseconds: 1000),
          ),
        );

      expect(service.cached(original, clipB, dissolve), isNotNull);
      expect(service.cached(longer, clipB, dissolve), isNull);
    });

    test('changing the target aspect ratio invalidates the seam', () {
      // The seam is rendered (and cropped) to the clip's target aspect ratio,
      // so switching it must re-render rather than reuse the old crop.
      final square = clip('a', transition: dissolve);
      final vertical = square.copyWith(
        targetAspectRatio: model.AspectRatio.vertical,
      );
      final clipB = clip('b');
      final service = TransitionSeamRenderService()
        ..cacheSeamForTest(
          square,
          clipB,
          dissolve,
          const TransitionSeam(
            path: '/tmp/seam.mp4',
            duration: Duration(milliseconds: 1500),
            tailConsumed: Duration(milliseconds: 1000),
            headConsumed: Duration(milliseconds: 1000),
          ),
        );

      expect(service.cached(square, clipB, dissolve), isNotNull);
      expect(service.cached(vertical, clipB, dissolve), isNull);
    });
  });

  group('persisted seam reuse', () {
    late Directory tempRoot;
    late editor.ProVideoEditor originalProVideoEditor;
    var renderCount = 0;
    // Every path the stubbed render wrote, standing in for the `divine_*.mp4`
    // the real render leaves in the temporary cache directory.
    final renderedPaths = <String>[];

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      originalProVideoEditor = editor.ProVideoEditor.instance;
      editor.ProVideoEditor.instance = _FakeProVideoEditor();
      tempRoot = Directory.systemTemp.createTempSync('seam_persist_test_');
      renderCount = 0;
      renderedPaths.clear();
      VideoEditorRenderService.renderVideoOverride =
          ({
            required clips,
            required usePersistentStorage,
            aspectRatio,
            parameters,
            taskId,
            maxOutputDuration,
          }) async {
            renderCount++;
            final rendered = File('${tempRoot.path}/render_$renderCount.mp4')
              ..writeAsStringSync('seam body');
            renderedPaths.add(rendered.path);
            return rendered.path;
          };
    });

    tearDown(() {
      VideoEditorRenderService.renderVideoOverride = null;
      editor.ProVideoEditor.instance = originalProVideoEditor;
      if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
    });

    TransitionSeamRenderService service() => TransitionSeamRenderService(
      documentsDirectoryProvider: () async => tempRoot,
    );

    test('a seam persisted by an earlier session is reused instead of '
        're-rendered', () async {
      final clipA = clip('a', transition: dissolve);
      final clipB = clip('b');

      final first = await service().render(
        clipA: clipA,
        clipB: clipB,
        transition: dissolve,
      );

      expect(first, isNotNull);
      expect(renderCount, 1);
      expect(File(first!.path).existsSync(), isTrue);

      // A second service starts with an empty in-memory cache, so reuse here
      // can only come from the keyed file under `transition_seams/` — this is
      // the cross-session branch the editor relies on.
      final second = await service().render(
        clipA: clipA,
        clipB: clipB,
        transition: dissolve,
      );

      expect(second?.path, first.path);
      expect(renderCount, 1);
    });

    test('a seam persisted under a different key is not reused', () async {
      final clipA = clip('a', transition: dissolve);
      final clipB = clip('b');
      const longerDissolve = editor.ClipTransition(
        type: editor.ClipTransitionType.dissolve,
        duration: Duration(milliseconds: 800),
      );

      final first = await service().render(
        clipA: clipA,
        clipB: clipB,
        transition: dissolve,
      );
      expect(renderCount, 1);

      // The persisted path is sha256 of the key, and the key carries the cache
      // version alongside the clip/transition fields. A key change must land on
      // a different file rather than replaying the old one — that is the
      // mechanism `_seamCacheVersion` uses to orphan seams rendered by an older
      // algorithm after an app upgrade.
      final second = await service().render(
        clipA: clipA.copyWith(transition: longerDissolve),
        clipB: clipB,
        transition: longerDissolve,
      );

      expect(renderCount, 2);
      expect(second, isNotNull);
      expect(second!.path, isNot(first!.path));
      expect(File(first.path).existsSync(), isTrue);
    });

    test("deletes the render's cache output once the seam is "
        'persisted', () async {
      final seam = await service().render(
        clipA: clip('a', transition: dissolve),
        clipB: clip('b'),
        transition: dissolve,
      );

      expect(seam, isNotNull);
      expect(renderedPaths, hasLength(1));
      // The seam is the copy under `transition_seams/`; the render's own
      // output is a `divine_*.mp4` in the cache dir that no janitor pattern
      // reaps, so the service must remove it itself once the copy landed.
      expect(seam!.path, isNot(renderedPaths.single));
      expect(File(seam.path).existsSync(), isTrue);
      expect(File(renderedPaths.single).existsSync(), isFalse);
    });

    test('deletes the cache output when the seam is rejected', () async {
      editor.ProVideoEditor.instance = _FakeProVideoEditor(
        duration: Duration.zero,
      );

      final seam = await service().render(
        clipA: clip('a', transition: dissolve),
        clipB: clip('b'),
        transition: dissolve,
      );

      // A zero-duration result discards the seam. The render's cache output
      // has to go the same way, or a rejected seam leaks the ~2 MB a
      // successful one no longer does.
      expect(seam, isNull);
      expect(renderedPaths, hasLength(1));
      expect(File(renderedPaths.single).existsSync(), isFalse);
    });
  });

  group('SeamTimeline', () {
    test('is the identity when no seam is spliced', () {
      final timeline = SeamTimeline(
        [clip('a'), clip('b')],
        TransitionSeamRenderService(),
      );

      expect(timeline.hasSeams, isFalse);
      expect(
        timeline.compositeToTimeline(const Duration(milliseconds: 2500)),
        equals(const Duration(milliseconds: 2500)),
      );
    });

    test('maps a spliced speed body by its real rendered duration, not '
        'playbackDuration', () {
      // 3s clip at 2× → playbackDuration 1500ms, but the re-encoded file lands
      // at 1400ms (frame-rounding). The composite span must follow the real
      // file, else the playhead drifts by the 100ms delta.
      final clipA = DivineVideoClip(
        id: 'a',
        video: editor.EditorVideo.file(File('/tmp/a.mp4')),
        duration: const Duration(seconds: 3),
        recordedAt: DateTime(2024),
        targetAspectRatio: model.AspectRatio.square,
        originalAspectRatio: 1,
        playbackSpeed: 2,
      );
      final speeds = ClipSpeedRenderService()
        ..cacheForTest(
          clipA,
          const RenderedSpeedClip(
            path: '/tmp/a_speed.mp4',
            duration: Duration(milliseconds: 1400),
          ),
        );
      final timeline = SeamTimeline(
        [clipA],
        TransitionSeamRenderService(),
        speedRenders: speeds,
      );

      // Composite (real file) span 1400ms ≠ editor (playbackDuration) span
      // 1500ms, so the axes are no longer the identity.
      expect(timeline.hasSeams, isTrue);
      // Composite end (1400ms, where the file actually ends) → editor end
      // (1500ms, the clip's full drawn length).
      expect(
        timeline.compositeToTimeline(const Duration(milliseconds: 1400)),
        equals(const Duration(milliseconds: 1500)),
      );
      // Half the composite maps to half the editor body.
      expect(
        timeline.compositeToTimeline(const Duration(milliseconds: 700)),
        equals(const Duration(milliseconds: 750)),
      );
      // Round-trips: editor end → composite end.
      expect(
        timeline.timelineToComposite(const Duration(milliseconds: 1500)),
        equals(const Duration(milliseconds: 1400)),
      );
    });

    test('leaves a speed body 1:1 when no render is cached yet', () {
      final clipA = DivineVideoClip(
        id: 'a',
        video: editor.EditorVideo.file(File('/tmp/a.mp4')),
        duration: const Duration(seconds: 3),
        recordedAt: DateTime(2024),
        targetAspectRatio: model.AspectRatio.square,
        originalAspectRatio: 1,
        playbackSpeed: 2,
      );
      final timeline = SeamTimeline(
        [clipA],
        TransitionSeamRenderService(),
        speedRenders: ClipSpeedRenderService(),
      );

      // No rendered file → live retiming, composite span == playbackDuration.
      expect(timeline.hasSeams, isFalse);
      expect(
        timeline.compositeToTimeline(const Duration(milliseconds: 750)),
        equals(const Duration(milliseconds: 750)),
      );
    });

    test('maps the mid-seam position onto the clip boundary', () {
      // 500ms dissolve on 3s clips → consumed 1000ms/side, seam 1500ms.
      final clipA = clip('a', transition: dissolve);
      final clipB = clip('b');
      final service = TransitionSeamRenderService()
        ..cacheSeamForTest(
          clipA,
          clipB,
          dissolve,
          const TransitionSeam(
            path: '/tmp/seam.mp4',
            duration: Duration(milliseconds: 1500),
            tailConsumed: Duration(milliseconds: 1000),
            headConsumed: Duration(milliseconds: 1000),
          ),
        );
      final timeline = SeamTimeline([clipA, clipB], service);

      expect(timeline.hasSeams, isTrue);
      // Body of clip A ends at composite 2000ms → editor 2000ms.
      expect(
        timeline.compositeToTimeline(const Duration(milliseconds: 2000)),
        equals(const Duration(milliseconds: 2000)),
      );
      // Mid-seam (composite 2750ms) lands on the boundary (editor 3000ms).
      expect(
        timeline.compositeToTimeline(const Duration(milliseconds: 2750)),
        equals(const Duration(seconds: 3)),
      );
      // Composite end (5500ms) → editor end (6000ms).
      expect(
        timeline.compositeToTimeline(const Duration(milliseconds: 5500)),
        equals(const Duration(seconds: 6)),
      );
      // Round-trips through the boundary.
      expect(
        timeline.timelineToComposite(const Duration(seconds: 3)),
        equals(const Duration(milliseconds: 2750)),
      );
    });

    test('splits a short middle clip between two clamped overlaps instead of '
        'replaying it, keeping the editor axis monotonic (#5487)', () {
      DivineVideoClip sized(
        String id,
        Duration duration, {
        editor.ClipTransition? transition,
      }) => DivineVideoClip(
        id: id,
        video: editor.EditorVideo.file(File('/tmp/$id.mp4')),
        duration: duration,
        recordedAt: DateTime(2024),
        targetAspectRatio: model.AspectRatio.square,
        originalAspectRatio: 1,
        transition: transition,
      );

      // A=5s, B=600ms, C=5s, 500ms dissolve on A->B and B->C. Unclamped, each
      // dissolve would consume the whole 600ms clip B, so the preview replayed
      // B in both seams (different frames + length than the export — #5487). The
      // clamp shrinks both dissolves so B's head + tail consumption fits exactly
      // (300ms each), splitting B between the two seams — played once.
      final clipA = sized(
        'a',
        const Duration(seconds: 5),
        transition: dissolve,
      );
      final clipB = sized(
        'b',
        const Duration(milliseconds: 600),
        transition: dissolve,
      );
      final clipC = sized('c', const Duration(seconds: 5));
      final clips = [clipA, clipB, clipC];

      // The seams are keyed by the clamped transition — what the canvas renders
      // and the preview plan looks up.
      final clamped = clampTransitions(clips);
      final service = TransitionSeamRenderService()
        ..cacheSeamForTest(
          clipA,
          clipB,
          clamped[clipA.id]!,
          const TransitionSeam(
            path: '/tmp/seamAB.mp4',
            duration: Duration(milliseconds: 450),
            tailConsumed: Duration(milliseconds: 300),
            headConsumed: Duration(milliseconds: 300),
          ),
        )
        ..cacheSeamForTest(
          clipB,
          clipC,
          clamped[clipB.id]!,
          const TransitionSeam(
            path: '/tmp/seamBC.mp4',
            duration: Duration(milliseconds: 450),
            tailConsumed: Duration(milliseconds: 300),
            headConsumed: Duration(milliseconds: 300),
          ),
        );

      // B is split into the two seams: A body, both seams, C body — B never
      // plays as its own body and is never replayed.
      final players = buildSeamAwarePlayerClips(clips, service);
      expect(players.map((c) => c.uri), [
        '/tmp/a.mp4',
        '/tmp/seamAB.mp4',
        '/tmp/seamBC.mp4',
        '/tmp/c.mp4',
      ]);
      expect(players.where((c) => c.uri == '/tmp/b.mp4'), isEmpty);

      // Sweep the whole composite axis; the mapped editor position must never
      // go backward.
      final timeline = SeamTimeline(clips, service);
      var previous = Duration.zero;
      for (var ms = 0; ms <= 15000; ms += 50) {
        final mapped = timeline.compositeToTimeline(Duration(milliseconds: ms));
        expect(
          mapped,
          greaterThanOrEqualTo(previous),
          reason: 'editor axis went backward at composite ${ms}ms',
        );
        previous = mapped;
      }
    });

    test('a single-clip loop wrap maps bodies 1:1 on the display axis', () {
      // The display axis excludes the wrap-consumed head/tail (they live in
      // the seam region the strip draws at the end), so the body maps 1:1 —
      // playhead X = thumbnail X = preview frame X — and the seam segment
      // covers the appended region.
      final only = clip('a', transition: dissolve);
      final service = TransitionSeamRenderService()
        ..cacheSeamForTest(
          only,
          only,
          dissolve,
          const TransitionSeam(
            path: '/tmp/wrap.mp4',
            duration: Duration(milliseconds: 800),
            tailConsumed: Duration(milliseconds: 500),
            headConsumed: Duration(milliseconds: 500),
          ),
        );
      final timeline = SeamTimeline([only], service);

      // Body (composite [0,2000]) is the identity on the display axis.
      expect(
        timeline.compositeToTimeline(Duration.zero),
        equals(Duration.zero),
      );
      expect(
        timeline.compositeToTimeline(const Duration(seconds: 1)),
        equals(const Duration(seconds: 1)),
      );
      expect(
        timeline.compositeToTimeline(const Duration(seconds: 2)),
        equals(const Duration(seconds: 2)),
      );
      // The seam plays after the body and maps onto the appended seam region.
      expect(
        timeline.compositeToTimeline(const Duration(milliseconds: 2800)),
        greaterThan(const Duration(seconds: 2)),
      );
      // Never seeks negative.
      expect(
        timeline.timelineToComposite(Duration.zero),
        equals(Duration.zero),
      );
    });
  });

  group('enforceSeamCacheLimit', () {
    late Directory tempRoot;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync('seam_cache_test_');
    });

    tearDown(() {
      if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
    });

    TransitionSeamRenderService serviceWithBudget(int budget) =>
        TransitionSeamRenderService(
          documentsDirectoryProvider: () async => tempRoot,
          maxSeamCacheBytes: budget,
        );

    Future<File> seam(String name, int bytes, DateTime modified) async {
      final dir = Directory('${tempRoot.path}/transition_seams')
        ..createSync(recursive: true);
      final file = File('${dir.path}/$name')
        ..writeAsBytesSync(List<int>.filled(bytes, 0));
      await file.setLastModified(modified);
      return file;
    }

    test('deletes least-recently-modified seams beyond the budget', () async {
      final oldest = await seam('old.mp4', 60, DateTime(2020));
      final middle = await seam('mid.mp4', 60, DateTime(2020, 1, 2));
      final newest = await seam('new.mp4', 60, DateTime(2020, 1, 3));

      await serviceWithBudget(100).enforceSeamCacheLimit();

      // 180 bytes > 100: drop oldest (→120), still over, drop middle (→60).
      expect(oldest.existsSync(), isFalse);
      expect(middle.existsSync(), isFalse);
      expect(newest.existsSync(), isTrue);
    });

    test('keeps every seam when the directory is within budget', () async {
      final a = await seam('a.mp4', 40, DateTime(2020));
      final b = await seam('b.mp4', 40, DateTime(2020, 1, 2));

      await serviceWithBudget(1000).enforceSeamCacheLimit();

      expect(a.existsSync(), isTrue);
      expect(b.existsSync(), isTrue);
    });

    test('completes when the documents directory cannot be '
        'resolved', () async {
      final service = TransitionSeamRenderService(
        documentsDirectoryProvider: () async =>
            throw const FileSystemException('unavailable'),
        maxSeamCacheBytes: 100,
      );

      await expectLater(service.enforceSeamCacheLimit(), completes);
    });

    test('clear() kicks off a trim of the persisted seam '
        'directory', () async {
      final oldest = await seam('old.mp4', 60, DateTime(2020));
      final newest = await seam('new.mp4', 60, DateTime(2020, 1, 2));

      serviceWithBudget(100).clear();

      // The trim is unawaited by design (it must not block editor teardown);
      // poll until it lands.
      for (var i = 0; i < 400 && oldest.existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      // 120 bytes > 100: drop oldest (→60), newest survives.
      expect(oldest.existsSync(), isFalse);
      expect(newest.existsSync(), isTrue);
    });
  });
}
