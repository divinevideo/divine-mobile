// ABOUTME: Exposes the device-level post Live Activity repository to
// ABOUTME: account containers, and keeps it in step with the signed-in account.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/device_scope.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/notifications_providers.dart';
import 'package:openvine/providers/provider_detached_future.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/post_live_activity_channel.dart';
import 'package:openvine/services/post_live_activity_registrar.dart';
import 'package:openvine/services/push_notification_service.dart';
import 'package:openvine/utils/platform_support.dart';
import 'package:post_live_activity_repository/post_live_activity_repository.dart';
import 'package:unified_logger/unified_logger.dart';

const _syncLogName = 'PostLiveActivitySync';

/// The device-level pieces of the post Live Activity. Device-scoped because
/// an activity outlives an account switch.
class PostLiveActivityDevice {
  /// Creates the device-level bundle.
  const PostLiveActivityDevice({
    required this.channel,
    required this.registrar,
    required this.repository,
  });

  /// The native bridge.
  final PostLiveActivityChannel channel;

  /// Sends registrations as the account that owns them.
  final PostLiveActivityRegistrar registrar;

  /// Decides when the activity starts, registers and ends.
  final PostLiveActivityRepository repository;
}

/// The shared repository, or null off iOS. Overridden from `DeviceScope`.
final postLiveActivityRepositoryProvider =
    Provider<PostLiveActivityRepository?>(
      (_) => null,
    );

/// The shared registrar, or null off iOS. Overridden from `DeviceScope`.
final postLiveActivityRegistrarProvider = Provider<PostLiveActivityRegistrar?>(
  (_) => null,
);

/// Keeps the device-level post Live Activity in step with this container's
/// account. Every account container builds it (`AppRootSideEffects`).
///
/// - Binds the account to the registrar once its signer-backed session is
///   ready; registrations made earlier get `retryLater`.
/// - Ends the account's activities on the device once it stops being the
///   signed-in identity, independent of the sign-out teardown budget. The
///   teardown callback is only an earlier best effort.
/// - Sweeps after binding and on every resume, only while this container is
///   the live one. A settled signed-out state sweeps with no owner.
/// - Allows activities only while the flag is on and the account signs
///   without a prompt (v1), and ends every activity when either rules it out.
final postLiveActivitySyncProvider = Provider<void>((ref) {
  final repository = ref.watch(postLiveActivityRepositoryProvider);
  final registrar = ref.watch(postLiveActivityRegistrarProvider);
  if (repository == null || registrar == null) return;

  final authService = ref.watch(authServiceProvider);
  final switchController = ref.read(deviceScopeProvider).switchController;
  final container = ref.container;
  // Before the swap host mounts, the startup container is the live one.
  bool isCurrentContainer() => identical(
    switchController.currentContainer ?? container,
    container,
  );

  final sync = _PostLiveActivitySync(
    repository: repository,
    registrar: registrar,
    authService: authService,
    readSession: () => ref.read(nostrSessionProvider),
    readFlag: () =>
        ref.read(isFeatureEnabledProvider(FeatureFlag.postLiveActivity)),
    isCurrentContainer: isCurrentContainer,
    bindingFor: (owner) => LiveActivityAccountBinding(
      ownerPubkey: owner,
      readPushService: () =>
          ref.mounted ? ref.read(pushNotificationServiceProvider) : null,
      readNotificationsAuthorized: () async {
        if (!ref.mounted || !isFirebaseSupported) return false;
        final messaging = ref.read(firebaseMessagingProvider);
        final settings = await messaging.getNotificationSettings();
        return notificationsAuthorizedFor(settings.authorizationStatus);
      },
      isActiveAccount: () =>
          isCurrentContainer() && authService.currentIdentity?.pubkey == owner,
    ),
  );

  final unregisterBeforeSessionTeardown = authService
      .registerBeforeSessionTeardownCallback(sync.endOwnerBeforeTeardown);

  ref
    ..listen<AuthState>(currentAuthStateProvider, (_, _) => sync.reconcile())
    // NostrService can clear the session before auth state is re-emitted.
    ..listen<NostrSessionReadiness>(
      nostrSessionProvider,
      (_, _) => sync.reconcile(),
    )
    ..listen<bool>(
      isFeatureEnabledProvider(FeatureFlag.postLiveActivity),
      (_, _) => sync.reconcile(),
    );

  final lifecycle = AppLifecycleListener(
    onResume: () => runProviderDetached(
      sync.sweepOnResume(),
      'sweep post Live Activities after resume',
      logName: _syncLogName,
    ),
  );

  sync.reconcile();

  ref.onDispose(() {
    lifecycle.dispose();
    unregisterBeforeSessionTeardown();
    sync.dispose();
  });
});

