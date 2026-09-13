// ABOUTME: Tests for RelayDiscoveryOrchestrator — NIP-65 discovery write-backs,
// ABOUTME: stale-session guard, fallback relays, and bootstrap kind:10002.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyContainer;
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth/relay_discovery_orchestrator.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _MockRelayDiscoveryService extends Mock
    implements RelayDiscoveryService {}

/// In-memory [WebSocketSink] that records frames and never touches a socket.
class _FakeWebSocketSink implements WebSocketSink {
  final List<dynamic> added = [];
  final Completer<void> _done = Completer<void>();

  @override
  void add(dynamic data) => added.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await stream.forEach(add);
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> get done => _done.future;
}

/// In-memory [WebSocketChannel] whose inbound stream is driven by the test via
/// [simulateMessage], so the profile-check REQ/EVENT/EOSE exchange runs with no
/// real socket. Mirrors the fake in `nostr_sdk`'s connection-manager tests.
class _FakeWebSocketChannel implements WebSocketChannel {
  _FakeWebSocketChannel({Future<void>? readyFuture})
    : _ready = readyFuture ?? Future<void>.value();

  final _FakeWebSocketSink _sink = _FakeWebSocketSink();
  final StreamController<dynamic> _controller =
      StreamController<dynamic>.broadcast();
  final Future<void> _ready;

  /// Push a raw server frame down to the connected client.
  void simulateMessage(dynamic message) => _controller.add(message);

  @override
  WebSocketSink get sink => _sink;

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  Future<void> get ready => _ready;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not mocked');
}

/// Hands out [_FakeWebSocketChannel]s and, when [readyError] is set, makes the
/// handshake fail so `RelayBase.connect()` reports a dead connection.
class _FakeWebSocketChannelFactory implements WebSocketChannelFactory {
  _FakeWebSocketChannelFactory({this.readyError});

  final Object? readyError;
  final List<_FakeWebSocketChannel> createdChannels = [];

  _FakeWebSocketChannel get lastChannel => createdChannels.last;

