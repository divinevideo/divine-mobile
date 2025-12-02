import '../event.dart';

abstract class NostrSigner {
  Future<String?> getPublicKey();

  Future<Event?> signEvent(Event event);

  Future<Map?> getRelays();

  Future<String?> encrypt(pubkey, plaintext);

  Future<String?> decrypt(pubkey, ciphertext);

  Future<String?> nip44Encrypt(pubkey, plaintext);

  Future<String?> nip44Decrypt(pubkey, ciphertext);

  void close();
}
