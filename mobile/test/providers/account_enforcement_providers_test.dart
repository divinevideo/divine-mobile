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
  Future<FunnelcakeAccountStatusResponse> fetchStatus({
    required String expectedPubkey,
  }) async {
    requestedPubkeys.add(expectedPubkey);
    final result = results.removeAt(0);
    if (result is FunnelcakeAccountStatus) {
      return FunnelcakeAccountStatusResponse(result);
    }
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
  Future<FunnelcakeAccountStatusResponse> fetchStatus({
    required String expectedPubkey,
  }) => results.removeAt(0).future.then(FunnelcakeAccountStatusResponse.new);
}

class _ActivePubkey extends Notifier<String?> {
  @override
  String? build() => _pubkeyA;

  void switchTo(String? pubkey) => state = pubkey;
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
    test('a developer override answers without a request', () async {
      final authService = _MockAuthService();
      when(() => authService.currentPublicKeyHex).thenReturn(_pubkeyA);
      when(() => authService.canPublishNostrWritesNow).thenReturn(true);
      final client = _QueueStatusClient([FunnelcakeAccountStatus.active]);
      final container = _container(authService: authService, client: client);
      addTearDown(container.dispose);
      const simulated = AccountEnforcementStatus(
        kind: AccountEnforcementKind.banned,
        category: AccountEnforcementCategory.ageReview,
      );

      container
          .read(accountEnforcementDevOverrideProvider.notifier)
          .simulate(
            simulated,
          );
      final result = await container.read(
        accountEnforcementStatusProvider.future,
      );

      expect(result, same(simulated));
      expect(client.requestedPubkeys, isEmpty);
    });

