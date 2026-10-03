import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart'
    show LocalizedText, StickerData, StickerPackData;
import 'package:openvine/extensions/complete_parameters_extensions.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

CompleteParameters _makeParams({
  double blur = 0,
  List<List<double>>? matrixFilterList,
  List<List<double>>? matrixTuneAdjustmentsList,
  Duration? startTime,
  Duration? endTime,
  int? cropWidth,
  int? cropHeight,
  int rotateTurns = 0,
  int? cropX,
  int? cropY,
  bool flipX = false,
  bool flipY = false,
  Uint8List? image,
  bool isTransformed = false,
  List<Layer>? layers,
  List<VideoClip>? videoClips,
  List<AudioTrack>? audioTracks,
  Map<String, dynamic>? meta,
}) {
  return CompleteParameters(
    meta: meta ?? const {},
    blur: blur,
    originalImageSize: const Size(1080, 1920),
    temporaryDecodedImageSize: const Size(1080, 1920),
    bodySize: const Size(400, 800),
    editorSize: const Size(400, 800),
    matrixFilterList: matrixFilterList ?? const [],
    matrixTuneAdjustmentsList: matrixTuneAdjustmentsList ?? const [],
    startTime: startTime,
    endTime: endTime,
    cropWidth: cropWidth,
    cropHeight: cropHeight,
    rotateTurns: rotateTurns,
    cropX: cropX,
    cropY: cropY,
    flipX: flipX,
    flipY: flipY,
    image: image ?? Uint8List(0),
    isTransformed: isTransformed,
    layers: layers ?? const [],
    videoClips: videoClips ?? const [],
    audioTracks: audioTracks ?? const [],
  );
}

AudioTrack _makeAudioTrack({String id = 'a1'}) {
  return AudioTrack(
    id: id,
    title: 'track',
    subtitle: 'artist',
    duration: const Duration(seconds: 30),
    audio: EditorAudio.asset('audio.mp3'),
  );
}

VideoClip _makeVideoClip({String id = 'v1'}) {
  return VideoClip(
    id: id,
    title: 'clip',
    clip: EditorVideoClip.asset('clip.mp4'),
    duration: const Duration(seconds: 10),
  );
}

