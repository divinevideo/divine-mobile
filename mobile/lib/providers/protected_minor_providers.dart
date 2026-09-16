// ABOUTME: Riverpod providers exposing the non-blocking protected-minor (13-15)
// ABOUTME: state from Keycast's verified_minor flag, for #175/#176 to consume.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/protected_minor_status.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/provider_detached_future.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/protected_minor_repository.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/protected_minor_override_service.dart';
import 'package:openvine/services/protected_minor_sticky_store.dart';

/// Developer-only override service (debug builds).
final protectedMinorOverrideServiceProvider =
    Provider<ProtectedMinorOverrideService>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return ProtectedMinorOverrideService(prefs: prefs);
    });

/// Repository that reads `verified_minor` from Keycast for the current session.
final protectedMinorRepositoryProvider = Provider<ProtectedMinorRepository>((
  ref,
) {
  final oauthClient = ref.watch(oauthClientProvider);
  return ProtectedMinorRepository(
    oauthClient: oauthClient,
    // Owner-bound rather than a bare getSessionOrRefresh(): a session left
    // behind by another account would otherwise answer the minor question for
    // this one.
    readAccessToken: ref.watch(authServiceProvider).activeAccountKeycastToken,
  );
});

/// Non-blocking protected-minor state for the authenticated account.
///
/// Unauthenticated accounts are never protected. In debug builds a local
/// override short-circuits the real fetch. Otherwise the repository reads the
/// Keycast flag, preserving fetch failures as unknown so #175/#176 can choose
/// their own enforcement posture.
///
/// Notes for consumers (#175/#176):
/// - Resolving this may trigger a Keycast token refresh via
///   `AuthService.activeAccountKeycastToken()` (a network call + storage write)
///   when the cached session is stale. In the common case a valid session is
///   reused with no refresh. A session that is not bound to the signed-in
///   account yields no token at all, which reads as unknown — the fail-safe
///   answer for a session whose owner cannot be named.
/// - This only recomputes when auth state changes. An account approved as a
///   minor mid-session (no auth-state transition) will not refetch until the
///   provider is invalidated — call `ref.invalidate(protectedMinorStatusProvider)`
///   when fresh state is required.
final protectedMinorStatusProvider = FutureProvider<ProtectedMinorStatus>((
  ref,
) async {
  final authState = ref.watch(currentAuthStateProvider);
  if (authState != AuthState.authenticated) {
    return ProtectedMinorStatus.notProtected();
  }

  if (kDebugMode) {
    final override = ref
        .watch(protectedMinorOverrideServiceProvider)
        .getOverride();
    if (override != null) {
      return override
          ? ProtectedMinorStatus.protected()
          : ProtectedMinorStatus.notProtected();
    }
  }

  return ref.watch(protectedMinorRepositoryProvider).fetchCurrentStatus();
});

/// Convenience boolean seam for the protections (#175/#176).
///
/// Reads the last-known status via `.value`, so a protected minor stays
/// protected through a refetch (AsyncLoading) instead of flickering to
/// not-protected — matching the blocking review gate, which reads
/// `reviewStatusAsync.value` (`app_router.dart`). `false` only until the first
/// resolution.
///
/// Note: unknown/error status is still exposed on [protectedMinorStatusProvider]
/// for consumers that need to distinguish an unavailable check from confirmed
/// not-protected.
/// Persisted last-known protected-minor state (fail-safe backing, #175).
final protectedMinorStickyStoreProvider = Provider<ProtectedMinorStickyStore>((
  ref,
) {
  return ProtectedMinorStickyStore(prefs: ref.watch(sharedPreferencesProvider));
});

