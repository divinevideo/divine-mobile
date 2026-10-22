// ABOUTME: Widget tests for BadgeDetailScreen — which actions each viewer role
// ABOUTME: gets, and how a badge with no definition event is surfaced.

import 'dart:async';

import 'package:badge_repository/badge_repository.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/badges/badge_videos_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/screens/badges/badge_detail_screen.dart';
import 'package:openvine/screens/badges/badge_videos_screen.dart';
import 'package:openvine/screens/badges/widgets/badge_recipient_row.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/services/broken_video_tracker.dart';
import 'package:openvine/widgets/user_profile_tile.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockBadgeRepository extends Mock implements BadgeRepository {}

class _MockFunnelcakeClient extends Mock implements FunnelcakeApiClient {}

class _MockBrokenTracker extends Mock implements BrokenVideoTracker {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockBadgeVideoPager extends Mock implements BadgeVideoPager {}

void main() {
  group('BadgeDetailScreen', () {
    late _MockBadgeRepository repository;
    late _MockContentBlocklistRepository contentBlocklistRepository;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUpAll(() {
      registerFallbackValue(const BadgeCoordinate(pubkey: '', identifier: ''));
      registerFallbackValue(BadgeAwardViewData(award: _award()));
    });

    setUp(() {
      repository = _MockBadgeRepository();
      contentBlocklistRepository = _MockContentBlocklistRepository();
      when(
        () => repository.loadAcceptedHolders(any()),
      ).thenAnswer((_) async => <String>{});
    });

    /// Pumps the screen behind a real [GoRouter].
    ///
    /// The screen pops itself once a deletion lands, and `context.pop` is a
    /// GoRouter extension — a bare `MaterialApp` would throw there instead of
    /// exercising the flow.
    Widget buildSubject({
      VideosRepository? videosRepository,
      List<Override> overrides = const [],
    }) {
      final router = GoRouter(
        initialLocation: '/badges/b/badge',
        routes: [
          GoRoute(
            path: OtherProfileScreen.pathWithNpub,
            builder: (_, state) => Scaffold(
              body: Text('profile ${state.pathParameters.values.single}'),
            ),
          ),
          GoRoute(
            path: BadgeVideosScreen.path,
            builder: (_, state) {
              expect(
                state.extra,
                isA<BadgeVideosSeed>().having(
                  (seed) => seed.coordinate,
                  'coordinate',
                  _coordinate,
                ),
              );
              return Scaffold(
                body: Text(
                  'badge video destination ${state.pathParameters['naddr']}',
                ),
              );
            },
          ),
          GoRoute(
            path: '/badges',
            builder: (_, _) => const Scaffold(body: Text('badge dashboard')),
            routes: [
              GoRoute(
                path: 'b/badge',
                builder: (_, _) =>
                    const BadgeDetailScreen(coordinate: _coordinate),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      return testProviderScope(
        additionalOverrides: [
          badgeRepositoryProvider.overrideWithValue(repository),
          contentBlocklistRepositoryProvider.overrideWithValue(
            contentBlocklistRepository,
          ),
          if (videosRepository != null)
            videosRepositoryProvider.overrideWithValue(videosRepository),
          ...overrides,
        ],
        child: MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    }

    /// Scrolls the awardee list into view and opens the revoke sheet.
    ///
    /// Management rows follow the holder video feed and are built lazily.
    Future<void> tapRevoke(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.byType(BadgeRecipientRow),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(l10n.badgeDetailRevokeAction));
      await tester.pumpAndSettle();
    }

    testWidgets('offers awarding and editing to the badge owner', (
      tester,
    ) async {
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(definition: _definition(), isOwner: true),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Scene Stealer'), findsWidgets);
      expect(find.text(l10n.badgeDetailAwardAction), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(l10n.badgeDetailNoRecipients),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.badgeDetailNoRecipients), findsOneWidget);
    });

    testWidgets('offers accepting to a recipient who has not accepted', (
      tester,
    ) async {
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(
          definition: _definition(),
          isOwner: false,
          viewerAward: BadgeAwardViewData(award: _award()),
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.badgesActionAccept), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(l10n.badgeDetailBlockClaimantsAction),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.badgeDetailBlockClaimantsAction), findsOneWidget);
      expect(find.text(l10n.badgeDetailAwardAction), findsNothing);
    });

    testWidgets('offers removing to a recipient who already accepted', (
      tester,
    ) async {
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(
          definition: _definition(),
          isOwner: false,
          viewerAward: BadgeAwardViewData(award: _award(), isAccepted: true),
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.badgesActionRemove), findsOneWidget);
      expect(find.text(l10n.badgesActionAccept), findsNothing);
    });

    testWidgets('blocks badge claimants only after confirmation', (
      tester,
    ) async {
      final claimants = {_pubkey(2), _pubkey(3)};
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(definition: _definition(), isOwner: false),
      );
      when(
        () => repository.loadClaimantPubkeys(any()),
      ).thenAnswer((_) async => claimants);
      when(
        () => contentBlocklistRepository.blockUsers(any()),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.badgeDetailBlockClaimantsAction));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.badgeDetailBlockClaimantsHeading(claimants.length)),
        findsOneWidget,
      );
      expect(
        find.text(l10n.badgeDetailBlockClaimantsBody(claimants.length)),
        findsOneWidget,
      );

      await tester.tap(
        find.text(l10n.badgeDetailBlockClaimantsConfirm(claimants.length)),
      );
      await tester.pumpAndSettle();

      verify(() => repository.loadClaimantPubkeys(_coordinate)).called(1);
      verify(() => contentBlocklistRepository.blockUsers(claimants)).called(1);
      expect(find.text(l10n.badgeDetailBlockClaimantsSuccess), findsOneWidget);
    });

