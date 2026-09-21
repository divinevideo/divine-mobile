import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/clip_speed_render_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as editor;

class _FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProviderPlatform({
    required this.temporaryPath,
    required this.documentsPath,
  });

  final String temporaryPath;
  final String documentsPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;

  @override
  Future<String?> getApplicationCachePath() async =>
      p.join(p.dirname(temporaryPath), 'cache');
}

class _FakeProVideoEditor extends editor.ProVideoEditor {
  final renderStarted = <Completer<void>>[];
  final allowRenderToFinish = <Completer<void>>[];
  int renderCount = 0;

  /// The task id of every render started, in order.
  final renderedTaskIds = <String>[];

  /// Task ids the service asked to cancel, in order.
  final cancelledTaskIds = <String>[];

  Completer<void> renderStartedAt(int index) {
    while (renderStarted.length <= index) {
      renderStarted.add(Completer<void>());
    }
    return renderStarted[index];
  }

  Completer<void> allowRenderToFinishAt(int index) {
    while (allowRenderToFinish.length <= index) {
      allowRenderToFinish.add(Completer<void>());
    }
    return allowRenderToFinish[index];
  }

  @override
  void initializeStream() {}

  @override
  Future<void> cancel(String taskId) async => cancelledTaskIds.add(taskId);

  @override
  Future<String> renderVideoToFile(
    String filePath,
    editor.VideoRenderData value, {
    editor.NativeLogLevel? nativeLogLevel,
  }) async {
    final renderIndex = renderCount++;
    renderedTaskIds.add(value.id);
    renderStartedAt(renderIndex).complete();
    await allowRenderToFinishAt(renderIndex).future;
    // Synchronous so a render released under `fakeAsync` settles on the
    // microtask queue alone; real disk I/O never completes inside it.
    File(filePath).writeAsStringSync('rendered speed body');
    return filePath;
  }

  @override
  Future<editor.VideoMetadata> getMetadata(
    editor.EditorVideo value, {
    bool checkStreamingOptimization = false,
    editor.NativeLogLevel? nativeLogLevel,
  }) async {
    return editor.VideoMetadata(
      duration: const Duration(milliseconds: 1500),
      extension: 'mp4',
      fileSize: 1024,
      resolution: const Size(1080, 1920),
      rotation: 0,
      bitrate: 1_000_000,
    );
  }
}

