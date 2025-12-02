import 'dart:convert';
import 'dart:developer';

import 'package:bech32/bech32.dart';

import '../event.dart';
import '../event_kind.dart';
import '../nip19/nip19.dart';
import '../nostr.dart';
import '../utils/dio_util.dart';
import '../utils/string_util.dart';
import 'lnurl_response.dart';

class Zap {
  static String decodeLud06Link(String lud06) {
    var decoder = Bech32Decoder();
    var bech32Result = decoder.convert(lud06, 2000);
    var data = Nip19.convertBits(bech32Result.data, 5, 8, false);
    return utf8.decode(data);
  }

  static String? getLud16LinkFromLud16(String lud16) {
    var strs = lud16.split("@");
    if (strs.length < 2) {
      return null;
    }

    var username = strs[0];
    var domainname = strs[1];

    return "https://$domainname/.well-known/lnurlp/$username";
  }

  static String? getLnurlFromLud16(String lud16) {
    var link = getLud16LinkFromLud16(lud16);
    List<int> data = utf8.encode(link!);
    data = Nip19.convertBits(data, 8, 5, true);

    var encoder = Bech32Encoder();
    Bech32 input = Bech32("lnurl", data);
    var lnurl = encoder.convert(input, 2000);

    return lnurl.toUpperCase();
  }

  static Future<LnurlResponse?> getLnurlResponse(String link) async {
    var responseMap = await DioUtil.get(link);
    if (responseMap != null && StringUtil.isNotBlank(responseMap["callback"])) {
      return LnurlResponse.fromJson(responseMap);
    }

    return null;
  }

  static Future<String?> getInvoiceCode({
    required String lnurl,
    required String lud16Link,
    required int sats,
    required String recipientPubkey,
    String? eventId,
    required Nostr targetNostr,
    required List<String> relays,
    String? pollOption,
    String? comment,
  }) async {
    // var lnurlLink = decodeLud06Link(lnurl);
    var lnurlResponse = await getLnurlResponse(lud16Link);
    if (lnurlResponse == null) {
      return null;
    }

    var callback = lnurlResponse.callback!;
    if (callback.contains("?")) {
      callback += "&";
    } else {
      callback += "?";
    }

    var amount = sats * 1000;
    callback += "amount=$amount";

    String eventContent = "";
    if (StringUtil.isNotBlank(comment)) {
      var commentNum = lnurlResponse.commentAllowed;
      if (commentNum != null) {
        if (commentNum < comment!.length) {
          comment = comment.substring(0, commentNum);
        }
        callback += "&comment=${Uri.encodeQueryComponent(comment)}";
        eventContent = comment;
      }
    }

    var tags = [
      ["relays", ...relays],
      ["amount", amount.toString()],
      ["lnurl", lnurl],
      ["p", recipientPubkey],
    ];
    if (StringUtil.isNotBlank(eventId)) {
      tags.add(["e", eventId!]);
    }
    if (StringUtil.isNotBlank(pollOption)) {
      tags.add(["poll_option", pollOption!]);
    }
    Event? event =
        Event(targetNostr.publicKey, EventKind.ZAP_REQUEST, tags, eventContent);
    event = await targetNostr.nostrSigner.signEvent(event);
    if (event == null) {
      return null;
    }
    log(jsonEncode(event));
    var eventStr = Uri.encodeQueryComponent(jsonEncode(event));
    callback += "&nostr=$eventStr";
    callback += "&lnurl=$lnurl";

    log("getInvoice callback $callback");

    var responseMap = await DioUtil.get(callback);
    if (responseMap != null && StringUtil.isNotBlank(responseMap["pr"])) {
      return responseMap["pr"];
    }

    return null;
  }
}