    testWidgets('shows an empty state when no claimants are found', (
      tester,
    ) async {
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(definition: _definition(), isOwner: false),
      );
      when(
        () => repository.loadClaimantPubkeys(any()),
      ).thenAnswer((_) async => const <String>{});

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.badgeDetailBlockClaimantsAction));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.badgeDetailBlockClaimantsEmptyTitle),
        findsOneWidget,
      );
      expect(
        find.text(l10n.badgeDetailBlockClaimantsEmptyBody),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();

      verifyNever(() => contentBlocklistRepository.blockUsers(any()));
    });

    testWidgets('offers retry when loading claimants fails', (tester) async {
      var attempts = 0;
      final claimants = {_pubkey(2)};
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(definition: _definition(), isOwner: false),
      );
      when(() => repository.loadClaimantPubkeys(any())).thenAnswer((_) async {
        attempts += 1;
        if (attempts == 1) throw Exception('relay unavailable');
        return claimants;
      });

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.badgeDetailBlockClaimantsAction));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.badgeDetailBlockClaimantsLoadError),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.commonRetry));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.badgeDetailBlockClaimantsHeading(claimants.length)),
        findsOneWidget,
      );
      verify(() => repository.loadClaimantPubkeys(_coordinate)).called(2);
    });

    testWidgets('shows a failure snackbar when blocking claimants fails', (
      tester,
    ) async {
      final claimants = {_pubkey(2)};
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(definition: _definition(), isOwner: false),
      );
      when(
        () => repository.loadClaimantPubkeys(any()),
      ).thenAnswer((_) async => claimants);
      when(
        () => contentBlocklistRepository.blockUsers(any()),
      ).thenThrow(Exception('prefs failed'));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.badgeDetailBlockClaimantsAction));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(l10n.badgeDetailBlockClaimantsConfirm(claimants.length)),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.badgeDetailBlockClaimantsFailure), findsOneWidget);
      expect(find.text(l10n.badgeDetailBlockClaimantsTitle), findsOneWidget);
    });

    testWidgets('deletes only after the owner confirms', (tester) async {
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(definition: _definition(), isOwner: true),
      );
      when(() => repository.deleteBadge(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel(l10n.badgeDetailDeleteAction));
      await tester.pumpAndSettle();

      expect(find.text(l10n.badgeDetailDeleteTitle), findsOneWidget);
      expect(find.text(l10n.badgeDetailDeleteBody), findsOneWidget);

      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();
      verifyNever(() => repository.deleteBadge(any()));

      await tester.tap(find.bySemanticsLabel(l10n.badgeDetailDeleteAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.badgeDetailDeleteConfirm));
      await tester.pumpAndSettle();

      verify(() => repository.deleteBadge(_coordinate)).called(1);
    });

    testWidgets('tells the owner when a relay refuses the deletion', (
      tester,
    ) async {
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(definition: _definition(), isOwner: true),
      );
      when(() => repository.deleteBadge(any())).thenThrow(
        const BadgePublishException(
          'rejected',
          eventKind: EventKind.eventDeletion,
          outcome: PublishOutcome(
            eventId: 'deadbeef',
            acceptedBy: [],
            rejectedBy: {'wss://relay.divine.video': 'delete not authorized'},
            noResponseFrom: [],
          ),
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel(l10n.badgeDetailDeleteAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.badgeDetailDeleteConfirm));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.shareMenuDeleteFailedRelayRejected),
        findsOneWidget,
      );
      // The badge is still there, so the page must not have popped.
      expect(find.text('Scene Stealer'), findsWidgets);
    });

    testWidgets('revokes a recipient only after the owner confirms', (
      tester,
    ) async {
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(
          definition: _definition(),
          isOwner: true,
          recipients: [_recipient()],
        ),
      );
      when(
        () => repository.revokeAward(
          coordinate: any(named: 'coordinate'),
          recipientPubkey: any(named: 'recipientPubkey'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tapRevoke(tester);

      expect(find.text(l10n.badgeDetailRevokeTitle), findsOneWidget);
      expect(find.text(l10n.badgeDetailRevokeBody), findsOneWidget);
      // Someone else's pin is their event, so the copy only promises to ask.
      expect(find.text(l10n.badgeDetailRevokeSelfBody), findsNothing);
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();
      verifyNever(
        () => repository.revokeAward(
          coordinate: any(named: 'coordinate'),
          recipientPubkey: any(named: 'recipientPubkey'),
        ),
      );

      await tapRevoke(tester);
      await tester.tap(find.text(l10n.badgeDetailRevokeConfirm));
      await tester.pumpAndSettle();

      verify(
        () => repository.revokeAward(
          coordinate: _coordinate,
          recipientPubkey: _pubkey(2),
        ),
      ).called(1);
      expect(find.text(l10n.badgeDetailRevokeSuccess), findsOneWidget);
    });

    testWidgets('promises to unpin only when you revoke yourself', (
      tester,
    ) async {
      // The general copy says the badge stays until the recipient takes it
      // down. For your own pin that undersells it — the revoke removes it.
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(
          definition: _definition(),
          isOwner: true,
          recipients: [_recipient(isViewer: true)],
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tapRevoke(tester);

      expect(find.text(l10n.badgeDetailRevokeSelfBody), findsOneWidget);
      expect(find.text(l10n.badgeDetailRevokeBody), findsNothing);
    });

    testWidgets('tells the owner when a relay refuses the revoke', (
      tester,
    ) async {
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(
          definition: _definition(),
          isOwner: true,
          recipients: [_recipient()],
        ),
      );
      when(
        () => repository.revokeAward(
          coordinate: any(named: 'coordinate'),
          recipientPubkey: any(named: 'recipientPubkey'),
        ),
      ).thenThrow(
        const BadgePublishException(
          'rejected',
          eventKind: EventKind.eventDeletion,
          outcome: PublishOutcome(
            eventId: 'deadbeef',
            acceptedBy: [],
            rejectedBy: {'wss://relay.divine.video': 'delete not authorized'},
            noResponseFrom: [],
          ),
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tapRevoke(tester);
      await tester.tap(find.text(l10n.badgeDetailRevokeConfirm));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.shareMenuDeleteFailedRelayRejected),
        findsOneWidget,
      );
    });

    testWidgets('hides the revoke action from non-owners', (tester) async {
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(
          definition: _definition(),
          isOwner: false,
          recipients: [_recipient()],
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(find.byType(BadgeRecipientRow), findsNothing);
      expect(find.bySemanticsLabel(l10n.badgeDetailRevokeAction), findsNothing);
    });

    testWidgets('hides the delete action from non-owners', (tester) async {
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(definition: _definition(), isOwner: false),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(l10n.badgeDetailDeleteAction), findsNothing);
    });

    testWidgets('says so when no definition event could be found', (
      tester,
    ) async {
      when(
        () => repository.loadBadgeDetail(any()),
      ).thenAnswer((_) async => _detail(isOwner: false));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.badgeDetailMissing), findsOneWidget);
    });

    testWidgets('lists accepted holders with a holder tile', (
      tester,
    ) async {
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(definition: _definition(), isOwner: false),
      );
      when(
        () => repository.loadAcceptedHolders(any()),
      ).thenAnswer((_) async => {_pubkey(3)});

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is UserProfileTile && widget.pubkey == _pubkey(3),
        ),
        findsOneWidget,
      );
    });

    testWidgets('holder taps open the complete profile route', (tester) async {
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(definition: _definition(), isOwner: false),
      );
      when(() => repository.loadAcceptedHolders(any()))
          .thenAnswer((_) async => {_pubkey(3)});
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      final tile = find.byWidgetPredicate(
        (widget) => widget is UserProfileTile && widget.pubkey == _pubkey(3),
      );
      tester.widget<UserProfileTile>(tile).onTap!();
      await tester.pumpAndSettle();
      expect(
        find.text('profile ${Nip19.encodePubKey(_pubkey(3))}'),
        findsOneWidget,
      );
    });

    testWidgets('collapses holders to six until Show more', (tester) async {
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(definition: _definition(), isOwner: false),
      );
      when(() => repository.loadAcceptedHolders(any()))
          .thenAnswer((_) async => {for (var i = 3; i < 11; i++) _pubkey(i)});
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      final tile = find.byWidgetPredicate(
        (widget) => widget is UserProfileTile && widget.pubkey == _pubkey(3),
      );
      final list = tester.widget<SliverList>(
        find.ancestor(of: tile, matching: find.byType(SliverList)).first,
      );
      expect(list.delegate.estimatedChildCount, 6);
      await tester.scrollUntilVisible(
        find.text(l10n.profileShowMore),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.profileShowMore));
      await tester.pumpAndSettle();
      expect(find.text(l10n.profileShowMore), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SliverList && widget.delegate.estimatedChildCount == 8,
        ),
        findsOneWidget,
      );
    });

    testWidgets('indexed preview starts videos before relay holders finish', (
      tester,
    ) async {
      final holders = Completer<Set<String>>();
      final client = _MockFunnelcakeClient();
      final videos = _MockVideosRepository();
      final pager = _MockBadgeVideoPager();
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(definition: _definition(), isOwner: false),
      );
      when(() => repository.loadAcceptedHolders(any()))
          .thenAnswer((_) => holders.future);
      when(() => repository.withoutHiddenPubkeys(any()))
          .thenReturn([_pubkey(3)]);
      when(
        () => client.getBadgeHolderPreview(
          creatorPubkey: any(named: 'creatorPubkey'),
          dTag: any(named: 'dTag'),
        ),
      ).thenAnswer((_) async => [_pubkey(3)]);
      when(() => videos.createBadgeVideoPager(any())).thenReturn(pager);
      when(pager.loadMore).thenAnswer((_) async => [_video()]);
      when(() => pager.hasMore).thenReturn(false);
      await tester.pumpWidget(
        buildSubject(
          videosRepository: videos,
          overrides: [funnelcakeApiClientProvider.overrideWithValue(client)],
        ),
      );
      await tester.pump();
      await tester.pump();
      verify(() => videos.createBadgeVideoPager({_pubkey(3)})).called(1);
      holders.complete({_pubkey(3)});
      await tester.pumpAndSettle();
    });

    testWidgets('inline holder grid excludes broken videos', (tester) async {
      final videos = _MockVideosRepository();
      final pager = _MockBadgeVideoPager();
      final tracker = _MockBrokenTracker();
      when(() => tracker.isVideoBroken(any())).thenReturn(true);
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(definition: _definition(), isOwner: false),
      );
      when(() => repository.loadAcceptedHolders(any()))
          .thenAnswer((_) async => {_pubkey(3)});
      when(() => videos.createBadgeVideoPager(any())).thenReturn(pager);
      when(pager.loadMore).thenAnswer((_) async => [_video()]);
      when(() => pager.hasMore).thenReturn(false);
      await tester.pumpWidget(
        buildSubject(
          videosRepository: videos,
          overrides: [
            brokenVideoTrackerProvider.overrideWith((_) async => tracker),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(l10n.exploreNoVideosAvailable),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(VideoThumbnailWidget), findsNothing);
      expect(find.text(l10n.exploreNoVideosAvailable), findsOneWidget);
    });

    testWidgets('labels each holder video for screen readers', (
      tester,
    ) async {
      final videosRepository = _MockVideosRepository();
      final pager = _MockBadgeVideoPager();
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(definition: _definition(), isOwner: false),
      );
      when(
        () => repository.loadAcceptedHolders(any()),
      ).thenAnswer((_) async => {_pubkey(3)});
      when(
        () => videosRepository.createBadgeVideoPager(any()),
      ).thenReturn(pager);
      when(pager.loadMore).thenAnswer((_) async => [_video()]);
      when(() => pager.hasMore).thenReturn(false);

      await tester.pumpWidget(buildSubject(videosRepository: videosRepository));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.bySemanticsLabel(l10n.profileVideoThumbnailLabel(1)),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        find.bySemanticsLabel(l10n.profileVideoThumbnailLabel(1)),
        findsOneWidget,
      );
    });

    testWidgets('shows inline retry feedback only for new page failures', (
      tester,
    ) async {
      final videos = _MockVideosRepository();
      final pager = _MockBadgeVideoPager();
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(definition: _definition(), isOwner: false),
      );
      when(() => repository.loadAcceptedHolders(any()))
          .thenAnswer((_) async => {_pubkey(3)});
      when(() => videos.createBadgeVideoPager(any())).thenReturn(pager);
      var pages = 0;
      when(pager.loadMore).thenAnswer((_) async {
        if ((pages++).isEven) return [_video()];
        throw Exception('controlled page failure');
      });
      when(() => pager.hasMore).thenReturn(true);
      await tester.pumpWidget(buildSubject(videosRepository: videos));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(l10n.profileShowMore),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.profileShowMore));
      await tester.pumpAndSettle();
      expect(find.text(l10n.feedFailedToLoadVideos), findsOneWidget);
      final gridContext = tester.element(find.byType(VideoThumbnailWidget));
      final cubit = gridContext.read<BadgeVideosCubit>();
      expect(cubit.state.loadMoreFailures, 1);
      ScaffoldMessenger.of(gridContext).clearSnackBars();
      await tester.pumpAndSettle();
      expect(find.text(l10n.feedFailedToLoadVideos), findsNothing);

      await cubit.loadForHolders({_pubkey(3), _pubkey(4)});
      await tester.pumpAndSettle();
      expect(cubit.state.loadMoreFailures, 0);
      expect(find.text(l10n.feedFailedToLoadVideos), findsNothing);

      await tester.tap(find.text(l10n.profileShowMore));
      await tester.pumpAndSettle();
      expect(cubit.state.loadMoreFailures, 1);
      expect(find.text(l10n.feedFailedToLoadVideos), findsOneWidget);
      expect(
        find.bySemanticsLabel(l10n.profileVideoThumbnailLabel(1)),
        findsOneWidget,
      );
    });

    testWidgets('reloads holder videos when the videos repository is rebuilt', (
      tester,
    ) async {
      final first = _MockVideosRepository();
      final second = _MockVideosRepository();
      final firstPager = _MockBadgeVideoPager();
      final secondPager = _MockBadgeVideoPager();
      final activeRepository = StateProvider<VideosRepository>((_) => first);
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(definition: _definition(), isOwner: false),
      );
      when(
        () => repository.loadAcceptedHolders(any()),
      ).thenAnswer((_) async => {_pubkey(3)});
      when(() => first.createBadgeVideoPager(any())).thenReturn(firstPager);
      when(firstPager.loadMore).thenAnswer((_) async => []);
      when(() => firstPager.hasMore).thenReturn(false);
      when(() => second.createBadgeVideoPager(any())).thenReturn(secondPager);
      when(secondPager.loadMore).thenAnswer((_) async => [_video()]);
      when(() => secondPager.hasMore).thenReturn(false);

      await tester.pumpWidget(
        buildSubject(
          overrides: [
            videosRepositoryProvider.overrideWith(
              (ref) => ref.watch(activeRepository),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      ProviderScope.containerOf(
        tester.element(find.byType(BadgeDetailScreen)),
      ).read(activeRepository.notifier).state = second;
      await tester.pumpAndSettle();

      verify(() => first.createBadgeVideoPager({_pubkey(3)})).called(1);
      verify(() => second.createBadgeVideoPager({_pubkey(3)})).called(1);
      await tester.scrollUntilVisible(
        find.bySemanticsLabel(l10n.profileVideoThumbnailLabel(1)),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.bySemanticsLabel(l10n.profileVideoThumbnailLabel(1)),
        findsOneWidget,
      );
    });

    testWidgets('reloads visible holders and videos after a block', (
      tester,
    ) async {
      final videos = _MockVideosRepository();
      final pager = _MockBadgeVideoPager();
      var blocked = false;
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(definition: _definition(), isOwner: false),
      );
      when(() => repository.loadAcceptedHolders(any()))
          .thenAnswer((_) async => blocked ? <String>{} : {_pubkey(3)});
      when(() => videos.createBadgeVideoPager(any())).thenReturn(pager);
      when(pager.loadMore).thenAnswer((_) async => [_video()]);
      when(() => pager.hasMore).thenReturn(false);
      await tester.pumpWidget(buildSubject(videosRepository: videos));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(VideoThumbnailWidget),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(VideoThumbnailWidget), findsOneWidget);
      blocked = true;
      ProviderScope.containerOf(tester.element(find.byType(BadgeDetailScreen)))
          .read(blocklistVersionProvider.notifier)
          .increment();
      await tester.pumpAndSettle();
      verify(() => repository.loadAcceptedHolders(any())).called(2);
      expect(find.byType(VideoThumbnailWidget), findsNothing);
    });

    testWidgets(
      'pending subscription read shows Loading without guessing membership',
      (tester) async {
        final subscriptions = Completer<Set<BadgeCoordinate>>();
        when(() => repository.loadBadgeDetail(any())).thenAnswer(
          (_) async => _detail(definition: _definition(), isOwner: false),
        );
        when(() => repository.loadSubscriptions(requireComplete: true))
            .thenAnswer((_) => subscriptions.future);
        await tester.pumpWidget(
          buildSubject(
            overrides: [
              authServiceProvider.overrideWithValue(
                createMockAuthService(currentPublicKeyHex: _pubkey(1)),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(l10n.commonLoading),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.commonLoading), findsOneWidget);
        expect(find.text(l10n.badgeSubscribeAction), findsNothing);
        expect(find.text(l10n.badgeSubscribedAction), findsNothing);
        subscriptions.complete({_coordinate});
        await tester.pumpAndSettle();
        expect(find.text(l10n.badgeSubscribedAction), findsOneWidget);
      },
    );

    testWidgets(
      'subscription retry preserves loaded holder videos and shows precise copy',
      (tester) async {
        final videos = _MockVideosRepository();
        final pager = _MockBadgeVideoPager();
        var reads = 0;
        when(() => repository.loadBadgeDetail(any())).thenAnswer(
          (_) async => _detail(definition: _definition(), isOwner: false),
        );
        when(() => repository.loadAcceptedHolders(any()))
            .thenAnswer((_) async => {_pubkey(3)});
        when(() => repository.loadSubscriptions(requireComplete: true))
            .thenAnswer((_) async {
              if (reads++ == 0) {
                throw const BadgeReadIncompleteException('subscription read');
              }
              return {_coordinate};
            });
        when(() => videos.createBadgeVideoPager(any())).thenReturn(pager);
        when(pager.loadMore).thenAnswer((_) async => [_video()]);
        when(() => pager.hasMore).thenReturn(false);
        await tester.pumpWidget(
          buildSubject(
            videosRepository: videos,
            overrides: [
              authServiceProvider.overrideWithValue(
                createMockAuthService(currentPublicKeyHex: _pubkey(1)),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(l10n.badgeSubscriptionLoadError),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.commonRetry));
        await tester.pumpAndSettle();
        expect(find.text(l10n.badgeSubscribedAction), findsOneWidget);
        verify(() => repository.loadAcceptedHolders(any())).called(1);
        verify(() => videos.createBadgeVideoPager(any())).called(1);
      },
    );

    for (final saveFails in [false, true]) {
      testWidgets(
        'subscription reads and saves preserve the loaded video pager, save failure $saveFails',
        (
          tester,
        ) async {
          final subscriptions = Completer<Set<BadgeCoordinate>>();
          final videos = _MockVideosRepository();
          final pager = _MockBadgeVideoPager();
          when(() => repository.loadBadgeDetail(any())).thenAnswer(
            (_) async => _detail(definition: _definition(), isOwner: false),
          );
          when(() => repository.loadAcceptedHolders(any()))
              .thenAnswer((_) async => {_pubkey(3)});
          when(() => repository.loadSubscriptions(requireComplete: true))
              .thenAnswer((_) => subscriptions.future);
          when(() => repository.setSubscription(_coordinate, subscribed: true))
              .thenAnswer((_) async {
                if (saveFails) {
                  throw const BadgeReadIncompleteException('save refused');
                }
                return {_coordinate};
              });
          when(() => videos.createBadgeVideoPager(any())).thenReturn(pager);
          when(pager.loadMore).thenAnswer((_) async => [_video()]);
          when(() => pager.hasMore).thenReturn(false);
          await tester.pumpWidget(
            buildSubject(
              videosRepository: videos,
              overrides: [
                authServiceProvider.overrideWithValue(
                  createMockAuthService(currentPublicKeyHex: _pubkey(1)),
                ),
              ],
            ),
          );
          await tester.pump();
          await tester.pump();
          expect(find.text(l10n.badgeSubscribeAction), findsNothing);
          subscriptions.complete({});
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text(l10n.badgeSubscribeAction),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.badgeSubscribeAction));
          await tester.pumpAndSettle();
          expect(
            find.text(
              saveFails ? l10n.badgesUpdateError : l10n.badgeSubscribedAction,
            ),
            findsOneWidget,
          );
          verify(() => videos.createBadgeVideoPager(any())).called(1);
        },
      );
    }

    testWidgets('opens the badge video page from the detail header', (
      tester,
    ) async {
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(definition: _definition(), isOwner: false),
      );
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(l10n.profileVideosLabel),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.profileVideosLabel));
      await tester.pumpAndSettle();
      expect(
        find.text('badge video destination ${_coordinate.toNaddr()}'),
        findsOneWidget,
      );
    });

    testWidgets('discloses public subscriptions beside the subscribe action', (
      tester,
    ) async {
      when(() => repository.loadBadgeDetail(any())).thenAnswer(
        (_) async => _detail(definition: _definition(), isOwner: false),
      );
      when(() => repository.loadSubscriptions(requireComplete: true))
          .thenAnswer(
            (_) async => <BadgeCoordinate>{},
          );
      await tester.pumpWidget(
        buildSubject(
          overrides: [
            authServiceProvider.overrideWithValue(
              createMockAuthService(currentPublicKeyHex: _pubkey(1)),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(l10n.badgeSubscribeAction),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.badgeSubscriptionsPublicNotice), findsOneWidget);
    });

    testWidgets('offers a retry when the lookup fails', (tester) async {
      when(
        () => repository.loadBadgeDetail(any()),
      ).thenThrow(Exception('relay unavailable'));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.badgeDetailLoadError), findsOneWidget);
      expect(find.text(l10n.commonRetry), findsOneWidget);
    });
  });
}

