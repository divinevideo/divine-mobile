// ABOUTME: Tests all-account Funnelcake enforcement provider behavior.
// ABOUTME: Covers signer gating, account isolation, and retained restrictions.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/account_enforcement_status.dart';
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/providers/account_enforcement_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/repositories/account_enforcement_repository.dart';
import 'package:openvine/services/account_status_api_client.dart';
import 'package:openvine/services/auth_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _QueueStatusClient extends AccountStatusApiClient {
  _QueueStatusClient(this.results)
    : super(
        baseUri: Uri.parse('https://api.divine.video'),
        authHeaderProvider: ({required url, required method}) async => null,
      );

  final List<Object> results;
  final List<String> requestedPubkeys = [];

  @override
  Future<FunnelcakeAccountStatus> fetchStatus({
    required String expectedPubkey,
  }) async {
    requestedPubkeys.add(expectedPubkey);
    final result = results.removeAt(0);
    if (result is FunnelcakeAccountStatus) return result;
    throw result;
  }
}

class _ControlledStatusClient extends AccountStatusApiClient {
  _ControlledStatusClient(this.results)
    : super(
        baseUri: Uri.parse('https://api.divine.video'),
        authHeaderProvider: ({required url, required method}) async => null,
      );

  final List<Completer<FunnelcakeAccountStatus>> results;

  @override
  Future<FunnelcakeAccountStatus> fetchStatus({
    required String expectedPubkey,
  }) => results.removeAt(0).future;
}

const _pubkeyA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _pubkeyB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

