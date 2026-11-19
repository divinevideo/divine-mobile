// ABOUTME: Method and event channel wrapper for the iOS post Live Activity.
// ABOUTME: Implements the repository's platform port; no-ops off iOS and on web.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:post_live_activity_repository/post_live_activity_repository.dart';
import 'package:unified_logger/unified_logger.dart';

const _logName = 'PostLiveActivityChannel';

bool _defaultIsSupported() =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// The native `divine/post_live_activity` bridge as a [LiveActivityPlatform].
///
/// Off iOS and on web nothing touches the channel: [isEnabled] is false,
/// [start] throws [UnsupportedError], everything else is a no-op and
/// [events] is empty.
class PostLiveActivityChannel implements LiveActivityPlatform {
  /// Creates the channel wrapper.
  PostLiveActivityChannel({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
    bool Function()? isSupported,
  }) : _method = methodChannel ?? const MethodChannel(methodChannelName),
       _eventChannel = eventChannel ?? const EventChannel(eventChannelName),
       _isSupported = isSupported ?? _defaultIsSupported;

  /// Name of the method channel.
  static const methodChannelName = 'divine/post_live_activity';

  /// Name of the event channel.
  static const eventChannelName = 'divine/post_live_activity/events';

  final MethodChannel _method;
  final EventChannel _eventChannel;
  final bool Function() _isSupported;

  late final Stream<LiveActivityPlatformEvent> _events = _isSupported()
      ? _eventChannel
            .receiveBroadcastStream()
            .map(_parseEvent)
            .where((event) => event != null)
            .cast<LiveActivityPlatformEvent>()
            .asBroadcastStream()
      : const Stream<LiveActivityPlatformEvent>.empty();

  @override
  Stream<LiveActivityPlatformEvent> get events => _events;

  @override
  Future<bool> isEnabled() async {
    if (!_isSupported()) return false;
    try {
      return await _method.invokeMethod<bool>('isEnabled') ?? false;
    } on PlatformException catch (e) {
      _warn('isEnabled failed: $e');
      return false;
    } on MissingPluginException catch (e) {
      _warn('channel missing for isEnabled: $e');
      return false;
    }
  }

  @override
  Future<String> writeThumbnail(Uint8List bytes) async {
    if (!_isSupported()) return '';
    final name = await _method.invokeMethod<String>('writeThumbnail', {
      'bytes': bytes,
    });
    return name ?? '';
  }

  @override
  Future<String> start({
    required String ownerPubkey,
    required bool showFirstRunNote,
    String? thumbnailFileName,
  }) async {
    if (!_isSupported()) {
      throw UnsupportedError('Live Activities are only available on iOS');
    }
    final id = await _method.invokeMethod<String>('start', {
      'ownerPubkey': ownerPubkey,
      'thumbnailFileName': thumbnailFileName,
      'showFirstRunNote': showFirstRunNote,
    });
    if (id == null) {
      throw PlatformException(
        code: 'activity_failed',
        message: 'start returned no activity id',
      );
    }
    return id;
  }

  @override
  Future<void> update(
    String id, {
    required LiveActivityPhase phase,
    required bool showFirstRunNote,
    String? postCoordinate,
    String? postEventId,
  }) async {
    if (!_isSupported()) return;
    await _method.invokeMethod<void>('update', {
      'activityId': id,
      'phase': phase.name,
      'postCoordinate': postCoordinate,
      'postEventId': postEventId,
      'showFirstRunNote': showFirstRunNote,
    });
  }

  @override
  Future<void> end(String id, {required bool immediate}) async {
    if (!_isSupported()) return;
    await _method.invokeMethod<void>('end', {
      'activityId': id,
      'immediate': immediate,
    });
  }

  @override
  Future<List<RunningLiveActivity>> list() async {
    if (!_isSupported()) return const [];
    final raw = await _method.invokeListMethod<Object?>('list') ?? const [];
    final running = <RunningLiveActivity>[];
    for (final entry in raw) {
      final parsed = _parseRunning(entry);
      if (parsed == null) {
        _warn('dropping malformed list entry: $entry');
      } else {
        running.add(parsed);
      }
    }
    return running;
  }

  RunningLiveActivity? _parseRunning(Object? entry) {
    if (entry is! Map) return null;
    final id = entry['activityId'];
    final owner = entry['ownerPubkey'];
    final startedAtMs = entry['startedAtMs'];
    final state = _parseState(entry['state']);
    final coordinate = entry['postCoordinate'];
    final eventId = entry['postEventId'];
    if (id is! String ||
        owner is! String ||
        startedAtMs is! int ||
        state == null ||
        (coordinate != null && coordinate is! String) ||
        (eventId != null && eventId is! String)) {
      return null;
    }
    return RunningLiveActivity(
      id: id,
      ownerPubkey: owner,
      startedAt: DateTime.fromMillisecondsSinceEpoch(startedAtMs),
      postCoordinate: coordinate as String?,
      postEventId: eventId as String?,
      state: state,
    );
  }

  LiveActivityPlatformEvent? _parseEvent(Object? raw) {
    final event = _tryParseEvent(raw);
    if (event == null) _warn('dropping malformed event: $raw');
    return event;
  }

  LiveActivityPlatformEvent? _tryParseEvent(Object? raw) {
    if (raw is! Map) return null;
    switch (raw['type']) {
      case 'enablement':
        final enabled = raw['enabled'];
        return enabled is bool ? EnablementChanged(enabled: enabled) : null;
      case 'pushToken':
        final id = raw['activityId'];
        final token = raw['token'];
        return id is String && token is String
            ? PushTokenChanged(activityId: id, token: token)
            : null;
      case 'state':
        final id = raw['activityId'];
        final state = _parseState(raw['state']);
        return id is String && state != null
            ? ActivityStateChanged(activityId: id, state: state)
            : null;
    }
    return null;
  }

  LiveActivityState? _parseState(Object? value) => switch (value) {
    'active' => LiveActivityState.active,
    'ended' => LiveActivityState.ended,
    'dismissed' => LiveActivityState.dismissed,
    'stale' => LiveActivityState.stale,
    _ => null,
  };

  void _warn(String message) =>
      Log.warning(message, name: _logName, category: LogCategory.system);
}
