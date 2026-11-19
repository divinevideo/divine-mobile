// ABOUTME: Tests for how a room call recovers what the relays lose: an offer
// ABOUTME: or answer that never arrives, and a subscription the relays close

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/client_utils/keys.dart' as keys;
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/collab_room/call/collab_room_call.dart';
import 'package:openvine/collab_room/call/collab_room_call_signal.dart';
import 'package:openvine/collab_room/call/collab_room_call_transport.dart';

class _MockPeerConnection extends Mock implements RTCPeerConnection {}

class _MockTransceiver extends Mock implements RTCRtpTransceiver {}

class _MockSender extends Mock implements RTCRtpSender {}

class _FakeTrack extends Fake implements MediaStreamTrack {}

class _FakeStream extends Fake implements MediaStream {}

/// Hands the call what [incoming] carries and keeps what it sends. Each
/// subscription closes at once while [closes] is set.
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
    return closes ? const Stream.empty() : incoming.stream;
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
    late List<_MockPeerConnection> connections;
    late StreamController<int> made;
    late RTCSignalingState signaling;
    late WebRtcCollabRoomCall call;

    setUpAll(() {
      registerFallbackValue(_FakeTrack());
      registerFallbackValue(_FakeStream());
      registerFallbackValue(RTCSessionDescription('', ''));
      registerFallbackValue(RTCRtpMediaType.RTCRtpMediaTypeVideo);
      registerFallbackValue(RTCRtpTransceiverInit());
    });

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
      signaling = RTCSignalingState.RTCSignalingStateHaveLocalOffer;
      call = WebRtcCollabRoomCall(
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
        createConnection: (_) async {
          final sender = _MockSender();
          final transceiver = _MockTransceiver();
          final connection = _MockPeerConnection();
          when(() => transceiver.sender).thenReturn(sender);
          when(
            () => connection.addTrack(any(), any()),
          ).thenAnswer((_) async => sender);
          when(
            () => connection.addTransceiver(
              kind: any(named: 'kind'),
              init: any(named: 'init'),
            ),
          ).thenAnswer((_) async => transceiver);
          when(
            connection.createOffer,
          ).thenAnswer((_) async => RTCSessionDescription('v=0', 'offer'));
          when(
            () => connection.setLocalDescription(any()),
          ).thenAnswer((_) async {});
          when(() => connection.setRemoteDescription(any())).thenAnswer(
            (_) async => signaling = RTCSignalingState.RTCSignalingStateStable,
          );
          when(
            connection.getLocalDescription,
          ).thenAnswer((_) async => RTCSessionDescription('v=0', 'offer'));
          when(() => connection.signalingState).thenAnswer((_) => signaling);
          when(connection.close).thenAnswer((_) async {});
          when(connection.dispose).thenAnswer((_) async {});
          connections.add(connection);
          made.add(connections.length);
          return connection;
        },
      );
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

    group('an offer whose answer never comes', () {
      test('is made again on a new connection', () async {
        await call.start();
        final offers = nextOffer();
        await hello();
        await offers;

        final again = nextOffer();
        await again.timeout(const Duration(seconds: 5));

        expect(connections, hasLength(2));
        verify(connections.first.close).called(1);
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
        verify(() => connections.single.setRemoteDescription(any())).called(1);
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
        verify(connections.single.dispose).called(1);
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
