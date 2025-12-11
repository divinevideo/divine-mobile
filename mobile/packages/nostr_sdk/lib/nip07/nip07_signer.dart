// ABOUTME: Web browser NIP-07 signer implementation for window.nostr API.
// ABOUTME: Handles signing and encryption via browser extension like Alby or nos2x.

import 'dart:async';

import '../event.dart';
import '../signer/nostr_signer.dart';
import 'nip07_signer_method.dart'
    if (dart.library.io) 'nip07_signer_method_io.dart'
    if (dart.library.js) 'nip07_signer_method_web.dart';

class NIP07Signer extends NostrSigner {
  static String uriPre = "websigner";

  static bool isWebNostrSignerKey(String key) {
    if (key.startsWith(uriPre)) {
      return true;
    }
    return false;
  }

  static String getPubkey(String key) {
    var strs = key.split(":");
    if (strs.length >= 2) {
      return strs[1];
    }

    return key;
  }

  static bool support() {
    return nip07SignerMethodSupport();
  }

  NIP07Signer({String? pubkey}) {
    _pubkey = pubkey;
  }

  String? _pubkey;

  @override
  Future<String?> getPublicKey() async {
    if (_pubkey != null) {
      return _pubkey!;
    }

    var stringResult = await nip07SignerMethodGetPublicKey();
    if (stringResult != null) {
      _pubkey = stringResult;
    }

    return _pubkey;
  }

  @override
  Future<Map?> getRelays() async {
    return nip07SignerMethodGetRelays();
  }

  @override
  Future<String?> decrypt(pubkey, ciphertext) async {
    return nip07SignerMethodDecrypt(pubkey, ciphertext);
  }

  @override
  Future<String?> encrypt(pubkey, plaintext) async {
    return nip07SignerMethodEncrypt(pubkey, plaintext);
  }

  @override
  Future<String?> nip44Decrypt(pubkey, ciphertext) async {
    return nip07SignerMethodNip44Decrypt(pubkey, ciphertext);
  }

  @override
  Future<String?> nip44Encrypt(pubkey, plaintext) async {
    return nip07SignerMethodNip44Encrypt(pubkey, plaintext);
  }

  @override
  Future<Event?> signEvent(Event event) async {
    return nip07SignerMethodSignEvent(event);
  }

  @override
  void close() {}
}
