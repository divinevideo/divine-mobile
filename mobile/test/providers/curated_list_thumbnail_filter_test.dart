// ABOUTME: Exercises shared card thumbnails through real feed policy and wiring.
// ABOUTME: Keeps REST, relay, search and pending policy changes behind filters.

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/divine_host_filter_service.dart';
import 'package:openvine/services/feed_aspect_ratio_preference_service.dart';
import 'package:openvine/services/nsfw_content_filter.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_provenance_filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_repository/videos_repository.dart';

const _viewer =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _author =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _event =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _thumbnail = 'https://example.com/preview.jpg';

class _Auth extends Mock implements AuthService {}

class _Relay extends Mock implements NostrClient {}

class _Api extends Mock implements FunnelcakeApiClient {}

class _Storage extends Mock implements VideoLocalStorage {}

class _Lists extends Mock implements CuratedListService {}

class _Blocks extends Mock implements ContentBlocklistRepository {}

class _AuthState extends CurrentAuthState {
  @override
  AuthState build() => AuthState.authenticated;

  void change(AuthState next) => state = next;
}

class _ListsState extends CuratedListsState {
  _ListsState(this.input);
  final CuratedListService input;
  @override
  CuratedListService get service => input;
  @override
  Future<List<CuratedList>> build() async => input.lists;
}

