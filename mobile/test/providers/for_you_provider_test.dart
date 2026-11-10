// ABOUTME: Tests the For You recommendations feed provider.
// ABOUTME: Pins that an account change drops the old account's feed.

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockNostrClient extends Mock implements NostrClient {}

const _accountA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _accountB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  group(ForYouFeed, () {
    group('account changes', () {
      test(
        'rebuilds for the new account after a sign-out and sign-in in one '
        'container',
        () async {
          final harness = await _FeedHarness.start(
            recommend: (viewer, _) async => _page(viewer),
          );
          addTearDown(harness.dispose);
          expect(await harness.feedIds(), equals([_id(_accountA, 1)]));

          await harness.signOut();
          await harness.signIn(_accountB);

          expect(await harness.feedIds(), equals([_id(_accountB, 1)]));
        },
      );

      test('drops a page load that lands after sign-out', () async {
        final secondPage = Completer<HomeFeedResult>();
        final secondPageRequested = Completer<void>();
        final harness = await _FeedHarness.start(
          recommend: (viewer, cursor) {
            if (cursor == null) return Future.value(_page(viewer, next: 'p2'));
            secondPageRequested.complete();
            return secondPage.future;
          },
        );
        addTearDown(harness.dispose);
        expect(await harness.feedIds(), equals([_id(_accountA, 1)]));

        final loading = harness.feed.loadMore();
        await secondPageRequested.future;
        await harness.signOut();
        secondPage.complete(_page(_accountA, number: 2));
        await loading;

        expect(await harness.feedIds(), isEmpty);
      });

      test(
        'keeps a page load that fails after sign-out from restoring the '
        'previous feed',
        () async {
          final secondPage = Completer<HomeFeedResult>();
          final secondPageRequested = Completer<void>();
          final harness = await _FeedHarness.start(
            recommend: (viewer, cursor) {
              if (cursor == null) {
                return Future.value(_page(viewer, next: 'p2'));
              }
              secondPageRequested.complete();
              return secondPage.future;
            },
          );
          addTearDown(harness.dispose);
          expect(await harness.feedIds(), equals([_id(_accountA, 1)]));

          final loading = harness.feed.loadMore();
          await secondPageRequested.future;
          await harness.signOut();
          secondPage.completeError(Exception('connection reset'));
          await loading;

          expect(await harness.feedIds(), isEmpty);
        },
      );

      test(
        'keeps a refresh that fails after sign-out from restoring the '
        'previous feed',
        () async {
          final refreshed = Completer<HomeFeedResult>();
          final refreshRequested = Completer<void>();
          var requests = 0;
          final harness = await _FeedHarness.start(
            recommend: (viewer, _) {
              requests++;
              if (requests == 1) return Future.value(_page(viewer));
              refreshRequested.complete();
              return refreshed.future;
            },
          );
          addTearDown(harness.dispose);
          expect(await harness.feedIds(), equals([_id(_accountA, 1)]));

          final refreshing = harness.feed.refresh();
          await refreshRequested.future;
          await harness.signOut();
          refreshed.completeError(Exception('connection reset'));
          await refreshing;

          expect(await harness.feedIds(), isEmpty);
        },
      );
    });
  });
}

/// Builds the real [ForYouFeed] for [_accountA] and replays what it observes
/// when NostrService changes identity inside one container: the auth pubkey,
/// the session readiness and a new Nostr client, in that service's order.
class _FeedHarness {
  _FeedHarness._(this._recommend);

  final Future<HomeFeedResult> Function(String viewer, String? cursor)
  _recommend;
  late final ProviderContainer container;
  late final List<Override> Function(NostrClient nostrClient) _overrides;
  late final ProviderSubscription<AsyncValue<VideoFeedState>> _subscription;
  String? _signedIn = _accountA;

