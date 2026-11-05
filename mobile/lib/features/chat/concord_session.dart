// MPL-2.0
import 'dart:convert';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:openvine/features/chat/concord_configuration.dart';

const _defaultConcordRelay = 'wss://relay.staging.dvines.org';

String resolveConcordRelay({required String invite, required String relay}) {
  if (invite.isNotEmpty && !isSecureConcordRelay(relay)) {
    throw StateError('Configured community requires an explicit secure relay');
  }
  return relay.isEmpty ? _defaultConcordRelay : relay;
}

String get concordRelayUrl => resolveConcordRelay(
  invite: const String.fromEnvironment('CONCORD_INVITE_URL'),
  relay: const String.fromEnvironment('CONCORD_RELAY_URL'),
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
  NostrSigner? Function()? signerForSend,
  ConcordControlState? Function()? controlState,
  bool Function()? canPublish,
  Map<String, ConcordOutboxReadKey> Function()? historicalOutboxKeys,
}) {
  final relay = WebSocketRelayGateway(concordRelayUrl);
  final sealed = signer != null && pubkey != null
      ? SealedChatTransport(
          relay: relay,
          signer: (template) async {
            // A restored account can gain its live RPC signer without its auth
            // enum changing. Resolve it per send rather than pinning the stub.
            final activeSigner = signerForSend == null
                ? signer
                : signerForSend();
            if (activeSigner == null) {
              throw StateError('chat session is no longer active');
            }
            final event = Event(
              pubkey,
              template['kind'] as int,
              (template['tags'] as List)
                  .map((t) => (t as List).map((e) => '$e').toList())
                  .toList(),
              template['content'] as String,
              createdAt: template['created_at'] as int,
            );
            final signed = await activeSigner.signEvent(event);
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
    controlState: controlState,
    canPublish: canPublish,
    historicalOutboxKeys: historicalOutboxKeys,
    outboxAuthor: pubkey,
    sealedTransport: sealed,
  );
}
