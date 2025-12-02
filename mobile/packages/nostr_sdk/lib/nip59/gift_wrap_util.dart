import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;

import '../client_utils/keys.dart';
import '../event.dart';
import '../event_kind.dart';
import '../nip44/nip44_v2.dart';
import '../nostr.dart';

class GiftWrapUtil {
  static Future<Event?> getRumorEvent(Nostr nostr, Event e) async {
    var rumorText = await nostr.nostrSigner.nip44Decrypt(e.pubkey, e.content);
    if (rumorText == null) {
      return null;
    }

    var rumorJson = jsonDecode(rumorText);
    var rumorEvent = Event.fromJson(rumorJson);

    if (!rumorEvent.isValid || !rumorEvent.isSigned) {
      log("GiftWrap rumorEvent sign check result fail, id: ${e.id}, from: ${e.pubkey}");
      return null;
    }

    var sourceText = await nostr.nostrSigner
        .nip44Decrypt(rumorEvent.pubkey, rumorEvent.content);
    if (sourceText == null) {
      return null;
    }

    var jsonObj = jsonDecode(sourceText);
    return Event.fromJson(jsonObj);
  }

  static Future<Event?> getGiftWrapEvent(
      Nostr nostr, Event e, String receiverPublicKey) async {
    var giftEventCreatedAt =
        e.createdAt - math.Random().nextInt(60 * 60 * 24 * 2);
    var rumorEventMap = e.toJson();
    rumorEventMap.remove("sig");

    var sealEventContent = await nostr.nostrSigner
        .nip44Encrypt(receiverPublicKey, jsonEncode(rumorEventMap));
    if (sealEventContent == null) {
      return null;
    }
    var sealEvent =
        Event(nostr.publicKey, EventKind.SEAL_EVENT_KIND, [], sealEventContent);
    await nostr.signEvent(sealEvent);

    var randomPrivateKey = generatePrivateKey();
    var randomPubkey = getPublicKey(randomPrivateKey);
    var randomKey = NIP44V2.shareSecret(randomPrivateKey, receiverPublicKey);
    var giftWrapEventContent =
        await NIP44V2.encrypt(jsonEncode(sealEvent.toJson()), randomKey);
    var giftWrapEvent = Event(
        randomPubkey,
        EventKind.GIFT_WRAP,
        [
          ["p", receiverPublicKey]
        ],
        giftWrapEventContent,
        createdAt: giftEventCreatedAt);
    giftWrapEvent.sign(randomPrivateKey);

    return giftWrapEvent;
  }
}
