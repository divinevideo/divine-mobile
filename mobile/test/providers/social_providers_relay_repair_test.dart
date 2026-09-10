// ABOUTME: Tests that the DM retry sweep runs on the connectivity owner's
// ABOUTME: transitions and leaves relay repair to that owner (#6046, #8990).

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/crash_reporting_provider.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/relay_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/connectivity_transition_monitor.dart';
import 'package:openvine/services/crash_reporting_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockAppDatabase extends Mock implements AppDatabase {}

class _MockCrashReportingService extends Mock
    implements CrashReportingService {}

class _MockDmRepository extends Mock implements DmRepository {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockOutgoingDmsDao extends Mock implements OutgoingDmsDao {}

class _ReadyNostrSession extends NostrSession {
  _ReadyNostrSession(this._readiness);

  final NostrSessionReadiness _readiness;

  @override
  NostrSessionReadiness build() => _readiness;
}

class _FixedNostrService extends NostrService {
  _FixedNostrService(this._client);

  final NostrClient _client;

  @override
  NostrClient build() => _client;
}

/// Keeps the foreground trigger quiet, so every sweep comes from connectivity.
class _Backgrounded extends AppForeground {
  @override
  bool build() => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('outgoingDmRetryServiceProvider', () {
    const pubkey =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    late StreamController<ConnectivityTransition> transitions;
    late _MockOutgoingDmsDao dao;
    late _MockNostrClient client;
    late ProviderContainer container;

    setUp(() {
      // The sweep probes connectivity itself. A real plugin call resolves at
      // an unpredictable point in a test, so answer it here: online.
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'check' ? ['wifi'] : null,
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      transitions = StreamController<ConnectivityTransition>.broadcast();
      addTearDown(transitions.close);

      client = _MockNostrClient();
      when(() => client.hasKeys).thenReturn(true);
      when(() => client.publicKey).thenReturn(pubkey);
      when(client.forceReconnectAll).thenAnswer((_) async {});

      dao = _MockOutgoingDmsDao();
      when(
        () => dao.getRetryableForOwner(
          ownerPubkey: any(named: 'ownerPubkey'),
          maxRetries: any(named: 'maxRetries'),
        ),
      ).thenAnswer((_) async => []);
      when(
        () => dao.getStillPendingForOwner(any()),
      ).thenAnswer((_) async => []);
      final database = _MockAppDatabase();
      when(() => database.outgoingDmsDao).thenReturn(dao);

      final dmRepository = _MockDmRepository();
      when(
        () => dmRepository.retryableOutgoingWork,
      ).thenAnswer((_) => const Stream<void>.empty());
      when(dmRepository.retryableMessageDeletions).thenAnswer((_) async => []);

      final authService = _MockAuthService();
      when(() => authService.currentPublicKeyHex).thenReturn(pubkey);

      container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          nostrSessionProvider.overrideWith(
            () => _ReadyNostrSession(
              NostrSessionReadiness.nostrReady(pubkey: pubkey, client: client),
            ),
          ),
          nostrServiceProvider.overrideWith(() => _FixedNostrService(client)),
          dmRepositoryProvider.overrideWithValue(dmRepository),
          databaseProvider.overrideWithValue(database),
          crashReportingServiceProvider.overrideWithValue(
            _MockCrashReportingService(),
          ),
          appForegroundProvider.overrideWith(_Backgrounded.new),
          connectivityRelayReconnectProvider.overrideWithValue(
            transitions.stream,
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    test('sweeps once for each connectivity transition', () async {
      // Each transition, offline included, starts a pass; which pass runs is
      // the service's own probe, answered online here.
      container.listen(outgoingDmRetryServiceProvider, (_, _) {});
      await pumpEventQueue();

      transitions.add(ConnectivityTransition.offline);
      await pumpEventQueue();
      transitions.add(ConnectivityTransition.online);
      await pumpEventQueue();

      verify(
        () => dao.getRetryableForOwner(
          ownerPubkey: pubkey,
          maxRetries: any(named: 'maxRetries'),
        ),
      ).called(2);
    });

    test('leaves relay repair to the connectivity owner', () async {
      // Repairing here as well reconnected the pool twice per network change.
      container.listen(outgoingDmRetryServiceProvider, (_, _) {});
      await pumpEventQueue();

      transitions.add(ConnectivityTransition.online);
      await pumpEventQueue();

      verifyNever(client.forceReconnectAll);
    });
  });
}
