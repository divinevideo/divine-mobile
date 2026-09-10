// ABOUTME: Coordinates native home-screen quick actions with app auth/routing.
// ABOUTME: Keeps startup quick-action orchestration testable outside main.dart.

import 'dart:async';

import 'package:divine_quick_actions/divine_quick_actions.dart';
import 'package:openvine/services/auth_service.dart' show AuthState;
import 'package:unified_logger/unified_logger.dart';

const quickActionCameraType = 'camera';
const quickActionNotificationsType = 'notifications';

typedef QuickActionErrorReporter = Future<void> Function(
  Object error,
  StackTrace stackTrace,
  String reason,
);

typedef QuickActionDelay = Future<bool> Function();
typedef QuickActionCallbackScheduler = void Function(void Function() callback);

class QuickActionTitles {
  const QuickActionTitles({required this.camera, required this.notifications});

  final String camera;
  final String notifications;
}

abstract interface class QuickActionsClient {
  Future<bool> get isSupported;

  Future<DivineQuickActionEvent?> initialize({
    void Function(DivineQuickActionEvent action)? onAction,
  });

  Future<bool> setActions(List<DivineQuickAction> actions);

  Future<bool> clearActions();

  Future<void> dispose();
}

class DivineQuickActionsClient implements QuickActionsClient {
  DivineQuickActionsClient([DivineQuickActions? quickActions])
    : _quickActions = quickActions ?? DivineQuickActions.instance;

  final DivineQuickActions _quickActions;

  @override
  Future<bool> get isSupported => _quickActions.isSupported;

  @override
  Future<DivineQuickActionEvent?> initialize({
    void Function(DivineQuickActionEvent action)? onAction,
  }) {
    return _quickActions.initialize(onAction: onAction);
  }

  @override
  Future<bool> setActions(List<DivineQuickAction> actions) {
    return _quickActions.setActions(actions);
  }

  @override
  Future<bool> clearActions() {
    return _quickActions.clearActions();
  }

  @override
  Future<void> dispose() {
    return _quickActions.dispose();
  }
}

abstract interface class QuickActionsNavigator {
  String get currentPath;

  void openCamera();

  void openNotifications();

  void suppressAuthenticatedAuthRouteRedirect();

  void clearAuthRouteRedirectSuppression();
}

class QuickActionsCoordinator {
  QuickActionsCoordinator({
    required QuickActionsClient client,
    required Stream<AuthState> authStateStream,
    required AuthState Function() readAuthState,
    required QuickActionTitles Function() readTitles,
    required QuickActionsNavigator navigator,
    required QuickActionErrorReporter reportError,
    required QuickActionDelay waitForAuthRedirectToSettle,
    required QuickActionCallbackScheduler scheduleRedirectSuppressionClear,
    required bool isAndroid,
    String cameraPath = '/video-recorder',
  }) : _client = client,
       _authStateStream = authStateStream,
       _readAuthState = readAuthState,
       _readTitles = readTitles,
       _navigator = navigator,
       _reportError = reportError,
       _waitForAuthRedirectToSettle = waitForAuthRedirectToSettle,
       _scheduleRedirectSuppressionClear = scheduleRedirectSuppressionClear,
       _isAndroid = isAndroid,
       _cameraPath = cameraPath;

  final QuickActionsClient _client;
  final Stream<AuthState> _authStateStream;
  final AuthState Function() _readAuthState;
  final QuickActionTitles Function() _readTitles;
  final QuickActionsNavigator _navigator;
  final QuickActionErrorReporter _reportError;
  final QuickActionDelay _waitForAuthRedirectToSettle;
  final QuickActionCallbackScheduler _scheduleRedirectSuppressionClear;
  final bool _isAndroid;
  final String _cameraPath;

  StreamSubscription<AuthState>? _authSubscription;
  DivineQuickActionEvent? _pendingAction;

  void start() {
    unawaited(
      _client.initialize(onAction: handleAction).catchError((
        Object error,
        StackTrace stackTrace,
      ) async {
        Log.warning(
          'Quick actions initialization failed: $error',
          name: 'QuickActions',
          category: LogCategory.system,
        );
        await _reportError(
          error,
          stackTrace,
          'Quick actions initialization failed',
        );
        return null;
      }),
    );

    unawaited(_authSubscription?.cancel());
    _authSubscription = _authStateStream.distinct().listen((authState) {
      unawaited(syncActions());
      handleAuthStateChanged(authState);
    });

    unawaited(syncActions());
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
    await _client.dispose();
  }

