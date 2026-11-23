// ABOUTME: Videos, commenters and watch recorders for tests that run a real
// ABOUTME: NostrClient against an InMemoryRelay.

import 'dart:async';

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

import 'in_memory_relay.dart';

/// Bounds every wait, so a regression fails instead of hanging.
const relayWaitTimeout = Duration(seconds: 5);

/// The kind of the videos comments are posted on.
const testVideoKind = 34236;

/// Loopback with nothing listening, so the relay information lookup the
/// client makes on connect fails at once instead of reaching the network.
const _relayUrl = 'ws://127.0.0.1:1';

/// A connected [NostrClient] whose only relay is [relay].
Future<NostrClient> connectTo(InMemoryRelay relay) async {
  final client = NostrClient(
    config: NostrClientConfig(
      signer: LocalNostrSigner(generatePrivateKey()),
      webSocketChannelFactory: relay,
    ),
    relayManagerConfig: RelayManagerConfig(
      defaultRelayUrl: _relayUrl,
      storage: InMemoryRelayStorage(),
      webSocketChannelFactory: relay,
    ),
  );
  await client.initialize();
  return client;
}

/// A video comments are posted on.
class TestVideo {
  TestVideo()
    : id = generatePrivateKey(),
      authorPubkey = getPublicKey(generatePrivateKey());

  final String id;
  final String authorPubkey;
}

/// Someone commenting from another client, straight onto the relay.
class TestCommenter {
  TestCommenter() : _privateKey = generatePrivateKey();

  final String _privateKey;

  String get pubkey => getPublicKey(_privateKey);

  /// A NIP-22 top-level comment on [video].
  Event comment(TestVideo video, String text) => Event(pubkey, 1111, [
    ['E', video.id, '', video.authorPubkey],
    ['K', '$testVideoKind'],
    ['P', video.authorPubkey],
    ['e', video.id, '', video.authorPubkey],
    ['k', '$testVideoKind'],
    ['p', video.authorPubkey],
  ], text)..sign(_privateKey);

  /// A NIP-09 request to delete the comment [commentId].
  Event deletion(String commentId) => Event(pubkey, 5, [
    ['e', commentId],
    ['k', '1111'],
  ], '')..sign(_privateKey);
}

/// Records what a watch has delivered, so a test can wait for one item.
class Received<T> {
  Received(Stream<T> stream, this._idOf) {
    _subscription = stream.listen((item) {
      final id = _idOf(item);
      ids.add(id);
      _arrivals.add(id);
    });
  }

  final String Function(T item) _idOf;

  /// The id of every item delivered so far.
  final Set<String> ids = {};

  final StreamController<String> _arrivals = StreamController.broadcast();
  late final StreamSubscription<T> _subscription;

  /// Completes once the watch has delivered the item [id].
  Future<void> waitFor(String id) => ids.contains(id)
      ? Future.value()
      : _arrivals.stream
            .firstWhere((arrived) => arrived == id)
            .timeout(
              relayWaitTimeout,
              onTimeout: () => fail('Never delivered $id'),
            );

  /// Stops listening to the watch, which ends it.
  Future<void> cancel() async {
    await _subscription.cancel();
    await _arrivals.close();
  }
}