/// Whether a live protected-minor status may be trusted as a fresh signal for
/// the current account, or `null` to fall back to the persisted sticky value.
///
/// A status is only trustworthy when the session is **authenticated** and the
/// value is **freshly resolved** (`AsyncData`). This rejects two fail-safe
/// hazards: the `notProtected()` the #174 seam emits merely because auth has
/// not completed (cold start / session restore), and a stale value retained
/// from a previous account during a refetch (`AsyncLoading`/`AsyncError`).
ProtectedMinorStatus? trustedProtectedMinorStatus({
  required bool authenticated,
  required AsyncValue<ProtectedMinorStatus> live,
}) {
  if (!authenticated) return null;
  if (live is! AsyncData<ProtectedMinorStatus>) return null;
  return live.value;
}

/// Effective protected-minor seam for the protections (#175/#176), fail-safe.
///
/// The effective value is a trusted live status when available, else the
/// persisted last-known (sticky). A trusted status is also persisted for the
/// next cold start. Unknown/error and any untrusted status never weaken
/// protection: an account confirmed a protected minor stays protected offline
/// and at cold start, and lifts only on a positive not-a-minor signal from an
/// authenticated check (age-up / revocation).
final isProtectedMinorProvider = Provider<bool>((ref) {
  final authState = ref.watch(currentAuthStateProvider);
  final pubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
  final store = ref.watch(protectedMinorStickyStoreProvider);
  final live = ref.watch(protectedMinorStatusProvider);

  // Account-switch safety relies on the invariant that every account swap
  // transits a non-authenticated authState (authenticating/checking), which
  // invalidates protectedMinorStatusProvider (it watches currentAuthStateProvider)
  // back into AsyncLoading before authState returns to authenticated for the new
  // account. That is why a stale AsyncData from a previous account can never be
  // trusted here. A future silent same-authState pubkey swap would need to also
  // invalidate the status provider to preserve this guarantee.
  final trusted = trustedProtectedMinorStatus(
    authenticated: authState == AuthState.authenticated,
    live: live,
  );
  if (trusted != null) {
    // Persist trusted transitions for future cold starts (fire-and-forget).
    runProviderDetached(
      store.applyLiveStatus(pubkey, trusted),
      'persist protected-minor status',
      logName: 'ProtectedMinorProviders',
    );
    if (trusted.kind == ProtectedMinorStatusKind.protected) return true;
    if (trusted.kind == ProtectedMinorStatusKind.notProtected) return false;
  }
  // Untrusted / unknown -> last-known persisted value (sticky).
  return store.isProtectedMinorFor(pubkey);
});

/// Whether a Keycast-backed protected-minor verdict can apply to the current
/// account. Returns `true` only for OAuth-authenticated accounts and for
/// accounts that have previously been marked as Keycast-custodial.
///
/// The #182 key-management restriction uses this to distinguish accounts that
/// may have an unknown verdict from Keycast (and must fail closed) from pure
/// self-custody accounts that Keycast can never produce a verdict for (and must
/// not be permanently restricted by an unanswerable check).
final keycastSignalApplicableProvider = Provider<bool>((ref) {
  // AuthService mutates its pubkey and auth-source fields in place, so watch
  // the auth state so applicability recomputes across the current account-swap
  // invariant: every swap transits a non-authenticated state. A future silent
  // same-state pubkey swap must also invalidate this provider explicitly.
  ref.watch(currentAuthStateProvider);
  final authService = ref.watch(authServiceProvider);
  final pubkey = authService.currentPublicKeyHex;
  final authSource = authService.authenticationSource;
  final store = ref.watch(protectedMinorStickyStoreProvider);

  // OAuth accounts can receive a Keycast verdict, so key management fails
  // closed on unknown.
  if (authSource == AuthenticationSource.divineOAuth) {
    return true;
  }

  // Key management stays fail-closed for self-custody accounts that were
  // previously seen by Keycast, since a pubkey can flip between auth sources
  // on the same device.
  if (pubkey != null && store.wasKeycastAccountFor(pubkey)) {
    return true;
  }

  // Keep this exhaustive so every new auth source requires an explicit
  // key-management fail-direction decision at this child-safety boundary.
  return switch (authSource) {
    AuthenticationSource.divineOAuth => true,
    AuthenticationSource.none ||
    AuthenticationSource.automatic ||
    AuthenticationSource.importedKeys ||
    AuthenticationSource.bunker ||
    AuthenticationSource.amber ||
    AuthenticationSource.nip07 => false,
  };
});