  Future<void> syncActions() async {
    final authState = _readAuthState();
    final titles = _readTitles();

    try {
      final isSupported = await _client.isSupported;
      if (!isSupported) return;

      if (authState != AuthState.authenticated) {
        if (_isAuthPending(authState)) return;

        final cleared = await _client.clearActions();
        Log.debug(
          'Quick actions cleared for unauthenticated state: $cleared',
          name: 'QuickActions',
          category: LogCategory.system,
        );
        return;
      }

      if (_isAndroid) {
        // Android launchers can retain stale dynamic shortcut metadata unless
        // the old set is explicitly removed before publishing the replacement.
        await _client.clearActions();
      }

      final updated = await _client.setActions(<DivineQuickAction>[
        DivineQuickAction(
          type: quickActionCameraType,
          title: titles.camera,
          androidIconName: 'ic_quick_action_camera_padded',
          iosIconName: 'camera.fill',
          iosIconStyle: DivineQuickActionIosIconStyle.system,
          rank: 0,
        ),
        DivineQuickAction(
          type: quickActionNotificationsType,
          title: titles.notifications,
          androidIconName: 'ic_quick_action_notifications_padded',
          iosIconName: 'bell.fill',
          iosIconStyle: DivineQuickActionIosIconStyle.system,
          rank: 1,
        ),
      ]);
      Log.debug(
        'Quick actions configured for authenticated user: $updated',
        name: 'QuickActions',
        category: LogCategory.system,
      );
    } catch (error, stackTrace) {
      Log.warning(
        'Quick actions sync failed: $error',
        name: 'QuickActions',
        category: LogCategory.system,
      );
      await _reportError(error, stackTrace, 'Quick actions sync failed');
    }
  }

  void handleAction(DivineQuickActionEvent action) {
    final authState = _readAuthState();
    if (authState != AuthState.authenticated) {
      if (_isAuthPending(authState)) {
        _pendingAction = action;
        Log.info(
          'Deferring quick action until auth restores: ${action.type}',
          name: 'QuickActions',
          category: LogCategory.system,
        );
        return;
      }

      _pendingAction = null;
      Log.info(
        'Ignoring quick action while unauthenticated: ${action.type}',
        name: 'QuickActions',
        category: LogCategory.system,
      );
      unawaited(_client.clearActions());
      return;
    }

    switch (action.type) {
      case quickActionCameraType:
        _openCamera();
      case quickActionNotificationsType:
        Log.info(
          'Opening notifications from quick action',
          name: 'QuickActions',
          category: LogCategory.ui,
        );
        _navigator.openNotifications();
      default:
        Log.warning(
          'Unknown quick action ignored: ${action.type}',
          name: 'QuickActions',
          category: LogCategory.system,
        );
    }
  }

  void handleAuthStateChanged(AuthState authState) {
    final pendingAction = _pendingAction;
    if (pendingAction == null || _isAuthPending(authState)) return;

    _pendingAction = null;
    if (authState == AuthState.authenticated) {
      unawaited(_handlePendingActionAfterAuthRedirect(pendingAction));
      return;
    }

    Log.info(
      'Dropping deferred quick action after auth resolved: ${pendingAction.type}',
      name: 'QuickActions',
      category: LogCategory.system,
    );
  }

  bool _isAuthPending(AuthState authState) {
    return switch (authState) {
      AuthState.checking || AuthState.authenticating => true,
      AuthState.authenticated ||
      AuthState.unauthenticated ||
      AuthState.awaitingTosAcceptance => false,
    };
  }

  Future<void> _handlePendingActionAfterAuthRedirect(
    DivineQuickActionEvent action,
  ) async {
    final shouldContinue = await _waitForAuthRedirectToSettle();
    if (!shouldContinue) return;

    handleAction(action);
  }

  void _openCamera() {
    Log.info(
      'Opening camera from quick action',
      name: 'QuickActions',
      category: LogCategory.ui,
    );
    if (_navigator.currentPath == _cameraPath) return;

    _navigator.suppressAuthenticatedAuthRouteRedirect();
    _navigator.openCamera();
    _scheduleRedirectSuppressionClear(
      _navigator.clearAuthRouteRedirectSuppression,
    );
  }
}
