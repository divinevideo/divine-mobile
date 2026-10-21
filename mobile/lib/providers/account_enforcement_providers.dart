// ABOUTME: Riverpod infrastructure exposing Funnelcake enforcement status for the active account.
// ABOUTME: Retains only confirmed restrictions so unavailable refreshes cannot erase warnings.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/account_enforcement_status.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/repositories/account_enforcement_repository.dart';
import 'package:openvine/services/account_status_api_client.dart';
import 'package:openvine/services/auth_service.dart';

final accountStatusApiClientProvider = Provider<AccountStatusApiClient>((ref) {
  final nip98 = ref.watch(nip98AuthServiceProvider);
  final client = AccountStatusApiClient(
    baseUri: Uri.parse(ref.watch(currentEnvironmentProvider).apiBaseUrl),
    httpClient: ref.watch(instrumentedHttpClientFactoryProvider)(),
    authHeaderProvider: ({required url, required method}) async {
      final token = await nip98.createAuthToken(url: url, method: method);
      return token?.authorizationHeader;
    },
  );
  ref.onDispose(client.dispose);
  return client;
});

final accountEnforcementRepositoryProvider =
    Provider<AccountEnforcementRepository>((ref) {
      return AccountEnforcementRepository(
        apiClient: ref.watch(accountStatusApiClientProvider),
      );
    });

final accountRestrictionMemoryProvider = Provider<AccountRestrictionMemory>(
  (_) => AccountRestrictionMemory(),
);

class AccountRestrictionMemory {
  final Map<String, AccountEnforcementStatus> _byPubkey = {};

  AccountEnforcementStatus? read(String pubkey) => _byPubkey[pubkey];

  void record(String pubkey, AccountEnforcementStatus status) {
    if (status.isEnforced) {
      _byPubkey[pubkey] = status;
    } else {
      _byPubkey.remove(pubkey);
    }
  }
}

/// Developer-options simulation of an enforcement state, so the status screen
/// can be seen in states Funnelcake cannot yet report (support-trust-safety#260).
///
/// Held in memory only: a restart always returns to the real status.
class AccountEnforcementDevOverride
    extends Notifier<AccountEnforcementStatus?> {
  @override
  AccountEnforcementStatus? build() => null;

  void simulate(AccountEnforcementStatus status) => state = status;

  void clear() => state = null;
}

final accountEnforcementDevOverrideProvider =
    NotifierProvider<AccountEnforcementDevOverride, AccountEnforcementStatus?>(
      AccountEnforcementDevOverride.new,
    );

/// Accounts already shown their age-review closure on launch this session.
///
/// In memory on purpose: the notice comes back on the next cold launch, but a
/// resume refetch in the same session must not push it again
/// (support-trust-safety#260). It lives in the account's container, which an
/// account switch rebuilds, so switching back to a closed account shows the
/// notice again; switching in is opening that account.
class AgeReviewClosureLaunchShown extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Records [pubkey] and returns whether this is its first showing.
  bool markShown(String pubkey) {
    if (state.contains(pubkey)) return false;
    state = {...state, pubkey};
    return true;
  }
}

final ageReviewClosureLaunchShownProvider =
    NotifierProvider<AgeReviewClosureLaunchShown, Set<String>>(
      AgeReviewClosureLaunchShown.new,
    );

final activeEnforcementPubkeyProvider = Provider<String?>((ref) {
  final authState = ref.watch(currentAuthStateProvider);
  if (authState != AuthState.authenticated) return null;
  return ref.watch(authServiceProvider).currentPublicKeyHex;
});

final FutureProvider<AccountEnforcementStatus>
accountEnforcementStatusProvider =
    FutureProvider.autoDispose<AccountEnforcementStatus>((ref) async {
      final authState = ref.watch(currentAuthStateProvider);
      final pubkey = ref.watch(activeEnforcementPubkeyProvider);
      if (authState != AuthState.authenticated) {
        return const AccountEnforcementStatus(
          kind: AccountEnforcementKind.signedOut,
        );
      }
      final devOverride = ref.watch(accountEnforcementDevOverrideProvider);
      if (devOverride != null) return devOverride;
      if (pubkey == null) throw const AccountStatusUnavailable();

      final authService = ref.watch(authServiceProvider);
      ref.watch(currentAuthRpcCapabilityProvider);
      if (!authService.canPublishNostrWritesNow) {
        throw const AccountStatusUnavailable();
      }

      final repository = ref.watch(accountEnforcementRepositoryProvider);
      final memory = ref.read(accountRestrictionMemoryProvider);
      final status = await repository.fetchCurrentStatus(pubkey: pubkey);
      if (!ref.mounted) return status;
      memory.record(pubkey, status);
      return status;
    }, retry: (_, _) => null);

final Provider<bool> isAccountEnforcedProvider = Provider.autoDispose<bool>((
  ref,
) {
  final pubkey = ref.watch(activeEnforcementPubkeyProvider);
  if (pubkey == null) return false;
  final asyncStatus = ref.watch(accountEnforcementStatusProvider);
  final current = asyncStatus.hasValue ? asyncStatus.value : null;
  return current?.isEnforced ??
      ref.read(accountRestrictionMemoryProvider).read(pubkey)?.isEnforced ??
      false;
});

void refreshAccountEnforcementAfterRestriction(ProviderContainer container) {
  container.invalidate(accountEnforcementStatusProvider);
}
