// ABOUTME: Drives the detached clip's opacity action end to end: the live
// ABOUTME: preview while the slider moves, and what it writes onto the layer.

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
import 'package:pro_image_editor/pro_image_editor.dart';
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

const _item = TimelineOverlayItem(
  id: 'layer-1',
  type: TimelineOverlayType.layer,
  startTime: Duration(seconds: 2),
  endTime: Duration(seconds: 6),
);

WidgetLayer _detachedLayer() {
  final meta = DetachedClipLayerData(
    clip: DivineVideoClip(
      id: 'clip-1',
      video: EditorVideo.file('/docs/clip-1.mp4'),
      duration: const Duration(seconds: 6),
      recordedAt: DateTime(2026),
      targetAspectRatio: model.AspectRatio.square,
      originalAspectRatio: 1,
    ),
    layerId: 'layer-1',
    sourceOffset: const Duration(seconds: 1),
  ).toMeta();
  return WidgetLayer(
    id: 'layer-1',
    widget: const SizedBox.shrink(),
    meta: meta,
    exportConfigs: WidgetLayerExportConfigs(id: 'layer-1', meta: meta),
  );
}

void main() {
  group('editDetachedClipOpacity', () {
    late _MockProImageEditorState editor;
    late _MockVideoEditorMainBloc mainBloc;

    setUpAll(() {
      registerFallbackValue(_FakeLayer());
      registerFallbackValue(
        const VideoEditorDetachedClipOpacityPreviewChanged(null),
      );
    });

    setUp(() {
      editor = _MockProImageEditorState();
      when(
        () => editor.replaceLayer(
          index: any(named: 'index'),
          layer: any(named: 'layer'),
        ),
      ).thenAnswer((_) {});
      mainBloc = _MockVideoEditorMainBloc();
      when(() => mainBloc.isClosed).thenReturn(false);
      when(() => mainBloc.state).thenReturn(
        const VideoEditorMainState(currentPosition: Duration(seconds: 3)),
      );
    });

    /// A page with one button that runs the action for [layer], inside the
    /// scope and bloc the timeline's action bar would have around it.
    Future<void> pump(WidgetTester tester, Layer layer) async {
      when(() => editor.activeLayers).thenReturn([layer]);
      final page = Scaffold(
        body: BlocProvider<VideoEditorMainBloc>.value(
          value: mainBloc,
          child: VideoEditorScope(
            editorKey: GlobalKey(),
            removeAreaKey: GlobalKey(),
            originalClipAspectRatio: 1,
            bodySizeNotifier: ValueNotifier(const Size(400, 600)),
            zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
            playTimeNotifier: ValueNotifier(Duration.zero),
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
                onPressed: () =>
                    editDetachedClipOpacity(context, layer, item: _item),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        // The sheet closes itself through go_router.
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

    /// The layer the action wrote back, read off the editor.
    WidgetLayer written() =>
        verify(
              () => editor.replaceLayer(
                index: 0,
                layer: captureAny(named: 'layer'),
              ),
            ).captured.single
            as WidgetLayer;

    void verifyNothingWritten() => verifyNever(
      () => editor.replaceLayer(
        index: any(named: 'index'),
        layer: any(named: 'layer'),
      ),
    );

    testWidgets('previews every step on the canvas and writes only the last', (
      tester,
    ) async {
      await pump(tester, _detachedLayer());

      await drag(tester, 0.6);
      await drag(tester, 0.4);
      expect(find.text('40%'), findsOneWidget);
      verify(
        () => mainBloc.add(
          const VideoEditorDetachedClipOpacityPreviewChanged((
            layerId: 'layer-1',
            opacity: 0.6,
          )),
        ),
      ).called(1);
      verify(
        () => mainBloc.add(
          const VideoEditorDetachedClipOpacityPreviewChanged((
            layerId: 'layer-1',
            opacity: 0.4,
          )),
        ),
      ).called(1);
      // A drag is one adjustment, not a run of undo steps.
      verifyNothingWritten();

      await tapSheetButton(tester, DivineIconName.check);

      final layer = written();
      expect(
        DetachedClipLayerData.opacityOf(DetachedClipLayerData.metaOf(layer)),
        0.4,
      );
      // Both meta slots and the live widget follow, so a draft round-trip and
      // the canvas agree.
      expect(DetachedClipLayerData.opacityOf(layer.meta), 0.4);
      expect(DetachedClipLayerData.opacityOf(layer.exportConfigs.meta), 0.4);
      expect(layer.widget, isA<DetachedClipLayerView>());
      // The rest of the layer survives: the value is added, not the meta
      // rebuilt.
      expect(
        DetachedClipLayerData.sourceOffsetOf(
          DetachedClipLayerData.metaOf(layer),
        ),
        const Duration(seconds: 1),
      );
      verify(
        () => mainBloc.add(
          const VideoEditorDetachedClipOpacityPreviewChanged(null),
        ),
      ).called(1);
    });

    testWidgets('puts the layer back on cancel', (tester) async {
      await pump(tester, _detachedLayer());

      await drag(tester, 0.4);
      await tapSheetButton(tester, DivineIconName.x);

      verifyNothingWritten();
      verify(
        () => mainBloc.add(
          const VideoEditorDetachedClipOpacityPreviewChanged(null),
        ),
      ).called(1);
    });

    testWidgets('keeps what the canvas shows when the sheet is swiped away', (
      tester,
    ) async {
      await pump(tester, _detachedLayer());

      await drag(tester, 0.4);
      // Above the sheet: the barrier is clear so the canvas can be judged,
      // which also makes it easy to tap without meaning to cancel.
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();

      expect(find.byType(LayerOpacitySheet), findsNothing);
      expect(
        DetachedClipLayerData.opacityOf(
          DetachedClipLayerData.metaOf(written()),
        ),
        0.4,
      );
    });

    testWidgets('writes nothing when the slider ends where it started', (
      tester,
    ) async {
      await pump(tester, _detachedLayer());

      await drag(tester, 0.4);
      await drag(tester, 1);
      await tapSheetButton(tester, DivineIconName.check);

      // An undo step that undoes nothing reads as a broken undo.
      verifyNothingWritten();
    });

    testWidgets('moves the playhead onto a clip that is not on screen', (
      tester,
    ) async {
      // A clip is not drawn outside its window, so the slider would fade
      // nothing visible.
      when(() => mainBloc.state).thenReturn(const VideoEditorMainState());

      await pump(tester, _detachedLayer());

      verify(
        () =>
            mainBloc.add(const VideoEditorSeekRequested(Duration(seconds: 2))),
      ).called(1);
    });

    testWidgets('leaves the playhead alone while the clip is on screen', (
      tester,
    ) async {
      await pump(tester, _detachedLayer());

      verifyNever(
        () => mainBloc.add(any(that: isA<VideoEditorSeekRequested>())),
      );
    });

    testWidgets("leaves the playhead alone on the clip's last frame", (
      tester,
    ) async {
      // The window is closed at both ends, so the clip is still drawn with
      // the playhead exactly on its end. Trimming that end leaves it there.
      when(() => mainBloc.state).thenReturn(
        const VideoEditorMainState(currentPosition: Duration(seconds: 6)),
      );

      await pump(tester, _detachedLayer());

      verifyNever(
        () => mainBloc.add(any(that: isA<VideoEditorSeekRequested>())),
      );
    });

    testWidgets("moves the playhead back from past the clip's end", (
      tester,
    ) async {
      when(() => mainBloc.state).thenReturn(
        const VideoEditorMainState(
          currentPosition: Duration(seconds: 6, milliseconds: 1),
        ),
      );

      await pump(tester, _detachedLayer());

      verify(
        () =>
            mainBloc.add(const VideoEditorSeekRequested(Duration(seconds: 2))),
      ).called(1);
    });
  });
}
