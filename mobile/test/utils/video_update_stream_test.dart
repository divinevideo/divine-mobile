// ABOUTME: Pins the stream form of VideoEventService's update callbacks: it
// ABOUTME: listens only while subscribed and forwards every republished video.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/video_update_stream.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

VideoEvent _video(String id) => VideoEvent(
  id: id,
  pubkey: 'a' * 64,
  createdAt: 1700000000,
  content: '',
  timestamp: DateTime.utc(2026),
);

void main() {
  group(videoUpdatesOf, () {
    late _MockVideoEventService service;
    late List<void Function(VideoEvent)> callbacks;
    late int unregistered;

    setUp(() {
      service = _MockVideoEventService();
      callbacks = [];
      unregistered = 0;
      when(() => service.addVideoUpdateListener(any())).thenAnswer((call) {
        final callback =
            call.positionalArguments.single as void Function(VideoEvent);
        callbacks.add(callback);
        void unregister() {
          unregistered++;
          callbacks.remove(callback);
        }

        return unregister;
      });
    });

    test('registers no callback until something listens', () {
      videoUpdatesOf(service);

      expect(callbacks, isEmpty);
    });

    test('forwards every video the service reports updated', () async {
      final received = <String>[];
      final subscription = videoUpdatesOf(
        service,
      ).listen((video) => received.add(video.id));

      callbacks.single(_video('one'));
      callbacks.single(_video('two'));
      await pumpEventQueue();

      expect(received, ['one', 'two']);
      await subscription.cancel();
    });

    test('unregisters once the last listener cancels', () async {
      final updates = videoUpdatesOf(service);
      final first = updates.listen((_) {});
      final second = updates.listen((_) {});

      await first.cancel();
      expect(unregistered, 0);
      await second.cancel();

      expect(unregistered, 1);
      expect(callbacks, isEmpty);
    });
  });
}
