// ABOUTME: Tests for pasting a copied clip style: the settings landing on every
// ABOUTME: target in one emit, color masks baked or taken off per target, and a
// ABOUTME: color mask that fails leaving the rest of the style in place.

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show EqualizerSettings;
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_boomerang.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/models/video_editor/clip_style.dart';
import 'package:openvine/services/video_editor/chroma_key_bake_service.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerMask, LayerMaskShape;
import 'package:pro_video_editor/pro_video_editor.dart'
    show ChromaKey, EditorVideo;

const _key = ClipChromaKey(
  key: ChromaKey.greenScreen(backgroundColor: Color(0xFF203040)),
);
const _mask = LayerMask(shape: LayerMaskShape.heart);
const _boost = EqualizerSettings([6, 0, 0, 0, 0, 0, 0, 0, 0, 0]);

DivineVideoClip _clip(
  String id, {
  bool isFreezeFrame = false,
  ClipChromaKey? chromaKey,
  String? chromaKeySourcePath,
}) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/documents/$id.mp4'),
  duration: const Duration(seconds: 2),
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
  isFreezeFrame: isFreezeFrame,
  chromaKey: chromaKey,
  chromaKeySourcePath: chromaKeySourcePath,
);

void main() {
  group('$ClipEditorBloc style paste', () {
    ClipEditorBloc seeded(
      List<DivineVideoClip> clips, {
      ChromaKeyBakeFn? bakeChromaKey,
      DeferFileCleanupFn? deferFileCleanup,
    }) {
      final bloc = ClipEditorBloc(
        onFinalClipInvalidated: () {},
        saveClipToLibrary: ({required clip}) async => false,
        bakeChromaKey: bakeChromaKey,
        extractPoster: ({required videoPath, required timestamp}) async => null,
        deferFileCleanup: deferFileCleanup ?? (_) {},
      );
      addTearDown(bloc.close);
      return bloc..add(ClipEditorInitialized(clips));
    }

    /// Pastes [style] onto [clipIds] and waits for the paste to report.
    Future<ClipEditorState> paste(
      ClipEditorBloc bloc,
      List<String> clipIds,
      ClipStyle style,
    ) {
      final done = bloc.stream.firstWhere(
        (state) => state.lastClipStylePasteResult != null,
      );
      bloc.add(ClipEditorStylePasteRequested(clipIds: clipIds, style: style));
      return done;
    }

    test(
      'puts volume, EQ, speed and shape mask on every target at once',
      () async {
        final bloc = seeded([_clip('a'), _clip('b'), _clip('c')]);
        await pumpEventQueue();
        final untouched = bloc.state.clips[1];

        final state = await paste(
          bloc,
          ['a', 'c'],
          const ClipStyle(
            volume: 0.5,
            equalizer: _boost,
            playbackSpeed: 2,
            mask: _mask,
          ),
        );

        for (final clip in [state.clips[0], state.clips[2]]) {
          expect(clip.volume, 0.5);
          expect(clip.equalizer, _boost);
          expect(clip.playbackSpeed, 2);
          expect(clip.mask, _mask);
        }
        expect(state.clips[1], same(untouched));
        final result = state.lastClipStylePasteResult! as ClipStylePasteSuccess;
        expect(result.colorMaskFailures, 0);
        expect(result.previousClips.map((c) => c.volume), [1, 1, 1]);
      },
    );

    test('bakes the color mask into each target in turn', () async {
      final baked = <String>[];
      final bloc = seeded(
        [_clip('a'), _clip('b')],
        bakeChromaKey:
            ({
              required sourceClip,
              required chromaKey,
              required renderId,
            }) async {
              baked.add(sourceClip.id);
              return (
                video: EditorVideo.file('/documents/${sourceClip.id}_key.mp4'),
                source: sourceClip.video!.file!.path,
              );
            },
      );
      await pumpEventQueue();
      final renderIds = <String?>[];
      final sub = bloc.stream.listen(
        (s) => renderIds.add(s.clipStylePasteRenderId),
      );
      addTearDown(sub.cancel);

      final state = await paste(
        bloc,
        ['a', 'b'],
        ClipStyle.of(_clip('x', chromaKey: _key)),
      );

      expect(baked, ['a', 'b']);
      expect(
        renderIds,
        containsAllInOrder([
          ChromaKeyBakeService.renderIdFor('a'),
          ChromaKeyBakeService.renderIdFor('b'),
        ]),
      );
      expect(state.clips.map((c) => c.chromaKey), [_key, _key]);
      expect(state.clips.map((c) => c.video?.file?.path), [
        '/documents/a_key.mp4',
        '/documents/b_key.mp4',
      ]);
      expect(state.isPastingClipStyle, isFalse);
    });

    test('a color mask baked onto a boomerang drops its record', () async {
      // The key lands on the bounced footage. Turning the boomerang off would
      // put back the footage before it, unkeyed, and drop the mask.
      final bloc = seeded(
        [
          _clip('a').copyWith(
            boomerang: const ClipBoomerang(
              sourcePath: '/documents/a_take.mp4',
              sourceDuration: Duration(seconds: 1),
            ),
          ),
        ],
        bakeChromaKey:
            ({
              required sourceClip,
              required chromaKey,
              required renderId,
            }) async => (
              video: EditorVideo.file('/documents/a_key.mp4'),
              source: sourceClip.video!.file!.path,
            ),
      );
      await pumpEventQueue();

      final state = await paste(
        bloc,
        ['a'],
        ClipStyle.of(_clip('x', chromaKey: _key)),
      );

      final clip = state.clips.single;
      expect(clip.chromaKey, _key);
      expect(clip.video?.file?.path, '/documents/a_key.mp4');
      expect(clip.boomerang, isNull);
    });

    test(
      'a target whose color mask fails keeps its own and takes the rest',
      () async {
        final bloc = seeded(
          [_clip('a'), _clip('b')],
          bakeChromaKey:
              ({
                required sourceClip,
                required chromaKey,
                required renderId,
              }) async {
                if (sourceClip.id == 'b') throw Exception('render failed');
                return (
                  video: EditorVideo.file('/documents/a_key.mp4'),
                  source: sourceClip.video!.file!.path,
                );
              },
        );
        await pumpEventQueue();

        final state = await paste(
          bloc,
          ['a', 'b'],
          const ClipStyle(
            volume: 0.2,
            equalizer: EqualizerSettings.none,
            playbackSpeed: 1,
            chromaKey: _key,
          ),
        );

        expect(state.clips.map((c) => c.chromaKey), [_key, null]);
        expect(state.clips.map((c) => c.volume), [0.2, 0.2]);
        final result = state.lastClipStylePasteResult! as ClipStylePasteSuccess;
        expect(result.colorMaskFailures, 1);
      },
    );

    test(
      'queues the color mask made for a target deleted during its render',
      () async {
        final bRender = Completer<void>();
        final deferred = <String?>[];
        late final ClipEditorBloc bloc;
        bloc = seeded(
          [_clip('a'), _clip('b')],
          bakeChromaKey:
              ({
                required sourceClip,
                required chromaKey,
                required renderId,
              }) async {
                if (sourceClip.id == 'b') {
                  bloc.add(const ClipEditorClipRemoved('b'));
                  await bRender.future;
                }
                return (
                  video: EditorVideo.file(
                    '/documents/${sourceClip.id}_key.mp4',
                  ),
                  source: sourceClip.video!.file!.path,
                );
              },
          deferFileCleanup: deferred.addAll,
        );
        await pumpEventQueue();

        final done = paste(
          bloc,
          ['a', 'b'],
          const ClipStyle(
            volume: 1,
            equalizer: EqualizerSettings.none,
            playbackSpeed: 1,
            chromaKey: _key,
          ),
        );
        await pumpEventQueue();
        expect(bloc.state.clips.map((c) => c.id), ['a']);
        bRender.complete();
        final state = await done;

        expect(state.clips.single.video?.file?.path, '/documents/a_key.mp4');
        expect(deferred, contains('/documents/b_key.mp4'));
        expect(deferred, isNot(contains('/documents/a_key.mp4')));
      },
    );

    test(
      'takes a color mask off by putting the unmasked footage back',
      () async {
        final dir = Directory.systemTemp.createTempSync('style_paste');
        addTearDown(() => dir.deleteSync(recursive: true));
        final unmasked = File('${dir.path}/raw.mp4')..writeAsStringSync('raw');
        final bloc = seeded([
          _clip('a', chromaKey: _key, chromaKeySourcePath: unmasked.path),
        ]);
        await pumpEventQueue();

        final state = await paste(bloc, ['a'], ClipStyle.of(_clip('plain')));

        expect(state.clips.single.chromaKey, isNull);
        expect(state.clips.single.video?.file?.path, unmasked.path);
      },
    );

    test('a freeze frame takes only the shape mask', () async {
      final bloc = seeded([_clip('a', isFreezeFrame: true)]);
      await pumpEventQueue();

      final state = await paste(
        bloc,
        ['a'],
        const ClipStyle(
          volume: 0.2,
          equalizer: _boost,
          playbackSpeed: 3,
          chromaKey: _key,
          mask: _mask,
        ),
      );

      final clip = state.clips.single;
      expect(clip.mask, _mask);
      expect(clip.volume, 1);
      expect(clip.equalizer, EqualizerSettings.none);
      expect(clip.playbackSpeed, isNull);
      expect(clip.chromaKey, isNull);
    });

    test('changes nothing when every target already matches', () async {
      final bloc = seeded([_clip('a'), _clip('b')]);
      await pumpEventQueue();
      final before = bloc.state;
      expect(before.clips, hasLength(2));

      bloc.add(
        ClipEditorStylePasteRequested(
          clipIds: const ['a', 'b'],
          style: ClipStyle.of(_clip('x')),
        ),
      );
      await pumpEventQueue();

      expect(bloc.state, same(before));
    });
  });
}
