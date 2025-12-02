// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:convert';

import '../event.dart';

import 'dart:js_interop';
import 'dart:js' as js;

import '../utils/platform_util.dart';

@JS()
external JSPromise nip07GetPublicKey();

@JS()
external JSPromise nip07GetRelays();

@JS()
external JSPromise nip07Nip04Decrypt(String pubkey, String ciphertext);

@JS()
external JSPromise nip07Nip04Encrypt(String pubkey, String plaintext);

@JS()
external JSPromise nip07Nip44Decrypt(String pubkey, String ciphertext);

@JS()
external JSPromise nip07Nip44Encrypt(String pubkey, String plaintext);

@JS()
external JSPromise nip07SignEvent(String eventStr);

bool nip07SignerMethodSupport() {
  if (PlatformUtil.isWeb()) {
    return js.context.callMethod("nip07Support");
  }
  return false;
}

Future<String?> nip07SignerMethodGetPublicKey() async {
  var promise = nip07GetPublicKey();
  return (await promise.toDart) as String?;
}

Future<Map?> nip07SignerMethodGetRelays() async {
  var promise = nip07GetRelays();
  var stringResult = (await promise.toDart) as String?;
  if (stringResult != null) {
    return jsonDecode(stringResult);
  }

  return null;
}

Future<String?> nip07SignerMethodDecrypt(pubkey, ciphertext) async {
  var promise = nip07Nip04Decrypt(pubkey, ciphertext);
  return (await promise.toDart) as String?;
}

Future<String?> nip07SignerMethodEncrypt(pubkey, plaintext) async {
  var promise = nip07Nip04Encrypt(pubkey, plaintext);
  return (await promise.toDart) as String?;
}

Future<String?> nip07SignerMethodNip44Decrypt(pubkey, ciphertext) async {
  var promise = nip07Nip44Decrypt(pubkey, ciphertext);
  return (await promise.toDart) as String?;
}

Future<String?> nip07SignerMethodNip44Encrypt(pubkey, plaintext) async {
  var promise = nip07Nip44Encrypt(pubkey, plaintext);
  return (await promise.toDart) as String?;
}

Future<Event?> nip07SignerMethodSignEvent(Event event) async {
  var promise = nip07SignEvent(jsonEncode(event.toJson()));
  var stringResult = (await promise.toDart) as String?;
  if (stringResult != null) {
    return Event.fromJson(jsonDecode(stringResult));
  }

  return null;
}
