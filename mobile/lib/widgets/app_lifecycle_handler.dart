// ABOUTME: App lifecycle handler that pauses all videos when app goes to background
// ABOUTME: Ensures videos never play when app is not visible and manages background battery usage

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nostr_client/nostr_client.dart' show ForceReconnectOutcome;
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/notifications/services/notification_refresh_coordinator.dart';
import 'package:openvine/providers/account_enforcement_providers.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/background_activity_provider.dart';
import 'package:openvine/providers/log_message_batcher_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/services/account_state_resume_refresher.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/utils/log_message_batcher.dart';
import 'package:unified_logger/unified_logger.dart';

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
  // Read here rather than in dispose(), where ref is no longer usable.
  late final LogMessageBatcher _logMessageBatcher;
  bool _tickersEnabled = true;

  @override
  void initState() {
    super.initState();
    _backgroundManager = ref.read(backgroundActivityManagerProvider);
    _logMessageBatcher = ref.read(logMessageBatcherProvider);
    WidgetsBinding.instance.addObserver(this);

    // Resume any pending publish drafts after first frame,
    // but only once the user is authenticated.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      unawaited(_clearAppBadge());

      final authService = ref.read(authServiceProvider);
      if (!authService.isAuthenticated) {
        final authState = await authService.authStateStream.firstWhere(
          (state) => state == AuthState.authenticated,
          orElse: () => AuthState.unauthenticated,
        );
        if (!mounted || authState != AuthState.authenticated) return;
      }

      // Defer one more frame so the GoRouter auth-redirect can settle
      // before we surface pending publish failures.
      final settled = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) => settled.complete());
      await settled.future;
      if (!mounted) return;

      ref.read(videoPublishProvider.notifier).resumePendingPublishes(context);
      await ref.read(clipLibraryServiceProvider).migrateOldClips();
      await ref.read(draftStorageServiceProvider).migrateOldDrafts();
      // Hard-delete trashed clips past the 30-day retention window.
      // Best-effort, idempotent; failures here are logged inside the
      // service and must never block app startup.
      try {
        await ref.read(clipLibraryServiceProvider).purgeExpiredTrash();
      } catch (e, st) {
        Log.error(
          'Trash purge sweep failed: $e',
          name: 'AppLifecycleHandler',
          category: LogCategory.video,
          error: e,
          stackTrace: st,
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // This widget is account-scoped while the batcher is device-scoped. Flush
    // pending summaries without cancelling the timer on account swaps.
    _logMessageBatcher.flush();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Notify background activity manager first
    _backgroundManager.onAppLifecycleStateChanged(state);

    if (state != AppLifecycleState.resumed) {
      // Inactive is routine on desktop, but this no-ops unless an editor
      // autosave debounce is pending. Detached may be the only signal before
      // process teardown, so flush before the state-specific work below.
      unawaited(ref.read(videoEditorProvider.notifier).flushPendingAutosave());
    }

    switch (state) {
      case AppLifecycleState.resumed:
        Log.info(
          '📱 App resumed from background - restoring activities',
          name: 'AppLifecycleHandler',
          category: LogCategory.system,
        );

        // Reset performance tracker sessions to prevent stale start
        // times from producing absurd load-time measurements (e.g.
        // 27+ hours) when providers re-fire on resume.
        ref.read(feedPerformanceTrackerProvider).resetAllSessions();
        ref.read(screenAnalyticsServiceProvider).resetAllSessions();
        ref.read(surfacePerformanceTrackerProvider).resetAllSessions();

        // Notify foreground state provider - enables visibility detection
        ref.read(appForegroundProvider.notifier).setForeground(true);
        ref.invalidate(accountEnforcementStatusProvider);

        if (!_tickersEnabled) {
          setState(() => _tickersEnabled = true);
        }

        // Force reconnect relays - WebSocket connections are often silently
        // dropped by iOS/Android when app is backgrounded. Without this,
        // subscriptions sent to stale sockets will timeout (30s) with no response.
        _reconnectRelays();
        unawaited(_clearAppBadge());
        unawaited(
          ref
              .read(notificationRefreshCoordinatorProvider)
              ?.refresh(reason: NotificationRefreshReason.appResume),
        );
        unawaited(context.read<InviteStatusCubit?>()?.load());

        // Refetch protected-minor account state so a server-side flip that
        // landed while idle-authenticated is picked up on resume, rather than
        // waiting for the next relaunch or re-auth. TTL-guarded internally so a
        // frequent backgrounder doesn't hit Keycast on every foreground.
        ref
            .read(accountStateResumeRefresherProvider)
            .refreshOnResume(
              authenticated: ref.read(authServiceProvider).isAuthenticated,
            );

        // Don't force resume playback. Foreground, route, and overlay gates
        // decide which mounted feed may play.
        Log.info(
          '📱 App resumed - foreground playback gates restored',
          name: 'AppLifecycleHandler',
          category: LogCategory.system,
        );

      case AppLifecycleState.inactive:
        if (_inactiveDisablesForegroundPlayback(defaultTargetPlatform)) {
          Log.info(
            '📱 App became inactive - disabling foreground playback gates',
            name: 'AppLifecycleHandler',
            category: LogCategory.system,
          );
          ref.read(appForegroundProvider.notifier).setForeground(false);
          if (_tickersEnabled) {
            setState(() => _tickersEnabled = false);
          }
        } else {
          // Desktop inactive is common during menu/window focus changes.
          Log.debug(
            '📱 App became inactive (desktop focus change) - keeping videos active',
            name: 'AppLifecycleHandler',
            category: LogCategory.system,
          );
        }

      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        Log.info(
          '📱 App backgrounded - disabling foreground playback gates',
          name: 'AppLifecycleHandler',
          category: LogCategory.system,
        );

        // Playback pause is handled by appForegroundProvider=false:
        // - pooled FeedVideos forwards isActive=false to InfiniteVideoFeed
        // - activeVideoIdProvider returns null for legacy video items.
        ref.read(appForegroundProvider.notifier).setForeground(false);

        if (_tickersEnabled) {
          setState(() => _tickersEnabled = false);
        }

      case AppLifecycleState.detached:
        // App is being terminated
        unawaited(VideoEditorRenderService.cancelActiveNativeTasks());
    }
  }

  /// Reconnects relay WebSocket connections after app resume.
  ///
  /// iOS/Android often silently drop WebSocket connections when apps are
  /// backgrounded. The connection status may still show "connected" but
  /// the socket is actually dead. This causes subscriptions to timeout
  /// because messages are sent to a dead socket and never reach the relay.
  Future<void> _reconnectRelays() async {
    try {
      final nostrClient = ref.read(nostrServiceProvider);
      final outcome = await nostrClient.forceReconnectAll();
      final connected =
          '${nostrClient.connectedRelayCount} of '
          '${nostrClient.configuredRelayCount}';
      Log.info(
        switch (outcome) {
          ForceReconnectOutcome.completed =>
            '📱 Relay reconnect after app resume finished: $connected relays '
                'connected',
          ForceReconnectOutcome.stillDialling =>
            '📱 Relay reconnect after app resume ended with relays still '
                'connecting ($connected connected)',
        },
        name: 'AppLifecycleHandler',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.warning(
        '📱 Failed to reconnect relays on resume: $e',
        name: 'AppLifecycleHandler',
        category: LogCategory.system,
      );
    }
  }

  Future<void> _clearAppBadge() async {
    try {
      await ref.read(appBadgeServiceProvider).clear();
    } catch (e, st) {
      Log.warning(
        'App badge clear failed during lifecycle handling: $e\n$st',
        name: 'AppLifecycleHandler',
        category: LogCategory.system,
      );
    }
  }

  @override
  Widget build(BuildContext context) =>
      TickerMode(enabled: _tickersEnabled, child: widget.child);
}

bool _inactiveDisablesForegroundPlayback(TargetPlatform platform) =>
    platform == TargetPlatform.android || platform == TargetPlatform.iOS;
