// ABOUTME: Owns the app-wide first-frame performance subscription.
// ABOUTME: Cancels telemetry observation when its provider container is disposed.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:openvine/observability/feed_playback_performance.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/startup_performance_provider.dart';

final feedPlaybackPerformanceProvider = Provider<void>((ref) {
  final observer = FeedPlaybackPerformance(
    FeedFirstFrameMetrics.events,
    ref.watch(performanceMonitoringServiceProvider),
    ref.watch(startupPerformanceServiceProvider),
  );
  ref.onDispose(() => unawaited(observer.dispose()));
});
