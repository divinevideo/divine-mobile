// MPL-2.0
import 'dart:convert';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';

/// POC relay endpoint (controlled local/POC relay; staging default).
const String concordRelayUrl = String.fromEnvironment(
  'CONCORD_RELAY_URL',
  defaultValue: 'wss://relay.staging.dvines.org',
);

/// Stable 32-byte identifier for a channel in the public POC catalog.
String pocChannelIdFor(String channel) =>
    sha256.convert(utf8.encode('concord-poc-channel:$channel')).toString();

/// Deterministic public POC key; not a real community membership grant.
GroupKey pocStreamKeyFor(String channelId) {
  final secret = sha256.convert(utf8.encode('concord-poc-stream:$channelId'));
  return groupKey(
    'concord/channel',
    secret.toString(),
    pocChannelIdFor(channelId),
    epoch: 0,
  );
}

class _UnavailableCipher implements StreamCipher {
  @override
  String seal(String p, String s) =>
      throw StateError('chat requires the active Divine signer');
  @override
  String open(String c, String s) =>
      throw StateError('chat requires the active Divine signer');
}

typedef ConcordRepositoryBuilder = ConcordRepository Function({
  required String? pubkey,
  required NostrSigner? signer,
  required AccountScopedStore store,
});

/// Builds the chat repository bound to the live session: real WebSocket
/// relay, account-scoped store keyed to the signed-in pubkey, and a
/// sealed transport whose author signer is the already signed-in Divine
/// identity (Keycast/local/external). No new login, keypair, or token
/// store is introduced. Signed-out wiring fails closed.
ConcordRepository buildConcordRepository({
  required String? pubkey,
  required NostrSigner? signer,
  required AccountScopedStore store,
}) {
  final relay = WebSocketRelayGateway(concordRelayUrl);
  final sealed = signer != null && pubkey != null
      ? SealedChatTransport(
          relay: relay,
          signer: (template) async {
            final event = Event(
              pubkey,
              template['kind'] as int,
              (template['tags'] as List)
                  .map((t) => (t as List).map((e) => '$e').toList())
                  .toList(),
              template['content'] as String,
              createdAt: template['created_at'] as int,
            );
            final signed = await signer.signEvent(event);
            if (signed == null) {
              throw StateError('session signer refused to sign chat seal');
            }
            return signed.toJson();
          },
        )
      : null;
  return ConcordRepository(
    relay: relay,
    store: store,
    cipher: _UnavailableCipher(),
    sealedTransport: sealed,
  );
}
