// ABOUTME: Tests for how a room call recovers what the relays lose: an offer
// ABOUTME: or answer that never arrives, and a subscription the relays close

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:nostr_sdk/client_utils/keys.dart' as keys;
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/collab_room/call/collab_room_call.dart';
import 'package:openvine/collab_room/call/collab_room_call_signal.dart';
import 'package:openvine/collab_room/call/collab_room_call_transport.dart';
import 'package:sound_service/sound_service.dart';

class _FakeSender extends Fake implements RTCRtpSender {}

class _FakeTransceiver extends Fake implements RTCRtpTransceiver {
  @override
  final RTCRtpSender sender = _FakeSender();
}

/// A connection that makes offers and takes answers, and counts what was
/// done to it. It waits for an answer until it gets one.
class _FakePeerConnection extends Fake implements RTCPeerConnection {
  RTCSignalingState _signaling =
      RTCSignalingState.RTCSignalingStateHaveLocalOffer;
  int answers = 0;
  int closes = 0;
  int disposes = 0;

  @override
  Function(RTCPeerConnectionState state)? onConnectionState;

  @override
  Function(RTCTrackEvent event)? onTrack;

  @override
  Function(RTCIceGatheringState state)? onIceGatheringState;

  @override
  Function(RTCIceCandidate candidate)? onIceCandidate;

  @override
  RTCSignalingState? get signalingState => _signaling;

  @override
  Future<RTCRtpSender> addTrack(
    MediaStreamTrack track, [
    MediaStream? stream,
  ]) async => _FakeSender();

  @override
  Future<RTCRtpTransceiver> addTransceiver({
    MediaStreamTrack? track,
    RTCRtpMediaType? kind,
    RTCRtpTransceiverInit? init,
  }) async => _FakeTransceiver();

  @override
  Future<RTCSessionDescription> createOffer([
    Map<String, dynamic> constraints = const {},
  ]) async => RTCSessionDescription('v=0', 'offer');

  @override
  Future<void> setLocalDescription(RTCSessionDescription description) async {}

  @override
  Future<RTCSessionDescription?> getLocalDescription() async =>
      RTCSessionDescription('v=0', 'offer');

  @override
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    answers++;
    _signaling = RTCSignalingState.RTCSignalingStateStable;
  }

  @override
  Future<void> close() async => closes++;

  @override
  Future<void> dispose() async => disposes++;
}

/// Hands the call what [incoming] carries from the time it asks for, as a
/// relay does, and keeps what it sends. Each subscription closes at once
/// while [closes] is set.
class _RelayTransport implements CollabRoomCallTransport {
  final incoming = StreamController<Event>.broadcast();
  final _sent = StreamController<Event>.broadcast();
  final sent = <Event>[];
  final _watched = StreamController<int>.broadcast();
  bool closes = false;
  int subscriptions = 0;

  /// Each message as it is sent.
  Stream<Event> get sending => _sent.stream;

  /// The count of subscriptions, each time one is made.
  Stream<int> get watching => _watched.stream;

  @override
  Stream<Event> watch(String author, {required int since}) {
    _watched.add(++subscriptions);
    return closes
        ? const Stream.empty()
        : incoming.stream.where((event) => event.createdAt >= since);
  }

  @override
  Future<void> publish(Event event) async {
    sent.add(event);
    _sent.add(event);
  }
}

/// Short enough to run the whole retry budget in a test.
const _answerTimeout = Duration(milliseconds: 60);

