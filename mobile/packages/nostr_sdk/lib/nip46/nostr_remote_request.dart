import 'dart:convert';

import '../signer/nostr_signer.dart';
import '../utils/string_util.dart';

class NostrRemoteRequest {
  String id;

  String method;

  List<String> params;

  NostrRemoteRequest(this.method, this.params) : id = StringUtil.rndNameStr(12);

  Future<String?> encrypt(NostrSigner signer, String pubkey) async {
    Map<String, dynamic> jsonMap = {};
    jsonMap["id"] = id;
    jsonMap["method"] = method;
    jsonMap["params"] = params;

    var jsonStr = jsonEncode(jsonMap);
    return await signer.nip44Encrypt(pubkey, jsonStr);
  }

  static Future<NostrRemoteRequest?> decrypt(
      String ciphertext, NostrSigner signer, String pubkey) async {
    try {
      var plaintext = await signer.nip44Decrypt(pubkey, ciphertext);
      if (StringUtil.isNotBlank(plaintext)) {
        // print(plaintext);
        var jsonMap = jsonDecode(plaintext!);

        var id = jsonMap["id"];
        var method = jsonMap["method"];
        var params0 = jsonMap["params"];
        List<String> params = [];
        if (params0 != null && params0 is List) {
          for (var param in params0) {
            params.add(param);
          }
        }

        if (id != null && id is String && method != null && method is String) {
          var request = NostrRemoteRequest(method, params);
          request.id = id;
          return request;
        }
      }
    } catch (e) {
      print("NostrRemoteRequest decrypt error");
      print(e);
    }

    return null;
  }
}
