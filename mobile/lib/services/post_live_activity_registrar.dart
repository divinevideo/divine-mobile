// ABOUTME: Sends post Live Activity registrations through the signed-in
// ABOUTME: account's push service, only ever as the account that owns them.

import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/services/push_notification_service.dart';
import 'package:post_live_activity_repository/post_live_activity_repository.dart';
import 'package:unified_logger/unified_logger.dart';

const _logName = 'PostLiveActivityRegistrar';

/// What the registrar needs from one signed-in account.
class LiveActivityAccountBinding {
  /// Creates a binding for [ownerPubkey].
  const LiveActivityAccountBinding({
    required this.ownerPubkey,
    required this.readPushService,
    required this.readNotificationsAuthorized,
    required this.isActiveAccount,
  });

  /// The account this binding signs as.
  final String ownerPubkey;

  /// The account's push service, or null while it is not ready.
  final PushNotificationService? Function() readPushService;

  /// Whether the OS lets the app show notifications.
  final Future<bool> Function() readNotificationsAuthorized;

  /// Whether [ownerPubkey] is still the signed-in account.
  final bool Function() isActiveAccount;
}

/// Device-level [LiveActivityRegistrar]; account containers attach and
/// detach their bindings as they come and go.
class PostLiveActivityRegistrar implements LiveActivityRegistrar {
  final _bindings = <String, List<_Attached>>{};

  /// Makes [binding] available and returns a handle for [detach].
  Object attach(LiveActivityAccountBinding binding) {
    final attached = _Attached(binding);
    _bindings.putIfAbsent(binding.ownerPubkey, () => []).add(attached);
    return attached;
  }

  /// Removes only the binding that [handle] was returned for.
  void detach(Object handle) {
    if (handle is! _Attached) return;
    final list = _bindings[handle.binding.ownerPubkey];
    if (list == null) return;
    list.remove(handle);
    if (list.isEmpty) _bindings.remove(handle.binding.ownerPubkey);
  }

  _Attached? _latest(String owner) {
    final list = _bindings[owner];
    return list == null || list.isEmpty ? null : list.last;
  }

  @override
  Future<LiveActivityRegistrarResult> register(
    LiveActivityRegistration registration,
  ) async {
    final owner = registration.ownerPubkey;
    final attached = _latest(owner);
    // The account container is still getting ready.
    if (attached == null) return LiveActivityRegistrarResult.retryLater;
    final binding = attached.binding;
    if (!binding.isActiveAccount()) return LiveActivityRegistrarResult.skipped;
    final push = binding.readPushService();
    if (push == null) return LiveActivityRegistrarResult.retryLater;

    final bool authorized;
    try {
      authorized = await binding.readNotificationsAuthorized();
    } on Object catch (error, stack) {
      // The permission read is the plugin's, not the push service's; a
      // failure there is no reason to report the registration as failed.
      Log.warning(
        'Could not read the notification permission for a Live Activity '
        'registration; retrying later',
        name: _logName,
        category: LogCategory.system,
        error: error,
        stackTrace: stack,
      );
      return LiveActivityRegistrarResult.retryLater;
    }
    final result = await push.registerLiveActivity(
      owner,
      registration,
      notificationsAuthorized: authorized,
    );
    switch (result) {
      case PushRegistrationResult.published:
        return LiveActivityRegistrarResult.published;
      case PushRegistrationResult.retryableFailure:
        return LiveActivityRegistrarResult.retryLater;
      case PushRegistrationResult.uncertainFailure:
        return LiveActivityRegistrarResult.uncertain;
      case PushRegistrationResult.terminalFailure:
        // Sign-out deactivates the push service before the identity clears,
        // so a stopped service means the account is leaving, not a failure.
        if (_latest(owner) != attached ||
            !binding.isActiveAccount() ||
            !push.acceptsRegistration) {
          return LiveActivityRegistrarResult.skipped;
        }
        Log.warning(
          'Live Activity registration failed terminally for '
          '${pubkeyForLogs(owner)}',
          name: _logName,
          category: LogCategory.system,
        );
        return LiveActivityRegistrarResult.failed;
    }
  }
}

class _Attached {
  _Attached(this.binding);

  final LiveActivityAccountBinding binding;
}
