// ABOUTME: Method-channel implementation of the background uploader platform.
// ABOUTME: Forwards enqueue/cancel to native and fans native events into Dart.

import 'dart:async';

import 'package:background_uploader/background_uploader_platform_interface.dart';
import 'package:background_uploader/src/models/background_upload_event.dart';
import 'package:background_uploader/src/models/background_upload_request.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// An implementation of [BackgroundUploaderPlatform] that uses method channels.
class MethodChannelBackgroundUploader extends BackgroundUploaderPlatform {
  /// Constructor that wires the native event callback.
  MethodChannelBackgroundUploader({
    @visibleForTesting MethodChannel? methodChannel,
  }) : methodChannel =
           methodChannel ?? const MethodChannel('background_uploader') {
    this.methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final MethodChannel methodChannel;

  final StreamController<BackgroundUploadEvent> _eventController =
      StreamController<BackgroundUploadEvent>.broadcast();

  /// Most-recent terminal event per taskId, retained until claimed via
  /// [takeBufferedTerminalEvent]. The OS (notably an iOS background
  /// `URLSession`) delivers terminal events for uploads that finished while
  /// the app was dead as soon as the engine attaches — often before any Dart
  /// listener has subscribed to the broadcast [events] stream, which would
  /// silently drop them. Buffering lets startup reconciliation recover them.
  /// Bounded to [_maxBufferedTerminals] with oldest-first eviction.
  final Map<String, BackgroundUploadEvent> _bufferedTerminals =
      <String, BackgroundUploadEvent>{};

  static const int _maxBufferedTerminals = 64;

  @override
  Stream<BackgroundUploadEvent> get events => _eventController.stream;

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onUploadEvent':
        final arguments = call.arguments;
        if (arguments is Map<dynamic, dynamic>) {
          final event = BackgroundUploadEvent.tryFromMap(arguments);
          if (event != null) {
            if (event.isTerminal) {
              _bufferTerminal(event);
            }
            _eventController.add(event);
          }
        }
        return null;
      default:
        return null;
    }
  }

  void _bufferTerminal(BackgroundUploadEvent event) {
    // Re-insert so the freshest entry is last for oldest-first eviction.
    _bufferedTerminals
      ..remove(event.taskId)
      ..[event.taskId] = event;
    while (_bufferedTerminals.length > _maxBufferedTerminals) {
      _bufferedTerminals.remove(_bufferedTerminals.keys.first);
    }
  }

  @override
  Future<BackgroundUploadEvent?> takeBufferedTerminalEvent(
    String taskId,
  ) async {
    return _bufferedTerminals.remove(taskId);
  }

  @override
  Future<bool> isSupported() async {
    final result = await methodChannel.invokeMethod<bool>('isSupported');
    return result ?? false;
  }

  @override
  Future<void> enqueue(BackgroundUploadRequest request) {
    return methodChannel.invokeMethod<void>('enqueue', request.toMap());
  }

  @override
  Future<void> cancel(String taskId) {
    return methodChannel.invokeMethod<void>('cancel', <String, Object?>{
      'taskId': taskId,
    });
  }

  @override
  Future<void> beginForegroundSession(String sessionId) {
    return methodChannel.invokeMethod<void>(
      'beginForegroundSession',
      <String, Object?>{'sessionId': sessionId},
    );
  }

  @override
  Future<void> endForegroundSession(String sessionId) {
    return methodChannel.invokeMethod<void>(
      'endForegroundSession',
      <String, Object?>{'sessionId': sessionId},
    );
  }

  @override
  Future<List<String>> activeTaskIds() async {
    final result = await methodChannel.invokeListMethod<String>(
      'activeTaskIds',
    );
    return result ?? const <String>[];
  }

  /// Releases this instance's channel handler and event stream.
  @visibleForTesting
  Future<void> dispose() async {
    methodChannel.setMethodCallHandler(null);
    await _eventController.close();
  }
}
