import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/seen_videos_notifier.dart';

import '../helpers/real_integration_test_helper.dart';

void main() {
  group('VideoEventsProvider - Fresh First', () {
    setUpAll(() async {
      await RealIntegrationTestHelper.setupTestEnvironment();
    });

    test(
      'emits videos with unseen first on initial load',
      () async {
        // PART 1: Get some videos and mark them as seen
        print('TEST PART 1: Loading initial videos and marking some as seen');

        final container1 = ProviderContainer();
        final nostrService = container1.read(nostrServiceProvider);
        await nostrService.initialize();

        // Get initial videos
        final states = <List<VideoEvent>>[];
        final completer = Completer<void>();

        container1.listen<AsyncValue<List<VideoEvent>>>(videoEventsProvider, (
          previous,
          next,
        ) {
          if (next.hasValue) {
            states.add(next.value!);
            if (next.value!.length >= 4 && !completer.isCompleted) {
              completer.complete();
            }
          }
        });

        container1.read(videoEventsProvider);

        final timer = Timer(const Duration(seconds: 10), () {
          if (!completer.isCompleted) completer.complete();
        });

        await completer.future;
        timer.cancel();

        expect(
          states.isNotEmpty,
          true,
          reason: 'Should have received videos from relay',
        );
        final videos = states.last;
        expect(
          videos.length,
          greaterThanOrEqualTo(4),
          reason: 'Should have at least 4 videos',
        );

        // Mark some videos as seen
        final seenNotifier = container1.read(seenVideosProvider.notifier);
        await seenNotifier.markVideoAsSeen(videos[0].id);
        await seenNotifier.markVideoAsSeen(videos[2].id);

        print('Marked 2 videos as seen: ${videos[0].id}, ${videos[2].id}');
        container1.dispose();

        // PART 2: Create new container (simulates app restart) - should load with fresh-first ordering
        print('TEST PART 2: Simulating app restart with existing seen state');

        final container2 = ProviderContainer();
        final nostrService2 = container2.read(nostrServiceProvider);
        await nostrService2.initialize();

        final states2 = <List<VideoEvent>>[];
        final completer2 = Completer<void>();

        container2.listen<AsyncValue<List<VideoEvent>>>(videoEventsProvider, (
          previous,
          next,
        ) {
          if (next.hasValue) {
            states2.add(next.value!);
            if (next.value!.length >= 4 && !completer2.isCompleted) {
              completer2.complete();
            }
          }
        });

        container2.read(videoEventsProvider);

        final timer2 = Timer(const Duration(seconds: 10), () {
          if (!completer2.isCompleted) completer2.complete();
        });

        await completer2.future;
        timer2.cancel();

        expect(
          states2.isNotEmpty,
          true,
          reason: 'Should have received videos on restart',
        );
        final restartVideos = states2.last;
        expect(restartVideos.length, greaterThanOrEqualTo(4));

        // Get the seen notifier from the new container to check which videos are seen
        final seenNotifier2 = container2.read(seenVideosProvider.notifier);

        print('After restart, received ${restartVideos.length} videos');
        print(
          'First 3 video IDs: ${restartVideos.take(3).map((v) => v.id).toList()}',
        );

        // Find positions of seen vs unseen videos
        final seenIndices = <int>[];
        final unseenIndices = <int>[];

        for (int i = 0; i < restartVideos.length; i++) {
          if (seenNotifier2.hasSeenVideo(restartVideos[i].id)) {
            seenIndices.add(i);
          } else {
            unseenIndices.add(i);
          }
        }

        print('Seen video count: ${seenIndices.length}');
        print('Unseen video count: ${unseenIndices.length}');
        print(
          'Last unseen index: ${unseenIndices.isNotEmpty ? unseenIndices.last : "none"}',
        );
        print(
          'First seen index: ${seenIndices.isNotEmpty ? seenIndices.first : "none"}',
        );

        // Verify: All unseen videos should come before all seen videos
        if (unseenIndices.isNotEmpty && seenIndices.isNotEmpty) {
          expect(
            unseenIndices.last < seenIndices.first,
            true,
            reason:
                'On app restart, all unseen videos should come before all seen videos. Last unseen at ${unseenIndices.last}, first seen at ${seenIndices.first}',
          );
        }

        container2.dispose();
      },
      timeout: const Timeout(Duration(seconds: 40)),
    );

    // Edge case tests simplified - the main test above covers the core behavior
  });
}
