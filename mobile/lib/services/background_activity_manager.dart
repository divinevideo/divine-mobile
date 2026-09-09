// ABOUTME: Manages app background state to prevent network usage and battery drain
// ABOUTME: Suspends non-critical services when app goes to background to conserve resources

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:unified_logger/unified_logger.dart';

/// Background activity manager to control network and battery usage
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class BackgroundActivityManager {
  BackgroundActivityManager();

  bool _isAppInForeground = true;
  final List<BackgroundAwareService> _registeredServices = [];

  // Defensive bound on how long the manager will await a single service's
  // onAppBackgrounded notification before logging and moving on. The
  // [BackgroundAwareService.onAppBackgrounded] interface is currently
  // synchronous `void`, so the timeout does not fire for any in-tree
  // implementation — it exists to protect the immediate-background phase
  // from iOS/Android watchdog kills if the interface is ever widened to
  // `FutureOr<void>` (or an impl starts blocking the microtask chain).
  static const Duration _suspendGracePeriod = Duration(seconds: 1);

  // Timer for delayed actions
  Timer? _backgroundSuspensionTimer;

  /// Current app foreground state
  bool get isAppInForeground => _isAppInForeground;
  bool get isAppInBackground => !_isAppInForeground;

  /// Register a service for background state management
  void registerService(BackgroundAwareService service) {
    if (!_registeredServices.contains(service)) {
      _registeredServices.add(service);
      Log.debug(
        'Registered background-aware service: ${service.serviceName}',
        name: 'BackgroundActivityManager',
        category: LogCategory.system,
      );
    }
  }

  /// Unregister a service
  void unregisterService(BackgroundAwareService service) {
    _registeredServices.remove(service);
    Log.debug(
      'Unregistered background-aware service: ${service.serviceName}',
      name: 'BackgroundActivityManager',
      category: LogCategory.system,
    );
  }

  /// Handle app lifecycle state changes
  void onAppLifecycleStateChanged(AppLifecycleState state) {
    final wasInForeground = _isAppInForeground;

    switch (state) {
      case AppLifecycleState.resumed:
        _isAppInForeground = true;
        if (!wasInForeground) {
          _onAppResumed();
        }

      case AppLifecycleState.inactive:
        // On desktop platforms, inactive is a normal state during UI operations
        // Don't treat it as backgrounded to avoid disrupting video playback
        Log.debug(
          'App became inactive (keeping foreground state)',
          name: 'BackgroundActivityManager',
          category: LogCategory.system,
        );

      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _isAppInForeground = false;
        if (wasInForeground) {
          _onAppBackgrounded();
        }

      case AppLifecycleState.detached:
        _isAppInForeground = false;
        _onAppTerminating();
    }
  }

  /// Handle app entering background
  void _onAppBackgrounded() {
    Log.info(
      '📱 App entered background - suspending non-critical activities',
      name: 'BackgroundActivityManager',
      category: LogCategory.system,
    );

    // Cancel any existing suspension timer
    _backgroundSuspensionTimer?.cancel();

    // Immediate actions for background state
    _performImmediateBackgroundActions();

    // Delayed actions after 30 seconds in background
    _backgroundSuspensionTimer = Timer(const Duration(seconds: 30), () {
      if (isAppInBackground) {
        _performDelayedBackgroundActions();
      }
    });
  }

  /// Handle app resuming from background
  void _onAppResumed() {
    Log.info(
      '📱 App resumed from background - restoring activities',
      name: 'BackgroundActivityManager',
      category: LogCategory.system,
    );

    // Cancel background suspension timer
    _backgroundSuspensionTimer?.cancel();

    // Restore all services
    _restoreServices();
  }

  /// Handle app termination
  void _onAppTerminating() {
    Log.info(
      '📱 App terminating - cleaning up resources',
      name: 'BackgroundActivityManager',
      category: LogCategory.system,
    );

    _backgroundSuspensionTimer?.cancel();

    // Force suspend all services
    _suspendAllServices();
  }

  /// Immediate actions when app goes to background
  void _performImmediateBackgroundActions() {
    Log.info(
      '🔄 Performing immediate background actions',
      name: 'BackgroundActivityManager',
      category: LogCategory.system,
    );

    // Fan out per-service notifications onto microtasks so a slow or
    // misbehaving service cannot block the suspend pass. See the comment on
    // [_suspendGracePeriod] for why the .timeout() bound exists despite
    // never firing against the current sync `void` interface.
    for (final service in _registeredServices) {
      Future.microtask(() async {
        try {
          await Future(service.onAppBackgrounded).timeout(_suspendGracePeriod);
        } on TimeoutException {
          Log.warning(
            'Service ${service.serviceName} exceeded '
            '${_suspendGracePeriod.inSeconds}s suspend grace period',
            name: 'BackgroundActivityManager',
            category: LogCategory.system,
          );
        } catch (e) {
          Log.error(
            'Error suspending service ${service.serviceName}: $e',
            name: 'BackgroundActivityManager',
            category: LogCategory.system,
          );
        }
      });
    }
  }

  /// Delayed actions after app has been in background for a while
  void _performDelayedBackgroundActions() {
    Log.info(
      '🔄 Performing delayed background suspension',
      name: 'BackgroundActivityManager',
      category: LogCategory.system,
    );

    for (final service in _registeredServices) {
      try {
        service.onExtendedBackground();
      } catch (e) {
        Log.error(
          'Error in extended background handling for ${service.serviceName}: $e',
          name: 'BackgroundActivityManager',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Restore services when app returns to foreground
  void _restoreServices() {
    Log.info(
      '🔄 Restoring services from background',
      name: 'BackgroundActivityManager',
      category: LogCategory.system,
    );

    for (final service in _registeredServices) {
      try {
        service.onAppResumed();
      } catch (e) {
        Log.error(
          'Error restoring service ${service.serviceName}: $e',
          name: 'BackgroundActivityManager',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Suspend all services immediately
  void _suspendAllServices() {
    for (final service in _registeredServices) {
      try {
        service.onExtendedBackground();
      } catch (e) {
        Log.error(
          'Error force-suspending service ${service.serviceName}: $e',
          name: 'BackgroundActivityManager',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Get status information for debugging
  Map<String, dynamic> getStatus() {
    return {
      'isAppInForeground': _isAppInForeground,
      'registeredServices': _registeredServices.length,
      'serviceNames': _registeredServices.map((s) => s.serviceName).toList(),
    };
  }

  void dispose() {
    _backgroundSuspensionTimer?.cancel();
    _registeredServices.clear();
  }

  /// Restores this manager to its construction state.
  ///
  /// [dispose] is not a substitute: it leaves [_isAppInForeground] wherever
  /// the last lifecycle event put it, and a stale `false` there is what turns
  /// a later `resumed` into a fan-out over whatever is still registered
  /// (#6880).
  @visibleForTesting
  void resetForTesting() {
    _backgroundSuspensionTimer?.cancel();
    _backgroundSuspensionTimer = null;
    _registeredServices.clear();
    _isAppInForeground = true;
  }
}

/// Interface for services that need background state awareness
abstract class BackgroundAwareService {
  /// Name of the service for logging purposes
  String get serviceName;

  /// Called immediately when app goes to background
  void onAppBackgrounded();

  /// Called when app has been in background for extended time
  void onExtendedBackground();

  /// Called when app returns to foreground
  void onAppResumed();
}
