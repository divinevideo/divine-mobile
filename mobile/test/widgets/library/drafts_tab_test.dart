// ABOUTME: Tests for DraftsTab widget
// ABOUTME: Verifies drafts list, loading, error, and empty states

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/drafts_library/drafts_library_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/widgets/library/drafts_tab.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockDraftsLibraryBloc
    extends MockBloc<DraftsLibraryEvent, DraftsLibraryState>
    implements DraftsLibraryBloc {}

DivineVideoClip _createTestClip([String id = 'clip_1']) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/tmp/test.mp4'),
  duration: const Duration(seconds: 6),
  recordedAt: DateTime(2025),
  originalAspectRatio: 9 / 16,
  targetAspectRatio: .vertical,
);

void main() {
  final en = AppLocalizationsEn();

  group(DraftsTab, () {
    late _MockDraftsLibraryBloc mockBloc;

    DivineVideoDraft createDraft({
      String? id,
      String title = 'Test Draft',
      // Defaults to one clip because a draft without any is not a state the
      // library can produce — and post eligibility keys off having something
      // to publish.
      List<DivineVideoClip>? clips,
      DivineVideoClip? finalRenderedClip,
    }) {
      return DivineVideoDraft(
        id: id ?? 'draft-${DateTime.now().millisecondsSinceEpoch}',
        clips: clips ?? [_createTestClip()],
        title: title,
        description: 'Test Description',
        hashtags: const {},
        selectedApproach: 'default',
        createdAt: DateTime(2026),
        lastModified: DateTime(2026),
        publishStatus: PublishStatus.draft,
        publishAttempts: 0,
        finalRenderedClip: finalRenderedClip,
      );
    }

    setUp(() {
      mockBloc = _MockDraftsLibraryBloc();
    });

    Widget buildWidget({bool isSelectionMode = true}) {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            body: BlocProvider<DraftsLibraryBloc>.value(
              value: mockBloc,
              child: DraftsTab(showRecordButton: isSelectionMode),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('loading indicator when initial state', (tester) async {
        when(() => mockBloc.state).thenReturn(const DraftsLibraryInitial());

        await tester.pumpWidget(buildWidget());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('loading indicator when loading state', (tester) async {
        when(() => mockBloc.state).thenReturn(const DraftsLibraryLoading());

        await tester.pumpWidget(buildWidget());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('friendly error and retry when error state', (tester) async {
        when(() => mockBloc.state).thenReturn(const DraftsLibraryError());

        await tester.pumpWidget(buildWidget());

        expect(find.text(en.libraryCouldNotLoadDrafts), findsOneWidget);
        expect(find.text(en.searchTryAgain), findsOneWidget);
        expect(find.text('Failed to load drafts'), findsNothing);
      });

      testWidgets('$EmptyLibraryState when no drafts', (tester) async {
        when(
          () => mockBloc.state,
        ).thenReturn(const DraftsLibraryLoaded(drafts: []));

        await tester.pumpWidget(buildWidget());

        expect(find.byType(EmptyLibraryState), findsOneWidget);
        expect(find.text(en.libraryNoDraftsYetTitle), findsOneWidget);
      });

      testWidgets('drafts list when drafts are loaded', (tester) async {
        when(() => mockBloc.state).thenReturn(
          DraftsLibraryLoaded(
            drafts: [
              createDraft(id: 'draft1', title: 'Draft 1'),
              createDraft(id: 'draft2', title: 'Draft 2'),
            ],
          ),
        );

        await tester.pumpWidget(buildWidget());

        expect(find.byType(ListView), findsOneWidget);
        expect(find.byType(DraftListTile), findsNWidgets(2));
      });

      testWidgets('shows autosaved draft with in-progress badge', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          DraftsLibraryLoaded(
            drafts: [
              createDraft(
                id: VideoEditorConstants.autoSaveId,
                title: 'Autosaved',
              ),
              createDraft(id: 'real-draft', title: 'Real Draft'),
            ],
          ),
        );

        await tester.pumpWidget(buildWidget());

        expect(find.byType(DraftListTile), findsNWidgets(2));
        expect(find.text('Autosaved'), findsOneWidget);
        expect(find.text(en.libraryDraftInProgressBadge), findsOneWidget);
      });
    });

    group('post action', () {
      // #5203 hid this action for drafts with no cached render, because
      // publishing one shipped the raw recording without its editor layers.
      // Publish now renders on demand with those layers restored, so the
      // action stays available.
      testWidgets('shows post action when draft has no final render', (
        tester,
      ) async {
        when(
          () => mockBloc.state,
        ).thenReturn(DraftsLibraryLoaded(drafts: [createDraft(id: 'draft1')]));

        await tester.pumpWidget(buildWidget());
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();

        expect(find.text(en.libraryDraftActionPost), findsOneWidget);
        expect(find.text(en.libraryDraftActionEdit), findsOneWidget);
        expect(find.text(en.libraryDraftActionDelete), findsOneWidget);
      });

      testWidgets('shows post action when draft has a final render', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          DraftsLibraryLoaded(
            drafts: [
              createDraft(id: 'draft1', finalRenderedClip: _createTestClip()),
            ],
          ),
        );

        await tester.pumpWidget(buildWidget());
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();

        expect(find.text(en.libraryDraftActionPost), findsOneWidget);
      });
    });

    group('duplicate action', () {
      testWidgets('shows duplicate action in the options menu', (tester) async {
        when(
          () => mockBloc.state,
        ).thenReturn(DraftsLibraryLoaded(drafts: [createDraft(id: 'draft1')]));

        await tester.pumpWidget(buildWidget());
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();

        expect(find.text(en.libraryDraftActionDuplicate), findsOneWidget);
      });

      testWidgets(
        'dispatches duplicate event with a numbered copy title when tapped',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            DraftsLibraryLoaded(
              drafts: [createDraft(id: 'draft1', title: 'My Project')],
            ),
          );

          await tester.pumpWidget(buildWidget());
          await tester.tap(find.byType(IconButton));
          await tester.pumpAndSettle();
          await tester.tap(find.text(en.libraryDraftActionDuplicate));
          await tester.pumpAndSettle();

          verify(
            () => mockBloc.add(
              DraftsLibraryDuplicateRequested(
                'draft1',
                newTitle: en.libraryDraftCopyTitle('My Project', 1),
              ),
            ),
          ).called(1);
        },
      );

      testWidgets('numbers the next copy instead of stacking suffixes', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          DraftsLibraryLoaded(
            drafts: [
              createDraft(id: 'copy', title: 'My Project (copy 1)'),
              createDraft(id: 'orig', title: 'My Project'),
            ],
          ),
        );

        await tester.pumpWidget(buildWidget());
        // First tile is the existing copy; open its options menu.
        await tester.tap(find.byType(IconButton).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(en.libraryDraftActionDuplicate));
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(
            DraftsLibraryDuplicateRequested(
              'copy',
              newTitle: en.libraryDraftCopyTitle('My Project', 2),
            ),
          ),
        ).called(1);
      });

      testWidgets('duplicate of an untitled draft keeps a null title', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          DraftsLibraryLoaded(
            drafts: [createDraft(id: 'draft1', title: '')],
          ),
        );

        await tester.pumpWidget(buildWidget());
        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(en.libraryDraftActionDuplicate));
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(const DraftsLibraryDuplicateRequested('draft1')),
        ).called(1);
      });
    });

    group('snackbar feedback', () {
      Future<void> pumpWithEmittedState(
        WidgetTester tester,
        DraftsLibraryState emitted,
      ) async {
        final drafts = [createDraft(id: 'draft1')];
        whenListen(
          mockBloc,
          Stream<DraftsLibraryState>.value(emitted),
          initialState: DraftsLibraryLoaded(drafts: drafts),
        );

        await tester.pumpWidget(buildWidget());
        await tester.pump(); // deliver the emitted state
        await tester.pump(); // start the snackbar entrance animation
      }

      testWidgets('shows the duplicated snackbar on '
          '$DraftsLibraryDraftDuplicated', (tester) async {
        await pumpWithEmittedState(
          tester,
          DraftsLibraryDraftDuplicated(drafts: [createDraft(id: 'draft1')]),
        );

        expect(find.text(en.libraryDraftDuplicatedSnackbar), findsOneWidget);
      });

      testWidgets('shows the duplicate-failed snackbar on '
          '$DraftsLibraryDuplicateFailed', (tester) async {
        await pumpWithEmittedState(
          tester,
          DraftsLibraryDuplicateFailed(drafts: [createDraft(id: 'draft1')]),
        );

        expect(
          find.text(en.libraryDraftDuplicateFailedSnackbar),
          findsOneWidget,
        );
      });

      testWidgets('shows the deleted snackbar on $DraftsLibraryDraftDeleted', (
        tester,
      ) async {
        await pumpWithEmittedState(
          tester,
          const DraftsLibraryDraftDeleted(drafts: []),
        );

        expect(find.text(en.libraryDraftDeletedSnackbar), findsOneWidget);
      });

      testWidgets('shows the delete-failed snackbar on '
          '$DraftsLibraryDeleteFailed', (tester) async {
        await pumpWithEmittedState(
          tester,
          DraftsLibraryDeleteFailed(drafts: [createDraft(id: 'draft1')]),
        );

        expect(find.text(en.libraryDraftDeleteFailedSnackbar), findsOneWidget);
      });
    });
  });

  group(DraftListTile, () {
    DivineVideoDraft createDraft({
      String? id,
      String title = 'Test Draft',
      DateTime? lastModified,
    }) {
      return DivineVideoDraft(
        id: id ?? 'draft-${DateTime.now().millisecondsSinceEpoch}',
        clips: const [],
        title: title,
        description: 'Test Description',
        hashtags: const {},
        selectedApproach: 'default',
        createdAt: DateTime(2026),
        lastModified: lastModified ?? DateTime(2026),
        publishStatus: PublishStatus.draft,
        publishAttempts: 0,
      );
    }

    Widget buildWidget({
      required DivineVideoDraft draft,
      VoidCallback? onTap,
      VoidCallback? onOpenMore,
      bool enableShrink = false,
    }) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: DraftListTile(
            draft: draft,
            onTap: onTap,
            onOpenMore: onOpenMore,
            enableShrink: enableShrink,
          ),
        ),
      );
    }

    testWidgets('renders draft title', (tester) async {
      await tester.pumpWidget(
        buildWidget(draft: createDraft(title: 'My Video Draft')),
      );

      expect(find.text('My Video Draft'), findsOneWidget);
    });

    testWidgets('shows untitled when title is empty', (tester) async {
      await tester.pumpWidget(buildWidget(draft: createDraft(title: '')));

      expect(find.text(en.draftUntitled), findsOneWidget);
    });

    testWidgets('shows in-progress badge for autosaved draft', (tester) async {
      await tester.pumpWidget(
        buildWidget(draft: createDraft(id: VideoEditorConstants.autoSaveId)),
      );

      expect(find.text(en.libraryDraftInProgressBadge), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildWidget(draft: createDraft(), onTap: () => tapped = true),
      );

      await tester.tap(find.byType(InkWell).first);
      expect(tapped, isTrue);
    });

    testWidgets('shows more button when onOpenMore is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(draft: createDraft(), onOpenMore: () {}),
      );

      // Finds the trailing IconButton (more options button)
      expect(find.byType(IconButton), findsOneWidget);
    });
  });
}
