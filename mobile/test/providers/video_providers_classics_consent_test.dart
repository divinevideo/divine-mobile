// ABOUTME: Pins that the Classics browse read built by videosRepositoryProvider
// ABOUTME: identifies the viewer only with consent, and only for an account
// ABOUTME: the protected-minor gate has confirmed.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/config/adaptive_classics.dart';
import 'package:openvine/models/protected_minor_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/divine_host_filter_service.dart';
import 'package:openvine/services/feed_aspect_ratio_preference_service.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_provider_overrides.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _MockContentFilterService extends Mock implements ContentFilterService {}

class _MockFeedAspectRatioPreferenceService extends Mock
    implements FeedAspectRatioPreferenceService {}

class _MockDivineHostFilterService extends Mock
    implements DivineHostFilterService {}

class _MockSeenVideosService extends Mock implements SeenVideosService {}

class _StaticContentFilterVersion extends ContentFilterVersion {
  @override
  int build() => 0;
}

class _StaticDivineHostFilterVersion extends DivineHostFilterVersion {
  @override
  int build() => 0;
}

class _ConsentAnalytics extends TestAnalyticsService {
  bool consent = false;

  @override
  bool get initializedAnalyticsConsent => consent;
}

const _viewer =
    'abababababababababababababababababababababababababababababababab';

