import 'package:nostr_sdk/utils/string_util.dart';

class RelayAddrUtil {
  static String handle(String addr) {
    var uri = Uri.parse(addr);
    if (StringUtil.isBlank(uri.path) &&
        StringUtil.isBlank(uri.query) &&
        StringUtil.isBlank(uri.fragment)) {
      uri = Uri(
        scheme: uri.scheme,
        userInfo: uri.userInfo,
        host: uri.host,
        port: uri.port,
        path: "/",
      );
    }

    return uri.toString();
  }
}
