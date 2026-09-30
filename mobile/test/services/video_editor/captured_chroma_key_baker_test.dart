import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/services/video_editor/captured_chroma_key_baker.dart';
import 'package:openvine/services/video_editor/chroma_key_bake_service.dart';
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
    });
  });
}
