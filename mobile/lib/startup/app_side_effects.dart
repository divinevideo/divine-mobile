// ABOUTME: The one place app-wide side-effect providers are activated.
// ABOUTME: Two hosts, split by what activating each provider costs at startup.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/notifications_providers.dart';
import 'package:openvine/providers/relay_list_repository_provider.dart';
import 'package:openvine/providers/relay_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/supporter_providers.dart';
import 'package:openvine/router/providers/route_normalization_provider.dart';
import 'package:openvine/router/providers/support_route_trail_provider.dart';

/// App-wide side effects that must run for the whole life of the process.
///
/// Mounted once, at the app root, above `MaterialApp.router`. Membership rule:
/// a provider belongs here when activating it costs no more than the
/// already-constructed `authServiceProvider`, **or** when its whole point is to
/// keep working while the bottom-nav shell is not mounted.
///
/// The identity mirrors are the reason this host exists. They were previously
/// activated from `AppShell.build()`, which does not run until the user lands
/// on a bottom-nav tab — so for the whole pre-shell window (splash, auth
/// restore, sign-up, e-mail verification, onboarding) Crashlytics reports and
/// Firebase Analytics events carried no `user_id`, even for an already
/// authenticated user restored from the keychain. Both providers' own dartdoc
/// said "watch this provider at app startup"; this host is what makes that
/// true.
class AppRootSideEffects extends ConsumerWidget {
  const AppRootSideEffects({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Redirects the router to canonical URLs. Router plumbing, not a service:
    // it only reads `goRouterProvider` and attaches a listener.
    ref.watch(routeNormalizationProvider);

    // Retains parameter-free route context for support diagnostics. It must be
    // active before the user enters Settings or the Support Center.
    ref.watch(supportRouteTrailProvider);

    // Mirrors the authenticated pubkey into Zendesk, and into Firebase
    // Analytics + Crashlytics. Cheap to activate: `authServiceProvider` is
    // already constructed, and the extra `profileRepositoryProvider` /
    // `nostrSessionProvider` reads the Zendesk mirror makes are notifier reads
    // that build nothing.
    //
    // Activation here happens during the first frame, before
    // `AuthService.initialize()` — that runs in the post-frame `essential`
    // startup phase — so auth still reports `checking` and a restored identity
    // arrives on `authStateStream` rather than through either provider's eager
    // branch.
    ref.watch(zendeskIdentitySyncProvider);
    ref.watch(analyticsIdentitySyncProvider);

    // Reclaims store purchases made before canonical entitlement recording was
    // available. It runs only for an authenticated account with the Worker
    // configured. Canonical state avoids repeated work after success; failures
    // retry when the app returns to the foreground.
    ref.watch(supporterRecoveryProvider);

    // Durable-queue drivers. Each owns a foreground (and, for profile saves,
    // connectivity) subscription that re-drives a Drift-backed queue, and none
    // has a UI consumer — without an activation here they would never be
    // constructed at all (#4124, #3161).
    ref.watch(outgoingDmRetryServiceProvider);
    ref.watch(dmReactionRetryServiceProvider);
    ref.watch(viewEventRetryServiceProvider);
    ref.watch(productEventQueueProvider);
    ref.watch(profileSaveRetryServiceProvider);

    // The one owner of connectivity-driven relay repair (#3161, #8990). The
    // pool has to self-heal on a real network change app-wide, including on
    // routes outside the shell, so it cannot be deferred to
    // [AppShellSideEffects]; its transitions also drive the DM retry sweep.
    // It reads the Nostr client only when a repair fires, so a signed-out
    // launch pays for a connectivity subscription and nothing more.
    ref.watch(connectivityRelayReconnectProvider);

    // Registers the FCM token and drains notification preferences once the
    // signer-backed session is ready. Push must remain correct on top-level
    // routes such as Settings, where [AppShellSideEffects] is not mounted.
    // Both providers gate network work on session readiness, so a signed-out
    // launch pays construction only and never requests notification permission.
    ref.watch(notificationPreferencesDirtySyncBridgeProvider);
    ref.watch(pushNotificationSyncProvider);

    return child;
  }
}

/// App-wide side effects deferred until the bottom-nav shell mounts.
///
/// Mounted by the bottom-nav `StatefulShellRoute` (see `routes/shell.dart`),
/// above `AppShell` rather than inside it, so the shell widget stays pure
/// chrome. Membership rule: activating the provider builds a feed/follow
/// service or starts recurring work that a signed-out user idling on
/// `/welcome` should not pay for.
///
/// The deferral moves *construction*, not correctness: each member either
/// gates its own work on `nostrSessionProvider` readiness, or — as
/// [relayStatisticsBridgeProvider] does — reads the current relay state on
/// activation, which is empty until a session dials relays anyway.
///
/// These are all `keepAlive`, so they are started once and are not torn down
/// when the shell is covered by a pushed full-screen route.
class AppShellSideEffects extends ConsumerWidget {
  const AppShellSideEffects({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Records relay connection events for analytics, and runs a 3s timer
    // syncing per-relay SDK counters — recurring work, so it waits for a
    // signed-in session.
    // TODO(#4338): remove when relay management moves to a dedicated
    // cubit/service.
    ref.watch(relayStatisticsBridgeProvider);

    // Refreshes feeds when the relay set changes. Builds
    // `videoEventServiceProvider`.
    // TODO(#4338): remove when feed refresh is driven by a relay event stream
    // in a cubit.
    ref.watch(relaySetChangeBridgeProvider);

    // Retries a dirty kind:10002 relay-list publish once the session is ready.
    ref.watch(relayListDirtyPublishBridgeProvider);

    // Retries a kind 3 contact-list broadcast withheld by an unreadable
    // relay, once the session is ready or the app returns to the foreground.
    ref.watch(contactListDirtyBroadcastBridgeProvider);

    // Syncs block/mute lists after login, then reconciles follows that
    // contradict a block. The reconciler builds `followRepositoryProvider`.
    // TODO(#4338): remove when BlocklistCubit owns post-login sync.
    ref.watch(blocklistSyncBridgeProvider);
    ref.watch(blockedFollowReconcilerProvider);

    return child;
  }
}
