// ABOUTME: Tests for ComposableVideoGrid widget
// ABOUTME: Verifies grid rendering, broken video filtering, and user interactions
//
// NOTE: Tests that render video tiles are skipped because ComposableVideoGrid
// uses UserName widget, which triggers the Nostr provider chain
// (userProfileReactive -> userProfileService -> nostrService) that attempts
// real WebSocket connections to relays.
//
// Flutter's TestWidgetsFlutterBinding automatically intercepts and mocks all
// HTTP/WebSocket connections, returning "Mocked response" errors. This is built
// into Flutter's test framework, not something we control.
//
// For tests with real Nostr connections, see the integration test version at:
// test/integration/composable_video_grid_test.dart
//
// That version uses IntegrationTestWidgetsFlutterBinding which allows real
// network connections and tests the widget in the context of the running app.
//
// The skipped tile tests are kept for reference and potential future
// refactoring where ComposableVideoGrid could accept profile data as props
// instead of fetching via providers, which would allow isolated widget testing.

import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/creator_delete_enforcement_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/repositories/creator_delete_enforcement_repository.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/broken_video_tracker.dart' as broken_tracker;
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/subscribed_list_video_cache.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
// Override lives in riverpod's misc barrel; flutter_riverpod does not
// re-export the type name even though it accepts List<Override>.
import 'package:riverpod/misc.dart' show Override;

import '../helpers/test_provider_overrides.dart';

const _ownPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

class _MockContentDeletionService extends Mock
    implements ContentDeletionService {}

class _MockEnforcementRepository extends Mock
    implements CreatorDeleteEnforcementRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockSubscribedListVideoCache extends Mock
    implements SubscribedListVideoCache {}

/// Provider overrides every scope in this file needs.
///
/// [ComposableVideoGrid] renders `UserName`, which reaches the user-profile
/// provider chain and transitively requires SharedPreferences. Without the
/// override the scope throws `UnimplementedError: sharedPreferencesProvider
/// must be overridden`, which is why this file's tile-rendering tests were
/// previously disabled with `skip: true`.
List<Override> _gridOverrides(
  broken_tracker.BrokenVideoTracker tracker, {
  MockNostrClient? nostrService,
  MockAuthService? authService,
  SubscribedListVideoCache? subscribedListCache,
  List<Override> extra = const [],
}) => [
  sharedPreferencesProvider.overrideWithValue(createMockSharedPreferences()),
  authServiceProvider.overrideWithValue(authService ?? createMockAuthService()),
  nostrServiceProvider.overrideWithValue(
    nostrService ?? createMockNostrService(),
  ),
  brokenVideoTrackerProvider.overrideWith((ref) async => tracker),
  subscribedListVideoCacheProvider.overrideWithValue(subscribedListCache),
  userProfileReactiveProvider.overrideWith((ref, pubkey) => Stream.value(null)),
  ...extra,
];

/// A mock auth service reporting a signed-in session for [pubkey].
///
/// `createMockAuthService` stubs `authState` and `isAuthenticated`
/// independently, so both are set here: the grid reads the bool, and leaving
/// them inconsistent would make a "signed in" fixture behave as signed out.
MockAuthService _authenticatedAuthService(String pubkey) {
  final authService = createMockAuthService();
  when(() => authService.authState).thenReturn(AuthState.authenticated);
  when(() => authService.isAuthenticated).thenReturn(true);
  when(() => authService.currentPublicKeyHex).thenReturn(pubkey);
  return authService;
}

