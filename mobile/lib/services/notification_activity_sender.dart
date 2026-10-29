import 'dart:async';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:openvine/services/nip98_auth_service.dart';

/// Signs visibility updates for the captured owner immediately before sending.
class NotificationActivitySender {
  NotificationActivitySender({
    required FunnelcakeApiClient client,
    required Nip98AuthService authService,
  }) : _client = client,
       _authService = authService;

  static const _signingTimeout = Duration(seconds: 15);
  final FunnelcakeApiClient _client;
  final Nip98AuthService _authService;

  /// Discards superseded lifecycle work and signatures from retired accounts.
  Future<void> send(
    String owner,
    NotificationActivityUpdate update,
    bool Function() isCurrent,
  ) async {
    bool current() => isCurrent() && _authService.isCurrentOwner(owner);
    if (!current()) return;
    final token = await _authService
        .createAuthToken(
          url: _client.notificationActivityUri.toString(),
          method: HttpMethod.post,
          payload: update.body,
          reuseCached: false,
        )
        .timeout(_signingTimeout);
    if (!current()) return;
    if (token == null || token.signedEvent.pubkey != owner) {
      throw const Nip98AuthException(
        'Notification activity signer unavailable',
      );
    }
    await _client.recordNotificationActivity(
      update,
      authHeaders: {'Authorization': token.authorizationHeader},
    );
  }
}
