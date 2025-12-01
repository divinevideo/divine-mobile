import '../client_utils/keys.dart';
import '../nip19/nip19.dart';
import '../utils/string_util.dart';

/// This client is designed for nostr client.
class NostrRemoteSignerInfo {
  String remoteSignerPubkey;

  List<String> relays;

  String? optionalSecret;

  // Client signer nsec, sometime need to save all info in one place, so nsec should save as a par here.
  String? nsec;

  // User Pubkey, sometime need to save all info in one place, so nsec should save as a par here.
  String? userPubkey;

  NostrRemoteSignerInfo({
    required this.remoteSignerPubkey,
    required this.relays,
    this.optionalSecret,
    this.nsec,
    this.userPubkey,
  });

  @override
  String toString() {
    Map<String, dynamic> pars = {};
    pars["relay"] = relays;
    pars["secret"] = optionalSecret;
    if (nsec != null) {
      pars["nsec"] = nsec;
    }
    if (userPubkey != null) {
      pars["userPubkey"] = userPubkey;
    }

    var uri = Uri(
      scheme: "bunker",
      host: remoteSignerPubkey,
      queryParameters: pars,
    );

    return uri.toString();
  }

  static bool isBunkerUrl(String? bunkerUrlText) {
    if (bunkerUrlText != null) {
      return bunkerUrlText.startsWith("bunker://");
    }

    return false;
  }

  static NostrRemoteSignerInfo? parseBunkerUrl(String bunkerUrlText,
      {String? nsec}) {
    var uri = Uri.parse(bunkerUrlText);

    var pars = uri.queryParametersAll;

    var remoteSignerPubkey = uri.host;

    var relays = pars["relay"];
    if (relays == null || relays.isEmpty) {
      return null;
    }

    var optionalSecrets = pars["secret"];
    String? optionalSecret;
    if (optionalSecrets != null && optionalSecrets.isNotEmpty) {
      optionalSecret = optionalSecrets.first;
    }

    if (StringUtil.isBlank(nsec)) {
      if (pars["nsec"] != null && pars["nsec"]!.isNotEmpty) {
        nsec = pars["nsec"]!.first;
      } else {
        nsec = Nip19.encodePrivateKey(generatePrivateKey());
      }
    }

    var userPubkeys = pars["userPubkey"];
    String? userPubkey;
    if (userPubkeys != null && userPubkeys.isNotEmpty) {
      userPubkey = userPubkeys.first;
    }

    return NostrRemoteSignerInfo(
      remoteSignerPubkey: remoteSignerPubkey,
      relays: relays,
      optionalSecret: optionalSecret,
      nsec: nsec!,
      userPubkey: userPubkey,
    );
  }
}
