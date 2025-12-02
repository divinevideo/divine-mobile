import '../event.dart';
import 'nostr_signer.dart';

class PubkeyOnlyNostrSigner implements NostrSigner {
  String pubkey;

  PubkeyOnlyNostrSigner(this.pubkey);

  @override
  Future<String?> decrypt(pubkey, ciphertext) async {
    return null;
  }

  @override
  Future<String?> encrypt(pubkey, plaintext) async {
    return null;
  }

  @override
  Future<String?> getPublicKey() async {
    return pubkey;
  }

  @override
  Future<Map?> getRelays() async {
    return null;
  }

  @override
  Future<Event?> signEvent(Event event) async {
    return null;
  }

  @override
  Future<String?> nip44Decrypt(pubkey, ciphertext) async {
    return null;
  }

  @override
  Future<String?> nip44Encrypt(pubkey, plaintext) async {
    return null;
  }

  @override
  void close() {}
}
