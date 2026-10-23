import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/text_wrap_hint/text_wrap_hint_cubit.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_text_wrap_hint.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar_chip.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

void main() {
  setUpAll(() => registerFallbackValue(TextLayer(text: 'fallback')));

  group(VideoEditorTextWrapHint, () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    late _MockProImageEditorState editor;
    late TextWrapHintCubit cubit;

    setUp(() {
      editor = _MockProImageEditorState();
      cubit = TextWrapHintCubit();
      addTearDown(cubit.close);
    });

    /// Shows the hint for [layer], whose wrapped layout the editor reports
    /// as [wrapsAtEdges]; a [pinned] hint stands for a timeline selection.
    Future<void> pumpHint(
      WidgetTester tester,
      TextLayer layer, {
      required bool wrapsAtEdges,
      bool pinned = true,
    }) async {
      when(() => editor.activeLayers).thenReturn([layer]);
      when(() => editor.textLayerWrapsAtBounds(any())).thenReturn(wrapsAtEdges);
      if (pinned) {
        cubit.layerSelected(layer.id);
      } else {
        cubit.layerTransformed(layer.id);
      }
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: VideoEditorScope(
                editorKey: GlobalKey(),
                removeAreaKey: GlobalKey(),
                originalClipAspectRatio: 9 / 16,
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
                child: const Row(
                  children: [
                    VideoEditorTextWrapHint(fallback: Text('fallback')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    TextLayer replacedLayer() =>
        verify(
              () => editor.replaceLayer(
                index: 0,
                layer: captureAny(named: 'layer'),
              ),
            ).captured.single
            as TextLayer;

    testWidgets('lets a text the edges wrap run past them', (tester) async {
      final layer = TextLayer(text: 'Big title');
      await pumpHint(tester, layer, wrapsAtEdges: true);

      expect(
        tester.getSemantics(find.byType(VideoEditorToolbarChip)),
        isSemantics(
          label: l10n.videoEditorTextDontWrap,
          isLiveRegion: true,
        ),
      );
      await tester.tap(find.text(l10n.videoEditorTextDontWrap));

      final replaced = replacedLayer();
      expect(replaced.id, layer.id);
      expect(replaced.wrapAtLayerBounds, isFalse);
    });

    testWidgets('wraps a text that runs past the edges again', (tester) async {
      await pumpHint(
        tester,
        TextLayer(text: 'Big title', wrapAtLayerBounds: false),
        wrapsAtEdges: true,
      );

      await tester.tap(find.text(l10n.videoEditorTextWrapAtEdges));

      expect(replacedLayer().wrapAtLayerBounds, isTrue);
    });

    testWidgets('offers the other direction once the layer change reaches it', (
      tester,
    ) async {
      await pumpHint(tester, TextLayer(text: 'Big title'), wrapsAtEdges: true);
      await tester.tap(find.text(l10n.videoEditorTextDontWrap));

      when(() => editor.activeLayers).thenReturn([replacedLayer()]);
      cubit.layersChanged();
      await tester.pump();

      expect(find.text(l10n.videoEditorTextWrapAtEdges), findsOneWidget);
    });

    testWidgets('stays a while longer after a tap on it after a pinch', (
      tester,
    ) async {
      await pumpHint(
        tester,
        TextLayer(text: 'Big title'),
        wrapsAtEdges: true,
        pinned: false,
      );

      await tester.pump(TextWrapHintCubit.defaultTransientDuration * 0.75);
      await tester.tap(find.text(l10n.videoEditorTextDontWrap));
      await tester.pump(TextWrapHintCubit.defaultTransientDuration * 0.75);
      expect(find.text(l10n.videoEditorTextDontWrap), findsOneWidget);

      await tester.pump(TextWrapHintCubit.defaultTransientDuration * 0.25);
      expect(find.byType(VideoEditorToolbarChip), findsNothing);
    });

    testWidgets('keeps the fallback for a text the edges do not wrap', (
      tester,
    ) async {
      await pumpHint(tester, TextLayer(text: 'Hi'), wrapsAtEdges: false);

      expect(find.text('fallback'), findsOneWidget);
      expect(find.byType(VideoEditorToolbarChip), findsNothing);
    });

    testWidgets('keeps the fallback for a text that runs past the edges but '
        'would fit inside them', (tester) async {
      await pumpHint(
        tester,
        TextLayer(text: 'Hi', wrapAtLayerBounds: false),
        wrapsAtEdges: false,
      );

      expect(find.text('fallback'), findsOneWidget);
      expect(find.byType(VideoEditorToolbarChip), findsNothing);
    });
  });

  group('textWrapHintLayerIdOf', () {
    test('takes the id of a text layer', () {
      final layer = TextLayer(text: 'Title');

      expect(textWrapHintLayerIdOf(layer), layer.id);
    });

    test('ignores a burned-in caption', () {
      final caption = TextLayer(
        text: 'Caption',
        meta: {VideoEditorConstants.captionCueMetaKey: true},
      );

      expect(textWrapHintLayerIdOf(caption), isNull);
    });

    test('ignores any other layer', () {
      expect(textWrapHintLayerIdOf(EmojiLayer(emoji: '🎉')), isNull);
    });
  });
}
