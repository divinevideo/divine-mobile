// ABOUTME: Tests for the Deleted filter's trashed-clip list
// ABOUTME: Verifies restore/hard-delete wiring, countdown copy, and empty state

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';
import 'package:openvine/widgets/library/trashed_clips_list.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockClipsLibraryBloc
    extends MockBloc<ClipsLibraryEvent, ClipsLibraryState>
    implements ClipsLibraryBloc {}

void main() {
  final en = AppLocalizationsEn();

  group(TrashedClipsList, () {
    late _MockClipsLibraryBloc mockBloc;

    final trashedClip = DivineVideoClip(
      id: 'trashed-clip',
      video: EditorVideo.file('/tmp/trashed.mp4'),
      thumbnailPath: '/tmp/trashed.jpg',
      duration: const Duration(seconds: 5),
      recordedAt: DateTime(2026, 5),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
      deletedAt: DateTime.now().subtract(const Duration(days: 28)),
    );

    setUp(() {
      mockBloc = _MockClipsLibraryBloc();
    });

    Widget buildWidget(ClipsLibraryState state) {
      when(() => mockBloc.state).thenReturn(state);
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: BlocProvider<ClipsLibraryBloc>.value(
            value: mockBloc,
            child: const TrashedClipsList(),
          ),
        ),
      );
    }

    testWidgets('shows the purge countdown and restores a clip', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(
          ClipsLibraryState(
            status: ClipsLibraryStatus.trashLoaded,
            filter: const ClipLibraryTrashFilter(),
            trashedClips: [trashedClip],
          ),
        ),
      );
      await tester.pump();

      expect(find.text(en.libraryTrashAutoDeletes(2)), findsOneWidget);
      expect(find.text(en.libraryClipDuration('5.00')), findsOneWidget);
      expect(find.text('5.00'), findsNothing);

      await tester.tap(find.bySemanticsLabel(en.libraryTrashRestoreLabel));
      await tester.pump();

      verify(
        () => mockBloc.add(const ClipsLibraryRestoreClips({'trashed-clip'})),
      ).called(1);
    });

    testWidgets('keeps the fractional duration of a sub-second clip', (
      tester,
    ) async {
      final subSecondClip = trashedClip.copyWith(
        id: 'sub-second-clip',
        duration: const Duration(milliseconds: 400),
      );

      await tester.pumpWidget(
        buildWidget(
          ClipsLibraryState(
            status: ClipsLibraryStatus.trashLoaded,
            filter: const ClipLibraryTrashFilter(),
            trashedClips: [subSecondClip],
          ),
        ),
      );
      await tester.pump();

      expect(find.text(en.libraryClipDuration('0.40')), findsOneWidget);
      expect(find.text('0.40'), findsNothing);
      expect(find.text('0s'), findsNothing);
    });

    testWidgets('confirms before hard-deleting a clip', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          ClipsLibraryState(
            status: ClipsLibraryStatus.trashLoaded,
            filter: const ClipLibraryTrashFilter(),
            trashedClips: [trashedClip],
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.bySemanticsLabel(en.libraryTrashDeleteNowLabel));
      await tester.pumpAndSettle();

      expect(find.text(en.libraryTrashDeleteConfirmTitle), findsOneWidget);
      verifyNever(() => mockBloc.add(ClipsLibraryHardDeleteClip(trashedClip)));

      await tester.tap(find.text(en.libraryDeleteConfirm));
      await tester.pumpAndSettle();

      verify(
        () => mockBloc.add(ClipsLibraryHardDeleteClip(trashedClip)),
      ).called(1);
    });

    testWidgets(
      'does not overflow a 360dp row at default or large text scale',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        Future<void> pumpAt(double textScale) async {
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: const Size(360, 800),
                textScaler: TextScaler.linear(textScale),
              ),
              child: buildWidget(
                ClipsLibraryState(
                  status: ClipsLibraryStatus.trashLoaded,
                  filter: const ClipLibraryTrashFilter(),
                  trashedClips: [trashedClip],
                ),
              ),
            ),
          );
          await tester.pump();
        }

        await pumpAt(1);
        expect(tester.takeException(), isNull);
        expect(find.text(en.libraryTrashAutoDeletes(2)), findsOneWidget);

        await pumpAt(1.5);
        expect(tester.takeException(), isNull);

        await pumpAt(3);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('shows the empty state when the bin is empty', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          const ClipsLibraryState(
            status: ClipsLibraryStatus.trashLoaded,
            filter: ClipLibraryTrashFilter(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(EmptyLibraryState), findsOneWidget);
      expect(find.text(en.libraryTrashEmptyTitle), findsOneWidget);
    });
  });
}
