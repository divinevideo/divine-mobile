import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/notification_content_preloader.dart';

void main() {
  final actor = 'a' * 64;
  final event = 'b' * 64;
  final reference = 'c' * 64;
  group('preload', () {
    test(
      'preloads the authoritative coordinate without walking the source event',
      () async {
        final loaded = <String>[];
        final coordinate = '34236:$actor:video';
        final preloader = NotificationContentPreloader(
          loadVideo: (id) async {
            loaded.add(id);
            return null;
          },
          resolveVideoTarget: (_) async => throw StateError('must not walk'),
          cacheThumbnail: (_) async {},
        );
        await preloader.preload({
          'type': 'like',
          'referencedAddress': coordinate,
          'referencedEventId': reference,
          'eventId': event,
        });
        expect(loaded, [coordinate]);
      },
    );
    test('resolves referenced comment to its root before warming', () async {
      final resolved = <String>[];
      final loaded = <String>[];
      final preloader = NotificationContentPreloader(
        loadVideo: (id) async {
          loaded.add(id);
          return null;
        },
        resolveVideoTarget: (id) async {
          resolved.add(id);
          return event;
        },
        cacheThumbnail: (_) async {},
      );
      await preloader.preload({
        'type': 'comment',
        'referencedEventId': reference,
        'eventId': event,
      });
      expect(resolved, [reference]);
      expect(loaded, [event]);
    });
    test('does not fetch private, campaign, or malformed payloads', () async {
      var loads = 0;
      final preloader = NotificationContentPreloader(
        loadVideo: (_) async {
          loads++;
          return null;
        },
        cacheThumbnail: (_) async {
          loads++;
        },
      );
      for (final type in ['directMessage', 'campaign', 'unknown']) {
        await preloader.preload({'type': type, 'eventId': event});
      }
      await preloader.preload({});
      expect(loads, 0);
    });
    test('deduplicates in-flight targets and bounds concurrent work', () async {
      final pending = Completer<void>();
      var calls = 0;
      final preloader = NotificationContentPreloader(
        loadVideo: (_) async {
          calls++;
          await pending.future;
          return null;
        },
        cacheThumbnail: (_) async {},
      );
      final first = preloader.preload({'type': 'like', 'eventId': event});
      await preloader.preload({'type': 'like', 'eventId': event});
      final second = preloader.preload({'type': 'like', 'eventId': reference});
      await preloader.preload({'type': 'like', 'eventId': actor});
      expect(calls, 2);
      pending.complete();
      await Future.wait([first, second]);
    });
    test(
      'warms the shared thumbnail cache even when the profile lookup fails',
      () async {
        final thumbnails = <String>[];
        final video = VideoEvent(
          id: event,
          pubkey: actor,
          createdAt: 1,
          content: '',
          timestamp: DateTime.utc(2026),
          thumbnailUrl: 'https://example.com/thumbnail.jpg',
        );
        final preloader = NotificationContentPreloader(
          loadVideo: (_) async => video,
          loadProfile: (_) async => throw StateError('profile unavailable'),
          cacheThumbnail: (url) async {
            thumbnails.add(url);
          },
        );
        await preloader.preload({
          'type': 'like',
          'eventId': event,
          'senderPubkey': actor,
        });
        expect(thumbnails, ['https://example.com/thumbnail.jpg']);
      },
    );

    test('a failed warmup never escapes to notification display', () async {
      final preloader = NotificationContentPreloader(
        loadVideo: (_) async => throw StateError('offline'),
        cacheThumbnail: (_) async {},
      );
      await expectLater(
        preloader.preload({'type': 'like', 'eventId': event}),
        completes,
      );
    });

    test('does no work after dispose', () async {
      final requested = <String>[];
      final preloader = NotificationContentPreloader(
        loadVideo: (id) async {
          requested.add(id);
          return null;
        },
        loadProfile: (pubkey) async {
          requested.add(pubkey);
        },
        cacheThumbnail: (_) async {},
      );
      await preloader.preload({'type': 'like', 'eventId': event});
      expect(requested, [event]);

      preloader.dispose();
      await preloader.preload({
        'type': 'like',
        'eventId': reference,
        'senderPubkey': actor,
      });

      expect(requested, [event]);
    });
  });
}
