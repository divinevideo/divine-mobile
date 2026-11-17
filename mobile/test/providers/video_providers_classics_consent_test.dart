// ABOUTME: Pins that the Classics browse read built by videosRepositoryProvider
// ABOUTME: identifies the viewer only while analytics consent is initialized.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
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

void main() {
  group('videosRepositoryProvider Classics browsing', () {
    late _MockFunnelcakeApiClient api;
    late _ConsentAnalytics analytics;
    late ProviderContainer container;
    final viewers = <String?>[];

    setUp(() async {
      registerFallbackValue(const ClassicRecommendationsRequest(seed: 'x'));
      registerFallbackValue(Duration.zero);
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
      api = _MockFunnelcakeApiClient();
      when(() => api.isAvailable).thenReturn(true);
      when(() => api.isDisposed).thenReturn(false);
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
      container = ProviderContainer(
        overrides: [
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
    });

    test('sends no viewer while analytics consent is off', () async {
      await container.read(videosRepositoryProvider).getClassicVideos();

      expect(viewers, hasLength(1));
      expect(viewers.single, isNull);
    });

    test('sends the viewer once analytics consent is on', () async {
      analytics.consent = true;

      await container.read(videosRepositoryProvider).getClassicVideos();

      expect(viewers, [_viewer]);
    });
  });
}
