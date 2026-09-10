// ABOUTME: Tests for the unified share sheet (_UnifiedShareSheet). Covers share
// ABOUTME: sheet rendering, feature flags, save/bookmark, copy link, share via,
// ABOUTME: and quick-send behavior.

import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:bookmarks_repository/bookmarks_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/auth_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/creator_delete_enforcement_providers.dart';
import 'package:openvine/providers/video_clip_import_provider.dart';
import 'package:openvine/repositories/creator_delete_enforcement_repository.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/video_clip_import_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/widgets/video_feed_item/actions/share_action_button.dart';
import 'package:profile_repository/profile_repository.dart';

import '../helpers/test_provider_overrides.dart';

class _MockBookmarksRepository extends Mock implements BookmarksRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockVideoSharingService extends Mock implements VideoSharingService {}

class _MockContentDeletionService extends Mock
    implements ContentDeletionService {}

class _MockEnforcementRepository extends Mock
    implements CreatorDeleteEnforcementRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockVideoClipImportService extends Mock
    implements VideoClipImportService {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

class _FakeDivineVideoClip extends Fake implements DivineVideoClip {
  @override
  String? get libraryTitle => 'My local cut';
}

/// Fake notifier that provides test data for curatedListsStateProvider.
///
/// Uses a static field instead of a module-level variable so that state
/// does not leak between test files when running in a shared isolate.
class _FakeCuratedListsState extends CuratedListsState {
  static List<CuratedList> fakeLists = [];

  @override
  CuratedListService? get service => null;

  @override
  Future<List<CuratedList>> build() async => fakeLists;
}

VideoEvent _testVideo({
  String id =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  Map<String, String> rawTags = const {},
  String? vineId,
  String title = 'Test Video Title',
}) {
  return VideoEvent(
    id: id,
    pubkey: 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
    createdAt: 1757385263,
    content: 'Test video content',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
    videoUrl: 'https://example.com/video.mp4',
    title: title,
    rawTags: rawTags,
    vineId: vineId,
  );
}

void main() {
  late VideoEvent testVideo;
  late _MockBookmarksRepository mockBookmarksRepository;
  late _MockVideoSharingService mockVideoSharingService;
  late _MockProfileRepository mockProfileRepository;
  late _MockVideoClipImportService mockVideoClipImportService;

  setUpAll(() {
    registerFallbackValue(_FakeVideoEvent());
  });

  setUp(() {
    mockProfileRepository = _MockProfileRepository();
    when(
      () =>
          mockProfileRepository.getCachedProfile(pubkey: any(named: 'pubkey')),
    ).thenAnswer((_) async => null);
    when(
      () =>
          mockProfileRepository.fetchFreshProfile(pubkey: any(named: 'pubkey')),
    ).thenAnswer((_) async => null);

    testVideo = _testVideo();

    mockBookmarksRepository = _MockBookmarksRepository();
    mockVideoSharingService = _MockVideoSharingService();
    mockVideoClipImportService = _MockVideoClipImportService();
    _FakeCuratedListsState.fakeLists = [];

    when(
      () => mockVideoClipImportService.importToLibrary(
        any(),
        libraryTitle: any(named: 'libraryTitle'),
      ),
    ).thenAnswer((_) async => VideoClipImportSuccess(_FakeDivineVideoClip()));
    when(
      () => mockBookmarksRepository.isVideoBookmarkedGlobally(any()),
    ).thenReturn(false);
    when(
      () => mockBookmarksRepository.hasUnreadablePrivateItems,
    ).thenReturn(false);
    when(
      () => mockBookmarksRepository.syncGlobalBookmarks(),
    ).thenAnswer((_) async => true);
    when(
      () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(any()),
    ).thenAnswer(
      (_) async => const BookmarkToggleResult(
        succeeded: true,
        wasBookmarked: false,
        isBookmarked: true,
      ),
    );
    when(
      () => mockVideoSharingService.generateShareText(any()),
    ).thenReturn('https://divine.video/video/test');
    when(
      () => mockVideoSharingService.generateShareUrl(any()),
    ).thenReturn('https://divine.video/video/test');
    when(() => mockVideoSharingService.recentlySharedWith).thenReturn([]);
  });

  group('Unified share sheet', () {
    Widget buildSubject({
      bool curatedListsEnabled = true,
      bool debugToolsEnabled = true,
      VideoEvent? video,
      MockAuthService? mockAuthService,
      ContentDeletionService? contentDeletionService,
      CreatorDeleteEnforcementRepository? enforcementRepository,
      VideoEventService? videoEventService,
    }) => testProviderScope(
      mockAuthService: mockAuthService,
      additionalOverrides: [
        profileRepositoryProvider.overrideWithValue(mockProfileRepository),
        profileReadRepositoryProvider.overrideWithValue(mockProfileRepository),
        bookmarksRepositoryProvider.overrideWith(
          (ref) => mockBookmarksRepository,
        ),
        videoSharingServiceProvider.overrideWith(
          (ref) => mockVideoSharingService,
        ),
        if (contentDeletionService != null)
          contentDeletionServiceProvider.overrideWith(
            (ref) async => contentDeletionService,
          ),
        if (enforcementRepository != null)
          creatorDeleteEnforcementRepositoryProvider.overrideWithValue(
            enforcementRepository,
          ),
        if (videoEventService != null)
          videoEventServiceProvider.overrideWithValue(videoEventService),
        videoClipImportServiceProvider.overrideWithValue(
          mockVideoClipImportService,
        ),
        curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
        isFeatureEnabledProvider(
          FeatureFlag.curatedLists,
        ).overrideWithValue(curatedListsEnabled),
        isFeatureEnabledProvider(
          FeatureFlag.debugTools,
        ).overrideWithValue(debugToolsEnabled),
      ],
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ShareActionButton(video: video ?? testVideo)),
      ),
    );

    testWidgets('tapping share button opens unified share sheet', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      // Verify section headers
      expect(find.text('Share with'), findsOneWidget);
      expect(find.text('More actions'), findsOneWidget);
    });

    testWidgets('share sheet header shows video title', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Test Video Title'), findsOneWidget);
    });

    testWidgets('share sheet shows Find people item', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Find\npeople'), findsOneWidget);
    });

    testWidgets('More actions row shows Save action', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets(
      'More actions row keeps Save when the reconciled read omits the video',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.pumpWidget(buildSubject());
        await tester.tap(find.byType(ShareActionButton));
        await tester.pumpAndSettle();

        expect(find.text(l10n.shareSheetSave), findsOneWidget);
        expect(find.text(l10n.shareSheetRemoveFromSaved), findsNothing);
        verify(() => mockBookmarksRepository.syncGlobalBookmarks()).called(1);
        verify(
          () => mockBookmarksRepository.isVideoBookmarkedGlobally(testVideo.id),
        ).called(1);
      },
    );

    testWidgets(
      'More actions row offers Remove from saved once the reconciled read '
      'finds the video',
      (tester) async {
        when(
          () => mockBookmarksRepository.syncGlobalBookmarks(),
        ).thenAnswer((_) async => true);
        when(
          () => mockBookmarksRepository.isVideoBookmarkedGlobally(any()),
        ).thenReturn(true);
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.pumpWidget(buildSubject());
        await tester.tap(find.byType(ShareActionButton));
        await tester.pumpAndSettle();

        expect(find.text(l10n.shareSheetRemoveFromSaved), findsOneWidget);
        expect(find.text(l10n.shareSheetSave), findsNothing);
      },
    );

    testWidgets(
      'More actions row keeps Save when the reconcile is inconclusive',
      (tester) async {
        // The stale local cache says "bookmarked", but the relay read failed.
        // Believing the cache here is the #7072 mislabel, so the row must not
        // claim a saved state it could not confirm.
        when(
          () => mockBookmarksRepository.syncGlobalBookmarks(),
        ).thenAnswer((_) async => false);
        when(
          () => mockBookmarksRepository.isVideoBookmarkedGlobally(any()),
        ).thenReturn(true);
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.pumpWidget(buildSubject());
        await tester.tap(find.byType(ShareActionButton));
        await tester.pumpAndSettle();

        expect(find.text(l10n.shareSheetSave), findsOneWidget);
        expect(find.text(l10n.shareSheetRemoveFromSaved), findsNothing);
      },
    );

    testWidgets('More actions row shows Copy action', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('More actions row shows Share via action', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Share via'), findsOneWidget);
    });

    // Report was moved out of the share sheet onto the video overlay's
    // action column (ReportActionButton) — see commit 39c4f62d2 / PR #4087.
    // The corresponding share-sheet test is intentionally deleted.

    testWidgets('More actions row shows Add to clips for classic Vines', (
      tester,
    ) async {
      final classicVideo = _testVideo(
        rawTags: const {'platform': 'vine'},
        vineId: 'classic-vine-id',
      );

      await tester.pumpWidget(buildSubject(video: classicVideo));
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Add to clips'), findsOneWidget);
    });

    testWidgets(
      'More actions row hides Add to clips for non-classic, non-own videos',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.tap(find.byType(ShareActionButton));
        await tester.pumpAndSettle();

        expect(find.text('Add to clips'), findsNothing);
      },
    );

    testWidgets(
      'More actions row prompts for a clip title and confirms saved title for owned videos',
      (tester) async {
        final authService = createMockAuthService(
          authState: AuthState.authenticated,
          currentPublicKeyHex: testVideo.pubkey,
        );

        await tester.pumpWidget(buildSubject(mockAuthService: authService));
        await tester.tap(find.byType(ShareActionButton));
        await tester.pumpAndSettle();

        expect(find.text('Add to clips'), findsOneWidget);

        await tester.tap(find.text('Add to clips'));
        await tester.pumpAndSettle();

        expect(find.text('Name this clip'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller?.text,
          'Test Video Title',
        );

        await tester.enterText(find.byType(TextField), 'My local cut');
        await tester.tap(find.text('Save clip'));
        await tester.pumpAndSettle();

        expect(find.text('Saved "My local cut" to clips'), findsOneWidget);
        verify(
          () => mockVideoClipImportService.importToLibrary(
            testVideo,
            libraryTitle: 'My local cut',
          ),
        ).called(1);
      },
    );

    testWidgets('More actions row shows owner edit and delete actions', (
      tester,
    ) async {
      final authService = createMockAuthService(
        authState: AuthState.authenticated,
        currentPublicKeyHex: testVideo.pubkey,
      );

      await tester.pumpWidget(buildSubject(mockAuthService: authService));
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Edit Video'), findsOneWidget);
      expect(find.text('Delete Video'), findsOneWidget);
    });

    testWidgets('More actions row disables Edit during relay deletion', (
      tester,
    ) async {
      final authService = createMockAuthService(
        authState: AuthState.authenticated,
        currentPublicKeyHex: testVideo.pubkey,
      );
      final deletionService = _MockContentDeletionService();
      final enforcementRepository = _MockEnforcementRepository();
      final videoEventService = _MockVideoEventService();
      final relayCompleter = Completer<DeleteResult>();
      final l10n = lookupAppLocalizations(const Locale('en'));
      when(
        () => deletionService.quickDelete(
          video: testVideo,
          reason: DeleteReason.personalChoice,
        ),
      ).thenAnswer((_) => relayCompleter.future);

      await tester.pumpWidget(
        buildSubject(
          mockAuthService: authService,
          contentDeletionService: deletionService,
          enforcementRepository: enforcementRepository,
          videoEventService: videoEventService,
        ),
      );
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.shareMenuDeleteVideo));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.shareMenuDelete));
      await tester.pump();

      final editGesture = find.ancestor(
        of: find.text(l10n.shareMenuEditVideo),
        matching: find.byType(GestureDetector),
      );
      expect(tester.widget<GestureDetector>(editGesture).onTap, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      relayCompleter.complete(
        DeleteResult.failure('rejected', DeleteFailureKind.relayRejected),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<GestureDetector>(editGesture).onTap, isNotNull);
    });

    testWidgets('More actions row hides owner actions for non-owned videos', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Edit Video'), findsNothing);
      expect(find.text('Delete Video'), findsNothing);
    });

    testWidgets('tapping Add to clips shows success snackbar with clip title', (
      tester,
    ) async {
      final classicVideo = _testVideo(
        rawTags: const {'platform': 'vine'},
        vineId: 'classic-vine-id',
      );

      await tester.pumpWidget(buildSubject(video: classicVideo));
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to clips'));
      await tester.pumpAndSettle();

      expect(find.text('Name this clip'), findsOneWidget);

      await tester.tap(find.text('Save clip'));
      await tester.pumpAndSettle();

      expect(find.text('Saved "My local cut" to clips'), findsOneWidget);
      verify(
        () => mockVideoClipImportService.importToLibrary(
          classicVideo,
          libraryTitle: 'Test Video Title',
        ),
      ).called(1);
    });

    testWidgets('tapping Save shows success snackbar', (tester) async {
      when(
        () => mockBookmarksRepository.isVideoBookmarkedGlobally(any()),
      ).thenReturn(false);
      when(
        () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(any()),
      ).thenAnswer(
        (_) async => const BookmarkToggleResult(
          succeeded: true,
          wasBookmarked: false,
          isBookmarked: true,
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();
      clearInteractions(mockBookmarksRepository);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.shareAddedToBookmarks), findsOneWidget);
      verify(
        () => mockBookmarksRepository.isVideoBookmarkedGlobally(testVideo.id),
      ).called(1);
      verify(
        () =>
            mockBookmarksRepository.toggleVideoInGlobalBookmarks(testVideo.id),
      ).called(1);
    });

    testWidgets(
      'Save shows a spinner and stops accepting taps while in flight',
      (tester) async {
        // The real toggle reconciles kind 10003 with the relay, signs, then
        // waits for the publish to be accepted — 3.9s on a healthy production
        // connection. Holding the future open is the only way a test can see
        // that window; the other Save tests resolve in a microtask and the
        // handler finishes before the first rebuild.
        final gate = Completer<BookmarkToggleResult>();
        when(
          () => mockBookmarksRepository.isVideoBookmarkedGlobally(any()),
        ).thenReturn(false);
        when(
          () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(any()),
        ).thenAnswer((_) => gate.future);

        await tester.pumpWidget(buildSubject());
        await tester.tap(find.byType(ShareActionButton));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save'));
        // Never pumpAndSettle here: the spinner animates forever and the pump
        // budget runs out instead of settling.
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        final saveSemantics = tester.getSemantics(
          find
              .ancestor(of: find.text('Save'), matching: find.byType(Semantics))
              .first,
        );
        expect(
          saveSemantics.flagsCollection.isEnabled,
          equals(Tristate.isFalse),
        );

        await tester.tap(find.text('Save'));
        await tester.pump();

        gate.complete(
          const BookmarkToggleResult(
            succeeded: true,
            wasBookmarked: false,
            isBookmarked: true,
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.shareAddedToBookmarks), findsOneWidget);
        verify(
          () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(
            testVideo.id,
          ),
        ).called(1);
      },
    );

    testWidgets('tapping Save shows failure snackbar on error', (tester) async {
      when(
        () => mockBookmarksRepository.isVideoBookmarkedGlobally(any()),
      ).thenReturn(false);
      when(
        () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(any()),
      ).thenAnswer(
        (_) async => const BookmarkToggleResult(
          succeeded: false,
          wasBookmarked: false,
          isBookmarked: false,
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to add bookmark'), findsOneWidget);
    });

    testWidgets('tapping Save shows failure snackbar on exception', (
      tester,
    ) async {
      when(
        () => mockBookmarksRepository.isVideoBookmarkedGlobally(any()),
      ).thenReturn(false);
      when(
        () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(any()),
      ).thenThrow(Exception('Network error'));

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to add bookmark'), findsOneWidget);
    });

    // Both network-shaped failures share the "couldn't reach the network"
    // wording. timedOut is the one a degraded connection actually produces:
    // the read runs with requireAllRelaysSettled, so one slow relay times the
    // query out while connectedRelays is non-empty and noRelays stays false.
    for (final (name, failure) in const [
      ('couldNotReachRelays', BookmarkToggleFailure.couldNotReachRelays),
      ('timedOut', BookmarkToggleFailure.timedOut),
    ]) {
      testWidgets('tapping Save reports $name as a network failure', (
        tester,
      ) async {
        when(
          () => mockBookmarksRepository.isVideoBookmarkedGlobally(any()),
        ).thenReturn(false);
        when(
          () => mockBookmarksRepository.toggleVideoInGlobalBookmarks(any()),
        ).thenAnswer(
          (_) async => BookmarkToggleResult(
            succeeded: false,
            wasBookmarked: false,
            isBookmarked: false,
            failure: failure,
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.tap(find.byType(ShareActionButton));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.profileSetupNoRelaysConnected), findsOneWidget);
        expect(find.text(l10n.shareFailedToAddBookmark), findsNothing);
      });
    }

    testWidgets('share sheet has correct DivineIcons', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      final divineIcons = tester
          .widgetList<DivineIcon>(find.byType(DivineIcon))
          .toList();
      final iconNames = divineIcons.map((i) => i.icon).toList();

      // Share with section
      expect(iconNames, contains(DivineIconName.search));
      // More actions section
      expect(iconNames, contains(DivineIconName.bookmarkSimple));
      expect(iconNames, contains(DivineIconName.linkSimple));
      // DivineIconName.flag (Report) was removed from the share sheet when
      // Report became its own button on the video overlay action column —
      // see ReportActionButton in VideoOverlayActionColumn.
      // shareFat appears in button and Share via action
      expect(
        iconNames.where((n) => n == DivineIconName.shareFat).length,
        greaterThanOrEqualTo(1),
      );
    });

    testWidgets('does not show removed MVP items', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      // Removed in MVP streamlining
      expect(find.text('Send to Viner'), findsNothing);
      expect(find.text('Safety Actions'), findsNothing);
      expect(find.text('Public Lists'), findsNothing);
    });

    // Video lists (kind 30005) ship unflagged: the profile Lists tab and its
    // create button are ungated, so gating only the add action would leave
    // the flag able to strand lists the user can still make but not fill.
    // FeatureFlag.curatedLists now covers people lists (kind 30000) alone.
    for (final flagEnabled in [true, false]) {
      testWidgets(
        'shows Add to List with the curatedLists flag ${flagEnabled ? 'on' : 'off'}',
        (tester) async {
          final l10n = lookupAppLocalizations(const Locale('en'));

          await tester.pumpWidget(
            buildSubject(curatedListsEnabled: flagEnabled),
          );
          await tester.tap(find.byType(ShareActionButton));
          await tester.pumpAndSettle();

          expect(find.text(l10n.shareSheetAddToList), findsOneWidget);
        },
      );
    }

    testWidgets(
      'shows Event JSON and Event ID when debugTools flag is enabled',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildSubject());
        await tester.tap(find.byType(ShareActionButton));
        await tester.pumpAndSettle();

        expect(find.text('Event JSON'), findsOneWidget);
        expect(find.text('Event ID'), findsOneWidget);
      },
    );

    testWidgets(
      'hides Event JSON and Event ID when debugTools flag is disabled',
      (tester) async {
        await tester.pumpWidget(buildSubject(debugToolsEnabled: false));
        await tester.tap(find.byType(ShareActionButton));
        await tester.pumpAndSettle();

        expect(find.text('Event JSON'), findsNothing);
        expect(find.text('Event ID'), findsNothing);
      },
    );
  });

  group('Select-then-send behavior', () {
    const testContact = ShareableUser(
      pubkey:
          '1111111111111111111111111111111111111111111111111111111111111111',
      displayName: 'Alice',
    );
    late _MockFollowRepository mockFollowRepository;
    late AppLocalizations l10n;

    setUp(() {
      mockFollowRepository = _MockFollowRepository();
      when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
      l10n = lookupAppLocalizations(const Locale('en'));
    });

    Widget buildSubjectWithContacts() {
      when(
        () => mockVideoSharingService.recentlySharedWith,
      ).thenReturn([testContact]);

      return testProviderScope(
        mockFollowRepository: mockFollowRepository,
        additionalOverrides: [
          profileRepositoryProvider.overrideWithValue(mockProfileRepository),
          profileReadRepositoryProvider.overrideWithValue(
            mockProfileRepository,
          ),
          bookmarksRepositoryProvider.overrideWith(
            (ref) => mockBookmarksRepository,
          ),
          videoSharingServiceProvider.overrideWith(
            (ref) => mockVideoSharingService,
          ),
          curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
          isFeatureEnabledProvider(
            FeatureFlag.curatedLists,
          ).overrideWithValue(true),
          isFeatureEnabledProvider(
            FeatureFlag.debugTools,
          ).overrideWithValue(true),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ShareActionButton(video: testVideo)),
        ),
      );
    }

    Finder sendButton() => find.byWidgetPredicate(
      (widget) => widget is DivineIcon && widget.icon == DivineIconName.arrowUp,
    );

    testWidgets('tapping contact selects it and never sends', (tester) async {
      await tester.pumpWidget(buildSubjectWithContacts());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      // Verify contact appears in horizontal row
      expect(find.text('Alice'), findsOneWidget);

      // Tap contact — selects and reveals the message composer
      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.shareMessageHint), findsOneWidget);
      expect(find.text(l10n.shareSheetMoreActions), findsNothing);
      verifyNever(
        () => mockVideoSharingService.shareVideoWithMultipleUsers(
          video: any(named: 'video'),
          recipientPubkeys: any(named: 'recipientPubkeys'),
          personalMessage: any(named: 'personalMessage'),
        ),
      );
    });

    testWidgets('explicit send delivers to the selected contact', (
      tester,
    ) async {
      when(
        () => mockVideoSharingService.shareVideoWithMultipleUsers(
          video: any(named: 'video'),
          recipientPubkeys: any(named: 'recipientPubkeys'),
          personalMessage: any(named: 'personalMessage'),
        ),
      ).thenAnswer(
        (_) async => {
          testContact.pubkey: ShareResult.createSuccess(
            '2222222222222222222222222222222222222222222222222222222222222222',
          ),
        },
      );

      await tester.pumpWidget(buildSubjectWithContacts());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();
      await tester.tap(sendButton());
      await tester.pumpAndSettle();

      final captured = verify(
        () => mockVideoSharingService.shareVideoWithMultipleUsers(
          video: any(named: 'video'),
          recipientPubkeys: captureAny(named: 'recipientPubkeys'),
          personalMessage: any(named: 'personalMessage'),
        ),
      ).captured;
      expect(captured.single, equals([testContact.pubkey]));

      // Sheet dismissed, success snackbar shown
      expect(find.text(l10n.shareWithTitle), findsNothing);
      expect(find.text(l10n.sharePostSharedWith('Alice')), findsOneWidget);
    });

    testWidgets('tapping the selected contact again deselects it', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubjectWithContacts());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.shareMessageHint), findsOneWidget);

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.shareMessageHint), findsNothing);
      expect(find.text(l10n.shareSheetMoreActions), findsOneWidget);
      verifyNever(
        () => mockVideoSharingService.shareVideoWithMultipleUsers(
          video: any(named: 'video'),
          recipientPubkeys: any(named: 'recipientPubkeys'),
          personalMessage: any(named: 'personalMessage'),
        ),
      );
    });

    testWidgets('send shows failure snackbar on error', (tester) async {
      when(
        () => mockVideoSharingService.shareVideoWithMultipleUsers(
          video: any(named: 'video'),
          recipientPubkeys: any(named: 'recipientPubkeys'),
          personalMessage: any(named: 'personalMessage'),
        ),
      ).thenAnswer(
        (_) async => {
          testContact.pubkey: ShareResult.failure('Network timeout'),
        },
      );

      await tester.pumpWidget(buildSubjectWithContacts());
      await tester.tap(find.byType(ShareActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();
      await tester.tap(sendButton());
      await tester.pumpAndSettle();

      expect(find.text(l10n.shareFailedToSend), findsOneWidget);
      // The sheet dismisses on failure: the send is durably queued and
      // retried in the background, so there is no in-sheet manual retry.
      expect(find.text(l10n.shareWithTitle), findsNothing);
    });
  });
}
