// ABOUTME: Tests the per-account post Live Activity sync: binding, the signer
// ABOUTME: and flag gate, ending on account exit, and current-only sweeps.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/device_scope.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/notifications_providers.dart';
import 'package:openvine/providers/post_live_activity_providers.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/post_live_activity_registrar.dart';
import 'package:post_live_activity_repository/post_live_activity_repository.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockDeviceScope extends Mock implements DeviceScope {}

class _MockSwitchController extends Mock implements AccountSwitchController {}

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeRepository extends Fake implements PostLiveActivityRepository {
  @override
  bool featureEnabled = true;

  final calls = <String>[];

  @override
  Future<void> endAll() async => calls.add('endAll');

  @override
  Future<void> endLocally({required String ownerPubkey}) async =>
      calls.add('endLocally:$ownerPubkey');

  @override
  Future<void> sweep({required String? currentOwnerPubkey}) async =>
      calls.add('sweep:$currentOwnerPubkey');
}

class _FakeRegistrar extends Fake implements PostLiveActivityRegistrar {
  final attached = <LiveActivityAccountBinding>[];

  @override
  Object attach(LiveActivityAccountBinding binding) {
    attached.add(binding);
    return binding;
  }

  @override
  void detach(Object handle) => attached.remove(handle);
}

class _TestNostrSession extends NostrSession {
  _TestNostrSession(this._initial);

  final NostrSessionReadiness _initial;

  @override
  NostrSessionReadiness build() => _initial;

  void setReadiness(NostrSessionReadiness readiness) => state = readiness;
}

class _Flag extends Notifier<bool> {
  @override
  bool build() => true;

  void set({required bool enabled}) => state = enabled;
}

final _flagProvider = NotifierProvider<_Flag, bool>(_Flag.new);

const _ownerA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _ownerB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

