// ABOUTME: Widget tests for FeedModeSwitch
// ABOUTME: Tests feed source labels, tap interactions, and bottom sheet selection

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/screens/feed/feed_immersive_cubit.dart';
import 'package:openvine/screens/feed/feed_mode_switch.dart';
import 'package:openvine/screens/feed/feed_settings_menu.dart';
import 'package:openvine/widgets/video_feed_item/feed_immersive_chrome.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockVideoFeedBloc extends MockBloc<VideoFeedEvent, VideoFeedBlocState>
    implements VideoFeedBloc {}

class _MockVideoVolumeCubit extends MockCubit<VideoVolumeState>
    implements VideoVolumeCubit {}

void main() {
  group(FeedModeSwitch, () {
    late _MockVideoFeedBloc mockBloc;
    late _MockVideoVolumeCubit mockVolumeCubit;
    late AppLocalizations l10n;

    setUp(() {
      mockBloc = _MockVideoFeedBloc();
      mockVolumeCubit = _MockVideoVolumeCubit();
      when(() => mockVolumeCubit.state).thenReturn(const VideoVolumeState());
    });

    setUpAll(() {
      registerFallbackValue(
        const VideoFeedSourceChanged(VideoFeedSource.forYou()),
      );
      l10n = lookupAppLocalizations(const Locale('en'));
    });

    tearDown(() {
      mockBloc.close();
      mockVolumeCubit.close();
    });

    Widget createTestWidget({
      // The harness accepts both Riverpod override generations used here.
      // ignore: strict_raw_type
      List overrides = const [],
      bool isPreviewMode = false,
    }) {
      return ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(
              children: [
                MultiBlocProvider(
                  providers: [
                    BlocProvider<VideoFeedBloc>.value(value: mockBloc),
                    BlocProvider<VideoVolumeCubit>.value(
                      value: mockVolumeCubit,
                    ),
                  ],
                  child: FeedModeSwitch(isPreviewMode: isPreviewMode),
                ),
              ],
            ),
          ),
        ),
      );
    }

    CuratedList curatedList({required String id, required String name}) {
      final now = DateTime(2026);
      return CuratedList(
        id: id,
        name: name,
        videoEventIds: const [],
        createdAt: now,
        updatedAt: now,
      );
    }

    VideoEvent video({required String id}) {
      return VideoEvent(
        id: id,
        pubkey: 'd4e5f6789012345678901234567890abcdef123456789012345678901234a1b2c3',
        createdAt: 1700000000,
        content: 'Test video',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
        videoUrl: 'https://example.com/video.mp4',
      );
    }

    group('Tap Target', () {
      Future<void> pumpDefault(WidgetTester tester) async {
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoFeedBlocState(status: VideoFeedStatus.success));
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
      }

      Finder labelTarget() => find
          .ancestor(
            of: find.text(l10n.feedModeForYou),
            matching: find.byType(GestureDetector),
          )
          .first;

      testWidgets('meets the Android tap target guideline', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpDefault(tester);

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('does not grow the live header beyond its settings target', (
        tester,
      ) async {
        await pumpDefault(tester);

        final headerRow = find
            .ancestor(
              of: find.byType(FeedSettingsMenu),
              matching: find.byType(Row),
            )
            .first;
        expect(tester.getSize(headerRow).height, kMinInteractiveDimension);
      });

      testWidgets('does not reserve a tap target in preview mode', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget(isPreviewMode: true));

        expect(
          tester.getSize(labelTarget()).height,
          lessThan(kMinInteractiveDimension),
        );
      });
    });

    group('Feed Source Labels', () {
      testWidgets('displays "For You" label for the default home source', (
        tester,
      ) async {
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoFeedBlocState(status: VideoFeedStatus.success));
        await tester.pumpWidget(createTestWidget());

        expect(find.text(l10n.feedModeForYou), findsOneWidget);
      });

      testWidgets('displays "Classics" label for the classic source', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            source: VideoFeedSource.classic(),
          ),
        );
        await tester.pumpWidget(createTestWidget());

        expect(find.text(l10n.feedModeClassics), findsOneWidget);
      });

      testWidgets('displays selected subscribed-list name for list source', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          VideoFeedBlocState(
            status: VideoFeedStatus.success,
            source: const VideoFeedSource.subscribedList(
              listId: 'best',
              listName: 'Best Vines',
            ),
            subscribedLists: [curatedList(id: 'best', name: 'Best Vines')],
          ),
        );
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Best Vines'), findsOneWidget);
      });
    });

    group('Feed Settings', () {
      testWidgets('does not show owner actions in the feed settings popover', (
        tester,
      ) async {
        final firstVideo = video(
          id: 'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234',
        );
        final activeVideo = video(
          id: 'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a1',
        );
        when(() => mockBloc.state).thenReturn(
          VideoFeedBlocState(
            status: VideoFeedStatus.success,
            videos: [firstVideo, activeVideo],
            currentIndex: 1,
          ),
        );
        final mockAuth = createMockAuthService();
        when(() => mockAuth.currentPublicKeyHex).thenReturn(activeVideo.pubkey);

        await tester.pumpWidget(
          createTestWidget(
            overrides: getStandardTestOverrides(mockAuthService: mockAuth),
          ),
        );

        await tester.tap(find.bySemanticsLabel(l10n.videoSettingsMenuOpen));
        await tester.pump();

        expect(find.text(l10n.shareMenuEditVideo), findsNothing);
        expect(find.text(l10n.shareMenuDeleteVideo), findsNothing);
      });
    });

    group('Tap Interaction', () {
      testWidgets('opens VineBottomSheet on tap', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            source: VideoFeedSource.forYou(),
          ),
        );
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.text(l10n.feedModeForYou));
        await tester.pumpAndSettle();

        expect(find.byType(VineBottomSheet), findsOneWidget);
      });

      testWidgets(
        'dropdown shows For You, Following, New, Classics, and subscribed lists',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            VideoFeedBlocState(
              status: VideoFeedStatus.success,
              source: const VideoFeedSource.forYou(),
              subscribedLists: [curatedList(id: 'best', name: 'Best Vines')],
            ),
          );
          await tester.pumpWidget(createTestWidget());

          await tester.tap(find.text(l10n.feedModeForYou));
          await tester.pumpAndSettle();

          expect(find.text(l10n.feedModeForYou), findsWidgets);
          expect(find.text(l10n.feedModeFollowing), findsOneWidget);
          expect(find.text(l10n.feedModeNew), findsOneWidget);
          expect(find.text(l10n.feedModeClassics), findsOneWidget);
          expect(find.text('Best Vines'), findsOneWidget);
        },
      );

      testWidgets('dispatches VideoFeedSourceChanged when For You selected', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            source: VideoFeedSource.following(),
          ),
        );
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.text(l10n.feedModeFollowing));
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.feedModeForYou));
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(
            const VideoFeedSourceChanged(VideoFeedSource.forYou()),
          ),
        ).called(1);
      });

      testWidgets('dispatches VideoFeedSourceChanged when following selected', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            source: VideoFeedSource.forYou(),
          ),
        );
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.text(l10n.feedModeForYou));
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.feedModeFollowing));
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(
            const VideoFeedSourceChanged(VideoFeedSource.following()),
          ),
        ).called(1);
      });

      testWidgets('dispatches VideoFeedSourceChanged when New selected', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            source: VideoFeedSource.forYou(),
          ),
        );
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.text(l10n.feedModeForYou));
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.feedModeNew));
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(
            const VideoFeedSourceChanged(VideoFeedSource.newVideos()),
          ),
        ).called(1);
      });

      testWidgets('dispatches VideoFeedSourceChanged when Classics selected', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            source: VideoFeedSource.forYou(),
          ),
        );
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.text(l10n.feedModeForYou));
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.feedModeClassics));
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(
            const VideoFeedSourceChanged(VideoFeedSource.classic()),
          ),
        ).called(1);
      });

      testWidgets(
        'dispatches VideoFeedSourceChanged when subscribed list selected',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            VideoFeedBlocState(
              status: VideoFeedStatus.success,
              source: const VideoFeedSource.forYou(),
              subscribedLists: [curatedList(id: 'best', name: 'Best Vines')],
            ),
          );
          await tester.pumpWidget(createTestWidget());

          await tester.tap(find.text(l10n.feedModeForYou));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Best Vines'));
          await tester.pumpAndSettle();

          verify(
            () => mockBloc.add(
              const VideoFeedSourceChanged(
                VideoFeedSource.subscribedList(
                  listId: 'best',
                  listName: 'Best Vines',
                ),
              ),
            ),
          ).called(1);
        },
      );

      testWidgets('does not dispatch event when bottom sheet dismissed', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            source: VideoFeedSource.forYou(),
          ),
        );
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.text(l10n.feedModeForYou));
        await tester.pumpAndSettle();

        // Dismiss by tapping outside (on the barrier).
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        verifyNever(() => mockBloc.add(any()));
      });

      testWidgets('pauses video playback while the mode sheet is open', (
        tester,
      ) async {
        // Regression: the mode sheet used to bypass the overlay-visibility
        // integration, so the video behind it kept playing.
        when(() => mockBloc.state).thenReturn(
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            source: VideoFeedSource.forYou(),
          ),
        );
        await tester.pumpWidget(createTestWidget());

        final container = ProviderScope.containerOf(
          tester.element(find.byType(FeedModeSwitch)),
          listen: false,
        );

        await tester.tap(find.text(l10n.feedModeForYou));
        await tester.pumpAndSettle();

        expect(
          container.read(overlayVisibilityProvider).isBottomSheetOpen,
          isTrue,
        );

        await tester.tap(find.text(l10n.feedModeFollowing));
        await tester.pumpAndSettle();

        expect(
          container.read(overlayVisibilityProvider).isBottomSheetOpen,
          isFalse,
        );
      });

      testWidgets(
        'clears the pause flag when the mode sheet is dismissed without a '
        'selection',
        (tester) async {
          // Regression guard: dismissing via the scrim (no option tapped)
          // must still resume playback. The clear lives in the extension's
          // whenComplete, so it fires on cancel too — this pins that path.
          when(() => mockBloc.state).thenReturn(
            const VideoFeedBlocState(
              status: VideoFeedStatus.success,
              source: VideoFeedSource.forYou(),
            ),
          );
          await tester.pumpWidget(createTestWidget());

          final container = ProviderScope.containerOf(
            tester.element(find.byType(FeedModeSwitch)),
            listen: false,
          );

          await tester.tap(find.text(l10n.feedModeForYou));
          await tester.pumpAndSettle();

          expect(
            container.read(overlayVisibilityProvider).isBottomSheetOpen,
            isTrue,
          );

          // Dismiss by tapping outside (on the barrier), no option selected.
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();

          expect(
            container.read(overlayVisibilityProvider).isBottomSheetOpen,
            isFalse,
          );
        },
      );
    });

    group('Tap Area Coverage', () {
      // Regression: before HitTestBehavior.opaque was set on the
      // GestureDetector, taps on the caret icon and the spacing gap
      // between label and caret fell through -- only the text label itself
      // responded.

      testWidgets(
        'opens bottom sheet when caret icon is tapped (not the text label)',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const VideoFeedBlocState(
              status: VideoFeedStatus.success,
              source: VideoFeedSource.forYou(),
            ),
          );
          await tester.pumpWidget(createTestWidget());

          // The visible caret uses VineTheme.whiteText; shadow copies use
          // VineTheme.innerShadow -- filter to the real icon only.
          final caretIcon = find.descendant(
            of: find.byType(FeedModeSwitch),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is DivineIcon &&
                  w.icon == DivineIconName.caretDown &&
                  w.color == VineTheme.whiteText,
            ),
          );
          expect(caretIcon, findsOneWidget);

          await tester.tap(caretIcon);
          await tester.pumpAndSettle();

          expect(find.byType(VineBottomSheet), findsOneWidget);
        },
      );

      testWidgets(
        'opens bottom sheet when tapping the spacing gap between label and caret',
        (tester) async {
          // The 12 px Row spacing gap has no child widget drawn in it;
          // HitTestBehavior.opaque ensures it still registers taps.
          when(() => mockBloc.state).thenReturn(
            const VideoFeedBlocState(
              status: VideoFeedStatus.success,
              source: VideoFeedSource.forYou(),
            ),
          );
          await tester.pumpWidget(createTestWidget());

          final textRect = tester.getRect(find.text(l10n.feedModeForYou));
          final caretIcon = find.descendant(
            of: find.byType(FeedModeSwitch),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is DivineIcon &&
                  w.icon == DivineIconName.caretDown &&
                  w.color == VineTheme.whiteText,
            ),
          );
          final caretRect = tester.getRect(caretIcon);

          await tester.tapAt(
            Offset((textRect.right + caretRect.left) / 2, textRect.center.dy),
          );
          await tester.pumpAndSettle();

          expect(find.byType(VineBottomSheet), findsOneWidget);
        },
      );
    });

    group('Immersive mode', () {
      testWidgets('fades the header out while the viewer holds the video', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            source: VideoFeedSource.forYou(),
          ),
        );
        final immersiveCubit = FeedImmersiveCubit();
        addTearDown(immersiveCubit.close);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Stack(
                  children: [
                    MultiBlocProvider(
                      providers: [
                        BlocProvider<VideoFeedBloc>.value(value: mockBloc),
                        BlocProvider<FeedImmersiveCubit>.value(
                          value: immersiveCubit,
                        ),
                      ],
                      child: const FeedModeSwitch(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        double headerOpacity() => tester
            .widget<AnimatedOpacity>(
              find
                  .descendant(
                    of: find.byType(FeedImmersiveChrome),
                    matching: find.byType(AnimatedOpacity),
                  )
                  .first,
            )
            .opacity;

        expect(headerOpacity(), equals(1.0));

        immersiveCubit.enter();
        await tester.pumpAndSettle();

        expect(headerOpacity(), equals(0.0));
      });
    });

    group('Accessibility', () {
      // Helper: finds the Semantics widget that wraps the feed-mode
      // GestureDetector by walking up from the visible label text.
      Semantics findFeedModeSemanticsWidget(WidgetTester tester, String label) {
        final expectedLabel = l10n.feedModeSemanticLabel(label);
        return tester.widget<Semantics>(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byWidgetPredicate(
                  (w) => w is Semantics && w.properties.label == expectedLabel,
                ),
              )
              .first,
        );
      }

      testWidgets(
        'Semantics widget carries button=true and the current source label',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const VideoFeedBlocState(
              status: VideoFeedStatus.success,
              source: VideoFeedSource.forYou(),
            ),
          );
          await tester.pumpWidget(createTestWidget());

          final semanticsWidget = findFeedModeSemanticsWidget(
            tester,
            l10n.feedModeForYou,
          );
          expect(
            semanticsWidget.properties.label,
            equals(l10n.feedModeSemanticLabel(l10n.feedModeForYou)),
          );
          expect(semanticsWidget.properties.button, isTrue);
        },
      );

      testWidgets('semantics label updates when the feed source changes', (
        tester,
      ) async {
        whenListen(
          mockBloc,
          Stream.fromIterable([
            const VideoFeedBlocState(
              status: VideoFeedStatus.success,
              source: VideoFeedSource.following(),
            ),
          ]),
          initialState: const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            source: VideoFeedSource.forYou(),
          ),
        );
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        final semanticsWidget = findFeedModeSemanticsWidget(
          tester,
          l10n.feedModeFollowing,
        );
        expect(
          semanticsWidget.properties.label,
          equals(l10n.feedModeSemanticLabel(l10n.feedModeFollowing)),
        );
      });

      testWidgets(
        'opens bottom sheet when the Semantics button area is tapped',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const VideoFeedBlocState(
              status: VideoFeedStatus.success,
              source: VideoFeedSource.forYou(),
            ),
          );
          await tester.pumpWidget(createTestWidget());

          await tester.tap(
            find
                .ancestor(
                  of: find.text(l10n.feedModeForYou),
                  matching: find.byWidgetPredicate(
                    (w) =>
                        w is Semantics &&
                        w.properties.label ==
                            l10n.feedModeSemanticLabel(l10n.feedModeForYou),
                  ),
                )
                .first,
          );
          await tester.pumpAndSettle();

          expect(find.byType(VineBottomSheet), findsOneWidget);
        },
      );
    });

    testWidgets('label gets updated when source changes', (tester) async {
      whenListen(
        mockBloc,
        Stream.fromIterable([
          const VideoFeedBlocState(
            status: VideoFeedStatus.success,
            source: VideoFeedSource.forYou(),
          ),
        ]),
        initialState: const VideoFeedBlocState(
          status: VideoFeedStatus.success,
          source: VideoFeedSource.following(),
        ),
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text(l10n.feedModeForYou), findsOneWidget);
    });
  });
}