ProviderContainer _container({
  required AuthService authService,
  required _QueueStatusClient client,
  AccountRestrictionMemory? memory,
}) {
  return ProviderContainer(
    overrides: [
      currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
      currentAuthRpcCapabilityProvider.overrideWithValue(
        AuthRpcCapability.rpcReady,
      ),
      authServiceProvider.overrideWithValue(authService),
      accountEnforcementRepositoryProvider.overrideWithValue(
        AccountEnforcementRepository(apiClient: client),
      ),
      if (memory != null)
        accountRestrictionMemoryProvider.overrideWithValue(memory),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('accountEnforcementStatusProvider', () {
    test('signed out resolves without a request', () async {
      final client = _QueueStatusClient([FunnelcakeAccountStatus.active]);
      final container = ProviderContainer(
        overrides: [
          currentAuthStateProvider.overrideWithValue(AuthState.unauthenticated),
          currentAuthRpcCapabilityProvider.overrideWithValue(
            AuthRpcCapability.unavailable,
          ),
          accountEnforcementRepositoryProvider.overrideWithValue(
            AccountEnforcementRepository(apiClient: client),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        accountEnforcementStatusProvider.future,
      );
      expect(result.kind, AccountEnforcementKind.signedOut);
      expect(client.requestedPubkeys, isEmpty);
    });

    test('every signer-backed authentication source uses Funnelcake', () async {
      for (final source in AuthenticationSource.values.where(
        (source) => source != AuthenticationSource.none,
      )) {
        final authService = _MockAuthService();
        when(() => authService.currentPublicKeyHex).thenReturn(_pubkeyA);
        when(() => authService.canPublishNostrWritesNow).thenReturn(true);
        when(() => authService.authenticationSource).thenReturn(source);
        final client = _QueueStatusClient([FunnelcakeAccountStatus.suspended]);
        final container = _container(authService: authService, client: client);

        final result = await container.read(
          accountEnforcementStatusProvider.future,
        );
        expect(
          result.kind,
          AccountEnforcementKind.suspended,
          reason: '$source',
        );
        expect(client.requestedPubkeys, [_pubkeyA], reason: '$source');
        container.dispose();
      }
    });

    test('pubkey-only identity is indeterminate without a request', () async {
      final authService = _MockAuthService();
      when(() => authService.currentPublicKeyHex).thenReturn(_pubkeyA);
      when(() => authService.canPublishNostrWritesNow).thenReturn(false);
      final client = _QueueStatusClient([FunnelcakeAccountStatus.active]);
      final container = _container(authService: authService, client: client);
      addTearDown(container.dispose);
      final subscription = container.listen(
        accountEnforcementStatusProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      await expectLater(
        container.read(accountEnforcementStatusProvider.future),
        throwsA(isA<AccountStatusUnavailable>()),
      );
      expect(client.requestedPubkeys, isEmpty);
    });

    test(
      'failed refresh preserves restriction across provider disposal',
      () async {
        final authService = _MockAuthService();
        when(() => authService.currentPublicKeyHex).thenReturn(_pubkeyA);
        when(() => authService.canPublishNostrWritesNow).thenReturn(true);
        final memory = AccountRestrictionMemory();
        final client = _QueueStatusClient([
          FunnelcakeAccountStatus.suspended,
          const AccountStatusApiException(
            AccountStatusApiFailureKind.unavailable,
            'offline',
          ),
        ]);
        final container = _container(
          authService: authService,
          client: client,
          memory: memory,
        );
        addTearDown(container.dispose);

        final subscription = container.listen(
          accountEnforcementStatusProvider,
          (_, _) {},
        );
        await container.read(accountEnforcementStatusProvider.future);
        subscription.close();
        await container.pump();

        final failedSubscription = container.listen(
          accountEnforcementStatusProvider,
          (_, _) {},
        );
        await expectLater(
          container.read(accountEnforcementStatusProvider.future),
          throwsA(isA<AccountStatusUnavailable>()),
        );
        failedSubscription.close();
        expect(memory.read(_pubkeyA)?.isEnforced, isTrue);
      },
    );

    test('successful active response clears retained restriction', () async {
      final authService = _MockAuthService();
      when(() => authService.currentPublicKeyHex).thenReturn(_pubkeyA);
      when(() => authService.canPublishNostrWritesNow).thenReturn(true);
      final memory = AccountRestrictionMemory()
        ..record(
          _pubkeyA,
          const AccountEnforcementStatus(kind: AccountEnforcementKind.banned),
        );
      final client = _QueueStatusClient([FunnelcakeAccountStatus.active]);
      final container = _container(
        authService: authService,
        client: client,
        memory: memory,
      );
      addTearDown(container.dispose);

      await container.read(accountEnforcementStatusProvider.future);
      expect(memory.read(_pubkeyA), isNull);
    });

    test(
      'superseded refresh cannot overwrite newer restriction memory',
      () async {
        final authService = _MockAuthService();
        when(() => authService.currentPublicKeyHex).thenReturn(_pubkeyA);
        when(() => authService.canPublishNostrWritesNow).thenReturn(true);
        final stale = Completer<FunnelcakeAccountStatus>();
        final current = Completer<FunnelcakeAccountStatus>();
        final memory = AccountRestrictionMemory();
        final client = _ControlledStatusClient([stale, current]);
        final container = ProviderContainer(
          overrides: [
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            currentAuthRpcCapabilityProvider.overrideWithValue(
              AuthRpcCapability.rpcReady,
            ),
            authServiceProvider.overrideWithValue(authService),
            accountEnforcementRepositoryProvider.overrideWithValue(
              AccountEnforcementRepository(apiClient: client),
            ),
            accountRestrictionMemoryProvider.overrideWithValue(memory),
          ],
        );
        addTearDown(container.dispose);

        final subscription = container.listen(
          accountEnforcementStatusProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        final staleResult = container.read(
          accountEnforcementStatusProvider.future,
        );
        await container.pump();

        container.invalidate(accountEnforcementStatusProvider);
        final currentResult = container.read(
          accountEnforcementStatusProvider.future,
        );
        current.complete(FunnelcakeAccountStatus.suspended);
        expect((await currentResult).kind, AccountEnforcementKind.suspended);
        expect(memory.read(_pubkeyA)?.kind, AccountEnforcementKind.suspended);

        stale.complete(FunnelcakeAccountStatus.active);
        await staleResult;
        expect(memory.read(_pubkeyA)?.kind, AccountEnforcementKind.suspended);
      },
    );

    test('retained restriction never leaks to another account', () {
      final memory = AccountRestrictionMemory()
        ..record(
          _pubkeyA,
          const AccountEnforcementStatus(
            kind: AccountEnforcementKind.suspended,
          ),
        );
      expect(memory.read(_pubkeyA)?.isEnforced, isTrue);
      expect(memory.read(_pubkeyB), isNull);
    });
  });
}
