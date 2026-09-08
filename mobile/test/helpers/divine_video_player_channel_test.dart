// ABOUTME: Verifies paired native video player mocks cannot leak across tests.
// ABOUTME: Covers both method and event channel teardown in the shared helper.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'divine_video_player_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('divine_video_player/player_7');
  const eventChannel = EventChannel('divine_video_player/player_7/events');

  group('installMockDivineVideoPlayer', () {
    test('installs the method and event handlers together', () {
      installMockDivineVideoPlayer(playerId: 7);

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      expect(
        messenger.checkMockMessageHandler(methodChannel.name, null),
        isFalse,
      );
      expect(
        messenger.checkMockMessageHandler(eventChannel.name, null),
        isFalse,
      );
    });

    test('clears both handlers after the prior test', () {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      expect(
        messenger.checkMockMessageHandler(methodChannel.name, null),
        isTrue,
      );
      expect(
        messenger.checkMockMessageHandler(eventChannel.name, null),
        isTrue,
      );
    });
  });
}
