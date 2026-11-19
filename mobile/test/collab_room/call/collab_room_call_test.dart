// ABOUTME: Tests for the WebRTC room call's handling of what the device
// ABOUTME: refuses, which flutter_webrtc reports as plain strings

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/client_utils/keys.dart' as keys;
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/collab_room/call/collab_room_call.dart';
import 'package:openvine/collab_room/call/collab_room_call_transport.dart';

const _author =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _sam = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

/// Takes every message until [refuse] is set, then turns them all down.
class _RefusingTransport implements CollabRoomCallTransport {
  bool refuse = false;

  @override
  Stream<Event> watch(String author, {required int since}) =>
      const Stream.empty();

  @override
  Future<void> publish(Event event) async {
    if (refuse) {
      throw const CollabRoomCallException('No relay accepted the call signal');
    }
  }
}

class _SilentTransport implements CollabRoomCallTransport {
  @override
  Stream<Event> watch(String author, {required int since}) {
    watched = true;
    return const Stream.empty();
  }

  bool watched = false;

  @override
  Future<void> publish(Event event) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(WebRtcCollabRoomCall, () {
    const channel = MethodChannel('FlutterWebRTC.Method');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('releases the microphone granted after the call ended', () async {
      final requested = Completer<void>();
      final response = Completer<Map<String, Object>>();
      final released = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'getUserMedia':
            requested.complete();
            return response.future;
          case 'trackDispose':
            released.add(call.arguments['trackId'] as String);
          case 'streamDispose':
            released.add(call.arguments['streamId'] as String);
        }
        return null;
      });
      final transport = _SilentTransport();
      final call = WebRtcCollabRoomCall(
        me: _author,
        others: {_sam},
        callKey: '1' * 64,
        accountSigner: LocalNostrSigner('2' * 64),
        transport: transport,
      );

      final starting = call.start();
      await requested.future;
      final stopping = call.stop();
      response.complete({
        'streamId': 'late-audio',
        'audioTracks': [
          {
            'id': 'microphone',
            'label': 'Microphone',
            'kind': 'audio',
            'enabled': true,
          },
        ],
      });
      await Future.wait([starting, stopping]);

      expect(released, ['microphone', 'late-audio']);
      expect(transport.watched, isFalse);
    });

    test(
      'keeps the camera on when telling the others about it fails',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method != 'getUserMedia') return null;
          final constraints = call.arguments['constraints'] as Map;
          final video = constraints['video'] != false;
          return {
            'streamId': video ? 'camera' : 'microphone',
            if (!video)
              'audioTracks': [
                {
                  'id': 'mic-track',
                  'label': 'Microphone',
                  'kind': 'audio',
                  'enabled': true,
                },
              ],
            if (video)
              'videoTracks': [
                {
                  'id': 'camera-track',
                  'label': 'Camera',
                  'kind': 'video',
                  'enabled': true,
                },
              ],
          };
        });
        final transport = _RefusingTransport();
        // Real keys: the messages are encrypted to the other person.
        final myKey = keys.generatePrivateKey();
        final call = WebRtcCollabRoomCall(
          me: keys.getPublicKey(myKey),
          others: {keys.getPublicKey(keys.generatePrivateKey())},
          callKey: keys.generatePrivateKey(),
          accountSigner: LocalNostrSigner(myKey),
          transport: transport,
        );
        addTearDown(call.stop);
        final changes = <CollabRoomCallSnapshot>[];
        call.changes.listen(changes.add);
        await call.start();
        transport.refuse = true;

        // The camera opened; only the message about it did not go out.
        await expectLater(call.setCameraOn(true), completes);
        await pumpEventQueue();

        expect(changes.last.cameraOn, isTrue);
      },
    );

    test('reports a microphone the device refuses as an exception', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getUserMedia') {
          throw PlatformException(code: 'denied', message: 'no microphone');
        }
        return null;
      });
      final call = WebRtcCollabRoomCall(
        me: _author,
        others: {_sam},
        callKey: '1' * 64,
        accountSigner: LocalNostrSigner('2' * 64),
        transport: _SilentTransport(),
      );

      // flutter_webrtc throws a plain string here, which the call cubit's
      // `on Exception` would let escape uncaught.
      await expectLater(
        call.start(),
        throwsA(
          isA<CollabRoomCallException>().having(
            (error) => error.message,
            'message',
            contains('no microphone'),
          ),
        ),
      );
    });
  });
}
