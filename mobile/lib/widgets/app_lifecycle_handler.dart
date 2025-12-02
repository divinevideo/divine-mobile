// ABOUTME: App lifecycle handler that pauses all videos when app goes to background
// ABOUTME: Ensures videos never play when app is not visible and manages background battery usage

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/log_message_batcher.dart';

/// Handles app lifecycle events for video playback
class AppLifecycleHandler extends ConsumerStatefulWidget {
  const AppLifecycleHandler({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<AppLifecycleHandler> createState() =>
      _AppLifecycleHandlerState();
}

class _AppLifecycleHandlerState extends ConsumerState<AppLifecycleHandler>
    with WidgetsBindingObserver {
  late final BackgroundActivityManager _backgroundManager;
  bool _tickersEnabled = true;

  @override
  void initState() {
    super.initState();
    _backgroundManager = BackgroundActivityManager();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Dispose log message batcher and flush any remaining messages
    LogMessageBatcher.instance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final visibilityManager = ref.read(videoVisibilityManagerProvider);

    // Notify background activity manager first
    _backgroundManager.onAppLifecycleStateChanged(state);

    switch (state) {
      case AppLifecycleState.resumed:
        Log.info(
          '📱 App resumed from background - restoring activities',
          name: 'AppLifecycleHandler',
          category: LogCategory.system,
        );

        // Notify foreground state provider - enables visibility detection
        ref.read(appForegroundProvider.notifier).setForeground(true);

        if (!_tickersEnabled) {
          setState(() => _tickersEnabled = true);
        }
        // Don't force resume playback - let visibility detectors naturally trigger
        // This prevents playing videos that are covered by modals/camera screen
        Log.info(
          '📱 App resumed - visibility detectors will handle playback naturally',
          name: 'AppLifecycleHandler',
          category: LogCategory.system,
        );

      case AppLifecycleState.inactive:
        // On desktop, inactive happens during normal UI operations (clicking, menu interactions, etc.)
        // Don't treat this as backgrounded - videos should continue playing
        Log.debug(
          '📱 App became inactive (normal on desktop) - keeping videos active',
          name: 'AppLifecycleHandler',
          category: LogCategory.system,
        );

      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        Log.info(
          '📱 App backgrounded - clearing active video and pausing all videos',
          name: 'AppLifecycleHandler',
          category: LogCategory.system,
        );

        // CRITICAL: Notify foreground state provider FIRST - disables visibility detection
        // This prevents VisibilityDetector callbacks from reactivating videos
        ref.read(appForegroundProvider.notifier).setForeground(false);

        if (_tickersEnabled) {
          setState(() => _tickersEnabled = false);
        }

        // Active video pause is now handled by derived provider:
        // appForegroundProvider=false → activeVideoIdProvider returns null → VideoFeedItem pauses

        // Pause all videos and clear visibility state
        // Execute async to prevent blocking scene update
        Future.microtask(() => visibilityManager.pauseAllVideos());

      case AppLifecycleState.detached:
        // App is being terminated
        break;
    }
  }

  @override
  Widget build(BuildContext context) =>
      TickerMode(enabled: _tickersEnabled, child: widget.child);
}
