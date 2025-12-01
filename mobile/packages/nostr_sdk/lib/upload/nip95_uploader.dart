import 'package:mime/mime.dart';
import 'package:nostr_sdk/utils/path_type_util.dart';
import 'dart:io';

import '../event.dart';
import '../event_kind.dart';
import '../nip19/nip19_tlv.dart';
import '../nostr.dart';
import '../utils/base64.dart';
import '../utils/string_util.dart';

class NIP95Uploader {
  static Future<String?> upload(Nostr nostr, String filePath,
      {String? fileName}) async {
    var result = await uploadForEvent(nostr, filePath, fileName: fileName);
    if (result != null) {
      // TODO Here should set relayAddrs to event.
      return "nostr:${NIP19Tlv.encodeNevent(Nevent(id: result.id, relays: result.sources))}";
    }

    return null;
  }

  static Future<Event?> uploadForEvent(Nostr nostr, String filePath,
      {String? fileName}) async {
    String? base64Content;
    if (BASE64.check(filePath)) {
      base64Content = filePath;
    } else {
      var file = File(filePath);
      var data = await file.readAsBytes();
      base64Content = BASE64.toBase64(data);
    }

    if (StringUtil.isNotBlank(base64Content)) {
      base64Content = base64Content.replaceFirst("data:image/png;base64,", "");
    }

    var mimeType = lookupMimeType(filePath);
    if (StringUtil.isNotBlank(mimeType)) {
      var pathType = PathTypeUtil.getPathType(filePath);
      if (pathType == "image") {
        mimeType = "image/jpeg";
      } else if (pathType == "video") {
        mimeType = "video/mp4";
      } else if (pathType == "audio") {
        mimeType = "audio/mpeg";
      }
    }

    var tags = [
      ["type", mimeType],
      ["alt", "Binary data"],
    ];

    var pubkey = nostr.publicKey;
    var event =
        Event(pubkey, EventKind.STORAGE_SHARED_FILE, tags, base64Content);

    return nostr.sendEvent(event);
  }
}
