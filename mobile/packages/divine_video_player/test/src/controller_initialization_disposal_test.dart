import 'dart:async';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('controller initialization lifecycle', () {
    late DivineVideoPlayerController controller;
    late Completer<Object?> creation;
    late Completer<void> createStarted;
    late List<MethodCall> calls;
    late List<MethodCall> eventCalls;
    const channel = MethodChannel('divine_video_player');
    const events = MethodChannel('divine_video_player/player_0/events');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() {
      DivineVideoPlayerController.resetIdCounterForTesting();
      DivineVideoPlayerController.debugForceWebBackend = false;
      DivineVideoPlayerController.debugForceLinuxBackend = false;
      controller = DivineVideoPlayerController(useTexture: true);
      creation = Completer<Object?>();
      createStarted = Completer<void>();
      calls = [];
      eventCalls = [];
      messenger
        ..setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'create') {
            createStarted.complete();
            return creation.future;
          }
          return null;
        })
        ..setMockMethodCallHandler(events, (call) async {
          eventCalls.add(call);
          return null;
        });
    });

    tearDown(() async {
      await controller.dispose();
      messenger
        ..setMockMethodCallHandler(channel, null)
        ..setMockMethodCallHandler(events, null);
      DivineVideoPlayerController.debugForceWebBackend = null;
      DivineVideoPlayerController.debugForceLinuxBackend = null;
    });

    test(
      'disposal during create releases the late player exactly once',
      () async {
        final initialization = controller.initialize();
        await createStarted.future;
        await controller.dispose();
        await controller.dispose();
        expect(calls.map((call) => call.method), ['create']);

        creation.complete({'textureId': 42});
        await initialization;
        await controller.dispose();

        expect(calls.map((call) => call.method), ['create', 'dispose']);
        expect(calls.last.arguments, {'id': 0});
        expect(eventCalls, isEmpty);
        expect(controller.textureId, isNull);
        expect(controller.isInitialized, isFalse);
        expect(DivineVideoPlayerController.liveControllerCount, 0);
      },
    );

    test(
      'normal disposal cancels events before releasing the player',
      () async {
        final initialization = controller.initialize();
        await createStarted.future;
        creation.complete({'textureId': 42});
        await initialization;
        expect(controller.textureId, 42);
        expect(DivineVideoPlayerController.liveControllerCount, 1);
        await controller.dispose();
        await controller.dispose();
        expect(eventCalls.map((call) => call.method), ['listen', 'cancel']);
        expect(calls.map((call) => call.method), ['create', 'dispose']);
        expect(DivineVideoPlayerController.liveControllerCount, 0);
      },
    );

    test('initialization after disposal creates no player', () async {
      await controller.dispose();
      creation.complete(null);
      await expectLater(controller.initialize(), throwsStateError);
      expect(calls, isEmpty);
    });

    test('concurrent initialization creates only one player', () async {
      final initialization = controller.initialize();
      await createStarted.future;
      await expectLater(controller.initialize(), throwsStateError);
      creation.complete(null);
      await initialization;
      expect(calls.where((call) => call.method == 'create'), hasLength(1));
    });
  });
}
