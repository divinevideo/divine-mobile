// ABOUTME: Orchestrates an in-place account switch — build a container, sign it
// ABOUTME: in as the target account, then swap; roll back on failure.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/device_scope.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/notifications_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:unified_logger/unified_logger.dart';

/// Signs [container]'s fresh [AuthService] in as [account].
///
/// Reuses the existing `signInForAccount` — the container gets its own
/// `AuthService` instance, so the sign-in's global-session mutation lands on
/// the new instance, never the live one. That is what lets the in-place swap
/// skip the side-effect-free `activate()` refactor (design §8.2 correction).
typedef AccountSignIn = Future<void> Function(
  ProviderContainer container,
  KnownAccount account,
);

const _accountSwitchPushCleanupTimeout = Duration(seconds: 15);

/// Stops the outgoing account's DM ingest before the incoming container signs
/// in and wipes shared DM state.
///
/// The identity-change cleanup runs from the *incoming* container, where
/// `dmListeningStopProvider` finds no repository and returns early — while the
/// outgoing container's repository is still draining history into the
/// `DeviceScope`-shared database and `SharedPreferences`. The invariant is
/// that no writer for an account may be live while that account's
/// device-scoped data is wiped, and the scope that owns the data is the device,
/// not either container. See #7318.
Future<bool> _quiesceOutgoingDmIngest(ProviderContainer? outgoing) async {
  if (outgoing == null || !outgoing.exists(dmRepositoryProvider)) return false;
  try {
    await outgoing.read(dmListeningStopProvider)();
    return true;
  } catch (error) {
    Log.warning(
      'Stopping the outgoing account DM ingest before the swap failed: $error',
      name: 'swapAccount',
    );
    return false;
  }
}

/// Re-opens the outgoing account's DM ingest after a failed swap, so the
/// rollback does not leave the still-signed-in user without DMs.
Future<void> _resumeOutgoingDmIngest(ProviderContainer? outgoing) async {
  if (outgoing == null || !outgoing.exists(dmRepositoryProvider)) return;
  try {
    await outgoing.read(dmRepositoryProvider).startListening();
  } catch (error) {
    Log.warning(
      'Resuming the outgoing account DM ingest after a failed swap '
      'failed: $error',
      name: 'swapAccount',
    );
  }
}

Future<void> _defaultSignIn(
  ProviderContainer container,
  KnownAccount account,
) async {
  // A swapped-in container does not run the startup coordinator, so give it the
  // same per-container prerequisites a fresh launch establishes before auth.
  // EnvironmentService defaults to production and applies any persisted
  // override here, so the new account's signer and relays target the right
  // environment rather than whatever an uninitialised service would default to.
  // (NostrService / relay connections still come up lazily once
  // signInForAccount authenticates — same as a cold launch.)
  await container
      .read(environmentServiceProvider)
      .initialize(sharedPreferences: container.read(sharedPreferencesProvider));
  await container.read(authServiceProvider).initializeForAccountSwitch();
  await container
      .read(authServiceProvider)
      .signInForAccount(
        account.pubkeyHex,
        account.authSource,
        claimLegacyRows: false,
      );
}

