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

final playbackTelemetryProvider = Provider<void>((ref) {
  final analytics = ref.watch(analyticsServiceProvider);
  final httpClient = ref.watch(instrumentedHttpClientFactoryProvider)();
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
  void configure({bool reset = false}) => queue.configure(
    initializedConsent: analytics.initializedAnalyticsConsent,
    b2OptIn: ref.read(isFeatureEnabledProvider(FeatureFlag.b2PlaybackCanary)),
    reset: reset,
  );
  configure();
  final subscription = analytics.privacyChanges.listen(
    (_) => configure(reset: true),
  );
  ref.listen(isFeatureEnabledProvider(FeatureFlag.b2PlaybackCanary), (_, _) {
    configure(reset: true);
  });
  ref.onDispose(() {
    unawaited(subscription.cancel());
    unawaited(queue.dispose());
    httpClient.close();
  });
});
