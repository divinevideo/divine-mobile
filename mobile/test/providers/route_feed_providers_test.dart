// ABOUTME: Verifies Explore's open feed follows republished video revisions.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

VideoEvent _revision(String id, {required int kind, required int createdAt}) =>
    VideoEvent(
      id: id * 64,
      pubkey: 'a' * 64,
      createdAt: createdAt,
      eventCreatedAt: createdAt,
      timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
      content: '',
      vineId: 'shared-clip',
      addressableDTag: 'shared-clip',
      eventKind: kind,
    );

void main() {
  group(exploreTabVideoUpdateListenerProvider, () {
    late ProviderContainer container;
    late void Function(VideoEvent) reportUpdate;

    setUpAll(() {
      registerFallbackValue((VideoEvent _) {});
    });

    setUp(() {
      final service = _MockVideoEventService();
      when(() => service.addVideoUpdateListener(any())).thenAnswer((call) {
        reportUpdate =
            call.positionalArguments.single as void Function(VideoEvent);
        return () {};
      });
      container = ProviderContainer.test(
        overrides: [videoEventServiceProvider.overrideWith((_) => service)],
      );
      container.read(exploreTabVideoUpdateListenerProvider);
    });

    test('replaces only the edited kind at a shared d tag', () {
      final short = _revision('b', kind: 34236, createdAt: 1000);
      final normal = _revision(
        'c',
        kind: 34235,
        createdAt: 1000,
      ).copyWith(nostrLikeCount: 7);
      final edited = _revision('d', kind: 34235, createdAt: 2000);
      container.read(exploreTabVideosProvider.notifier).state = [short, normal];

      reportUpdate(edited);

      final videos = container.read(exploreTabVideosProvider)!;
      expect(videos.map((video) => video.id), [short.id, edited.id]);
      expect(videos.last.nostrLikeCount, 7);
    });

    test(
      'keeps a republished revision when a later callback loses the tie',
      () {
        final opened = _revision('b', kind: 34236, createdAt: 1000);
        final winner = _revision('c', kind: 34236, createdAt: 2000);
        final loser = _revision('d', kind: 34236, createdAt: 2000);
        container.read(exploreTabVideosProvider.notifier).state = [opened];

        reportUpdate(winner);
        reportUpdate(loser);

        expect(container.read(exploreTabVideosProvider), [winner]);
      },
    );
  });
}
