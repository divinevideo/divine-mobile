// ABOUTME: Tests the keyframe actions on a timeline layer: adding and removing
// ABOUTME: the keyframe at the playhead, the keyframe sheet, and the opacity.

import 'dart:math' as math;

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_layer_view.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_opacity.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/animation_picker_components.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/keyframes/layer_keyframe_actions.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/keyframes/layer_keyframes_sheet.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pve;
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

class _FakeLayer extends Fake implements Layer {}

const _ms = Duration(milliseconds: 1);

/// Pumps a page with one button that runs [onOpen] inside the scope and bloc
/// the timeline's action bar would have around it, and taps it.
Future<void> _pumpEditorPage(
  WidgetTester tester, {
  required ProImageEditorState editor,
  required VideoEditorMainBloc mainBloc,
  required Future<void> Function(BuildContext context) onOpen,
  Duration? livePlayTime,
}) async {
  final page = Scaffold(
    body: BlocProvider<VideoEditorMainBloc>.value(
      value: mainBloc,
      child: VideoEditorScope(
        editorKey: GlobalKey(),
        removeAreaKey: GlobalKey(),
        originalClipAspectRatio: 1,
        bodySizeNotifier: ValueNotifier(const Size(400, 600)),
        zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
        playTimeNotifier: ValueNotifier(
          livePlayTime ?? mainBloc.state.currentPosition,
        ),
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
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => onOpen(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpWidget(
    // The sheets close themselves through go_router or their own route.
    MaterialApp.router(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => page)],
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Makes [editor] replace layers in [layers] in place, as the editor does.
void _stubReplaceLayer(ProImageEditorState editor, List<Layer> layers) {
  void replace(Invocation invocation) {
    layers[invocation.namedArguments[#index] as int] =
        invocation.namedArguments[#layer] as Layer;
  }

  when(() => editor.activeLayers).thenReturn(layers);
  when(
    () => editor.replaceLayer(
      index: any(named: 'index'),
      layer: any(named: 'layer'),
      skipUpdateHistory: any(named: 'skipUpdateHistory'),
    ),
  ).thenAnswer(replace);
  when(
    () => editor.replaceLayer(
      index: any(named: 'index'),
      layer: any(named: 'layer'),
    ),
  ).thenAnswer(replace);
}

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
    startTime: const Duration(seconds: 2),
    endTime: const Duration(seconds: 6),
    offset: const Offset(10, 20),
    widget: DetachedClipLayerView(meta: meta),
    meta: meta,
    exportConfigs: WidgetLayerExportConfigs(id: 'layer-1', meta: meta),
  );
}

PaintLayer _censorLayer() => PaintLayer(
  rawSize: const Size(40, 20),
  opacity: 1,
  item: PaintedModel(
    mode: PaintMode.blur,
    offsets: const [Offset.zero, Offset(40, 20)],
    erasedOffsets: const [],
    color: const Color(0xFFFFFFFF),
    strokeWidth: 1,
    opacity: 1,
  ),
);

/// A text layer from 2 s that moves right and turns between two keyframes,
/// at 2.0 s and 3.0 s of the video.
TextLayer _movingText() => TextLayer(
  id: 'layer-1',
  text: 'hi',
  startTime: const Duration(seconds: 2),
  endTime: const Duration(seconds: 6),
  keyframes: const [
    LayerKeyframe(time: Duration.zero, offset: Offset.zero, opacity: 0.2),
    LayerKeyframe(
      time: Duration(seconds: 1),
      offset: Offset(100, 0),
      scale: 2,
      rotation: 1,
    ),
  ],
);

void main() {
  group('canKeyframeLayer', () {
    test('lets every layer but a hidden area move', () {
      expect(canKeyframeLayer(TextLayer(text: 'hi')), isTrue);
      expect(canKeyframeLayer(_detachedLayer()), isTrue);
      expect(canKeyframeLayer(_censorLayer()), isFalse);
      expect(canKeyframeLayer(null), isFalse);
    });
  });

  group('layerWithKeyframeToggled', () {
    test('adds the first keyframe where the layer is laid out', () {
      final layer = TextLayer(
        text: 'hi',
        startTime: const Duration(seconds: 2),
        offset: const Offset(30, 40),
        scale: 1.5,
        rotation: 0.25,
        opacity: 0.6,
      );

      final updated = layerWithKeyframeToggled(layer, _ms * 2500);

      expect(updated.keyframes, const [
        LayerKeyframe(
          time: Duration(milliseconds: 500),
          offset: Offset(30, 40),
          scale: 1.5,
          rotation: 0.25,
          opacity: 0.6,
        ),
      ]);
      // The canvas updates the layer it shows instead of building a new one.
      expect(updated.key, same(layer.key));
      expect(layer.keyframes, isEmpty);
    });

    test('adds a keyframe where the keyframes move the layer', () {
      final layer = _movingText();

      final updated = layerWithKeyframeToggled(layer, _ms * 2500);

      expect(updated.keyframes, hasLength(3));
      final added = updated.keyframes[1];
      expect(added.time, _ms * 500);
      expect(added.placement, layer.keyframePlacementAt(_ms * 2500));
    });

    test('removes one keyframe of several', () {
      final updated = layerWithKeyframeToggled(_movingText(), _ms * 3010);

      expect(updated.keyframes.map((k) => k.time), [Duration.zero]);
    });

    test('leaves the layer where it showed when its last keyframe goes', () {
      final layer = TextLayer(
        text: 'hi',
        keyframes: const [
          LayerKeyframe(
            time: Duration.zero,
            offset: Offset(70, 80),
            scale: 3,
            rotation: 0.5,
            opacity: 0.3,
          ),
        ],
      );

      final updated = layerWithKeyframeToggled(layer, Duration.zero);

      expect(updated.keyframes, isEmpty);
      expect(updated.offset, const Offset(70, 80));
      expect(updated.scale, 3);
      expect(updated.rotation, 0.5);
      expect(updated.opacity, 0.3);
    });

    group('on a detached clip', () {
      test('moves the clip opacity into its first keyframe', () {
        final updated = layerWithKeyframeToggled(
          _detachedLayer(opacity: 0.4),
          _ms * 2000,
        ) as WidgetLayer;

        expect(updated.keyframes.single.opacity, 0.4);
        final meta = DetachedClipLayerData.metaOf(updated);
        // Its view would otherwise fade the clip a second time.
        expect(DetachedClipLayerData.opacityOf(meta), 1);
        expect(
          (updated.widget as DetachedClipLayerView).meta,
          same(updated.meta),
        );
        expect(updated.exportConfigs.meta, updated.meta);
        expect(updated.opacity, 1);
      });

      test('moves the opacity back out of its last keyframe', () {
        final keyframed = layerWithKeyframeToggled(
          _detachedLayer(opacity: 0.4),
          _ms * 2000,
        );

        final updated = layerWithKeyframeToggled(keyframed, _ms * 2000);

        expect(updated.keyframes, isEmpty);
        expect(
          DetachedClipLayerData.opacityOf(
            DetachedClipLayerData.metaOf(updated),
          ),
          0.4,
        );
        // The base opacity applies on top of the meta one in the editor.
        expect(updated.opacity, 1);
      });
    });
  });

  group('keyframe curves', () {
    test('keyframeSegmentIndex picks the motion at the time', () {
      final layer = TextLayer(
        text: 'hi',
        keyframes: const [
          LayerKeyframe(time: Duration(seconds: 1), offset: Offset.zero),
          LayerKeyframe(time: Duration(seconds: 2), offset: Offset.zero),
          LayerKeyframe(time: Duration(seconds: 3), offset: Offset.zero),
        ],
      );

      expect(keyframeSegmentIndex(layer, Duration.zero), 0);
      expect(keyframeSegmentIndex(layer, _ms * 1500), 0);
      expect(keyframeSegmentIndex(layer, _ms * 2000), 1);
      expect(keyframeSegmentIndex(layer, _ms * 9000), 1);
      expect(keyframeSegmentIndex(TextLayer(text: 'hi'), Duration.zero), null);
    });

    test('layerWithKeyframeCurve eases the motion at the time', () {
      final layer = _movingText();

      final updated = layerWithKeyframeCurve(
        layer,
        _ms * 2500,
        AnimationCurve.bounceOut,
      );

      expect(updated.keyframes.first.curve, AnimationCurve.bounceOut);
      expect(updated.keyframes.last.curve, AnimationCurve.linear);
      expect(layer.keyframes.first.curve, AnimationCurve.linear);
    });
  });

  group('keyframe effects', () {
    test('plays the effect on the motion at the time', () {
      final layer = _movingText();
      final bounce = defaultKeyframeEffect(LayerAnimationType.bounce);

      final updated = layerWithKeyframeEffect(layer, _ms * 2500, bounce);

      expect(updated.keyframes.first.effects, [bounce]);
      expect(layerKeyframeEffectAt(updated, _ms * 2500), bounce);
      expect(layer.keyframes.first.effects, isEmpty);

      final cleared = layerWithKeyframeEffect(updated, _ms * 2500, null);
      expect(layerKeyframeEffectAt(cleared, _ms * 2500), isNull);
    });

    test('starts every effect as a loop', () {
      for (final type in keyframeEffectTypes) {
        final effect = defaultKeyframeEffect(type);
        expect(effect.type, type);
        expect(effect.phase, AnimationPhase.loop);
        expect(effect.duration, greaterThan(Duration.zero));
      }
    });

    test('are off for a detached clip, which exports without animations', () {
      expect(canPlayKeyframeEffects(_detachedLayer()), isFalse);
      expect(canPlayKeyframeEffects(_movingText()), isTrue);
    });
  });

  group('opacity', () {
    test('layerWithOpacity sets the layer own opacity without keyframes', () {
      final updated = layerWithOpacity(
        TextLayer(text: 'hi'),
        Duration.zero,
        .4,
      );

      expect(updated.opacity, 0.4);
      expect(updated.keyframes, isEmpty);
    });

    test('layerWithOpacity writes a keyframe at the time of a moving '
        'layer', () {
      final layer = _movingText();

      final updated = layerWithOpacity(layer, _ms * 2500, 0.7);

      final added = updated.keyframes[1];
      expect(added.time, _ms * 500);
      expect(added.opacity, 0.7);
      expect(added.offset, layer.keyframePlacementAt(_ms * 2500)!.offset);
    });

    test('layerOpacityAt reads the keyframes, the clip and the layer', () {
      expect(layerOpacityAt(_movingText(), _ms * 2000), 0.2);
      expect(layerOpacityAt(_detachedLayer(opacity: 0.4), Duration.zero), 0.4);
      expect(
        layerOpacityAt(TextLayer(text: 'hi', opacity: 0.3), Duration.zero),
        0.3,
      );
    });
  });

  group('editLayerOpacity', () {
    late _MockProImageEditorState editor;
    late _MockVideoEditorMainBloc mainBloc;

    const item = TimelineOverlayItem(
      id: 'layer-1',
      type: TimelineOverlayType.layer,
      startTime: Duration(seconds: 2),
      endTime: Duration(seconds: 6),
    );

    setUpAll(() {
      registerFallbackValue(_FakeLayer());
      registerFallbackValue(const VideoEditorSeekRequested(Duration.zero));
    });

    setUp(() {
      editor = _MockProImageEditorState();
      when(() => editor.mounted).thenReturn(true);
      mainBloc = _MockVideoEditorMainBloc();
      when(() => mainBloc.isClosed).thenReturn(false);
      when(() => mainBloc.state).thenReturn(
        const VideoEditorMainState(currentPosition: Duration(seconds: 3)),
      );
    });

    Future<void> pump(
      WidgetTester tester,
      Layer layer, {
      Duration? livePlayTime,
    }) async {
      // The preview and the final write both replace the layer in place.
      _stubReplaceLayer(editor, [layer]);
      await _pumpEditorPage(
        tester,
        editor: editor,
        mainBloc: mainBloc,
        onOpen: (context) => editLayerOpacity(context, layer, item: item),
        livePlayTime: livePlayTime,
      );
    }

    Future<void> drag(WidgetTester tester, double opacity) async {
      tester.widget<DivineSlider>(find.byType(DivineSlider)).onChanged!(
        opacity,
      );
      await tester.pump();
    }

    Future<void> tapSheetButton(
      WidgetTester tester,
      DivineIconName icon,
    ) async {
      await tester.tap(
        find.descendant(
          of: find.byType(LayerOpacitySheet),
          matching: find.byWidgetPredicate(
            (w) => w is DivineIconButton && w.icon == icon,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('previews every step and writes the last as one history step', (
      tester,
    ) async {
      final layer = TextLayer(id: 'layer-1', text: 'hi');
      await pump(tester, layer);

      await drag(tester, 0.6);
      await drag(tester, 0.3);
      expect(editor.activeLayers.single.opacity, 0.3);
      verify(
        () => editor.replaceLayer(
          index: 0,
          layer: any(named: 'layer'),
          skipUpdateHistory: true,
        ),
      ).called(2);

      await tapSheetButton(tester, DivineIconName.check);

      // Puts the layer back before the step is recorded.
      verify(
        () => editor.replaceLayer(
          index: 0,
          layer: layer,
          skipUpdateHistory: true,
        ),
      ).called(1);

      final written =
          verify(
                () => editor.replaceLayer(
                  index: 0,
                  layer: captureAny(named: 'layer'),
                ),
              ).captured.single
              as Layer;
      expect(written.opacity, 0.3);
      expect(layer.opacity, 1);
    });

    testWidgets('puts the layer back on cancel and records nothing', (
      tester,
    ) async {
      final layer = TextLayer(id: 'layer-1', text: 'hi');
      await pump(tester, layer);

      await drag(tester, 0.3);
      await tapSheetButton(tester, DivineIconName.x);

      expect(editor.activeLayers.single, same(layer));
      verifyNever(
        () => editor.replaceLayer(
          index: any(named: 'index'),
          layer: any(named: 'layer'),
        ),
      );
    });

    testWidgets('fades a moving layer in the keyframe at the playhead', (
      tester,
    ) async {
      await pump(tester, _movingText());

      await drag(tester, 0.5);
      await tapSheetButton(tester, DivineIconName.check);

      final written =
          verify(
                () => editor.replaceLayer(
                  index: 0,
                  layer: captureAny(named: 'layer'),
                ),
              ).captured.single
              as Layer;
      final atPlayhead = written.keyframes.singleWhere(
        (k) => k.time == const Duration(seconds: 1),
      );
      expect(atPlayhead.opacity, 0.5);
    });

    testWidgets('fades at the visible playhead while the bloc seek is stale', (
      tester,
    ) async {
      when(() => mainBloc.state).thenReturn(
        const VideoEditorMainState(currentPosition: Duration(seconds: 2)),
      );
      await pump(
        tester,
        _movingText(),
        livePlayTime: const Duration(seconds: 3),
      );

      await drag(tester, 0.5);
      await tapSheetButton(tester, DivineIconName.check);

      final keyframes = editor.activeLayers.single.keyframes;
      expect(keyframes.first.opacity, 0.2);
      expect(keyframes.last.time, const Duration(seconds: 1));
      expect(keyframes.last.opacity, 0.5);
    });

    testWidgets('fades a moving clip in its keyframe, not its own opacity', (
      tester,
    ) async {
      final clip = _detachedLayer()
        ..keyframes = const [
          LayerKeyframe(time: Duration.zero, offset: Offset.zero),
          LayerKeyframe(time: Duration(seconds: 2), offset: Offset(50, 0)),
        ];
      await pump(tester, clip);

      await drag(tester, 0.5);
      await tapSheetButton(tester, DivineIconName.check);

      final written =
          verify(
                () => editor.replaceLayer(
                  index: 0,
                  layer: captureAny(named: 'layer'),
                ),
              ).captured.single
              as Layer;
      // Keyframes carry a moving clip's opacity. Its own would fade it again
      // on the canvas, while the export lets the keyframes replace it.
      expect(
        written.keyframes
            .singleWhere((k) => k.time == const Duration(seconds: 1))
            .opacity,
        0.5,
      );
      expect(
        DetachedClipLayerData.opacityOf(DetachedClipLayerData.metaOf(written)),
        1,
      );
    });

    testWidgets('moves a playhead outside the layer onto its start', (
      tester,
    ) async {
      when(() => mainBloc.state).thenReturn(
        const VideoEditorMainState(currentPosition: Duration(seconds: 9)),
      );
      await pump(tester, TextLayer(id: 'layer-1', text: 'hi'));

      verify(
        () =>
            mainBloc.add(const VideoEditorSeekRequested(Duration(seconds: 2))),
      ).called(1);
    });
  });

  group('editLayerKeyframes', () {
    late _MockProImageEditorState editor;
    late _MockVideoEditorMainBloc mainBloc;

    const item = TimelineOverlayItem(
      id: 'layer-1',
      type: TimelineOverlayType.layer,
      startTime: Duration(seconds: 2),
      endTime: Duration(seconds: 6),
    );

    setUpAll(() {
      registerFallbackValue(_FakeLayer());
      registerFallbackValue(const VideoEditorSeekRequested(Duration.zero));
    });

    setUp(() {
      editor = _MockProImageEditorState();
      when(() => editor.mounted).thenReturn(true);
      mainBloc = _MockVideoEditorMainBloc();
      when(() => mainBloc.isClosed).thenReturn(false);
    });

    /// Opens the sheet for [layer] with the playhead at [playhead].
    Future<void> pump(
      WidgetTester tester,
      Layer layer, {
      required Duration playhead,
      Duration? livePlayTime,
    }) async {
      when(
        () => mainBloc.state,
      ).thenReturn(VideoEditorMainState(currentPosition: playhead));
      _stubReplaceLayer(editor, [layer]);
      await _pumpEditorPage(
        tester,
        editor: editor,
        mainBloc: mainBloc,
        onOpen: (context) => editLayerKeyframes(context, layer, item: item),
        livePlayTime: livePlayTime,
      );
    }

    AppLocalizations l10n(WidgetTester tester) =>
        AppLocalizations.of(tester.element(find.byType(LayerKeyframesSheet)));

    /// Taps the confirm (check) or cancel (x) button in the sheet's header.
    Future<void> tapHeaderButton(
      WidgetTester tester,
      DivineIconName icon,
    ) async {
      await tester.tap(
        find.byWidgetPredicate((w) => w is DivineIconButton && w.icon == icon),
      );
      await tester.pumpAndSettle();
    }

    /// The layer written as a history step, read off the editor.
    Layer written() =>
        verify(
              () => editor.replaceLayer(
                index: 0,
                layer: captureAny(named: 'layer'),
              ),
            ).captured.single
            as Layer;

    void verifyNothingWritten() => verifyNever(
      () => editor.replaceLayer(
        index: any(named: 'index'),
        layer: any(named: 'layer'),
      ),
    );

    testWidgets('says how keyframes work', (tester) async {
      await pump(
        tester,
        TextLayer(id: 'layer-1', text: 'hi'),
        playhead: const Duration(seconds: 3),
      );

      expect(find.text(l10n(tester).videoEditorKeyframesHint), findsOneWidget);
    });

    testWidgets('adds the keyframe at the playhead and closes', (tester) async {
      await pump(
        tester,
        TextLayer(
          id: 'layer-1',
          text: 'hi',
          startTime: const Duration(seconds: 2),
          endTime: const Duration(seconds: 6),
          offset: const Offset(30, 40),
        ),
        playhead: const Duration(seconds: 3),
      );

      await tester.tap(find.text(l10n(tester).videoEditorKeyframeAdd));
      await tester.pumpAndSettle();

      final written = editor.activeLayers.single;
      expect(written.keyframes.single.time, const Duration(seconds: 1));
      expect(written.keyframes.single.offset, const Offset(30, 40));
      expect(find.byType(LayerKeyframesSheet), findsNothing);
      // Without two keyframes there is no motion to ease.
      expect(find.byType(CurvePickerRow), findsNothing);
    });

    testWidgets('removes the keyframe the playhead is on', (tester) async {
      await pump(tester, _movingText(), playhead: const Duration(seconds: 3));

      await tester.tap(find.text(l10n(tester).videoEditorKeyframeRemove));
      await tester.pumpAndSettle();

      expect(editor.activeLayers.single.keyframes.single.time, Duration.zero);
    });

    testWidgets('removes the visible keyframe while the bloc seek is stale', (
      tester,
    ) async {
      await pump(
        tester,
        _movingText(),
        playhead: const Duration(seconds: 2),
        livePlayTime: const Duration(seconds: 3),
      );

      await tester.tap(find.text(l10n(tester).videoEditorKeyframeRemove));
      await tester.pumpAndSettle();

      expect(editor.activeLayers.single.keyframes.single.time, Duration.zero);
    });

    testWidgets('eases the motion the playhead is in', (tester) async {
      await pump(
        tester,
        _movingText(),
        playhead: const Duration(milliseconds: 2500),
      );

      expect(
        find.text(l10n(tester).videoEditorKeyframeCurveSegment('1', '2')),
        findsOneWidget,
      );
      tester
          .widget<CurvePickerRow>(find.byType(CurvePickerRow))
          .onChanged(pve.AnimationCurve.bounceOut);
      await tester.pump();

      // Shown on the canvas, with the sheet still open on the curve picked.
      expect(
        editor.activeLayers.single.keyframes.first.curve,
        AnimationCurve.bounceOut,
      );
      expect(
        tester.widget<CurvePickerRow>(find.byType(CurvePickerRow)).selected,
        pve.AnimationCurve.bounceOut,
      );
      verifyNothingWritten();

      await tapHeaderButton(tester, DivineIconName.check);

      expect(written().keyframes.first.curve, AnimationCurve.bounceOut);
    });

    testWidgets('puts the layer back on cancel', (tester) async {
      final layer = _movingText();
      await pump(tester, layer, playhead: const Duration(milliseconds: 2500));

      tester
          .widget<CurvePickerRow>(find.byType(CurvePickerRow))
          .onChanged(pve.AnimationCurve.bounceOut);
      await tester.pump();
      await tapHeaderButton(tester, DivineIconName.x);

      expect(find.byType(LayerKeyframesSheet), findsNothing);
      expect(editor.activeLayers.single, same(layer));
      verifyNothingWritten();
    });

    testWidgets('keeps what the canvas shows when the sheet is swiped away', (
      tester,
    ) async {
      await pump(
        tester,
        _movingText(),
        playhead: const Duration(milliseconds: 2500),
      );

      tester
          .widget<CurvePickerRow>(find.byType(CurvePickerRow))
          .onChanged(pve.AnimationCurve.bounceOut);
      await tester.pump();
      // Above the sheet: the barrier is clear so the canvas can be judged.
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();

      expect(find.byType(LayerKeyframesSheet), findsNothing);
      expect(written().keyframes.first.curve, AnimationCurve.bounceOut);
    });

    testWidgets('records no step for the curve the motion already has', (
      tester,
    ) async {
      await pump(
        tester,
        _movingText(),
        playhead: const Duration(milliseconds: 2500),
      );

      tester
          .widget<CurvePickerRow>(find.byType(CurvePickerRow))
          .onChanged(pve.AnimationCurve.linear);
      await tester.pump();
      await tapHeaderButton(tester, DivineIconName.check);

      // An undo step that undoes nothing reads as a broken undo.
      verifyNothingWritten();
    });

    testWidgets('fades the keyframe the playhead is on as one step', (
      tester,
    ) async {
      await pump(tester, _movingText(), playhead: const Duration(seconds: 3));

      final slider = tester.widget<DivineSlider>(find.byType(DivineSlider));
      expect(slider.value, 1);
      slider.onChanged!(0.6);
      slider.onChanged!(0.3);
      await tester.pump();
      // Each step shows on the canvas without a history step.
      expect(editor.activeLayers.single.keyframes.last.opacity, 0.3);
      verifyNothingWritten();

      await tapHeaderButton(tester, DivineIconName.check);

      final layer = written();
      expect(layer.keyframes.last.opacity, 0.3);
      expect(layer.keyframes.first.opacity, 0.2);
    });

    testWidgets('offers no opacity off a keyframe', (tester) async {
      await pump(
        tester,
        _movingText(),
        playhead: const Duration(milliseconds: 2500),
      );

      expect(find.text(l10n(tester).videoEditorOpacityLabel), findsNothing);
    });

    testWidgets('plays the effect picked on the motion', (tester) async {
      await pump(
        tester,
        _movingText(),
        playhead: const Duration(milliseconds: 2500),
      );

      await tester.tap(find.text(l10n(tester).videoEditorLayerAnimationWiggle));
      await tester.pumpAndSettle();

      expect(
        layerKeyframeEffectAt(editor.activeLayers.single, _ms * 2500),
        defaultKeyframeEffect(LayerAnimationType.wiggle),
      );
      // Its strength can be set right away.
      expect(
        find.text(l10n(tester).videoEditorLayerAnimationWiggleAngle),
        findsOneWidget,
      );

      await tapHeaderButton(tester, DivineIconName.check);

      expect(
        layerKeyframeEffectAt(written(), _ms * 2500),
        defaultKeyframeEffect(LayerAnimationType.wiggle),
      );
    });

    testWidgets('keeps the strength when the picked effect is tapped again', (
      tester,
    ) async {
      await pump(
        tester,
        _movingText(),
        playhead: const Duration(milliseconds: 2500),
      );
      final wiggle = find.text(l10n(tester).videoEditorLayerAnimationWiggle);
      await tester.tap(wiggle);
      await tester.pumpAndSettle();

      // Off a keyframe the strength slider is the only one in the sheet.
      tester.widget<DivineSlider>(find.byType(DivineSlider))
        ..onChanged!(20)
        ..onChangeEnd!(20);
      await tester.pump();
      await tester.tap(wiggle);
      await tester.pumpAndSettle();

      final effect = layerKeyframeEffectAt(
        editor.activeLayers.single,
        _ms * 2500,
      );
      expect(effect?.type, LayerAnimationType.wiggle);
      expect(effect?.wiggleAngle, closeTo(20 * math.pi / 180, 1e-9));
    });

    testWidgets('offers no effect for a detached clip', (tester) async {
      final clip = _detachedLayer()
        ..keyframes = const [
          LayerKeyframe(time: Duration.zero, offset: Offset.zero),
          LayerKeyframe(time: Duration(seconds: 1), offset: Offset(50, 0)),
        ];
      await pump(tester, clip, playhead: const Duration(milliseconds: 2500));

      expect(find.text(l10n(tester).videoEditorKeyframeEffect), findsNothing);
      expect(find.byType(CurvePickerRow), findsOneWidget);
    });

    testWidgets('moves a playhead outside the layer onto its start', (
      tester,
    ) async {
      await pump(
        tester,
        TextLayer(
          id: 'layer-1',
          text: 'hi',
          startTime: const Duration(seconds: 2),
          endTime: const Duration(seconds: 6),
        ),
        playhead: const Duration(seconds: 9),
      );

      verify(
        () =>
            mainBloc.add(const VideoEditorSeekRequested(Duration(seconds: 2))),
      ).called(1);

      await tester.tap(find.text(l10n(tester).videoEditorKeyframeAdd));
      await tester.pumpAndSettle();

      expect(editor.activeLayers.single.keyframes.single.time, Duration.zero);
    });
  });
}
