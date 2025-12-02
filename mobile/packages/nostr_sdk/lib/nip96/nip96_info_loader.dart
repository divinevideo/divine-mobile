import '../utils/dio_util.dart';
import 'nip96_server_adaptation.dart';

class NIP96InfoLoader {
  static NIP96InfoLoader? _nip96infoLoader;

  static NIP96InfoLoader getInstance() {
    _nip96infoLoader ??= NIP96InfoLoader();

    return _nip96infoLoader!;
  }

  Map<String, Nip96ServerAdaptation> serverAdaptations = {};

  Future<Nip96ServerAdaptation?> getServerAdaptation(String url) async {
    var sa = serverAdaptations[url];
    sa ??= await pullServerAdaptation(url);

    if (sa != null) {
      serverAdaptations[url] = sa;
    }

    return sa;
  }

  Future<Nip96ServerAdaptation?> pullServerAdaptation(String url) async {
    var uri = Uri.parse(url);
    var newUri = Uri(
        scheme: uri.scheme,
        host: uri.host,
        path: "/.well-known/nostr/nip96.json");

    var jsonMap = await DioUtil.get(newUri.toString());
    if (jsonMap != null) {
      return Nip96ServerAdaptation.fromJson(jsonMap);
    }

    return null;
  }
}
