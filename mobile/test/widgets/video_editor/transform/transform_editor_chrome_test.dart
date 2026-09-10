// ABOUTME: Widget tests for the shared crop-rotate editor chrome.
// ABOUTME: Covers the app-bar and bottom-bar actions both transform screens use.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/transform/transform_editor_chrome.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show CropRotateEditorState;

class _MockCropRotateEditorState extends Mock implements CropRotateEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockCropRotateEditorState';
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  late _MockCropRotateEditorState editorState;

  setUp(() {
    editorState = _MockCropRotateEditorState();
    when(editorState.done).thenAnswer((_) async {});
  });

  Finder buttonWithIcon(DivineIconName icon) => find.byWidgetPredicate(
    (widget) => widget is DivineIconButton && widget.icon == icon,
  );

  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(body: child),
      ),
    );
  }

  group(TransformEditorAppBar, () {
    testWidgets('cancels the transform from the back button', (tester) async {
      await pump(tester, TransformEditorAppBar(editorState: editorState));

      await tester.tap(buttonWithIcon(DivineIconName.arrowLeft));
      await tester.pump();

      verify(editorState.close).called(1);
      verifyNever(editorState.done);
    });

    testWidgets('applies the transform from the done button', (tester) async {
      await pump(tester, TransformEditorAppBar(editorState: editorState));

      await tester.tap(buttonWithIcon(DivineIconName.check));
      await tester.pump();

      verify(editorState.done).called(1);
    });
  });

  group(TransformEditorBottomBar, () {
    testWidgets('rotates, flips and resets through the editor state', (
      tester,
    ) async {
      await pump(tester, TransformEditorBottomBar(editorState: editorState));

      await tester.tap(buttonWithIcon(DivineIconName.arrowArcLeft));
      await tester.tap(buttonWithIcon(DivineIconName.cameraRotate));
      await tester.tap(buttonWithIcon(DivineIconName.arrowsCounterClockwise));
      await tester.pump();

      verify(editorState.rotate).called(1);
      verify(editorState.flip).called(1);
      verify(() => editorState.reset()).called(1);
    });

    testWidgets('renders no leading action when none is supplied', (
      tester,
    ) async {
      // A still has nothing to play, so the frame editor's bar is
      // rotate/flip/reset only.
      await pump(tester, TransformEditorBottomBar(editorState: editorState));

      expect(find.byType(TransformEditorAction), findsNWidgets(3));
      expect(find.text(l10n.videoEditorTransformPlayLabel), findsNothing);
    });

    testWidgets('renders the leading action before rotate', (tester) async {
      await pump(
        tester,
        TransformEditorBottomBar(
          editorState: editorState,
          leading: TransformEditorAction(
            icon: .play,
            label: l10n.videoEditorTransformPlayLabel,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byType(TransformEditorAction), findsNWidgets(4));
      expect(
        tester.getTopLeft(find.text(l10n.videoEditorTransformPlayLabel)).dx,
        lessThan(
          tester.getTopLeft(find.text(l10n.videoEditorTransformRotateLabel)).dx,
        ),
      );
    });
  });
}