/// Whether the current account has an affirmative protected-minor designation
/// and must use the restricted DM experience (#176, #8561).
///
/// Divine treats accounts as 16+ for messaging unless Greenlight has marked
/// them as protected minors. An unavailable or unresolved Keycast check must
/// therefore not restrict an account with no prior protected verdict. The
/// sticky behavior in [isProtectedMinorProvider] still keeps a previously
/// confirmed protected minor restricted through startup, refreshes, and
/// outages until a trusted not-protected verdict clears the designation.
final isDmRestrictedProvider = Provider<bool>(
  (ref) => ref.watch(isProtectedMinorProvider),
);

/// Whether the current DM restriction comes from a confirmed protected-minor
/// verdict. DM restrictions now require that affirmative verdict, so this
/// named seam remains for policy consumers while sharing the same answer.
final hasConfirmedDmRestrictionProvider = Provider<bool>(
  (ref) => ref.watch(isDmRestrictedProvider),
);

/// The #182 key-management seam — gates nsec export ("copy private key") and
/// key import/change (swapping the account to a self-held key) for protected
/// minors.
///
/// Key management intentionally retains its fail-closed posture independently
/// of the DM policy: a protected minor — or any Keycast-backed account whose
/// status cannot be positively cleared — cannot export or replace its key.
/// Pure self-custody accounts that Keycast has never known remain unrestricted.
final isKeyManagementRestrictedProvider = Provider<bool>((ref) {
  final authState = ref.watch(currentAuthStateProvider);
  final authService = ref.watch(authServiceProvider);
  final pubkey = authService.currentPublicKeyHex;
  final authSource = authService.authenticationSource;
  final store = ref.watch(protectedMinorStickyStoreProvider);
  final live = ref.watch(protectedMinorStatusProvider);
  final keycastApplicable = ref.watch(keycastSignalApplicableProvider);

  if (authSource == AuthenticationSource.divineOAuth) {
    // Intentional fire-and-forget monotonic marker; SharedPreferences updates
    // its in-memory cache before the Future completes, so later synchronous
    // wasKeycastAccountFor() reads see it in-session.
    runProviderDetached(
      store.markKeycastAccount(pubkey),
      'persist Keycast account history',
      logName: 'ProtectedMinorProviders',
    );
  }

  final trusted = trustedProtectedMinorStatus(
    authenticated: authState == AuthState.authenticated,
    live: live,
  );
  if (trusted != null) {
    // Same fire-and-forget persistence as isProtectedMinorProvider (idempotent
    // there and here; whichever seam resolves first records the verdict).
    runProviderDetached(
      store.applyLiveStatus(pubkey, trusted),
      'persist key-management minor status',
      logName: 'ProtectedMinorProviders',
    );
    if (trusted.kind == ProtectedMinorStatusKind.protected) return true;
    if (trusted.kind == ProtectedMinorStatusKind.notProtected) return false;
  }
  // No trusted answer: an explicit persisted verdict wins. Otherwise, fail
  // closed only when Keycast could apply to this account now or historically.
  final lastKnown = store.lastKnownFor(pubkey);
  if (lastKnown != null) return lastKnown;
  if (authState != AuthState.authenticated || pubkey == null) return true;

  // The auth source is restored asynchronously after the pubkey, so `none`
  // means we do not yet know whether Keycast applies to this account. Fail
  // closed rather than guess in the permissive direction.
  if (authSource == AuthenticationSource.none) return true;

  // Fail closed only when Keycast signals are applicable to this account.
  return keycastApplicable;
});
