// ABOUTME: Riverpod infrastructure exposing Funnelcake enforcement status for the active account.
// ABOUTME: Retains only confirmed restrictions so unavailable refreshes cannot erase warnings.

import 'package:flutter/foundation.dart' show kDebugMode;
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
/// Held in memory only, for the account it was turned on for: a restart, or
/// any change of account, returns to the real status. Read in debug builds
/// only, like the minor-review and protected-minor simulations.
class AccountEnforcementDevOverride
    extends Notifier<AccountEnforcementStatus?> {
  @override
  AccountEnforcementStatus? build() {
    ref.watch(activeEnforcementPubkeyProvider);
    return null;
  }

  void simulate(AccountEnforcementStatus status) => state = status;

  void clear() => state = null;
}

final accountEnforcementDevOverrideProvider =
    NotifierProvider<AccountEnforcementDevOverride, AccountEnforcementStatus?>(
      AccountEnforcementDevOverride.new,
    );

/// Accounts already shown their age-review closure on launch this session.
///
/// In memory on purpose, so the notice comes back on the next cold launch
/// (support-trust-safety#260). Within a session it stops the notice from
/// pushing again when the shell mounts again; resume refetches do not reach
/// the notice once it has answered. Any change of account empties it, signing
/// out included, because signing in or switching to an account is opening it:
/// a closed account that comes back is told again.
class AgeReviewClosureLaunchShown extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(activeEnforcementPubkeyProvider);
    return const {};
  }

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
      if (kDebugMode) {
        final devOverride = ref.watch(accountEnforcementDevOverrideProvider);
        if (devOverride != null) return devOverride;
      }
      if (pubkey == null) throw const AccountStatusSignerNotReady();

      final authService = ref.watch(authServiceProvider);
      ref.watch(currentAuthRpcCapabilityProvider);
      if (!authService.canPublishNostrWritesNow) {
        throw const AccountStatusSignerNotReady();
      }

      final repository = ref.watch(accountEnforcementRepositoryProvider);
      final memory = ref.read(accountRestrictionMemoryProvider);
      final status = await repository.fetchCurrentStatus(pubkey: pubkey);
      if (!ref.mounted) return status;
      memory.record(pubkey, status);
      return status;
    }, retry: (_, _) => null);

/// Whether [lastConfirmedRestrictionProvider] knows of a restriction, so the
/// Settings row and the profile agree with what Account Status shows.
final Provider<bool> isAccountEnforcedProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(lastConfirmedRestrictionProvider) != null,
);

/// The restriction this session last confirmed for the active account, or
/// null when it knows of none.
///
/// The status's own value while it holds one, through a reload or a failed
/// read; otherwise the restriction memory, which outlives the status
/// provider, as when the launch notice lets go of it before Account Status
/// opens.
final Provider<AccountEnforcementStatus?> lastConfirmedRestrictionProvider =
    Provider.autoDispose<AccountEnforcementStatus?>((ref) {
      final pubkey = ref.watch(activeEnforcementPubkeyProvider);
      if (pubkey == null) return null;
      final asyncStatus = ref.watch(accountEnforcementStatusProvider);
      final current = asyncStatus.hasValue ? asyncStatus.value : null;
      if (current != null) return current.isEnforced ? current : null;
      return ref.read(accountRestrictionMemoryProvider).read(pubkey);
    });

void refreshAccountEnforcementAfterRestriction(ProviderContainer container) {
  container.invalidate(accountEnforcementStatusProvider);
}
