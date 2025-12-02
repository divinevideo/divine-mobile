import 'dart:convert';

import '../event.dart';
import '../event_kind.dart';
import 'nostr_signer.dart';

Future<void> signerTest(NostrSigner nostrSigner) async {
  var pubkey = await nostrSigner.getPublicKey();
  print("pubkey $pubkey");

  await Future.delayed(const Duration(seconds: 10));

  {
    var ciphertext = await nostrSigner.encrypt(pubkey, "Hello");
    print("ciphertext $ciphertext");

    await Future.delayed(const Duration(seconds: 10));

    var plaintext = await nostrSigner.decrypt(pubkey, ciphertext);
    print("plaintext $plaintext");
  }

  await Future.delayed(const Duration(seconds: 10));

  {
    var ciphertext = await nostrSigner.nip44Encrypt(pubkey, "Hello");
    print("ciphertext $ciphertext");

    await Future.delayed(const Duration(seconds: 10));

    var plaintext = await nostrSigner.nip44Decrypt(pubkey, ciphertext);
    print("plaintext $plaintext");
  }

  await Future.delayed(const Duration(seconds: 10));

  Event? event = Event(pubkey!, EventKind.TEXT_NOTE, [], "Hello");
  event = await nostrSigner.signEvent(event);
  print(event);
  print(jsonEncode(event!.toJson()));
}