void main() {
  group('ComposableVideoGrid', () {
    late List<VideoEvent> testVideos;
    late broken_tracker.BrokenVideoTracker mockTracker;

    setUp(() {
      final now = DateTime.now();
      final nowTimestamp = now.millisecondsSinceEpoch ~/ 1000;
      testVideos = [
        VideoEvent(
          id: 'video1',
          pubkey: 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2', // 64-char hex pubkey
          content: 'Test video 1',
          title: 'Video 1',
          videoUrl: 'https://example.com/video1.mp4',
          thumbnailUrl: 'https://example.com/thumb1.jpg',
          duration: 5,
          originalLikes: 10,
          originalLoops: 100,
          createdAt: nowTimestamp,
          timestamp: now,
        ),
        VideoEvent(
          id: 'video2',
          pubkey: 'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3', // 64-char hex pubkey
          content: 'Test video 2',
          title: 'Video 2',
          videoUrl: 'https://example.com/video2.mp4',
          thumbnailUrl: 'https://example.com/thumb2.jpg',
          duration: 3,
          originalLikes: 5,
          originalLoops: 50,
          createdAt: nowTimestamp,
          timestamp: now,
        ),
        VideoEvent(
          id: 'broken_video',
          pubkey: 'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4', // 64-char hex pubkey
          content: 'Broken video',
          title: 'Broken Video',
          videoUrl: 'https://example.com/broken.mp4',
          duration: 4,
          createdAt: nowTimestamp,
          timestamp: now,
        ),
      ];

      // Create mock tracker with no broken videos
      mockTracker = broken_tracker.BrokenVideoTracker();
    });

    testWidgets('renders grid with provided videos', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _gridOverrides(mockTracker),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: testVideos.take(2).toList(), // Only non-broken videos
                onVideoTap: (videos, index) {},
              ),
            ),
          ),
        ),
      );

      // Wait for widget to build
      await tester.pump();

      // Should render 2 video tiles
      expect(find.byType(GestureDetector), findsNWidgets(2));
    });

    testWidgets('filters out broken videos using BrokenVideoTracker', (
      tester,
    ) async {
      // Mark video as broken
      mockTracker.markVideoBroken('broken_video', 'Test broken');

      await tester.pumpWidget(
        ProviderScope(
          overrides: _gridOverrides(mockTracker),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: testVideos, // All 3 videos including broken one
                onVideoTap: (videos, index) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Should only render 2 tiles (broken_video filtered out)
      expect(find.byType(GestureDetector), findsNWidgets(2));
    });

    testWidgets('shows empty state when no videos after filtering', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _gridOverrides(mockTracker),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: const [],
                onVideoTap: (videos, index) {},
                emptyBuilder: () => const Text('No videos available'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('No videos available'), findsOneWidget);
    });

    testWidgets('keeps empty state refreshable when refresh callback is set', (
      tester,
    ) async {
      var refreshCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: _gridOverrides(mockTracker),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: const [],
                onVideoTap: (videos, index) {},
                onRefresh: () async {
                  refreshCount++;
                },
                emptyBuilder: () => const Text('No videos available'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('No videos available'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.byType(Scrollable), findsOneWidget);

      final refreshIndicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      await refreshIndicator.onRefresh();

      expect(refreshCount, 1);
    });

    testWidgets('refreshes empty state from top-edge pointer scroll down', (
      tester,
    ) async {
      var refreshCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: _gridOverrides(mockTracker),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: const [],
                onVideoTap: (videos, index) {},
                onRefresh: () async {
                  refreshCount++;
                },
                emptyBuilder: () => const Text('No videos available'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final pointer = TestPointer(1, PointerDeviceKind.trackpad);
      pointer.hover(tester.getCenter(find.byType(Scrollable)));

      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
      await tester.pumpAndSettle();

      expect(refreshCount, 1);
    });

    testWidgets('calls onVideoTap with correct params when tile tapped', (
      tester,
    ) async {
      List<VideoEvent>? tappedVideos;
      int? tappedIndex;

      await tester.pumpWidget(
        ProviderScope(
          overrides: _gridOverrides(mockTracker),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: testVideos.take(2).toList(),
                onVideoTap: (videos, index) {
                  tappedVideos = videos;
                  tappedIndex = index;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Tap the second video
      await tester.tap(find.byType(GestureDetector).at(1));
      await tester.pump();

      expect(tappedIndex, equals(1));
      expect(tappedVideos, isNotNull);
      expect(tappedVideos!.length, equals(2));
    });

    testWidgets('uses correct grid parameters', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _gridOverrides(mockTracker),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: testVideos.take(2).toList(),
                onVideoTap: (videos, index) {},
                crossAxisCount: 3,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // The grid is built from slivers inside a CustomScrollView, so the
      // delegate hangs off SliverGrid rather than a GridView.
      final sliverGrid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final delegate =
          sliverGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

      expect(delegate.crossAxisCount, equals(3));
      expect(delegate.childAspectRatio, equals(1.0));
    });

    testWidgets('renders the video title over the thumbnail', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _gridOverrides(mockTracker),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: [testVideos.first],
                onVideoTap: (videos, index) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // The info overlay carries the author and the title. Engagement counts
      // and the duration badge are no longer rendered here.
      expect(find.text('Video 1'), findsOneWidget);
    });

    group('delete confirmation copy', () {
      testWidgets(
        'uses the shared owner-delete confirmation copy for owned videos',
        (tester) async {
          final mockNostr = createMockNostrService();
          when(() => mockNostr.publicKey).thenReturn(_ownPubkey);
          final l10n = lookupAppLocalizations(const Locale('en'));
          final video = VideoEvent(
            id: 'owned-video',
            pubkey: _ownPubkey,
            content: 'Owned video',
            title: 'Owned video',
            authorName: 'Creator',
            videoUrl: 'https://example.com/owned.mp4',
            thumbnailUrl: 'https://example.com/owned.jpg',
            duration: 5,
            createdAt: DateTime(2026).millisecondsSinceEpoch ~/ 1000,
            timestamp: DateTime(2026),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: _gridOverrides(
                mockTracker,
                nostrService: mockNostr,
                authService: _authenticatedAuthService(_ownPubkey),
              ),
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: ComposableVideoGrid(
                    videos: [video],
                    onVideoTap: (videos, index) {},
                  ),
                ),
              ),
            ),
          );

          await tester.pump();
          await tester.longPress(
            find.bySemanticsLabel(l10n.profileVideoThumbnailLabel(1)),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.videoGridDeleteVideo));
          await tester.pumpAndSettle();

          final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
          expect(dialog.title, isA<Text>());
          expect((dialog.title! as Text).data, l10n.shareMenuDeleteVideo);
          expect(dialog.content, isA<Text>());
          expect(
            (dialog.content! as Text).data,
            l10n.shareMenuDeleteConfirmation,
          );
          expect(dialog.actions, hasLength(2));
          expect(find.text(l10n.shareMenuDeleteConfirmation), findsOneWidget);
        },
      );
      testWidgets('shows the relay failure result after delete', (
        tester,
      ) async {
        final mockNostr = createMockNostrService();
        when(() => mockNostr.publicKey).thenReturn(_ownPubkey);
        final l10n = lookupAppLocalizations(const Locale('en'));
        final deletionService = _MockContentDeletionService();
        final enforcementRepository = _MockEnforcementRepository();
        final videoEventService = _MockVideoEventService();
        final relayCompleter = Completer<DeleteResult>();
        final video = VideoEvent(
          id: 'owned-video',
          pubkey: _ownPubkey,
          content: 'Owned video',
          title: 'Owned video',
          authorName: 'Creator',
          videoUrl: 'https://example.com/owned.mp4',
          thumbnailUrl: 'https://example.com/owned.jpg',
          duration: 5,
          createdAt: DateTime(2026).millisecondsSinceEpoch ~/ 1000,
          timestamp: DateTime(2026),
        );
        when(
          () => deletionService.quickDelete(
            video: video,
            reason: DeleteReason.personalChoice,
          ),
        ).thenAnswer((_) => relayCompleter.future);

        await tester.pumpWidget(
          ProviderScope(
            overrides: _gridOverrides(
              mockTracker,
              nostrService: mockNostr,
              authService: _authenticatedAuthService(_ownPubkey),
              extra: [
                contentDeletionServiceProvider.overrideWith(
                  (ref) async => deletionService,
                ),
                creatorDeleteEnforcementRepositoryProvider.overrideWithValue(
                  enforcementRepository,
                ),
                videoEventServiceProvider.overrideWithValue(videoEventService),
              ],
            ),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ComposableVideoGrid(
                  videos: [video],
                  onVideoTap: (videos, index) {},
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.longPress(
          find.bySemanticsLabel(l10n.profileVideoThumbnailLabel(1)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoGridDeleteVideo));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.shareMenuDelete));
        await tester.pump();

        await tester.longPress(
          find.bySemanticsLabel(l10n.profileVideoThumbnailLabel(1)),
        );
        await tester.pump(const Duration(milliseconds: 500));
        final editTile = tester.widget<ListTile>(
          find.ancestor(
            of: find.text(l10n.videoGridEditVideo),
            matching: find.byType(ListTile),
          ),
        );
        expect(editTile.enabled, isFalse);

        relayCompleter.complete(
          DeleteResult.failure(
            'relay rejected',
            DeleteFailureKind.relayRejected,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.shareMenuDeleteFailedRelayRejected),
          findsOneWidget,
        );
      });
      testWidgets('keeps Edit and Delete blocked until cleanup finishes', (
        tester,
      ) async {
        final mockNostr = createMockNostrService();
        final deletionService = _MockContentDeletionService();
        final enforcementRepository = _MockEnforcementRepository();
        final videoEventService = _MockVideoEventService();
        final cleanupCompleter = Completer<CreatorDeleteEnforcementResult>();
        when(() => mockNostr.publicKey).thenReturn(_ownPubkey);
        final l10n = lookupAppLocalizations(const Locale('en'));
        final video = VideoEvent(
          id: 'owned-video',
          pubkey: _ownPubkey,
          content: 'Owned video',
          title: 'Owned video',
          authorName: 'Creator',
          videoUrl: 'https://example.com/owned.mp4',
          thumbnailUrl: 'https://example.com/owned.jpg',
          duration: 5,
          createdAt: DateTime(2026).millisecondsSinceEpoch ~/ 1000,
          timestamp: DateTime(2026),
        );
        when(
          () => deletionService.quickDelete(
            video: video,
            reason: DeleteReason.personalChoice,
          ),
        ).thenAnswer(
          (_) async => DeleteResult.createSuccess(
            'delete-event-id',
            acceptance: DeleteAcceptance.everyRelay,
          ),
        );
        when(
          () => enforcementRepository.enforce('delete-event-id'),
        ).thenAnswer((_) => cleanupCompleter.future);

        await tester.pumpWidget(
          ProviderScope(
            overrides: _gridOverrides(
              mockTracker,
              nostrService: mockNostr,
              authService: _authenticatedAuthService(_ownPubkey),
              extra: [
                contentDeletionServiceProvider.overrideWith(
                  (ref) async => deletionService,
                ),
                creatorDeleteEnforcementRepositoryProvider.overrideWithValue(
                  enforcementRepository,
                ),
                videoEventServiceProvider.overrideWithValue(videoEventService),
              ],
            ),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ComposableVideoGrid(
                  videos: [video],
                  onVideoTap: (videos, index) {},
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        final tile = find.bySemanticsLabel(l10n.profileVideoThumbnailLabel(1));
        await tester.longPress(tile);
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoGridDeleteVideo));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.shareMenuDelete));
        await tester.pumpAndSettle();

        await tester.longPress(tile);
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        var deleteTile = tester.widget<ListTile>(
          find.ancestor(
            of: find.text(l10n.videoGridDeleteVideo),
            matching: find.byType(ListTile),
          ),
        );
        expect(deleteTile.enabled, isFalse);
        var editTile = tester.widget<ListTile>(
          find.ancestor(
            of: find.text(l10n.videoGridEditVideo),
            matching: find.byType(ListTile),
          ),
        );
        expect(editTile.enabled, isFalse);

        cleanupCompleter.complete(
          const CreatorDeleteEnforcementResult.confirmed(),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        deleteTile = tester.widget<ListTile>(
          find.ancestor(
            of: find.text(l10n.videoGridDeleteVideo),
            matching: find.byType(ListTile),
          ),
        );
        expect(deleteTile.enabled, isTrue);
        editTile = tester.widget<ListTile>(
          find.ancestor(
            of: find.text(l10n.videoGridEditVideo),
            matching: find.byType(ListTile),
          ),
        );
        expect(editTile.enabled, isTrue);
      });
    });

    group('selection mode', () {
      Widget buildGrid({required Set<String> selectedVideoIds}) {
        return ProviderScope(
          overrides: _gridOverrides(mockTracker),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: testVideos.take(2).toList(),
                selectedVideoIds: selectedVideoIds,
                onVideoTap: (videos, index) {},
              ),
            ),
          ),
        );
      }

      Finder selectedBadges() => find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.maxWidth == 24 &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color == VineTheme.vineGreen,
      );

      Finder unselectedBadges() => find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.maxWidth == 24 &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color ==
                VineTheme.whiteText.withValues(alpha: 0.25),
      );

      testWidgets('marks only the selected tile with the filled badge', (
        tester,
      ) async {
        await tester.pumpWidget(buildGrid(selectedVideoIds: {'video1'}));
        await tester.pump();

        expect(selectedBadges(), findsOneWidget);
        expect(unselectedBadges(), findsOneWidget);
      });

      testWidgets('paints the selected badge per the design', (tester) async {
        // Figma: vineGreen circle with a stroked check in the dark button
        // ink, and the selected thumbnail dimmed to half opacity.
        await tester.pumpWidget(buildGrid(selectedVideoIds: {'video1'}));
        await tester.pump();

        expect(
          find.descendant(
            of: selectedBadges(),
            matching: find.byType(CustomPaint),
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Opacity && widget.opacity == 0.5,
          ),
          findsOneWidget,
        );

        final unselected =
            tester.widget<Container>(unselectedBadges()).decoration!
                as BoxDecoration;
        expect(
          unselected.border,
          Border.all(color: VineTheme.whiteText, width: 2),
        );
      });

      testWidgets('announces per-tile selection state to assistive tech', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(buildGrid(selectedVideoIds: {'video1'}));
        await tester.pump();

        expect(
          tester.getSemantics(find.bySemanticsIdentifier('video_thumbnail_0')),
          isSemantics(isSelected: true),
        );
        expect(
          tester.getSemantics(find.bySemanticsIdentifier('video_thumbnail_1')),
          isSemantics(isSelected: false),
        );
        semantics.dispose();
      });

      testWidgets('shows no selection circles outside selection mode', (
        tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: _gridOverrides(mockTracker),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ComposableVideoGrid(
                  videos: testVideos.take(2).toList(),
                  onVideoTap: (videos, index) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(selectedBadges(), findsNothing);
        expect(unselectedBadges(), findsNothing);
      });
    });

    group('top outer radius', () {
      // Resolved to physical corners per direction: the grid hands the tile
      // a directional radius so RTL mirrors it with the mirrored columns.
      BorderRadius tileRadius(
        WidgetTester tester,
        int index, {
        TextDirection direction = TextDirection.ltr,
      }) => tester
          .widget<ClipRRect>(
            find
                .descendant(
                  of: find.byWidgetPredicate(
                    (widget) =>
                        widget is Semantics &&
                        widget.properties.identifier ==
                            'video_thumbnail_$index',
                  ),
                  matching: find.byType(ClipRRect),
                )
                .first,
          )
          .borderRadius
          .resolve(direction);

      double tileDx(WidgetTester tester, int index) => tester
          .getTopLeft(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.identifier == 'video_thumbnail_$index',
            ),
          )
          .dx;

      testWidgets("enlarges only the first row's outer top corners", (
        tester,
      ) async {
        // Phone-width surface pins the responsive column count to 2, so the
        // top row is exactly items 0 and 1.
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: _gridOverrides(mockTracker),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ComposableVideoGrid(
                  videos: testVideos,
                  useMasonryLayout: true,
                  topOuterRadius: 32,
                  onVideoTap: (videos, index) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        const inner = Radius.circular(4);
        const outer = Radius.circular(32);
        expect(
          tileRadius(tester, 0),
          const BorderRadius.only(
            topLeft: outer,
            topRight: inner,
            bottomLeft: inner,
            bottomRight: inner,
          ),
        );
        expect(
          tileRadius(tester, 1),
          const BorderRadius.only(
            topLeft: inner,
            topRight: outer,
            bottomLeft: inner,
            bottomRight: inner,
          ),
        );
        // Second row keeps the default small radius on every corner.
        expect(tileRadius(tester, 2), const BorderRadius.all(inner));
      });

      testWidgets('mirrors the outer corners with the columns under RTL', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: _gridOverrides(mockTracker),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: ComposableVideoGrid(
                    videos: testVideos,
                    useMasonryLayout: true,
                    topOuterRadius: 32,
                    onVideoTap: (videos, index) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // The masonry render object mirrors columns under RTL: tile 0 paints
        // on the right. Its enlarged corner must follow it there — a physical
        // topLeft would bite mid-edge instead (#8453 review).
        expect(tileDx(tester, 0), greaterThan(tileDx(tester, 1)));

        const inner = Radius.circular(4);
        const outer = Radius.circular(32);
        const rtl = TextDirection.rtl;
        expect(
          tileRadius(tester, 0, direction: rtl),
          const BorderRadius.only(
            topRight: outer,
            topLeft: inner,
            bottomLeft: inner,
            bottomRight: inner,
          ),
        );
        expect(
          tileRadius(tester, 1, direction: rtl),
          const BorderRadius.only(
            topRight: inner,
            topLeft: outer,
            bottomLeft: inner,
            bottomRight: inner,
          ),
        );
      });

      testWidgets('keeps every corner small when not set', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: _gridOverrides(mockTracker),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ComposableVideoGrid(
                  videos: testVideos.take(2).toList(),
                  useMasonryLayout: true,
                  onVideoTap: (videos, index) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        const inner = Radius.circular(4);
        expect(tileRadius(tester, 0), const BorderRadius.all(inner));
        expect(tileRadius(tester, 1), const BorderRadius.all(inner));
      });
    });

    group('subscribed-list badge', () {
      Finder badgeFinder() => find.byWidgetPredicate(
        (widget) =>
            widget is DivineIcon && widget.icon == DivineIconName.images,
      );

      Widget buildGrid({required bool showBadge}) {
        final cache = _MockSubscribedListVideoCache();
        when(() => cache.getListsForVideo(any())).thenReturn({'some-list'});
        return ProviderScope(
          overrides: _gridOverrides(mockTracker, subscribedListCache: cache),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: testVideos.take(2).toList(),
                showSubscribedListBadge: showBadge,
                onVideoTap: (videos, index) {},
              ),
            ),
          ),
        );
      }

      testWidgets('marks tiles whose video is in a subscribed list', (
        tester,
      ) async {
        await tester.pumpWidget(buildGrid(showBadge: true));
        await tester.pump();

        expect(badgeFinder(), findsNWidgets(2));
      });

      testWidgets('defaults to showing the badge when the flag is omitted', (
        tester,
      ) async {
        // Pins the constructor default — the production path for every
        // discovery surface, none of which pass the flag.
        final cache = _MockSubscribedListVideoCache();
        when(() => cache.getListsForVideo(any())).thenReturn({'some-list'});
        await tester.pumpWidget(
          ProviderScope(
            overrides: _gridOverrides(mockTracker, subscribedListCache: cache),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ComposableVideoGrid(
                  videos: testVideos.take(2).toList(),
                  onVideoTap: (videos, index) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(badgeFinder(), findsNWidgets(2));
      });

      testWidgets('shows no badge when the caller turns it off', (
        tester,
      ) async {
        await tester.pumpWidget(buildGrid(showBadge: false));
        await tester.pump();

        expect(badgeFinder(), findsNothing);
      });
    });

    group('header slivers', () {
      testWidgets('renders header slivers above the grid', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: _gridOverrides(mockTracker),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ComposableVideoGrid(
                  videos: testVideos.take(2).toList(),
                  headerSlivers: const [
                    SliverToBoxAdapter(child: Text('HEADER')),
                  ],
                  onVideoTap: (videos, index) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('HEADER'), findsOneWidget);
        expect(find.byType(GestureDetector), findsNWidgets(2));
      });

      testWidgets('keeps header slivers above the empty state', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: _gridOverrides(mockTracker),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ComposableVideoGrid(
                  videos: const [],
                  headerSlivers: const [
                    SliverToBoxAdapter(child: Text('HEADER')),
                  ],
                  onVideoTap: (videos, index) {},
                  emptyBuilder: () => const Text('EMPTY'),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('HEADER'), findsOneWidget);
        expect(find.text('EMPTY'), findsOneWidget);
      });
    });

    group('background panel', () {
      Widget buildGrid({
        List<VideoEvent> videos = const [],
        Color? backgroundColor,
        double? topOuterRadius,
        Widget Function()? emptyBuilder,
        List<Widget> headerSlivers = const [],
      }) {
        return ProviderScope(
          overrides: _gridOverrides(mockTracker),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: videos,
                backgroundColor: backgroundColor,
                topOuterRadius: topOuterRadius,
                emptyBuilder: emptyBuilder,
                headerSlivers: headerSlivers,
                onVideoTap: (videos, index) {},
              ),
            ),
          ),
        );
      }

      testWidgets('paints a rounded panel behind the grid and fills below it', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildGrid(
            videos: testVideos.take(2).toList(),
            backgroundColor: const Color(0xFF112233),
            topOuterRadius: 32,
          ),
        );
        await tester.pump();

        final panel = tester.widget<DecoratedSliver>(
          find.byType(DecoratedSliver),
        );
        final decoration = panel.decoration as BoxDecoration;
        expect(decoration.color, const Color(0xFF112233));
        expect(
          decoration.borderRadius,
          const BorderRadius.vertical(top: Radius.circular(32)),
        );
        // The panel continues to the bottom of the viewport when the grid
        // content is shorter than the screen.
        final filler = tester.widget<SliverFillRemaining>(
          find.byType(SliverFillRemaining),
        );
        expect((filler.child! as ColoredBox).color, const Color(0xFF112233));
      });

      testWidgets('defaults to no panel', (tester) async {
        await tester.pumpWidget(
          buildGrid(videos: testVideos.take(2).toList()),
        );
        await tester.pump();

        expect(find.byType(DecoratedSliver), findsNothing);
      });

      testWidgets('paints the panel behind the empty state', (tester) async {
        await tester.pumpWidget(
          buildGrid(
            backgroundColor: const Color(0xFF112233),
            topOuterRadius: 32,
            headerSlivers: const [SliverToBoxAdapter(child: Text('HEADER'))],
            emptyBuilder: () => const Text('EMPTY'),
          ),
        );
        await tester.pump();

        final box = tester.widget<DecoratedBox>(
          find
              .ancestor(
                of: find.text('EMPTY'),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final decoration = box.decoration as BoxDecoration;
        expect(decoration.color, const Color(0xFF112233));
        expect(
          decoration.borderRadius,
          const BorderRadius.vertical(top: Radius.circular(32)),
        );
      });
    });

    group('load-more footer', () {
      // Renders the grid path with no tiles (empty list + no emptyBuilder) so
      // the footer can be exercised without the video-tile Nostr/network chain.
      Widget buildGrid({
        required bool isLoadingMore,
        required bool hasMoreContent,
        Future<void> Function()? onLoadMore,
      }) {
        return ProviderScope(
          overrides: _gridOverrides(mockTracker),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ComposableVideoGrid(
                videos: const [],
                onVideoTap: (videos, index) {},
                isLoadingMore: isLoadingMore,
                hasMoreContent: hasMoreContent,
                onLoadMore: onLoadMore,
              ),
            ),
          ),
        );
      }

      testWidgets(
        'shows a centered $BrandedLoadingIndicator below the scrolling grid '
        'while loading more',
        (tester) async {
          await tester.pumpWidget(
            buildGrid(
              isLoadingMore: true,
              hasMoreContent: true,
              onLoadMore: () async {},
            ),
          );
          await tester.pump(); // resolve broken-tracker future

          expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
          // The footer is no longer a grid cell: the grid is a sliver scroll
          // view and the legacy box-scrolling GridView is gone.
          expect(find.byType(CustomScrollView), findsOneWidget);
          expect(find.byType(GridView), findsNothing);

          // Horizontally centered across the full scrollable width.
          final indicatorCenter = tester.getCenter(
            find.byType(BrandedLoadingIndicator),
          );
          final scrollViewCenter = tester.getCenter(
            find.byType(CustomScrollView),
          );
          expect(
            indicatorCenter.dx,
            moreOrLessEquals(scrollViewCenter.dx, epsilon: 1),
          );
        },
      );

      testWidgets('does not show the loading indicator when not loading more', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildGrid(
            isLoadingMore: false,
            hasMoreContent: true,
            onLoadMore: () async {},
          ),
        );
        await tester.pump();

        // Footer slot exists (more content available) but stays empty until
        // a load actually starts.
        expect(find.byType(BrandedLoadingIndicator), findsNothing);
      });

      testWidgets('omits the loading indicator when there is no more content', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildGrid(isLoadingMore: false, hasMoreContent: false),
        );
        await tester.pump();

        expect(find.byType(BrandedLoadingIndicator), findsNothing);
      });
    });

    group('owner action affordance', () {
      const otherPubkey =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

      VideoEvent videoBy(String pubkey) => VideoEvent(
        id: 'video-by-$pubkey',
        pubkey: pubkey,
        content: 'A video',
        title: 'A video',
        authorName: 'Creator',
        videoUrl: 'https://example.com/v.mp4',
        thumbnailUrl: 'https://example.com/v.jpg',
        duration: 5,
        createdAt: DateTime(2026).millisecondsSinceEpoch ~/ 1000,
        timestamp: DateTime(2026),
      );

      Future<void> pumpGridFor(
        WidgetTester tester, {
        required VideoEvent video,
        required String nostrClientPubkey,
        String? authServicePubkey,
      }) async {
        final mockNostr = createMockNostrService();
        when(() => mockNostr.publicKey).thenReturn(nostrClientPubkey);
        final mockAuth = createMockAuthService();
        when(() => mockAuth.currentPublicKeyHex).thenReturn(authServicePubkey);
        final signedIn = authServicePubkey != null;
        when(() => mockAuth.authState).thenReturn(
          signedIn ? AuthState.authenticated : AuthState.unauthenticated,
        );
        when(() => mockAuth.isAuthenticated).thenReturn(signedIn);

        await tester.pumpWidget(
          ProviderScope(
            overrides: _gridOverrides(
              mockTracker,
              nostrService: mockNostr,
              authService: mockAuth,
            ),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ComposableVideoGrid(
                  videos: [video],
                  onVideoTap: (videos, index) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      SemanticsNode tileNode(WidgetTester tester) {
        final l10n = lookupAppLocalizations(const Locale('en'));
        return tester.getSemantics(
          find.bySemanticsLabel(l10n.profileVideoThumbnailLabel(1)),
        );
      }

      testWidgets(
        'does not advertise a long-press action on a video the viewer '
        'does not own',
        (tester) async {
          final handle = tester.ensureSemantics();

          await pumpGridFor(
            tester,
            video: videoBy(otherPubkey),
            nostrClientPubkey: _ownPubkey,
            authServicePubkey: _ownPubkey,
          );

          expect(
            tileNode(
              tester,
            ).getSemanticsData().hasAction(SemanticsAction.longPress),
            isFalse,
            reason:
                'Advertising a long-press on a video the viewer does not own '
                'invites assistive-tech users to perform an action that '
                'silently does nothing.',
          );
          handle.dispose();
        },
      );

      testWidgets('labels the owner long-press action with the options hint', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final l10n = lookupAppLocalizations(const Locale('en'));

        await pumpGridFor(
          tester,
          video: videoBy(_ownPubkey),
          nostrClientPubkey: _ownPubkey,
          authServicePubkey: _ownPubkey,
        );

        expect(
          tileNode(
            tester,
          ).getSemanticsData().hasAction(SemanticsAction.longPress),
          isTrue,
        );
        expect(
          tileNode(tester),
          isSemantics(onLongPressHint: l10n.videoGridOptionsTitle),
          reason:
              'Without a hint, assistive tech announces that a long-press '
              'exists but cannot say what it does.',
        );
        handle.dispose();
      });

      testWidgets(
        'opens the owner sheet when the Nostr client public-key cache is '
        'still empty but the auth service knows the owner',
        (tester) async {
          final l10n = lookupAppLocalizations(const Locale('en'));

          // NostrClient.publicKey is a plain cache read that starts empty and
          // is not re-refreshed on a miss (#6813), so ownership must not
          // depend on it alone.
          await pumpGridFor(
            tester,
            video: videoBy(_ownPubkey),
            nostrClientPubkey: '',
            authServicePubkey: _ownPubkey,
          );

          await tester.longPress(
            find.bySemanticsLabel(l10n.profileVideoThumbnailLabel(1)),
          );
          await tester.pumpAndSettle();

          expect(
            find.text(l10n.videoGridDeleteVideo),
            findsOneWidget,
            reason:
                'The signed-in owner must keep the edit/delete affordance even '
                'while the Nostr client key cache is empty.',
          );
        },
      );

      testWidgets('advertises no long-press action when signed out', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();

        await pumpGridFor(
          tester,
          video: videoBy(_ownPubkey),
          // Client replacement is queued during sign-out, so the old client
          // can still expose its cached key for a rebuild. Auth state must win.
          nostrClientPubkey: _ownPubkey,
        );

        expect(
          tileNode(
            tester,
          ).getSemanticsData().hasAction(SemanticsAction.longPress),
          isFalse,
        );
        handle.dispose();
      });
    });
  });
}
