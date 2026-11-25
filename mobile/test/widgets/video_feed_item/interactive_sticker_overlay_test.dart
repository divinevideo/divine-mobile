// ABOUTME: Tests a question, Add yours or replies sticker on a playing video:
// ABOUTME: it reads only on the active video and opens what its buttons open.

import 'dart:async';

import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart' show LatestAddressableEvents;
import 'package:nostr_sdk/nostr_sdk.dart' show Event;
import 'package:openvine/blocs/sticker_responses/sticker_responses_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/add_yours_context.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/providers/add_yours_context_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/feed_repository_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/sticker_responses_filter_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/video_replies/video_replies_screen.dart';
import 'package:openvine/widgets/video_editor/social_sticker/interactive_sticker_card.dart';
import 'package:openvine/widgets/video_feed_item/interactive_sticker_overlay.dart';
import 'package:video_responses_repository/video_responses_repository.dart';

class _MockVideoResponsesRepository extends Mock
    implements VideoResponsesRepository {}

class _MockFeedRepository extends Mock implements FeedRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _Session extends NostrSession {
  _Session(this._readiness);

  final NostrSessionReadiness _readiness;

  @override
  NostrSessionReadiness build() => _readiness;
}

final String _creator = 'a' * 64;
final String _viewer = 'b' * 64;

VideoStickerRegion _region(VideoStickerKind kind, String label) =>
    VideoStickerRegion(
      kind: kind,
      target: '',
      centerX: 0.5,
      centerY: 0.5,
      width: 0.8,
      height: 0.5,
      style: 'light',
      label: label,
    );

final VideoEvent _video = VideoEvent(
  id: 'd' * 64,
  pubkey: _creator,
  createdAt: 1778120201,
  content: '',
  timestamp: DateTime.utc(2026),
  vineId: 'root-d',
  addressableDTag: 'root-d',
);

VideoEvent _reply(int n) => VideoEvent(
  id: '$n'.padLeft(64, '0'),
  pubkey: '$n'.padLeft(64, 'f'),
  createdAt: 1778120201 + n,
  content: '',
  timestamp: DateTime.utc(2026),
);

