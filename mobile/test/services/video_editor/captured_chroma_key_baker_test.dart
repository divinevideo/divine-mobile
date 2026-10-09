import 'dart:async';
import 'dart:ui';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/c2pa_edit_source.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/services/video_editor/captured_chroma_key_baker.dart';
import 'package:openvine/services/video_editor/chroma_key_bake_service.dart';
import 'package:openvine/services/video_editor/video_render_failures.dart';
import 'package:openvine/services/video_thumbnail_service.dart'
    show ThumbnailFileResult;
import 'package:pro_video_editor/pro_video_editor.dart'
    show ChromaKey, EditorVideo;

const _recordedKey = ClipChromaKey(
  key: ChromaKey.greenScreen(backgroundColor: Color(0xFF203040)),
);

DivineVideoClip _take(String id) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/documents/$id.mp4'),
  duration: const Duration(seconds: 2),
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
  thumbnailPath: '/documents/${id}_raw.jpg',
  captureChromaKey: _recordedKey,
);

({EditorVideo video, String source}) _keyedFile(DivineVideoClip clip) => (
  video: EditorVideo.file('/documents/${clip.id}_keyed.mp4'),
  source: clip.video!.file!.path,
);

Future<ThumbnailFileResult?> _poster({
  required String videoPath,
  required Duration timestamp,
}) async => ThumbnailFileResult(
  path: videoPath.replaceAll('.mp4', '.jpg'),
  timestamp: timestamp,
);

