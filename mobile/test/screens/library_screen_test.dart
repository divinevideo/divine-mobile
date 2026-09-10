// ABOUTME: Tests for LibraryScreen - browsing and managing saved clips/drafts
// ABOUTME: Covers tabs, navigation, empty states, and clip selection flows

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/models/clip_category.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/widgets/library/clips_tab.dart';
import 'package:openvine/widgets/library/drafts_tab.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';
import 'package:openvine/widgets/library/pinch_zoom_grid.dart';
import 'package:openvine/widgets/video_clip/video_clip_thumbnail_card.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/go_router.dart';

class _MockGallerySaveService extends Mock implements GallerySaveService {}

class _FakeEditorVideo extends Fake implements EditorVideo {}

class _MockClipLibraryService extends Mock implements ClipLibraryService {}

class _MockDraftStorageService extends Mock implements DraftStorageService {}

DivineVideoDraft _createTestDraft() => DivineVideoDraft(
  id: 'draft-1',
  clips: [
    DivineVideoClip(
      id: 'draft-clip-1',
      video: EditorVideo.file('/test/draft.mp4'),
      duration: const Duration(seconds: 6),
      recordedAt: DateTime(2026),
      targetAspectRatio: models.AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
    ),
  ],
  title: 'Test Draft',
  description: '',
  hashtags: const {},
  selectedApproach: 'default',
  createdAt: DateTime(2026),
  lastModified: DateTime(2026),
  publishStatus: PublishStatus.draft,
  publishAttempts: 0,
);

/// Stands in for the recorder session that opened the library, whose clips
/// become the pre-selected set.
class _StubClipManagerNotifier extends ClipManagerNotifier {
  _StubClipManagerNotifier(this._clips);

  final List<DivineVideoClip> _clips;

  @override
  ClipManagerState build() => ClipManagerState(clips: _clips);
}