  @override
  WebSocketChannel create(Uri uri) {
    final channel = _FakeWebSocketChannel(
      readyFuture: readyError != null
          ? Future<void>.error(readyError!)
          : Future<void>.value(),
    );
    createdChannels.add(channel);
    return channel;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testPrivateKey =
      '6b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e';
  const testPubkey =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';
  const testNpub = 'npub1testonly';
  const primaryRelayUrl = 'wss://relay.test.divine.video';

  group(RelayDiscoveryOrchestrator, () {
    late _MockRelayDiscoveryService discoveryService;
    late List<List<DiscoveredRelay>> userRelaysWrites;
    late List<bool> hasProfileWrites;
    late List<(String, List<String>)> externalRelayCalls;
    late NostrIdentity? identity;
    late bool sessionCurrent;
    late BootstrapRelayListCallback? bootstrapCallback;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      discoveryService = _MockRelayDiscoveryService();
      userRelaysWrites = [];
      hasProfileWrites = [];
      externalRelayCalls = [];
      identity = null;
      sessionCurrent = true;
      bootstrapCallback = null;
    });

    RelayDiscoveryOrchestrator buildOrchestrator({
      WebSocketChannelFactory? profileCheckChannelFactory,
      String? profileCheckIndexerUrl,
    }) => RelayDiscoveryOrchestrator(
      relayDiscoveryService: discoveryService,
      primaryRelayUrl: primaryRelayUrl,
      isSessionCurrent: (_) => sessionCurrent,
      currentIdentity: () => identity,
      onUserRelays: userRelaysWrites.add,
      onHasExistingProfile: hasProfileWrites.add,
      userRelaysDiscoveredCallback: () =>
          (pubkey, urls) => externalRelayCalls.add((pubkey, urls)),
      bootstrapRelayListCallback: () => bootstrapCallback,
      profileCheckChannelFactory: profileCheckChannelFactory,
      profileCheckIndexerUrl: profileCheckIndexerUrl,
    );

    group('discoverUserRelays', () {
      test('reports discovered relays and notifies the external callback '
          'with the target pubkey', () async {
        const relays = [
          DiscoveredRelay(url: 'wss://a.example'),
          DiscoveredRelay(url: 'wss://b.example', write: false),
        ];
        when(
          () => discoveryService.discoverRelays(testNpub),
        ).thenAnswer((_) async => RelayDiscoveryResult.success(relays, 'idx'));

        await buildOrchestrator().discoverUserRelays(testNpub, testPubkey);

        expect(userRelaysWrites, equals([relays]));
        expect(externalRelayCalls, hasLength(2));
        expect(externalRelayCalls.first.$1, equals(testPubkey));
        expect(
          externalRelayCalls.first.$2,
          equals(['wss://a.example', 'wss://b.example']),
        );
        expect(externalRelayCalls.last.$1, equals(testPubkey));
        expect(
          externalRelayCalls.last.$2,
          equals(IndexerRelayConfig.dmInboxTaggedRelays),
        );
      });

      test('ignores results for a stale session', () async {
        sessionCurrent = false;
        when(() => discoveryService.discoverRelays(testNpub)).thenAnswer(
          (_) async => RelayDiscoveryResult.success(const [
            DiscoveredRelay(url: 'wss://a.example'),
          ], 'idx'),
        );

        await buildOrchestrator().discoverUserRelays(testNpub, testPubkey);

        expect(userRelaysWrites, isEmpty);
        expect(externalRelayCalls, isEmpty);
      });

      test('empty discovery clears relays and connects the safe fallback '
          'set without reporting it as user relays', () async {
        when(
          () => discoveryService.discoverRelays(testNpub),
        ).thenAnswer((_) async => RelayDiscoveryResult.success(const [], null));

        await buildOrchestrator().discoverUserRelays(testNpub, testPubkey);

        expect(userRelaysWrites, equals([<DiscoveredRelay>[]]));
        expect(externalRelayCalls, hasLength(1));
        expect(
          externalRelayCalls.single.$2,
          equals(IndexerRelayConfig.safeFallbackRelays),
        );
      });

      test('discovery failure clears relays and connects the safe fallback '
          'set', () async {
        when(
          () => discoveryService.discoverRelays(testNpub),
        ).thenThrow(Exception('indexers unreachable'));

        await buildOrchestrator().discoverUserRelays(testNpub, testPubkey);

        expect(userRelaysWrites, equals([<DiscoveredRelay>[]]));
        expect(
          externalRelayCalls.single.$2,
          equals(IndexerRelayConfig.safeFallbackRelays),
        );
      });

      test('discovery failure for a stale session writes nothing', () async {
        sessionCurrent = false;
        when(
          () => discoveryService.discoverRelays(testNpub),
        ).thenThrow(Exception('indexers unreachable'));

        await buildOrchestrator().discoverUserRelays(testNpub, testPubkey);

        expect(userRelaysWrites, isEmpty);
        expect(externalRelayCalls, isEmpty);
      });
    });

    group('publishBootstrapRelayList', () {
      LocalNostrIdentity localIdentity() => LocalNostrIdentity(
        keyContainer: SecureKeyContainer.fromPrivateKeyHex(testPrivateKey),
      );

      test('no-ops without a current identity', () async {
        var called = false;
        bootstrapCallback = (event, relays) async {
          called = true;
          return true;
        };

        await buildOrchestrator().publishBootstrapRelayList();

        expect(called, isFalse);
      });

      test('no-ops without a registered callback', () async {
        identity = localIdentity();

        await buildOrchestrator().publishBootstrapRelayList();

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool('bootstrap_kind10002_published_$testPubkey'),
          isNull,
        );
      });

      test('signs and publishes a kind:10002 pointing at the primary relay, '
          'then sets the one-shot flag', () async {
        identity = localIdentity();
        Event? publishedEvent;
        List<String>? publishedTargets;
        bootstrapCallback = (event, relays) async {
          publishedEvent = event;
          publishedTargets = relays;
          return true;
        };

        await buildOrchestrator().publishBootstrapRelayList();

        expect(publishedEvent, isNotNull);
        expect(publishedEvent!.kind, equals(EventKind.relayListMetadata));
        expect(publishedEvent!.pubkey, equals(testPubkey));
        expect(publishedEvent!.sig, isNotEmpty);
        expect(
          publishedEvent!.tags,
          equals([
            ['r', primaryRelayUrl],
          ]),
        );
        expect(
          publishedTargets,
          equals([primaryRelayUrl, ...IndexerRelayConfig.defaultIndexers]),
        );
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool('bootstrap_kind10002_published_$testPubkey'),
          isTrue,
        );
      });

      test('leaves the flag unset when no relay accepts the event so the '
          'next login retries', () async {
        identity = localIdentity();
        bootstrapCallback = (event, relays) async => false;

        await buildOrchestrator().publishBootstrapRelayList();

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool('bootstrap_kind10002_published_$testPubkey'),
          isNull,
        );
      });

