import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/playback_telemetry_provider.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class _Analytics extends Mock implements AnalyticsService {}

class _Nip98 extends Mock implements Nip98AuthService {}

void main() {
  tearDown(() => FeedPlaybackTelemetry.configure(enabled: false));

  group('playbackTelemetryProvider', () {
    test(
      'off-cohort feeds do not construct analytics or HTTP dependencies',
      () {
        final container = ProviderContainer(
          overrides: [
            isFeatureEnabledProvider(FeatureFlag.b2PlaybackCanary)
                .overrideWithValue(false),
            analyticsServiceProvider.overrideWith(
              (_) => throw StateError('analytics constructed'),
            ),
            instrumentedHttpClientFactoryProvider.overrideWith(
              (_) => throw StateError('HTTP constructed'),
            ),
          ],
        );
        addTearDown(container.dispose);
        expect(
          () => container.read(playbackTelemetryProvider),
          returnsNormally,
        );
        expect(FeedPlaybackTelemetry.startLoad(), isNull);
      },
    );

    test(
      'mounted ownership enforces consent, suspension and last-feed disposal',
      () async {
        final changes = StreamController<void>.broadcast(sync: true);
        addTearDown(changes.close);
        var consent = true;
        final analytics = _Analytics();
        when(() => analytics.initializedAnalyticsConsent)
            .thenAnswer((_) => consent);
        when(() => analytics.privacyChanges).thenAnswer((_) => changes.stream);
        final container = ProviderContainer(
          overrides: [
            isFeatureEnabledProvider(FeatureFlag.b2PlaybackCanary)
                .overrideWithValue(true),
            analyticsServiceProvider.overrideWithValue(analytics),
            nip98AuthServiceProvider.overrideWithValue(_Nip98()),
            instrumentedHttpClientFactoryProvider.overrideWithValue(
              () => MockClient((_) => throw StateError('unexpected request')),
            ),
          ],
        );
        addTearDown(container.dispose);
        final ownership = container.listen(
          playbackTelemetryProvider,
          (_, _) {},
        );
        final beforeWithdrawal = FeedPlaybackTelemetry.startLoad()!;
        consent = false;
        changes.add(null);
        expect(beforeWithdrawal.isCurrent, isFalse);
        expect(FeedPlaybackTelemetry.startLoad(), isNull);
        consent = true;
        changes.add(null);
        final beforeSuspension = FeedPlaybackTelemetry.startLoad()!;
        ownership.pause();
        expect(beforeSuspension.isCurrent, isFalse);
        changes.add(null);
        expect(FeedPlaybackTelemetry.startLoad(), isNull);
        ownership.resume();
        await container.pump();
        final beforeDisposal = FeedPlaybackTelemetry.startLoad()!;
        ownership.close();
        await container.pump();
        expect(beforeDisposal.isCurrent, isFalse);
        expect(FeedPlaybackTelemetry.startLoad(), isNull);
      },
    );
  });
}
