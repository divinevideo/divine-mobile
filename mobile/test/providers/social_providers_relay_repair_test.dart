// ABOUTME: Tests that the DM retry sweeps run on the connectivity owner's
// ABOUTME: transitions and when a relay connects, and leave relay repair to
// ABOUTME: the connectivity owner (#6046, #8990, #8516).

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

class _MockDmReactionsRepository extends Mock
    implements DmReactionsRepository {}

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

const _pubkey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _relay = 'wss://relay.example';

Map<String, RelayConnectionStatus> _relayIs(RelayState state) => {
  _relay: RelayConnectionStatus(url: _relay, state: state),
};

/// Answers the sweeps' own connectivity probe: online.
void _answerConnectivityProbeOnline() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  messenger.setMockMethodCallHandler(
    channel,
    (call) async => call.method == 'check' ? ['wifi'] : null,
  );
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
}

/// A client whose only relay starts disconnected; [statuses] carries the
/// pool's later snapshots.
_MockNostrClient _clientWithRelayStatuses(
  StreamController<Map<String, RelayConnectionStatus>> statuses,
) {
  final client = _MockNostrClient();
  when(() => client.hasKeys).thenReturn(true);
  when(() => client.publicKey).thenReturn(_pubkey);
  when(
    () => client.relayStatuses,
  ).thenReturn(_relayIs(RelayState.disconnected));
  when(() => client.relayStatusStream).thenAnswer((_) => statuses.stream);
  return client;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('outgoingDmRetryServiceProvider', () {
    const pubkey = _pubkey;

    late StreamController<ConnectivityTransition> transitions;
    late StreamController<Map<String, RelayConnectionStatus>> relayStatuses;
    late _MockOutgoingDmsDao dao;
    late _MockNostrClient client;
    late ProviderContainer container;

    setUp(() {
      // The sweep probes connectivity itself. A real plugin call resolves at
      // an unpredictable point in a test, so answer it here: online.
      _answerConnectivityProbeOnline();

      transitions = StreamController<ConnectivityTransition>.broadcast();
      addTearDown(transitions.close);
      relayStatuses =
          StreamController<Map<String, RelayConnectionStatus>>.broadcast();
      addTearDown(relayStatuses.close);

      client = _clientWithRelayStatuses(relayStatuses);
      when(client.forceReconnectAll).thenAnswer(
        (_) async => ForceReconnectOutcome.completed,
      );

      dao = _MockOutgoingDmsDao();
      when(
        () => dao.getRetryableForOwner(
          ownerPubkey: any(named: 'ownerPubkey'),
          maxRetries: any(named: 'maxRetries'),
          environment: any(named: 'environment'),
        ),
      ).thenAnswer((_) async => []);
      when(
        () => dao.getStillPendingForOwner(
          any(),
          environment: any(named: 'environment'),
        ),
      ).thenAnswer((_) async => []);
      when(
        () => dao.getExhaustedHeldForOwner(
          ownerPubkey: any(named: 'ownerPubkey'),
          maxRetries: any(named: 'maxRetries'),
          environment: any(named: 'environment'),
        ),
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
          environment: any(named: 'environment'),
        ),
      ).called(2);
    });

    test('sweeps when a relay connects, and not again while it stays '
        'connected (#8516)', () async {
      container.listen(outgoingDmRetryServiceProvider, (_, _) {});
      await pumpEventQueue();

      relayStatuses.add(_relayIs(RelayState.connected));
      await pumpEventQueue();
      verify(
        () => dao.getRetryableForOwner(
          ownerPubkey: pubkey,
          maxRetries: any(named: 'maxRetries'),
          environment: any(named: 'environment'),
        ),
      ).called(1);

      // A later snapshot in which the same relay is still connected is no
      // new reason to sweep.
      relayStatuses.add(_relayIs(RelayState.connected));
      await pumpEventQueue();
      verifyNever(
        () => dao.getRetryableForOwner(
          ownerPubkey: pubkey,
          maxRetries: any(named: 'maxRetries'),
          environment: any(named: 'environment'),
        ),
      );
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
  group('dmReactionRetryServiceProvider', () {
    late StreamController<Map<String, RelayConnectionStatus>> relayStatuses;
    late _MockDmReactionsRepository reactions;
    late ProviderContainer container;

    setUp(() {
      _answerConnectivityProbeOnline();
      relayStatuses =
          StreamController<Map<String, RelayConnectionStatus>>.broadcast();
      addTearDown(relayStatuses.close);
      final client = _clientWithRelayStatuses(relayStatuses);

      reactions = _MockDmReactionsRepository();
      when(() => reactions.isInitialized).thenReturn(true);
      when(
        () => reactions.retryableReactionWork,
      ).thenAnswer((_) => const Stream<void>.empty());
      when(reactions.retryableReactions).thenAnswer((_) async => []);
      when(reactions.retryableDeletions).thenAnswer((_) async => []);

      final authService = _MockAuthService();
      when(() => authService.currentPublicKeyHex).thenReturn(_pubkey);

      container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          nostrSessionProvider.overrideWith(
            () => _ReadyNostrSession(
              NostrSessionReadiness.nostrReady(pubkey: _pubkey, client: client),
            ),
          ),
          nostrServiceProvider.overrideWith(() => _FixedNostrService(client)),
          dmRepositoryProvider.overrideWithValue(_MockDmRepository()),
          dmReactionsRepositoryProvider.overrideWithValue(reactions),
          crashReportingServiceProvider.overrideWithValue(
            _MockCrashReportingService(),
          ),
          appForegroundProvider.overrideWith(_Backgrounded.new),
        ],
      );
      addTearDown(container.dispose);
    });

    test('sweeps each time a relay connects, and not while it stays '
        'connected (#8516)', () async {
      container.listen(dmReactionRetryServiceProvider, (_, _) {});
      await pumpEventQueue();
      verifyNever(reactions.retryableReactions);

      relayStatuses.add(_relayIs(RelayState.connected));
      await pumpEventQueue();
      verify(reactions.retryableReactions).called(1);

      relayStatuses.add(_relayIs(RelayState.connected));
      await pumpEventQueue();
      verifyNever(reactions.retryableReactions);

      relayStatuses
        ..add(_relayIs(RelayState.disconnected))
        ..add(_relayIs(RelayState.connected));
      await pumpEventQueue();
      verify(reactions.retryableReactions).called(1);
    });
  });
}
