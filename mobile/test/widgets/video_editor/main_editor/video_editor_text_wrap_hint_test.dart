import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/text_wrap_hint/text_wrap_hint_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_text_wrap_hint.dart';
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

    Future<void> pumpHint(WidgetTester tester, TextLayer layer) async {
      when(() => editor.activeLayers).thenReturn([layer]);
      cubit.layerSelected(layer.id);
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

    testWidgets('lets a text the edges wrap run past them', (tester) async {
      final layer = TextLayer(text: 'Big title');
      when(() => editor.textLayerWrapsAtBounds(layer)).thenReturn(true);
      await pumpHint(tester, layer);

      await tester.tap(find.text(l10n.videoEditorTextDontWrap));

      final replaced =
          verify(
                () => editor.replaceLayer(
                  index: 0,
                  layer: captureAny(named: 'layer'),
                ),
              ).captured.single
              as TextLayer;
      expect(replaced.id, layer.id);
      expect(replaced.wrapAtLayerBounds, isFalse);
    });

    testWidgets('wraps a text that runs past the edges again', (tester) async {
      final layer = TextLayer(text: 'Big title', wrapAtLayerBounds: false);
      await pumpHint(tester, layer);

      await tester.tap(find.text(l10n.videoEditorTextWrapAtEdges));

      final replaced =
          verify(
                () => editor.replaceLayer(
                  index: 0,
                  layer: captureAny(named: 'layer'),
                ),
              ).captured.single
              as TextLayer;
      expect(replaced.wrapAtLayerBounds, isTrue);
    });

    testWidgets('keeps the fallback for a text the edges do not wrap', (
      tester,
    ) async {
      final layer = TextLayer(text: 'Hi');
      when(() => editor.textLayerWrapsAtBounds(layer)).thenReturn(false);
      await pumpHint(tester, layer);

      expect(find.text('fallback'), findsOneWidget);
      expect(find.text(l10n.videoEditorTextDontWrap), findsNothing);
    });
  });
}
