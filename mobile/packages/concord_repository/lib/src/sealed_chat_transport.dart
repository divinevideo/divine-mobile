// MPL-2.0
import 'package:concord_repository/src/concord_repository.dart';
import 'package:concord_repository/src/sealed_transport.dart';

/// Live sealed-send path: seals with the async session signer, wraps
/// under the stream key (kind 1059), publishes through the relay
/// gateway, and opens received wraps with full verification.
class SealedChatTransport {
  SealedChatTransport({required this.relay, required this.signer});
  final RelayGateway relay;
  final SealSigner signer;

  Future<Map<String, dynamic>> sendRumor({
    required Map<String, dynamic> rumor,
    required String streamSeedHex,
    required String streamPubkey,
  }) async {
    final seal = await sealRumorWithSigner(
      rumor: rumor,
      sealKind: 20013,
      streamSeedHex: streamSeedHex,
      streamPubkey: streamPubkey,
      signer: signer,
    );
    final wrap = await wrapSeal(
      seal: seal,
      streamSeedHex: streamSeedHex,
      streamPubkey: streamPubkey,
    );
    await relay.publish(wrap);
    return wrap;
  }

  Future<Map<String, dynamic>> openIncoming({
    required Map<String, dynamic> wrap,
    required String streamSeedHex,
    required String streamPubkey,
  }) => openWrap(
    wrap: wrap,
    streamSeedHex: streamSeedHex,
    streamPubkey: streamPubkey,
  );

  Stream<Map<String, dynamic>> subscribeWraps({
    required String streamPubkey,
  }) => relay.subscribe({
    'kinds': [1059],
    'authors': [streamPubkey],
  });
}
