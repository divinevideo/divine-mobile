// ABOUTME: Unit and widget tests for VideoEditorScope.
// ABOUTME: Verifies scale calculation and InheritedWidget access.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

void main() {
  group(VideoEditorScope, () {
    test('calculateFittedBoxScale returns 1.0 for zero size', () {
      final scale = VideoEditorScope.calculateFittedBoxScale(Size.zero, 9 / 16);
      expect(scale, equals(1.0));
    });

    test('calculateFittedBoxScale returns expected positive scale', () {
      final scale = VideoEditorScope.calculateFittedBoxScale(
        const Size(400, 800),
        9 / 16,
      );

      expect(scale, greaterThan(0));
    });

    test('calculateFittedBoxScale matches square canvas on portrait body', () {
      final scale = VideoEditorScope.calculateFittedBoxScale(
        const Size(400, 800),
        1,
        targetAspectRatio: 1,
      );

      expect(scale, equals(1));
    });

    test('calculateFittedBoxScale covers contained vertical target area', () {
      final scale = VideoEditorScope.calculateFittedBoxScale(
        const Size(400, 800),
        9 / 16,
        targetAspectRatio: 9 / 16,
      );

      expect(scale, closeTo(16 / 9, 0.001));
    });

    test('calculateFittedBoxScale covers target area on wide body', () {
      final scale = VideoEditorScope.calculateFittedBoxScale(
        const Size(800, 400),
        1,
        targetAspectRatio: 9 / 16,
      );

      expect(scale, closeTo(1, 0.001));
    });

    test('calculateFittedBoxScale uses target aspect ratio separately', () {
      final scale = VideoEditorScope.calculateFittedBoxScale(
        const Size(400, 800),
        1,
        targetAspectRatio: 9 / 16,
      );

      // A square render covers a vertical target, so the height ratio wins.
      expect(scale, closeTo(16 / 9, 0.001));
    });

    test('calculateTargetSize contains target ratio inside the body', () {
      expect(
        VideoEditorScope.calculateTargetSize(const Size(400, 800), 9 / 16),
        equals(const Size(400, 400 / (9 / 16))),
      );
      expect(
        VideoEditorScope.calculateTargetSize(const Size(800, 400), 9 / 16),
        equals(const Size(400 * 9 / 16, 400)),
      );
    });

    testWidgets('of returns nearest scope from context', (tester) async {
      final editorKey = GlobalKey<ProImageEditorState>();
      final removeAreaKey = GlobalKey();
      late VideoEditorScope resolvedScope;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: VideoEditorScope(
            editorKey: editorKey,
            removeAreaKey: removeAreaKey,
            onOpenCamera: () {},
            onAddStickers: () {},
            onOpenClipsEditor: () {},
            onAddEditTextLayer: ([layer]) async => null,
            onOpenMusicLibrary: () {},
            onOpenVoiceOver: () {},
            onOpenCaptions: () {},
            originalClipAspectRatio: 9 / 16,
            bodySizeNotifier: ValueNotifier(const Size(400, 800)),
            zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
            playTimeNotifier: ValueNotifier(Duration.zero),
            playheadAdvancingNotifier: ValueNotifier<bool>(false),
            fromLibrary: false,
            child: Builder(
              builder: (context) {
                resolvedScope = VideoEditorScope.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(resolvedScope.editorKey, equals(editorKey));
      expect(resolvedScope.removeAreaKey, equals(removeAreaKey));
    });

    testWidgets('requireEditor returns editorOverride when provided', (
      tester,
    ) async {
      final editorKey = GlobalKey<ProImageEditorState>();
      final removeAreaKey = GlobalKey();
      final mockEditor = _MockProImageEditorState();
      late ProImageEditorState resolvedEditor;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: VideoEditorScope(
            editorKey: editorKey,
            editorOverride: mockEditor,
            removeAreaKey: removeAreaKey,
            onOpenCamera: () {},
            onAddStickers: () {},
            onOpenClipsEditor: () {},
            onAddEditTextLayer: ([layer]) async => null,
            onOpenMusicLibrary: () {},
            onOpenVoiceOver: () {},
            onOpenCaptions: () {},
            originalClipAspectRatio: 9 / 16,
            bodySizeNotifier: ValueNotifier(const Size(400, 800)),
            zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
            playTimeNotifier: ValueNotifier(Duration.zero),
            playheadAdvancingNotifier: ValueNotifier<bool>(false),
            fromLibrary: false,
            child: Builder(
              builder: (context) {
                resolvedEditor = VideoEditorScope.of(context).requireEditor;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(identical(resolvedEditor, mockEditor), isTrue);
    });
  });
}