void main() {
  group('bakePendingCapturedChromaKeys', () {
    test('bakes only the takes still waiting on their key', () async {
      final plain = _take('plain').copyWith(clearCaptureChromaKey: true);
      final asked = <String>[];

      final clips = await bakePendingCapturedChromaKeys(
        [plain, _take('pending')],
        (clip) async {
          asked.add(clip.id);
          return clip.copyWith(
            video: EditorVideo.file('/documents/${clip.id}_keyed.mp4'),
            chromaKey: clip.captureChromaKey,
            chromaKeySourcePath: clip.video!.file!.path,
            clearCaptureChromaKey: true,
          );
        },
      );

      expect(asked, ['pending']);
      expect(clips.first, same(plain));
      expect(clips.last.video?.file?.path, '/documents/pending_keyed.mp4');
      expect(clips.last.chromaKey, _recordedKey);
    });
  });

  group(CapturedChromaKeyBaker, () {
    group('bake', () {
      test('returns the take with its recorded key burned in', () async {
        ClipChromaKey? renderedKey;
        final baker = CapturedChromaKeyBaker(
          render:
              ({
                required sourceClip,
                required chromaKey,
                required renderId,
              }) async {
                renderedKey = chromaKey;
                expect(renderId, ChromaKeyBakeService.renderIdFor('a'));
                return _keyedFile(sourceClip);
              },
          extractPoster: _poster,
          cancelRender: (_) async {},
        );

        final keyed = await baker.bake(_take('a'));

        expect(renderedKey, _recordedKey);
        expect(keyed.video?.file?.path, '/documents/a_keyed.mp4');
        expect(keyed.chromaKey, _recordedKey);
        expect(keyed.chromaKeySourcePath, '/documents/a.mp4');
        // Signed against the raw take, which carries the camera proof.
        expect(keyed.derivedFrom, const [
          C2paEditSource(path: '/documents/a.mp4'),
        ]);
        expect(keyed.captureChromaKey, isNull);
        // The raw poster shows the wall the key removed.
        expect(keyed.thumbnailPath, '/documents/a_keyed.jpg');
      });

      test('keeps the old poster when none can be taken', () async {
        final baker = CapturedChromaKeyBaker(
          render: ({
            required sourceClip,
            required chromaKey,
            required renderId,
          }) async => _keyedFile(sourceClip),
          extractPoster: ({required videoPath, required timestamp}) async =>
              throw Exception('decoder gone'),
          cancelRender: (_) async {},
        );

        final keyed = await baker.bake(_take('a'));

        expect(keyed.thumbnailPath, '/documents/a_raw.jpg');
        expect(keyed.chromaKey, _recordedKey);
      });

      test('bakes one take at a time', () async {
        final gates = {'a': Completer<void>(), 'b': Completer<void>()};
        final started = <String>[];
        final baker = CapturedChromaKeyBaker(
          render:
              ({
                required sourceClip,
                required chromaKey,
                required renderId,
              }) async {
                started.add(sourceClip.id);
                await gates[sourceClip.id]!.future;
                return _keyedFile(sourceClip);
              },
          extractPoster: _poster,
          cancelRender: (_) async {},
        );

        final first = baker.bake(_take('a'));
        final second = baker.bake(_take('b'));
        await pumpEventQueue();
        expect(started, ['a']);

        gates['a']!.complete();
        await first;
        await pumpEventQueue();
        expect(started, ['a', 'b']);

        gates['b']!.complete();
        expect((await second).chromaKey, _recordedKey);
      });

      test(
        'reports a failed render and carries on with the next take',
        () async {
          final baker = CapturedChromaKeyBaker(
            render:
                ({
                  required sourceClip,
                  required chromaKey,
                  required renderId,
                }) async {
                  if (sourceClip.id == 'broken') {
                    throw StateError('render failed');
                  }
                  return _keyedFile(sourceClip);
                },
            extractPoster: _poster,
            cancelRender: (_) async {},
          );

          final broken = baker.bake(_take('broken'));
          final fine = baker.bake(_take('fine'));

          await expectLater(broken, throwsStateError);
          expect((await fine).chromaKey, _recordedKey);
        },
      );

      test('gives up on a render that never settles and bakes the next', () {
        fakeAsync((async) {
          final cancelled = <String>[];
          final baker = CapturedChromaKeyBaker(
            render:
                ({
                  required sourceClip,
                  required chromaKey,
                  required renderId,
                }) => sourceClip.id == 'stalled'
                ? Completer<({EditorVideo video, String source})>().future
                : Future.value(_keyedFile(sourceClip)),
            extractPoster: _poster,
            cancelRender: (renderId) async => cancelled.add(renderId),
          );
          Object? stalledError;
          DivineVideoClip? next;
          unawaited(
            baker
                .bake(_take('stalled'))
                .then<void>(
                  (_) {},
                  onError: (Object error) => stalledError = error,
                ),
          );
          unawaited(baker.bake(_take('next')).then((clip) => next = clip));

          async.elapse(VideoEditorConstants.previewRenderWatchdogTimeout);
          async.flushMicrotasks();

          expect(stalledError, isA<VideoRenderFailedException>());
          expect(cancelled, [ChromaKeyBakeService.renderIdFor('stalled')]);
          expect(next?.chromaKey, _recordedKey);
        });
      });

      test('refuses a clip with no key waiting', () {
        final baker = CapturedChromaKeyBaker(
          render: ({
            required sourceClip,
            required chromaKey,
            required renderId,
          }) async => _keyedFile(sourceClip),
          extractPoster: _poster,
          cancelRender: (_) async {},
        );

        expect(
          () => baker.bake(_take('a').copyWith(clearCaptureChromaKey: true)),
          throwsArgumentError,
        );
      });
    });

    group('hold', () {
      test('keeps a bake from starting until released', () async {
        var renders = 0;
        final baker = CapturedChromaKeyBaker(
          render:
              ({
                required sourceClip,
                required chromaKey,
                required renderId,
              }) async {
                renders++;
                return _keyedFile(sourceClip);
              },
          extractPoster: _poster,
          cancelRender: (_) async {},
        )..hold();

        final keyed = baker.bake(_take('a'));
        await pumpEventQueue();
        expect(renders, 0);
        expect(baker.isHeld, isTrue);

        baker.release();

        expect((await keyed).chromaKey, _recordedKey);
        expect(renders, 1);
      });

      test(
        'stops the render in flight and starts it over on release',
        () async {
          final cancelled = <String>[];
          final firstAttempt =
              Completer<({EditorVideo video, String source})>();
          var attempts = 0;
          final baker = CapturedChromaKeyBaker(
            render:
                ({required sourceClip, required chromaKey, required renderId}) {
                  attempts++;
                  return attempts == 1
                      ? firstAttempt.future
                      : Future.value(_keyedFile(sourceClip));
                },
            extractPoster: _poster,
            cancelRender: (renderId) async {
              cancelled.add(renderId);
              firstAttempt.completeError(Exception('render cancelled'));
            },
          );

          final keyed = baker.bake(_take('a'));
          await pumpEventQueue();
          baker.hold();
          await pumpEventQueue();

          // The camera gets the encoder; the bake waits instead of failing.
          expect(cancelled, [ChromaKeyBakeService.renderIdFor('a')]);
          expect(attempts, 1);

          baker.release();

          expect((await keyed).video?.file?.path, '/documents/a_keyed.mp4');
          expect(attempts, 2);
        },
      );

      test('fails a later render instead of retrying it forever', () async {
        final firstAttempt = Completer<({EditorVideo video, String source})>();
        var attempts = 0;
        var attemptsOfB = 0;
        final baker = CapturedChromaKeyBaker(
          render:
              ({required sourceClip, required chromaKey, required renderId}) {
                attempts++;
                if (sourceClip.id == 'a' && attempts == 1) {
                  return firstAttempt.future;
                }
                // Only the first try fails: a baker that wrongly retries it
                // then resolves and fails this test, instead of looping
                // forever and starving the test's own timeout.
                if (sourceClip.id == 'b' && ++attemptsOfB == 1) {
                  throw StateError('render failed');
                }
                return Future.value(_keyedFile(sourceClip));
              },
          extractPoster: _poster,
          cancelRender: (_) async =>
              firstAttempt.completeError(Exception('render cancelled')),
        );

        final a = baker.bake(_take('a'));
        await pumpEventQueue();
        baker
          ..hold()
          ..release();
        await a;
        final before = attempts;

        // Nothing holds this one, so its failure is a failure, not a
        // postponement.
        await expectLater(baker.bake(_take('b')), throwsStateError);
        expect(attempts, before + 1);
      });
    });
  });
}
