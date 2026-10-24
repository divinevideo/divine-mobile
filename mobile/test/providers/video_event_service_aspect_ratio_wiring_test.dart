// ABOUTME: Regression test for the #6714 PR review — videoEventServiceProvider
// ABOUTME: must attach the same FeedAspectRatioPreferenceService instance the
// ABOUTME: settings toggle mutates, so a live flip re-filters list surfaces.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/preferences_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/feed_aspect_ratio_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';
import '../helpers/test_provider_overrides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('videoEventServiceProvider aspect-ratio wiring (#6714 review)', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: getStandardTestOverrides(mockSharedPreferences: prefs)
            .cast(),
      );
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'a preference flip made through feedAspectRatioPreferenceServiceProvider '
      'is reflected by VideoEventService.filterVideoList',
      () async {
        final service = container.read(videoEventServiceProvider);
        final preference = container.read(
          feedAspectRatioPreferenceServiceProvider,
        );

        // media.divine.video so both survive the default
        // Divine-hosted-only preference and only the shape filter decides.
        final square = TestHelpers.createVideoEvent(
          id: 'square1',
          videoUrl: 'https://media.divine.video/square1hash',
          dimensions: '640x640',
        );
        final portrait = TestHelpers.createVideoEvent(
          id: 'portrait1',
          videoUrl: 'https://media.divine.video/portrait1hash',
          dimensions: '720x1280',
        );

        expect(
          service.filterVideoList([square, portrait]).map((v) => v.id),
          containsAll(<String>['square1', 'portrait1']),
        );

        await preference.setPreference(FeedAspectRatioPreference.squareOnly);

        expect(
          service.filterVideoList([square, portrait]).map((v) => v.id),
          equals(['square1']),
          reason:
              'VideoEventService must filter against the exact preference '
              'instance the settings toggle mutates. Dropping the '
              'setFeedAspectRatioPreferenceService(...) call in '
              'videoEventServiceProvider leaves this list unfiltered.',
        );
      },
    );
  });
}