      test('skips publishing when the one-shot flag is already set', () async {
        SharedPreferences.setMockInitialValues({
          'bootstrap_kind10002_published_$testPubkey': true,
        });
        identity = localIdentity();
        var called = false;
        bootstrapCallback = (event, relays) async {
          called = true;
          return true;
        };

        await buildOrchestrator().publishBootstrapRelayList();

        expect(called, isFalse);
      });
    });

    group('checkExistingProfile', () {
      const indexerUrl = 'wss://indexer.test.divine.video';

      test(
        'reports false without network when no pubkey is available',
        () async {
          await buildOrchestrator().checkExistingProfile(null);

          expect(hasProfileWrites, equals([false]));
        },
      );

      test('reports true when the indexer returns a kind:0 EVENT', () async {
        final channelFactory = _FakeWebSocketChannelFactory();

        final future = buildOrchestrator(
          profileCheckChannelFactory: channelFactory,
          profileCheckIndexerUrl: indexerUrl,
        ).checkExistingProfile(testPubkey);

        // Let connect() finish so the inbound stream listener is attached
        // before the frame is pushed — the channel stream is broadcast and
        // drops events that arrive with no listener.
        await pumpEventQueue();
        channelFactory.lastChannel.simulateMessage(
          jsonEncode(<dynamic>[
            'EVENT',
            'sub',
            <String, dynamic>{'kind': 0, 'pubkey': testPubkey},
          ]),
        );
        await future;

        expect(hasProfileWrites, equals([true]));
        expect(channelFactory.createdChannels, hasLength(1));
      });

      test('uses an opaque subscription id for the profile check', () async {
        final channelFactory = _FakeWebSocketChannelFactory();

        final future = buildOrchestrator(
          profileCheckChannelFactory: channelFactory,
          profileCheckIndexerUrl: indexerUrl,
        ).checkExistingProfile(testPubkey);

        await pumpEventQueue();
        final request = jsonDecode(
          channelFactory.lastChannel._sink.added.single as String,
        ) as List<dynamic>;
        final subscriptionId = request[1] as String;
        channelFactory.lastChannel.simulateMessage(
          jsonEncode(<dynamic>['EOSE', subscriptionId]),
        );
        await future;

        expect(subscriptionId, hasLength(16));
        expect(RegExp(r'^[0-9a-z]{16}$').hasMatch(subscriptionId), isTrue);
      });

      test(
        'reports false when the indexer returns EOSE with no event',
        () async {
          final channelFactory = _FakeWebSocketChannelFactory();

          final future = buildOrchestrator(
            profileCheckChannelFactory: channelFactory,
            profileCheckIndexerUrl: indexerUrl,
          ).checkExistingProfile(testPubkey);

          await pumpEventQueue();
          channelFactory.lastChannel.simulateMessage(
            jsonEncode(<dynamic>['EOSE', 'sub']),
          );
          await future;

          expect(hasProfileWrites, equals([false]));
        },
      );

      test(
        'reports false when the indexer connection cannot be established',
        () async {
          final channelFactory = _FakeWebSocketChannelFactory(
            readyError: Exception('handshake failed'),
          );

          await buildOrchestrator(
            profileCheckChannelFactory: channelFactory,
            profileCheckIndexerUrl: indexerUrl,
          ).checkExistingProfile(testPubkey);

          expect(hasProfileWrites, equals([false]));
        },
      );
    });

    group('connectToFallbackRelays', () {
      test('pushes the safe fallback set through the external callback', () {
        buildOrchestrator().connectToFallbackRelays(testPubkey);

        expect(externalRelayCalls, hasLength(1));
        expect(externalRelayCalls.single.$1, equals(testPubkey));
        expect(
          externalRelayCalls.single.$2,
          equals(IndexerRelayConfig.safeFallbackRelays),
        );
      });

      test(
        'pushes the tagged DM inbox relays without reporting user relays',
        () {
          buildOrchestrator().connectToDmInboxRelays(testPubkey);

          expect(externalRelayCalls, hasLength(1));
          expect(externalRelayCalls.single.$1, equals(testPubkey));
          expect(
            externalRelayCalls.single.$2,
            equals(IndexerRelayConfig.dmInboxTaggedRelays),
          );
          expect(userRelaysWrites, isEmpty);
        },
      );
    });
  });
}
