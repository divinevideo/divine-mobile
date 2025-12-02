import 'dart:convert';

import 'package:hex/hex.dart';
import 'package:nostr_sdk/event.dart';

import '../nip19/nip19.dart';
import '../signer/nostr_signer.dart';
import '../utils/string_util.dart';

class PrivateZap {
  static Future<String?> decryptZapEvent(
      NostrSigner signer, Event event) async {
    var signerPubkey = await signer.getPublicKey();
    var tags = event.tags;
    var senderPubkey = event.pubkey;
    String? receiverPubkey;
    String? pubkey;

    String? anonStr;
    for (var tag in tags) {
      if (tag is List && tag.length > 1) {
        var k = tag[0];
        if (k == "anon") {
          anonStr = tag[1];
        } else if (k == "p") {
          receiverPubkey = tag[1];
        }
      }
    }

    if (senderPubkey == signerPubkey || receiverPubkey == signerPubkey) {
      if (senderPubkey == signerPubkey) {
        pubkey = receiverPubkey;
      } else if (receiverPubkey == signerPubkey) {
        pubkey = senderPubkey;
      }

      if (StringUtil.isNotBlank(anonStr)) {
        var strs = anonStr!.split("_");
        if (strs.length > 1) {
          var encryptedText = Nip19.decode(strs[0]);
          var iv = Nip19.decode(strs[1]);

          encryptedText = base64.encode(HEX.decode(encryptedText));
          iv = base64.encode(HEX.decode(iv));
          var source = await signer.decrypt(pubkey, "$encryptedText?iv=$iv");
          return source;
        }
      }
    }

    return null;
  }
}
