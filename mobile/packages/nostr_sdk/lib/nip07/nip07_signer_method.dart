import '../event.dart';

bool nip07SignerMethodSupport() {
  throw UnimplementedError('not implement');
}

Future<String?> nip07SignerMethodGetPublicKey() async {
  throw UnimplementedError('not implement');
}

Future<Map?> nip07SignerMethodGetRelays() async {
  throw UnimplementedError('not implement');
}

Future<String?> nip07SignerMethodDecrypt(
  String pubkey,
  String ciphertext,
) async {
  throw UnimplementedError('not implement');
}

Future<String?> nip07SignerMethodEncrypt(
  String pubkey,
  String plaintext,
) async {
  throw UnimplementedError('not implement');
}

Future<String?> nip07SignerMethodNip44Decrypt(
  String pubkey,
  String ciphertext,
) async {
  throw UnimplementedError('not implement');
}

Future<String?> nip07SignerMethodNip44Encrypt(
  String pubkey,
  String plaintext,
) async {
  throw UnimplementedError('not implement');
}

Future<Event?> nip07SignerMethodSignEvent(Event event) async {
  throw UnimplementedError('not implement');
}
