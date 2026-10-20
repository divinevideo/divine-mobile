// ABOUTME: Tests for the split-screen layout preview: reframing one cell
// ABOUTME: leaves the others as they were

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/split_screen_layout/split_screen_layout_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/split_screen_layout/split_screen_layout_preview.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

DivineVideoClip _clip(String id) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/documents/$id.mp4'),
  duration: const Duration(seconds: 2),
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
);

void main() {
  group(SplitScreenLayoutPreview, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    testWidgets('leaves the other cells alone while one is reframed', (
      tester,
    ) async {
      final cubit = SplitScreenLayoutCubit(
        aspectRatio: model.AspectRatio.vertical,
        borderColor: VineTheme.backgroundColor,
      )..clipsPicked([_clip('a'), _clip('b')]);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: const SplitScreenLayoutPreview(),
            ),
          ),
        ),
      );
      final second = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label ==
                l10n.videoEditorLayoutCellSemanticLabel('2'),
      );
      final before = tester.widget(second);

      cubit.cellReframed(
        0,
        focalPoint: Offset.zero,
        delta: const Offset(10, 0),
        zoom: 2,
        cellSize: const Size(90, 320),
      );
      await tester.pump();

      expect(cubit.state.cells.first!.zoom, 2);
      expect(identical(tester.widget(second), before), isTrue);
    });
  });
}