class _PostLiveActivitySync {
  _PostLiveActivitySync({
    required this.repository,
    required this.registrar,
    required this.authService,
    required this.readSession,
    required this.readFlag,
    required this.isCurrentContainer,
    required this.bindingFor,
  });

  final PostLiveActivityRepository repository;
  final PostLiveActivityRegistrar registrar;
  final AuthService authService;
  final NostrSessionReadiness Function() readSession;
  final bool Function() readFlag;
  final bool Function() isCurrentContainer;
  final LiveActivityAccountBinding Function(String owner) bindingFor;

  /// The signed-in account this container last saw.
  String? _owner;
  Object? _binding;
  bool? _allowed;
  bool _sweptSignedOut = false;

  void reconcile() {
    final identity = authService.currentIdentity?.pubkey;
    final owner = _owner;
    // Only the identity decides: a signer upgrade for the same account
    // passes through tearingDown, and nostrReady -> identityKnown is not
    // the account leaving.
    if (owner != null && identity != owner) _endOwner(owner);
    if (identity != null) {
      _owner = identity;
      _sweptSignedOut = false;
    }
    final allowed = _syncAllowed(identity);
    _syncBinding(identity, allowed: allowed);
    _sweepIfSignedOut(identity);
  }

  Future<void> endOwnerBeforeTeardown() async {
    final owner = _owner;
    if (owner == null) return;
    await repository.endLocally(ownerPubkey: owner);
  }

  Future<void> sweepOnResume() async {
    if (!isCurrentContainer()) return;
    final identity = authService.currentIdentity?.pubkey;
    if (identity != null) {
      await repository.sweep(currentOwnerPubkey: identity);
    } else if (authService.authState == AuthState.unauthenticated) {
      await repository.sweep(currentOwnerPubkey: null);
    }
  }

  void dispose() => _detach();

  void _endOwner(String owner) {
    _owner = null;
    _detach();
    Log.info(
      'Ending post Live Activities of ${pubkeyForLogs(owner)}: '
      'no longer the signed-in account',
      name: _syncLogName,
      category: LogCategory.system,
    );
    runProviderDetached(
      repository.endLocally(ownerPubkey: owner),
      'end the leaving account post Live Activities',
      logName: _syncLogName,
    );
  }

  /// Whether activities are allowed now; ends them all when that turns off.
  bool _syncAllowed(String? identity) {
    // A signed-out or still-restoring container has no signer to judge, so
    // only the flag applies until an identity is known.
    final allowed =
        readFlag() &&
        (identity == null ||
            signsWithoutPrompting(authService.authenticationSource));
    if (!allowed) _detach();
    if (!isCurrentContainer()) return allowed;
    repository.featureEnabled = allowed;
    if (allowed == _allowed) return allowed;
    _allowed = allowed;
    if (allowed) return allowed;
    runProviderDetached(
      repository.endAll(),
      'end post Live Activities the flag or signer rules out',
      logName: _syncLogName,
    );
    return allowed;
  }

  void _syncBinding(String? identity, {required bool allowed}) {
    if (identity == null || !allowed || _binding != null) return;
    final session = readSession();
    if (!session.isReadyForActiveClient || session.pubkey != identity) return;
    _binding = registrar.attach(bindingFor(identity));
    if (!isCurrentContainer()) return;
    runProviderDetached(
      repository.sweep(currentOwnerPubkey: identity),
      'sweep post Live Activities after binding',
      logName: _syncLogName,
    );
  }

  void _sweepIfSignedOut(String? identity) {
    if (identity != null || _sweptSignedOut) return;
    if (authService.authState != AuthState.unauthenticated) return;
    if (!isCurrentContainer()) return;
    _sweptSignedOut = true;
    runProviderDetached(
      repository.sweep(currentOwnerPubkey: null),
      'sweep post Live Activities while signed out',
      logName: _syncLogName,
    );
  }

  void _detach() {
    final binding = _binding;
    if (binding == null) return;
    _binding = null;
    registrar.detach(binding);
  }
}