/// Long enough that a retry would surely have come.
const _quiet = Duration(milliseconds: 300);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(WebRtcCollabRoomCall, () {
    const channel = MethodChannel('FlutterWebRTC.Method');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late _RelayTransport transport;
    late String callKey;
    late String meKey;
    late String me;
    late String otherKey;
    late String other;
    late List<_FakePeerConnection> connections;
    late StreamController<int> made;
    late WebRtcCollabRoomCall call;

    /// A call that says hello again after [helloRetryDelays], by default
    /// never, so each test sees only the messages it is about.
    WebRtcCollabRoomCall makeCall({
      List<Duration> helloRetryDelays = const [],
    }) => WebRtcCollabRoomCall(
      me: me,
      others: {other},
      callKey: callKey,
      accountSigner: LocalNostrSigner(meKey),
      transport: transport,
      gatherTimeout: Duration.zero,
      answerTimeout: _answerTimeout,
      relayRetryDelays: const [
        Duration(milliseconds: 10),
        Duration(milliseconds: 10),
        Duration(milliseconds: 10),
      ],
      helloRetryDelays: helloRetryDelays,
      createConnection: (_) async {
        final connection = _FakePeerConnection();
        connections.add(connection);
        made.add(connections.length);
        return connection;
      },
    );

    setUp(() {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method != 'getUserMedia') return null;
        return {
          'streamId': 'microphone',
          'audioTracks': [
            {
              'id': 'mic-track',
              'label': 'Microphone',
              'kind': 'audio',
              'enabled': true,
            },
          ],
        };
      });
      transport = _RelayTransport();
      callKey = keys.generatePrivateKey();
      // This device offers: the one with the smaller pubkey does.
      final a = keys.generatePrivateKey();
      final b = keys.generatePrivateKey();
      final aFirst = keys.getPublicKey(a).compareTo(keys.getPublicKey(b)) < 0;
      meKey = aFirst ? a : b;
      otherKey = aFirst ? b : a;
      me = keys.getPublicKey(meKey);
      other = keys.getPublicKey(otherKey);
      connections = [];
      made = StreamController<int>.broadcast();
      call = makeCall();
    });

    tearDown(() async {
      await call.stop();
      messenger.setMockMethodCallHandler(channel, null);
      await transport.incoming.close();
      await made.close();
    });

    CollabRoomCallChannel theirChannel() => CollabRoomCallChannel(
      callKey,
      accountPubkey: other,
      accountSigner: LocalNostrSigner(otherKey),
    );

    Future<void> hearFromThem(CollabRoomCallSignal signal) async {
      final event = await theirChannel().seal(signal, recipient: me);
      transport.incoming.add(event);
    }

    Future<void> hello() => hearFromThem(
      CollabRoomCallSignal(
        type: CollabRoomCallSignalType.hello,
        from: other,
        session: 'theirs',
      ),
    );

    /// The next offer this device sends.
    Future<CollabRoomCallSignal> nextOffer() async {
      await for (final event in transport.sending) {
        final signal = await theirChannel().open(event, others: {me});
        if (signal?.type == CollabRoomCallSignalType.offer) return signal!;
      }
      throw StateError('No offer was sent');
    }

    group('the audio session', () {
      test('is held for the call from start to stop', () async {
        expect(AudioSessionService.isHeldByCall, isFalse);

        await call.start();
        // The editor's playback setup, made while the call comes back,
        // must not take the call's microphone and speaker.
        expect(AudioSessionService.isHeldByCall, isTrue);

        await call.stop();
        expect(AudioSessionService.isHeldByCall, isFalse);
      });

      test('is not held by a call stopped before it started', () async {
        await call.stop();
        await call.start();

        expect(AudioSessionService.isHeldByCall, isFalse);
      });
    });

    group('an offer whose answer never comes', () {
      test('is made again on a new connection', () async {
        await call.start();
        final offers = nextOffer();
        await hello();
        await offers;

        final again = nextOffer();
        await again.timeout(const Duration(seconds: 5));

        expect(connections, hasLength(2));
        expect(connections.first.closes, 1);
      });

      test('is not made again once answered', () async {
        await call.start();
        final first = nextOffer();
        await hello();
        final offer = await first;

        await hearFromThem(
          CollabRoomCallSignal(
            type: CollabRoomCallSignalType.answer,
            from: other,
            session: 'theirs',
            to: me,
            toSession: offer.session,
            sdp: 'v=0',
            sdpType: 'answer',
          ),
        );

        await expectLater(
          made.stream.first.timeout(_quiet),
          throwsA(isA<TimeoutException>()),
        );
        expect(connections, hasLength(1));
        expect(connections.single.answers, 1);
      });

      test('is given up after two more tries', () async {
        await call.start();
        final third = made.stream.firstWhere((count) => count == 3);
        await hello();
        await third.timeout(const Duration(seconds: 5));

        await expectLater(
          made.stream.first.timeout(_quiet),
          throwsA(isA<TimeoutException>()),
        );
        expect(connections, hasLength(3));
      });
    });

    group('a hello nobody answers', () {
      setUp(() async {
        await call.stop();
        call = makeCall(
          helloRetryDelays: const [
            Duration(milliseconds: 20),
            Duration(milliseconds: 20),
          ],
        );
      });

      Future<List<CollabRoomCallSignalType>> sentTypes() async => [
        for (final event in transport.sent)
          (await theirChannel().open(event, others: {me}))!.type,
      ];

      test('is said twice more', () async {
        await call.start();
        await transport.sending
            .take(2)
            .last
            .timeout(const Duration(seconds: 5));
        await pumpEventQueue();

        await expectLater(
          transport.sending.first.timeout(_quiet),
          throwsA(isA<TimeoutException>()),
        );
        expect(await sentTypes(), [
          CollabRoomCallSignalType.hello,
          CollabRoomCallSignalType.hello,
          CollabRoomCallSignalType.hello,
        ]);
      });

      test('is not said again once they are heard', () async {
        await call.start();
        final offered = nextOffer();
        await hello();
        await offered.timeout(const Duration(seconds: 5));

        await expectLater(
          transport.sending
              .asyncMap((event) => theirChannel().open(event, others: {me}))
              .firstWhere(
                (signal) => signal?.type == CollabRoomCallSignalType.hello,
              )
              .timeout(_quiet),
          throwsA(isA<TimeoutException>()),
        );
      });
    });

    group('a peer whose clock runs behind', () {
      test('is heard from the start', () async {
        await call.start();
        final offered = nextOffer();
        final hello = await theirChannel().seal(
          CollabRoomCallSignal(
            type: CollabRoomCallSignalType.hello,
            from: other,
            session: 'theirs',
          ),
          recipient: me,
        );
        // The same hello from a phone 20 seconds slow.
        transport.incoming.add(
          Event(
            hello.pubkey,
            hello.kind,
            hello.tags,
            hello.content,
            createdAt: hello.createdAt - 20,
          )..sign(callKey),
        );

        await offered.timeout(const Duration(seconds: 5));

        expect(connections, hasLength(1));
      });
    });

    group('a subscription the relays close', () {
      test('is listened to again, saying hello again', () async {
        transport.closes = true;
        // Only the first close: the test is about coming back once.
        final again = transport.watching.firstWhere((count) => count == 2);
        final hello = transport.sending.first;
        await call.start();
        await hello;
        final secondHello = transport.sending.first;

        await again.timeout(const Duration(seconds: 5));
        await secondHello.timeout(const Duration(seconds: 5));

        expect(transport.sent, hasLength(greaterThanOrEqualTo(2)));
      });

      test('fails the call after closing again and again', () async {
        transport.closes = true;
        final failed = Completer<Object>();
        call.changes.listen((_) {}, onError: failed.complete);

        await call.start();

        expect(
          await failed.future.timeout(const Duration(seconds: 5)),
          isA<CollabRoomCallException>(),
        );
        expect(transport.subscriptions, 4);
      });
    });

    group('on Android', () {
      setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
      tearDown(() => debugDefaultTargetPlatformOverride = null);

      // flutter_webrtc only leaves call mode when the last peer connection
      // is disposed.
      test('hands the audio back after a call that connected nobody', () async {
        await call.start();

        await call.stop();

        expect(connections, hasLength(1));
        expect(connections.single.disposes, 1);
      });

      test('needs nothing extra once a connection was made', () async {
        await call.start();
        final offered = nextOffer();
        await hello();
        await offered;

        await call.stop();

        expect(connections, hasLength(1));
      });
    });
  });
}
