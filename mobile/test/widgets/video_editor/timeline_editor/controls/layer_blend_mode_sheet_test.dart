// ABOUTME: Drives a layer's blend action end to end: the live preview of each
// ABOUTME: mode tapped, and the one history step it writes onto the layer.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/extensions/layer_blend_mode.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/layer_blend_mode_sheet.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '../../../../helpers/scroll.dart';

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

void main() {
  group('editLayerBlendMode', () {
    late _MockProImageEditorState editor;
    late _MockVideoEditorMainBloc mainBloc;
    late ValueNotifier<Duration> playTime;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUpAll(() {
      registerFallbackValue(_FakeLayer());
      registerFallbackValue(const VideoEditorSeekRequested(Duration.zero));
    });

    setUp(() {
      editor = _MockProImageEditorState();
      when(() => editor.mounted).thenReturn(true);
      when(
        () => editor.replaceLayer(
          index: any(named: 'index'),
          layer: any(named: 'layer'),
          skipUpdateHistory: any(named: 'skipUpdateHistory'),
        ),
      ).thenAnswer((_) {});
      mainBloc = _MockVideoEditorMainBloc();
      when(() => mainBloc.state).thenReturn(const VideoEditorMainState());
      playTime = ValueNotifier(const Duration(seconds: 3));
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
            playTimeNotifier: playTime,
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
                    editLayerBlendMode(context, layer, item: _item),
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

    Future<void> tapSheetButton(
      WidgetTester tester,
      DivineIconName icon,
    ) async {
      await tester.tap(
        find.descendant(
          of: find.byType(LayerBlendModeSheet),
          matching: find.byWidgetPredicate(
            (w) => w is DivineIconButton && w.icon == icon,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Taps the chip [label], scrolling the row to it first: the later
    /// modes start past the sheet's edge.
    Future<void> tapMode(WidgetTester tester, String label) async {
      await scrollUntilTappable(
        tester,
        find.text(label),
        100,
        scrollable: find.descendant(
          of: find.byType(LayerBlendModeSheet),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text(label));
      await tester.pump();
    }

    /// The modes of the layers shown on the canvas without a history step,
    /// in order.
    List<BlendMode> previewed() => verify(
      () => editor.replaceLayer(
        index: 0,
        layer: captureAny(named: 'layer'),
        skipUpdateHistory: true,
      ),
    ).captured.map((layer) => (layer as Layer).blendMode).toList();

    /// The modes of the layers written as history steps, in order.
    List<BlendMode> written() => verify(
      () => editor.replaceLayer(index: 0, layer: captureAny(named: 'layer')),
    ).captured.map((layer) => (layer as Layer).blendMode).toList();

    void verifyNothingWritten() => verifyNever(
      () => editor.replaceLayer(
        index: any(named: 'index'),
        layer: any(named: 'layer'),
      ),
    );

    testWidgets("offers every mode, the layer's own one selected", (
      tester,
    ) async {
      await pump(tester, TextLayer(text: 'a', blendMode: BlendMode.screen));

      expect(editorBlendModes, hasLength(9));
      for (final label in [
        l10n.videoEditorBlendModeNormal,
        l10n.videoEditorBlendModeMultiply,
        l10n.videoEditorBlendModeDarken,
        l10n.videoEditorBlendModeScreen,
        l10n.videoEditorBlendModeLighten,
        l10n.videoEditorBlendModeAdd,
        l10n.videoEditorBlendModeOverlay,
        l10n.videoEditorBlendModeSoftLight,
        l10n.videoEditorBlendModeDifference,
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(
        tester.getSemantics(find.text(l10n.videoEditorBlendModeScreen)),
        isSemantics(isSelected: true, isButton: true, hasEnabledState: true),
      );
    });

    testWidgets('previews every mode tapped and writes the last as one step', (
      tester,
    ) async {
      await pump(tester, TextLayer(id: 'layer-1', text: 'a'));

      await tapMode(tester, l10n.videoEditorBlendModeScreen);
      await tapMode(tester, l10n.videoEditorBlendModeMultiply);
      await tapSheetButton(tester, DivineIconName.check);

      // Each mode shows on the canvas, then the layer is put back before the
      // one history step is written.
      expect(previewed(), [
        BlendMode.screen,
        BlendMode.multiply,
        BlendMode.srcOver,
      ]);
      expect(written(), [BlendMode.multiply]);
    });

    testWidgets('keeps what the canvas shows when the sheet is swiped away', (
      tester,
    ) async {
      await pump(tester, TextLayer(id: 'layer-1', text: 'a'));

      await tapMode(tester, l10n.videoEditorBlendModeDifference);
      // Above the sheet: the barrier is clear so the canvas can be judged.
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();

      expect(find.byType(LayerBlendModeSheet), findsNothing);
      expect(written(), [BlendMode.difference]);
    });

    testWidgets('puts the layer back on cancel and writes nothing', (
      tester,
    ) async {
      await pump(tester, TextLayer(id: 'layer-1', text: 'a'));

      await tapMode(tester, l10n.videoEditorBlendModeAdd);
      await tapSheetButton(tester, DivineIconName.x);

      expect(previewed(), [BlendMode.plus, BlendMode.srcOver]);
      verifyNothingWritten();
    });

    testWidgets('writes nothing when the sheet closes on the mode it opened '
        'with', (tester) async {
      await pump(
        tester,
        TextLayer(id: 'layer-1', text: 'a', blendMode: BlendMode.overlay),
      );

      await tapMode(tester, l10n.videoEditorBlendModeNormal);
      await tapMode(tester, l10n.videoEditorBlendModeOverlay);
      await tapSheetButton(tester, DivineIconName.check);

      verifyNothingWritten();
    });

    testWidgets('moves a playhead outside the layer to its start', (
      tester,
    ) async {
      playTime.value = const Duration(seconds: 8);
      await pump(tester, TextLayer(id: 'layer-1', text: 'a'));

      verify(
        () =>
            mainBloc.add(const VideoEditorSeekRequested(Duration(seconds: 2))),
      ).called(1);
    });
  });
}
