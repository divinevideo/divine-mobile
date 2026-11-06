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
  var delivery = ref.keepAlive();
  var observing = true;
  var b2OptIn = true;
  var validDependencies = true;
  late final PlaybackTelemetryQueue queue;
  queue = PlaybackTelemetryQueue(
    onIdle: () {
      if (observing) return;
      delivery.close();
      // A paused non-weak subscription can prevent automatic disposal even
      // after keepAlive closes. Invalidate the idle owner explicitly; a later
      // feed resume builds a fresh owner instead of retaining idle resources.
      scheduleMicrotask(() {
        if (ref.mounted && !observing && queue.isIdle) ref.invalidateSelf();
      });
    },
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
    initializedConsent:
        validDependencies && analytics.initializedAnalyticsConsent,
    b2OptIn: b2OptIn,
    reset: reset,
  );
  configure();
  // Keep only bounded delivery alive after the final feed leaves. Riverpod
  // pauses Ref listeners even with keepAlive, so privacy listeners below are
  // container-owned and explicitly closed with this delivery owner.
  ref.onCancel(() {
    observing = false;
    queue.setCollecting(false);
  });
  ref.onResume(() {
    observing = true;
    queue.setCollecting(true);
    // Riverpod disallows keepAlive inside lifecycle callbacks themselves.
    scheduleMicrotask(() {
      if (!ref.mounted) return;
      final previous = delivery;
      delivery = ref.keepAlive();
      previous.close();
      if (!observing && queue.isIdle) delivery.close();
    });
  });
  final subscription = analytics.privacyChanges.listen(
    (_) => configure(reset: true),
  );
  final cohort = ref.container.listen(
    isFeatureEnabledProvider(FeatureFlag.b2PlaybackCanary),
    (_, enabled) {
      b2OptIn = enabled;
      configure(reset: true);
    },
  );
  final environmentBoundary = ref.container.listen(
    currentEnvironmentProvider,
    (_, _) {
      validDependencies = false;
      configure(reset: true);
    },
  );
  final analyticsBoundary = ref.container.listen(
    analyticsServiceProvider,
    (_, _) {
      validDependencies = false;
      configure(reset: true);
    },
  );
  ref.onDispose(() {
    cohort.close();
    environmentBoundary.close();
    analyticsBoundary.close();
    unawaited(subscription.cancel());
    unawaited(queue.dispose());
  });
});
