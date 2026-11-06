// ABOUTME: Pins how likes and reposts repositories meet a signer that only
// ABOUTME: arrives after startup: a new identity swaps the Nostr client, the
// ABOUTME: repositories rebuild on it, and the new instance resolves the key.

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:db_client/db_client.dart' show AppDbClient;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/models/nostr_signature_verification_policy.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/crash_reporting_provider.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/relay_statistics_service.dart';
import 'package:reposts_repository/reposts_repository.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNostrSigner extends Mock implements NostrSigner {}

class _MockAppDbClient extends Mock implements AppDbClient {}

class _MockRelayStatisticsService extends Mock
    implements RelayStatisticsService {}

class _MockConnectionStatusService extends Mock
    implements ConnectionStatusService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockContentPolicyEngine extends Mock implements ContentPolicyEngine {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _MockCrashReportingService extends Mock
    implements CrashReportingService {}

/// What one client the factory vended was asked, in order.
class _ClientRecord {
  _ClientRecord(this.signer);

  final NostrSigner? signer;
  final List<String?> resolvedKeys = [];
  final List<List<String>?> subscribedAuthors = [];
  final List<List<String>?> queriedAuthors = [];
}

void main() {
  const pubkey =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';

  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(<String>[]);
  });

  late _MockAuthService authService;
  late StreamController<AuthState> authStates;
  late List<_ClientRecord> clients;
  late NostrIdentity? currentIdentity;
  late AuthState currentAuthState;

  NostrClient recordingFactory({
    NostrSigner? signer,
    RelayStatisticsService? statisticsService,
    EnvironmentConfig? environmentConfig,
    AppDbClient? dbClient,
  }) {
    final record = _ClientRecord(signer);
    clients.add(record);
    final client = _MockNostrClient();
    // Same contract as the real NostrClient.resolvePublicKey, which
    // nostr_service_factory_test.dart pins against a real client: ask the
    // signer, and report an empty key as null.
    when(client.resolvePublicKey).thenAnswer((_) async {
      final key = await (signer ?? const UnauthenticatedSigner())
          .getPublicKey();
      final resolved = (key == null || key.isEmpty) ? null : key;
      record.resolvedKeys.add(resolved);
      return resolved;
    });
    when(() => client.hasKeys).thenReturn(signer != null);
    when(() => client.publicKey).thenReturn('');
    when(client.initialize).thenAnswer((_) async {});
    when(client.ensureUserRemovedRelaysLoaded).thenAnswer((_) async {});
    when(() => client.addRelays(any())).thenAnswer((_) async => 0);
    when(
      () => client.subscribe(
        any(),
        subscriptionId: any(named: 'subscriptionId'),
      ),
    ).thenAnswer((invocation) {
      final filters = invocation.positionalArguments.first as List<Filter>;
      record.subscribedAuthors.add(filters.first.authors);
      return const Stream<Event>.empty();
    });
    when(
      () => client.queryEventsDetailed(
        any(),
        requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
      ),
    ).thenAnswer((invocation) async {
      final filters = invocation.positionalArguments.first as List<Filter>;
      record.queriedAuthors.add(filters.first.authors);
      return (events: <Event>[], timedOut: false, noRelays: false);
    });
    when(() => client.queryEvents(any())).thenAnswer((invocation) async {
      final filters = invocation.positionalArguments.first as List<Filter>;
      record.queriedAuthors.add(filters.first.authors);
      return <Event>[];
    });
    when(() => client.unsubscribe(any())).thenAnswer((_) async {});
    when(client.dispose).thenAnswer((_) async {});
    return client;
  }

  setUp(() {
    authService = _MockAuthService();
    authStates = StreamController<AuthState>.broadcast();
    clients = [];
    currentIdentity = null;
    currentAuthState = AuthState.unauthenticated;

    when(() => authService.currentIdentity).thenAnswer((_) => currentIdentity);
    when(() => authService.authState).thenAnswer((_) => currentAuthState);
    when(() => authService.authStateStream)
        .thenAnswer((_) => authStates.stream);
    // Null keeps both repositories off local storage, which is not what this
    // file is about; the key-resolution path does not read it.
    when(() => authService.currentPublicKeyHex).thenReturn(null);
    when(() => authService.currentNpub).thenReturn(null);
    when(() => authService.userRelays).thenReturn([]);
    when(() => authService.canPublishNostrWritesNow).thenReturn(false);
    when(
      () => authService.registerUserRelaysDiscoveredCallback(any()),
    ).thenReturn(null);
    when(
      () => authService.registerBootstrapRelayListCallback(any()),
    ).thenReturn(null);
  });

  tearDown(() => authStates.close());

  ProviderContainer createContainer() {
    final connectionStatus = _MockConnectionStatusService();
    when(() => connectionStatus.isOnline).thenReturn(true);
    return ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        relayStatisticsServiceProvider.overrideWithValue(
          _MockRelayStatisticsService(),
        ),
        currentEnvironmentProvider.overrideWithValue(
          EnvironmentConfig.production,
        ),
        appDbClientProvider.overrideWithValue(_MockAppDbClient()),
        nostrClientFactoryProvider.overrideWithValue(recordingFactory),
        nostrSignatureVerificationPolicyProvider.overrideWithValue(
          NostrSignatureVerificationPolicy.nonDivineRelays,
        ),
        connectionStatusServiceProvider.overrideWithValue(connectionStatus),
        pendingActionServiceProvider.overrideWithValue(null),
        contentBlocklistRepositoryProvider.overrideWithValue(
          _MockContentBlocklistRepository(),
        ),
        contentPolicyEngineProvider.overrideWithValue(
          _MockContentPolicyEngine(),
        ),
        funnelcakeApiClientProvider.overrideWithValue(
          _MockFunnelcakeApiClient(),
        ),
        crashReportingServiceProvider.overrideWithValue(
          _MockCrashReportingService(),
        ),
      ],
    );
  }

  /// Sign in the way AuthService does: identity first, then the state event.
  Future<void> signIn(NostrIdentity identity) async {
    currentIdentity = identity;
    currentAuthState = AuthState.authenticated;
    authStates.add(AuthState.authenticated);
    await pumpEventQueue();
  }

  KeycastNostrIdentity keycastIdentityWithoutRpc() {
    final rpc = _MockNostrSigner();
    when(rpc.getPublicKey).thenAnswer((_) async => null);
    return KeycastNostrIdentity(pubkey: pubkey, rpcSigner: rpc);
  }

  group('likesRepositoryProvider', () {
    test('an identity that appears after startup gets a keyed client and a '
        'synced, subscribed repository', () async {
      final container = createContainer();
      addTearDown(container.dispose);
      final repositories = <LikesRepository>[];
      container.listen(
        likesRepositoryProvider,
        (_, next) => repositories.add(next),
        fireImmediately: true,
      );
      await pumpEventQueue();

      await signIn(keycastIdentityWithoutRpc());

      expect(clients, hasLength(2));
      final (keyless, keyed) = (clients.first, clients.last);
      expect(keyless.signer, isNull);
      // Resolved once, by the signed-out instance: nothing was built over the
      // keyless client after the identity appeared.
      expect(keyless.resolvedKeys, equals([null]));
      expect(keyless.subscribedAuthors, isEmpty);
      expect(keyless.queriedAuthors, isEmpty);
      expect(keyed.signer, isA<KeycastNostrIdentity>());
      expect(keyed.resolvedKeys, everyElement(equals(pubkey)));
      expect(keyed.subscribedAuthors, contains(equals([pubkey])));
      expect(keyed.queriedAuthors, contains(equals([pubkey])));
      expect(repositories, hasLength(greaterThan(1)));
      expect(repositories.toSet(), hasLength(repositories.length));
    });
  });

  group('repostsRepositoryProvider', () {
    test('an identity that appears after startup gets a keyed client and a '
        'subscribed repository', () async {
      final container = createContainer();
      addTearDown(container.dispose);
      final repositories = <RepostsRepository>[];
      container.listen(
        repostsRepositoryProvider,
        (_, next) => repositories.add(next),
        fireImmediately: true,
      );
      await pumpEventQueue();

      await signIn(keycastIdentityWithoutRpc());

      expect(clients, hasLength(2));
      final (keyless, keyed) = (clients.first, clients.last);
      expect(keyless.resolvedKeys, equals([null]));
      expect(keyless.subscribedAuthors, isEmpty);
      expect(keyed.resolvedKeys, everyElement(equals(pubkey)));
      expect(keyed.subscribedAuthors, contains(equals([pubkey])));
      expect(repositories, hasLength(greaterThan(1)));
    });
  });
}
