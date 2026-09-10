import 'package:nostr_sdk/event.dart';

/// Minimal signer interface for publishing signed Nostr events from a
/// repository without depending on the app's auth stack.
///
/// Consumed by repositories that publish on the user's behalf (e.g.
/// `ContentBlocklistRepository` for the NIP-51 kind 10000 mute list and the
/// legacy kind 30000 block list) and implemented at the app layer (e.g.
/// `AuthService`). Kept intentionally narrow — it only needs [Event] from
/// `nostr_sdk`, so neither the repository nor this contract depends on the
/// app's auth stack.
abstract class BlockListSigner {
  /// Whether the current user is authenticated and can sign events.
  bool get isAuthenticated;

  /// Creates and signs a Nostr event with the given [kind], [content], and
  /// [tags]. Returns `null` if signing fails or the user is not
  /// authenticated.
  Future<Event?> createAndSignEvent({
    required int kind,
    required String content,
    List<List<String>>? tags,
    int? createdAt,
  });
}