String? _currentRouterLocation(AccountSwitchController controller) {
  final current = controller.currentContainer;
  if (current == null) return null;
  if (!current.exists(goRouterProvider)) return null;
  return current
      .read(goRouterProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .toString();
}

/// Retargets an own-account route from the leaving account to the account that
/// is about to become active.
///
/// Most routes are safe to preserve across an account-container swap. Own-
/// account URLs are identity-bearing, though: carrying one into the new
/// container renders data for the leaving account while the rest of the app
/// already reflects the target account.
///
/// The routed segment is matched with [routeIdentifiesUser] rather than
/// compared raw so equivalent npub, nprofile, hex, and relative `me` forms are
/// recognized consistently.
///
/// Supported user-identifying routes that are retargeted:
/// - `/profile/<identifier>`
/// - `/followers/<identifier>`
/// - `/following/<identifier>`
/// - `/profile-view/<identifier>`
String? accountSwitchInitialLocation({
  required String? currentLocation,
  required String? currentPubkeyHex,
  required String targetPubkeyHex,
}) {
  if (currentLocation == null) return null;

  final uri = Uri.tryParse(currentLocation);
  if (uri == null) return currentLocation;
  final segments = uri.pathSegments;
  // Routes that carry a user identity as the second segment and should be
  // retargeted when the identity matches the leaving account.
  const userRoutes = {'profile', 'followers', 'following', 'profile-view'};

  if (segments.length < 2 || !userRoutes.contains(segments.first)) {
    return currentLocation;
  }

  if (!routeIdentifiesUser(segments[1], currentPubkeyHex)) {
    return currentLocation;
  }

  final routeType = segments.first;
  // Followers/following compare this segment directly with the client's hex
  // key. Profile routes normalize the identifier and conventionally use npub.
  final targetIdentifier = routeType == 'followers' || routeType == 'following'
      ? targetPubkeyHex
      : NostrKeyUtils.encodePubKey(targetPubkeyHex);
  final targetPath =
      '/$routeType/$targetIdentifier${segments.length >= 3 ? '/${segments.skip(2).join('/')}' : ''}';
  return uri.replace(path: targetPath).toString();
}

/// Switches the live app to [account] in place: builds a new container on the
/// shared [deviceScope], signs it in, and swaps it in via [controller].
///
/// [currentAuthService] is the live container's service — the account being
/// left. Its signer credentials (OAuth session, bunker URL, Amber info) live in
/// shared secure-storage slots that the incoming account's sign-in overwrites,
/// so they are archived per-account first. The sign-out this swap replaced used
/// to do that; without it the leaving account comes back as "session expired"
/// with no refresh token left to recover from.
///
/// That archive is a precondition, not a best-effort side trip: it throws if
/// the write fails, aborting before anything is mutated, because a swap that
/// carries on past it destroys the credentials it was meant to preserve.
///
/// Prove-then-commit: nothing user-visible changes until the new account's
/// sign-in succeeds. On failure the half-built container is disposed and the
/// current account's container is left untouched — the rollback the previous
/// welcome-bounce flow could not guarantee (#4623). Rethrows so the caller can
/// surface a "couldn't switch" affordance. The archive survives that rollback
/// intentionally: it only ever copies the leaving account's own credentials
/// into its own slot.
///
/// Push deregistration follows the same commit boundary. The outgoing
/// coordinator is captured before sign-in can replace shared signer storage,
/// but it runs only after [AccountSwitchController.swapTo] commits the target.
/// The swap host retains the outgoing container until cleanup settles so its
/// account-scoped signer remains usable throughout deregistration.
///
/// Rolling the container back is not enough on its own: a sign-in that got far
/// enough to fail has already restored the *target* account's signer keys over
/// the shared slots and persisted its auth source, which the live container
/// never re-reads but the next cold launch does. The rollback restores the
/// leaving account's keys from the archive written above. It cannot throw:
/// callers dispatch on the sign-in failure's type, so a rollback that escaped
/// would swap out the type they match on and cost the user the recovery route.
///
/// [signIn] is injectable for testing; production uses [signInForAccount].
Future<void> swapAccount({
  required DeviceScope deviceScope,
  required AccountSwitchController controller,
  required AuthService currentAuthService,
  required KnownAccount account,
  AccountSignIn signIn = _defaultSignIn,
}) async {
  await controller.runExclusive(() async {
    await currentAuthService.archiveCurrentSignerInfo();
    final current = controller.currentContainer;
    final outgoingPushCoordinator =
        current != null && current.exists(pushNotificationSyncProvider)
        ? current.read(pushNotificationSyncProvider)
        : null;
    final currentLocation = accountSwitchInitialLocation(
      currentLocation: _currentRouterLocation(controller),
      currentPubkeyHex: current?.read(authServiceProvider).currentPublicKeyHex,
      targetPubkeyHex: account.pubkeyHex,
    );
    final container = buildAccountContainer(
      deviceScope,
      accountOverrides: [
        if (currentLocation != null)
          routerInitialLocationProvider.overrideWithValue(currentLocation),
      ],
    );
    final keyStorage = container.read(secureKeyStorageProvider);
    SecureKeyContainer? previousPrimary;
    var outgoingDmIngestQuiesced = false;
    try {
      previousPrimary = await keyStorage.getKeyContainer();
      // Before sign-in, because sign-in is what runs the identity-change
      // cleanup that wipes the shared DM tables. See #7318.
      outgoingDmIngestQuiesced = await _quiesceOutgoingDmIngest(current);
      await signIn(container, account);
      await controller.swapTo(
        container,
        beforePreviousContainerDispose: outgoingPushCoordinator == null
            ? null
            : () async {
                // The incoming account is live before cleanup starts. The
                // backend only removes a token when the signed pubkey still
                // owns it, so a late outgoing 3080 cannot unregister the
                // incoming 3079. Keep using the captured outgoing coordinator:
                // after disposal, the replacement container has no access to
                // the signer that must authorize this cleanup.
                try {
                  await outgoingPushCoordinator
                      .deregisterLastReadyPubkeyAfterAccountSwitch()
                      .timeout(_accountSwitchPushCleanupTimeout);
                } catch (error) {
                  // The target account is already live. Push cleanup is
                  // best-effort and must not turn a committed switch into a
                  // rollback attempt.
                  Log.warning(
                    'Outgoing account push deregistration failed: $error',
                    name: 'swapAccount',
                  );
                }
              },
      );
      try {
        await container
            .read(authServiceProvider)
            .claimLegacyRowsForCurrentUser();
      } catch (error) {
        // The target container is already mounted, so this post-commit
        // migration cannot be rolled back.
        Log.warning(
          'Claiming legacy user data after account swap failed: $error',
          name: 'swapAccount',
        );
      }
    } catch (_) {
      // The outgoing container stays live on a rollback. If this attempt
      // stopped its live subscription, restore that subscription before the
      // key restores below, which can throw. History recovery remains
      // resumable and restarts on the next inbox open. See #7318.
      if (outgoingDmIngestQuiesced) {
        await _resumeOutgoingDmIngest(current);
      }
      try {
        await currentAuthService.restoreSignerInfoForCurrentAccount();
        await keyStorage.restorePrimaryKeyContainer(previousPrimary);
      } catch (rollbackError, rollbackStack) {
        // Swallowed on purpose: the caller dispatches on the sign-in failure's
        // type to decide between the re-auth offer and the generic snackbar,
        // and letting a rollback failure escape here replaces that type.
        Log.error(
          'Account swap rollback failed',
          name: 'swapAccount',
          error: rollbackError,
          stackTrace: rollbackStack,
        );
      } finally {
        container.dispose();
      }
      rethrow;
    }
    previousPrimary?.dispose();
  });
}
