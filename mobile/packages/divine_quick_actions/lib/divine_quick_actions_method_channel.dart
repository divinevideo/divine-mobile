// ABOUTME: Method-channel implementation for Divine quick actions.
// ABOUTME: Handles native shortcut configuration and activation callbacks.

import 'dart:async';

import 'package:divine_quick_actions/divine_quick_actions_platform_interface.dart';
import 'package:divine_quick_actions/src/models/divine_quick_action.dart';
import 'package:divine_quick_actions/src/models/divine_quick_action_event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// An implementation of [DivineQuickActionsPlatform] that uses method channels.
class MethodChannelDivineQuickActions extends DivineQuickActionsPlatform {
  /// Constructor that sets up the native callback handler.
  MethodChannelDivineQuickActions() {
    methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('divine_quick_actions');

  final StreamController<DivineQuickActionEvent> _actionController =
      StreamController<DivineQuickActionEvent>.broadcast();

  final StreamController<void> _cameraWidgetPinnedController =
      StreamController<void>.broadcast();

  @override
  Stream<DivineQuickActionEvent> get actionStream => _actionController.stream;

  @override
  Stream<void> get cameraWidgetPinnedStream =>
      _cameraWidgetPinnedController.stream;

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onQuickAction':
        final arguments = call.arguments;
        if (arguments is Map<dynamic, dynamic>) {
          final action = DivineQuickActionEvent.tryFromMap(arguments);
          if (action != null) {
            _actionController.add(action);
          }
        }
        return null;
      case 'onCameraWidgetPinned':
        _cameraWidgetPinnedController.add(null);
        return null;
      default:
        return null;
    }
  }

  @override
  Future<bool> isSupported() async {
    final result = await methodChannel.invokeMethod<bool>('isSupported');
    return result ?? false;
  }

  @override
  Future<bool> setActions(List<DivineQuickAction> actions) async {
    final result = await methodChannel.invokeMethod<bool>(
      'setActions',
      actions.map((action) => action.toMap()).toList(),
    );
    return result ?? false;
  }

  @override
  Future<List<DivineQuickAction>> getActions() async {
    final result = await methodChannel.invokeListMethod<dynamic>('getActions');
    return (result ?? const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map(DivineQuickAction.tryFromMap)
        .whereType<DivineQuickAction>()
        .toList();
  }

  @override
  Future<bool> clearActions() async {
    final result = await methodChannel.invokeMethod<bool>('clearActions');
    return result ?? false;
  }

  @override
  Future<DivineQuickActionEvent?> consumeLaunchAction() async {
    final result = await methodChannel.invokeMapMethod<dynamic, dynamic>(
      'consumeLaunchAction',
    );
    if (result == null) return null;
    return DivineQuickActionEvent.tryFromMap(result, isLaunchAction: true);
  }

  @override
  Future<bool> isCameraWidgetPinSupported() async {
    final result = await methodChannel.invokeMethod<bool>(
      'isCameraWidgetPinSupported',
    );
    return result ?? false;
  }

  @override
  Future<bool> requestPinCameraWidget() async {
    final result = await methodChannel.invokeMethod<bool>(
      'requestPinCameraWidget',
    );
    return result ?? false;
  }
}