void main() {
  group('CompleteParametersEquality', () {
    group('deepEquals', () {
      test('returns true for identical references', () {
        final params = _makeParams();
        expect(params.deepEquals(params), isTrue);
      });

      test('returns true for two equal instances', () {
        final a = _makeParams(blur: 2, flipX: true);
        final b = _makeParams(blur: 2, flipX: true);
        expect(a.deepEquals(b), isTrue);
      });

      test('returns true when image bytes are equal '
          'but different Uint8List instances', () {
        final a = _makeParams(image: Uint8List.fromList([1, 2, 3]));
        final b = _makeParams(image: Uint8List.fromList([1, 2, 3]));
        // Built-in == would fail here because Uint8List uses identity.
        expect(a.deepEquals(b), isTrue);
      });

      test('returns false when image bytes differ', () {
        final a = _makeParams(image: Uint8List.fromList([1, 2, 3]));
        final b = _makeParams(image: Uint8List.fromList([4, 5, 6]));
        expect(a.deepEquals(b), isFalse);
      });

      test('returns false when blur differs', () {
        expect(_makeParams(blur: 1).deepEquals(_makeParams(blur: 2)), isFalse);
      });

      test('returns false when startTime differs', () {
        expect(
          _makeParams(
            startTime: const Duration(seconds: 1),
          ).deepEquals(_makeParams(startTime: const Duration(seconds: 2))),
          isFalse,
        );
      });

      test('returns false when endTime differs', () {
        expect(
          _makeParams(
            endTime: const Duration(seconds: 5),
          ).deepEquals(_makeParams(endTime: const Duration(seconds: 10))),
          isFalse,
        );
      });

      test('returns false when cropWidth differs', () {
        expect(
          _makeParams(cropWidth: 100).deepEquals(_makeParams(cropWidth: 200)),
          isFalse,
        );
      });

      test('returns false when cropHeight differs', () {
        expect(
          _makeParams(cropHeight: 100).deepEquals(_makeParams(cropHeight: 200)),
          isFalse,
        );
      });

      test('returns false when rotateTurns differs', () {
        expect(
          _makeParams(rotateTurns: 1).deepEquals(_makeParams(rotateTurns: 3)),
          isFalse,
        );
      });

      test('returns false when cropX differs', () {
        expect(
          _makeParams(cropX: 10).deepEquals(_makeParams(cropX: 20)),
          isFalse,
        );
      });

      test('returns false when cropY differs', () {
        expect(
          _makeParams(cropY: 10).deepEquals(_makeParams(cropY: 20)),
          isFalse,
        );
      });

      test('returns false when flipX differs', () {
        expect(_makeParams(flipX: true).deepEquals(_makeParams()), isFalse);
      });

      test('returns false when flipY differs', () {
        expect(_makeParams(flipY: true).deepEquals(_makeParams()), isFalse);
      });

      test('returns false when isTransformed differs', () {
        expect(
          _makeParams(isTransformed: true).deepEquals(_makeParams()),
          isFalse,
        );
      });

      test('returns false when audioTracks differ', () {
        expect(
          _makeParams(
            audioTracks: [_makeAudioTrack()],
          ).deepEquals(_makeParams()),
          isFalse,
        );
      });

      test('returns false when videoClips differ', () {
        expect(
          _makeParams(videoClips: [_makeVideoClip()]).deepEquals(_makeParams()),
          isFalse,
        );
      });

      test('returns false when matrixFilterList differs', () {
        expect(
          _makeParams(
            matrixFilterList: [
              [1, 0, 0, 0, 0],
            ],
          ).deepEquals(_makeParams()),
          isFalse,
        );
      });

      test('returns false when matrixTuneAdjustmentsList differs', () {
        expect(
          _makeParams(
            matrixTuneAdjustmentsList: [
              [0, 1, 0, 0, 0],
            ],
          ).deepEquals(_makeParams()),
          isFalse,
        );
      });
    });

    group('diff', () {
      test('returns empty list for equal instances', () {
        final a = _makeParams(blur: 5, flipX: true);
        final b = _makeParams(blur: 5, flipX: true);
        expect(a.diff(b), isEmpty);
      });

      test('returns empty list for identical reference', () {
        final a = _makeParams();
        expect(a.diff(a), isEmpty);
      });

      test('reports single differing scalar field', () {
        final a = _makeParams(blur: 1);
        final b = _makeParams(blur: 2);
        expect(a.diff(b), equals(['blur']));
      });

      test('reports multiple differing fields', () {
        final a = _makeParams(blur: 1, flipX: true, rotateTurns: 1);
        final b = _makeParams(blur: 2, rotateTurns: 3);
        expect(a.diff(b), containsAll(['blur', 'flipX', 'rotateTurns']));
      });

      test('reports image when bytes differ', () {
        final a = _makeParams(image: Uint8List.fromList([1]));
        final b = _makeParams(image: Uint8List.fromList([2]));
        expect(a.diff(b), contains('image'));
      });

      test('does not report image when bytes are equal', () {
        final a = _makeParams(image: Uint8List.fromList([1, 2]));
        final b = _makeParams(image: Uint8List.fromList([1, 2]));
        expect(a.diff(b), isNot(contains('image')));
      });

      test('reports layers when lists differ', () {
        final a = _makeParams();
        final b = _makeParams(layers: [TextLayer(text: 'hello')]);
        expect(a.diff(b), contains('layers'));
      });

      test('reports videoClips when lists differ', () {
        final a = _makeParams();
        final b = _makeParams(videoClips: [_makeVideoClip()]);
        expect(a.diff(b), contains('videoClips'));
      });

      test('reports matrixFilterList when lists differ', () {
        final a = _makeParams();
        final b = _makeParams(
          matrixFilterList: [
            [1, 0, 0, 0, 0],
          ],
        );
        expect(a.diff(b), contains('matrixFilterList'));
      });

      test('reports matrixTuneAdjustmentsList when lists differ', () {
        final a = _makeParams();
        final b = _makeParams(
          matrixTuneAdjustmentsList: [
            [0, 1, 0, 0, 0],
          ],
        );
        expect(a.diff(b), contains('matrixTuneAdjustmentsList'));
      });

      test('reports audioTracks when they differ', () {
        final a = _makeParams();
        final b = _makeParams(audioTracks: [_makeAudioTrack()]);
        expect(a.diff(b), contains('audioTracks'));
      });

      test('reports startTime and endTime when they differ', () {
        final a = _makeParams();
        final b = _makeParams(
          startTime: const Duration(seconds: 1),
          endTime: const Duration(seconds: 5),
        );
        expect(a.diff(b), containsAll(['startTime', 'endTime']));
      });

      test('reports all crop fields when they differ', () {
        final a = _makeParams();
        final b = _makeParams(
          cropWidth: 100,
          cropHeight: 200,
          cropX: 10,
          cropY: 20,
        );
        expect(
          a.diff(b),
          containsAll(['cropWidth', 'cropHeight', 'cropX', 'cropY']),
        );
      });
    });

    group('toLogString', () {
      test('truncates image field when longer than 50 characters', () {
        final largeImage = Uint8List.fromList(
          List.generate(200, (i) => i % 256),
        );
        final params = _makeParams(image: largeImage);
        final logStr = params.toLogString();

        // The image field should be truncated
        expect(logStr, contains('…'));
        expect(logStr, contains('chars)'));
        // Should NOT contain the full image list
        final fullImageStr = largeImage.toList().toString();
        expect(logStr, isNot(contains(fullImageStr)));
      });

      test('keeps image field when shorter than 50 characters', () {
        final smallImage = Uint8List.fromList([1, 2, 3]);
        final params = _makeParams(image: smallImage);
        final logStr = params.toLogString();

        // Should contain the full image value
        expect(logStr, contains('[1, 2, 3]'));
        // Should NOT contain truncation markers
        expect(logStr, isNot(contains('…')));
      });

      test('preserves all non-image fields', () {
        final params = _makeParams(
          blur: 3.5,
          flipX: true,
          rotateTurns: 2,
          cropWidth: 100,
          cropHeight: 200,
        );
        final logStr = params.toLogString();

        expect(logStr, contains('blur'));
        expect(logStr, contains('3.5'));
        expect(logStr, contains('flipX'));
        expect(logStr, contains('true'));
        expect(logStr, contains('rotateTurns'));
        expect(logStr, contains('cropWidth'));
        expect(logStr, contains('cropHeight'));
      });

      test('handles empty image without error', () {
        final params = _makeParams(image: Uint8List(0));
        final logStr = params.toLogString();

        expect(logStr, isA<String>());
        expect(logStr, contains('image'));
      });

      test('truncated image shows total length', () {
        final largeImage = Uint8List.fromList(
          List.generate(500, (i) => i % 256),
        );
        final params = _makeParams(image: largeImage);
        final logStr = params.toLogString();

        // Should include the total character count of the original
        final fullLength = largeImage.toList().toString().length;
        expect(logStr, contains('$fullLength chars'));
      });
    });
  });

  group('completeParametersFromDraftMap', () {
    WidgetLayer buildStickerLayer(StickerData sticker) {
      return WidgetLayer(
        width: 120,
        widget: VideoEditorSticker(
          sticker: sticker,
          enableLimitCacheSize: false,
        ),
        meta: sticker.toJson(),
        exportConfigs: WidgetLayerExportConfigs(
          id: 'sticker-${sticker.description.fallback}',
          meta: sticker.toJson(),
        ),
      );
    }

    // Mirrors how a draft persists editorEditingParameters: the in-memory
    // CompleteParameters is serialized via toMap() and round-tripped through
    // JSON into storage.
    Map<String, dynamic> persistedMapFor(CompleteParameters params) {
      return json.decode(json.encode(params.toMap())) as Map<String, dynamic>;
    }

    test(
      'rehydrates a sticker widget layer instead of throwing the '
      'widgetLoader assertion',
      () {
        const sticker = StickerData.network(
          'https://stickers.example.com/heart.png',
          description: LocalizedText({'en': 'Red heart'}),
          tags: ['heart'],
          packData: StickerPackData(
            packId: 'reactions',
            packName: 'Reactions',
          ),
        );
        final map = persistedMapFor(
          _makeParams(layers: [buildStickerLayer(sticker)]),
        );

        // The package's own fromMap can't rebuild a widget layer exported by
        // id without a loader — this is the crash the helper exists to prevent.
        // (AssertionError in debug; the same site null-check-crashes in
        // release, where asserts are stripped.)
        expect(
          () => CompleteParameters.fromMap(map),
          throwsA(isA<AssertionError>()),
        );

        final restored = completeParametersFromDraftMap(map);

        expect(restored.layers, hasLength(1));
        final layer = restored.layers.single;
        expect(layer, isA<WidgetLayer>());
        expect((layer as WidgetLayer).widget, isA<VideoEditorSticker>());
        expect(
          (layer.widget as VideoEditorSticker).sticker.props,
          equals(sticker.props),
        );
      },
    );

    test('returns default parameters for an empty map', () {
      final restored = completeParametersFromDraftMap(const {});

      expect(restored.layers, isEmpty);
      expect(restored.blur, equals(0.0));
    });

    test('preserves non-widget parameters alongside rehydrated layers', () {
      const sticker = StickerData.asset(
        'assets/stickers/star.svg',
        description: LocalizedText({'en': 'Gold star'}),
        tags: ['star'],
        packData: StickerPackData.fallback,
      );
      final map = persistedMapFor(
        _makeParams(
          layers: [buildStickerLayer(sticker)],
          flipX: true,
          rotateTurns: 2,
          cropWidth: 720,
        ),
      );

      final restored = completeParametersFromDraftMap(map);

      expect(restored.flipX, isTrue);
      expect(restored.rotateTurns, equals(2));
      expect(restored.cropWidth, equals(720));
      expect(restored.layers, hasLength(1));
    });
  });

  group('captionTrackFromMeta', () {
    const track = CaptionTrack(
      presetId: 'classic',
      languageTag: 'en-US',
      cues: [
        CaptionCue(
          id: 'cue-1',
          text: 'Hello.',
          start: Duration.zero,
          end: Duration(seconds: 1),
        ),
      ],
    );

    test('restores the caption track from meta', () {
      final params = _makeParams(
        meta: {'captions': track.toJson()},
      );

      expect(params.captionTrackFromMeta, equals(track));
    });

    test('returns null without a captions key or on malformed data', () {
      expect(_makeParams().captionTrackFromMeta, isNull);
      expect(
        _makeParams(meta: {'captions': 42}).captionTrackFromMeta,
        isNull,
      );
      expect(
        _makeParams(
          meta: {
            'captions': {'presetId': 42},
          },
        ).captionTrackFromMeta,
        isNull,
      );
    });
  });
}
