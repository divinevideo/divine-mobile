import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;

import 'relay_info.dart';

class RelayInfoUtil {
  static Future<RelayInfo?> get(String url) async {
    late Uri uri;
    if (url.indexOf("wss://") == 0) {
      uri = Uri.parse(url).replace(scheme: 'https');
    } else {
      uri = Uri.parse(url).replace(scheme: 'http');
    }
    try {
      final response = await http.get(
        uri,
        headers: {'Accept': 'application/nostr+json'},
      );
      final decodedResponse = jsonDecode(response.body) as Map;
      return RelayInfo.fromJson(decodedResponse);
    } catch (e) {
      log("RelayInfo get error:");
      log('$e');
    }

    return null;
  }
}
