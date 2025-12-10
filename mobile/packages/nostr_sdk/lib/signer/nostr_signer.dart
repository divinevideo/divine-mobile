import '../event.dart';

abstract class NostrSigner {
  Future<String?> getPublicKey();

  Future<Event?> signEvent(Event event);

  Future<Map?> getRelays();

  Future<String?> encrypt(String pubkey, String plaintext);

  Future<String?> decrypt(String pubkey, String ciphertext);

  Future<String?> nip44Encrypt(String pubkey, String plaintext);

  Future<String?> nip44Decrypt(String pubkey, String ciphertext);

  void close();
}