void main() {
  late Directory tempDir;
  late PathProviderPlatform originalPathProvider;
  late editor.ProVideoEditor originalProVideoEditor;

  DivineVideoClip clip(
    String id, {
    double? playbackSpeed,
    Duration trimStart = Duration.zero,
    Duration trimEnd = Duration.zero,
    String? path,
  }) => DivineVideoClip(
    id: id,
    video: editor.EditorVideo.file(File(path ?? '/tmp/$id.mp4')),
    duration: const Duration(seconds: 3),
    recordedAt: DateTime(2024),
    targetAspectRatio: model.AspectRatio.square,
    originalAspectRatio: 1,
    playbackSpeed: playbackSpeed,
    trimStart: trimStart,
    trimEnd: trimEnd,
  );

  const rendered = RenderedSpeedClip(
    path: '/tmp/a_speed.mp4',
    duration: Duration(milliseconds: 1500),
  );

  group(ClipSpeedRenderService, () {
    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      originalPathProvider = PathProviderPlatform.instance;
      originalProVideoEditor = editor.ProVideoEditor.instance;
      tempDir = await Directory.systemTemp.createTemp(
        'clip_speed_render_service_test_',
      );
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        temporaryPath: p.join(tempDir.path, 'tmp'),
        documentsPath: p.join(tempDir.path, 'documents'),
      );
      await Directory(p.join(tempDir.path, 'tmp')).create(recursive: true);
      await Directory(
        p.join(tempDir.path, 'documents'),
      ).create(recursive: true);
    });

    tearDown(() async {
      PathProviderPlatform.instance = originalPathProvider;
      editor.ProVideoEditor.instance = originalProVideoEditor;
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    group('cached', () {
      test('returns the seeded render for a non-1× clip', () {
        final c = clip('a', playbackSpeed: 2);
        final service = ClipSpeedRenderService()..cacheForTest(c, rendered);

        expect(service.cached(c), same(rendered));
      });

      test('returns null for a clip at the default (1×) speed', () {
        final c = clip('a'); // playbackSpeed null == 1×
        final service = ClipSpeedRenderService()..cacheForTest(c, rendered);

        expect(service.cached(c), isNull);
      });

      test('returns null for an explicit 1.0× clip', () {
        final c = clip('a', playbackSpeed: 1);
        final service = ClipSpeedRenderService()..cacheForTest(c, rendered);

        expect(service.cached(c), isNull);
      });

      test('misses the cache when the speed changes', () {
        final slow = clip('a', playbackSpeed: 2);
        final faster = clip('a', playbackSpeed: 3);
        final service = ClipSpeedRenderService()..cacheForTest(slow, rendered);

        expect(service.cached(slow), same(rendered));
        expect(service.cached(faster), isNull);
      });

      test('misses the cache when the trim changes', () {
        final untrimmed = clip('a', playbackSpeed: 2);
        final trimmed = clip(
          'a',
          playbackSpeed: 2,
          trimStart: const Duration(milliseconds: 500),
        );
        final service = ClipSpeedRenderService()
          ..cacheForTest(untrimmed, rendered);

        expect(service.cached(untrimmed), same(rendered));
        expect(service.cached(trimmed), isNull);
      });

      test('misses the cache when the source file changes (e.g. reverse)', () {
        final forward = clip('a', playbackSpeed: 2);
        final reversed = clip(
          'a',
          playbackSpeed: 2,
          path: '/tmp/a_reversed.mp4',
        );
        final service = ClipSpeedRenderService()
          ..cacheForTest(forward, rendered);

        expect(service.cached(forward), same(rendered));
        expect(service.cached(reversed), isNull);
      });
    });

    group('render', () {
      test('short-circuits to null for a 1× clip without touching native', () {
        final service = ClipSpeedRenderService();

        expect(service.render(clip('a')), completion(isNull));
        expect(service.isRendering(clip('a')), isFalse);
      });

      test('reuses one render for clips that differ only by id', () async {
        final native = _FakeProVideoEditor();
        editor.ProVideoEditor.instance = native;
        final service = ClipSpeedRenderService();

        // A duplicated / re-split clip: fresh id, byte-identical body.
        final original = clip('a', playbackSpeed: 2);
        final duplicate = clip(
          'a_copy_123',
          playbackSpeed: 2,
          path: '/tmp/a.mp4',
        );

        final first = service.render(original);
        await pumpEventQueue();
        native.allowRenderToFinishAt(0).complete();
        await first;

        expect(service.cached(duplicate), isNotNull);
        await expectLater(service.render(duplicate), completes);
        expect(
          native.renderCount,
          1,
          reason: 'the duplicate must reuse the original body, not re-encode',
        );
      });

      test(
        'caps concurrent native renders so the encoder does not stall',
        () async {
          final native = _FakeProVideoEditor();
          editor.ProVideoEditor.instance = native;
          final service = ClipSpeedRenderService();

          final pending = [
            for (var i = 0; i < 3; i++)
              service.render(clip('a$i', playbackSpeed: 2)),
          ];
          // Both slots have to be occupied before the cap means anything, and
          // the fake says so itself. pumpEventQueue only drains the microtask
          // queue a fixed number of times, which is a race against the awaits
          // the service makes on the way to the encoder.
          await native.renderStartedAt(1).future;
          await pumpEventQueue();

          expect(
            native.renderCount,
            2,
            reason:
                'the third clip must queue instead of opening a 3rd session',
          );

          // Freeing one slot lets exactly one queued clip through; wait on
          // the fake's own start signal rather than a pumpEventQueue race.
          native.allowRenderToFinishAt(0).complete();
          await native.renderStartedAt(2).future;
          expect(native.renderCount, 3);

          native
            ..allowRenderToFinishAt(1).complete()
            ..allowRenderToFinishAt(2).complete();
          await Future.wait(pending);
        },
      );

      test('drops queued renders once the editor closes', () async {
        final native = _FakeProVideoEditor();
        editor.ProVideoEditor.instance = native;
        final service = ClipSpeedRenderService();

        final pending = [
          for (var i = 0; i < 3; i++)
            service.render(clip('a$i', playbackSpeed: 2)),
        ];
        await native.renderStartedAt(1).future;
        await pumpEventQueue();
        expect(native.renderCount, 2);

        // Closing the editor must not let the backlog keep encoding.
        service.clear();
        native
          ..allowRenderToFinishAt(0).complete()
          ..allowRenderToFinishAt(1).complete();
        await Future.wait(pending);
        await pumpEventQueue();

        expect(
          native.renderCount,
          2,
          reason: 'the queued third clip must be abandoned, not encoded',
        );
      });
    });

    group('render bound', () {
      test('a render that never settles fails at the preview bound, gives its '
          'slot back and cancels its own native task', () {
        fakeAsync((async) {
          final native = _FakeProVideoEditor();
          editor.ProVideoEditor.instance = native;
          final service = ClipSpeedRenderService();
          final stalled = clip('a', playbackSpeed: 2);
          var settled = false;
          RenderedSpeedClip? result;

          // The stalled render and a healthy one take both slots; the healthy
          // one finishes its encode well inside the bound.
          unawaited(
            service.render(stalled).then((rendered) {
              settled = true;
              result = rendered;
            }),
          );
          unawaited(service.render(clip('b', playbackSpeed: 2)));
          async.flushMicrotasks();
          expect(native.renderCount, 2);
          expect(service.isRendering(stalled), isTrue);
          native.allowRenderToFinishAt(1).complete();
          async.flushMicrotasks();

          async.elapse(VideoEditorConstants.previewRenderWatchdogTimeout);
          async.flushMicrotasks();

          expect(settled, isTrue);
          expect(result, isNull);
          expect(
            service.isRendering(stalled),
            isFalse,
            reason: 'a timed-out clip must be free to render again',
          );
          expect(native.renderedTaskIds.first, startsWith('speed_'));
          expect(
            native.cancelledTaskIds,
            [native.renderedTaskIds.first],
            reason: 'only the stalled render is cancelled, not the healthy one',
          );

          // Both slots are free again: a leaked slot would let only one of
          // the next two clips start.
          unawaited(service.render(clip('c', playbackSpeed: 2)));
          unawaited(service.render(clip('d', playbackSpeed: 2)));
          async.flushMicrotasks();
          expect(
            native.renderCount,
            4,
            reason: 'the slot the stalled render held must be given back',
          );
        });
      });

      test('retries a timed-out clip under a fresh native task id', () {
        fakeAsync((async) {
          final native = _FakeProVideoEditor();
          editor.ProVideoEditor.instance = native;
          final service = ClipSpeedRenderService();
          final stalled = clip('a', playbackSpeed: 2);

          unawaited(service.render(stalled));
          async.elapse(VideoEditorConstants.previewRenderWatchdogTimeout);
          async.flushMicrotasks();
          expect(native.renderedTaskIds, hasLength(1));

          // The next timeline change asks for the same body again. It has to
          // reach the encoder (not the stale in-flight future) and under an id
          // of its own: the plugin holds a restart of a cancelled id until the
          // cancelled pipeline reports back, which a stalled one never does.
          unawaited(service.render(stalled));
          async.flushMicrotasks();

          expect(native.renderedTaskIds, hasLength(2));
          expect(native.renderedTaskIds[1], startsWith('speed_'));
          expect(native.renderedTaskIds[1], isNot(native.renderedTaskIds[0]));
          expect(service.isRendering(stalled), isTrue);
        });
      });
    });

    group('clear', () {
      test('seeded entry is cached, then dropped after clear', () {
        final c = clip('a', playbackSpeed: 2);
        final service = ClipSpeedRenderService()..cacheForTest(c, rendered);

        expect(service.cached(c), same(rendered));

        service.clear();
        expect(service.cached(c), isNull);
      });
    });

    group('disk cleanup', () {
      test(
        'renders speed files under temporary cache instead of documents',
        () async {
          final c = clip(
            'a',
            playbackSpeed: 2,
            path: p.join(tempDir.path, 'source.mp4'),
          );
          File(c.video!.file!.path).writeAsStringSync('source');
          final fakeEditor = _FakeProVideoEditor();
          editor.ProVideoEditor.instance = fakeEditor;
          final service = ClipSpeedRenderService();

          final render = service.render(c);
          await fakeEditor.renderStartedAt(0).future;
          fakeEditor.allowRenderToFinishAt(0).complete();
          final rendered = await render;

          expect(rendered, isNotNull);
          expect(
            p.isWithin(
              p.join(tempDir.path, 'tmp', 'speed_clips'),
              rendered!.path,
            ),
            isTrue,
          );
          expect(
            Directory(
              p.join(tempDir.path, 'documents', 'speed_clips'),
            ).existsSync(),
            isFalse,
          );
        },
      );

      test('clear removes cached rendered speed files from disk', () {
        final c = clip('a', playbackSpeed: 2);
        final file = File(p.join(tempDir.path, 'tmp', 'speed_clips', 'a.mp4'))
          ..createSync(recursive: true)
          ..writeAsStringSync('rendered speed body');
        final service = ClipSpeedRenderService()
          ..cacheForTest(
            c,
            RenderedSpeedClip(
              path: file.path,
              duration: const Duration(milliseconds: 1500),
            ),
          );

        service.clear();

        expect(file.existsSync(), isFalse);
        expect(service.cached(c), isNull);
      });

      test(
        'clear prevents an in-flight render from publishing a file',
        () async {
          final c = clip(
            'a',
            playbackSpeed: 2,
            path: p.join(tempDir.path, 'source.mp4'),
          );
          File(c.video!.file!.path).writeAsStringSync('source');
          final fakeEditor = _FakeProVideoEditor();
          editor.ProVideoEditor.instance = fakeEditor;
          final service = ClipSpeedRenderService();

          final render = service.render(c);
          await fakeEditor.renderStartedAt(0).future;
          service.clear();

          fakeEditor.allowRenderToFinishAt(0).complete();
          final rendered = await render;

          expect(rendered, isNull);
          expect(service.cached(c), isNull);
          expect(
            Directory(p.join(tempDir.path, 'tmp', 'speed_clips')).existsSync(),
            isFalse,
          );
        },
      );

      test(
        'a stale render does not unregister the replacement in-flight render',
        () async {
          final c = clip(
            'a',
            playbackSpeed: 2,
            path: p.join(tempDir.path, 'source.mp4'),
          );
          File(c.video!.file!.path).writeAsStringSync('source');
          final fakeEditor = _FakeProVideoEditor();
          editor.ProVideoEditor.instance = fakeEditor;
          final service = ClipSpeedRenderService();

          final staleRender = service.render(c);
          await fakeEditor.renderStartedAt(0).future;
          service.clear();

          final replacementRender = service.render(c);
          await fakeEditor.renderStartedAt(1).future;
          fakeEditor.allowRenderToFinishAt(0).complete();
          await staleRender;

          expect(service.isRendering(c), isTrue);
          expect(service.render(c), same(replacementRender));

          fakeEditor.allowRenderToFinishAt(1).complete();
          expect(await replacementRender, isNotNull);
          expect(service.isRendering(c), isFalse);
        },
      );
    });

    group('eviction', () {
      RenderedSpeedClip seedFile(String name) {
        final file = File(p.join(tempDir.path, 'tmp', 'speed_clips', name))
          ..createSync(recursive: true)
          ..writeAsStringSync('body');
        return RenderedSpeedClip(
          path: file.path,
          duration: const Duration(milliseconds: 1500),
        );
      }

      test('evicts the least-recently-used body — file and cache entry '
          'together — once the cap is exceeded', () {
        final service = ClipSpeedRenderService();
        final clips = <DivineVideoClip>[];
        final rendereds = <RenderedSpeedClip>[];
        // Seed one past the cap (33 entries): the oldest must be evicted.
        for (var i = 0; i <= 32; i++) {
          final c = clip('a$i', playbackSpeed: 2);
          final r = seedFile('a$i.mp4');
          clips.add(c);
          rendereds.add(r);
          service.cacheForTest(c, r);
        }

        // Evicted entries are dropped from the in-memory cache AND from disk,
        // so a lookup can never resolve to a dead path.
        expect(service.cached(clips.first), isNull);
        expect(File(rendereds.first.path).existsSync(), isFalse);
        // The most-recent entry survives with its file intact.
        expect(service.cached(clips.last), same(rendereds.last));
        expect(File(rendereds.last.path).existsSync(), isTrue);
      });

      test('promotes on lookup so an in-use body is not the one evicted', () {
        final service = ClipSpeedRenderService();
        final clips = <DivineVideoClip>[];
        final rendereds = <RenderedSpeedClip>[];
        for (var i = 0; i < 32; i++) {
          final c = clip('a$i', playbackSpeed: 2);
          final r = seedFile('a$i.mp4');
          clips.add(c);
          rendereds.add(r);
          service.cacheForTest(c, r);
        }

        // Touch the oldest so it becomes most-recently-used.
        expect(service.cached(clips.first), same(rendereds.first));

        // One more push over the cap evicts the now-oldest (a1), not the
        // promoted a0.
        service.cacheForTest(
          clip('a32', playbackSpeed: 2),
          seedFile('a32.mp4'),
        );

        expect(service.cached(clips.first), same(rendereds.first));
        expect(service.cached(clips[1]), isNull);
        expect(File(rendereds[1].path).existsSync(), isFalse);
      });
    });
  });
}