class _Fixture {
  static Future<_Fixture> open({
    bool relay = false,
    bool squareOnly = false,
    String? hidden,
    String restThumbnail = _thumbnail,
    List<String>? relayLabels,
    List<String> serverLabels = const [],
  }) async {
    final fixture = _Fixture();
    SharedPreferences.setMockInitialValues({
      DivineHostFilterService.showDivineHostedOnlyStorageKey: hidden == 'host',
    });
    final prefs = await SharedPreferences.getInstance();
    final age = AgeVerificationService(
      preferences: prefs,
      currentPubkeyHex: () => _viewer,
      onAdultContentVerificationChanged: () {
        if (fixture.ready) {
          fixture.container
              .read(adultContentVerificationVersionProvider.notifier)
              .increment();
        }
      },
    );
    await age.initialize();
    fixture.content = ContentFilterService(ageVerificationService: age);
    await fixture.content.initialize();
    fixture.host = DivineHostFilterService(prefs);
    final provenance = VideoProvenanceFilterService(prefs);
    final aspect = FeedAspectRatioPreferenceService(prefs);
    if (squareOnly) {
      await aspect.setPreference(FeedAspectRatioPreference.squareOnly);
    }
    final blocks = _Blocks();
    when(() => blocks.changes).thenAnswer((_) => const Stream.empty());
    fixture.blocked = hidden == 'blocked' || hidden == 'muted';
    when(() => blocks.shouldFilterFromFeeds(any())).thenAnswer(
      (i) => fixture.blocked && i.positionalArguments.first == _author,
    );
    when(() => blocks.currentState).thenAnswer(
      (_) => ContentPolicyState(
        currentUserPubkey: _viewer,
        blockedPubkeys: hidden == 'blocked' ? {_author} : {},
        mutedPubkeys: hidden == 'muted' ? {_author} : {},
        pubkeysBlockingUs: {},
        pubkeysMutingUs: {},
      ),
    );
    final auth = _Auth();
    when(() => auth.currentPublicKeyHex).thenReturn(_viewer);
    final client = _Relay();
    when(() => client.publicKey).thenReturn(_viewer);
    final labels = [
      if ([
        'nudity',
        'sexual',
        'graphic-media',
        'violence',
        'flashing-lights',
      ].contains(hidden))
        hidden!,
    ];
    fixture.stats = VideoStats(
      id: _event,
      pubkey: _author,
      createdAt: DateTime.utc(2026),
      kind: 34236,
      dTag: 'video',
      title: 'Video',
      dimensions: squareOnly ? '720x1280' : null,
      thumbnail: restThumbnail,
      videoUrl: 'https://example.com/video.mp4',
      reactions: 0,
      comments: 0,
      reposts: 0,
      engagementScore: 0,
      contentWarningLabels: labels,
      moderationLabels: serverLabels,
    );
    final api = _Api();
    when(() => api.getVideoStats(_event)).thenAnswer((_) {
      final pending = fixture.pending;
      return pending?.future ?? Future.value(relay ? null : fixture.stats);
    });
    when(
      () => client.queryEvents(any(), timeout: any(named: 'timeout')),
    ).thenAnswer((i) async {
      final filters = i.positionalArguments.first as List<Filter>;
      if (filters.any((f) => f.kinds?.contains(30005) ?? false)) return [];
      return [
        Event.fromJson({
          'id': _event,
          'pubkey': _author,
          'created_at': 1770000000,
          'kind': 34236,
          'tags': [
            ['d', 'video'],
            ['url', 'https://example.com/video.mp4'],
            ['thumb', _thumbnail],
            if (squareOnly) ['dim', '720x1280'],
            for (final label in relayLabels ?? labels)
              ['l', label, 'content-warning'],
          ],
          'content': '',
          'sig': '',
        }),
      ];
    });
    final videoService =
        VideoEventService(
            client,
            crashReporter: const SilentCrashReporter(),
          )
          ..setBlocklistRepository(blocks)
          ..setDivineHostFilterService(fixture.host)
          ..setProvenanceFilterService(provenance);
    final nsfw = createNsfwFilter(fixture.content, viewerPubkey: () => _viewer);
    final videos = VideosRepository(
      nostrClient: client,
      localStorage: _Storage(),
      blockFilter: blocks.shouldFilterFromFeeds,
      deletedFilter: videoService.isVideoEventKnownDeleted,
      removedVideoIds: videoService.removedVideoIds,
      contentFilter: nsfw,
      feedShapeFilter: aspect.shouldHideVideo,
      warningLabelsResolver: createNsfwWarnLabels(
        fixture.content,
        viewerPubkey: () => _viewer,
      ),
    );
    final row = CuratedList(
      id: 'dance',
      pubkey: _viewer,
      name: 'Dance',
      videoEventIds: const [_event],
      thumbnailUrls: const ['https://example.com/stale.jpg'],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final lists = _Lists();
    when(() => lists.myLists).thenReturn([row]);
    when(() => lists.lists).thenReturn([row]);
    when(() => lists.subscribedLists).thenReturn(const []);
    fixture.container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authServiceProvider.overrideWithValue(auth),
        currentAuthStateProvider.overrideWith(_AuthState.new),
        nostrServiceProvider.overrideWithValue(client),
        funnelcakeApiClientProvider.overrideWithValue(api),
        contentBlocklistRepositoryProvider.overrideWithValue(blocks),
        ageVerificationServiceProvider.overrideWithValue(age),
        contentFilterServiceProvider.overrideWithValue(fixture.content),
        divineHostFilterServiceProvider.overrideWithValue(fixture.host),
        videoProvenanceFilterServiceProvider.overrideWithValue(provenance),
        feedAspectRatioPreferenceServiceProvider.overrideWithValue(aspect),
        videoEventServiceProvider.overrideWithValue(videoService),
        videosRepositoryProvider.overrideWithValue(videos),
        curatedListsStateProvider.overrideWith(() => _ListsState(lists)),
      ],
    );
    fixture.ready = true;
    fixture.subscription = fixture.container.listen(
      myListsWithThumbnailsProvider,
      (_, next) => fixture.states.add(next),
    );
    addTearDown(() async {
      fixture.ready = false;
      fixture.subscription.close();
      fixture.container.dispose();
      videoService.dispose();
      fixture.content.dispose();
      fixture.host.dispose();
      provenance.dispose();
      aspect.dispose();
    });
    return fixture;
  }

  bool blocked = false;
  bool ready = false;
  Completer<VideoStats?>? pending;
  late VideoStats stats;
  late ProviderContainer container;
  late ContentFilterService content;
  late DivineHostFilterService host;
  late ProviderSubscription<AsyncValue<List<CuratedList>>> subscription;
  final states = <AsyncValue<List<CuratedList>>>[];
  Future<List<CuratedList>> read() =>
      container.read(myListsWithThumbnailsProvider.future);
}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(Duration.zero);
  });
  group('shared curated card content policy', () {
    test(
      'REST server Hide cannot regain a preview from unlabelled relays',
      () async {
        final fixture = await _Fixture.open(
          restThumbnail: '',
          serverLabels: const ['nudity'],
        );
        final video = fixture.stats.toVideoEvent();
        expect(video.contentWarningLabels, isEmpty);
        expect(video.moderationLabels, ['nudity']);
        expect(
          fixture.container
              .read(videosRepositoryProvider)
              .applyContentPreferences([video]),
          isEmpty,
        );
        expect((await fixture.read()).single.thumbnailUrls, isEmpty);
        final repository = fixture.container.read(
          curatedListRepositoryProvider,
        );
        for (final emission
            in await repository.searchAllLists('dance').toList()) {
          expect(emission.single.thumbnailUrls, isEmpty);
        }
        expect(
          await fixture.content.ageVerificationService.setAdultContentVerified(
            true,
          ),
          isTrue,
        );
        await fixture.content.setPreference(
          ContentLabel.nudity,
          ContentFilterPreference.show,
        );
        await fixture.container.pump();
        expect((await fixture.read()).single.thumbnailUrls, [_thumbnail]);
        final refreshed = fixture.container.read(curatedListRepositoryProvider);
        expect(
          (await refreshed.searchAllLists('dance').last).single.thumbnailUrls,
          [_thumbnail],
        );
      },
    );
    for (final label in [ContentLabel.nudity, ContentLabel.flashingLights]) {
      test(
        'REST ${label.value} denial survives less complete relay metadata',
        () async {
          final fixture = await _Fixture.open(
            hidden: label.value,
            restThumbnail: '',
            relayLabels: const [],
          );
          expect((await fixture.read()).single.thumbnailUrls, isEmpty);
          final repository = fixture.container.read(
            curatedListRepositoryProvider,
          );
          for (final emission
              in await repository.searchAllLists('dance').toList()) {
            expect(emission.single.thumbnailUrls, isEmpty);
          }
          if (label == ContentLabel.nudity) {
            expect(
              await fixture.content.ageVerificationService
                  .setAdultContentVerified(true),
              isTrue,
            );
          }
          await fixture.content.setPreference(
            label,
            ContentFilterPreference.show,
          );
          await fixture.container.pump();
          expect((await fixture.read()).single.thumbnailUrls, [_thumbnail]);
          final refreshed = fixture.container.read(
            curatedListRepositoryProvider,
          );
          expect(
            (await refreshed.searchAllLists('dance').last).single.thumbnailUrls,
            [_thumbnail],
          );
        },
      );
    }
    for (final relay in [false, true]) {
      test(
        'square-only feed keeps permitted portrait ${relay ? "relay" : "REST"} list previews',
        () async {
          final fixture = await _Fixture.open(relay: relay, squareOnly: true);
          final video = fixture.stats.toVideoEvent();
          expect(
            fixture.container
                .read(videosRepositoryProvider)
                .applyContentPreferences([video]),
            isEmpty,
          );
          expect(
            fixture.container
                .read(videoEventServiceProvider)
                .shouldHideVideo(video),
            isFalse,
          );
          expect((await fixture.read()).single.thumbnailUrls, [_thumbnail]);
          final repository = fixture.container.read(
            curatedListRepositoryProvider,
          );
          final emissions = await repository.searchAllLists('dance').toList();
          expect(emissions, hasLength(4));
          expect(emissions.first.single.thumbnailUrls, isEmpty);
          for (final emission in emissions.skip(1)) {
            expect(emission.single.thumbnailUrls, [_thumbnail]);
          }
        },
      );
      for (final label in ['nudity', 'flashing-lights']) {
        test(
          'square-only cards keep $label ${relay ? "relay" : "REST"} previews neutral',
          () async {
            final fixture = await _Fixture.open(
              relay: relay,
              squareOnly: true,
              hidden: label,
            );
            expect((await fixture.read()).single.thumbnailUrls, isEmpty);
            final repository = fixture.container.read(
              curatedListRepositoryProvider,
            );
            for (final emission
                in await repository.searchAllLists('dance').toList()) {
              expect(emission.single.thumbnailUrls, isEmpty);
            }
          },
        );
      }
      test(
        'warned ${relay ? 'relay' : 'REST'} videos use neutral previews until Show',
        () async {
          final fixture = await _Fixture.open(
            relay: relay,
            hidden: 'flashing-lights',
          );
          final permitted = fixture.container
              .read(videosRepositoryProvider)
              .applyContentPreferences([fixture.stats.toVideoEvent()]);
          expect(permitted, hasLength(1));
          expect(permitted.single.warnLabels, isNotEmpty);
          expect((await fixture.read()).single.thumbnailUrls, isEmpty);
          final repository = fixture.container.read(
            curatedListRepositoryProvider,
          );
          for (final emission
              in await repository.searchAllLists('dance').toList()) {
            expect(emission.single.thumbnailUrls, isEmpty);
          }
          await fixture.content.setPreference(
            ContentLabel.flashingLights,
            ContentFilterPreference.show,
          );
          await fixture.container.pump();
          expect((await fixture.read()).single.thumbnailUrls, [_thumbnail]);
          final refreshed = fixture.container.read(
            curatedListRepositoryProvider,
          );
          expect(
            (await refreshed.searchAllLists('dance').last).single.thumbnailUrls,
            [_thumbnail],
          );
        },
      );
      for (final hidden in [
        'blocked',
        'muted',
        'host',
        'nudity',
        'sexual',
        'graphic-media',
        'violence',
      ]) {
        test(
          'hides $hidden previews from ${relay ? 'relays' : 'REST'} in both surfaces',
          () async {
            final fixture = await _Fixture.open(relay: relay, hidden: hidden);
            expect((await fixture.read()).single.thumbnailUrls, isEmpty);
            final repository = fixture.container.read(
              curatedListRepositoryProvider,
            );
            final emissions = await repository.searchAllLists('dance').toList();
            expect(emissions, hasLength(4));
            for (final emission in emissions) {
              expect(emission.single.name, 'Dance');
              expect(emission.single.thumbnailUrls, isEmpty);
            }
          },
        );
      }
    }

    test('a completed preview retires when its video is deleted', () async {
      final fixture = await _Fixture.open();
      expect((await fixture.read()).single.thumbnailUrls, [_thumbnail]);
      fixture.container
          .read(videoEventServiceProvider)
          .removeVideoEventCompletely(fixture.stats.toVideoEvent());
      await fixture.container.pump();
      expect((await fixture.read()).single.thumbnailUrls, isEmpty);
      final repository = fixture.container.read(curatedListRepositoryProvider);
      expect(
        (await repository.searchAllLists('dance').last).single.thumbnailUrls,
        isEmpty,
      );
    });

    test('block sync preserves the repository and its list listener', () async {
      final fixture = await _Fixture.open();
      await fixture.read();
      final held = fixture.container.read(curatedListRepositoryProvider);
      var streamClosed = false;
      final updates = <List<CuratedList>>[];
      final subscription = held.subscribedListsStream.listen(
        updates.add,
        onDone: () => streamClosed = true,
      );
      addTearDown(subscription.cancel);
      await fixture.container.pump();

      fixture.container.read(blocklistVersionProvider.notifier).increment();
      await fixture.container.pump();

      expect(fixture.container.read(curatedListRepositoryProvider), same(held));
      expect(streamClosed, isFalse);
      fixture.container.read(contentFilterVersionProvider.notifier).increment();
      fixture.container
          .read(divineHostFilterVersionProvider.notifier)
          .increment();
      fixture.container
          .read(videoProvenanceFilterVersionProvider.notifier)
          .increment();
      fixture.container
          .read(adultContentVerificationVersionProvider.notifier)
          .increment();
      await fixture.container.pump();
      expect(fixture.container.read(curatedListRepositoryProvider), same(held));
      expect(streamClosed, isFalse);
      final followed = (await fixture.read()).single;
      held.setSubscribedLists([followed]);
      await fixture.container.pump();
      expect(updates.last.single.id, followed.id);
      held.setSubscribedLists(const []);
      await fixture.container.pump();
      expect(updates.last, isEmpty);
      expect(streamClosed, isFalse);
    });

    test(
      'policy changes retire loaded thumbnails and pending results',
      () async {
        final fixture = await _Fixture.open();
        expect((await fixture.read()).single.thumbnailUrls, [_thumbnail]);
        final oldFilter = fixture.container.read(
          curatedListThumbnailFilterProvider,
        );
        fixture.pending = Completer<VideoStats?>();
        final beforeChange = fixture.states.length;
        await fixture.host.setShowDivineHostedOnly(true);
        await fixture.container.pump();
        expect(
          fixture.container.read(myListsWithThumbnailsProvider).isLoading,
          isTrue,
        );
        expect(oldFilter(fixture.stats.toVideoEvent()), isTrue);
        fixture.pending!.complete(fixture.stats);
        expect((await fixture.read()).single.thumbnailUrls, isEmpty);
        expect(
          fixture.states
              .skip(beforeChange)
              .whereType<AsyncData<List<CuratedList>>>()
              .expand((state) => state.value)
              .expand((list) => list.thumbnailUrls),
          isEmpty,
        );
        await fixture.host.setShowDivineHostedOnly(false);
        await fixture.container.pump();
        expect((await fixture.read()).single.thumbnailUrls, [_thumbnail]);
        expect(oldFilter(fixture.stats.toVideoEvent()), isTrue);
      },
    );

    test(
      'content preference changes requery instead of reusing visible previews',
      () async {
        final fixture = await _Fixture.open(hidden: 'nudity');
        expect((await fixture.read()).single.thumbnailUrls, isEmpty);
        final age = fixture.content.ageVerificationService;
        expect(await age.setAdultContentVerified(true), isTrue);
        await fixture.content.setPreference(
          ContentLabel.nudity,
          ContentFilterPreference.show,
        );
        await fixture.container.pump();
        expect((await fixture.read()).single.thumbnailUrls, [_thumbnail]);
        expect(await age.setAdultContentVerified(false), isTrue);
        await fixture.container.pump();
        expect((await fixture.read()).single.thumbnailUrls, isEmpty);
        await fixture.content.setPreference(
          ContentLabel.nudity,
          ContentFilterPreference.hide,
        );
        await fixture.container.pump();
        expect((await fixture.read()).single.thumbnailUrls, isEmpty);
      },
    );

    test(
      'a stable repository reads the current policy after an auth ABA',
      () async {
        final fixture = await _Fixture.open();
        final original = await fixture.read();
        expect(original.single.thumbnailUrls, [_thumbnail]);
        final oldRepository = fixture.container.read(
          curatedListRepositoryProvider,
        );
        final auth = fixture.container.read(
          currentAuthStateProvider.notifier,
        ) as _AuthState;
        auth.change(AuthState.unauthenticated);
        await fixture.container.pump();
        auth.change(AuthState.authenticated);
        await fixture.container.pump();
        expect((await fixture.read()).single.thumbnailUrls, [_thumbnail]);
        expect(
          fixture.container.read(curatedListRepositoryProvider),
          same(oldRepository),
        );
        final late = await oldRepository.resolveListThumbnails(original);
        expect(late.single.thumbnailUrls, [_thumbnail]);
        fixture.blocked = true;
        fixture.container.read(blocklistVersionProvider.notifier).increment();
        await fixture.container.pump();
        expect(
          (await oldRepository.resolveListThumbnails(original))
              .single
              .thumbnailUrls,
          isEmpty,
        );
      },
    );

    test('a disposed repository cannot expose late previews', () async {
      final fixture = await _Fixture.open();
      final original = await fixture.read();
      final held = fixture.container.read(curatedListRepositoryProvider);
      fixture.container.invalidate(curatedListRepositoryProvider);
      await fixture.container.pump();
      expect(
        fixture.container.read(curatedListRepositoryProvider),
        isNot(same(held)),
      );
      expect(
        (await held.resolveListThumbnails(original)).single.thumbnailUrls,
        isEmpty,
      );
      expect((await fixture.read()).single.thumbnailUrls, [_thumbnail]);
    });

    test(
      'block changes retire cached previews and unblock resolves again',
      () async {
        final fixture = await _Fixture.open();
        expect((await fixture.read()).single.thumbnailUrls, [_thumbnail]);
        fixture.blocked = true;
        fixture.container.read(blocklistVersionProvider.notifier).increment();
        await fixture.container.pump();
        expect((await fixture.read()).single.thumbnailUrls, isEmpty);
        fixture.blocked = false;
        fixture.container.read(blocklistVersionProvider.notifier).increment();
        await fixture.container.pump();
        expect((await fixture.read()).single.thumbnailUrls, [_thumbnail]);
      },
    );
  });
}
