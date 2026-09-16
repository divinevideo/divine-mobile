// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifications_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Bridges Nostr session readiness to push notification registration.
///
/// Registers FCM token only after the signer-backed Nostr client is ready.
/// Deregisters the last ready client through AuthService's pre-teardown hook so
/// outgoing-session cleanup runs before signers and callbacks are cleared. The
/// returned coordinator lets account switching run the same captured-identity
/// cleanup after the replacement account has committed.

@ProviderFor(pushNotificationSync)
final pushNotificationSyncProvider = PushNotificationSyncProvider._();

/// Bridges Nostr session readiness to push notification registration.
///
/// Registers FCM token only after the signer-backed Nostr client is ready.
/// Deregisters the last ready client through AuthService's pre-teardown hook so
/// outgoing-session cleanup runs before signers and callbacks are cleared. The
/// returned coordinator lets account switching run the same captured-identity
/// cleanup after the replacement account has committed.

final class PushNotificationSyncProvider
    extends
        $FunctionalProvider<
          PushNotificationSessionCoordinator?,
          PushNotificationSessionCoordinator?,
          PushNotificationSessionCoordinator?
        >
    with $Provider<PushNotificationSessionCoordinator?> {
  /// Bridges Nostr session readiness to push notification registration.
  ///
  /// Registers FCM token only after the signer-backed Nostr client is ready.
  /// Deregisters the last ready client through AuthService's pre-teardown hook so
  /// outgoing-session cleanup runs before signers and callbacks are cleared. The
  /// returned coordinator lets account switching run the same captured-identity
  /// cleanup after the replacement account has committed.
  PushNotificationSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushNotificationSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushNotificationSyncHash();

  @$internal
  @override
  $ProviderElement<PushNotificationSessionCoordinator?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PushNotificationSessionCoordinator? create(Ref ref) {
    return pushNotificationSync(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushNotificationSessionCoordinator? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushNotificationSessionCoordinator?>(
        value,
      ),
    );
  }
}

String _$pushNotificationSyncHash() =>
    r'a08c32bb6b3e31711d5ead99494ccf9b17181bb2';
