import 'package:models/models.dart';

/// Whether a response names the selected room's canonical Nostr host key.
bool matchesLiveRoomHost({
  required Object? hostPubkey,
  required String expectedHostPubkey,
}) =>
    hostPubkey is String &&
    NostrHexUtils.isValidPubkey(hostPubkey) &&
    hostPubkey == hostPubkey.toLowerCase() &&
    hostPubkey == expectedHostPubkey;
