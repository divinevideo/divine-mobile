// ABOUTME: Tests for the split-screen layout controls: the selected cell's
// ABOUTME: Library / Camera / remove actions at large text sizes

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/split_screen_layout/split_screen_layout_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/split_screen_layout/split_screen_layout_controls.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

import '../../../helpers/text_lines.dart';

DivineVideoClip _clip(String id) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/documents/$id.mp4'),
  duration: const Duration(seconds: 2),
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
);

void main() {
  group(SplitScreenCellActions, () {
    /// Pumps the actions on a 360-wide phone with a filled cell selected, so
    /// the remove button takes its share of the row.
    Future<void> pump(WidgetTester tester, {required Locale locale}) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cubit = SplitScreenLayoutCubit(
        aspectRatio: model.AspectRatio.vertical,
        borderColor: VineTheme.backgroundColor,
      )..clipsPicked([_clip('a')]);
      addTearDown(cubit.close);
      cubit.cellSelected(0);
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          locale: locale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: SplitScreenCellActions(
                onPickFromLibrary: () {},
                onRecordWithCamera: () {},
              ),
            ),
          ),
        ),
      );
    }

    /// Whether [label] lost letters to an ellipsis or had a word split.
    bool isCut(WidgetTester tester, String label) =>
        tester
            .renderObject<RenderParagraph>(find.text(label))
            .didExceedMaxLines ||
        wordsSplitAcrossLines(tester, find.text(label)).isNotEmpty;

    testWidgets('keeps Library and Camera side by side while both labels '
        'fit', (tester) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await pump(tester, locale: const Locale('en'));

      expect(isCut(tester, l10n.videoEditorLibraryLabel), isFalse);
      expect(isCut(tester, l10n.videoEditorCameraLabel), isFalse);
      final library = tester.getRect(find.byType(DivineButton).first);
      final camera = tester.getRect(find.byType(DivineButton).last);
      expect(camera.top, library.top);
      expect(camera.width, moreOrLessEquals(library.width));
    });

    testWidgets('gives each button a row of its own once a label would be '
        'cut side by side', (tester) async {
      // Halved beside the remove button, German "Mediathek" was cut at the
      // normal text size.
      final l10n = lookupAppLocalizations(const Locale('de'));
      await pump(tester, locale: const Locale('de'));

      expect(isCut(tester, l10n.videoEditorLibraryLabel), isFalse);
      expect(isCut(tester, l10n.videoEditorCameraLabel), isFalse);
      final library = tester.getRect(find.byType(DivineButton).first);
      final camera = tester.getRect(find.byType(DivineButton).last);
      final remove = tester.getRect(find.byType(DivineIconButton));
      expect(camera.top, greaterThanOrEqualTo(library.bottom));
      expect(remove.left, greaterThanOrEqualTo(camera.right));
      expect(remove.center.dy, moreOrLessEquals(camera.center.dy));
      expect(remove.right, lessThanOrEqualTo(360));
    });
  });
}