/// Builds the real [videosRepositoryProvider] wiring around [api].
///
/// [gate] decides how the Adaptive Classics account gate resolves.
Future<ProviderContainer> _buildContainer({
  required _MockFunnelcakeApiClient api,
  required _ConsentAnalytics analytics,
  required List<Override> gate,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final nostr = _MockNostrClient();
  when(() => nostr.isInitialized).thenReturn(true);
  when(() => nostr.publicKey).thenReturn(_viewer);
  when(() => nostr.hasKeys).thenReturn(false);
  when(() => nostr.connectedRelayCount).thenReturn(1);
  when(() => nostr.configuredRelays).thenReturn(<String>[]);
  final auth = createMockAuthService(
    authState: AuthState.authenticated,
    currentPublicKeyHex: _viewer,
  );
  final seen = _MockSeenVideosService();
  when(seen.initializeForFeed).thenAnswer((_) async {});
  when(
    () => seen.wasSeenRecently(any(), within: any(named: 'within')),
  ).thenReturn(false);
  final host = _MockDivineHostFilterService();
  when(() => host.showDivineHostedOnly).thenReturn(false);
  when(() => api.isAvailable).thenReturn(true);
  when(() => api.isDisposed).thenReturn(false);
  final container = ProviderContainer(
    overrides: [
      ...gate,
      appVersionProvider.overrideWithValue('test'),
      sharedPreferencesProvider.overrideWithValue(preferences),
      nostrServiceProvider.overrideWithValue(nostr),
      authServiceProvider.overrideWithValue(auth),
      funnelcakeApiClientProvider.overrideWithValue(api),
      analyticsServiceProvider.overrideWithValue(analytics),
      contentFilterServiceProvider.overrideWithValue(
        _MockContentFilterService(),
      ),
      feedAspectRatioPreferenceServiceProvider.overrideWithValue(
        _MockFeedAspectRatioPreferenceService(),
      ),
      contentFilterVersionProvider.overrideWith(
        _StaticContentFilterVersion.new,
      ),
      divineHostFilterVersionProvider.overrideWith(
        _StaticDivineHostFilterVersion.new,
      ),
      divineHostFilterServiceProvider.overrideWithValue(host),
      seenVideosServiceProvider.overrideWithValue(seen),
      pendingActionServiceProvider.overrideWithValue(null),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUpAll(() {
    registerFallbackValue(const ClassicRecommendationsRequest(seed: 'x'));
    registerFallbackValue(Duration.zero);
  });

  group('videosRepositoryProvider Classics browsing', () {
    late _MockFunnelcakeApiClient api;
    late _ConsentAnalytics analytics;
    late ProviderContainer container;
    final viewers = <String?>[];

    setUp(() async {
      api = _MockFunnelcakeApiClient();
      viewers.clear();
      when(
        () => api.getClassicRecommendations(
          request: any(named: 'request'),
          userPubkey: any(named: 'userPubkey'),
        ),
      ).thenAnswer((call) async {
        viewers.add(call.namedArguments[#userPubkey] as String?);
        return const RecommendationsResponse(videos: [], source: 'mixed');
      });
      analytics = _ConsentAnalytics();
      container = await _buildContainer(
        api: api,
        analytics: analytics,
        gate: [adaptiveClassicsEnabledProvider.overrideWithValue(true)],
      );
    });

    test('sends no viewer while analytics consent is off', () async {
      await container.read(videosRepositoryProvider).getClassicVideos();

      expect(viewers, hasLength(1));
      expect(viewers.single, isNull);
    });

    test(
      'a replaced repository ends its in-flight read as superseded',
      () async {
        final reply = Completer<RecommendationsResponse>();
        when(
          () => api.getClassicRecommendations(
            request: any(named: 'request'),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) => reply.future);
        final retired = container.read(videosRepositoryProvider);
        final read = retired.getClassicVideos();
        await pumpEventQueue();

        container.invalidate(videosRepositoryProvider);
        expect(container.read(videosRepositoryProvider), isNot(same(retired)));
        reply.complete(
          const RecommendationsResponse(videos: [], source: 'mixed'),
        );

        await expectLater(read, throwsA(isA<FunnelcakeException>()));
      },
    );

    test('sends the viewer once analytics consent is on', () async {
      analytics.consent = true;

      await container.read(videosRepositoryProvider).getClassicVideos();

      expect(viewers, [_viewer]);
    });
  });

  group('videosRepositoryProvider Classics account gate', () {
    late _MockFunnelcakeApiClient api;
    late ProviderContainer container;
    late Completer<ProtectedMinorStatus> status;
    var recommendationReads = 0;
    var archiveReads = 0;

    setUp(() async {
      api = _MockFunnelcakeApiClient();
      recommendationReads = 0;
      archiveReads = 0;
      when(
        () => api.getClassicRecommendations(
          request: any(named: 'request'),
          userPubkey: any(named: 'userPubkey'),
        ),
      ).thenAnswer((_) async {
        recommendationReads++;
        return const RecommendationsResponse(videos: [], source: 'mixed');
      });
      when(
        () => api.getClassicVines(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async {
        archiveReads++;
        return const [];
      });
      status = Completer<ProtectedMinorStatus>();
      container = await _buildContainer(
        api: api,
        analytics: _ConsentAnalytics(),
        // The real adaptiveClassicsEnabledProvider, driven by the
        // protected-minor status the repository's per-read gate reads.
        gate: [
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          protectedMinorStatusProvider.overrideWith((ref) => status.future),
        ],
      );
      final subscription = container.listen(
        protectedMinorStatusProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
    });

    Future<void> resolveStatus(ProtectedMinorStatus value) async {
      status.complete(value);
      await container.read(protectedMinorStatusProvider.future);
    }

    test(
      'keeps a protected account off the recommendations endpoint',
      () async {
        await resolveStatus(ProtectedMinorStatus.protected());

        await container.read(videosRepositoryProvider).getClassicVideos();

        expect(recommendationReads, isZero);
        expect(archiveReads, greaterThan(0));
      },
    );

    test(
      'keeps an account off the endpoint while its status is unknown',
      () async {
        await resolveStatus(ProtectedMinorStatus.unknown());

        await container.read(videosRepositoryProvider).getClassicVideos();

        expect(recommendationReads, isZero);
        expect(archiveReads, greaterThan(0));
      },
    );

    test(
      'keeps an account off the endpoint while its first status check is '
      'pending',
      () async {
        await container.read(videosRepositoryProvider).getClassicVideos();

        expect(recommendationReads, isZero);
        expect(archiveReads, greaterThan(0));
      },
    );

    test(
      'the same repository reads the endpoint once the account is confirmed',
      () async {
        final repository = container.read(videosRepositoryProvider);
        await repository.getClassicVideos();
        expect(recommendationReads, isZero);

        await resolveStatus(ProtectedMinorStatus.notProtected());

        expect(container.read(videosRepositoryProvider), same(repository));
        await repository.getClassicVideos();
        expect(recommendationReads, 1);
      },
    );
  });
}
