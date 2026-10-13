// MPL-2.0
import 'dart:convert';

/// Cipher port injected by the repository layer (NIP-44 via the app
/// signer). Concord stream envelopes are kind 1059 wraps carrying a
/// kind 20013 (chat/guestbook/rekey) or 20014 (control) seal — the same
/// outer kinds as NIP-59, but with Concord stream addressing, epoch
/// binding, and validation; they are never plain DM gift wraps.
abstract interface class StreamCipher {
  String seal(String plaintext, String streamId);
  String open(String ciphertext, String streamId);
}

int sealKindForPlane(String plane) => plane == 'control' ? 20014 : 20013;

/// Outer stream wrap kind (CORD-01).
const int streamWrapKind = 1059;

class StreamEnvelope {
  StreamEnvelope({
    required this.streamId,
    required this.ciphertext,
    required this.createdAt,
  });
  factory StreamEnvelope.seal(
    StreamCipher c, {
    required String streamId,
    required String plaintext,
    required int createdAt,
  }) => StreamEnvelope(
    streamId: streamId,
    createdAt: createdAt,
    ciphertext: c.seal(plaintext, streamId),
  );
  final String streamId;
  final String ciphertext;
  final int createdAt;
  Map<String, dynamic> toEventJson(String pubkey) => {
    'kind': streamWrapKind,
    'pubkey': pubkey,
    'created_at': createdAt,
    'content': ciphertext,
    'tags': [
      ['p', streamId],
    ],
  };
  String open(StreamCipher c) => c.open(ciphertext, streamId);
  String encode() => jsonEncode(toEventJson(''));
}
