// MPL-2.0
import 'dart:convert';

/// Cipher port injected by the repository layer. The Concord stream
/// envelope is deliberately distinct from standard NIP-59 DM gift wraps:
/// it never produces kind 1059/13/14 events.
abstract interface class StreamCipher {
  String seal(String plaintext, String streamId);
  String open(String ciphertext, String streamId);
}

/// POC envelope kind (provisional, pending spec confirmation).
const int streamEnvelopeKind = 33303;

class StreamEnvelope {
  StreamEnvelope({
    required this.streamId,
    required this.ciphertext,
    required this.createdAt,
  });
  final String streamId;
  final String ciphertext;
  final int createdAt;
  Map<String, dynamic> toEventJson(String pubkey) => {
    'kind': streamEnvelopeKind,
    'pubkey': pubkey,
    'created_at': createdAt,
    'content': ciphertext,
    'tags': [
      ['stream', streamId],
    ],
  };
  static StreamEnvelope seal(
    StreamCipher c, {
    required String streamId,
    required String plaintext,
    required int createdAt,
  }) => StreamEnvelope(
    streamId: streamId,
    createdAt: createdAt,
    ciphertext: c.seal(plaintext, streamId),
  );
  String open(StreamCipher c) => c.open(ciphertext, streamId);
  String encode() => jsonEncode(toEventJson(''));
}