void main() {
  setUpAll(() => registerFallbackValue(const RepliesCuration()));

  group(InteractiveStickerOverlay, () {
    late _MockVideoResponsesRepository repository;
    late _MockFollowRepository followRepository;
    late StickerResponsesFilter filter;
    late List<String> pushed;
    late List<Object?> extras;
    late int interactions;
    late AddYoursContext? addYoursWhileOpen;
    late Map<String, UserProfile> profiles;
    late bool isDmRestricted;

    setUp(() {
      profiles = {};
      isDmRestricted = false;
      repository = _MockVideoResponsesRepository();
      followRepository = _MockFollowRepository();
      filter = (videos) => videos;
      pushed = [];
      extras = [];
      interactions = 0;
      addYoursWhileOpen = null;
      when(
        () => repository.fetchReplies(
          videoId: any(named: 'videoId'),
          videoAddress: any(named: 'videoAddress'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => VideoResponses(total: 2, videos: [_reply(1), _reply(2)]),
      );
      when(
        () => repository.fetchCuration(
          creatorPubkey: any(named: 'creatorPubkey'),
          videoAddress: any(named: 'videoAddress'),
        ),
      ).thenAnswer((_) async => const RepliesCuration());
      when(
        () => repository.fetchJoined(
          chainRoot: any(named: 'chainRoot'),
          hashtag: any(named: 'hashtag'),
          limit: any(named: 'limit'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer(
        (_) async => VideoResponses(total: 12, videos: [_reply(3)]),
      );
    });

    /// Pumps the sticker, and returns whether its video is the one playing,
    /// which a test may change afterwards.
    Future<ValueNotifier<bool>> pump(
      WidgetTester tester,
      VideoStickerRegion region, {
      bool isActive = true,
      String? viewer = 'viewer',
      VideoEvent? on,
      bool manageReplies = false,
      LatestAddressableEvents? latestEvents,
    }) async {
      final pubkey = viewer == 'viewer' ? _viewer : viewer;
      final active = ValueNotifier(isActive);
      addTearDown(active.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  height: 240,
                  child: ValueListenableBuilder(
                    valueListenable: active,
                    builder: (_, isActive, _) => InteractiveStickerOverlay(
                      region: region,
                      video: on ?? _video,
                      data: SocialStickerData.ofRegion(region)!,
                      isActive: isActive,
                      onInteraction: () => interactions++,
                    ),
                  ),
                ),
              ),
            ),
            routes: [
              if (manageReplies)
                GoRoute(
                  path: 'video-replies/:videoId',
                  builder: (_, state) => VideoRepliesScreen(
                    videoId: state.pathParameters['videoId']!,
                    videoAddress: state.uri.queryParameters['address']!,
                  ),
                ),
              GoRoute(
                path: ':first',
                builder: (_, state) => _Pushed(
                  state: state,
                  onShown: (location, container) {
                    pushed.add(location);
                    extras.add(state.extra);
                    addYoursWhileOpen = container.read(addYoursContextProvider);
                  },
                ),
                routes: [
                  GoRoute(
                    path: ':second',
                    builder: (_, state) => _Pushed(
                      state: state,
                      onShown: (location, _) => pushed.add(location),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoResponsesRepositoryProvider.overrideWithValue(repository),
            if (latestEvents != null)
              latestAddressableEventsProvider.overrideWithValue(latestEvents),
            if (manageReplies) ...[
              repliesWarningsProvider.overrideWithValue((videos) => videos),
              repliesHiddenBySettingsProvider.overrideWithValue((_) => false),
            ],
            followRepositoryProvider.overrideWithValue(followRepository),
            stickerResponsesFilterProvider.overrideWithValue(
              (videos) => filter(videos),
            ),
            feedRepositoryProvider.overrideWithValue(_MockFeedRepository()),
            isDmRestrictedProvider.overrideWithValue(isDmRestricted),
            // Read for the avatar of a response that came without one.
            for (final n in [1, 2, 3])
              fetchUserProfileProvider(
                _reply(n).pubkey,
              ).overrideWith((ref) async => profiles[_reply(n).pubkey]),
            nostrSessionProvider.overrideWith(
              () => _Session(
                pubkey == null
                    ? const NostrSessionReadiness.signedOut()
                    : NostrSessionReadiness.identityKnown(pubkey: pubkey),
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      return active;
    }

    final question = _region(VideoStickerKind.question, 'Ask me anything');
    final replies = _region(VideoStickerKind.replies, 'Reply with a video');
    final addYours = _region(
      VideoStickerKind.prompt,
      'Show your desk\ndesksetup',
    );

    AppLocalizations l10n(WidgetTester tester) =>
        AppLocalizations.of(tester.element(find.byType(Scaffold).first));

    group('renders', () {
      testWidgets('reads who replied on a video the feed only loads ahead, '
          'so they are in when the viewer swipes to it', (tester) async {
        await pump(tester, replies, isActive: false);
        await tester.pump();

        expect(find.text('Reply with a video'), findsOneWidget);
        expect(
          find.text(l10n(tester).videoStickerRepliesCount(2)),
          findsOneWidget,
        );
      });

      testWidgets('keeps who replied, without reading them again, while the '
          'video is not the one playing, as under the comments', (
        tester,
      ) async {
        final active = await pump(tester, replies);
        await tester.pump();

        active.value = false;
        await tester.pump();

        expect(
          find.text(l10n(tester).videoStickerRepliesCount(2)),
          findsOneWidget,
        );

        active.value = true;
        await tester.pump();

        expect(
          find.text(l10n(tester).videoStickerRepliesCount(2)),
          findsOneWidget,
        );
        verify(
          () => repository.fetchReplies(
            videoId: any(named: 'videoId'),
            videoAddress: any(named: 'videoAddress'),
            limit: any(named: 'limit'),
          ),
        ).called(1);
      });

      testWidgets('keeps the remaining previews while applying a hide from '
          'comments', (tester) async {
        final events = LatestAddressableEvents();
        addTearDown(events.dispose);
        final secondRead = Completer<VideoResponses>();
        final reply = _reply(2)
            .copyWith(authorAvatar: 'https://cdn.example/2.jpg');
        var reads = 0;
        when(
          () => repository.fetchReplies(
            videoId: _video.id,
            videoAddress: _video.addressableId,
            limit: StickerResponsesCubit.feedLimit,
          ),
        ).thenAnswer((_) async {
          if (reads++ > 0) return secondRead.future;
          return VideoResponses(total: 2, videos: [_reply(1), reply]);
        });
        final active = await pump(tester, replies, latestEvents: events);
        await tester.pumpAndSettle();
        final strings = l10n(tester);
        expect(find.text(strings.videoStickerRepliesCount(2)), findsOneWidget);

        active.value = false;
        await tester.pump();

        // The comments writer records an accepted edit in the shared store.
        events.remember(
          Event(
            _creator,
            RepliesCuration.kind,
            RepliesCuration(hiddenIds: {_reply(1).id})
                .toTags(_video.addressableId!),
            '',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(strings.videoStickerRepliesCount(1)), findsOneWidget);
        expect(find.text(strings.videoStickerRepliesCount(2)), findsNothing);
        final latest = tester
            .widget<InteractiveStickerCopy>(find.byType(InteractiveStickerCopy))
            .responses!
            .latest;
        expect(latest.single.avatarUrl, 'https://cdn.example/2.jpg');
        expect(reads, 1);
      });

      testWidgets('applies newer hides while an older pin is still being '
          'read', (tester) async {
        final events = LatestAddressableEvents();
        addTearDown(events.dispose);
        final pin = Completer<VideoEvent?>();
        final pinned = _reply(9)
            .copyWith(authorAvatar: 'https://cdn.example/9.jpg');
        when(
          () => repository.fetchReplies(
            videoId: _video.id,
            videoAddress: _video.addressableId,
            limit: StickerResponsesCubit.feedLimit,
          ),
        ).thenAnswer(
          (_) async => VideoResponses(total: 3, videos: [_reply(1), _reply(2)]),
        );
        when(
          () => repository.fetchReply(
            pinned.id,
            videoId: _video.id,
            videoAddress: _video.addressableId,
          ),
        ).thenAnswer((_) => pin.future);
        await pump(tester, replies, latestEvents: events);
        await tester.pumpAndSettle();
        final strings = l10n(tester);
        expect(find.text(strings.videoStickerRepliesCount(3)), findsOneWidget);

        void remember(RepliesCuration curation, int revision) =>
            events.remember(
              Event(
                _creator,
                RepliesCuration.kind,
                curation.toTags(_video.addressableId!),
                '',
                createdAt: revision,
              ),
            );

        remember(
          RepliesCuration(pinnedId: pinned.id, hiddenIds: {_reply(1).id}),
          1,
        );
        await tester.pumpAndSettle();
        expect(find.text(strings.videoStickerRepliesCount(2)), findsOneWidget);

        remember(RepliesCuration(hiddenIds: {_reply(1).id, _reply(2).id}), 2);
        await tester.pumpAndSettle();
        expect(find.text(strings.videoStickerRepliesCount(1)), findsOneWidget);
        expect(find.text(strings.videoStickerRepliesCount(2)), findsNothing);

        pin.complete(pinned);
        await tester.pumpAndSettle();
        expect(find.text(strings.videoStickerRepliesCount(1)), findsOneWidget);
        final latest = tester
            .widget<InteractiveStickerCopy>(find.byType(InteractiveStickerCopy))
            .responses!
            .latest;
        expect(latest, isEmpty);

        // Pinning the same older reply again can reuse the completed read.
        remember(
          RepliesCuration(
            pinnedId: pinned.id,
            hiddenIds: {_reply(1).id, _reply(2).id},
          ),
          3,
        );
        await tester.pumpAndSettle();
        final repinned = tester
            .widget<InteractiveStickerCopy>(find.byType(InteractiveStickerCopy))
            .responses!
            .latest;
        expect(repinned.single.avatarUrl, 'https://cdn.example/9.jpg');
        verify(
          () => repository.fetchReply(
            pinned.id,
            videoId: _video.id,
            videoAddress: _video.addressableId,
          ),
        ).called(1);
      });

      testWidgets('uses the latest hides when they change during the initial '
          'pin read', (tester) async {
        final events = LatestAddressableEvents();
        addTearDown(events.dispose);
        final pin = Completer<VideoEvent?>();
        final pinned = _reply(9)
            .copyWith(authorAvatar: 'https://cdn.example/9.jpg');
        when(
          () => repository.fetchCuration(
            creatorPubkey: _creator,
            videoAddress: _video.addressableId!,
          ),
        ).thenAnswer((_) async => RepliesCuration(pinnedId: pinned.id));
        when(
          () => repository.fetchReply(
            pinned.id,
            videoId: _video.id,
            videoAddress: _video.addressableId,
          ),
        ).thenAnswer((_) => pin.future);
        await pump(tester, replies, latestEvents: events);
        await tester.pumpAndSettle();
        verify(
          () => repository.fetchReply(
            pinned.id,
            videoId: _video.id,
            videoAddress: _video.addressableId,
          ),
        ).called(1);
        final strings = l10n(tester);
        events.remember(
          Event(
            _creator,
            RepliesCuration.kind,
            RepliesCuration(hiddenIds: {_reply(1).id})
                .toTags(_video.addressableId!),
            '',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(strings.videoStickerRepliesCount(1)), findsOneWidget);

        pin.completeError(StateError('The old pin could not be read'));
        await tester.pumpAndSettle();
        expect(find.text(strings.videoStickerRepliesCount(1)), findsOneWidget);
      });

      testWidgets('shows how many replied once that is read', (tester) async {
        await pump(tester, replies);
        await tester.pump();

        expect(
          find.text(l10n(tester).videoStickerRepliesCount(2)),
          findsOneWidget,
        );
      });

      testWidgets('leaves out the responses the feeds would', (tester) async {
        filter = (videos) => [
          for (final video in videos)
            if (video.id != _reply(2).id) video,
        ];
        await pump(tester, replies);
        await tester.pump();

        expect(
          find.text(l10n(tester).videoStickerRepliesCount(1)),
          findsOneWidget,
        );
      });

      testWidgets("blurs a response the viewer's settings warn about", (
        tester,
      ) async {
        filter = (videos) => [
          for (final video in videos)
            if (video.id == _reply(1).id)
              video.copyWith(warnLabels: ['nudity'])
            else
              video,
        ];
        await pump(tester, replies);
        await tester.pump();

        final latest = tester
            .widget<InteractiveStickerCopy>(find.byType(InteractiveStickerCopy))
            .responses!
            .latest;
        expect(
          latest.map((preview) => preview.isBlurred),
          equals([true, false]),
        );
      });

      testWidgets('shows the avatar in the profile of a response that came '
          'without one', (tester) async {
        when(
          () => repository.fetchReplies(
            videoId: any(named: 'videoId'),
            videoAddress: any(named: 'videoAddress'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => VideoResponses(
            total: 3,
            videos: [
              _reply(1),
              _reply(2),
              _reply(3).copyWith(authorAvatar: 'https://cdn.example/3.jpg'),
            ],
          ),
        );
        profiles[_reply(1).pubkey] = UserProfile(
          pubkey: _reply(1).pubkey,
          picture: 'https://cdn.example/1.jpg',
          rawData: const {},
          createdAt: DateTime(2026),
          eventId: 'e' * 64,
        );
        await pump(tester, replies);
        await tester.pump();
        await tester.pump();

        final latest = tester
            .widget<InteractiveStickerCopy>(find.byType(InteractiveStickerCopy))
            .responses!
            .latest;
        expect(
          latest.map((preview) => preview.avatarUrl),
          equals([
            'https://cdn.example/1.jpg',
            null,
            'https://cdn.example/3.jpg',
          ]),
        );
      });

      testWidgets('shows a count that is only a floor with a plus', (
        tester,
      ) async {
        when(
          () => repository.fetchReplies(
            videoId: any(named: 'videoId'),
            videoAddress: any(named: 'videoAddress'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => VideoResponses(
            total: 500,
            videos: [_reply(1)],
            totalIsAtLeast: true,
          ),
        );
        await pump(tester, replies);
        await tester.pump();

        expect(
          find.text(l10n(tester).videoStickerRepliesCountAtLeast('500+')),
          findsOneWidget,
        );
      });

      testWidgets('shows how many joined an Add yours', (tester) async {
        await pump(tester, addYours);
        await tester.pump();

        expect(
          find.text(l10n(tester).videoStickerAddYoursJoined(12)),
          findsOneWidget,
        );
        verify(
          () => repository.fetchJoined(
            chainRoot: _video.addressableId!,
            hashtag: 'desksetup',
            limit: any(named: 'limit'),
            filter: any(named: 'filter'),
          ),
        ).called(1);
      });
    });

    group('interactions', () {
      testWidgets('opens the answer to a question with what it asks', (
        tester,
      ) async {
        await pump(tester, question);

        await tester.tap(
          find.text(l10n(tester).videoStickerQuestionAnswerHint),
        );
        await tester.pumpAndSettle();

        final uri = Uri.parse(pushed.single);
        expect(uri.path, equals('/question-answer/$_creator'));
        expect(uri.queryParameters['q'], equals('Ask me anything'));
        expect(uri.queryParameters['video'], equals(_video.id));
        expect(uri.queryParameters['d'], equals('root-d'));
        expect(interactions, equals(1));
      });

      testWidgets('asks someone signed out to sign in to answer', (
        tester,
      ) async {
        await pump(tester, question, viewer: null);

        await tester.tap(
          find.text(l10n(tester).videoStickerQuestionAnswerHint),
        );
        await tester.pump();

        expect(
          find.text(l10n(tester).videoStickerQuestionSignIn),
          findsOneWidget,
        );
        expect(pushed, isEmpty);
      });

      testWidgets('tells a protected minor answering is not available', (
        tester,
      ) async {
        isDmRestricted = true;
        await pump(tester, question);

        await tester.tap(
          find.text(l10n(tester).videoStickerQuestionAnswerHint),
        );
        await tester.pump();

        expect(
          find.text(l10n(tester).videoStickerQuestionUnavailable),
          findsOneWidget,
        );
        expect(pushed, isEmpty);
      });

      testWidgets('lets the creator not answer their own question', (
        tester,
      ) async {
        await pump(tester, question, viewer: _creator);

        await tester.tap(
          find.text(l10n(tester).videoStickerQuestionAnswerHint),
        );
        await tester.pumpAndSettle();

        expect(pushed, isEmpty);
        expect(interactions, isZero);
      });

      testWidgets('takes no tap on the replies while the video is not the '
          'one playing', (tester) async {
        await pump(tester, replies, isActive: false);
        await tester.pump();

        await tester.tap(find.text('Reply with a video'), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(pushed, isEmpty);
        expect(interactions, isZero);
      });

      testWidgets('opens the replies in the feed for a viewer', (
        tester,
      ) async {
        await pump(tester, replies);
        await tester.pump();

        await tester.tap(find.text('Reply with a video'));
        await tester.pumpAndSettle();

        expect(Uri.parse(pushed.single).path, equals('/pooled-video-feed'));
        expect(
          extras.single,
          isA<PooledFullscreenVideoFeedArgs>()
              .having(
                (args) => args.contextTitle,
                'contextTitle',
                l10n(tester).videoStickerRepliesManageTitle,
              )
              .having(
                (args) => args.isAddYoursSeries,
                'isAddYoursSeries',
                isFalse,
              ),
        );
      });

      testWidgets('opens the answers to an Add yours under its prompt', (
        tester,
      ) async {
        await pump(tester, addYours);
        await tester.pump();

        await tester.tap(
          find.text(l10n(tester).videoStickerAddYoursJoined(12)),
        );
        await tester.pumpAndSettle();

        expect(Uri.parse(pushed.single).path, equals('/pooled-video-feed'));
        expect(
          extras.single,
          isA<PooledFullscreenVideoFeedArgs>()
              .having(
                (args) => args.contextTitle,
                'contextTitle',
                'Show your desk',
              )
              // Its answers carry the same sticker, left out there.
              .having(
                (args) => args.isAddYoursSeries,
                'isAddYoursSeries',
                isTrue,
              ),
        );
      });

      testWidgets('opens the replies to manage for the creator', (
        tester,
      ) async {
        await pump(tester, replies, viewer: _creator);
        await tester.pump();

        await tester.tap(find.text('Reply with a video'));
        await tester.pumpAndSettle();

        final uri = Uri.parse(pushed.single);
        expect(uri.path, equals('/video-replies/${_video.id}'));
        expect(uri.queryParameters['address'], equals(_video.addressableId));
      });

      testWidgets('updates the sticker when a hide finishes after leaving '
          'Manage Replies', (tester) async {
        final events = LatestAddressableEvents();
        addTearDown(events.dispose);
        final hide = Completer<void>();
        when(
          () => repository.saveCuration(
            any(),
            videoAddress: _video.addressableId!,
            previous: any(named: 'previous'),
            takenBackRestores: any(named: 'takenBackRestores'),
          ),
        ).thenAnswer((invocation) async {
          await hide.future;
          final curation =
              invocation.positionalArguments.single as RepliesCuration;
          events.remember(
            Event(
              _creator,
              RepliesCuration.kind,
              curation.toTags(_video.addressableId!),
              '',
            ),
          );
          return curation;
        });
        final active = await pump(
          tester,
          replies,
          viewer: _creator,
          manageReplies: true,
          latestEvents: events,
        );
        await tester.pump();
        final strings = l10n(tester);
        expect(find.text(strings.videoStickerRepliesCount(2)), findsOneWidget);

        await tester.tap(find.text('Reply with a video'));
        await tester.pumpAndSettle();
        active.value = false;
        await tester.pump();

        await tester.tap(find.text(strings.videoStickerRepliesHide).first);
        await tester.pump();
        final manager = tester.element(find.byType(VideoRepliesScreen));
        GoRouter.of(manager).pop();
        await tester.pumpAndSettle();
        active.value = true;
        await tester.pump();
        expect(find.text(strings.videoStickerRepliesCount(2)), findsOneWidget);

        hide.complete();
        await tester.pumpAndSettle();
        expect(find.text(strings.videoStickerRepliesCount(1)), findsOneWidget);
        expect(find.text(strings.videoStickerRepliesCount(2)), findsNothing);
      });

      testWidgets('opens the camera to add yours, joining its chain', (
        tester,
      ) async {
        await pump(tester, addYours);
        await tester.pump();

        await tester.tap(find.text(l10n(tester).videoStickerAddYoursButton));
        await tester.pumpAndSettle();

        expect(Uri.parse(pushed.single).path, equals('/video-recorder'));
        expect(
          addYoursWhileOpen,
          equals(
            AddYoursContext(
              chainRoot: _video.addressableId!,
              prompt: 'Show your desk',
              hashtag: 'desksetup',
            ),
          ),
        );
      });

      group('on an answer naming the first video', () {
        final first = '34236:$_viewer:first';
        final answer = VideoStickerRegion(
          kind: VideoStickerKind.prompt,
          target: first,
          centerX: 0.5,
          centerY: 0.5,
          width: 0.8,
          height: 0.5,
          style: 'light',
          label: 'Show your desk\ndesksetup',
        );

        testWidgets('joins its own chain when that video starts none', (
          tester,
        ) async {
          when(
            () => repository.chainStart(first, hashtag: 'desksetup'),
          ).thenAnswer((_) async => AddYoursChainStart.doesNotStart);
          await pump(tester, answer);
          await tester.pump();

          await tester.tap(find.text(l10n(tester).videoStickerAddYoursButton));
          await tester.pumpAndSettle();

          expect(addYoursWhileOpen?.chainRoot, equals(_video.addressableId));
        });

        testWidgets('copies the resolved chain audience into a new answer', (
          tester,
        ) async {
          final root = VideoEvent(
            id: 'a' * 64,
            pubkey: _viewer,
            createdAt: 1778120201,
            content: '',
            timestamp: DateTime.utc(2026),
            vineId: 'first',
            addressableDTag: 'first',
            eventKind: 34236,
            nostrEventTags: [
              const VideoStickerRegion(
                kind: VideoStickerKind.prompt,
                target: '',
                centerX: 0.5,
                centerY: 0.5,
                width: 0.8,
                height: 0.5,
                label: 'Show your desk\ndesksetup',
                audience: VideoStickerAudience.following,
              ).toTag(),
            ],
          );
          when(
            () => repository.chainStart(first, hashtag: 'desksetup'),
          ).thenAnswer((_) async => AddYoursChainStart.starts(root));
          when(() => followRepository.followingPubkeys).thenReturn([]);
          await pump(tester, answer);
          await tester.pump();

          await tester.tap(find.text(l10n(tester).videoStickerAddYoursButton));
          await tester.pumpAndSettle();

          expect(addYoursWhileOpen?.chainRoot, first);
          expect(addYoursWhileOpen?.audience, VideoStickerAudience.following);
        });

        testWidgets('shows who joined but opens no camera while a relay that '
            'did not answer may hold that video', (tester) async {
          when(
            () => repository.chainStart(first, hashtag: 'desksetup'),
          ).thenAnswer((_) async => AddYoursChainStart.unconfirmed);
          await pump(tester, answer);
          await tester.pump();

          await tester.tap(find.text(l10n(tester).videoStickerAddYoursButton));
          await tester.pumpAndSettle();

          expect(
            find.text(l10n(tester).videoStickerAddYoursJoined(12)),
            findsOneWidget,
          );
          expect(pushed, isEmpty);
        });
      });

      group('when only some may answer', () {
        // Published without a look: it is in no frame.
        VideoStickerRegion restricted(VideoStickerRegion region) =>
            VideoStickerRegion(
              kind: region.kind,
              target: region.target,
              centerX: region.centerX,
              centerY: region.centerY,
              width: region.width,
              height: region.height,
              label: region.label,
              audience: VideoStickerAudience.following,
            );

        void creatorFollows(List<String> pubkeys) =>
            when(
              () => followRepository.getOthersFollowing(_creator),
            ).thenAnswer(
              (_) async =>
                  FollowingSnapshot(pubkeys: pubkeys, count: pubkeys.length),
            );

        testWidgets('shows it on a video the feed only loads ahead once it is '
            'read that the viewer may answer', (tester) async {
          creatorFollows([_viewer]);
          await pump(tester, restricted(replies), isActive: false);
          await tester.pump();

          expect(find.text('Reply with a video'), findsOneWidget);
        });

        testWidgets('hides it from someone the creator does not follow while '
            'nobody they follow replied', (tester) async {
          creatorFollows(const []);
          await pump(tester, restricted(replies));
          await tester.pump();

          expect(find.text('Reply with a video'), findsNothing);
        });

        testWidgets('invites someone the creator does not follow to watch '
            'the series once someone they follow joined, without a way to '
            'join', (tester) async {
          creatorFollows([_reply(3).pubkey]);
          await pump(tester, restricted(addYours));
          await tester.pump();

          expect(
            find.text(l10n(tester).videoStickerAddYoursButton),
            findsNothing,
          );
          await tester.tap(
            find.text(l10n(tester).videoStickerAddYoursWatchSeries),
          );
          await tester.pumpAndSettle();

          expect(Uri.parse(pushed.single).path, equals('/pooled-video-feed'));
          expect(addYoursWhileOpen, isNull);
        });

        testWidgets('opens a series only its creator adds to in the order it '
            'was posted, at the part the sticker is on', (tester) async {
          VideoEvent part(int n) => VideoEvent(
            id: '$n'.padLeft(64, 'a'),
            pubkey: _creator,
            createdAt: 1778120201 + n,
            content: '',
            timestamp: DateTime.utc(2026),
            vineId: 'part-$n',
            addressableDTag: 'part-$n',
            eventKind: 34236,
          );
          final first = '34236:$_creator:root-d';
          when(
            () => repository.chainStart(first, hashtag: 'desksetup'),
          ).thenAnswer((_) async => AddYoursChainStart.unconfirmed);
          when(
            () => repository.fetchSeriesBy(
              chainRoot: any(named: 'chainRoot'),
              hashtag: any(named: 'hashtag'),
              author: any(named: 'author'),
            ),
          ).thenAnswer(
            (_) async =>
                VideoResponses(total: 3, videos: [part(3), part(2), part(1)]),
          );
          await pump(
            tester,
            VideoStickerRegion(
              kind: VideoStickerKind.prompt,
              target: first,
              centerX: 0.5,
              centerY: 0.5,
              width: 0.8,
              height: 0.5,
              label: 'Show your desk\ndesksetup',
              audience: VideoStickerAudience.creator,
            ),
            on: part(2),
          );
          await tester.pump();

          await tester.tap(
            find.text(l10n(tester).videoStickerAddYoursWatchSeries),
          );
          await tester.pumpAndSettle();

          expect(
            extras.single,
            isA<PooledFullscreenVideoFeedArgs>()
                .having(
                  (args) => (args.source as VideoListViewSource).videos,
                  'videos',
                  equals([part(1), part(2), part(3)]),
                )
                .having((args) => args.initialIndex, 'initialIndex', 1),
          );
        });

        testWidgets('lets someone the creator follows join, and their answer '
            'keeps who may answer', (tester) async {
          creatorFollows([_viewer]);
          await pump(tester, restricted(addYours));
          await tester.pump();

          await tester.tap(find.text(l10n(tester).videoStickerAddYoursButton));
          await tester.pumpAndSettle();

          expect(
            addYoursWhileOpen?.audience,
            equals(VideoStickerAudience.following),
          );
        });
      });

      testWidgets('asks someone signed out to sign in to add yours', (
        tester,
      ) async {
        await pump(tester, addYours, viewer: null);
        await tester.pump();

        await tester.tap(find.text(l10n(tester).videoStickerAddYoursButton));
        await tester.pump();

        expect(
          find.text(l10n(tester).videoStickerAddYoursSignIn),
          findsOneWidget,
        );
        expect(pushed, isEmpty);
      });
    });
  });
}

/// A pushed page that tells which location it was opened at.
class _Pushed extends ConsumerStatefulWidget {
  const _Pushed({required this.state, required this.onShown});

  final GoRouterState state;
  final void Function(String location, ProviderContainer container) onShown;

  @override
  ConsumerState<_Pushed> createState() => _PushedState();
}

class _PushedState extends ConsumerState<_Pushed> {
  @override
  void initState() {
    super.initState();
    widget.onShown(
      widget.state.uri.toString(),
      ProviderScope.containerOf(context, listen: false),
    );
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}