  static Future<_FeedHarness> start({
    required Future<HomeFeedResult> Function(String viewer, String? cursor)
    recommend,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final harness = _FeedHarness._(recommend);

    final videoEvents = _MockVideoEventService();
    when(() => videoEvents.filterVideoList(any())).thenAnswer(
      (invocation) =>
          List<VideoEvent>.from(invocation.positionalArguments.first as List),
    );
    final blocklist = _MockContentBlocklistRepository();
    when(() => blocklist.shouldFilterFromFeeds(any())).thenReturn(false);
    final auth = _MockAuthService();
    when(() => auth.authState).thenReturn(AuthState.authenticated);
    when(
      () => auth.authStateStream,
    ).thenAnswer((_) => const Stream<AuthState>.empty());
    when(() => auth.currentPublicKeyHex).thenAnswer((_) => harness._signedIn);
    final videos = _MockVideosRepository();
    when(
      () => videos.getRecommendedVideos(
        userPubkey: any(named: 'userPubkey'),
        limit: any(named: 'limit'),
        cursor: any(named: 'cursor'),
        skipCache: any(named: 'skipCache'),
        preferredLanguages: any(named: 'preferredLanguages'),
        viewerCountry: any(named: 'viewerCountry'),
      ),
    ).thenAnswer(
      (invocation) => harness._recommend(
        invocation.namedArguments[#userPubkey] as String,
        invocation.namedArguments[#cursor] as String?,
      ),
    );
    http.Client httpClient() =>
        MockClient((_) async => http.Response('[]', 200));

    harness._overrides = (nostrClient) => [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appReadyProvider.overrideWithValue(true),
      videoEventServiceProvider.overrideWithValue(videoEvents),
      contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
      videosRepositoryProvider.overrideWithValue(videos),
      authServiceProvider.overrideWithValue(auth),
      nostrServiceProvider.overrideWithValue(nostrClient),
      currentEnvironmentProvider.overrideWithValue(
        EnvironmentConfig.production,
      ),
      appVersionProvider.overrideWithValue('1.0.0'),
      instrumentedHttpClientFactoryProvider.overrideWithValue(httpClient),
    ];
    harness.container = ProviderContainer(
      overrides: harness._overrides(_MockNostrClient()),
    );
    harness._session.update(
      const NostrSessionReadiness.identityKnown(pubkey: _accountA),
    );
    harness._subscription = harness.container.listen(
      forYouFeedProvider,
      (_, _) {},
    );
    return harness;
  }

  NostrSession get _session => container.read(nostrSessionProvider.notifier);

  ForYouFeed get feed => container.read(forYouFeedProvider.notifier);

  Future<List<String>> feedIds() async {
    final state = await container.read(forYouFeedProvider.future);
    return state.videos.map((video) => video.id).toList();
  }

  Future<void> signOut() async {
    final previous = _signedIn!;
    _signedIn = null;
    _session.update(NostrSessionReadiness.tearingDown(pubkey: previous));
    container.updateOverrides(_overrides(_MockNostrClient()));
    _session.update(const NostrSessionReadiness.signedOut());
    await pumpEventQueue();
  }

  Future<void> signIn(String pubkey) async {
    _signedIn = pubkey;
    container.updateOverrides(_overrides(_MockNostrClient()));
    _session.update(NostrSessionReadiness.identityKnown(pubkey: pubkey));
    await pumpEventQueue();
  }

  void dispose() {
    _subscription.close();
    container.dispose();
  }
}

String _id(String viewer, int page) => 'recommended-for-$viewer-page-$page';

HomeFeedResult _page(String viewer, {int number = 1, String? next}) {
  return HomeFeedResult(
    videos: [_video(_id(viewer, number))],
    hasMore: next != null,
    paginationCursor: next,
  );
}

VideoEvent _video(String id) {
  const createdAt = 1742169600;
  return VideoEvent(
    id: id,
    pubkey: 'author-$id',
    createdAt: createdAt,
    content: 'video $id',
    timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
    videoUrl: 'https://example.com/$id.mp4',
    thumbnailUrl: 'https://example.com/$id.jpg',
    rawTags: const {'d': 'seed', 'x': '1', 'y': '2', 'z': '3'},
    originalLoops: AppConstants.paginationBatchSize,
  );
}