    // Settings and the account's own profile keep the status alive, so it has
    // to follow the override in both directions without a fresh first build.
    test('clearing the developer override asks Funnelcake again', () async {
      final authService = _MockAuthService();
      when(() => authService.currentPublicKeyHex).thenReturn(_pubkeyA);
      when(() => authService.canPublishNostrWritesNow).thenReturn(true);
      final client = _QueueStatusClient([
        FunnelcakeAccountStatus.active,
        FunnelcakeAccountStatus.active,
      ]);
      final container = _container(authService: authService, client: client);
      addTearDown(container.dispose);
      final subscription = container.listen(
        accountEnforcementStatusProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(accountEnforcementStatusProvider.future);
      final override = container.read(
        accountEnforcementDevOverrideProvider.notifier,
      );

      override.simulate(
        const AccountEnforcementStatus(kind: AccountEnforcementKind.banned),
      );
      final simulated = await container.read(
        accountEnforcementStatusProvider.future,
      );
      override.clear();
      final cleared = await container.read(
        accountEnforcementStatusProvider.future,
      );

      expect(simulated.kind, AccountEnforcementKind.banned);
      expect(cleared.kind, AccountEnforcementKind.noRestrictionReported);
      expect(client.requestedPubkeys, [_pubkeyA, _pubkeyA]);
    });

    // Signing out and in again keeps the container, so a simulation turned on
    // for one account must not follow the developer onto the next.
    test('a developer override ends when the account changes', () async {
      final authService = _MockAuthService();
      when(() => authService.canPublishNostrWritesNow).thenReturn(true);
      final client = _QueueStatusClient([FunnelcakeAccountStatus.active]);
      final active = NotifierProvider<_ActivePubkey, String?>(
        _ActivePubkey.new,
      );
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
          activeEnforcementPubkeyProvider.overrideWith(
            (ref) => ref.watch(active),
          ),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(accountEnforcementDevOverrideProvider.notifier)
          .simulate(
            const AccountEnforcementStatus(
              kind: AccountEnforcementKind.banned,
              category: AccountEnforcementCategory.ageReview,
            ),
          );
      final subscription = container.listen(
        accountEnforcementStatusProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final simulated = await container.read(
        accountEnforcementStatusProvider.future,
      );

      container.read(active.notifier).switchTo(_pubkeyB);
      final next = await container.read(
        accountEnforcementStatusProvider.future,
      );

      expect(simulated.isAgeReviewClosure, isTrue);
      expect(next.kind, AccountEnforcementKind.noRestrictionReported);
      expect(client.requestedPubkeys, [_pubkeyB]);
    });

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

  group('ageReviewClosureLaunchShownProvider', () {
    test('marks an account shown once', () {
      final container = ProviderContainer(
        overrides: [
          activeEnforcementPubkeyProvider.overrideWithValue(_pubkeyA),
        ],
      );
      addTearDown(container.dispose);
      final shown = container.read(
        ageReviewClosureLaunchShownProvider.notifier,
      );

      expect(shown.markShown(_pubkeyA), isTrue);
      expect(shown.markShown(_pubkeyA), isFalse);
    });

    // Signing in is opening the account, so a closed account that signs out
    // and back in is told again (support-trust-safety#260). AppRootSideEffects
    // keeps the set active, which is what lets it see the sign-out at all: a
    // provider nothing listens to is paused and would miss it.
    test('forgets the mark when the account signs out', () async {
      final active = NotifierProvider<_ActivePubkey, String?>(
        _ActivePubkey.new,
      );
      final container = ProviderContainer(
        overrides: [
          activeEnforcementPubkeyProvider.overrideWith(
            (ref) => ref.watch(active),
          ),
        ],
      );
      addTearDown(container.dispose);
      final keepActive = container.listen(
        ageReviewClosureLaunchShownProvider,
        (_, _) {},
      );
      addTearDown(keepActive.close);
      container
          .read(ageReviewClosureLaunchShownProvider.notifier)
          .markShown(_pubkeyA);

      container.read(active.notifier).switchTo(null);
      // Signing out and back in are separate moments, not one synchronous
      // swap the provider could miss.
      await container.pump();
      container.read(active.notifier).switchTo(_pubkeyA);

      expect(
        container
            .read(ageReviewClosureLaunchShownProvider.notifier)
            .markShown(_pubkeyA),
        isTrue,
      );
    });
  });

  group('lastConfirmedRestrictionProvider', () {
    // The launch notice lets go of the status once it answers, so the next
    // reader starts a fresh read that may fail with nothing cached.
    test(
      'keeps a confirmed restriction after the status is released',
      () async {
        final authService = _MockAuthService();
        when(() => authService.currentPublicKeyHex).thenReturn(_pubkeyA);
        when(() => authService.canPublishNostrWritesNow).thenReturn(true);
        final client = _QueueStatusClient([
          FunnelcakeAccountStatus.suspended,
          const AccountStatusApiException(
            AccountStatusApiFailureKind.unavailable,
            'offline',
          ),
        ]);
        final container = _container(authService: authService, client: client);
        addTearDown(container.dispose);
        final launch = container.listen(
          lastConfirmedRestrictionProvider,
          (_, _) {},
        );
        await container.read(accountEnforcementStatusProvider.future);
        launch.close();
        await container.pump();

        final reopened = container.listen(
          lastConfirmedRestrictionProvider,
          (_, _) {},
        );
        addTearDown(reopened.close);
        await expectLater(
          container.read(accountEnforcementStatusProvider.future),
          throwsA(isA<AccountStatusUnavailable>()),
        );

        expect(client.requestedPubkeys, [_pubkeyA, _pubkeyA]);
        expect(
          container.read(lastConfirmedRestrictionProvider)?.kind,
          AccountEnforcementKind.suspended,
        );
      },
    );
  });

  // Settings and the profile header read this flag while Account Status reads
  // the restriction itself, so the two must agree.
  group('isAccountEnforcedProvider', () {
    test('stays set when the read after a release fails', () async {
      final authService = _MockAuthService();
      when(() => authService.currentPublicKeyHex).thenReturn(_pubkeyA);
      when(() => authService.canPublishNostrWritesNow).thenReturn(true);
      final client = _QueueStatusClient([
        FunnelcakeAccountStatus.suspended,
        const AccountStatusApiException(
          AccountStatusApiFailureKind.unavailable,
          'offline',
        ),
      ]);
      final container = _container(authService: authService, client: client);
      addTearDown(container.dispose);
      final launch = container.listen(
        accountEnforcementStatusProvider,
        (_, _) {},
      );
      await container.read(accountEnforcementStatusProvider.future);
      launch.close();
      await container.pump();

      final settings = container.listen(isAccountEnforcedProvider, (_, _) {});
      addTearDown(settings.close);
      await expectLater(
        container.read(accountEnforcementStatusProvider.future),
        throwsA(isA<AccountStatusUnavailable>()),
      );

      expect(client.requestedPubkeys, [_pubkeyA, _pubkeyA]);
      expect(container.read(isAccountEnforcedProvider), isTrue);
    });

    test('clears once Funnelcake reports the account active', () async {
      final authService = _MockAuthService();
      when(() => authService.currentPublicKeyHex).thenReturn(_pubkeyA);
      when(() => authService.canPublishNostrWritesNow).thenReturn(true);
      final client = _QueueStatusClient([FunnelcakeAccountStatus.active]);
      final container = _container(
        authService: authService,
        client: client,
        memory: AccountRestrictionMemory()
          ..record(
            _pubkeyA,
            const AccountEnforcementStatus(kind: AccountEnforcementKind.banned),
          ),
      );
      addTearDown(container.dispose);

      final settings = container.listen(isAccountEnforcedProvider, (_, _) {});
      addTearDown(settings.close);
      final whileLoading = container.read(isAccountEnforcedProvider);
      await container.read(accountEnforcementStatusProvider.future);

      expect(whileLoading, isTrue);
      expect(container.read(isAccountEnforcedProvider), isFalse);
    });
  });
}
