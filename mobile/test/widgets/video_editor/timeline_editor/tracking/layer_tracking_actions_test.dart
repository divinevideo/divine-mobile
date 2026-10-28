// ABOUTME: Tests pinning a layer to a tracked object: the keyframes it gets,
// ABOUTME: the progress overlay, and how the result reaches the editor.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/layer_tracking/layer_tracking_cubit.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/models/video_editor/layer_track_target.dart';
import 'package:openvine/models/video_editor/track_frame_mapping.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_layer_view.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/tracking/layer_tracking_actions.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show EditorVideo, ObjectTrackSample, VideoObjectTrack;

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

class _FakeLayer extends Fake implements Layer {}

const _ms = Duration(milliseconds: 1);

/// A square clip filling a square canvas of 400 × 400, so a frame fraction
/// f is the layer offset (f - 0.5) * 400.
LayerTrackTarget _target({Duration anchor = const Duration(seconds: 1)}) =>
    LayerTrackTarget(
      clipId: 'clip',
      video: EditorVideo.file('/tmp/clip.mp4'),
      clipStart: Duration.zero,
      trimStart: Duration.zero,
      speed: 1,
      start: Duration.zero,
      end: const Duration(seconds: 2),
      anchor: anchor,
      videoAspectRatio: 1,
      targetAspectRatio: 1,
    );

final _mapping = TrackFrameMapping(
  canvasSize: const Size(400, 400),
  videoAspectRatio: 1,
  targetAspectRatio: 1,
);

/// An object moving right by a fifth of the frame over two seconds, marked
/// at one second.
VideoObjectTrack _track({bool reachedEnd = true}) => VideoObjectTrack(
  anchorTime: _ms * 1000,
  reachedEnd: reachedEnd,
  samples: [
    for (var i = 0; i <= 60; i++)
      ObjectTrackSample(
        time: _ms * (i * 1000 / 30).round(),
        center: Offset(0.4 + 0.2 * i / 60, 0.5),
        size: const Size(0.2, 0.2),
      ),
  ],
);

WidgetLayer _detachedLayer({double opacity = 1}) {
  final meta = DetachedClipLayerData.withOpacity(
    DetachedClipLayerData(
      clip: DivineVideoClip(
        id: 'clip-1',
        video: EditorVideo.file('/docs/clip-1.mp4'),
        duration: const Duration(seconds: 6),
        recordedAt: DateTime(2026),
        targetAspectRatio: model.AspectRatio.square,
        originalAspectRatio: 1,
      ),
      layerId: 'layer-1',
    ).toMeta(),
    opacity,
  )!;
  return WidgetLayer(
    id: 'layer-1',
    offset: const Offset(0, -50),
    widget: DetachedClipLayerView(meta: meta),
    meta: meta,
    exportConfigs: WidgetLayerExportConfigs(meta: meta),
  );
}

