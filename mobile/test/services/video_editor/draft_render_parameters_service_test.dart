// ABOUTME: Tests DraftRenderParametersService restoring a draft's overlays
// ABOUTME: Covers layers, timed filters, tune and the graceful degrade paths

import 'dart:typed_data';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide AspectRatio;
import 'package:models/models.dart' show AspectRatio, AudioEvent;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/aspect_ratio_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/video_editor/draft_render_parameters_service.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

DivineVideoClip _clip() => DivineVideoClip(
  id: 'clip_1',
  video: EditorVideo.file('/tmp/test.mp4'),
  duration: const Duration(seconds: 6),
  recordedAt: DateTime(2025),
  originalAspectRatio: 9 / 16,
  targetAspectRatio: .vertical,
);

DivineVideoDraft _draft({
  Map<String, dynamic> editorStateHistory = const {},
  Map<String, dynamic> editorEditingParameters = const {},
  AudioEvent? selectedSound,
}) => DivineVideoDraft(
  id: 'draft_1',
  clips: [_clip()],
  title: '',
  description: '',
  hashtags: const {},
  selectedApproach: 'camera',
  createdAt: DateTime(2025),
  lastModified: DateTime(2025),
  publishStatus: PublishStatus.draft,
  publishAttempts: 0,
  editorStateHistory: editorStateHistory,
  editorEditingParameters: editorEditingParameters,
  selectedSound: selectedSound,
);

/// The persisted shape of a session laid out against [bodySize].
///
/// This is what `CompleteParameters.toMap` writes into a draft — note it has
/// no `capturedLayers`, `filterStates`, `tuneAdjustments` or `audioTracks`,
/// which is the gap the service exists to close.
Map<String, dynamic> _persistedParameters({Size? bodySize}) => {
  if (bodySize != null)
    'bodySize': {'width': bodySize.width, 'height': bodySize.height},
};

Map<String, dynamic> _historyWithTextLayer() => {
  'position': 0,
  'references': {
    'text-1': TextLayer(id: 'text-1', text: 'hello').toMap(),
  },
  'history': [
    {
      'layers': [
        {'id': 'text-1'},
      ],
    },
  ],
};