Future<void> _noopTeardown() async {}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(_noopTeardown);
  });

  group('signsWithoutPrompting', () {
    test('allows only the signers that never ask the person', () {
      final expected = {
        AuthenticationSource.divineOAuth: true,
        AuthenticationSource.importedKeys: true,
        AuthenticationSource.automatic: true,
        AuthenticationSource.bunker: false,
        AuthenticationSource.amber: false,
        AuthenticationSource.nip07: false,
        AuthenticationSource.none: false,
      };
      expect(expected.keys, unorderedEquals(AuthenticationSource.values));
      for (final source in AuthenticationSource.values) {
        expect(
          signsWithoutPrompting(source),
          expected[source],
          reason: '$source',
        );
      }
    });
  });

  group('postLiveActivitySyncProvider', () {
    late _MockAuthService auth;
    late _MockDeviceScope deviceScope;
    late _MockSwitchController switchController;
    late _FakeRepository repository;
    late _FakeRegistrar registrar;
    late StreamController<AuthState> authStates;
    late List<BeforeSessionTeardownCallback> teardownCallbacks;
    late _TestNostrSession session;
    ProviderContainer? currentContainer;
    late NostrIdentity? identity;
    late AuthenticationSource source;
    late AuthState authState;

    NostrSessionReadiness ready(String pubkey) {
      final client = _MockNostrClient();
      when(() => client.hasKeys).thenReturn(true);
      when(() => client.publicKey).thenReturn(pubkey);
      return NostrSessionReadiness.nostrReady(pubkey: pubkey, client: client);
    }

    void signIn(
      String pubkey, {
      AuthenticationSource as = AuthenticationSource.divineOAuth,
    }) {
      identity = PubkeyOnlyNostrIdentity(pubkey: pubkey);
      source = as;
      authState = AuthState.authenticated;
    }

    setUp(() {
      auth = _MockAuthService();
      deviceScope = _MockDeviceScope();
      switchController = _MockSwitchController();
      repository = _FakeRepository();
      registrar = _FakeRegistrar();
      authStates = StreamController<AuthState>.broadcast();
      teardownCallbacks = [];
      currentContainer = null;
      identity = null;
      source = AuthenticationSource.none;
      authState = AuthState.checking;

      when(() => deviceScope.switchController).thenReturn(switchController);
      when(
        () => switchController.currentContainer,
      ).thenAnswer((_) => currentContainer);
      when(() => auth.currentIdentity).thenAnswer((_) => identity);
      when(() => auth.currentPublicKeyHex).thenAnswer((_) => identity?.pubkey);
      when(() => auth.authenticationSource).thenAnswer((_) => source);
      when(() => auth.authState).thenAnswer((_) => authState);
      when(() => auth.authStateStream).thenAnswer((_) => authStates.stream);
      when(() => auth.registerBeforeSessionTeardownCallback(any())).thenAnswer(
        (invocation) {
          final callback =
              invocation.positionalArguments.first
                  as BeforeSessionTeardownCallback;
          teardownCallbacks.add(callback);
          return () => teardownCallbacks.remove(callback);
        },
      );
    });

    tearDown(() async {
      await authStates.close();
    });

    ProviderContainer build(
      NostrSessionReadiness initialSession, {
      bool makeCurrent = true,
    }) {
      session = _TestNostrSession(initialSession);
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          nostrSessionProvider.overrideWith(() => session),
          postLiveActivityRepositoryProvider.overrideWithValue(repository),
          postLiveActivityRegistrarProvider.overrideWithValue(registrar),
          deviceScopeProvider.overrideWithValue(deviceScope),
          pushNotificationServiceProvider.overrideWithValue(null),
          isFeatureEnabledProvider(
            FeatureFlag.postLiveActivity,
          ).overrideWith((ref) => ref.watch(_flagProvider)),
        ],
      );
      addTearDown(container.dispose);
      if (makeCurrent) currentContainer = container;
      // Listened, as AppRootSideEffects watches it; a merely read provider
      // is paused and stops hearing its own dependencies.
      container.listen(postLiveActivitySyncProvider, (_, _) {});
      return container;
    }

    /// Emits [state] after the auth service changed underneath, as the real
    /// service does.
    Future<void> emitAuth(AuthState state) async {
      authState = state;
      authStates.add(state);
      await pumpEventQueue();
    }

    Future<void> resume() async {
      binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpEventQueue();
    }

    group('signer gate', () {
      for (final eligible in [
        AuthenticationSource.divineOAuth,
        AuthenticationSource.importedKeys,
        AuthenticationSource.automatic,
      ]) {
        test('a $eligible account binds and lets activities start', () async {
          signIn(_ownerA, as: eligible);
          build(ready(_ownerA));
          await pumpEventQueue();

          expect(repository.featureEnabled, isTrue);
          expect(registrar.attached.single.ownerPubkey, _ownerA);
          expect(repository.calls, isNot(contains('endAll')));
        });
      }

      for (final prompting in [
        AuthenticationSource.amber,
        AuthenticationSource.bunker,
        AuthenticationSource.nip07,
      ]) {
        test('a $prompting account never starts an activity', () async {
          signIn(_ownerA, as: prompting);
          build(ready(_ownerA));
          await pumpEventQueue();

          expect(repository.featureEnabled, isFalse);
          expect(registrar.attached, isEmpty);
          expect(repository.calls, contains('endAll'));
        });
      }

      test('becoming an Amber account ends a running activity', () async {
        signIn(_ownerA);
        build(ready(_ownerA));
        await pumpEventQueue();
        expect(registrar.attached, hasLength(1));
        expect(repository.calls, isNot(contains('endAll')));

        signIn(_ownerA, as: AuthenticationSource.amber);
        await emitAuth(AuthState.authenticated);
        // Equal auth states do not re-emit; the session rebuild does.
        session.setReadiness(
          const NostrSessionReadiness.identityKnown(pubkey: _ownerA),
        );
        session.setReadiness(ready(_ownerA));
        await pumpEventQueue();

        expect(repository.featureEnabled, isFalse);
        expect(repository.calls.where((c) => c == 'endAll'), hasLength(1));
        expect(registrar.attached, isEmpty);
      });
    });

    group('feature flag', () {
      test('off leaves no binding and ends running activities', () async {
        signIn(_ownerA);
        build(ready(_ownerA));
        await pumpEventQueue();
        expect(registrar.attached, hasLength(1));

        currentContainer!.read(_flagProvider.notifier).set(enabled: false);
        await pumpEventQueue();

        expect(repository.featureEnabled, isFalse);
        expect(registrar.attached, isEmpty);
        expect(repository.calls.where((c) => c == 'endAll'), hasLength(1));
      });

      test('off from the start never binds', () async {
        signIn(_ownerA);
        session = _TestNostrSession(ready(_ownerA));
        final container = ProviderContainer(
          overrides: [
            authServiceProvider.overrideWithValue(auth),
            nostrSessionProvider.overrideWith(() => session),
            postLiveActivityRepositoryProvider.overrideWithValue(repository),
            postLiveActivityRegistrarProvider.overrideWithValue(registrar),
            deviceScopeProvider.overrideWithValue(deviceScope),
            pushNotificationServiceProvider.overrideWithValue(null),
            isFeatureEnabledProvider(
              FeatureFlag.postLiveActivity,
            ).overrideWithValue(false),
          ],
        );
        addTearDown(container.dispose);
        currentContainer = container;
        // Listened, as AppRootSideEffects watches it; a merely read provider
        // is paused and stops hearing its own dependencies.
        container.listen(postLiveActivitySyncProvider, (_, _) {});
        await pumpEventQueue();

        expect(repository.featureEnabled, isFalse);
        expect(registrar.attached, isEmpty);
        expect(repository.calls, contains('endAll'));
      });
    });

    group('binding', () {
      test('waits for the session to be ready before binding', () async {
        signIn(_ownerA);
        build(const NostrSessionReadiness.identityKnown(pubkey: _ownerA));
        await pumpEventQueue();
        expect(registrar.attached, isEmpty);

        session.setReadiness(ready(_ownerA));
        await pumpEventQueue();

        expect(registrar.attached.single.ownerPubkey, _ownerA);
        expect(registrar.attached.single.isActiveAccount(), isTrue);
      });

      test('the incoming account sweeps once after it binds', () async {
        signIn(_ownerB);
        build(ready(_ownerB));
        await pumpEventQueue();

        expect(repository.calls, ['sweep:$_ownerB']);
      });

      test('dispose detaches the binding it attached', () async {
        signIn(_ownerA);
        final container = build(ready(_ownerA));
        await pumpEventQueue();
        expect(registrar.attached, hasLength(1));

        container.dispose();

        expect(registrar.attached, isEmpty);
        expect(teardownCallbacks, isEmpty);
      });
    });

    group('ending on account exit', () {
      test('sign-out ends the activity locally even when the teardown '
          'budget ran out before its callback (RF1)', () async {
        signIn(_ownerA);
        build(ready(_ownerA));
        await pumpEventQueue();
        expect(teardownCallbacks, hasLength(1));
        repository.calls.clear();

        // The budget is spent: the teardown callback never runs. The
        // session is cleared and auth reports signed out.
        identity = null;
        source = AuthenticationSource.none;
        await emitAuth(AuthState.unauthenticated);
        session.setReadiness(
          const NostrSessionReadiness.tearingDown(pubkey: _ownerA),
        );
        session.setReadiness(const NostrSessionReadiness.signedOut());
        await pumpEventQueue();

        expect(
          repository.calls.where((c) => c == 'endLocally:$_ownerA'),
          hasLength(1),
        );
        expect(registrar.attached, isEmpty);
      });

      test('the teardown callback ends the owner locally', () async {
        signIn(_ownerA);
        build(ready(_ownerA));
        await pumpEventQueue();
        repository.calls.clear();

        await teardownCallbacks.single();

        expect(repository.calls, ['endLocally:$_ownerA']);
      });

      test('a different identity ends the previous owner', () async {
        signIn(_ownerA);
        build(ready(_ownerA));
        await pumpEventQueue();
        repository.calls.clear();

        signIn(_ownerB);
        await emitAuth(AuthState.authenticating);

        expect(repository.calls, contains('endLocally:$_ownerA'));
        expect(registrar.attached, isEmpty);
      });

      test('the session tearing down the owner ends it', () async {
        signIn(_ownerA);
        build(ready(_ownerA));
        await pumpEventQueue();
        repository.calls.clear();

        identity = null;
        session.setReadiness(
          const NostrSessionReadiness.tearingDown(pubkey: _ownerA),
        );
        await pumpEventQueue();

        expect(repository.calls, ['endLocally:$_ownerA']);
      });

      test('a ready to identity-known drop never ends anything', () async {
        signIn(_ownerA);
        build(ready(_ownerA));
        await pumpEventQueue();
        repository.calls.clear();

        session.setReadiness(
          const NostrSessionReadiness.identityKnown(pubkey: _ownerA),
        );
        await pumpEventQueue();

        expect(repository.calls, isEmpty);
        expect(registrar.attached, hasLength(1));
      });

      test('a signer upgrade that recreates the same account client never '
          'ends anything', () async {
        signIn(_ownerA);
        build(ready(_ownerA));
        await pumpEventQueue();
        repository.calls.clear();

        // NostrService reports tearingDown for the same pubkey when a
        // pubkey-only identity gains its signer.
        session.setReadiness(
          const NostrSessionReadiness.tearingDown(pubkey: _ownerA),
        );
        session.setReadiness(ready(_ownerA));
        await pumpEventQueue();

        expect(repository.calls, isEmpty);
        expect(registrar.attached, hasLength(1));
      });

      test('a signed-out cold start ends everything listed', () async {
        authState = AuthState.unauthenticated;
        build(const NostrSessionReadiness.signedOut());
        await pumpEventQueue();

        expect(repository.calls, ['sweep:null']);
      });

      test('a cold start still restoring sweeps nothing', () async {
        build(const NostrSessionReadiness.signedOut());
        await pumpEventQueue();

        expect(repository.calls, isEmpty);
      });
    });

    group('resume', () {
      test('sweeps in the current container', () async {
        signIn(_ownerA);
        build(ready(_ownerA));
        await pumpEventQueue();
        repository.calls.clear();

        await resume();

        expect(repository.calls, ['sweep:$_ownerA']);
      });

      test('does not sweep in a container that is not current', () async {
        signIn(_ownerA);
        build(ready(_ownerA), makeCurrent: false);
        currentContainer = ProviderContainer();
        addTearDown(currentContainer!.dispose);
        await pumpEventQueue();
        repository.calls.clear();

        await resume();

        expect(repository.calls, isEmpty);
      });
    });
  });
}
