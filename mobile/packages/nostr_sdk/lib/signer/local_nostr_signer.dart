import 'package:pointycastle/export.dart';
import '../client_utils/keys.dart' as keys;
import '../event.dart';
import '../nip04/nip04.dart';
import '../nip44/nip44_v2.dart';
import '../relay/native_schnorr_sign.dart';
import 'nostr_signer.dart';

class LocalNostrSigner implements NostrSigner {
  final String _privateKey;

  late String _publicKey;

  ECDHBasicAgreement? _agreement;
  bool _nativeSignerDisabled = false;

  LocalNostrSigner(this._privateKey) {
    _publicKey = keys.getPublicKey(_privateKey);
  }

  @override
  Future<String?> decrypt(pubkey, ciphertext) async {
    var agreement = getAgreement();
    return NIP04.decrypt(ciphertext, agreement, pubkey);
  }

  @override
  Future<String?> encrypt(pubkey, plaintext) async {
    var agreement = getAgreement();
    return NIP04.encrypt(plaintext, agreement, pubkey);
  }

  @override
  Future<String?> getPublicKey() async {
    return _publicKey;
  }

  @override
  Future<Map?> getRelays() async {
    return null;
  }

  @override
  Future<Event?> signEvent(Event event) async {
    if (!_nativeSignerDisabled && keys.keyIsValid(_privateKey)) {
      final nativeSign = resolveNativeSchnorrSigner();
      if (nativeSign != null) {
        try {
          event.sig = await nativeSign(
            privateKey: _privateKey,
            message: event.id,
            auxRand: keys.getRandomHexString(),
          );
          return event;
        } on Object catch (_) {
          _nativeSignerDisabled = true;
        }
      }
    }
    event.sign(_privateKey);
    return event;
  }

  ECDHBasicAgreement getAgreement() {
    _agreement ??= NIP04.getAgreement(_privateKey);
    return _agreement!;
  }

  @override
  Future<String?> nip44Decrypt(pubkey, ciphertext) async {
    var sealKey = NIP44V2.shareSecret(_privateKey, pubkey);
    return await NIP44V2.decrypt(ciphertext, sealKey);
  }

  @override
  Future<String?> nip44Encrypt(pubkey, plaintext) async {
    var conversationKey = NIP44V2.shareSecret(_privateKey, pubkey);
    return await NIP44V2.encrypt(plaintext, conversationKey);
  }

  @override
  void close() {}
}
