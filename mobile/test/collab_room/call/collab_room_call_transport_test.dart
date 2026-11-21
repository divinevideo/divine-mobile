// ABOUTME: Tests for the relay transport of a room call's sealed messages

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/collab_room/call/collab_room_call_signal.dart';
import 'package:openvine/collab_room/call/collab_room_call_transport.dart';

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  group(NostrCollabRoomCallTransport, () {
    late _MockNostrClient client;
    final event = Event('a' * 64, collabRoomCallSignalKind, const [], 'sealed');

    setUpAll(() => registerFallbackValue(event));

    setUp(() => client = _MockNostrClient());

    group('publish', () {
      test('completes once a relay took the message', () async {
        when(
          () => client.publishEvent(any()),
        ).thenAnswer((_) async => PublishSuccess(event: event));

        await expectLater(
          NostrCollabRoomCallTransport(client).publish(event),
          completes,
        );
      });

      // A relay turning a message down is the network, not a defect: a bare
      // StateError would have been sent to the crash reporter.
      test('reports a message no relay took as a call exception', () async {
        when(
          () => client.publishEvent(any()),
        ).thenAnswer((_) async => const PublishNoRelays());

        await expectLater(
          NostrCollabRoomCallTransport(client).publish(event),
          throwsA(isA<CollabRoomCallException>()),
        );
      });
    });
  });
}
