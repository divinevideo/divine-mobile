// ABOUTME: Manages app background state to prevent network usage and battery drain
// ABOUTME: Suspends non-critical services when app goes to background to conserve resources

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Background activity manager to control network and battery usage
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class BackgroundActivityManager {
  static final BackgroundActivityManager _instance =
      BackgroundActivityManager._internal();
  factory BackgroundActivityManager() => _instance;
  BackgroundActivityManager._internal();

  bool _isAppInForeground = true;
  bool _isInitialized = false;
  final List<BackgroundAwareService> _registeredServices = [];

  // Timers for delayed actions
  Timer? _backgroundSuspensionTimer;
  Timer? _periodicCleanupTimer;

  /// Current app foreground state
  bool get isAppInForeground => _isAppInForeground;
  bool get isAppInBackground => !_isAppInForeground;

  /// Initialize the background activity manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isInitialized = true;

    // Start periodic cleanup timer (runs every 5 minutes)
    _periodicCleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isAppInForeground) {
        _performPeriodicCleanup();
      }
    });

    Log.info(
      'Background activity manager initialized',
      name: 'BackgroundActivityManager',
      category: LogCategory.system,
    );
  }

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
        break;

      case AppLifecycleState.inactive:
        // On desktop platforms, inactive is a normal state during UI operations
        // Don't treat it as backgrounded to avoid disrupting video playback
        Log.debug(
          'App became inactive (keeping foreground state)',
          name: 'BackgroundActivityManager',
          category: LogCategory.system,
        );
        break;

      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _isAppInForeground = false;
        if (wasInForeground) {
          _onAppBackgrounded();
        }
        break;

      case AppLifecycleState.detached:
        _isAppInForeground = false;
        _onAppTerminating();
        break;
    }

    if (wasInForeground != _isAppInForeground) {}
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
    _periodicCleanupTimer?.cancel();

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

    // Process services async with timeout to prevent watchdog kills
    for (final service in _registeredServices) {
      Future.microtask(() async {
        try {
          // Give each service max 1 second to suspend
          await Future.any([
            Future(() => service.onAppBackgrounded()),
            Future.delayed(const Duration(seconds: 1)),
          ]);
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

  /// Periodic cleanup when app is in foreground
  void _performPeriodicCleanup() {
    Log.debug(
      '🧹 Performing periodic cleanup',
      name: 'BackgroundActivityManager',
      category: LogCategory.system,
    );

    for (final service in _registeredServices) {
      try {
        service.onPeriodicCleanup();
      } catch (e) {
        Log.error(
          'Error in periodic cleanup for ${service.serviceName}: $e',
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
    _periodicCleanupTimer?.cancel();
    _registeredServices.clear();
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

  /// Called periodically for cleanup (every 5 minutes while in foreground)
  void onPeriodicCleanup();
}