List<Object?> _captureAnnouncements(WidgetTester tester) {
  final announced = <Object?>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (message) async {
      if (message is Map && message['type'] == 'announce') {
        announced.add((message['data'] as Map?)?['message']);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return announced;
}

void main() {
  final en = AppLocalizationsEn();

  group(LibraryScreen, () {
    late _MockGallerySaveService mockGallerySaveService;
    late _MockClipLibraryService mockClipLibraryService;
    late _MockDraftStorageService mockDraftStorageService;
    late SharedPreferences sharedPreferences;

    setUpAll(() {
      registerFallbackValue(<DivineVideoClip>[]);
      registerFallbackValue(_FakeEditorVideo());
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockGallerySaveService = _MockGallerySaveService();
      mockClipLibraryService = _MockClipLibraryService();
      mockDraftStorageService = _MockDraftStorageService();

      when(
        () => mockClipLibraryService.getAllClips(),
      ).thenAnswer((_) async => []);
      when(
        () => mockClipLibraryService.getCategories(),
      ).thenAnswer((_) async => []);
      when(
        () => mockDraftStorageService.getAllDrafts(),
      ).thenAnswer((_) async => []);
    });

    Widget buildWidget({
      bool selectionMode = false,
      int initialTabIndex = 0,
      LibraryTabsMode tabsMode = LibraryTabsMode.allTabs,
      List<DivineVideoClip> editorClips = const [],
      List<DivineVideoClip> sessionClips = const [],
    }) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          gallerySaveServiceProvider.overrideWithValue(mockGallerySaveService),
          clipLibraryServiceProvider.overrideWithValue(mockClipLibraryService),
          draftStorageServiceProvider.overrideWithValue(
            mockDraftStorageService,
          ),
          if (sessionClips.isEmpty)
            clipManagerProvider.overrideWith(ClipManagerNotifier.new)
          else
            clipManagerProvider.overrideWith(
              () => _StubClipManagerNotifier(sessionClips),
            ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: LibraryScreen(
            selectionMode: selectionMode,
            initialTabIndex: initialTabIndex,
            tabsMode: tabsMode,
            editorClips: editorClips,
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('screen with tabs and My library title', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        // Should find tab bar with Drafts and Clips
        expect(find.text(en.libraryTabDrafts), findsOneWidget);
        expect(find.text(en.libraryTabClips), findsOneWidget);
      });

      testWidgets('$DraftsTab initially (first tab)', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Drafts tab is default selected (first in order)
        expect(find.byType(DraftsTab), findsOneWidget);
      });

      // The library shell paints its own surface behind the tabs. If that
      // surface is not itself a Material, ListTile ink splashes land on the
      // Material below it and are painted over — Flutter reports this as
      // "ListTile background color or ink splashes may be invisible".
      testWidgets('draft rows keep a visible ink surface', (tester) async {
        when(
          () => mockDraftStorageService.getAllDrafts(),
        ).thenAnswer((_) async => [_createTestDraft()]);

        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(DraftListTile), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('$ClipsTab initially when initialTabIndex is 1', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(initialTabIndex: 1));
        await tester.pumpAndSettle();

        expect(find.byType(ClipsTab), findsOneWidget);
      });

      // A pinch on the clips grid and a tab swipe compete for the same
      // pointers, and the swipe reads a two-finger spread as a horizontal
      // drag. Without this the tabs slide away instead of the grid zooming.
      testWidgets('suspends the tab swipe while the clips grid is pinched', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(initialTabIndex: 1));
        await tester.pumpAndSettle();

        TabBarView tabBarView() =>
            tester.widget<TabBarView>(find.byType(TabBarView));
        expect(tabBarView().physics, isNull);

        final grid = tester.element(find.byType(ClipsTab));
        const PinchZoomNotification(active: true).dispatch(grid);
        await tester.pump();

        expect(tabBarView().physics, isA<NeverScrollableScrollPhysics>());

        const PinchZoomNotification(active: false).dispatch(grid);
        await tester.pump();

        expect(tabBarView().physics, isNull);
      });

      // Pinching the grid is the primary way to the column count, but it is a
      // gesture assistive technology cannot perform — and the count is a
      // persisted preference, not transient view state. Without the toolbar
      // route to it, a screen-reader user could never set it.
      testWidgets('changes the grid size from the menu without a pinch', (
        tester,
      ) async {
        final announcements = _captureAnnouncements(tester);
        await tester.pumpWidget(buildWidget(initialTabIndex: 1));
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsLabel(en.libraryDisplayOptionsLabel));
        await tester.pumpAndSettle();
        await tester.tap(find.text(en.libraryGridSizeLabel));
        await tester.pumpAndSettle();

        expect(find.text(en.libraryGridSizeColumns(2)), findsOneWidget);
        expect(find.text(en.libraryGridSizeColumns(5)), findsOneWidget);

        await tester.tap(find.text(en.libraryGridSizeColumns(2)));
        await tester.pumpAndSettle();

        expect(sharedPreferences.getInt(ClipGridColumns.prefsKey), equals(2));
        expect(announcements, contains(en.libraryGridSizeColumns(2)));
      });

      testWidgets('$ClipSelectionFooter in selection mode', (tester) async {
        await tester.pumpWidget(buildWidget(selectionMode: true));
        await tester.pump();

        expect(find.byType(ClipSelectionFooter), findsOneWidget);
      });

      testWidgets('no app bar in selection mode', (tester) async {
        await tester.pumpWidget(buildWidget(selectionMode: true));
        await tester.pump();

        // In selection mode, appBar is null
        expect(find.text(en.profileLibraryLabel), findsNothing);
      });

      testWidgets('no FloatingActionButton', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(find.byType(FloatingActionButton), findsNothing);
      });
    });

    group('tab navigation', () {
      testWidgets(
        'shows drafts and clips but no sounds in withoutSounds mode',
        (tester) async {
          await tester.pumpWidget(
            buildWidget(
              initialTabIndex: 1,
              tabsMode: LibraryTabsMode.withoutSounds,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text(en.libraryTabDrafts), findsOneWidget);
          expect(find.text(en.libraryTabClips), findsOneWidget);
          expect(find.text(en.soundsTitle), findsNothing);
          expect(find.byType(ClipsTab), findsOneWidget);
        },
      );

      testWidgets('opens the drafts tab in withoutSounds mode', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            initialTabIndex: 1,
            tabsMode: LibraryTabsMode.withoutSounds,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(en.libraryTabDrafts));
        await tester.pumpAndSettle();

        expect(find.byType(DraftsTab), findsOneWidget);
      });

      testWidgets('shows only clips and hides tab bar in selection mode', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(selectionMode: true));
        await tester.pumpAndSettle();

        expect(find.byType(TabBar), findsNothing);
        expect(find.byType(ClipsTab), findsOneWidget);
        expect(find.byType(DraftsTab), findsNothing);
        expect(find.text(en.soundsTitle), findsNothing);
      });

      testWidgets('can switch to $ClipsTab', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Switch to clips tab
        await tester.tap(find.text(en.libraryTabClips));
        await tester.pumpAndSettle();

        expect(find.byType(ClipsTab), findsOneWidget);
      });

      testWidgets('can switch back to $DraftsTab', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Switch to clips tab
        await tester.tap(find.text(en.libraryTabClips));
        await tester.pumpAndSettle();

        // Switch back to drafts tab
        await tester.tap(find.text(en.libraryTabDrafts));
        await tester.pumpAndSettle();

        expect(find.byType(DraftsTab), findsOneWidget);
      });
    });

    group('selection across tab changes', () {
      DivineVideoClip sessionClip() => DivineVideoClip(
        id: 'session-clip',
        video: EditorVideo.file('/test/session.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime(2026),
        targetAspectRatio: models.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
      );

      ClipsLibraryBloc clipsBlocOf(WidgetTester tester) =>
          BlocProvider.of<ClipsLibraryBloc>(
            tester.element(find.byType(ClipsTab)),
          );

      // The auto-opened selection mirrors the recorder session that opened the
      // library. Clearing it on a peek at Drafts would drop that session's
      // clips, so it has to survive the tab change.
      testWidgets('keeps an auto-opened selection when peeking at $DraftsTab', (
        tester,
      ) async {
        final clip = sessionClip();
        when(
          () => mockClipLibraryService.getAllClips(),
        ).thenAnswer((_) async => [clip]);
        when(
          () => mockClipLibraryService.recoverMissingAssets(any()),
        ).thenAnswer(
          (invocation) async =>
              invocation.positionalArguments.single as List<DivineVideoClip>,
        );

        await tester.pumpWidget(
          buildWidget(
            initialTabIndex: 1,
            tabsMode: LibraryTabsMode.withoutSounds,
            sessionClips: [clip],
          ),
        );
        await tester.pumpAndSettle();

        final clipsBloc = clipsBlocOf(tester);
        expect(clipsBloc.state.didAutoOpenSelectionMode, isTrue);

        await tester.tap(find.text(en.libraryTabDrafts));
        await tester.pumpAndSettle();

        final state = clipsBloc.state;
        expect(state.isLibrarySelectionMode, isTrue);
        expect(state.selectedClipIds, contains(clip.id));
      });

      testWidgets('clears a user-opened selection on a tab change', (
        tester,
      ) async {
        final clip = sessionClip();
        when(
          () => mockClipLibraryService.getAllClips(),
        ).thenAnswer((_) async => [clip]);
        when(
          () => mockClipLibraryService.recoverMissingAssets(any()),
        ).thenAnswer(
          (invocation) async =>
              invocation.positionalArguments.single as List<DivineVideoClip>,
        );

        await tester.pumpWidget(
          buildWidget(
            initialTabIndex: 1,
            tabsMode: LibraryTabsMode.withoutSounds,
          ),
        );
        await tester.pumpAndSettle();

        final clipsBloc = clipsBlocOf(tester)
          ..add(const ClipsLibraryEnterSelectionMode());
        await tester.pumpAndSettle();

        expect(clipsBloc.state.didAutoOpenSelectionMode, isFalse);

        clipsBloc.add(ClipsLibraryToggleSelection(clip));
        await tester.pumpAndSettle();
        expect(clipsBloc.state.selectedClipIds, contains(clip.id));

        await tester.tap(find.text(en.libraryTabDrafts));
        await tester.pumpAndSettle();

        expect(clipsBloc.state.isLibrarySelectionMode, isFalse);
        expect(clipsBloc.state.selectedClipIds, isEmpty);
      });
    });

    group('filter selection', () {
      DivineVideoClip savedClip() => DivineVideoClip(
        id: 'saved-clip',
        video: EditorVideo.file('/test/saved.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime(2026),
        targetAspectRatio: models.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
      );

      test(
        'uses the full clip set when a selected clip is hidden by a filter',
        () {
          final clip = savedClip();
          // The filtered list is empty by default, matching an empty active
          // filter while the original selection remains in the full clip set.
          final state = ClipsLibraryState(
            clips: [clip],
            selectedClipIds: {clip.id},
            filter: const ClipLibraryArchiveFilter(),
          );

          expect(
            libraryTargetAspectRatioForSelection(
              selectionMode: false,
              editorClips: const [],
              clipsState: state,
            ),
            clip.targetAspectRatio.value,
          );
        },
      );
    });

    // A selection deliberately survives a filter switch so a video can span
    // categories. The bulk toolbar actions must not inherit that reach —
    // moving or trashing clips the grid is not showing is not something the
    // user can see coming.
    group('bulk actions across filters', () {
      final travel = ClipCategory(
        id: 'cat-travel',
        name: 'Travel',
        createdAt: DateTime(2026),
      );

      DivineVideoClip organizedClip(String id, {String? categoryId}) =>
          DivineVideoClip(
            id: id,
            video: EditorVideo.file('/test/$id.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime(2026),
            targetAspectRatio: models.AspectRatio.vertical,
            originalAspectRatio: 9 / 16,
            thumbnailPath: '/test/$id.jpg',
            ghostFramePath: '/test/${id}_ghost.jpg',
            categoryId: categoryId,
          );

      final unfiled = organizedClip('unfiled');
      final filed = organizedClip('filed', categoryId: travel.id);

      /// Opens the library with `unfiled` selected under All and `filed`
      /// selected under Travel, then leaves Travel active — so half the
      /// selection is off screen.
      Future<ClipsLibraryBloc> selectAcrossFilters(WidgetTester tester) async {
        when(
          () => mockClipLibraryService.getAllClips(),
        ).thenAnswer((_) async => [unfiled, filed]);
        when(
          () => mockClipLibraryService.getCategories(),
        ).thenAnswer((_) async => [travel]);

        await tester.pumpWidget(
          buildWidget(
            initialTabIndex: 1,
            tabsMode: LibraryTabsMode.withoutSounds,
          ),
        );
        await tester.pumpAndSettle();

        final clipsBloc =
            BlocProvider.of<ClipsLibraryBloc>(
                tester.element(find.byType(ClipsTab)),
              )
              ..add(const ClipsLibraryEnterSelectionMode())
              ..add(ClipsLibraryToggleSelection(unfiled))
              ..add(ClipsLibraryToggleSelection(filed))
              ..add(
                ClipsLibraryFilterChanged(ClipLibraryCategoryFilter(travel.id)),
              );
        await tester.pumpAndSettle();

        expect(clipsBloc.state.selectedClipIds, {'unfiled', 'filed'});
        expect(clipsBloc.state.sortedClips.map((c) => c.id), ['filed']);
        return clipsBloc;
      }

      testWidgets('delete trashes only the visible half of the selection', (
        tester,
      ) async {
        when(
          () => mockClipLibraryService.softDelete(any()),
        ).thenAnswer((_) async => true);

        final clipsBloc = await selectAcrossFilters(tester);

        await tester.tap(
          find.bySemanticsLabel(en.libraryDeleteSelectedClipsTooltip),
        );
        await tester.pumpAndSettle();

        verify(() => mockClipLibraryService.softDelete('filed')).called(1);
        verifyNever(() => mockClipLibraryService.softDelete('unfiled'));
        expect(clipsBloc.state.selectedClipIds, {'unfiled'});
      });

      testWidgets('move files only the visible half of the selection', (
        tester,
      ) async {
        when(
          () => mockClipLibraryService.setClipCategory(
            clipId: any(named: 'clipId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async {});

        final clipsBloc = await selectAcrossFilters(tester);

        await tester.tap(
          find.bySemanticsLabel(en.libraryMoveSelectedClipsTooltip),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(en.libraryCategoryMoveNone));
        await tester.pumpAndSettle();

        verify(
          () => mockClipLibraryService.setClipCategory(
            clipId: 'filed',
            categoryId: null,
          ),
        ).called(1);
        verifyNever(
          () => mockClipLibraryService.setClipCategory(
            clipId: 'unfiled',
            categoryId: any(named: 'categoryId'),
          ),
        );
        expect(clipsBloc.state.selectedClipIds, {'unfiled'});
      });

      // What survives an action is off screen by definition, so the grid
      // shows no marked clip. Without the create-video bar accounting for
      // it, that is indistinguishable from having selected nothing.
      testWidgets('the surviving selection stays visible on the create bar', (
        tester,
      ) async {
        when(
          () => mockClipLibraryService.softDelete(any()),
        ).thenAnswer((_) async => true);

        await selectAcrossFilters(tester);
        expect(find.text(en.libraryCreateVideo(2)), findsOneWidget);

        await tester.tap(
          find.bySemanticsLabel(en.libraryDeleteSelectedClipsTooltip),
        );
        await tester.pumpAndSettle();

        expect(find.text(en.libraryCreateVideo(1)), findsOneWidget);
      });
    });

    group('empty state', () {
      testWidgets(
        'drafts tab does not show path_provider plugin errors after load',
        (tester) async {
          await tester.pumpWidget(buildWidget());
          await tester.pumpAndSettle();

          expect(find.textContaining('MissingPluginException'), findsNothing);
          expect(
            find.textContaining('getApplicationDocumentsDirectory'),
            findsNothing,
          );
        },
      );

      testWidgets('shows $EmptyLibraryState when no drafts', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Drafts tab is default; with no drafts should show empty state
        expect(find.byType(EmptyLibraryState), findsOneWidget);
        expect(find.text(en.libraryNoDraftsYetTitle), findsOneWidget);
      });

      testWidgets('shows $EmptyLibraryState when no clips', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Switch to clips tab
        await tester.tap(find.text(en.libraryTabClips));
        await tester.pumpAndSettle();

        // With no clips saved, should show empty state
        expect(find.byType(EmptyLibraryState), findsOneWidget);
        expect(find.text(en.libraryNoClipsYetTitle), findsOneWidget);
      });
    });

    group('_createVideoFromSelected', () {
      testWidgets(
        'selection mode does not return clips already in editorClips',
        (tester) async {
          final existingClip = DivineVideoClip(
            id: 'existing-clip',
            video: EditorVideo.file('/test/existing.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime.now(),
            targetAspectRatio: models.AspectRatio.vertical,
            originalAspectRatio: 9 / 16,
            thumbnailPath: '/test/existing.jpg',
            ghostFramePath: '/test/existing_ghost.jpg',
          );
          final newClip = DivineVideoClip(
            id: 'new-clip',
            video: EditorVideo.file('/test/new.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: models.AspectRatio.vertical,
            originalAspectRatio: 9 / 16,
            thumbnailPath: '/test/new.jpg',
            ghostFramePath: '/test/new_ghost.jpg',
          );

          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => [existingClip, newClip]);
          when(
            () => mockClipLibraryService.recoverMissingAssets(any()),
          ).thenAnswer((_) async => [existingClip, newClip]);

          final mockGoRouter = MockGoRouter();

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(sharedPreferences),
                gallerySaveServiceProvider.overrideWithValue(
                  mockGallerySaveService,
                ),
                clipLibraryServiceProvider.overrideWithValue(
                  mockClipLibraryService,
                ),
                draftStorageServiceProvider.overrideWithValue(
                  mockDraftStorageService,
                ),
                clipManagerProvider.overrideWith(ClipManagerNotifier.new),
              ],
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: VineTheme.theme,
                home: MockGoRouterProvider(
                  goRouter: mockGoRouter,
                  child: LibraryScreen(
                    selectionMode: true,
                    initialTabIndex: 1,
                    editorClips: [existingClip],
                    tabsMode: LibraryTabsMode.withoutSounds,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final cards = find.byType(VideoClipThumbnailCard);
          expect(cards, findsNWidgets(2));

          await tester.tap(cards.at(0));
          await tester.tap(cards.at(1));
          await tester.pumpAndSettle();

          await tester.tap(find.text(en.librarySelect).first);
          await tester.pumpAndSettle();

          final captured = verify(
            () => mockGoRouter.pop<List<DivineVideoClip>>(captureAny()),
          ).captured;
          expect(captured, hasLength(1));

          final clips = captured.first as List<DivineVideoClip>;
          expect(clips.map((c) => c.id), isNot(contains('existing-clip')));
          expect(clips.map((c) => c.id), contains('new-clip'));
        },
      );

      testWidgets(
        'selection mode pops with selected clips when Add is tapped',
        (tester) async {
          final testClip = DivineVideoClip(
            id: 'sel-clip-1',
            video: EditorVideo.file('/test/clip1.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: models.AspectRatio.vertical,
            originalAspectRatio: 9 / 16,
            thumbnailPath: '/test/thumb1.jpg',
            ghostFramePath: '/test/ghost1.jpg',
          );

          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => [testClip]);
          when(
            () => mockClipLibraryService.recoverMissingAssets(any()),
          ).thenAnswer((_) async => [testClip]);

          final mockGoRouter = MockGoRouter();

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(sharedPreferences),
                gallerySaveServiceProvider.overrideWithValue(
                  mockGallerySaveService,
                ),
                clipLibraryServiceProvider.overrideWithValue(
                  mockClipLibraryService,
                ),
                draftStorageServiceProvider.overrideWithValue(
                  mockDraftStorageService,
                ),
                clipManagerProvider.overrideWith(ClipManagerNotifier.new),
              ],
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: VineTheme.theme,
                home: MockGoRouterProvider(
                  goRouter: mockGoRouter,
                  child: const LibraryScreen(
                    selectionMode: true,
                    initialTabIndex: 1,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Clips tab should show the clip
          expect(find.byType(ClipSelectionFooter), findsOneWidget);

          // Locate a clip thumbnail card and tap to select it
          final clipCard = find.byType(VideoClipThumbnailCard);
          expect(clipCard, findsOneWidget);
          await tester.tap(clipCard);
          await tester.pumpAndSettle();

          // Tap "Select" button (visible in the footer)
          await tester.tap(find.text(en.librarySelect).first);
          await tester.pumpAndSettle();

          // Verify context.pop was called with the selected clip list
          final captured = verify(
            () => mockGoRouter.pop<List<DivineVideoClip>>(captureAny()),
          ).captured;
          expect(captured, hasLength(1));
          final clips = captured.first as List<DivineVideoClip>;
          expect(clips, hasLength(1));
          expect(clips.first.id, equals('sel-clip-1'));
        },
      );
    });
    group('delete undo snackbar', () {
      testWidgets('tapping Undo after the screen is gone does not add to the '
          'closed bloc', (tester) async {
        final clip = DivineVideoClip(
          id: 'undo-clip-1',
          video: EditorVideo.file('/test/undo.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: models.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
          thumbnailPath: '/test/undo.jpg',
          ghostFramePath: '/test/undo_ghost.jpg',
        );

        when(
          () => mockClipLibraryService.getAllClips(),
        ).thenAnswer((_) async => [clip]);
        when(
          () => mockClipLibraryService.recoverMissingAssets(any()),
        ).thenAnswer((_) async => [clip]);
        when(
          () => mockClipLibraryService.softDelete(any()),
        ).thenAnswer((_) async => true);

        final showLibrary = ValueNotifier<bool>(true);
        addTearDown(showLibrary.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(sharedPreferences),
              gallerySaveServiceProvider.overrideWithValue(
                mockGallerySaveService,
              ),
              clipLibraryServiceProvider.overrideWithValue(
                mockClipLibraryService,
              ),
              draftStorageServiceProvider.overrideWithValue(
                mockDraftStorageService,
              ),
              clipManagerProvider.overrideWith(ClipManagerNotifier.new),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: VineTheme.theme,
              home: Scaffold(
                body: ValueListenableBuilder<bool>(
                  valueListenable: showLibrary,
                  builder: (context, show, _) => show
                      ? const LibraryScreen(
                          initialTabIndex: 1,
                          tabsMode: LibraryTabsMode.withoutSounds,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Trigger the delete → the app-level "Undo" snackbar appears.
        final clipsBloc = BlocProvider.of<ClipsLibraryBloc>(
          tester.element(find.byType(ClipsTab)),
        )..add(ClipsLibraryDeleteClip(clip));
        await tester.pumpAndSettle();

        expect(find.text(en.libraryClipsDeletedUndoLabel), findsOneWidget);

        // Navigate away: unmount the screen, closing its bloc, while the
        // app-level snackbar stays on screen.
        showLibrary.value = false;
        await tester.pump();
        expect(clipsBloc.isClosed, isTrue);

        await tester.tap(find.text(en.libraryClipsDeletedUndoLabel));
        await tester.pump();

        expect(tester.takeException(), isNull);
      });

      testWidgets('renders without an external Scaffold because LibraryScreen '
          'presents its own', (tester) async {
        // Regression guard: in production LibraryScreen is a full-screen route
        // with no ancestor Scaffold, so its floating snackbars (delete undo,
        // clip download feedback) only render if LibraryScreen provides a
        // Scaffold itself. `buildWidget` pumps LibraryScreen as `home:` with no
        // Scaffold wrapper, mirroring that structure. Before the fix this found
        // nothing.
        final clip = DivineVideoClip(
          id: 'undo-clip-2',
          video: EditorVideo.file('/test/undo2.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: models.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
          thumbnailPath: '/test/undo2.jpg',
          ghostFramePath: '/test/undo2_ghost.jpg',
        );
        when(
          () => mockClipLibraryService.getAllClips(),
        ).thenAnswer((_) async => [clip]);
        when(
          () => mockClipLibraryService.recoverMissingAssets(any()),
        ).thenAnswer((_) async => [clip]);
        when(
          () => mockClipLibraryService.softDelete(any()),
        ).thenAnswer((_) async => true);

        await tester.pumpWidget(
          buildWidget(
            initialTabIndex: 1,
            tabsMode: LibraryTabsMode.withoutSounds,
          ),
        );
        await tester.pumpAndSettle();

        BlocProvider.of<ClipsLibraryBloc>(
          tester.element(find.byType(ClipsTab)),
        ).add(ClipsLibraryDeleteClip(clip));
        await tester.pumpAndSettle();

        expect(find.text(en.libraryClipsDeletedUndoLabel), findsOneWidget);
      });

      testWidgets('does not scrim the screen while the delete is in flight', (
        tester,
      ) async {
        // Regression guard: the blocking progress scrim used to cover the
        // whole screen for the handful of frames a soft delete takes, which
        // read as the library flashing black on every trashed clip.
        final clip = DivineVideoClip(
          id: 'scrim-clip-1',
          video: EditorVideo.file('/test/scrim.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: models.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
          thumbnailPath: '/test/scrim.jpg',
          ghostFramePath: '/test/scrim_ghost.jpg',
        );
        when(
          () => mockClipLibraryService.getAllClips(),
        ).thenAnswer((_) async => [clip]);
        when(
          () => mockClipLibraryService.recoverMissingAssets(any()),
        ).thenAnswer((_) async => [clip]);
        // Held open so the assertions run while the bloc is still deleting.
        final softDelete = Completer<bool>();
        when(
          () => mockClipLibraryService.softDelete(any()),
        ).thenAnswer((_) => softDelete.future);

        await tester.pumpWidget(
          buildWidget(
            initialTabIndex: 1,
            tabsMode: LibraryTabsMode.withoutSounds,
          ),
        );
        await tester.pumpAndSettle();

        final bloc = BlocProvider.of<ClipsLibraryBloc>(
          tester.element(find.byType(ClipsTab)),
        )..add(ClipsLibraryDeleteClip(clip));
        // One pump lets the bloc emit `deleting`, the second paints it.
        await tester.pump();
        await tester.pump();

        expect(bloc.state.isDeleting, isTrue);
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Material && widget.color == VineTheme.scrim65,
          ),
          findsNothing,
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);

        softDelete.complete(true);
        await tester.pumpAndSettle();
      });
    });

    group('gallery save failure', () {
      // The failure arm of the gallery-save switch used to render
      // `e.toString()` straight into the snackbar, while its two sibling arms
      // both localized. Nothing covered it. This drives a real
      // GallerySaveService throw through the bloc and pins the localized copy
      // — and pins that the raw exception text does NOT reach the screen.
      testWidgets('shows localized copy and never the raw exception text', (
        tester,
      ) async {
        final clip = DivineVideoClip(
          id: 'clip-save-fail',
          video: EditorVideo.file('/test/save-fail.mp4'),
          duration: const Duration(seconds: 4),
          recordedAt: DateTime(2026),
          targetAspectRatio: models.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
          thumbnailPath: '/test/save-fail.jpg',
          ghostFramePath: '/test/save-fail_ghost.jpg',
        );

        when(
          () => mockClipLibraryService.getAllClips(),
        ).thenAnswer((_) async => [clip]);
        when(
          () => mockClipLibraryService.recoverMissingAssets(any()),
        ).thenAnswer((_) async => [clip]);
        when(
          () => mockGallerySaveService.saveVideoToGallery(any()),
        ).thenThrow(Exception('boom-secret-path-/Users/someone/clip.mp4'));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(sharedPreferences),
              gallerySaveServiceProvider.overrideWithValue(
                mockGallerySaveService,
              ),
              clipLibraryServiceProvider.overrideWithValue(
                mockClipLibraryService,
              ),
              draftStorageServiceProvider.overrideWithValue(
                mockDraftStorageService,
              ),
              clipManagerProvider.overrideWith(ClipManagerNotifier.new),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: VineTheme.theme,
              home: const LibraryScreen(
                initialTabIndex: 1,
                tabsMode: LibraryTabsMode.withoutSounds,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final bloc =
            tester.element(find.byType(ClipsTab)).read<ClipsLibraryBloc>()
              ..add(ClipsLibraryToggleSelection(clip));
        await tester.pumpAndSettle();
        bloc.add(const ClipsLibrarySaveToGallery());
        await tester.pumpAndSettle();

        expect(
          find.text(
            en.libraryClipsSaveFailed(GallerySaveService.destinationName),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('boom-secret-path'), findsNothing);
      });
    });

    group('web', () {
      testWidgets('shows mobile-app intercept instead of tabs', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.text(en.libraryWebUnavailableHeadline), findsOneWidget);
        expect(find.text(en.libraryWebUnavailableDescription), findsOneWidget);
        expect(find.text(en.libraryTabDrafts), findsNothing);
        expect(find.text(en.libraryTabClips), findsNothing);
      }, skip: !kIsWeb);
    });
  });
}
