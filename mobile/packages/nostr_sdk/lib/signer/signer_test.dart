import 'dart:convert';
import 'dart:developer';

import '../event.dart';
import '../event_kind.dart';
import 'nostr_signer.dart';

Future<void> signerTest(NostrSigner nostrSigner) async {
  var pubkey = await nostrSigner.getPublicKey();
  if (pubkey == null) {
    log("pubkey is null, cannot continue test");
    return;
  }
  log("pubkey $pubkey");

  await Future.delayed(const Duration(seconds: 10));

  {
    var ciphertext = await nostrSigner.encrypt(pubkey, "Hello");
    log("ciphertext $ciphertext");

    await Future.delayed(const Duration(seconds: 10));

    if (ciphertext != null) {
      var plaintext = await nostrSigner.decrypt(pubkey, ciphertext);
      log("plaintext $plaintext");
    }
  }

  await Future.delayed(const Duration(seconds: 10));

  {
    var ciphertext = await nostrSigner.nip44Encrypt(pubkey, "Hello");
    log("ciphertext $ciphertext");

    await Future.delayed(const Duration(seconds: 10));

    if (ciphertext != null) {
      var plaintext = await nostrSigner.nip44Decrypt(pubkey, ciphertext);
      log("plaintext $plaintext");
    }
  }

  await Future.delayed(const Duration(seconds: 10));

  Event? event = Event(pubkey, EventKind.textNote, [], "Hello");
  event = await nostrSigner.signEvent(event);
  log('$event');
  log(jsonEncode(event!.toJson()));
}