void main() {
  setUpAll(() => registerFallbackValue(_FakeLayer()));

  group('layerPinnedToTrack', () {
    test('moves the layer with the object, a constant distance above it', () {
      final pinned = layerPinnedToTrack(
        Layer(id: 'layer', offset: const Offset(0, -50)),
        track: _track(),
        target: _target(),
        mapping: _mapping,
      )!;
      // The object starts 40 px left of where it was marked and ends 40 px
      // right of it; a straight move needs only the two ends.
      expect(pinned.keyframes, hasLength(2));
      expect(pinned.keyframes.first.offset.dx, closeTo(-40, 1e-6));
      expect(pinned.keyframes.last.offset.dx, closeTo(40, 1e-6));
      expect(pinned.keyframes.last.offset.dy, closeTo(-50, 1e-6));
      expect(pinned.id, 'layer');
    });

    test('moves a detached clip opacity into its keyframes', () {
      final pinned = layerPinnedToTrack(
        _detachedLayer(opacity: 0.4),
        track: _track(),
        target: _target(),
        mapping: _mapping,
      )!;
      expect(pinned.keyframes.map((k) => k.opacity), everyElement(0.4));
      expect(
        DetachedClipLayerData.opacityOf(DetachedClipLayerData.metaOf(pinned)),
        1,
      );
    });

    test('gives nothing for a track that never left the marked frame', () {
      final pinned = layerPinnedToTrack(
        Layer(id: 'layer'),
        track: VideoObjectTrack(
          anchorTime: _ms * 1000,
          samples: [_track().samples[30]],
        ),
        target: _target(),
        mapping: _mapping,
      );
      expect(pinned, isNull);
    });
  });

  group('tracking in the editor', () {
    late _MockProImageEditorState editor;
    late _MockVideoEditorMainBloc mainBloc;
    late _MockClipEditorBloc clipBloc;
    late List<Layer> layers;
    late Completer<VideoObjectTrack> pending;
    late List<String> cancelled;
    late LayerTrackingCubit cubit;

    setUp(() {
      editor = _MockProImageEditorState();
      mainBloc = _MockVideoEditorMainBloc();
      clipBloc = _MockClipEditorBloc();
      layers = [Layer(id: 'layer', offset: const Offset(0, -50))];
      cancelled = [];
      when(() => editor.mounted).thenReturn(true);
      when(() => editor.activeLayers).thenAnswer((_) => layers);
      when(
        () => editor.replaceLayer(
          index: any(named: 'index'),
          layer: any(named: 'layer'),
        ),
      ).thenAnswer((invocation) {
        layers[invocation.namedArguments[#index] as int] =
            invocation.namedArguments[#layer] as Layer;
      });
      when(() => mainBloc.state).thenReturn(const VideoEditorMainState());
    });

    Future<void> pump(
      WidgetTester tester, {
      Duration playTime = const Duration(seconds: 1),
      List<DivineVideoClip> clips = const [],
      Future<void> Function(BuildContext context)? onOpen,
    }) async {
      // Made inside the test, so the fake clock drives their futures.
      pending = Completer<VideoObjectTrack>();
      cubit = LayerTrackingCubit(
        trackObject:
            ({required target, required region, required taskId, onProgress}) {
              onProgress?.call(0.25);
              return pending.future;
            },
        cancelTracking: (taskId) async {
          cancelled.add(taskId);
          if (!pending.isCompleted) pending.completeError(StateError('stop'));
        },
      );
      addTearDown(cubit.close);
      when(() => clipBloc.state).thenReturn(ClipEditorState(clips: clips));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
              BlocProvider<ClipEditorBloc>.value(value: clipBloc),
              BlocProvider<LayerTrackingCubit>.value(value: cubit),
            ],
            child: VideoEditorScope(
              editorKey: GlobalKey(),
              removeAreaKey: GlobalKey(),
              originalClipAspectRatio: 1,
              targetClipAspectRatio: 1,
              bodySizeNotifier: ValueNotifier(const Size(400, 600)),
              zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
              playTimeNotifier: ValueNotifier(playTime),
              playheadAdvancingNotifier: ValueNotifier<bool>(false),
              fromLibrary: false,
              onOpenCamera: () {},
              onOpenClipsEditor: () {},
              onAddStickers: () {},
              onAddEditTextLayer: ([layer]) async => null,
              onOpenMusicLibrary: () {},
              onOpenVoiceOver: () {},
              onOpenCaptions: () {},
              onOpenEffects: () {},
              editorOverride: editor,
              child: Scaffold(
                body: LayerTrackingResultListener(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Align(
                        alignment: Alignment.topLeft,
                        child: Builder(
                          builder: (context) => TextButton(
                            onPressed: () => onOpen?.call(context),
                            child: const Text('open'),
                          ),
                        ),
                      ),
                      const Positioned.fill(
                        child: LayerTrackingProgressOverlay(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    AppLocalizations l10n(WidgetTester tester) =>
        AppLocalizations.of(tester.element(find.byType(Scaffold)));

    Future<void> startTracking() =>
        cubit.track(layerId: 'layer', target: _target(), region: Rect.zero);

    group('LayerTrackingProgressOverlay', () {
      testWidgets('shows nothing while nothing is tracked', (tester) async {
        await pump(tester);
        expect(find.byType(PartialCircleSpinner), findsNothing);
      });

      testWidgets('shows the progress and stops on cancel', (tester) async {
        await pump(tester);
        unawaited(startTracking());
        await tester.pump();

        expect(find.text(l10n(tester).videoEditorTrackProgressLabel), findsOne);
        final spinner = tester.widget<PartialCircleSpinner>(
          find.byType(PartialCircleSpinner),
        );
        expect(spinner.progress, 0.25);

        await tester.tap(find.text(l10n(tester).commonCancel));
        await tester.pump();
        expect(cancelled, ['layer_track']);
      });

      testWidgets(
        'hides the editor from screen readers but keeps Cancel usable',
        (tester) async {
          await pump(tester);
          expect(find.semantics.byLabel('open'), findsOne);

          unawaited(startTracking());
          await tester.pump();
          expect(find.semantics.byLabel('open'), findsNothing);

          tester.semantics.tap(
            find.semantics.byLabel(l10n(tester).commonCancel),
          );
          await tester.pump();
          expect(cancelled, ['layer_track']);
        },
      );
    });

    group('LayerTrackingResultListener', () {
      testWidgets('pins the layer to the path as one history step', (
        tester,
      ) async {
        await pump(tester);
        unawaited(startTracking());
        await tester.pump();
        pending.complete(_track());
        await tester.pump();
        await tester.pump();

        verify(
          () => editor.replaceLayer(
            index: 0,
            layer: any(named: 'layer'),
          ),
        ).called(1);
        expect(layers.single.keyframes, hasLength(2));
        expect(layers.single.keyframes.last.offset.dx, closeTo(40, 1e-6));
        expect(find.byType(SnackBar), findsNothing);
        expect(cubit.state, const LayerTrackingState());
      });

      testWidgets('says when the object got lost on the way', (tester) async {
        await pump(tester);
        unawaited(startTracking());
        await tester.pump();
        pending.complete(_track(reachedEnd: false));
        await tester.pump();
        await tester.pump();

        expect(layers.single.hasKeyframes, isTrue);
        expect(find.text(l10n(tester).videoEditorTrackLostPartway), findsOne);
      });

      testWidgets('says when the region could not be followed', (tester) async {
        await pump(tester);
        unawaited(startTracking());
        await tester.pump();
        pending.complete(
          VideoObjectTrack(
            anchorTime: _ms * 1000,
            samples: [_track().samples[30]],
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(layers.single.hasKeyframes, isFalse);
        expect(find.text(l10n(tester).videoEditorTrackNotFollowed), findsOne);
      });

      testWidgets('says when tracking failed', (tester) async {
        await pump(tester);
        unawaited(startTracking());
        await tester.pump();
        pending.completeError(StateError('decoder died'));
        await tester.pump();
        await tester.pump();

        expect(find.text(l10n(tester).videoEditorTrackFailed), findsOne);
        expect(cubit.state, const LayerTrackingState());
      });

      testWidgets('leaves a layer deleted meanwhile alone', (tester) async {
        await pump(tester);
        unawaited(startTracking());
        await tester.pump();
        layers.clear();
        pending.complete(_track());
        await tester.pump();
        await tester.pump();

        verifyNever(
          () => editor.replaceLayer(
            index: any(named: 'index'),
            layer: any(named: 'layer'),
          ),
        );
        expect(find.byType(SnackBar), findsNothing);
      });
    });

    group('trackLayerObject', () {
      final item = TimelineOverlayItem(
        id: 'layer',
        type: TimelineOverlayType.layer,
        startTime: _ms * 500,
        endTime: _ms * 1500,
      );

      testWidgets('moves the playhead onto the layer first', (tester) async {
        await pump(
          tester,
          playTime: _ms * 3000,
          onOpen: (context) =>
              trackLayerObject(context, layers.single, item: item),
        );
        await tester.tap(find.text('open'));
        await tester.pump();

        verify(
          () => mainBloc.add(VideoEditorSeekRequested(_ms * 500)),
        ).called(1);
      });

      testWidgets('says when the clip under the playhead cannot be tracked', (
        tester,
      ) async {
        await pump(
          tester,
          clips: [
            DivineVideoClip(
              id: 'still',
              video: EditorVideo.file('/docs/still.mp4'),
              duration: const Duration(seconds: 2),
              recordedAt: DateTime(2026),
              targetAspectRatio: model.AspectRatio.square,
              originalAspectRatio: 1,
              isFreezeFrame: true,
            ),
          ],
          onOpen: (context) =>
              trackLayerObject(context, layers.single, item: item),
        );
        await tester.tap(find.text('open'));
        await tester.pump();

        expect(find.text(l10n(tester).videoEditorTrackUnavailable), findsOne);
        expect(cubit.state.isTracking, isFalse);
      });
    });
  });
}
