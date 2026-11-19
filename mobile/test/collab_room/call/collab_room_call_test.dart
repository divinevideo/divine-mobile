// ABOUTME: Tests for the WebRTC room call's handling of what the device
// ABOUTME: refuses, which flutter_webrtc reports as plain strings

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/collab_room/call/collab_room_call.dart';
import 'package:openvine/collab_room/call/collab_room_call_transport.dart';

const _author =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _sam = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

class _SilentTransport implements CollabRoomCallTransport {
  @override
  Stream<Event> watch(String author, {required int since}) =>
      const Stream.empty();

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
