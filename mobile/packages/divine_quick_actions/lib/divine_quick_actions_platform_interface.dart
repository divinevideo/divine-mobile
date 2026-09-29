// ABOUTME: Platform interface for Divine quick actions.
// ABOUTME: Defines shortcut configuration and activation contracts.

import 'dart:async';

import 'package:divine_quick_actions/divine_quick_actions_method_channel.dart';
import 'package:divine_quick_actions/src/models/divine_quick_action.dart';
import 'package:divine_quick_actions/src/models/divine_quick_action_event.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The interface that implementations of divine_quick_actions must implement.
abstract class DivineQuickActionsPlatform extends PlatformInterface {
  /// Constructs a DivineQuickActionsPlatform.
  DivineQuickActionsPlatform() : super(token: _token);

  static final Object _token = Object();

  static DivineQuickActionsPlatform _instance =
      MethodChannelDivineQuickActions();

  /// The default instance of [DivineQuickActionsPlatform] to use.
  ///
  /// Defaults to [MethodChannelDivineQuickActions].
  static DivineQuickActionsPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [DivineQuickActionsPlatform] when
  /// they register themselves.
  static set instance(DivineQuickActionsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Emits shortcut activations received while the app is already running.
  Stream<DivineQuickActionEvent> get actionStream {
    throw UnimplementedError('actionStream has not been implemented.');
  }

  /// Returns whether the current platform supports home-screen quick actions.
  Future<bool> isSupported() {
    throw UnimplementedError('isSupported() has not been implemented.');
  }

  /// Replaces all dynamic quick actions with [actions].
  Future<bool> setActions(List<DivineQuickAction> actions) {
    throw UnimplementedError('setActions() has not been implemented.');
  }

  /// Returns the dynamic quick actions currently configured by the app.
  Future<List<DivineQuickAction>> getActions() {
    throw UnimplementedError('getActions() has not been implemented.');
  }

  /// Clears all dynamic quick actions.
  Future<bool> clearActions() {
    throw UnimplementedError('clearActions() has not been implemented.');
  }

  /// Returns and clears a shortcut used to launch the app, if any.
  Future<DivineQuickActionEvent?> consumeLaunchAction() {
    throw UnimplementedError('consumeLaunchAction() has not been implemented.');
  }

  // The camera-widget members below default to "unsupported" rather than
  // throwing: a platform that cannot pin widgets is truthfully reporting that.

  /// Emits each time the launcher confirms the camera widget was added after
  /// [requestPinCameraWidget].
  Stream<void> get cameraWidgetPinnedStream => const Stream<void>.empty();

  /// Returns whether the launcher can add the camera widget on the user's
  /// behalf.
  Future<bool> isCameraWidgetPinSupported() => Future<bool>.value(false);

  /// Asks the launcher to add the camera widget to the home screen.
  Future<bool> requestPinCameraWidget() => Future<bool>.value(false);
}
