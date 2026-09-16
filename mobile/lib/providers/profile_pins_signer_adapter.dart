// ABOUTME: Adapts AuthService to the ProfilePinsRepository signer port.
// ABOUTME: Kept out of auth_service.dart, which is a frozen god file (#4338).

import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/repositories/profile_pins_repository.dart';
import 'package:openvine/services/auth_service.dart';

/// Presents [AuthService] as the narrow [ProfilePinsSigner] the pinned-video
/// repository depends on, for the same reason `BookmarkSignerAdapter` exists:
/// an `implements` clause on `AuthService` would grow a file the god-file
/// ratchet refuses to let grow.
class ProfilePinsSignerAdapter implements ProfilePinsSigner {
  /// Wraps [authService].
  const ProfilePinsSignerAdapter(this._authService);

  final AuthService _authService;

  @override
  String? get currentPublicKeyHex => _authService.currentPublicKeyHex;

  @override
  Future<Event?> createAndSignEvent({
    required int kind,
    required String content,
    List<List<String>>? tags,
    int? createdAt,
  }) => _authService.createAndSignEvent(
    kind: kind,
    content: content,
    tags: tags,
    createdAt: createdAt,
  );
}