const _coordinate = BadgeCoordinate(
  pubkey: '0000000000000000000000000000000000000000000000000000000000000065',
  identifier: 'scene-stealer',
);

BadgeDetailData _detail({
  required bool isOwner,
  Nip58BadgeDefinition? definition,
  BadgeAwardViewData? viewerAward,
  List<BadgeRecipientViewData> recipients = const [],
}) {
  return BadgeDetailData(
    coordinate: _coordinate,
    definition: definition,
    recipients: recipients,
    isOwner: isOwner,
    viewerAward: viewerAward,
  );
}

BadgeRecipientViewData _recipient({bool isViewer = false}) {
  return BadgeRecipientViewData(
    pubkey: _pubkey(2),
    awardEventId: '2'.padLeft(64, '0'),
    isAccepted: true,
    isViewer: isViewer,
  );
}

Nip58BadgeDefinition _definition() {
  return Nip58BadgeDefinition(
    event: _event(kind: EventKind.badgeDefinition),
    coordinate: _coordinate.value,
    dTag: _coordinate.identifier,
    name: 'Scene Stealer',
  );
}

Nip58BadgeAward _award() {
  return Nip58BadgeAward(
    event: _event(kind: EventKind.badgeAward),
    definitionCoordinate: _coordinate.value,
    recipientPubkeys: [_pubkey(2)],
  );
}

Event _event({required int kind}) {
  return Event.fromJson({
    'id': '1'.padLeft(64, '0'),
    'pubkey': _pubkey(1),
    'created_at': 1000,
    'kind': kind,
    'tags': <List<String>>[],
    'content': '',
    'sig': '',
  });
}

String _pubkey(int seed) => (seed + 100).toRadixString(16).padLeft(64, '0');

VideoEvent _video() => VideoEvent(
  id: 'a'.padLeft(64, '0'),
  pubkey: _pubkey(3),
  createdAt: 1000,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1000 * 1000),
  videoUrl: 'https://example.com/a.mp4',
);
