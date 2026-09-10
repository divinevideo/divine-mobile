// ABOUTME: Tests for ClipsTab widget
// ABOUTME: Verifies clips grid, selection, loading, and empty states

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_category.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/library/clip_category_chips.dart';
import 'package:openvine/widgets/library/clips_tab.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';
import 'package:openvine/widgets/library/pinch_zoom_grid.dart';
import 'package:openvine/widgets/library/trashed_clips_list.dart';
import 'package:openvine/widgets/video_clip/video_clip_preview.dart';
import 'package:openvine/widgets/video_clip/video_clip_thumbnail_card.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../helpers/divine_video_player_channel.dart';
import '../../helpers/go_router.dart';

class _MockClipsLibraryBloc
    extends MockBloc<ClipsLibraryEvent, ClipsLibraryState>
    implements ClipsLibraryBloc {}

void main() {
  final en = AppLocalizationsEn();

  group(ClipsTab, () {
    late _MockClipsLibraryBloc mockBloc;

    final clip1 = DivineVideoClip(
      id: 'clip1',
      video: EditorVideo.file('/path/to/clip1.mp4'),
      duration: const Duration(seconds: 5),
      recordedAt: DateTime(2026),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
    );

    final clip2 = DivineVideoClip(
      id: 'clip2',
      video: EditorVideo.file('/path/to/clip2.mp4'),
      duration: const Duration(seconds: 3),
      recordedAt: DateTime(2026),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
    );

    setUp(() {
      mockBloc = _MockClipsLibraryBloc();
    });

    Widget buildWidget({
      bool isSelectionMode = false,
      bool selectionEnabled = true,
      double? targetAspectRatio,
      bool showCategoryManagement = false,
      ScrollController? scrollController,
    }) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: BlocProvider<ClipsLibraryBloc>.value(
            value: mockBloc,
            child: ClipsTab(
              showRecordButton: isSelectionMode,
              backgroundColor: VineTheme.surfaceBackground,
              selectionEnabled: selectionEnabled,
              targetAspectRatio: targetAspectRatio,
              showCategoryManagement: showCategoryManagement,
              scrollController: scrollController,
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('loading indicator when loading', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ClipsLibraryState(status: ClipsLibraryStatus.loading),
        );

        await tester.pumpWidget(buildWidget());

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });

      testWidgets('friendly error and retry when error state', (tester) async {
        when(
          () => mockBloc.state,
        ).thenReturn(const ClipsLibraryState(status: ClipsLibraryStatus.error));

        await tester.pumpWidget(buildWidget());

        expect(find.text(en.libraryCouldNotLoadClips), findsOneWidget);
        expect(find.text(en.searchTryAgain), findsOneWidget);
      });

      testWidgets('$EmptyLibraryState when no clips', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const ClipsLibraryState(status: ClipsLibraryStatus.loaded),
        );

        await tester.pumpWidget(buildWidget());

        expect(find.byType(EmptyLibraryState), findsOneWidget);
        expect(find.text(en.libraryNoClipsYetTitle), findsOneWidget);
      });

      testWidgets('an archive-specific empty state under the Archive filter', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            filter: ClipLibraryArchiveFilter(),
          ),
        );

        await tester.pumpWidget(buildWidget(showCategoryManagement: true));

        expect(find.text(en.libraryArchiveEmptyTitle), findsOneWidget);
        expect(find.text(en.libraryNoClipsYetTitle), findsNothing);
      });

      testWidgets('a category-specific empty state under a category filter', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            filter: ClipLibraryCategoryFilter('cat-travel'),
          ),
        );

        await tester.pumpWidget(buildWidget(showCategoryManagement: true));

        expect(find.text(en.libraryCategoryEmptyTitle), findsOneWidget);
        expect(find.text(en.libraryNoClipsYetTitle), findsNothing);
      });

      testWidgets('marks an archived clip that stayed filed in its category', (
        tester,
      ) async {
        final archived = clip1.copyWith(
          categoryId: 'cat-travel',
          archivedAt: DateTime(2026, 3, 6),
        );
        when(() => mockBloc.state).thenReturn(
          ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            filter: const ClipLibraryCategoryFilter('cat-travel'),
            clips: [archived, clip2],
            sortedClips: [archived, clip2],
          ),
        );

        await tester.pumpWidget(buildWidget(showCategoryManagement: true));

        final cards = tester
            .widgetList<VideoClipThumbnailCard>(
              find.byType(VideoClipThumbnailCard),
            )
            .toList();
        expect(
          cards.singleWhere((c) => c.clip.id == 'clip1').showArchivedBadge,
          isTrue,
        );
        // The active clip beside it stays unmarked.
        expect(
          cards.singleWhere((c) => c.clip.id == 'clip2').showArchivedBadge,
          isFalse,
        );
      });

      testWidgets('leaves the archive view unmarked, where all clips are', (
        tester,
      ) async {
        final archived = clip1.copyWith(archivedAt: DateTime(2026, 3, 6));
        when(() => mockBloc.state).thenReturn(
          ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            filter: const ClipLibraryArchiveFilter(),
            clips: [archived],
            sortedClips: [archived],
          ),
        );

        await tester.pumpWidget(buildWidget(showCategoryManagement: true));

        expect(
          tester
              .widget<VideoClipThumbnailCard>(
                find.byType(VideoClipThumbnailCard),
              )
              .showArchivedBadge,
          isFalse,
        );
      });

      testWidgets('the trash list instead of the grid under Deleted', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          ClipsLibraryState(
            status: ClipsLibraryStatus.trashLoaded,
            filter: const ClipLibraryTrashFilter(),
            clips: [clip1],
            sortedClips: [clip1],
            // A trashed clip always carries deletedAt (the trash query
            // sources it from the row), which the tile's countdown asserts.
            trashedClips: [
              clip2.copyWith(deletedAt: DateTime(2026, 3, 5)),
            ],
          ),
        );

        await tester.pumpWidget(buildWidget(showCategoryManagement: true));

        expect(find.byType(TrashedClipsList), findsOneWidget);
        expect(find.byType(MasonryGridView), findsNothing);
      });

      testWidgets('the chip row, with built-in filters only when managing', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const ClipsLibraryState(status: ClipsLibraryStatus.loaded),
        );

        await tester.pumpWidget(buildWidget(showCategoryManagement: true));
        expect(find.text(en.libraryFilterDeleted), findsOneWidget);

        await tester.pumpWidget(buildWidget());
        expect(find.byType(ClipCategoryChips), findsNothing);
      });

      testWidgets('a short chip row stays start-aligned, not centred', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            categories: [
              ClipCategory(
                id: 'cat-travel',
                name: 'Travel',
                createdAt: DateTime(2026, 3, 5),
              ),
            ],
          ),
        );

        await tester.pumpWidget(buildWidget());

        // Two chips are far narrower than the viewport; the row's own 16px
        // padding plus the chip's inner padding is all that may precede it.
        final rowWidth = tester.getSize(find.byType(ClipCategoryChips)).width;
        final firstChipX = tester
            .getTopLeft(
              find.text(en.libraryFilterAll),
            )
            .dx;
        expect(rowWidth, greaterThan(200));
        expect(firstChipX, lessThan(40));
      });

      testWidgets('the picker chip row once the user has categories', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            categories: [
              ClipCategory(
                id: 'cat-travel',
                name: 'Travel',
                createdAt: DateTime(2026, 3, 5),
              ),
            ],
          ),
        );

        await tester.pumpWidget(buildWidget());

        expect(find.text(en.libraryFilterAll), findsOneWidget);
        expect(find.text('Travel'), findsOneWidget);
        expect(find.text(en.libraryFilterDeleted), findsNothing);
      });

      testWidgets(
        '$EmptyLibraryState without record button in selection mode',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const ClipsLibraryState(status: ClipsLibraryStatus.loaded),
          );

          await tester.pumpWidget(buildWidget(isSelectionMode: true));

          expect(find.byType(EmptyLibraryState), findsOneWidget);
          expect(find.byType(ElevatedButton), findsNothing);
        },
      );

      testWidgets('clip thumbnails when clips are loaded', (tester) async {
        when(() => mockBloc.state).thenReturn(
          ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            clips: [clip1, clip2],
            sortedClips: [clip1, clip2],
          ),
        );

        await tester.pumpWidget(buildWidget());

        expect(find.byType(VideoClipThumbnailCard), findsNWidgets(2));
      });

      testWidgets('the grid at the persisted column count', (tester) async {
        when(() => mockBloc.state).thenReturn(
          ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            clips: [clip1, clip2],
            sortedClips: [clip1, clip2],
            gridColumnCount: 2,
          ),
        );

        await tester.pumpWidget(buildWidget());

        // Two columns over the 800px test surface, less the 4px gutter.
        expect(
          tester.getSize(find.byType(VideoClipThumbnailCard).first).width,
          closeTo(398, 0.5),
        );
      });

      testWidgets('keeps the persisted column count across a filter switch', (
        tester,
      ) async {
        final category = ClipCategory(
          id: 'cat1',
          name: 'Trips',
          createdAt: DateTime(2026),
        );
        final allState = ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1, clip2],
          sortedClips: [clip1, clip2],
          categories: [category],
          gridColumnCount: 2,
        );
        whenListen(
          mockBloc,
          Stream.value(
            allState.copyWith(filter: const ClipLibraryCategoryFilter('cat1')),
          ),
          initialState: allState,
        );

        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // The zoom level lives in bloc state, so it has to survive the
        // remount that a filter switch performs.
        expect(
          tester.getSize(find.byType(VideoClipThumbnailCard).first).width,
          closeTo(398, 0.5),
        );
      });

      testWidgets(
        'attaches a supplied scroll controller to one grid while the filter '
        'switches',
        (tester) async {
          // The cross-fade briefly mounts the outgoing and incoming grids
          // together. A supplied controller would land on both, and
          // PinchZoomGrid reads `controller.position` when a pinch starts —
          // which asserts on anything but exactly one attached position.
          final controller = ScrollController();
          addTearDown(controller.dispose);

          final category = ClipCategory(
            id: 'cat1',
            name: 'Trips',
            createdAt: DateTime(2026),
          );
          final allState = ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            clips: [clip1, clip2],
            sortedClips: [clip1, clip2],
            categories: [category],
          );
          whenListen(
            mockBloc,
            Stream.value(
              allState.copyWith(
                filter: const ClipLibraryCategoryFilter('cat1'),
              ),
            ),
            initialState: allState,
          );

          await tester.pumpWidget(buildWidget(scrollController: controller));
          await tester.pump();
          // Mid-cross-fade, had one been started.
          await tester.pump(const Duration(milliseconds: 90));

          expect(controller.positions, hasLength(1));
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'cross-fades the filter switch when no scroll controller is supplied',
        (tester) async {
          // The standalone library owns no controller, so each grid brings its
          // own and the fade is safe — this pins that the chip row keeps it.
          final category = ClipCategory(
            id: 'cat1',
            name: 'Trips',
            createdAt: DateTime(2026),
          );
          final allState = ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            clips: [clip1, clip2],
            sortedClips: [clip1, clip2],
            categories: [category],
          );
          whenListen(
            mockBloc,
            Stream.value(
              allState.copyWith(
                filter: const ClipLibraryCategoryFilter('cat1'),
              ),
            ),
            initialState: allState,
          );

          await tester.pumpWidget(buildWidget());
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 90));

          expect(find.byType(PinchZoomGrid), findsNWidgets(2));

          await tester.pumpAndSettle();
          expect(find.byType(PinchZoomGrid), findsOneWidget);
        },
      );

      testWidgets(
        'omits the selection position when the badge is not shown',
        (tester) async {
          // Reachable on the ordinary library route: entering the library with
          // clips already in the editor pre-selects them
          // (ClipsLibraryLoadRequested.preSelectedIds) while selection mode is
          // still off, so selectionEnabled is false and no badge is rendered.
          when(() => mockBloc.state).thenReturn(
            ClipsLibraryState(
              status: ClipsLibraryStatus.loaded,
              clips: [clip1, clip2],
              sortedClips: [clip1, clip2],
              selectedClipIds: const {'clip1'},
            ),
          );

          await tester.pumpWidget(buildWidget(selectionEnabled: false));

          final semantics = tester.getSemantics(
            find.byType(VideoClipThumbnailCard).first,
          );
          // No badge on screen, so the ordinal would name a position the user
          // cannot see.
          expect(find.text('1'), findsNothing);
          expect(semantics.value, equals(en.videoClipSemanticValueSelected));
        },
      );
    });

    group('filter transition', () {
      final allState = ClipsLibraryState(
        status: ClipsLibraryStatus.loaded,
        clips: [clip1],
        sortedClips: [clip1],
      );
      final archiveState = ClipsLibraryState(
        status: ClipsLibraryStatus.loaded,
        filter: const ClipLibraryArchiveFilter(),
        clips: [clip1],
      );

      testWidgets('cross-fades the old content out while the new fades in', (
        tester,
      ) async {
        whenListen(
          mockBloc,
          Stream.value(archiveState),
          initialState: allState,
        );

        await tester.pumpWidget(buildWidget(showCategoryManagement: true));
        expect(find.byType(VideoClipThumbnailCard), findsOneWidget);

        // Let the archive state arrive, then stop mid-fade: the grid is on
        // its way out while the archive empty state is on its way in.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));

        expect(find.byType(VideoClipThumbnailCard), findsOneWidget);
        expect(find.text(en.libraryArchiveEmptyTitle), findsOneWidget);

        await tester.pumpAndSettle();
        expect(find.byType(VideoClipThumbnailCard), findsNothing);
        expect(find.text(en.libraryArchiveEmptyTitle), findsOneWidget);
      });

      testWidgets('swaps instantly when the platform asks for reduced motion', (
        tester,
      ) async {
        whenListen(
          mockBloc,
          Stream.value(archiveState),
          initialState: allState,
        );

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: buildWidget(showCategoryManagement: true),
          ),
        );
        expect(find.byType(VideoClipThumbnailCard), findsOneWidget);

        await tester.pump();
        await tester.pump();

        expect(find.byType(VideoClipThumbnailCard), findsNothing);
        expect(find.text(en.libraryArchiveEmptyTitle), findsOneWidget);
      });

      testWidgets('does not restart the fade when only the selection changes', (
        tester,
      ) async {
        final withSelection = ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1, clip2],
          sortedClips: [clip1, clip2],
          selectedClipIds: const {'clip1'},
        );
        whenListen(
          mockBloc,
          Stream.value(withSelection),
          initialState: ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            clips: [clip1, clip2],
            sortedClips: [clip1, clip2],
          ),
        );

        await tester.pumpWidget(buildWidget(showCategoryManagement: true));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));

        // Same filter, so the grid updates in place: two cards, not four
        // stacked across an outgoing and an incoming copy.
        expect(find.byType(VideoClipThumbnailCard), findsNWidgets(2));
      });
    });

    group('interactions', () {
      testWidgets('toggles selection when clip is tapped', (tester) async {
        when(() => mockBloc.state).thenReturn(
          ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            clips: [clip1],
            sortedClips: [clip1],
          ),
        );

        await tester.pumpWidget(buildWidget());

        await tester.tap(find.byType(VideoClipThumbnailCard).first);

        verify(
          () => mockBloc.add(ClipsLibraryToggleSelection(clip1)),
        ).called(1);
      });

      testWidgets('pinching the grid open changes the column count', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            clips: [clip1, clip2],
            sortedClips: [clip1, clip2],
          ),
        );

        await tester.pumpWidget(buildWidget());

        // Spreading 80px to 120px is a 1.5x zoom: 3 columns / 1.5 = 2.
        final centre = tester.getCenter(find.byType(ClipsTab));
        final first = await tester.startGesture(centre - const Offset(80, 0));
        final second = await tester.startGesture(centre + const Offset(80, 0));
        await tester.pump();
        await first.moveTo(centre - const Offset(120, 0));
        await second.moveTo(centre + const Offset(120, 0));
        await tester.pump();
        await first.up();
        await second.up();
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(const ClipsLibraryGridColumnsChanged(2)),
        ).called(1);
      });

      testWidgets('the grid still pinches after a filter switch', (
        tester,
      ) async {
        // The switch remounts the grid, so the zoom has to come back with it
        // rather than being left behind with the filter it was set up under.
        final category = ClipCategory(
          id: 'cat1',
          name: 'Trips',
          createdAt: DateTime(2026),
        );
        final allState = ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1, clip2],
          sortedClips: [clip1, clip2],
          categories: [category],
        );
        whenListen(
          mockBloc,
          Stream.value(
            allState.copyWith(filter: const ClipLibraryCategoryFilter('cat1')),
          ),
          initialState: allState,
        );

        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final centre = tester.getCenter(find.byType(ClipsTab));
        final first = await tester.startGesture(centre - const Offset(80, 0));
        final second = await tester.startGesture(centre + const Offset(80, 0));
        await tester.pump();
        await first.moveTo(centre - const Offset(120, 0));
        await second.moveTo(centre + const Offset(120, 0));
        await tester.pump();
        await first.up();
        await second.up();
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(const ClipsLibraryGridColumnsChanged(2)),
        ).called(1);
      });

      testWidgets('long-pressing a clip opens a drag selection', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            clips: [clip1, clip2],
            sortedClips: [clip1, clip2],
          ),
        );

        await tester.pumpWidget(buildWidget());

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(VideoClipThumbnailCard).first),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 10));

        verify(
          () => mockBloc.add(ClipsLibraryDragSelectionStarted(clip1)),
        ).called(1);

        await gesture.up();
        await tester.pump();

        verify(
          () => mockBloc.add(const ClipsLibraryDragSelectionEnded()),
        ).called(1);
      });

      testWidgets('dragging on from the long press reaches the next clip', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            clips: [clip1, clip2],
            sortedClips: [clip1, clip2],
          ),
        );

        await tester.pumpWidget(buildWidget());

        final cards = find.byType(VideoClipThumbnailCard);
        final gesture = await tester.startGesture(
          tester.getCenter(cards.first),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 10));
        await gesture.moveTo(tester.getCenter(cards.at(1)));
        await tester.pump();

        // The whole range is the bloc's to work out; the grid only reports
        // which clip the finger has reached.
        verify(
          () => mockBloc.add(ClipsLibraryDragSelectionExtended(clip2)),
        ).called(1);

        await gesture.up();
        await tester.pump();
      });

      testWidgets('holding the finger at the bottom scrolls on into the grid', (
        tester,
      ) async {
        // Four rows of three, so most of the grid starts off screen and the
        // range can only reach it by way of the edge auto-scroll.
        final clips = [
          for (var i = 0; i < 12; i++)
            DivineVideoClip(
              id: 'clip$i',
              video: EditorVideo.file('/path/to/clip$i.mp4'),
              duration: const Duration(seconds: 1),
              recordedAt: DateTime(2026),
              targetAspectRatio: .vertical,
              originalAspectRatio: 9 / 16,
            ),
        ];
        when(() => mockBloc.state).thenReturn(
          ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            clips: clips,
            sortedClips: clips,
          ),
        );

        await tester.pumpWidget(buildWidget());

        final grid = tester.getRect(find.byType(MasonryGridView));
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(VideoClipThumbnailCard).at(1)),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 10));
        await gesture.moveTo(Offset(grid.center.dx, grid.bottom - 8));
        await tester.pump();

        // Long enough for the auto-scroll to run out of grid, which parks the
        // finger over the last clip in the middle column.
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        verify(
          () => mockBloc.add(ClipsLibraryDragSelectionExtended(clips[10])),
        ).called(1);

        await gesture.up();
        await tester.pump();
      });

      testWidgets('a clip that cannot join the selection starts no drag', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            clips: [clip1],
            sortedClips: [clip1],
          ),
        );

        // The editor's timeline is square, so the vertical clip is disabled.
        await tester.pumpWidget(buildWidget(targetAspectRatio: 1));

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(VideoClipThumbnailCard).first),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 10));
        await gesture.up();
        await tester.pump();

        verifyNever(
          () => mockBloc.add(
            ClipsLibraryDragSelectionStarted(clip1, targetAspectRatio: 1),
          ),
        );
      });

      testWidgets('long-pressing while browsing starts a selection too', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          ClipsLibraryState(
            status: ClipsLibraryStatus.loaded,
            clips: [clip1, clip2],
            sortedClips: [clip1, clip2],
          ),
        );

        await tester.pumpWidget(buildWidget(selectionEnabled: false));

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(VideoClipThumbnailCard).first),
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 10));
        await gesture.up();
        await tester.pump();

        // Browsing has no selection on screen to toggle against, which the
        // bloc needs to know — it is the press that opens selection mode.
        verify(
          () => mockBloc.add(
            ClipsLibraryDragSelectionStarted(clip1, selectionEnabled: false),
          ),
        ).called(1);
      });

      testWidgets(
        'tap → trash closes preview and soft-deletes the clip',
        (tester) async {
          DivineVideoPlayerController.resetIdCounterForTesting();
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(
            const MethodChannel('divine_video_player'),
            (call) async {
              if (call.method == 'create') {
                return <String, Object?>{'textureId': 1};
              }
              return null;
            },
          );
          installMockDivineVideoPlayer();
          addTearDown(() {
            messenger.setMockMethodCallHandler(
              const MethodChannel('divine_video_player'),
              null,
            );
          });

          final mockGoRouter = MockGoRouter();
          when(() => mockGoRouter.pop<Object?>(any())).thenReturn(null);
          when(mockGoRouter.canPop).thenReturn(true);

          when(() => mockBloc.state).thenReturn(
            ClipsLibraryState(
              status: ClipsLibraryStatus.loaded,
              clips: [clip1],
              sortedClips: [clip1],
            ),
          );

          await tester.pumpWidget(
            ProviderScope(
              child: MockGoRouterProvider(
                goRouter: mockGoRouter,
                child: buildWidget(selectionEnabled: false),
              ),
            ),
          );

          // Browsing, so a tap opens the VideoClipPreview overlay; the long
          // press belongs to the drag selection. pumpAndSettle never settles
          // here because the preview shows a CircularProgressIndicator while
          // the player initializes.
          await tester.tap(find.byType(VideoClipThumbnailCard).first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(VideoClipPreview), findsOneWidget);

          await tester.tap(
            find.byWidgetPredicate(
              (w) => w is DivineIcon && w.icon == DivineIconName.trash,
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text(en.libraryDeleteClipTitle), findsOneWidget);

          final confirmButton = find.text(en.libraryDeleteConfirm).last;
          await tester.ensureVisible(confirmButton);
          await tester.tap(confirmButton, warnIfMissed: false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(VideoClipPreview), findsNothing);
          verify(() => mockBloc.add(ClipsLibraryDeleteClip(clip1))).called(1);
        },
      );
    });
  });

  group(ClipSelectionFooter, () {
    late _MockClipsLibraryBloc mockBloc;

    setUp(() {
      mockBloc = _MockClipsLibraryBloc();
    });

    Widget buildWidget({VoidCallback? onCreate}) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: BlocProvider<ClipsLibraryBloc>.value(
            value: mockBloc,
            child: ClipSelectionFooter(onCreate: onCreate ?? () {}),
          ),
        ),
      );
    }

    testWidgets('calls onCreate when the select button is tapped', (
      tester,
    ) async {
      when(() => mockBloc.state).thenReturn(
        const ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          selectedClipIds: {'clip1'},
        ),
      );

      var created = false;
      await tester.pumpWidget(buildWidget(onCreate: () => created = true));

      await tester.tap(find.text(en.librarySelect));

      expect(created, isTrue);
    });

    testWidgets('disables the select button without a selection', (
      tester,
    ) async {
      when(() => mockBloc.state).thenReturn(
        const ClipsLibraryState(status: ClipsLibraryStatus.loaded),
      );

      var created = false;
      await tester.pumpWidget(buildWidget(onCreate: () => created = true));

      await tester.tap(find.text(en.librarySelect));

      expect(created, isFalse);
    });
  });
}
