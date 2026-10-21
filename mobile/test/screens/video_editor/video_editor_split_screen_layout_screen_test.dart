// ABOUTME: Tests for the split-screen layout screen: filling a cell from a
// ABOUTME: picker and handing the rendered layout clip back on Done

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/split_screen_layout/split_screen_layout_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/screens/video_editor/video_editor_split_screen_layout_screen.dart';
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
  group(VideoEditorSplitScreenLayoutView, () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    late List<({double cellAspectRatio, int maxClips})> picks;

    setUp(() => picks = []);

    Future<List<DivineVideoClip>?> pickFromLibrary(
      BuildContext context, {
      required double cellAspectRatio,
      required int maxClips,
    }) async {
      picks.add((cellAspectRatio: cellAspectRatio, maxClips: maxClips));
      return [_clip('picked')];
    }

    Future<List<DivineVideoClip>?> recordNothing(
      BuildContext context, {
      required double cellAspectRatio,
      required int maxClips,
    }) async => null;

    SplitScreenLayoutCubit cubit() => SplitScreenLayoutCubit(
      aspectRatio: model.AspectRatio.vertical,
      borderColor: const Color(0xFF000000),
      renderLayout: ({
        required cells,
        required aspectRatio,
        required backgroundColor,
        required taskId,
      }) async => _clip('layout_of_${cells.single.clip.id}'),
    );

    /// Opens the view on a route of its own, so a pop hands its result to
    /// [onResult].
    Future<void> pump(
      WidgetTester tester, {
      ValueChanged<DivineVideoClip?>? onResult,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final result = await Navigator.of(context)
                    .push<DivineVideoClip>(
                      MaterialPageRoute(
                        builder: (_) => BlocProvider(
                          create: (_) => cubit(),
                          child: VideoEditorSplitScreenLayoutView(
                            pickFromLibrary: pickFromLibrary,
                            recordWithCamera: recordNothing,
                          ),
                        ),
                      ),
                    );
                onResult?.call(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('fills the selected cell with what the library picks', (
      tester,
    ) async {
      await pump(tester);
      expect(
        find.bySemanticsLabel(
          l10n.videoEditorLayoutCellEmptySemanticLabel('1'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.videoEditorLibraryLabel));
      await tester.pumpAndSettle();

      // Side by side in a vertical video, each cell is 9:32. Every cell is
      // free, those only a bigger layout shows included.
      expect(picks.single.cellAspectRatio, closeTo(9 / 32, 1e-9));
      expect(picks.single.maxClips, 4);
      expect(
        find.bySemanticsLabel(l10n.videoEditorLayoutCellSemanticLabel('1')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          l10n.videoEditorLayoutCellEmptySemanticLabel('2'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('hands the rendered layout back on Done', (tester) async {
      DivineVideoClip? result;
      await pump(tester, onResult: (value) => result = value);

      await tester.tap(find.text(l10n.videoEditorLibraryLabel));
      await tester.pumpAndSettle();
      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorLayoutDoneSemanticLabel),
      );
      await tester.pumpAndSettle();

      expect(result?.id, 'layout_of_picked');
      expect(find.byType(VideoEditorSplitScreenLayoutView), findsNothing);
    });
  });
}
