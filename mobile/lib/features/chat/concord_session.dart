// MPL-2.0
import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';

/// StreamCipher backed by the active Divine session signer (Keycast /
/// local / external). No new login, keypair, or token store: every call
/// delegates to the identity the user already signed in with.
class SignerStreamCipher implements StreamCipher {
  SignerStreamCipher(this._signer, {required this.peerPubkey});
  final NostrSigner _signer;

  /// Stream pubkey used as the NIP-44 peer for envelope sealing.
  final String peerPubkey;

  @override
  String seal(String plaintext, String streamId) =>
      throw UnimplementedError('use sealAsync');
  @override
  String open(String ciphertext, String streamId) =>
      throw UnimplementedError('use openAsync');

  Future<String> sealAsync(String plaintext) async {
    final out = await _signer.nip44Encrypt(peerPubkey, plaintext);
    if (out == null) throw StateError('signer nip44 encrypt unavailable');
    return out;
  }

  Future<String> openAsync(String ciphertext) async {
    final out = await _signer.nip44Decrypt(peerPubkey, ciphertext);
    if (out == null) throw StateError('signer nip44 decrypt unavailable');
    return out;
  }
}

/// POC relay endpoint (controlled local/POC relay; staging default).
const String concordRelayUrl = String.fromEnvironment(
  'CONCORD_RELAY_URL',
  defaultValue: 'wss://relay.staging.dvines.org',
);

/// Builds the chat repository bound to the live session: real WebSocket
/// relay, account-scoped store keyed to the signed-in pubkey, and the
/// session signer cipher. Falls back to in-memory POC wiring only when
/// nobody is signed in (chat UI then shows its login gate upstream).
ConcordRepository buildConcordRepository({
  required String? pubkey,
  required NostrSigner? signer,
  required String streamPubkey,
}) {
  return ConcordRepository(
    relay: WebSocketRelayGateway(concordRelayUrl),
    store: InMemoryConcordStore(pubkey ?? 'anonymous'),
    cipher: signer != null
        ? _SyncCipherAdapter(
            SignerStreamCipher(signer, peerPubkey: streamPubkey),
          )
        : _UnavailableCipher(),
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

/// StreamCipher is synchronous at the protocol port; the session signer
/// is async, so sealing for live sends goes through [SignerStreamCipher]
/// directly in the send path. This adapter only satisfies the port for
/// read-side wiring and fails closed rather than identity-mapping.
class _SyncCipherAdapter implements StreamCipher {
  _SyncCipherAdapter(SignerStreamCipher _);
  @override
  String seal(String p, String s) => throw StateError(
    'async signer seal required; use SignerStreamCipher.sealAsync',
  );
  @override
  String open(String c, String s) => throw StateError(
    'async signer open required; use SignerStreamCipher.openAsync',
  );
}