void main() {
  group(DraftRenderParametersService, () {
    late LayerRasterizer rasterizer;
    late DraftRenderParametersService service;

    setUp(() {
      rasterizer = LayerRasterizer();
      service = DraftRenderParametersService(rasterizer: rasterizer);
    });

    tearDown(() => rasterizer.dispose());

    test('returns null when the draft carries no editor state', () async {
      expect(await service.buildForDraft(_draft()), isNull);
    });

    test(
      'restores timed filters and tune the persisted parameters drop',
      () async {
        final draft = _draft(
          editorEditingParameters: _persistedParameters(),
          editorStateHistory: {
            'position': 0,
            'history': [
              {
                'filters': [
                  {
                    'matrices': [
                      List<double>.filled(20, 0.5),
                    ],
                    'startTime': 1000,
                    'endTime': 3000,
                  },
                ],
                'tune': [
                  {'id': 'brightness', 'value': 0.4, 'matrix': <double>[]},
                ],
              },
            ],
          },
        );

        final parameters = await service.buildForDraft(draft);

        expect(parameters, isNotNull);
        expect(parameters!.filterStates, hasLength(1));
        expect(
          parameters.filterStates.single.startTime,
          equals(const Duration(milliseconds: 1000)),
          reason: 'the timeline window is what the raw matrix list loses',
        );
        expect(parameters.tuneAdjustments, hasLength(1));
      },
    );

    test(
      'restores the recorder-picked sound the timeline never carries',
      () async {
        // `selectSound` writes no timeline track, so without the fallback the
        // same draft publishes with music from the editor and silent from the
        // library.
        final draft = _draft(
          editorEditingParameters: _persistedParameters(),
          selectedSound: AudioEvent(
            id: 'sound-1',
            pubkey: 'pubkey-1',
            createdAt: 1735689600,
            url: 'https://example.com/track.mp3',
            duration: 6,
          ),
        );

        final parameters = await service.buildForDraft(draft);

        expect(parameters!.audioTracks, hasLength(1));
        expect(parameters.audioTracks.single.id, equals('sound-1'));
      },
    );

    test('falls back to the size the state history was laid out at', () async {
      // `bodySize` only reaches storage through the editor's Done callback, so
      // a draft saved by backing out has layers and no parameters at all.
      // Blocking those would hide Post behind an error for the most ordinary
      // way to end up with overlays.
      final stub = _StubLayerRasterizer();
      addTearDown(stub.dispose);

      final draft = _draft(
        editorStateHistory: {
          ..._historyWithTextLayer(),
          'lastRenderedImgSize': {'width': 390.0, 'height': 694.0},
        },
      );

      final parameters = await DraftRenderParametersService(
        rasterizer: stub,
      ).buildForDraft(draft);

      expect(stub.editorBodySize, equals(const Size(390, 694)));
      expect(
        parameters!.bodySize,
        equals(const Size(390, 694)),
        reason:
            'the render scales the captured layers against this, so it has '
            'to match the size they were captured at',
      );
    });

    // The four cases below all mean "this draft has overlays we cannot
    // reproduce". Returning parameters without them would publish a video
    // silently missing text/stickers the user still sees on the draft — the
    // #5203 failure — so the publish is blocked instead.
    test('refuses to build when no body size can be resolved', () async {
      final stub = _StubLayerRasterizer();
      addTearDown(stub.dispose);

      // No `lastRenderedImgSize` either — `safeParseSize` yields `Size.zero`.
      final draft = _draft(
        editorEditingParameters: _persistedParameters(),
        editorStateHistory: _historyWithTextLayer(),
      );

      await expectLater(
        DraftRenderParametersService(rasterizer: stub).buildForDraft(draft),
        throwsA(
          isA<DraftOverlayRestoreException>().having(
            (e) => e.message,
            'message',
            contains('no editor body size'),
          ),
        ),
      );
    });

    test('refuses to build when only some layers rasterize', () async {
      // `captureAllLayers` drops a layer that produced no image instead of
      // reporting it, so a short result is a silent partial bake.
      final stub = _StubLayerRasterizer(dropLayers: true);
      addTearDown(stub.dispose);

      final draft = _draft(
        editorEditingParameters: _persistedParameters(
          bodySize: const Size(300, 500),
        ),
        editorStateHistory: _historyWithTextLayer(),
      );

      await expectLater(
        DraftRenderParametersService(rasterizer: stub).buildForDraft(draft),
        throwsA(
          isA<DraftOverlayRestoreException>().having(
            (e) => e.message,
            'message',
            contains('Only 0 of 1 layer(s)'),
          ),
        ),
      );
    });

    test('refuses to build when the state history is malformed', () async {
      // A history that will not parse may well describe layers, and there is
      // no way to tell from the outside.
      final draft = _draft(
        editorEditingParameters: _persistedParameters(
          bodySize: const Size(300, 500),
        ),
        editorStateHistory: const {'position': 0, 'history': 'not-a-list'},
      );

      await expectLater(
        service.buildForDraft(draft),
        throwsA(isA<DraftOverlayRestoreException>()),
      );
    });

    test('refuses to build when rasterizing the layers fails', () async {
      final draft = _draft(
        editorEditingParameters: _persistedParameters(
          bodySize: const Size(300, 500),
        ),
        editorStateHistory: _historyWithTextLayer(),
      );

      // No host is mounted, so the real rasterizer throws a StateError.
      await expectLater(
        service.buildForDraft(draft),
        throwsA(isA<DraftOverlayRestoreException>()),
      );
    });

    test('rasterizes the restored layers into capturedLayers', () async {
      // The rasterizer is stubbed here: producing real bytes means PNG
      // encoding through the isolate-backed recorder, which a widget test
      // cannot drive. pro_image_editor's own LayerRasterizer tests cover that
      // mount-paint-capture mechanism end to end; what matters here is that
      // the service hands it the layers it recovered from storage and puts
      // the result where the render reads it.
      final stub = _StubLayerRasterizer();
      addTearDown(stub.dispose);

      final draft = _draft(
        editorEditingParameters: _persistedParameters(
          bodySize: const Size(300, 500),
        ),
        editorStateHistory: _historyWithTextLayer(),
      );

      final parameters = await DraftRenderParametersService(
        rasterizer: stub,
      ).buildForDraft(draft);

      expect(
        stub.capturedLayerCount,
        equals(1),
        reason:
            'a layer restored from storage has never been rasterized, so '
            'without this the render would drop it entirely',
      );
      expect(
        stub.editorBodySize,
        equals(const Size(300, 500)),
        reason: 'layer offsets are relative to the editor body size',
      );
      expect(
        stub.basePixelRatio,
        equals(
          VideoEditorConstants.quality
                  .resolutionForAspectRatio(AspectRatio.vertical)
                  .width /
              300,
        ),
        reason:
            'capturing at the render scale gives one raster pixel per '
            'output pixel',
      );
      expect(parameters!.capturedLayers, hasLength(1));
    });
  });
}

/// Stands in for the real rasterizer so the service can be exercised without
/// a widget tree, recording what it was asked to bake.
///
/// [dropLayers] reproduces `captureAllLayers` returning fewer layers than it
/// was given, which is how the package reports a layer that produced no image.
class _StubLayerRasterizer extends LayerRasterizer {
  _StubLayerRasterizer({this.dropLayers = false});

  final bool dropLayers;

  int? capturedLayerCount;
  Size? editorBodySize;
  double? basePixelRatio;

  @override
  Future<List<ExportedLayer>> capture({
    required List<Layer> layers,
    required Size editorBodySize,
    ProImageEditorConfigs configs = const ProImageEditorConfigs(),
    double? pixelRatio,
    double? basePixelRatio,
    bool applyTransforms = true,
    ImageByteFormat format = ImageByteFormat.png,
    Future<void> Function()? awaitContentReady,
  }) async {
    capturedLayerCount = layers.length;
    this.editorBodySize = editorBodySize;
    this.basePixelRatio = basePixelRatio;
    await awaitContentReady?.call();
    if (dropLayers) return const [];
    return [
      for (final layer in layers)
        ExportedLayer(
          layer: layer,
          bytes: Uint8List.fromList(const [1, 2, 3]),
          logicalSize: const Size(10, 10),
        ),
    ];
  }
}
