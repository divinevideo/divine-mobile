// ABOUTME: Enables playback diagnostics only after consent and device opt-in.
// ABOUTME: Drops all queued correlation on consent, account and cohort changes.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/observability/playback_telemetry_queue.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/services/analytics_ingest_client.dart';

final Provider<void> playbackTelemetryProvider = Provider.autoDispose<void>((
  ref,
) {
  // Mounted feeds already resolve this flag. Off-cohort playback must not
  // construct analytics, signing or network dependencies just to observe it.
  if (!ref.watch(isFeatureEnabledProvider(FeatureFlag.b2PlaybackCanary))) {
    return;
  }
  final analytics = ref.watch(analyticsServiceProvider);
  final httpClient = ref.watch(instrumentedHttpClientFactoryProvider)();
  ref.onDispose(httpClient.close);
  final environment = ref.watch(currentEnvironmentProvider);
  final queue = PlaybackTelemetryQueue(
    client: AnalyticsIngestClient(
      httpClient: httpClient,
      nip98AuthService: ref.watch(nip98AuthServiceProvider),
      apiBaseUrl: () => environment.apiBaseUrl,
      timeout: const Duration(seconds: 5),
    ),
    platform: kIsWeb
        ? 'web'
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => 'android',
            TargetPlatform.iOS => 'ios',
            TargetPlatform.macOS => 'macos',
            TargetPlatform.windows => 'windows',
            TargetPlatform.linux => 'linux',
            _ => 'unknown',
          },
  );
  var observing = true;
  void configure({bool reset = false}) => queue.configure(
    initializedConsent: observing && analytics.initializedAnalyticsConsent,
    b2OptIn: ref.read(isFeatureEnabledProvider(FeatureFlag.b2PlaybackCanary)),
    reset: reset,
  );
  configure();
  // Offstage consumers can be paused without disposing their providers.
  // Stop delivery immediately so paused flag listeners cannot retain consent.
  ref.onCancel(() {
    observing = false;
    queue.configure(initializedConsent: false, b2OptIn: false, reset: true);
  });
  ref.onResume(() {
    observing = true;
    scheduleMicrotask(() {
      if (ref.mounted && observing) configure(reset: true);
    });
  });
  final subscription = analytics.privacyChanges.listen(
    (_) => configure(reset: true),
  );
  ref.listen(isFeatureEnabledProvider(FeatureFlag.b2PlaybackCanary), (_, _) {
    configure(reset: true);
  });
  ref.onDispose(() {
    unawaited(subscription.cancel());
    unawaited(queue.dispose());
  });
});
