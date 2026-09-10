// ABOUTME: Installs paired method and event mocks for a native video player.
// ABOUTME: Keeps per-player channel setup and teardown atomic across tests.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Installs the method and event channels for one mocked native video player.
///
/// Both handlers are cleared automatically when the current test scope ends.
void installMockDivineVideoPlayer({
  int playerId = 0,
  Future<Object?> Function(MethodCall call)? onMethodCall,
  MockStreamHandler? streamHandler,
}) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final methodChannel = MethodChannel(
    'divine_video_player/player_$playerId',
  );
  final eventChannel = EventChannel(
    'divine_video_player/player_$playerId/events',
  );

  messenger
    ..setMockMethodCallHandler(
      methodChannel,
      onMethodCall ?? (_) async => null,
    )
    ..setMockStreamHandler(
      eventChannel,
      streamHandler ?? EmptyPlayerStreamHandler(),
    );

  addTearDown(() {
    messenger
      ..setMockMethodCallHandler(methodChannel, null)
      ..setMockStreamHandler(eventChannel, null);
  });
}

/// An event handler for player tests that do not need native state updates.
class EmptyPlayerStreamHandler extends MockStreamHandler {
  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {}

  @override
  void onCancel(Object? arguments) {}
}
