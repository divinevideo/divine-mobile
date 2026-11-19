// ABOUTME: Binds passive recommendation request authentication to one account.
// ABOUTME: Reuses passive NIP-98 without signing for a replacement account.

import 'package:openvine/services/nip98_auth_service.dart';

/// Supplies exact-request authentication while this discovery owner is current.
class FindPeopleRequestAuth {
  const FindPeopleRequestAuth({
    required String owner,
    required String? Function() currentPubkey,
    required Nip98AuthService authService,
  }) : _owner = owner,
       _currentPubkey = currentPubkey,
       _authService = authService;

  final String _owner;
  final String? Function() _currentPubkey;
  final Nip98AuthService _authService;

  /// Unavailable signing leaves the server in its safe public-ranking context.
  /// The repository independently aborts retired requests before HTTP dispatch.
  Future<Map<String, String>> headersFor(Uri uri) async {
    if (_currentPubkey() != _owner) return const {};
    final token = await _authService.createAuthToken(
      url: uri.toString(),
      method: HttpMethod.get,
      allowUserInteraction: false,
    );
    if (_currentPubkey() != _owner ||
        token == null ||
        token.signedEvent.pubkey != _owner) {
      return const {};
    }
    return {'Authorization': token.authorizationHeader};
  }
}
