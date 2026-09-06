// ABOUTME: Tests crossposting API aggregation and mutation forwarding
// ABOUTME: Guards sequential Keycast-authenticated reads against token races

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/repositories/crossposting_repository.dart';
import 'package:openvine/services/crossposting_api_client.dart';

class _MockCrosspostingApiClient extends Mock
    implements CrosspostingApiClient {}

void main() {
  late _MockCrosspostingApiClient apiClient;
  late CrosspostingRepository repository;

  setUpAll(() {
    registerFallbackValue(CrosspostingPlatform.instagram);
    registerFallbackValue(CrosspostingMode.disabled);
    registerFallbackValue(Uri.parse('https://divine.video/app/callback'));
  });

  setUp(() {
    apiClient = _MockCrosspostingApiClient();
    repository = CrosspostingRepository(apiClient);
  });

  group('loadSettings', () {
    test(
      'loads platform, connection, and preference APIs sequentially',
      () async {
        final calls = <String>[];
        final platforms = Completer<List<CrosspostingPlatformInfo>>();
        final connections = Completer<List<CrosspostingConnection>>();
        final preferences = Completer<List<CrosspostingPreference>>();

        when(apiClient.getPlatforms).thenAnswer((_) {
          calls.add('platforms');
          return platforms.future;
        });
        when(apiClient.getConnections).thenAnswer((_) {
          calls.add('connections');
          return connections.future;
        });
        when(apiClient.getPreferences).thenAnswer((_) {
          calls.add('preferences');
          return preferences.future;
        });

        final result = repository.loadSettings();

        verify(apiClient.getPlatforms).called(1);
        verifyNever(apiClient.getConnections);
        verifyNever(apiClient.getPreferences);

        platforms.complete(const []);
        await untilCalled(apiClient.getConnections);
        verifyNever(apiClient.getPreferences);

        connections.complete(const []);
        await untilCalled(apiClient.getPreferences);

        preferences.complete(const []);
        await expectLater(result, completion(isEmpty));
        expect(calls, ['platforms', 'connections', 'preferences']);
      },
    );

    test('joins enabled platforms in service order', () async {
      const instagramReauth = CrosspostingConnection(
        id: 'instagram-reauth',
        platform: CrosspostingPlatform.instagram,
        status: CrosspostingConnectionStatus.needsReauth,
        externalAccountName: '@creator',
      );
      const instagramConnected = CrosspostingConnection(
        id: 'instagram-connected-later',
        platform: CrosspostingPlatform.instagram,
        status: CrosspostingConnectionStatus.connected,
      );
      const youtubeConnection = CrosspostingConnection(
        id: 'youtube-connected',
        platform: CrosspostingPlatform.youtube,
        status: CrosspostingConnectionStatus.connected,
        externalAccountName: 'Divine Creator',
      );
      when(apiClient.getPlatforms).thenAnswer(
        (_) async => const [
          CrosspostingPlatformInfo(
            platform: CrosspostingPlatform.youtube,
            enabled: true,
            supportsAutomatic: false,
          ),
          CrosspostingPlatformInfo(
            platform: CrosspostingPlatform.tiktok,
            enabled: false,
            supportsAutomatic: true,
          ),
          CrosspostingPlatformInfo(
            platform: CrosspostingPlatform.instagram,
            enabled: true,
            supportsAutomatic: true,
          ),
        ],
      );
      when(apiClient.getConnections).thenAnswer(
        (_) async => const [
          CrosspostingConnection(
            id: 'instagram-disconnected',
            platform: CrosspostingPlatform.instagram,
            status: CrosspostingConnectionStatus.disconnected,
          ),
          instagramConnected,
          instagramReauth,
          youtubeConnection,
        ],
      );
      when(apiClient.getPreferences).thenAnswer(
        (_) async => const [
          CrosspostingPreference(
            platform: CrosspostingPlatform.instagram,
            mode: CrosspostingMode.automatic,
            connectionId: 'instagram-reauth',
          ),
          CrosspostingPreference(
            platform: CrosspostingPlatform.tiktok,
            mode: CrosspostingMode.manual,
          ),
        ],
      );

      final settings = await repository.loadSettings();

      expect(
        settings,
        const [
          CrosspostingPlatformSettings(
            platform: CrosspostingPlatform.youtube,
            supportsAutomatic: false,
            connection: youtubeConnection,
            mode: CrosspostingMode.disabled,
          ),
          CrosspostingPlatformSettings(
            platform: CrosspostingPlatform.instagram,
            supportsAutomatic: true,
            connection: instagramConnected,
            mode: CrosspostingMode.automatic,
          ),
        ],
      );
      expect(settings.first.isConnected, isTrue);
      expect(settings.first.needsReauth, isFalse);
      expect(settings.last.isConnected, isTrue);
      expect(settings.last.needsReauth, isFalse);
    });

    test(
      'falls back to connected when preference connection is unusable',
      () async {
        const connected = CrosspostingConnection(
          id: 'connected',
          platform: CrosspostingPlatform.instagram,
          status: CrosspostingConnectionStatus.connected,
        );
        when(apiClient.getPlatforms).thenAnswer(
          (_) async => const [
            CrosspostingPlatformInfo(
              platform: CrosspostingPlatform.instagram,
              enabled: true,
              supportsAutomatic: true,
            ),
          ],
        );
        when(apiClient.getConnections).thenAnswer(
          (_) async => const [
            CrosspostingConnection(
              id: 'reauth-first',
              platform: CrosspostingPlatform.instagram,
              status: CrosspostingConnectionStatus.needsReauth,
            ),
            CrosspostingConnection(
              id: 'disconnected-preference',
              platform: CrosspostingPlatform.instagram,
              status: CrosspostingConnectionStatus.disconnected,
            ),
            connected,
          ],
        );
        when(apiClient.getPreferences).thenAnswer(
          (_) async => const [
            CrosspostingPreference(
              platform: CrosspostingPlatform.instagram,
              mode: CrosspostingMode.manual,
              connectionId: 'disconnected-preference',
            ),
          ],
        );

        final settings = await repository.loadSettings();

        expect(settings.single.connection, same(connected));
      },
    );

    test(
      'falls back to needs reauth when no connected record exists',
      () async {
        const reauth = CrosspostingConnection(
          id: 'reauth',
          platform: CrosspostingPlatform.x,
          status: CrosspostingConnectionStatus.needsReauth,
        );
        when(apiClient.getPlatforms).thenAnswer(
          (_) async => const [
            CrosspostingPlatformInfo(
              platform: CrosspostingPlatform.x,
              enabled: true,
              supportsAutomatic: true,
            ),
          ],
        );
        when(apiClient.getConnections).thenAnswer(
          (_) async => const [
            CrosspostingConnection(
              id: 'disconnected',
              platform: CrosspostingPlatform.x,
              status: CrosspostingConnectionStatus.disconnected,
            ),
            reauth,
          ],
        );
        when(apiClient.getPreferences).thenAnswer(
          (_) async => const [
            CrosspostingPreference(
              platform: CrosspostingPlatform.x,
              mode: CrosspostingMode.disabled,
              connectionId: 'missing',
            ),
          ],
        );

        final settings = await repository.loadSettings();

        expect(settings.single.connection, same(reauth));
      },
    );

    test('ignores disconnected connection records', () async {
      when(apiClient.getPlatforms).thenAnswer(
        (_) async => const [
          CrosspostingPlatformInfo(
            platform: CrosspostingPlatform.x,
            enabled: true,
            supportsAutomatic: true,
          ),
        ],
      );
      when(apiClient.getConnections).thenAnswer(
        (_) async => const [
          CrosspostingConnection(
            id: 'old-x',
            platform: CrosspostingPlatform.x,
            status: CrosspostingConnectionStatus.disconnected,
          ),
        ],
      );
      when(apiClient.getPreferences).thenAnswer((_) async => const []);

      final settings = await repository.loadSettings();

      expect(settings.single.connection, isNull);
      expect(settings.single.mode, CrosspostingMode.disabled);
    });

    test(
      'clamps a stale automatic preference to manual when unsupported',
      () async {
        when(apiClient.getPlatforms).thenAnswer(
          (_) async => const [
            CrosspostingPlatformInfo(
              platform: CrosspostingPlatform.x,
              enabled: true,
              supportsAutomatic: false,
            ),
          ],
        );
        when(apiClient.getConnections).thenAnswer((_) async => const []);
        when(apiClient.getPreferences).thenAnswer(
          (_) async => const [
            CrosspostingPreference(
              platform: CrosspostingPlatform.x,
              mode: CrosspostingMode.automatic,
            ),
          ],
        );

        final settings = await repository.loadSettings();

        // The load no longer throws; the stale preference degrades to manual so
        // one inconsistent server value cannot brick the settings screen.
        expect(settings.single.platform, CrosspostingPlatform.x);
        expect(settings.single.supportsAutomatic, isFalse);
        expect(settings.single.mode, CrosspostingMode.manual);
      },
    );
  });

  test('platform settings are immutable values with mode copyWith', () {
    const original = CrosspostingPlatformSettings(
      platform: CrosspostingPlatform.instagram,
      supportsAutomatic: true,
      mode: CrosspostingMode.disabled,
    );

    final updated = original.copyWith(mode: CrosspostingMode.manual);

    expect(updated.mode, CrosspostingMode.manual);
    expect(updated.platform, original.platform);
    expect(updated.supportsAutomatic, original.supportsAutomatic);
    expect(updated.connection, original.connection);
    expect(
      original,
      const CrosspostingPlatformSettings(
        platform: CrosspostingPlatform.instagram,
        supportsAutomatic: true,
        mode: CrosspostingMode.disabled,
      ),
    );
  });

  test('platform settings compare equivalent connection values', () {
    // Deliberately not `const`: Dart canonicalizes identical const objects to
    // one instance, which would satisfy the equality assertion below by
    // identity and let it pass even if `props` were wrong.
    // ignore: prefer_const_constructors
    final first = CrosspostingPlatformSettings(
      platform: CrosspostingPlatform.instagram,
      supportsAutomatic: true,
      // ignore: prefer_const_constructors
      connection: CrosspostingConnection(
        id: 'connection-id',
        platform: CrosspostingPlatform.instagram,
        status: CrosspostingConnectionStatus.connected,
        externalAccountId: 'account-id',
        externalAccountName: '@creator',
      ),
      mode: CrosspostingMode.manual,
    );
    // ignore: prefer_const_constructors
    final second = CrosspostingPlatformSettings(
      platform: CrosspostingPlatform.instagram,
      supportsAutomatic: true,
      // ignore: prefer_const_constructors
      connection: CrosspostingConnection(
        id: 'connection-id',
        platform: CrosspostingPlatform.instagram,
        status: CrosspostingConnectionStatus.connected,
        externalAccountId: 'account-id',
        externalAccountName: '@creator',
      ),
      mode: CrosspostingMode.manual,
    );

    expect(first, second);
  });

  test('startConnection forwards platform and return URL', () async {
    final returnUrl = Uri.parse('https://divine.video/app/callback');
    final start = CrosspostingStart(
      authorizationUrl: Uri.parse('https://instagram.com/oauth'),
      state: 'oauth-state',
    );
    when(
      () => apiClient.startConnection(
        CrosspostingPlatform.instagram,
        returnUrl: returnUrl,
      ),
    ).thenAnswer((_) async => start);

    final result = await repository.startConnection(
      CrosspostingPlatform.instagram,
      returnUrl: returnUrl,
    );

    expect(result, same(start));
    verify(
      () => apiClient.startConnection(
        CrosspostingPlatform.instagram,
        returnUrl: returnUrl,
      ),
    ).called(1);
  });

  test('disconnect forwards platform and connection ID', () async {
    when(
      () => apiClient.disconnect(CrosspostingPlatform.x, 'connection-id'),
    ).thenAnswer((_) async {});

    await repository.disconnect(CrosspostingPlatform.x, 'connection-id');

    verify(
      () => apiClient.disconnect(CrosspostingPlatform.x, 'connection-id'),
    ).called(1);
  });

  test('setMode forwards platform and mode', () async {
    when(
      () => apiClient.setMode(
        CrosspostingPlatform.youtube,
        CrosspostingMode.automatic,
      ),
    ).thenAnswer((_) async {});

    await repository.setMode(
      CrosspostingPlatform.youtube,
      CrosspostingMode.automatic,
    );

    verify(
      () => apiClient.setMode(
        CrosspostingPlatform.youtube,
        CrosspostingMode.automatic,
      ),
    ).called(1);
  });
}
