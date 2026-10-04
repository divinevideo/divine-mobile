// ABOUTME: Regression test for the #5953 PR review — deadMediaFeedGuardProvider
// ABOUTME: must mark the same BrokenVideoTracker instance videoEventServiceProvider
// ABOUTME: attaches to VideoEventService.filterVideoList, not a re-created one.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/dead_media_feed_guard.dart';
import 'package:openvine/services/media_availability_checker.dart';
import 'package:openvine/services/video_moderation_status_service.dart';

import '../helpers/test_helpers.dart';
import '../helpers/test_provider_overrides.dart';

/// Always reports the checked URL as a confirmed 404 with no network I/O, so
/// the guard-mark regression below can exercise the real
/// [DeadMediaFeedGuard.confirmAndMarkMissing] path deterministically.
class _AlwaysConfirmedMissingChecker implements MediaAvailabilityChecker {
  const _AlwaysConfirmedMissingChecker();

  @override
  Future<bool> isConfirmedMissing(String url) async => true;
}

class _AlwaysBlockedModerationStatusService
    extends VideoModerationStatusService {
  _AlwaysBlockedModerationStatusService();

  @override
  Future<VideoModerationStatus?> fetchStatus(String sha256) async =>
      const VideoModerationStatus(
        moderated: true,
        blocked: true,
        quarantined: false,
        ageRestricted: false,
        needsReview: false,
        aiGenerated: false,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('brokenVideoTrackerProvider identity (#5953 review)', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: getStandardTestOverrides().cast(),
      );
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'brokenVideoTrackerProvider returns the same instance on every read',
      () async {
        // videoEventServiceProvider builds first and captures whatever
        // instance brokenVideoTrackerProvider hands back at that moment —
        // exactly like production startup order.
        container.read(videoEventServiceProvider);

        final first = await container.read(brokenVideoTrackerProvider.future);
        final second = await container.read(brokenVideoTrackerProvider.future);

        expect(
          identical(first, second),
          isTrue,
          reason:
              'brokenVideoTrackerProvider must be keepAlive. Without it, the '
              "provider can autodispose once videoEventServiceProvider's "
              'one-off ref.read completes, so a later read (e.g. from '
              'deadMediaFeedGuardProvider) rebuilds a fresh tracker instance '
              'that VideoEventService never attached.',
        );
      },
    );

    test('a mark made through deadMediaFeedGuardProvider.confirmAndMarkMissing '
        'is reflected by VideoEventService.filterVideoList', () async {
      // Rebuild the container with deadMediaFeedGuardProvider overridden to
      // swap in a checker that deterministically reports a confirmed 404 —
      // everything else about the provider's body (resolving the tracker
      // via brokenVideoTrackerProvider) matches production exactly, so this
      // still exercises the real provider identifier and the real
      // confirmAndMarkMissing mark path, just without a live HEAD request.
      container.dispose();
      container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides().cast(),
          deadMediaFeedGuardProvider.overrideWith((ref) async {
            final tracker = await ref.watch(brokenVideoTrackerProvider.future);
            return DeadMediaFeedGuard(
              brokenVideoTracker: tracker,
              moderationStatusService: _AlwaysBlockedModerationStatusService(),
              availabilityChecker: const _AlwaysConfirmedMissingChecker(),
            );
          }),
        ],
      );

      // Build VideoEventService first (production attaches its tracker via
      // a fire-and-forget ref.read inside the provider's build function).
      final service = container.read(videoEventServiceProvider);

      // Let the fire-and-forget setBrokenVideoTracker(...) attach.
      await container.read(brokenVideoTrackerProvider.future);
      await pumpEventQueue();

      // media.divine.video so the videos survive the default
      // divine-hosted-only preference and only the tracker mark decides
      // whether they're filtered — matching the real #5953 scenario of a
      // missing media.divine.video blob.
      final good = TestHelpers.createVideoEvent(
        id: 'good1',
        videoUrl: 'https://media.divine.video/good1hash',
      );
      final dead = TestHelpers.createVideoEvent(
        id: 'dead1',
        videoUrl: 'https://media.divine.video/dead1hash',
      );

      expect(
        service.filterVideoList([good, dead]).map((v) => v.id),
        containsAll(<String>['good1', 'dead1']),
      );

      final guard = await container.read(deadMediaFeedGuardProvider.future);
      final marked = await guard.confirmAndMarkMissing(
        videoId: 'dead1',
        videoUrl: dead.videoUrl,
        explicitSha256: 'a' * 64,
      );
      expect(marked, isTrue);

      expect(
        service.filterVideoList([good, dead]).map((v) => v.id),
        equals(['good1']),
        reason:
            'VideoEventService must filter against the exact tracker '
            'instance the home-feed guard marks — a stale/duplicate '
            'tracker (the pre-fix autoDispose bug) would leave the dead '
            'item visible in the home scrolling feed.',
      );
    });
  });
}
