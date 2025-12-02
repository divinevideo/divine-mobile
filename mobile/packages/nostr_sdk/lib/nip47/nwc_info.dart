import 'dart:developer';

import '../client_utils/keys.dart';
import '../utils/string_util.dart';

class NWCInfo {
  String relay;

  String secret;

  String pubkey;

  String? lud16;

  NWCInfo(this.relay, this.secret, this.pubkey, {this.lud16});

  static NWCInfo? loadFromUrl(String? url) {
    if (StringUtil.isBlank(url)) {
      return null;
    }

    try {
      var uri = Uri.parse(url!);
      var pubkey = uri.host;
      var pars = uri.queryParameters;
      var relay = pars["relay"];
      var secret = pars["secret"];
      var lud16 = pars["lud16"];

      if (uri.scheme == "nostr+walletconnect" &&
          StringUtil.isNotBlank(relay) &&
          StringUtil.isNotBlank(secret)) {
        return NWCInfo(relay!, secret!, pubkey, lud16: lud16);
      }
    } catch (e) {
      log("NWCInfo loadFromUrl error $e");
    }

    return null;
  }

  @override
  String toString() {
    var relayStr = Uri.encodeQueryComponent(relay);
    var text = "nostr+walletconnect:$pubkey?relay=$relayStr&secret=$secret";
    if (StringUtil.isNotBlank(lud16)) {
      text += "&lud16=${lud16!}";
    }
    return text;
  }

  String senderPubkey() {
    return getPublicKey(secret);
  }
}
